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


	// Determine an arbitrage path to use for the given swap whihc just occured (in this same transaction)
	function findArbitrage( IERC20[] memory swapPath, uint256 swapAmountInValueInETH ) external returns (IERC20[] memory arbPath, uint256 arbAmountIn)
    	{
    	// Make sure the swap is profitable

    	return (new IERC20[](0), 0);
    	}
	}

