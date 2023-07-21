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

	function arbitrage( IERC20[] memory arbitragePath, uint256 arbitrageAmountIn, uint256 minArbitrageProfit ) public returns (uint256 arbitrageProfit)
		{
		return _arbitrage(arbitragePath, arbitrageAmountIn, minArbitrageProfit);
		}
    }

