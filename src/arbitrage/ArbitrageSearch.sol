// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

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


	function _bestArbitrageIn( uint256 A0, uint256 A1, uint256 B0, uint256 B1, uint256 C0, uint256 C1 ) public pure returns (uint256 bestArbAmountIn)
		{
		// Actual swaps using the arbitrage path will fail with insufficient reserves
		if ( A0 <= PoolUtils.DUST || A1 <= PoolUtils.DUST || B0 <= PoolUtils.DUST || B1 <= PoolUtils.DUST || C0 <= PoolUtils.DUST || C1 <= PoolUtils.DUST )
			return 0;

		// Original derivation: https://github.com/code-423n4/2024-01-salty-findings/issues/419
		// n0 = A0 * B0 * C0
		// n1 = A1 * B1 * C1
		//
		// m = A1 * B1 + C0 * B0 + C0 * A1
		// z = sqrt(A0 * C1) * sqrt(A1 * B0) * sqrt(B1 * C0)
		//
		// bestArbAmountIn = ( z - n0 ) / m;

		// This can be unchecked as the actual arbitrage that is performed when this is non-zero is checked and duplicates the check for profitability.
		// testArbitrageMethodsLarge() checks for proper behavior with extremely large reserves
		unchecked
			{
			uint256 n0 = A0 * B0 * C0;
			uint256 n1 = A1 * B1 * C1;

			if (n1 <= n0)
				return 0;

			uint256 m = A1 * ( B1 + C0 ) + C0 * B0;
			uint256 n0_div_m = n0 / m;

			// Division by m before multiply to reduce overflow risk
			uint256 z_div_m = PoolMath._sqrt( n0_div_m * (n1 / m));

			bestArbAmountIn = z_div_m - n0_div_m;

			// Make sure bestArbAmountIn is actually profitable
			uint256 amountOut = (A1 * bestArbAmountIn) / (A0 + bestArbAmountIn);
			amountOut = (B1 * amountOut) / (B0 + amountOut);
			amountOut = (C1 * amountOut) / (C0 + amountOut);

			if ( amountOut < bestArbAmountIn )
				return 0;
			}
		}
	}