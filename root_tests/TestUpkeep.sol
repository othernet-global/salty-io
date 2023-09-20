// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "../Upkeep.sol";


contract TestUpkeep is Upkeep
    {
	constructor( IPools _pools, IExchangeConfig _exchangeConfig, IPoolsConfig _poolsConfig, IDAOConfig _daoConfig, IPriceAggregator _priceAggregator, ISaltRewards _saltRewards, ILiquidity _liquidity, IEmissions _emissions )
	Upkeep( _pools, _exchangeConfig, _poolsConfig, _daoConfig, _priceAggregator, _saltRewards, _liquidity, _emissions )
		{
		}


	function withdrawTokenFromCounterswap( IERC20 token, address counterswapAddress ) public
		{
		_withdrawTokenFromCounterswap( token, counterswapAddress );
		}
	}
