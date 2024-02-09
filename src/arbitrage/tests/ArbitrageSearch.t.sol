// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "forge-std/Test.sol";
import "../../dev/Deployment.sol";
import "../../pools/PoolUtils.sol";


contract TestArbitrageSearch is ArbitrageSearch, Test
	{
	Deployment deployment = new Deployment();

	constructor()
	ArbitrageSearch(deployment.exchangeConfig())
		{
		}


	function _bruteForceFindBestArbAmountIn(uint256 swapAmountInValueInETH, uint256 reservesA0, uint256 reservesA1, uint256 reservesB0, uint256 reservesB1, uint256 reservesC0, uint256 reservesC1) public pure returns (uint256 bestArbAmountIn)
		{
		if ( reservesA0 <= PoolUtils.DUST || reservesA1 <= PoolUtils.DUST || reservesB0 <= PoolUtils.DUST || reservesB1 <= PoolUtils.DUST || reservesC0 <= PoolUtils.DUST || reservesC1 <= PoolUtils.DUST )
			return 0;

		// Brute force search from 1/1000 to 125 of swapAmountInValueInETH
		int256 bestProfit = 0;
		for (uint256 i = 0; i < 1250; i++ )
			{
			uint256 amountIn = 	swapAmountInValueInETH * ( i + 1 ) / 1000;

			uint256 amountOut = (reservesA1 * amountIn) / (reservesA0 + amountIn);
			amountOut = (reservesB1 * amountOut) / (reservesB0 + amountOut);
			amountOut = (reservesC1 * amountOut) / (reservesC0 + amountOut);

			int256 profit = int256(amountOut) - int256(amountIn);
			if ( profit > bestProfit)
				{
				bestProfit = profit;
				bestArbAmountIn = amountIn;
				}
			}
		}



//
//	// Fuzzes reserves and swapAmountInValueInETH with uint112s
//	function testSearchMethods(uint256 swapAmountInValueInETH, uint256 reservesA0, uint256 reservesA1, uint256 reservesB0, uint256 reservesB1, uint256 reservesC0, uint256 reservesC1) public
//		{
//		swapAmountInValueInETH = swapAmountInValueInETH % type(uint112).max;
//		reservesA0 = reservesA0 % type(uint112).max;
//		reservesA1 = reservesA1 % type(uint112).max;
//		reservesB0 = reservesB0 % type(uint112).max;
//		reservesB1 = reservesB1 % type(uint112).max;
//		reservesC0 = reservesC0 % type(uint112).max;
//		reservesC1 = reservesC1 % type(uint112).max;
//
//		uint256 bruteForceAmountIn = _bruteForceFindBestArbAmountIn(swapAmountInValueInETH, reservesA0, reservesA1, reservesB0, reservesB1, reservesC0, reservesC1);
//		uint256 binarySearchAmountIn = _bisectionSearch(swapAmountInValueInETH, reservesA0, reservesA1, reservesB0, reservesB1, reservesC0, reservesC1);
////		uint256 bestAmountIn = _computeBestArbitrage(reservesA0, reservesA1, reservesB0, reservesB1, reservesC0, reservesC1);
//
//		uint256 diff;
//		if ( bruteForceAmountIn > binarySearchAmountIn )
//			diff = bruteForceAmountIn - binarySearchAmountIn;
//		else
//			diff = binarySearchAmountIn - bruteForceAmountIn;
//
////		uint256 diff2;
////		if ( bruteForceAmountIn > bestAmountIn )
////			diff2 = bruteForceAmountIn - bestAmountIn;
////		else
////			diff2 = bestAmountIn - bruteForceAmountIn;
//
//		if ( bruteForceAmountIn == 0 )
//		if ( binarySearchAmountIn == 0 )
//			return;
//
//		uint256 percentDiffTimes1000 = diff * 100000 / ( bruteForceAmountIn + binarySearchAmountIn ) / 2;
//
//		// Less than a 1% difference between answers
//		assertTrue( percentDiffTimes1000 < 100000, "Divergent results" );
//
//
//
////		if ( bruteForceAmountIn == 0 )
////		if ( bestAmountIn == 0 )
////			return;
////
////		percentDiffTimes1000 = diff2 * 100000 / ( bruteForceAmountIn + bestAmountIn ) / 2;
////
////		// Less than a 1% difference between answers
////		assertTrue( percentDiffTimes1000 < 100000, "Divergent results 2" );
//		}



	function _computeBestArbitrage( uint256 A0, uint256 A1, uint256 B0, uint256 B1, uint256 C0, uint256 C1 ) public pure returns (uint256 bestArbAmountIn)
		{
		// Original derivation: https://github.com/code-423n4/2024-01-salty-findings/issues/419
		// n0 = A0 * B0 * C0
		// n1 = A1 * B1 * C1
		//
		// m = A1 * B1 + C0 * B0 + C0 * A1
		// z = sqrt(A0 * C1) * sqrt(A1 * B0) * sqrt(B1 * C0)
		//
		// bestArbAmountIn = ( z - n0 ) / m;

		// Prevent A0*B0*C0 and A1*B1*C1 full calculations to reduce overflow risk
		uint256 sqrt_n0 = Math.sqrt(A0 * B0) * Math.sqrt(C0);
		uint256 sqrt_n1 = Math.sqrt(A1 * B1) * Math.sqrt(C1);
		if (sqrt_n1 <= sqrt_n0)
			return 0;

		uint256 m = A1 * ( B1 + C0 ) + C0 * B0;
		uint256 z = sqrt_n0 * sqrt_n1;
		uint256 sqrt_k = sqrt_n0 / Math.sqrt(m);

		bestArbAmountIn = z / m - sqrt_k * sqrt_k;

		// Make sure bestArbAmountIn is actually profitable
		uint256 amountOut = (A1 * bestArbAmountIn) / (A0 + bestArbAmountIn);
		amountOut = (B1 * amountOut) / (B0 + amountOut);
		amountOut = (C1 * amountOut) / (C0 + amountOut);

		if ( ( int256(amountOut) - int256(bestArbAmountIn) ) < int256(PoolUtils.DUST) )
			return 0;
		}


	function getArbitrageProfit(uint256 arbitrageAmountIn, uint256 reservesA0, uint256 reservesA1, uint256 reservesB0, uint256 reservesB1, uint256 reservesC0, uint256 reservesC1) public pure returns (uint256 arbitrageProfit)
		{
		uint256 amountOut = reservesA1 * arbitrageAmountIn / (reservesA0 + arbitrageAmountIn);
		amountOut = reservesB1 * amountOut / (reservesB0 + amountOut);
		amountOut = reservesC1 * amountOut / (reservesC0 + amountOut);
		arbitrageProfit = amountOut - arbitrageAmountIn;
		}


	function testArbitrageMethods() public view {
            // Initial, roughly balanced pools
            // 18 ETH ~ 1 BTC ~ 40k TOKEN A
            uint256 reservesA0 = 900 ether; // ETH
            uint256 reservesA1 = 2000000 ether; // TOKEN A
            uint256 reservesB0 = 4000000 ether; // TOKEN A
            uint256 reservesB1 = 100 ether; // BTC
            uint256 reservesC0 = 500 ether; // BTC
            uint256 reservesC1 = 9000 ether; // ETH

            for (uint256 i = 0; i < 4; i++) {

                console.log("");

                uint256 bestApproxProfit;
                uint256 auxReservesB1;
                uint256 auxReservesB0;

                {
                    // Swap BTC for TOKEN A
                    uint256 swapAmountInValueInBTC = 1 ether * (i + 1);  // Arbitrary value for test
                    console.log(i, "- swap", swapAmountInValueInBTC / 10 ** 18, "BTC for TOKEN A");
                    auxReservesB1 = reservesB1 + swapAmountInValueInBTC;
                    auxReservesB0 = reservesB0 - reservesB0 * swapAmountInValueInBTC / auxReservesB1;

					uint256 gas0 = gasleft();
                    uint256 bestBrute = _bruteForceFindBestArbAmountIn(swapAmountInValueInBTC / 18, reservesA0, reservesA1, auxReservesB0, auxReservesB1, reservesC0, reservesC1);
					console.log( "BRUTE GAS: ", gas0 - gasleft() );

                    console.log("Original brute arbitrage estimation: ", bestBrute);
                    bestApproxProfit = getArbitrageProfit(bestBrute, reservesA0, reservesA1, auxReservesB0, auxReservesB1, reservesC0, reservesC1);
                    console.log("Brute arbitrage profit: ", bestApproxProfit);

					gas0 = gasleft();
                    uint256 bisectionEstimate = _bisectionSearch(swapAmountInValueInBTC / 18, reservesA0, reservesA1, auxReservesB0, auxReservesB1, reservesC0, reservesC1);
					console.log( "BISECTION GAS: ", gas0 - gasleft() );

                    console.log("Bisection arbitrage estimation: ", bisectionEstimate);
                    bestApproxProfit = getArbitrageProfit(bisectionEstimate, reservesA0, reservesA1, auxReservesB0, auxReservesB1, reservesC0, reservesC1);
                    console.log("Bisection arbitrage profit: ", bestApproxProfit);
                }

				uint256 bestExact;
				unchecked
					{
					uint256 gas0 = gasleft();
                	bestExact = _computeBestArbitrage(reservesA0, reservesA1, auxReservesB0, auxReservesB1, reservesC0, reservesC1);
					console.log( "BEST GAS: ", gas0 - gasleft() );
					}

                console.log("Best arbitrage computation: ", bestExact);
                uint256 bestExactProfit = getArbitrageProfit(bestExact, reservesA0, reservesA1, auxReservesB0, auxReservesB1, reservesC0, reservesC1);
                console.log("Best arbitrage profit: ", bestExactProfit);

				// Assumes an ETH price of $2300
                console.log("PROFIT IMPROVEMENT (in USD cents): ", 2300 * (bestExactProfit - bestApproxProfit) / 10 ** 16);
            }
        }




	// Test binarysearch at max reserves
	// Actual reserves in Salty.IO would not exceed uint112
	// This would allow for tokens with 18 decimals and 5 quadrillion tokens max supply
	function testMaxReserves() public pure
		{
		_bruteForceFindBestArbAmountIn(type(uint112).max, type(uint112).max, type(uint112).max, type(uint112).max, type(uint112).max, type(uint112).max, type(uint112).max);
		_bisectionSearch(type(uint112).max, type(uint112).max, type(uint112).max, type(uint112).max, type(uint112).max, type(uint112).max, type(uint112).max);

		// check _computeBestArbitrage for overflow
		_computeBestArbitrage(type(uint112).max, type(uint112).max, type(uint112).max, type(uint112).max, type(uint112).max, type(uint112).max);
		}




	}
