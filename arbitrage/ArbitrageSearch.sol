// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.20;

import "./interfaces/IArbitrageSearch.sol";
import "../interfaces/IExchangeConfig.sol";


contract ArbitrageSearch is IArbitrageSearch
    {
    IPools immutable public pools;
    IExchangeConfig immutable public exchangeConfig;

	IERC20 public wbtc;
	IERC20 public weth;
	ISalt public salt;

	// Token balances less than dust are treated as if they don't exist at all.
	// With the 18 decimals that are used for most tokens, DUST has a value of 0.0000000000000001
	// For tokens with 6 decimal places (like USDC) DUST has a value of .0001
	uint256 constant public _DUST = 100;


    constructor( IPools _pools, IExchangeConfig _exchangeConfig )
    	{
		require( address(_pools) != address(0), "_pools cannot be address(0)" );
		require( address(_exchangeConfig) != address(0), "_exchangeConfig cannot be address(0)" );

		pools = _pools;
		exchangeConfig = _exchangeConfig;

		// Cached for efficiency
		wbtc = exchangeConfig.wbtc();
		weth = exchangeConfig.weth();
		salt = exchangeConfig.salt();
    	}


	// Returns the arbitrage path to use based on swapTokenIn and swapTokenOut - where those two tokens form a whitelisted pair and have direct liquidity in the pools.
	// Swaps (in this contract version) are circular and will start and end with WETH.
	// Returned cycle is: arbToken1->arbToken2->arbToken3->arbToken1
	function _directArbitragePath( IERC20 swapTokenIn, IERC20 swapTokenOut ) internal view returns (IERC20 arbToken1, IERC20 arbToken2, IERC20 arbToken3)
		{
		// swap: WBTC->WETH
        // arb: WETH->WBTC->SALT->WETH
		if ( address(swapTokenIn) == address(wbtc))
		if ( address(swapTokenOut) == address(weth))
			return (weth, wbtc, salt);

		// swap: WETH->WBTC
        // arb: WETH->SALT->WBTC->WETH
		if ( address(swapTokenIn) == address(weth))
		if ( address(swapTokenOut) == address(wbtc))
			return (weth, salt, wbtc);

		// swap: WETH->token
        // arb: WETH->WBTC->token->WETH
		if ( address(swapTokenIn) == address(weth))
			return (weth, wbtc, swapTokenOut);

		// swap: token->WETH
        // arb: WETH->token->WBTC->WETH
		if ( address(swapTokenOut) == address(weth))
			return (weth, swapTokenIn, wbtc);

		// swap: token1->token2
        // arb: WETH->token2->token1->WETH
		return (weth, swapTokenOut, swapTokenIn);
		}


	// Returns the arbitrage path to use based on swapTokenIn and swapTokenOut - where those two tokens don't form a whitelisted pair
	// Swaps are circular and will start and end with WETH.
	// Returned cycle is: arbToken1->arbToken2->arbToken3->arbToken4->arbToken1
	function _indirectArbitragePath( IERC20 swapTokenIn, IERC20 swapTokenOut ) internal view returns (IERC20 arbToken1, IERC20 arbToken2, IERC20 arbToken3, IERC20 arbToken4)
		{
		// swap: token1->WETH->token2   (intermediate WETH used in swaps without direct pool on exchange)
		// arb: WETH->token1->WBTC->token2->WETH
		return (weth, swapTokenIn, wbtc, swapTokenOut);
		}


	// Determine an arbitrage path to use for the given swap which just occured in this same transaction
	function findArbitrage( IERC20 swapTokenIn, IERC20 swapTokenOut, uint256 swapAmountInValueInETH, bool isWhitelistedPair ) public view returns (IERC20[] memory arbitrageSwapPath, uint256 arbAmountIn)
    	{
    	if (isWhitelistedPair )
    		{
			arbitrageSwapPath = new IERC20[](3);
	   		(arbitrageSwapPath[0], arbitrageSwapPath[1], arbitrageSwapPath[2]) = _directArbitragePath( swapTokenIn, swapTokenOut );
	   		}
	   	else
	   		{
			arbitrageSwapPath = new IERC20[](4);
	   		(arbitrageSwapPath[0], arbitrageSwapPath[1], arbitrageSwapPath[2], arbitrageSwapPath[3]) = _indirectArbitragePath( swapTokenIn, swapTokenOut );
	   		}

		if ( swapAmountInValueInETH <= _DUST )
			return (arbitrageSwapPath,0);

		// Cache the reserves for efficiency
		(uint256 reservesA0, uint256 reservesA1) = pools.getPoolReserves( arbitrageSwapPath[0], arbitrageSwapPath[1]);
		(uint256 reservesB0, uint256 reservesB1) = pools.getPoolReserves( arbitrageSwapPath[1], arbitrageSwapPath[2]);

		uint256 reservesC0;
		uint256 reservesC1;
		uint256 reservesD0;
		uint256 reservesD1;

		if (isWhitelistedPair)
			{
			(reservesC0, reservesC1) = pools.getPoolReserves( arbitrageSwapPath[2], arbitrageSwapPath[0]);

			if ( reservesA0 <= _DUST || reservesA1 <= _DUST || reservesB0 <= _DUST || reservesB1 <= _DUST || reservesC0 <= _DUST || reservesC1 <= _DUST )
				return (arbitrageSwapPath,0);
			}
		else
			{
			(reservesC0, reservesC1) = pools.getPoolReserves( arbitrageSwapPath[2], arbitrageSwapPath[3]);
			(reservesD0, reservesD1) = pools.getPoolReserves( arbitrageSwapPath[3], arbitrageSwapPath[0]);

			if ( reservesA0 <= _DUST || reservesA1 <= _DUST || reservesB0 <= _DUST || reservesB1 <= _DUST || reservesC0 <= _DUST || reservesC1 <= _DUST || reservesD0 <= _DUST || reservesD1 <= _DUST )
				return (arbitrageSwapPath,0);
			}

    	// Try arbAmountIn from 10-200% of the swapAmountInValueInETH.
    	// Arbitrage paths from this contract always start and end with WETH for simplicity so the valueInETH translates directly for arbAmountIn.
    	arbAmountIn = 0;
    	uint256 bestProfitSoFar;

    	// Search 10% of the swapAmountInValueInETH at a time
    	uint256 fractionOfValueInETH = swapAmountInValueInETH / 10;

		// Cost is about 1274 gas per loop iteration
    	for( uint256 i = 0; i < 20; i++ )
    		{
    		arbAmountIn += fractionOfValueInETH;

			// Estimate the AMM output
			uint256 amountOut = reservesA1 - ( reservesA0 * reservesA1 ) / ( reservesA0 + arbAmountIn );
			amountOut = reservesB1 - ( reservesB0 * reservesB1 ) / ( reservesB0 + amountOut );
			amountOut = reservesC1 - ( reservesC0 * reservesC1 ) / ( reservesC0 + amountOut );
			if ( ! isWhitelistedPair )
				amountOut = reservesD1 - ( reservesD0 * reservesD1 ) / ( reservesD0 + amountOut );

			// If the simulated arbitrage isn't profitable, then just use the last value
			if ( amountOut < arbAmountIn )
				break;

			uint256 arbitrageProfit = amountOut - arbAmountIn;

			if ( arbitrageProfit < bestProfitSoFar )
				break;

			// This arbAmountIn is more profitable than what has been seen so far
			bestProfitSoFar = arbitrageProfit;
    		}

		return (arbitrageSwapPath, arbAmountIn - fractionOfValueInETH);
    	}
	}

