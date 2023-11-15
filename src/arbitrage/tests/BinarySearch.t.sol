// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "forge-std/Test.sol";
import "../../dev/Deployment.sol";
import "../../pools/PoolUtils.sol";


contract TestUnimodal is ArbitrageSearch, Test
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

		// Brute force search from 1/100 to 125 of swapAmountInValueInETH
		int256 bestProfit = 0;
		for (uint256 i = 0; i < 125; i++ )
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
	function testUnimodalHypothesis(uint112 swapAmountInValueInETH, uint112 reservesA0, uint112 reservesA1, uint112 reservesB0, uint112 reservesB1, uint112 reservesC0, uint112 reservesC1) public
		{
		uint256 bruteForceAmountIn = _bruteForceFindBestArbAmountIn(swapAmountInValueInETH, reservesA0, reservesA1, reservesB0, reservesB1, reservesC0, reservesC1);
		uint256 binarySearchAmountIn = _binarySearch(swapAmountInValueInETH, reservesA0, reservesA1, reservesB0, reservesB1, reservesC0, reservesC1);

		uint256 diff;
		if ( bruteForceAmountIn > binarySearchAmountIn )
			diff = bruteForceAmountIn - binarySearchAmountIn;
		else
			diff = binarySearchAmountIn - bruteForceAmountIn;

		if ( bruteForceAmountIn == 0 )
		if ( binarySearchAmountIn == 0 )
			return;

		uint256 percentDiffTimes1000 = diff * 100000 / ( bruteForceAmountIn + binarySearchAmountIn ) / 2;

		// Less than a 1% difference between answers
		assertTrue( percentDiffTimes1000 < 100000, "Divergent results" );
		}



	// Test binarysearch at max reserves
	// Actual reserves in Salty.IO would not exceed uint112
	// This would allow for tokens with 18 decimals and 5 quadrillion tokens max supply
	function testMaxReserves() public pure
		{
		_bruteForceFindBestArbAmountIn(type(uint112).max, type(uint112).max, type(uint112).max, type(uint112).max, type(uint112).max, type(uint112).max, type(uint112).max);
		_binarySearch(type(uint112).max, type(uint112).max, type(uint112).max, type(uint112).max, type(uint112).max, type(uint112).max, type(uint112).max);
		}
	}
