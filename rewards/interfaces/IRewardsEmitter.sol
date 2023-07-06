// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.12;

import "../../staking/interfaces/IStakingRewards.sol";
import "../../interfaces/IUpkeepable.sol";


interface IRewardsEmitter is IUpkeepable
	{
	function sharedRewards() external view returns (IStakingRewards);

	function addSALTRewards( AddedReward[] calldata addedRewards ) external;
	function pendingRewardsForPools( bytes32[] calldata pairs ) external view returns (uint256[] calldata);
	}
