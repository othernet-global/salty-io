// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.20;

import "../../staking/interfaces/IStakingRewards.sol";


interface IRewardsEmitter
	{
	function addSALTRewards( AddedReward[] calldata addedRewards ) external;

	// Views
	function pendingRewardsForPools( bytes32[] calldata pairs ) external view returns (uint256[] calldata);
	}
