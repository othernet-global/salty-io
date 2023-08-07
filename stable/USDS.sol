// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.21;

import "../openzeppelin/token/ERC20/ERC20.sol";
import "../stable/interfaces/ICollateral.sol";
import "../stable/interfaces/IStableConfig.sol";
import "./interfaces/IUSDS.sol";
import "../pools/PoolUtils.sol";
import "../pools/interfaces/IPools.sol";
import "../pools/interfaces/ICounterswap.sol";
import "../price_feed/interfaces/IPriceAggregator.sol";
import "../pools/interfaces/IPoolsConfig.sol";
import "../interfaces/IExchangeConfig.sol";


// USDS can be borrowed by users who have deposited WBTC/WETH liquidity as collateral via Collateral.sol
// The default initial collateralization ratio of collateral / borrowed USDS is 200%.
// The minimum default collateral ratio is 110% - below which positions can be liquidated by any user.

// If WBTC/WETH collateral is liquidated the reclaimed WBTC and WETH tokens are sent to this contract and swapped for USDS which is then burned (essentially "undoing" the user's original collateral deposit and USDS borrow).
contract USDS is ERC20, IUSDS
    {
    IPoolsConfig immutable public poolsConfig;
    IERC20 immutable public wbtc;
    IERC20 immutable public weth;

    ICollateral public collateral;
    IDAO public dao;
    IPools public pools;

	// This corresponds to USDS that was borrowed by users who had their collateral liquidated.
	// Because liquidated collateral no longer exists the borrowed USDS needs to be burned as well in order to
	// "undo" the collateralized position and return state back to where it was before the user deposited collateral and borrowed USDS.
	uint256 public usdsThatShouldBeBurned;


	constructor( IPoolsConfig _poolsConfig, IERC20 _wbtc, IERC20 _weth )
		ERC20( "testUSDS", "USDS" )
		{
		require( address(_poolsConfig) != address(0), "_poolsConfig cannot be address(0)" );
		require( address(_wbtc) != address(0), "_wbtc cannot be address(0)" );
		require( address(_weth) != address(0), "_weth cannot be address(0)" );

		poolsConfig = _poolsConfig;
		wbtc = _wbtc;
		weth = _weth;
        }


	// The Collateral contract will be set at deployment time and after that become immutable
	function setCollateral( ICollateral _collateral ) public
		{
		require( address(_collateral) != address(0), "_collateral cannot be address(0)" );
		require( address(collateral) == address(0), "setCollateral can only be called once" );

		collateral = _collateral;
		}


	// The Pools contract will be set at deployment time and after that become immutable
	function setPools( IPools _pools ) public
		{
		require( address(_pools) != address(0), "_pools cannot be address(0)" );
		require( address(pools) == address(0), "setPools can only be called once" );

		pools = _pools;
		}


	// The DAO contract will be set at deployment time and after that become immutable
	function setDAO( IDAO _dao ) public
		{
		require( address(_dao) != address(0), "_dao cannot be address(0)" );
		require( address(dao) == address(0), "setDAO can only be called once" );

		dao = _dao;
		}


	// Mint from the Collateral contract to allow users to borrow USDS after depositing BTC/ETH liquidity as collateral
	// Only callable by the Collateral contract.
	function mintTo( address wallet, uint256 amount ) public
		{
		require( msg.sender == address(collateral), "Can only mint from the Collateral contract" );
		require( address(wallet) != address(0), "Cannot mint to address(0)" );

		_mint( wallet, amount );
		}


	// Called when a user's collateral position has been liquidated to indicate that the borrowed USDS from the position needs to be burned.
	// Only callable by the Collateral contract.
	function shouldBurnMoreUSDS( uint256 usdsToBurn ) public
		{
		require( msg.sender == address(collateral), "Not the Collateral contract" );

		usdsThatShouldBeBurned += usdsToBurn;
		}


	// Send the specified token to Counterswap so that it is gradually converted to USDS
	function _sendTokenToCounterswap( ICounterswap counterswap, IERC20 token ) internal
		{
		uint256 tokenBalance = token.balanceOf( address(this) );
		if ( tokenBalance == 0 )
			return;

		token.approve( address(counterswap), tokenBalance );

		// We want to convert the sent token to USDS (this contract)
		counterswap.depositToken( token, this, tokenBalance );
		}


	// Send all WBTC and WETH in this contract to the Counterswap contract so that it can gradually be swapped to USDS (which can then be burned).
	// The WBTC and WETH is sent here on calls to Collateral.liquidateUser();
	function performUpkeep() public
		{
		require( msg.sender == address(dao), "Only callable from the DAO" );

		ICounterswap counterswap = poolsConfig.counterswap();

		// Send any WBTC or WETH in this contract to the Counterswap contract for gradual conversion to USDS
		_sendTokenToCounterswap(counterswap, wbtc);
		_sendTokenToCounterswap(counterswap, weth);

		if ( usdsThatShouldBeBurned == 0 )
			return;

		// Determine how much USDS has been converted through counterswaps and should be withdrawn from the Pools contract (deposited there earlier by the Counterswap contract).
		uint256 usdsToWithdraw = pools.depositedBalance( address(counterswap), this );

		// Don't withdraw more USDS than the amount to burn
		if ( usdsToWithdraw > usdsThatShouldBeBurned )
			usdsToWithdraw = usdsThatShouldBeBurned;

		if ( usdsToWithdraw == 0 )
			return;

		counterswap.withdrawToken( this, usdsToWithdraw );

		_burn( address(this), usdsToWithdraw );
		usdsThatShouldBeBurned -= usdsToWithdraw;
		}
	}

