// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "../interfaces/IExchangeConfig.sol";
import "../pools/PoolUtils.sol";


// Finds a circular path after a user's swap has occurred (from WETH to WETH in this case) that results in an arbitrage profit.
abstract contract ArbitrageSearch
    {
	IERC20 immutable public wbtc;
	IERC20 immutable public weth;
	ISalt immutable public salt;

	// Used to estimate the point just to the right of the midpoint
   	uint256 constant public MIDPOINT_PRECISION = 0.001e18; // .001 ETH precision for arb search


    constructor( IExchangeConfig _exchangeConfig )
    	{
		// Cached for efficiency
		wbtc = _exchangeConfig.wbtc();
		weth = _exchangeConfig.weth();
		salt = _exchangeConfig.salt();
    	}


	// Returns the middle two tokens in an arbitrage path that starts and ends with WETH.
	// The WETH tokens at the beginning and end of the path are not returned as they are always the same.
	// Full arbitrage cycle is: WETH->arbToken2->arbToken3->WETH
	function _arbitragePath( IERC20 swapTokenIn, IERC20 swapTokenOut ) internal view returns (IERC20 arbToken2, IERC20 arbToken3)
		{
		// swap: WBTC->WETH
        // arb: WETH->WBTC->SALT->WETH
		if ( address(swapTokenIn) == address(wbtc))
		if ( address(swapTokenOut) == address(weth))
			return (wbtc, salt);

		// swap: WETH->WBTC
        // arb: WETH->SALT->WBTC->WETH
		if ( address(swapTokenIn) == address(weth))
		if ( address(swapTokenOut) == address(wbtc))
			return (salt, wbtc);

		// swap: WETH->swapTokenOut
        // arb: WETH->WBTC->swapTokenOut->WETH
		if ( address(swapTokenIn) == address(weth))
			return (wbtc, swapTokenOut);

		// swap: swapTokenIn->WETH
        // arb: WETH->swapTokenIn->WBTC->WETH
		if ( address(swapTokenOut) == address(weth))
			return (swapTokenIn, wbtc);

		// swap: swapTokenIn->swapTokenOut
        // arb: WETH->swapTokenOut->swapTokenIn->WETH
		return (swapTokenOut, swapTokenIn);
		}


	// Given the reserves for the arbitrage swap, determine if right of the midpoint looks to be more profitable than the midpoint itself.
	// Used as a substitution for the overly complex derivative in order to determine which direction the optimal arbitrage amountIn is more likely to be.
	function _rightMoreProfitable( uint256 midpoint, uint256 reservesA0, uint256 reservesA1, uint256 reservesB0, uint256 reservesB1, uint256 reservesC0, uint256 reservesC1 ) internal pure returns (bool rightMoreProfitable)
		{
		unchecked
			{
			// Calculate the AMM output of the midpoint
			uint256 amountOut = (reservesA1 * midpoint) / (reservesA0 + midpoint);
			amountOut = (reservesB1 * amountOut) / (reservesB0 + amountOut);
			amountOut = (reservesC1 * amountOut) / (reservesC0 + amountOut);

			int256 profitMidpoint = int256(amountOut) - int256(midpoint);

			// If the midpoint isn't profitable then we can remove the right half the range as nothing there will be profitable there either.
			if ( profitMidpoint < int256(PoolUtils.DUST) )
				return false;


			// Calculate the AMM output of a point just to the right of the midpoint
			midpoint += MIDPOINT_PRECISION;

			amountOut = (reservesA1 * midpoint) / (reservesA0 + midpoint);
			amountOut = (reservesB1 * amountOut) / (reservesB0 + amountOut);
			amountOut = (reservesC1 * amountOut) / (reservesC0 + amountOut);

			int256 profitRightOfMidpoint = int256(amountOut) - int256(midpoint);

			return profitRightOfMidpoint > profitMidpoint;
			}
		}


	// Perform iterative bisection to search for the bestArbAmountIn in a range of 1/128th to 125% of swapAmountInValueInETH.
	// The search loop determines profits at the midpoint of the current range, and also just to the right of the midpoint.
	// Assuming that the profit function is unimodal (has only one peak), the two profit calculations can show us which half of the range the maximum profit is in (where to keep looking).
	//
	// The unimodal assumption has been tested with fuzzing (see ArbitrageSearch.t.sol) and looks to return optimum bestArbAmountIn within 1% of a brute force search method for fuzzed uint112 size reserves.
	// Additionally, fuzzing and testing reveal that the non-overflow assumptions are valid if the assumption is made that reserves do not exceed uint112.max.
   	// The uint112 size would allow tokens with 18 decimals of precision and a 5 quadrillion max supply - which is excluded from the whitelist process.
   	// Additionally, for tokens that may increase total supply over time, these calculations are duplicated with overflow checking intact within Pools._arbitrage() when arbitrage actually occurs.
	function _bisectionSearch( uint256 swapAmountInValueInETH, uint256 reservesA0, uint256 reservesA1, uint256 reservesB0, uint256 reservesB1, uint256 reservesC0, uint256 reservesC1 ) internal pure returns (uint256 bestArbAmountIn)
		{
		// This code can safely be made unchecked as the functionality for the found bestArbAmountIn is duplicated exactly in Pools._arbitrage with overflow checks kept in place.
		// If any overflows occur as a result of the calculations here they will happen in the Pools._arbitrage code.
		unchecked
			{
			if ( reservesA0 <= PoolUtils.DUST || reservesA1 <= PoolUtils.DUST || reservesB0 <= PoolUtils.DUST || reservesB1 <= PoolUtils.DUST || reservesC0 <= PoolUtils.DUST || reservesC1 <= PoolUtils.DUST )
				return 0;

			// Search bestArbAmountIn in a range from 1/128th to 125% of swapAmountInValueInETH.
			uint256 leftPoint = swapAmountInValueInETH >> 7;
			uint256 rightPoint = swapAmountInValueInETH + (swapAmountInValueInETH >> 2); // 100% + 25% of swapAmountInValueInETH

			// Cost is about 492 gas per loop iteration
			for( uint256 i = 0; i < 8; i++ )
				{
				uint256 midpoint = (leftPoint + rightPoint) >> 1;

				// Right of midpoint is more profitable?
				if ( _rightMoreProfitable( midpoint, reservesA0, reservesA1, reservesB0, reservesB1, reservesC0, reservesC1 ) )
					leftPoint = midpoint;
				else
					rightPoint = midpoint;
				}

			bestArbAmountIn = (leftPoint + rightPoint) >> 1;

			// Make sure bestArbAmountIn is actually profitable (taking into account precision errors)
			uint256 amountOut = (reservesA1 * bestArbAmountIn) / (reservesA0 + bestArbAmountIn);
			amountOut = (reservesB1 * amountOut) / (reservesB0 + amountOut);
			amountOut = (reservesC1 * amountOut) / (reservesC0 + amountOut);

			if ( ( int256(amountOut) - int256(bestArbAmountIn) ) < int256(PoolUtils.DUST) )
				return 0;
			}
		}
	}