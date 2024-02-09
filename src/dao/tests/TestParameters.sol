// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "../Parameters.sol";

contract TestParameters is Parameters
    {
	function executeParameterChange( ParameterTypes parameterType, bool increase, IPoolsConfig poolsConfig, IStakingConfig stakingConfig, IRewardsConfig rewardsConfig, IDAOConfig daoConfig ) public
		{
		_executeParameterChange( parameterType, increase, poolsConfig, stakingConfig, rewardsConfig, daoConfig );
		}
	}