// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "../Pools.sol";


contract TestPools is Pools
    {
    constructor( IExchangeConfig _exchangeConfig, IRewardsConfig _rewardsConfig, IPoolsConfig _poolsConfig )
    Pools(_exchangeConfig, _rewardsConfig, _poolsConfig)
    	{
    	}


	function shouldCounterswap( IERC20 swapTokenIn, IERC20 swapTokenOut, uint256 swapAmountIn, uint256 swapAmountOut ) public returns (bool)
		{
		address counterswapAddress = Counterswap._determineCounterswapAddress(swapTokenOut, swapTokenIn, wbtc, weth, salt, usds);

		return _shouldCounterswap(swapTokenIn, swapTokenOut, counterswapAddress, swapAmountIn, swapAmountOut );
		}
    }