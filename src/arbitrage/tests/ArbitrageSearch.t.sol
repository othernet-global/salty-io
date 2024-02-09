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

		// Brute force search from 1/100 to 10x of swapAmountInValueInETH
		int256 bestProfit = 0;
		for (uint256 i = 0; i < 1000; i++ )
			{
			uint256 amountIn = 	swapAmountInValueInETH * ( i + 1 ) / 100;

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




	// Fuzzes reserves and swapAmountInValueInETH with uint112s
	function testSearchMethods(uint256 swapAmountInValueInETH, uint256 reservesA0, uint256 reservesA1, uint256 reservesB0, uint256 reservesB1, uint256 reservesC0, uint256 reservesC1) public
		{
		swapAmountInValueInETH = swapAmountInValueInETH % type(uint112).max;
		reservesA0 = reservesA0 % type(uint112).max;
		reservesA1 = reservesA1 % type(uint112).max;
		reservesB0 = reservesB0 % type(uint112).max;
		reservesB1 = reservesB1 % type(uint112).max;
		reservesC0 = reservesC0 % type(uint112).max;
		reservesC1 = reservesC1 % type(uint112).max;

		uint256 bruteForceAmountIn = _bruteForceFindBestArbAmountIn(swapAmountInValueInETH, reservesA0, reservesA1, reservesB0, reservesB1, reservesC0, reservesC1);
		uint256 bestAmountIn = _bestArbitrageIn(reservesA0, reservesA1, reservesB0, reservesB1, reservesC0, reservesC1);

		uint256 diff;
		if ( bruteForceAmountIn > bestAmountIn )
			diff = bruteForceAmountIn - bestAmountIn;
		else
			diff = bestAmountIn - bruteForceAmountIn;

		if ( bruteForceAmountIn == 0 )
		if ( bestAmountIn == 0 )
			return;

		uint256 percentDiffTimes1000 = diff * 100000 / ( bruteForceAmountIn + bestAmountIn ) / 2;

		// Ensure less than a 1% difference between answers
		assertTrue( percentDiffTimes1000 < 100000, "Divergent results" );
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
                }

				uint256 bestExact;
				unchecked
					{
					uint256 gas0 = gasleft();
                	bestExact = _bestArbitrageIn(reservesA0, reservesA1, auxReservesB0, auxReservesB1, reservesC0, reservesC1);
					console.log( "BEST GAS: ", gas0 - gasleft() );
					}

                console.log("Best arbitrage computation: ", bestExact);
                uint256 bestExactProfit = getArbitrageProfit(bestExact, reservesA0, reservesA1, auxReservesB0, auxReservesB1, reservesC0, reservesC1);
                console.log("Best arbitrage profit: ", bestExactProfit);

				// Assumes an ETH price of $2300
                console.log("PROFIT IMPROVEMENT (in USD cents): ", 2300 * (bestExactProfit - bestApproxProfit) / 10 ** 16);
            }
        }


	function testArbitrageMethodsLarge() public {
			uint256 mult = 1000000000; // 1 billion mult

            // Initial, roughly balanced pools
            // 18 ETH ~ 1 BTC ~ 40k TOKEN A
            uint256 reservesA0 = mult * 900 ether; // 900 billion ETH
            uint256 reservesA1 = mult * 2000000 ether; // 2 quintillion TOKEN A
            uint256 reservesB0 = mult * 4000000 ether; // 4 quintillion TOKEN A
            uint256 reservesB1 = mult * 100 *10**8; // 100 billion BTC
            uint256 reservesC0 = mult * 500 *10**8; // 500 billion BTC
            uint256 reservesC1 = mult * 9000 ether; // 9 trillion ETH

            for (uint256 i = 0; i < 4; i++) {

                uint256 auxReservesB1;
                uint256 auxReservesB0;

				// Swap BTC for TOKEN A
				uint256 swapAmountInValueInBTC = 1000 *10**8 * (i + 1);  // Arbitrary value for test
				auxReservesB1 = reservesB1 + swapAmountInValueInBTC;
				auxReservesB0 = reservesB0 - reservesB0 * swapAmountInValueInBTC / auxReservesB1;

				uint256 bestExact = _bestArbitrageIn(reservesA0, reservesA1, auxReservesB0, auxReservesB1, reservesC0, reservesC1);
				assertTrue( bestExact != 0, "Arbitrage calculation overflow" );

//                uint256 bestExactProfit = getArbitrageProfit(bestExact, reservesA0, reservesA1, auxReservesB0, auxReservesB1, reservesC0, reservesC1);
//                console.log( "BEST PROFIT: ", bestExactProfit );
            }
        }




	// Test binarysearch at max reserves
	// Actual reserves in Salty.IO would not exceed uint112
	// This would allow for tokens with 18 decimals and 5 quadrillion tokens max supply
	function testMaxReserves() public pure
		{
		_bruteForceFindBestArbAmountIn(type(uint112).max, type(uint112).max, type(uint112).max, type(uint112).max, type(uint112).max, type(uint112).max, type(uint112).max);
		_bestArbitrageIn(type(uint112).max, type(uint112).max, type(uint112).max, type(uint112).max, type(uint112).max, type(uint112).max);
		}
	}
