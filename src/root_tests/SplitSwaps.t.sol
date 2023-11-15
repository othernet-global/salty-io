// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "forge-std/Test.sol";
import "../dev/Deployment.sol";
import "./TestERC20.sol";


contract TestSplitSwaps is Deployment
	{
	function init(uint256 rA0, uint256 rA1, uint256 rB0, uint256 rB1, uint256 rC0, uint256 rC1) public
		{
		// Fresh simulation
		initializeContracts();

		grantAccessDeployer();

		finalizeBootstrap();

		vm.startPrank(DEPLOYER);

		dai.approve(address(collateralAndLiquidity), type(uint256).max );
		weth.approve(address(collateralAndLiquidity), type(uint256).max );
		wbtc.approve(address(collateralAndLiquidity), type(uint256).max );

		dai.approve(address(pools), type(uint256).max );
		weth.approve(address(pools), type(uint256).max );
		wbtc.approve(address(pools), type(uint256).max );

		collateralAndLiquidity.depositLiquidityAndIncreaseShare( weth, dai, rA0, rA1, 0, block.timestamp, false );
		collateralAndLiquidity.depositLiquidityAndIncreaseShare( wbtc, dai, rB0, rB1, 0, block.timestamp, false );
		collateralAndLiquidity.depositCollateralAndIncreaseShare(rC0, rC1, 0, block.timestamp, false );
		vm.stopPrank();
		}


	// Check to see what the difference in swapAmountOut is being a large swap versus smaller ones
	function testLargeVersusSmallSwaps() public
		{
//		uint256 wethReserves = 1000 ether;
//		uint256 daiReserves = 3000000 ether; // $3000 base price for WETH, assume WBTC price of $30000
//		init(wethReserves, daiReserves, (wethReserves / 2 ) / 10**10 / 10, daiReserves / 2, (wethReserves * 5) / 10**10 / 10, wethReserves *5 );
//
//		vm.prank(DEPLOYER);
//		uint256 amountOut0 = pools.depositSwapWithdraw( weth, dai, 10 ether, 0, block.timestamp, true);
//		console.log( "amountOut0: ", amountOut0 );
//
//		init(wethReserves, daiReserves, (wethReserves / 2 ) / 10**10 / 10, daiReserves / 2, (wethReserves * 5) / 10**10 / 10, wethReserves *5 );
//
//		uint256 amountOut;
//
//		vm.startPrank(DEPLOYER);
//		for( uint256 i = 0; i < 10; i++ )
//		 	amountOut += pools.depositSwapWithdraw( weth, dai, 1 ether, 0, block.timestamp, true);
//
//		console.log( "amountOut: ", amountOut );
		}
    }
