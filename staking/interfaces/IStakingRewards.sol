// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.12;

import "./IStakingConfig.sol";


struct AddedReward
	{
	bytes32 poolID;							// The pool to add rewards to
	uint256 amountToAdd;				// The amount of rewards (as SALT) to add
	}

struct UserShareInfo
	{
	uint256 userShare;						// A users share for a given poolID
	uint256 virtualRewards;				// The amount of rewards that were added to maintain proper rewards/share ratio - and will be deducted from a user's pending rewards.
	uint256 cooldownExpiration;		// The timestamp when the user can modify their share
	}


interface IStakingRewards
	{
	function claimAllRewards( bytes32[] calldata pools ) external;
	function addSALTRewards( AddedReward[] calldata addedRewards ) external;

	// Views
	function stakingConfig() external returns (IStakingConfig);
	function totalSharesForPools( bytes32[] calldata pools ) external view returns (uint256[] calldata shares);
	function totalRewardsForPools( bytes32[] calldata pools ) external view returns (uint256[] calldata rewards);
	function userPendingReward( address wallet, bytes32 pool ) external view returns (uint256);
	function userRewardsForPools( address wallet, bytes32[] calldata pools ) external view returns (uint256[] calldata rewards);
	function userShareForPools( address wallet, bytes32[] calldata pools ) external view returns (uint256[] calldata shares);
	function userCooldowns( address wallet, bytes32[] calldata pools ) external view returns (uint256[] calldata cooldowns);
	function userShareInfoForPool( address wallet, bytes32 pool ) external view returns (UserShareInfo memory);
	}
