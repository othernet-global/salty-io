// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.12;


import "./IRewardsEmitter.sol";
import "./IRewardsConfig.sol";
import "../../staking/interfaces/IStaking.sol";
import "../../interfaces/IUpkeepable.sol";


interface IEmissions is IUpkeepable
	{
	function staking() external view returns( IStaking);
	function stakingConfig() external view returns( IStakingConfig);
	function stakingRewardsEmitter() external view returns (IRewardsEmitter);
	function rewardsConfig() external view returns( IRewardsConfig);
	}