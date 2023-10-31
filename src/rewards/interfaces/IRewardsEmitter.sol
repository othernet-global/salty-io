// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "../../staking/interfaces/IStakingRewards.sol";


interface IRewardsEmitter
	{
	function addSALTRewards( AddedReward[] calldata addedRewards ) external;
	function performUpkeep( uint256 timeSinceLastUpkeep ) external;

	// Views
	function pendingRewardsForPools( bytes32[] calldata pools ) external view returns (uint256[] calldata);
	}
