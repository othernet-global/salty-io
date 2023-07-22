// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.20;

import "./interfaces/IArbitrageSearch.sol";
import "../interfaces/IExchangeConfig.sol";


contract ArbitrageSearch is IArbitrageSearch
    {
    IPools immutable public pools;
    IExchangeConfig immutable public exchangeConfig;


    constructor( IPools _pools, IExchangeConfig _exchangeConfig )
    	{
		require( address(_pools) != address(0), "_pools cannot be address(0)" );
		require( address(_exchangeConfig) != address(0), "_exchangeConfig cannot be address(0)" );

		pools = _pools;
		exchangeConfig = _exchangeConfig;
    	}


//	BTC->ETH
//    ETH->BTC->SALT->ETH
//    ETH->BTC->token->ETH
//
//    ETH->BTC
//    ETH->SALT->BTC->ETH
//    ETH->token->BTC->ETH
//
//    ETH->token
//    ETH->BTC->token->ETH
//
//    token->ETH
//    ETH->token->BTC->ETH
//
//    // UI determines which of these
//    token1->token2 (neither ETH, direct pool exists)
//    ETH->token2->token1->ETH
//
//    // ...or
//    token1->ETH->token2 (neither ETH, no direct pool)
//    ETH->token1->BTC->token2->ETH

	// Determine an arbitrage path to use for the given swap whihc just occured (in this same transaction)
	function findArbitrage( IERC20 swapTokenIn, IERC20 swapTokenOut, uint256 swapAmountInValueInETH, bool isDirectlyPooled ) external returns (IERC20 tokenIn, IERC20 tokenA, IERC20 tokenB, IERC20 tokenC, uint256 arbAmountIn)
    	{
    	// Determine which path to use
    	// Make sure the swap is profitable

    	return (IERC20(address(0)), IERC20(address(0)), IERC20(address(0)), IERC20(address(0)), 0);
    	}
	}

