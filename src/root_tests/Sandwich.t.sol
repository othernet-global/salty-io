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

		usdc.approve(address(liquidity), type(uint256).max );
		weth.approve(address(liquidity), type(uint256).max );
		wbtc.approve(address(liquidity), type(uint256).max );

		usdc.approve(address(pools), type(uint256).max );
		weth.approve(address(pools), type(uint256).max );
		wbtc.approve(address(pools), type(uint256).max );

		liquidity.depositLiquidityAndIncreaseShare( weth, usdc, rA0, rA1, 0, 0, 0, block.timestamp, false );
		liquidity.depositLiquidityAndIncreaseShare( usdc, wbtc, rB0, rB1, 0, 0, 0, block.timestamp, false );
		liquidity.depositLiquidityAndIncreaseShare(wbtc, weth, rC0, rC1, 0, 0, 0, block.timestamp, false );
		vm.stopPrank();
		}


	function _sandwich(uint256 sandwichSize, uint256 rA0, uint256 rA1, uint256 rB0, uint256 rB1, uint256 rC0, uint256 rC1 ) public returns (uint256 amountOut, uint256 backrunOut, uint256 arbProfit)
		{
		init(rA0, rA1, rB0, rB1, rC0, rC1);

		vm.startPrank(DEPLOYER);

		// Frontrun
		uint256 frontrunOut = pools.depositSwapWithdraw( usdc, weth, sandwichSize, 0, block.timestamp );
//		console.log( "FRONTRUN OUT: ", frontrunOut );

		// User swap
		amountOut = pools.depositSwapWithdraw( usdc, weth, 5000 * 10**6, 0, block.timestamp );

		// Backrun
		backrunOut = pools.depositSwapWithdraw(  weth, usdc, frontrunOut, 0, block.timestamp );
//		console.log( "BACKRUN OUT: ", backrunOut );

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
//		_simulate(400 ether, 1000000 *10**6, 25 *10**8, 1000000 *10**6, 25 *10**8, 400 ether );


//		console.log( "\n1% of reserves being swapped by user" );
//		console.log( "WBTC/DAI reserves 1/2 the size of WETH/DAI" );
//		console.log( "WBTC/WETH reserves 2x the size of WETH/DAI" ); // WBTC/WETH should generally be larger due to it acting as collateral for USDC
//		uint256 wethReserves = 1000 ether;
//		uint256 usdcReserves = 3000000 ether; // $3000 base price for WETH, assume WBTC price of $30000
//		_simulate(wethReserves, usdcReserves, (wethReserves / 2 ) / 10**10 / 10, usdcReserves / 2, (wethReserves * 2) / 10**10 / 10, wethReserves *2 );
//
//		console.log( "\n.5% of reserves being swapped by user" );
//		console.log( "WBTC/DAI reserves 1/2 the size of WETH/DAI" );
//		console.log( "WBTC/WETH reserves 2x the size of WETH/DAI" ); // WBTC/WETH should generally be larger due to it acting as collateral for USDC
//		wethReserves = 2000 ether;
//		usdcReserves = 6000000 ether; // $3000 base price for WETH, assume WBTC price of $30000
//		_simulate(wethReserves, usdcReserves, (wethReserves / 2 ) / 10**10 / 10, usdcReserves / 2, (wethReserves * 2) / 10**10 / 10, wethReserves *2 );
//
//		console.log( "\n1% of reserves being swapped by user" );
//		console.log( "WBTC/DAI reserves 1/2 the size of WETH/DAI" );
//		console.log( "WBTC/WETH reserves 5x the size of WETH/DAI" ); // WBTC/WETH should generally be larger due to it acting as collateral for USDC
//		wethReserves = 1000 ether;
//		usdcReserves = 3000000 ether; // $3000 base price for WETH, assume WBTC price of $30000
//		_simulate(wethReserves, usdcReserves, (wethReserves / 2 ) / 10**10 / 10, usdcReserves / 2, (wethReserves * 5) / 10**10 / 10, wethReserves *5 );
//
//		console.log( "\n1% of reserves being swapped by user" );
//		console.log( "WBTC/DAI reserves 1x the size of WETH/DAI" );
//		console.log( "WBTC/WETH reserves 5x the size of WETH/DAI" ); // WBTC/WETH should generally be larger due to it acting as collateral for USDC
//		wethReserves = 1000 ether;
//		usdcReserves = 3000000 ether; // $3000 base price for WETH, assume WBTC price of $30000
//		_simulate(wethReserves, usdcReserves, (wethReserves / 1 ) / 10**10 / 10, usdcReserves / 1, (wethReserves * 5) / 10**10 / 10, wethReserves *5 );
//
//		console.log( "\n1% of reserves being swapped by user" );
//		console.log( "WBTC/DAI reserves 1/4 the size of WETH/DAI" );
//		console.log( "WBTC/WETH reserves 1x the size of WETH/DAI" ); // WBTC/WETH should generally be larger due to it acting as collateral for USDC
//		wethReserves = 1000 ether;
//		usdcReserves = 3000000 ether; // $3000 base price for WETH, assume WBTC price of $30000
//		_simulate(wethReserves, usdcReserves, (wethReserves / 4 ) / 10**10 / 10, usdcReserves / 4, (wethReserves * 1) / 10**10 / 10, wethReserves * 1 );
//
//		console.log( "\n1% of reserves being swapped by user" );
//		console.log( "WBTC/DAI reserves 1/2 the size of WETH/DAI" );
//		console.log( "WBTC/WETH reserves 10x the size of WETH/DAI" ); // WBTC/WETH should generally be larger due to it acting as collateral for USDC
//		wethReserves = 1000 ether;
//		usdcReserves = 3000000 ether; // $3000 base price for WETH, assume WBTC price of $30000
//		_simulate(wethReserves, usdcReserves, (wethReserves / 2 ) / 10**10 / 10, usdcReserves / 2, (wethReserves * 10) / 10**10 / 10, wethReserves * 10 );
		}


	// Determine the most significant bit of a non-zero number
    function _mostSignificantBit(uint256 x) internal pure returns (uint256 msb)
    	{
    	unchecked
    		{
			if (x >= 2**128) { x >>= 128; msb += 128; }
			if (x >= 2**64) { x >>= 64; msb += 64; }
			if (x >= 2**32) { x >>= 32; msb += 32; }
			if (x >= 2**16) { x >>= 16; msb += 16; }
			if (x >= 2**8) { x >>= 8; msb += 8; }
			if (x >= 2**4) { x >>= 4; msb += 4; }
			if (x >= 2**2) { x >>= 2; msb += 2; }
			if (x >= 2**1) { x >>= 1; msb += 1; }
			}
	    }


	// Determine the maximum msb across the given values
	function _maximumReservesMSB( uint256 A0, uint256 A1, uint256 B0, uint256 B1, uint256 C0, uint256 C1 ) internal pure returns (uint256 msb)
		{
		uint256 max = A0;
		if ( A1 > max )
			max = A1;
		if ( B0 > max )
			max = B0;
		if ( B1 > max )
			max = B1;
		if ( C0 > max )
			max = C0;
		if ( C1 > max )
			max = C1;

		return  _mostSignificantBit(max);
		}


	function _bestArbitrageIn( uint256 A0, uint256 A1, uint256 B0, uint256 B1, uint256 C0, uint256 C1 ) public pure returns (uint256 bestArbAmountIn)
		{
		// When actual swaps along the arbitrage path are executed - they can fail with insufficient reserves
		if ( A0 <= PoolUtils.DUST || A1 <= PoolUtils.DUST || B0 <= PoolUtils.DUST || B1 <= PoolUtils.DUST || C0 <= PoolUtils.DUST || C1 <= PoolUtils.DUST )
			return 0;

		// This can be unchecked as the actual arbitrage that is performed when this is non-zero is checked and duplicates the check for profitability.
		// testArbitrageMethodsLarge() checks for proper behavior with extremely large reserves as well.
		unchecked
			{
			// Original derivation: https://github.com/code-423n4/2024-01-salty-findings/issues/419
			// uint256 n0 = A0 * B0 * C0;
			//	uint256 n1 = A1 * B1 * C1;
			//	if (n1 <= n0) return 0;
			//
			//	uint256 m = A1 * B1 + C0 * B0 + C0 * A1;
			//	uint256 z = Math.sqrt(A0 * C1);
			//	z *= Math.sqrt(A1 * B0);
			//	z *= Math.sqrt(B1 * C0);
			//	bestArbAmountIn = (z - n0) / m;

			uint256 maximumMSB = _maximumReservesMSB( A0, A1, B0, B1, C0, C1 );

			// Assumes the largest number should use no more than 80 bits.
			// Multiplying three 80 bit numbers will yield 240 bits - within the 256 bit limit.
			uint256 shift = 0;
			if ( maximumMSB > 80 )
				{
				shift = maximumMSB - 80;

				A0 = A0 >> shift;
				A1 = A1 >> shift;
				B0 = B0 >> shift;
				B1 = B1 >> shift;
				C0 = C0 >> shift;
				C1 = C1 >> shift;
				}

			// Each variable will use less than 80 bits
			uint256 n0 = A0 * B0 * C0;
			uint256 n1 = A1 * B1 * C1;

			if (n1 <= n0)
				return 0;

			uint256 m = A1 *  B1 + C0 * ( B0 + A1 );

			// Calculating n0 * n1 directly would overflow under some situations.
			// Multiply the sqrt's instead - effectively keeping the max size the same
			uint256 z = Math.sqrt(n0) * Math.sqrt(n1);

			bestArbAmountIn = ( z - n0 ) / m;
			if ( bestArbAmountIn == 0 )
				return 0;

			// Convert back to normal scaling
			bestArbAmountIn = bestArbAmountIn << shift;

			// Needed for the below arbitrage profit testing
			A0 = A0 << shift;
			A1 = A1 << shift;
			B0 = B0 << shift;
			B1 = B1 << shift;
			C0 = C0 << shift;
			C1 = C1 << shift;

			// Make sure bestArbAmountIn arbitrage is actually profitable (or else it will revert when actually performed in Pools.sol)
			uint256 amountOut = (A1 * bestArbAmountIn) / (A0 + bestArbAmountIn);
			amountOut = (B1 * amountOut) / (B0 + amountOut);
			amountOut = (C1 * amountOut) / (C0 + amountOut);

			if ( amountOut < bestArbAmountIn )
				return 0;
			}
		}




	function testSandwich2() public
		{
//		for( uint256 i = 100; i < 10000; i = i + 100 )
//			{
//			uint256 sandwichAmountIn = i * 10**6;
//
//			// Initial pools for arbitrage
//			// 400 WETH, 1000000 USD
//			// 1000000 USD, 25 WBTC
//			// 25 WBTC, 400 WETH
//			(uint256 amountOut, uint256 backrunOut, uint256 arbProfit) = _sandwich(sandwichAmountIn, 400 ether, 1000000 *10**6, 1000000 *10**6, 25 *10**8, 25 *10**8, 400 ether );
//
//			if ( backrunOut > sandwichAmountIn )
//				console.log( i, "SANDWICH PROFIT: ", (backrunOut - sandwichAmountIn), amountOut );
//			else
//				console.log( i, "SANDWICH PROFIT: -", ( sandwichAmountIn - backrunOut), amountOut ) ;
//			}
		}
    }
