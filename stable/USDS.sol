// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.12;

import "../openzeppelin/token/ERC20/ERC20.sol";
import "../stable/interfaces/ICollateral.sol";
import "../stable/interfaces/IStableConfig.sol";
import "./interfaces/IUSDS.sol";
import "../Upkeepable.sol";
import "../pools/PoolUtils.sol";
import "../pools/interfaces/IPools.sol";


// USDS can be borrowed by users who have deposited WBTC/WETH liquidity as collateral via Collateral.sol
// The default initial collateralization ratio of collateral / borrowed USDS is 200%.
// The minimum default collateral ratio is 110%, below which positions can be liquidated by any user.

// If WBTC/WETH collateral is liquidated the WBTC and WETH tokens are sent to this contract and swapped for USDS which is then burned (essentially "undoing" the user's original collateral deposit and USDS borrow).
contract USDS is ERC20, IUSDS, Upkeepable
    {
    IStableConfig public stableConfig;
    IERC20 public wbtc;
    IERC20 public weth;

    ICollateral public collateral;
    IPools public pools;

	// This corresponds to USDS that was borrowed by users who had their collateral liquidated.
	// Because liquidated collateral no longer exists the borrowed USDS needs to be burned as well in order to
	// "undo" the collateralized position and return state back to where it was before the user deposited collateral and borrowed USDS.
	uint256 public usdsThatShouldBeBurned;


	constructor( IStableConfig _stableConfig, IERC20 _wbtc, IERC20 _weth )
		ERC20( "testUSDS", "USDS" )
		{
		require( address(_stableConfig) != address(0), "_stableConfig cannot be address(0)" );
		require( address(_wbtc) != address(0), "_wbtc cannot be address(0)" );
		require( address(_weth) != address(0), "_weth cannot be address(0)" );

		stableConfig = _stableConfig;
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


	// Mint from the Collateral contract to allow users to borrow USDS after depositing their BTC/ETH liquidity as collateral
	function mintTo( address wallet, uint256 amount ) public
		{
		require( msg.sender == address(collateral), "Can only mint from the Collateral contract" );
		require( address(wallet) != address(0), "cannot mint to address(0)" );

		_mint( wallet, amount );
		}


	// Called when a user's collateral position has been liquidated to indicate that the borrowed USDS from the position needs to be burned.
	// Only callable by the Collateral contract
	function shouldBurnMoreUSDS( uint256 usdsToBurn ) public
		{
		require( msg.sender == address(collateral), "Not the Collateral contract" );

		usdsThatShouldBeBurned += usdsToBurn;
		}


	// Swap a percentage of the given token (defined in stableConfig.percentSwapToUSDS) for USDS
	// Make sure that the swap has less slippage (in comparison to the price feed) than specified in stableConfig.maximumLiquidationSlippagePercentTimes1000
	function _swapPercentOfTokenForUSDS( IERC20 token, uint256 tokenPrice, uint256 percentSwapToUSDS, uint256 maximumLiquidationSlippagePercentTimes1000 ) internal
		{
		uint256 balance = token.balanceOf( address(this) );
		uint256 amountToSwap = (balance * percentSwapToUSDS) / 100;

		// Determine the minimum expected USDS
		uint256 amountOut = amountToSwap * tokenPrice / 10**18; // prices have 18 decimals
		uint256 minimumOut = amountOut * ( 100 * 1000 - maximumLiquidationSlippagePercentTimes1000 ) / 100;

		// Check that the required amountOut will be returned before trying to swap (to avoid the revert on failure)
		IERC20[] memory tokens = new IERC20[](2);
		tokens[0] = token;
		tokens[1] = this;

		uint256 quoteOut = pools.quoteAmountOut( tokens, amountToSwap );
		if ( quoteOut < minimumOut )
			return; // we'll try swapping again later

		// Already established the minimumOut will be met so don't specify minAmountOut
		pools.depositSwapWithdraw( token, this, amountToSwap, 0, block.timestamp );
		}


	// Check to see if there is usdsThatShouldBeBurned and if so burn USDS stored in this contract (which was sent here when users repaid their borrowed USDS in Collateral.sol).
	// Additionally, any WBTC/WETH sent here when user collateral was liquidated can be swapped for USDS which is then burned as well.
	// As the minimum collateral ratio defaults to 110% any excess WBTC/WETH that is not swapped for USDS will remain in this contract - in the case
    // that future liquidated positions are undercollateralized during times of high market volatility and the WBTC/WETH is needed to purchase more USDS to burn.
	function _performUpkeep() internal override
		{
		if ( usdsThatShouldBeBurned == 0 )
			return;

		// See if there is enough USDS in this contract to burn - if so, just burn that
		uint256 usdsBalance = balanceOf( address(this) );

		if ( usdsBalance >= usdsThatShouldBeBurned )
			{
			_burn( address(this), usdsThatShouldBeBurned );

			usdsThatShouldBeBurned = 0;
			return;
			}

		// Cached for efficiency
		uint256 percentSwapToUSDS = stableConfig.percentSwapToUSDS();
		uint256 maximumLiquidationSlippagePercentTimes1000 = stableConfig.maximumLiquidationSlippagePercentTimes1000();

		// Prices will be used to determine minimum amountOuts
		IPriceFeed priceFeed = stableConfig.priceFeed();
		uint256 btcPrice = priceFeed.getPriceBTC();
        uint256 ethPrice = priceFeed.getPriceETH();

		// Swap a percent of the WBTC and WETH in the contract for USDS
		_swapPercentOfTokenForUSDS( wbtc, btcPrice, percentSwapToUSDS, maximumLiquidationSlippagePercentTimes1000 );
		_swapPercentOfTokenForUSDS( weth, ethPrice, percentSwapToUSDS, maximumLiquidationSlippagePercentTimes1000 );

		// See how much USDS we have now
		usdsBalance = balanceOf( address(this) );

		// Enough USDS now to burn?
		if ( usdsBalance >= usdsThatShouldBeBurned )
			{
			_burn( address(this), usdsThatShouldBeBurned );

			usdsThatShouldBeBurned = 0;
			return;
			}

		// Not enough USDS to burn - just burn the current balance and update usdsThatShouldBeBurned
		_burn( address(this), usdsBalance );
		usdsThatShouldBeBurned -= usdsBalance;
		}
	}

