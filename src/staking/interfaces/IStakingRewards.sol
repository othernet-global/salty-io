// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;


struct AddedReward
	{
	bytes32 poolID;							// The pool to add rewards to
	uint256 amountToAdd;				// The amount of rewards (as SALT) to add
	}

struct UserShareInfo
	{
	uint128 userShare;					// A user's share for a given poolID
	uint128 virtualRewards;				// The amount of rewards that were added to maintain proper rewards/share ratio - and will be deducted from a user's pending rewards.
	uint256 cooldownExpiration;		// The timestamp when the user can modify their share
	}


interface IStakingRewards
	{
	function claimAllRewards( bytes32[] calldata poolIDs ) external returns (uint256 rewardsAmount);
	function addSALTRewards( AddedReward[] calldata addedRewards ) external;

	// Views
	function totalShares(bytes32 poolID) external view returns (uint256);
	function totalSharesForPools( bytes32[] calldata poolIDs ) external view returns (uint256[] calldata shares);
	function totalRewardsForPools( bytes32[] calldata poolIDs ) external view returns (uint256[] calldata rewards);

	function userRewardForPool( address wallet, bytes32 poolID ) external view returns (uint256);
	function userShareForPool( address wallet, bytes32 poolID ) external view returns (uint256);
	function userVirtualRewardsForPool( address wallet, bytes32 poolID ) external view returns (uint256);

	function userRewardsForPools( address wallet, bytes32[] calldata poolIDs ) external view returns (uint256[] calldata rewards);
	function userShareForPools( address wallet, bytes32[] calldata poolIDs ) external view returns (uint256[] calldata shares);
	function userCooldowns( address wallet, bytes32[] calldata poolIDs ) external view returns (uint256[] calldata cooldowns);
	}
