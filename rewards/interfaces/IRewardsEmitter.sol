// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.12;

import "../../staking/interfaces/IStakingRewards.sol";
import "../../staking/interfaces/IStakingConfig.sol";
import "../../pools/interfaces/IPoolsConfig.sol";
import "../../interfaces/IUpkeepable.sol";
import "../../interfaces/IExchangeConfig.sol";
import "./IRewardsConfig.sol";


interface IRewardsEmitter is IUpkeepable
	{
	function addSALTRewards( AddedReward[] calldata addedRewards ) external;

	// Views
	function exchangeConfig() external view returns (IExchangeConfig);
	function poolsConfig() external view returns (IPoolsConfig);
	function rewardsConfig() external view returns (IRewardsConfig);
	function stakingConfig() external view returns (IStakingConfig);
	function stakingRewards() external view returns (IStakingRewards);

	function pendingRewardsForPools( bytes32[] calldata pairs ) external view returns (uint256[] calldata);
	}
