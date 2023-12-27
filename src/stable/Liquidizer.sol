// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "../stable/interfaces/ICollateralAndLiquidity.sol";
import "../pools/interfaces/IPoolsConfig.sol";
import "../interfaces/IExchangeConfig.sol";
import "../pools/interfaces/IPools.sol";
import "./interfaces/ILiquidizer.sol";
import "./interfaces/IUSDS.sol";
import "../pools/PoolUtils.sol";

// Swaps tokens sent to this contract from collateral liquidiation and Protocol Owned Liquidity withdrawal to USDS - which is then burned.

// Extra USDS (beyond usdsThatShouldBeBurned) remains in this contract as a burnable buffer in the event of undercollateralized liquidation.
// Undercollateralized liquidation can happen if WBTC/WETH collateral drops rapidly in value so that collateral positions fall below a 100% collateral ratio before they can be liquidated.

// When there is insufficient USDS to burn, Protocol Owned Liquidity from the DAO is withdrawn, and converted to USDS.
contract Liquidizer is ILiquidizer, Ownable
    {
    event incrementedBurnableUSDS(uint256 newTotal);

	using SafeERC20 for ISalt;
	using SafeERC20 for IUSDS;

	// The percent of Protocol Owned Liquidity to withdraw when there is insufficient USDS to burn
    uint256 constant PERCENT_POL_TO_WITHDRAW = 1;

    IERC20 immutable public wbtc;
    IERC20 immutable public weth;
    IUSDS immutable public usds;
    ISalt immutable public salt;
    IERC20 immutable public dai;

    IExchangeConfig public exchangeConfig;
    IPoolsConfig immutable  public poolsConfig;
    ICollateralAndLiquidity public collateralAndLiquidity;
    IPools public pools;
    IDAO public dao;

	// This corresponds to USDS that was borrowed by users who had their collateral liquidated.
	// Because liquidated collateral no longer exists, the borrowed USDS needs to be burned in order to "undo" the collateralized position
	// and return state back to where it was before the liquidated user deposited collateral and borrowed USDS.
	uint256 public usdsThatShouldBeBurned;


	constructor( IExchangeConfig _exchangeConfig, IPoolsConfig _poolsConfig  )
		{
		poolsConfig = _poolsConfig;
		exchangeConfig = _exchangeConfig;

		wbtc = _exchangeConfig.wbtc();
		weth = _exchangeConfig.weth();
		usds = _exchangeConfig.usds();
		salt = _exchangeConfig.salt();
		dai = _exchangeConfig.dai();
        }


	// This will be called only once - at deployment time
	function setContracts( ICollateralAndLiquidity _collateralAndLiquidity, IPools _pools, IDAO _dao) external onlyOwner
		{
		collateralAndLiquidity = _collateralAndLiquidity;
		pools = _pools;
		dao = _dao;

		// Gas saving approve for future swaps.
		// Normally, this contract will have zero balances of these tokens.
		wbtc.approve( address(pools), type(uint256).max );
		weth.approve( address(pools), type(uint256).max );
		dai.approve( address(pools), type(uint256).max );

		// setContracts can only be called once
		renounceOwnership();
		}


	// Called when a user's collateral position has been liquidated - to indicate that the borrowed USDS from that position needs to be burned.
	function incrementBurnableUSDS( uint256 usdsToBurn ) external
		{
		require( msg.sender == address(collateralAndLiquidity), "Liquidizer.incrementBurnableUSDS is only callable from the CollateralAndLiquidity contract" );

		usdsThatShouldBeBurned += usdsToBurn;

		emit incrementedBurnableUSDS(usdsThatShouldBeBurned);
		}


	// Burn the specified amount of USDS
	function _burnUSDS(uint256 amountToBurn) internal
		{
		usds.safeTransfer( address(usds), amountToBurn );
		usds.burnTokensInContract();
		}


	// Burn up to usdsThatShouldBeBurned worth of USDS.
	// If there is a shortfall (as could be the case for undercollateralized liquidations), then withdraw a small percent of Protocol Owned Liquidity and convert it to USDS for burning.
	function _possiblyBurnUSDS() internal
		{
		// Check if there is USDS to burn
		if ( usdsThatShouldBeBurned == 0 )
			return;

		uint256 usdsBalance = usds.balanceOf(address(this));
		if ( usdsBalance >= usdsThatShouldBeBurned )
			{
			// Burn only up to usdsThatShouldBeBurned.
			// Leftover USDS will be kept in this contract in case it needs to be burned later.
			_burnUSDS( usdsThatShouldBeBurned );
    		usdsThatShouldBeBurned = 0;
			}
		else
			{
			// The entire usdsBalance will be burned - but there will still be an outstanding balance to burn later
			_burnUSDS( usdsBalance );
			usdsThatShouldBeBurned -= usdsBalance;

			// As there is a shortfall in the amount of USDS that can be burned, liquidate some Protocol Owned Liquidity and
			// send the underlying tokens here to be swapped to USDS
			dao.withdrawPOL(salt, usds, PERCENT_POL_TO_WITHDRAW);
			dao.withdrawPOL(dai, usds, PERCENT_POL_TO_WITHDRAW);
			}
		}


	// Swap WBTC, WETH and DAI in this contract to USDS (so that it can be burned).
	// Extra USDS will remain in the contract as a burnable buffer in the event of undercollateralized liquidation.
	// In the event insufficient USDS to burn, a small percent of Protocol Liquidity will be withdrawn from the DAO and converted to USDS for burning.
	function performUpkeep() external
		{
		require( msg.sender == address(exchangeConfig.upkeep()), "Liquidizer.performUpkeep is only callable from the Upkeep contract" );

		uint256 maximumInternalSwapPercentTimes1000 = poolsConfig.maximumInternalSwapPercentTimes1000();

		// Swap tokens that have previously been sent to this contract for USDS
		PoolUtils._placeInternalSwap(pools, wbtc, usds, wbtc.balanceOf(address(this)), maximumInternalSwapPercentTimes1000 );
		PoolUtils._placeInternalSwap(pools, weth, usds, weth.balanceOf(address(this)), maximumInternalSwapPercentTimes1000 );
		PoolUtils._placeInternalSwap(pools, dai, usds, dai.balanceOf(address(this)), maximumInternalSwapPercentTimes1000 );

		// Any SALT balance seen here should just be burned so as to not put negative price pressure on SALT by swapping it to USDS
		uint256 saltBalance = salt.balanceOf(address(this));
		if ( saltBalance > 0 )
			{
			salt.safeTransfer(address(salt), saltBalance);
			salt.burnTokensInContract();
			}

		_possiblyBurnUSDS();
		}
	}
