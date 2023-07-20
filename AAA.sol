// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.12;

import "./openzeppelin/security/ReentrancyGuard.sol";
import "./interfaces/IAAA.sol";
import "./rewards/interfaces/IRewardsEmitter.sol";
import "./dao/interfaces/IDAO.sol";
import "./interfaces/IExchangeConfig.sol";
import "./openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "./Upkeepable.sol";


contract AAA is IAAA, ReentrancyGuard, Upkeepable
    {
	using SafeERC20 for IERC20;

    IPools immutable public pools;
    IExchangeConfig immutable public exchangeConfig;

    IRewardsEmitter immutable public liquidityRewardsEmitter;
	IRewardsEmitter immutable public stakingRewardsEmitter;
	IRewardsEmitter immutable public collateralRewardsEmitter;

	IERC20 immutable public weth;


    constructor( IPools _pools, IExchangeConfig _exchangeConfig )
    	{
		require( address(_pools) != address(0), "_pools cannot be address(0)" );
		require( address(_exchangeConfig) != address(0), "_exchangeConfig cannot be address(0)" );

		pools = _pools;
		exchangeConfig = _exchangeConfig;

		liquidityRewardsEmitter = exchangeConfig.liquidityRewardsEmitter();
		stakingRewardsEmitter = exchangeConfig.stakingRewardsEmitter();
		collateralRewardsEmitter = exchangeConfig.collateralRewardsEmitter();

		weth = exchangeConfig.weth();
    	}


	// Attempt arbitrage just after the given token swap
	function attemptArbitrage( address swapper, IERC20[] memory swapPath, uint256 amountIn ) public nonReentrant
    	{
    	// Make sure the swap is profitable
    	}


	function _performUpkeep() internal override
		{
		}
	}

