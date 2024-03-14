// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "openzeppelin-contracts/contracts/utils/math/Math.sol";
import "../interfaces/IExchangeConfig.sol";
import "../pools/PoolUtils.sol";

// Finds a circular path after a user's swap has occurred (from WETH to WETH in this case) that results in an arbitrage profit.
abstract contract ArbitrageSearch
    {
	IERC20 immutable public weth;
	IERC20 immutable public usdc;
	IERC20 immutable public usdt;


    constructor( IExchangeConfig _exchangeConfig )
    	{
		// Cached for efficiency
		weth = _exchangeConfig.weth();
		usdc = _exchangeConfig.usdc();
		usdt = _exchangeConfig.usdt();
    	}


	// Returns the middle two tokens in an arbitrage path that starts and ends with WETH.
	// The WETH tokens at the beginning and end of the path are not returned as they are always the same.
	// Full arbitrage cycle is: WETH->arbToken2->arbToken3->WETH
	function _arbitragePath( IERC20 swapTokenIn, IERC20 swapTokenOut ) internal view returns (IERC20 arbToken2, IERC20 arbToken3)
		{
		// swap: USDC->WETH
        // arb: WETH->USDC->USDT->WETH
		if ( address(swapTokenIn) == address(usdc))
		if ( address(swapTokenOut) == address(weth))
			return (usdc, usdt);

		// swap: WETH->USDC
        // arb: WETH->USDT->USDC->WETH
		if ( address(swapTokenIn) == address(weth))
		if ( address(swapTokenOut) == address(usdc))
			return (usdt, usdc);

		// swap: WETH->swapTokenOut
        // arb: WETH->USDC->swapTokenOut->WETH
		if ( address(swapTokenIn) == address(weth))
			return (usdc, swapTokenOut);

		// swap: swapTokenIn->WETH
        // arb: WETH->swapTokenIn->USDC->WETH
		if ( address(swapTokenOut) == address(weth))
			return (swapTokenIn, usdc);

		// swap: swapTokenIn->swapTokenOut
        // arb: WETH->swapTokenOut->swapTokenIn->WETH
		return (swapTokenOut, swapTokenIn);
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


	// Given that x, y and z will be multiplied: determine the bit shift necessary to keep the product contained in 240 bits
	function _shiftRequired( uint256 x, uint256 y, uint256 z ) internal pure returns (uint256)
		{
		unchecked
			{
			// Determine the maximum number of bits required without shifting
			uint256 requiredBits0 = _mostSignificantBit(x) + _mostSignificantBit(y) + _mostSignificantBit(z);

			// Already fits in 240?
			if ( requiredBits0 < 240 )
				return 0;

			// Each number will be shifted so we can divide the required difference by 3
			return Math.ceilDiv( requiredBits0 - 240, 3 );
			}
		}


	// Determine the shift required to keep a0 * b0 * c0 and a1 * b1 * c1 within 240 bits
	function _determineShift( uint256 a0, uint256 b0, uint256 c0, uint256 a1, uint256 b1, uint256 c1 ) internal pure returns (uint256)
		{
		uint256 shift0 = _shiftRequired(a0, b0, c0);
		uint256 shift1 = _shiftRequired(a1, b1, c1);

		return shift0 > shift1 ? shift0 : shift1;
		}


	function _bestArbitrageIn( uint256 a0, uint256 a1, uint256 b0, uint256 b1, uint256 c0, uint256 c1 ) internal pure returns (uint256 bestArbAmountIn)
		{
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

			// Determine the shift required to keep a0 * b0 * c0 and a1 * b1 * c1 each within 240 bits
			uint256 shift = _determineShift( a0, b0, c0, a1, b1, c1 );

			if ( shift > 0 )
				{
				a0 = a0 >> shift;
				a1 = a1 >> shift;
				b0 = b0 >> shift;
				b1 = b1 >> shift;
				c0 = c0 >> shift;
				c1 = c1 >> shift;
				}

			// Each variable will use less than 80 bits
			uint256 n0 = a0 * b0 * c0;
			uint256 n1 = a1 * b1 * c1;

			if (n1 <= n0)
				return 0;

			uint256 m = a1 *  b1 + c0 * ( b0 + a1 );

			// Calculating n0 * n1 directly would overflow under some situations.
			// Multiply the sqrt's instead - effectively keeping the max size the same
			uint256 z = Math.sqrt(n0) * Math.sqrt(n1);

			bestArbAmountIn = ( z - n0 ) / m;
			if ( bestArbAmountIn == 0 )
				return 0;

			// Needed for the below arbitrage profit testing
			if ( shift > 0 )
				{
				// Convert back to normal scaling
				bestArbAmountIn = bestArbAmountIn << shift;

				a0 = a0 << shift;
				a1 = a1 << shift;
				b0 = b0 << shift;
				b1 = b1 << shift;
				c0 = c0 << shift;
				c1 = c1 << shift;
				}

			// Make sure bestArbAmountIn arbitrage is actually profitable (or else it will revert when actually performed in Pools.sol)
			uint256 amountOut = (a1 * bestArbAmountIn) / (a0 + bestArbAmountIn);
			amountOut = (b1 * amountOut) / (b0 + amountOut);
			amountOut = (c1 * amountOut) / (c0 + amountOut);

			if ( amountOut < bestArbAmountIn )
				return 0;
			}
		}
	}