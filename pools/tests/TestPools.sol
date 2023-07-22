// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.20;

import "forge-std/Test.sol";
import "../../root_tests/TestERC20.sol";
import "../Pools.sol";
import "../../Deployment.sol";
import "../PoolUtils.sol";


contract TestPools is Pools
	{
	Deployment public deployment = new Deployment();


	constructor()
	Pools(deployment.exchangeConfig(), deployment.poolsConfig())
		{
		setDAO( deployment.dao() );
		}


	function attemptArbitrage( IERC20 swapTokenIn, IERC20 swapTokenOut, uint256 swapAmountIn, bool hasDirectPool ) public returns (uint256 swapAmountInValueInETH, uint256 arbitrageProfit)
		{
		return _attemptArbitrage(swapTokenIn, swapTokenOut, swapAmountIn, hasDirectPool);
		}


	function arbitrage( IERC20 tokenIn, IERC20 tokenA, IERC20 tokenB, IERC20 tokenC, uint256 arbitrageAmountIn, uint256 minArbitrageProfit ) public returns (uint256 arbitrageProfit)
		{
		return _arbitrage(tokenIn, tokenA, tokenB, tokenC, arbitrageAmountIn, minArbitrageProfit);
		}
    }

