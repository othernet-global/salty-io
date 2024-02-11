// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "openzeppelin-contracts/contracts/utils/math/Math.sol";
import "../interfaces/IExchangeConfig.sol";
import "../pools/PoolUtils.sol";
import "../pools/PoolMath.sol";

// Finds a circular path after a user's swap has occurred (from WETH to WETH in this case) that results in an arbitrage profit.
abstract contract ArbitrageSearch
    {
	IERC20 immutable public wbtc;
	IERC20 immutable public weth;
	ISalt immutable public salt;


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

		return  PoolMath._mostSignificantBit(max);
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

			// Needed for arbitrage profit testing
			A0 = A0 << shift;
			A1 = A1 << shift;
			B0 = B0 << shift;
			B1 = B1 << shift;
			C0 = C0 << shift;
			C1 = C1 << shift;

			uint256 amountOut = (A1 * bestArbAmountIn) / (A0 + bestArbAmountIn);
			amountOut = (B1 * amountOut) / (B0 + amountOut);
			amountOut = (C1 * amountOut) / (C0 + amountOut);

			// Make sure bestArbAmountIn arbitrage is actually profitable
			if ( amountOut < bestArbAmountIn )
				return 0;
			}
		}
	}