// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.12;

import "./openzeppelin/security/ReentrancyGuard.sol";
import "./interfaces/IArbitrageSearch.sol";
import "./rewards/interfaces/IRewardsEmitter.sol";
import "./dao/interfaces/IDAO.sol";
import "./interfaces/IExchangeConfig.sol";
import "./openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "./Upkeepable.sol";


contract ArbitrageSearch is IArbitrageSearch
    {
	using SafeERC20 for IERC20;

    IPools immutable public pools;
    IExchangeConfig immutable public exchangeConfig;

	IERC20 immutable public weth;


    constructor( IPools _pools, IExchangeConfig _exchangeConfig )
    	{
		require( address(_pools) != address(0), "_pools cannot be address(0)" );
		require( address(_exchangeConfig) != address(0), "_exchangeConfig cannot be address(0)" );

		pools = _pools;
		exchangeConfig = _exchangeConfig;

		weth = exchangeConfig.weth();
    	}


	// Determine an arbitrage path to use for the given swap whihc jsut occured (in this same transaction)
	function findArbitrage( IERC20[] memory swapPath, uint256 amountIn ) external returns (IERC20[] memory arbPath, uint256 arbAmount)
    	{
    	// Make sure the swap is profitable

    	return (new IERC20[](0), 0);
    	}
	}

