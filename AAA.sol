//// SPDX-License-Identifier: BSL 1.1
//pragma solidity ^0.8.12;
//
//import "./uniswap/core/interfaces/IUniswapV2Pair.sol";
//import "./interfaces/IAAA.sol";
//import "./rewards/interfaces/IRewardsEmitter.sol";
//import "./interfaces/IPOL_Optimizer.sol";
//
//
//contract AAA is IAAA
//    {
//    IPOL_Optimizer public optimizer;
//
//
//    constructor( IRewardsEmitter _liquidityRewardsEmitter, IRewardsEmitter _stakingRewardsEmitter, IRewardsEmitter _collateralRewardsEmitter, IPOL_Optimizer _optimizer )
//    	{
//		require( address(_liquidityRewardsEmitter) != address(0), "_liquidityRewardsEmitter cannot be address(0)" );
//		require( address(_stakingRewardsEmitter) != address(0), "_stakingRewardsEmitter cannot be address(0)" );
//		require( address(_collateralRewardsEmitter) != address(0), "_collateralRewardsEmitter cannot be address(0)" );
//		require( address(_optimizer) != address(0), "_optimizer cannot be address(0)" );
//
//		liquidityRewardsEmitter = _liquidityRewardsEmitter;
//		stakingRewardsEmitter = _stakingRewardsEmitter;
//		collateralRewardsEmitter = _collateralRewardsEmitter;
//		optimizer = _optimizer;
//    	}
//
//
//	function collateralRewardsEmitterAddress() public view returns (address)
//		{
//		return address(collateralRewardsEmitter);
//		}
//
//
//	// Attempt arbitrage just after the given token swap
//	function attemptArbitrage( address tokenIn, address tokenOut, uint256 amountIn, address to ) public
//    	{
////    	IUniswapV2Pair pair = IUniswapV2Pair( _pair );
//    	}
//	}
//
