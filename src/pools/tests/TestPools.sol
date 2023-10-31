// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "../Pools.sol";


contract TestPools is Pools
    {
    constructor( IExchangeConfig _exchangeConfig, IPoolsConfig _poolsConfig )
    Pools(_exchangeConfig, _poolsConfig)
    	{
    	}

	function shouldCounterswap( IERC20 swapTokenIn, IERC20 swapTokenOut, uint256 swapAmountOut ) public view returns (bool)
		{
		bytes32 poolID = PoolUtils._poolIDOnly( swapTokenIn, swapTokenOut );

		// For counterswapping, make sure a swap hasn't already been placed within this block (which could indicate attempted manipulation)
		bool counterswapDisabled = ( lastSwapBlock(poolID)== uint32(block.number) );
		if ( counterswapDisabled )
			return false;

		address counterswapAddress = Counterswap._determineCounterswapAddress(swapTokenOut, swapTokenIn, wbtc, weth, salt, usds);

		return _counterswapDepositExists(counterswapAddress, swapTokenOut, swapAmountOut );
		}
    }