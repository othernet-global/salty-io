// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "forge-std/Test.sol";
import "../dev/Deployment.sol";
import "./TestERC20.sol";


contract TestSandwichAttacks is Deployment
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


	function _sandwich(uint256 sandwichSize, uint256 rA0, uint256 rA1, uint256 rB0, uint256 rB1, uint256 rC0, uint256 rC1 ) public returns (uint256 amountOut, uint256 backrunOut, uint256 arbProfit)
		{
		init(rA0, rA1, rB0, rB1, rC0, rC1);

		vm.startPrank(DEPLOYER);

		// Frontrun
		uint256 frontrunOut = pools.depositSwapWithdraw( weth, dai, sandwichSize * 1 ether, 0, block.timestamp );

		// User swap
		amountOut = pools.depositSwapWithdraw( weth, dai, 10 ether, 0, block.timestamp );

		// Backrun
		backrunOut = pools.depositSwapWithdraw( dai, weth, frontrunOut, 0, block.timestamp );

		arbProfit = pools.depositedUserBalance(address(dao), weth );

		vm.stopPrank();
		}


	// Front running looks to be significantly discouraged by the arbitrage process.
	// Especially for swaps smaller than 1% of the reserves the frontrunner has to deal with their initial swap being offset by arbitrage (putting them at an initial loss if they want to trade back).
	// The extra swaps placed by sandwich attacks generate extra arbitrage profits for the protocol as well.
	function _simulate(uint256 rA0, uint256 rA1, uint256 rB0, uint256 rB1, uint256 rC0, uint256 rC1) public
		{
		uint256 baseAmountOut;
		int256 maxSandwichProfit;
		uint256 maxAmountOut;
		uint256 maxArbProfit;

		// Find the most profitable sandwich attack
		for( uint256 i = 0; i < 100; i++ )
			{
			(uint256 amountOut, uint256 backrunOut, uint256 arbProfit) = _sandwich(i, rA0, rA1, rB0, rB1, rC0, rC1);

		//	console.log( i, amountOut / 1 ether, backrunOut, arbProfit );

			if ( i==0 )
				baseAmountOut = amountOut;

			int256 sandwichProfit  = int256(backrunOut) - int256(1 ether * i );
			if ( sandwichProfit > maxSandwichProfit )
				{
				maxSandwichProfit = sandwichProfit;
				maxAmountOut = amountOut;
				maxArbProfit = arbProfit;
				}
			}

		if ( (maxAmountOut + maxArbProfit * 3000 ) > baseAmountOut )
			console.log( "swap/arbitrage: +", ( (maxAmountOut + maxArbProfit * 3000 ) - baseAmountOut) / 1 ether  );
		else
			console.log( "swap/arbitrage: -", (baseAmountOut - (maxAmountOut + maxArbProfit * 3000 ) ) / 1 ether );

		if ( maxSandwichProfit > 0 )
			console.log( "sandwich: +", (uint256(maxSandwichProfit) * 3000 ) / 1 ether );
		else
			console.log( "sandwich: -", (uint256(maxSandwichProfit) * 3000 ) / 1 ether );
		}


	// Sandwich simulator will have the user swap 10 WETH -> DAI
	// The impact of the best found sandwich impact on the swap is reported
	// The WETH/DAI reserves can be adjusted to make the user swap a larger or smaller percentage of the reserves
	// The WBTC/DAI reserves can be adjusted in size
	// The WBTC/WETH reserves can be adjusted in size
	function testSandwich() public
		{
//		console.log( "\n1% of reserves being swapped by user" );
//		console.log( "WBTC/DAI reserves 1/2 the size of WETH/DAI" );
//		console.log( "WBTC/WETH reserves 2x the size of WETH/DAI" ); // WBTC/WETH should generally be larger due to it acting as collateral for USDS
//		uint256 wethReserves = 1000 ether;
//		uint256 daiReserves = 3000000 ether; // $3000 base price for WETH, assume WBTC price of $30000
//		_simulate(wethReserves, daiReserves, (wethReserves / 2 ) / 10**10 / 10, daiReserves / 2, (wethReserves * 2) / 10**10 / 10, wethReserves *2 );
//
//		console.log( "\n.5% of reserves being swapped by user" );
//		console.log( "WBTC/DAI reserves 1/2 the size of WETH/DAI" );
//		console.log( "WBTC/WETH reserves 2x the size of WETH/DAI" ); // WBTC/WETH should generally be larger due to it acting as collateral for USDS
//		wethReserves = 2000 ether;
//		daiReserves = 6000000 ether; // $3000 base price for WETH, assume WBTC price of $30000
//		_simulate(wethReserves, daiReserves, (wethReserves / 2 ) / 10**10 / 10, daiReserves / 2, (wethReserves * 2) / 10**10 / 10, wethReserves *2 );
//
//		console.log( "\n1% of reserves being swapped by user" );
//		console.log( "WBTC/DAI reserves 1/2 the size of WETH/DAI" );
//		console.log( "WBTC/WETH reserves 5x the size of WETH/DAI" ); // WBTC/WETH should generally be larger due to it acting as collateral for USDS
//		wethReserves = 1000 ether;
//		daiReserves = 3000000 ether; // $3000 base price for WETH, assume WBTC price of $30000
//		_simulate(wethReserves, daiReserves, (wethReserves / 2 ) / 10**10 / 10, daiReserves / 2, (wethReserves * 5) / 10**10 / 10, wethReserves *5 );
//
//		console.log( "\n1% of reserves being swapped by user" );
//		console.log( "WBTC/DAI reserves 1x the size of WETH/DAI" );
//		console.log( "WBTC/WETH reserves 5x the size of WETH/DAI" ); // WBTC/WETH should generally be larger due to it acting as collateral for USDS
//		wethReserves = 1000 ether;
//		daiReserves = 3000000 ether; // $3000 base price for WETH, assume WBTC price of $30000
//		_simulate(wethReserves, daiReserves, (wethReserves / 1 ) / 10**10 / 10, daiReserves / 1, (wethReserves * 5) / 10**10 / 10, wethReserves *5 );
//
//		console.log( "\n1% of reserves being swapped by user" );
//		console.log( "WBTC/DAI reserves 1/4 the size of WETH/DAI" );
//		console.log( "WBTC/WETH reserves 1x the size of WETH/DAI" ); // WBTC/WETH should generally be larger due to it acting as collateral for USDS
//		wethReserves = 1000 ether;
//		daiReserves = 3000000 ether; // $3000 base price for WETH, assume WBTC price of $30000
//		_simulate(wethReserves, daiReserves, (wethReserves / 4 ) / 10**10 / 10, daiReserves / 4, (wethReserves * 1) / 10**10 / 10, wethReserves * 1 );
//
//		console.log( "\n1% of reserves being swapped by user" );
//		console.log( "WBTC/DAI reserves 1/2 the size of WETH/DAI" );
//		console.log( "WBTC/WETH reserves 10x the size of WETH/DAI" ); // WBTC/WETH should generally be larger due to it acting as collateral for USDS
//		wethReserves = 1000 ether;
//		daiReserves = 3000000 ether; // $3000 base price for WETH, assume WBTC price of $30000
//		_simulate(wethReserves, daiReserves, (wethReserves / 2 ) / 10**10 / 10, daiReserves / 2, (wethReserves * 10) / 10**10 / 10, wethReserves * 10 );
		}
    }
