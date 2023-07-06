//// SPDX-License-Identifier: BSL 1.1
//pragma solidity ^0.8.12;
//
//import "../openzeppelin/token/ERC20/IERC20.sol";
//import "../openzeppelin/token/ERC20/ERC20.sol";
//import "../openzeppelin/token/ERC20/utils/SafeERC20.sol";
//import "../uniswap/core/interfaces/IUniswapV2Pair.sol";
//import "../uniswap/periphery/interfaces/IUniswapV2Router02.sol";
//import "./USDS.sol";
//import "./interfaces/ILiquidator.sol";
//import "./interfaces/ICollateral.sol";
//import "../Upkeepable.sol";
//import "../stable/interfaces/IStableConfig.sol";
//import "../interfaces/IExchangeConfig.sol";
//
//
//// @title Liquidator
//// @notice Liquidates the BTC/ETH LP within the contract for USDS (which is burnt) with extra sent to POL_Optimizer as WETH to create Protocol Owned Liquidity.
//
//contract Liquidator is ILiquidator, Upkeepable
//	{
//	using SafeERC20 for IERC20;
//
//	// The maximum USDS amount that can be swapped for in any one swap
//	uint256 public MAXIMUM_USDS_SWAP_SIZE = 250000 ether;
//
//	// When swapping BTC->USDS or ETH->USDS the maximum percent difference compared to the PriceFeed
//    uint256 public MAXIMUM_SLIPPAGE_PERCENT_TIMES_1000 = 3000;
//
//	// Default addresses on Polygon
//	// These can be set in the constructor to facilitate unit testing
//	IERC20 public wbtc;  // 0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6
//	IERC20 public weth; // 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619
//	USDS public usds;
//
//	uint256 public wbtcDecimals;
//	uint256 public wethDecimals;
//
//	// The BTC/ETH LP token which should be liquidated
//	IUniswapV2Pair public collateralLP;
//
//	// The Salty.IO Uniswap v2 router
//	IUniswapV2Router02 public router;
//
//	// The  Collateral contract which can increase the value of usdsToBurn
//	ICollateral public collateral;
//
//	IExchangeConfig public exchangeConfig;
//	IStableConfig public stableConfig;
//
//	// The amount of USDS that is pending to the burned as the result of liquidated collateral positions
//	uint256 public usdsToBurn;
//
//
//	constructor( IUniswapV2Pair _collateralLP, IUniswapV2Router02 _router, ICollateral _collateral, IStableConfig _stableConfig, IExchangeConfig _exchangeConfig )
//		{
//		wbtc = IERC20(_exchangeConfig.wbtc());
//		weth = IERC20(_exchangeConfig.weth());
//		usds = USDS(_exchangeConfig.usds());
//
//		wbtcDecimals = ERC20(address(wbtc)).decimals();
//		wethDecimals = ERC20(address(weth)).decimals();
//
//		collateralLP = _collateralLP;
//		router = _router;
//
//        wbtc.approve( address(router), type(uint256).max );
//        weth.approve( address(router), type(uint256).max );
//        usds.approve( address(router), type(uint256).max );
//
//        collateral = _collateral;
//        exchangeConfig = _exchangeConfig;
//        stableConfig = _stableConfig;
//		}
//
//
//	function increaseUSDSToBurn( uint256 amountToBurnLater ) public
//		{
//		// Only allow the collateral contract to increase the amount of USDS that will need to be burned to offset liquidations
//		require( msg.sender == address(collateral), "Not the Collateral contract" );
//
//		usdsToBurn = usdsToBurn + amountToBurnLater;
//		}
//
//
//	// Liquidates all collateralLP held in the contract (which would have been sent previously on Collateral.liquidate calls).
//	// USDS that was previously borrowed is burned and usdsToBurn is adjusted.
//	// Extra USDS is converted to WETH and sent to the POL_Optimizer to later create Protocol Owned Liquidity for the DAO
//	function _performUpkeep() internal override
//		{
//		if ( usdsToBurn == 0 )
//			return;
//
//		// Get the contract's balance of collateralLP tokens
//		uint256 collateralBalance = collateralLP.balanceOf( address(this) );
//		if ( collateralBalance == 0 )
//			return;
//
//		// Break the LP into BTC and ETH
//		(IERC20(address(collateralLP))).safeTransfer( address(collateralLP), collateralBalance );
//		(uint256 wbtcAmountRecovered, uint256 wethAmountRecovered) = collateralLP.burn( address(this) );
//
//		// The amount of USDS that needs to be swapped for will ideally be half of what needs to be burned
//		// Half in WBTC->USDS and half in WETH->USDS
//		uint256 usdsToSwapFor = usdsToBurn / 2;
//
//		// Limit the amount of USDS that will potentially be swapped for
//		if ( usdsToSwapFor > MAXIMUM_USDS_SWAP_SIZE )
//			usdsToSwapFor = MAXIMUM_USDS_SWAP_SIZE;
//
//		// Determine the maximum amount of WBTC and WETH that need to be swapped for USDS
//		address[] memory path1 = new address[](2);
//		path1[0] = address(wbtc);
//		path1[1] = address(usds);
//
//		address[] memory path2 = new address[](2);
//		path2[0] = address(weth);
//		path2[1] = address(usds);
//
//
//		uint256 wbtcIn = router.getAmountsIn( usdsToSwapFor, path1 )[0];
//		uint256 wethIn = router.getAmountsIn( usdsToSwapFor, path2 )[0];
//
//		// Can't swap more than what we recovered from liquidity
//		if ( wbtcIn > wbtcAmountRecovered )
//			wbtcIn = wbtcAmountRecovered;
//		if ( wethIn > wethAmountRecovered )
//			wethIn = wethAmountRecovered;
//
//		// Make sure the swaps are within maximum slippage
//		uint256 minWBTC_USDS = ( wbtcIn * stableConfig.priceFeed().getPriceBTC() ) / 10 ** 18;
//		uint256 minWETH_USDS = ( wethIn * stableConfig.priceFeed().getPriceETH() ) /  10 ** 18;
//		minWBTC_USDS = minWBTC_USDS - minWBTC_USDS * MAXIMUM_SLIPPAGE_PERCENT_TIMES_1000 / ( 100 * 1000 );
//		minWETH_USDS = minWETH_USDS - minWETH_USDS * MAXIMUM_SLIPPAGE_PERCENT_TIMES_1000 / ( 100 * 1000 );
//
//		uint256 outWBTC_USDS = router.getAmountsOut( wbtcIn, path1)[1];
//		uint256 outWETH_USDS = router.getAmountsOut( wethIn, path2)[1];
//
//		if ( outWBTC_USDS >= minWBTC_USDS )
//			router.swapExactTokensForTokens(wbtcIn, 0, path1, address(this), block.timestamp);
//
//		if ( outWETH_USDS >= minWETH_USDS )
//			router.swapExactTokensForTokens(wethIn, 0, path2, address(this), block.timestamp);
//
//		// Burn any USDS in the contract
//		uint256 usdsBalance = usds.balanceOf( address(this) );
//		if ( usdsBalance > 0 )
//			{
//			// Send the tokens to burn to the USDS contract itself
//			(IERC20(address(usds))).safeTransfer(address(usds), usdsBalance);
//			usds.burnTokensInContract();
//
//			// Reduce the number of tokens that need to be burned
//			if ( usdsBalance > usdsToBurn )
//				usdsToBurn = 0;
//			else
//				usdsToBurn = usdsToBurn - usdsBalance;
//			}
//
//		// Convert any remaining WBTC to WETH
//		uint256 wbtcBalance = wbtc.balanceOf( address(this) );
//		if ( wbtcBalance > 0 )
//			{
//			address[] memory path3 = new address[](2);
//			path3[0] = address(wbtc);
//			path3[1] = address(weth);
//
//			router.swapExactTokensForTokens( wbtcBalance, 0, path3, address(this), block.timestamp);
//			}
//
//		// Send all WETH to the POL_Optimizer
//		uint256 wethBalance = weth.balanceOf( address(this) );
//		if ( wethBalance > 0 )
//			weth.transfer( address(exchangeConfig.optimizer()), wethBalance );
//		}
//	}