// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.12;

import "../../staking/interfaces/IStakingRewards.sol";
import "../../staking/interfaces/IStakingConfig.sol";
import "../../pools/interfaces/IPoolsConfig.sol";
import "../../interfaces/IExchangeConfig.sol";
import "./IRewardsConfig.sol";


interface IRewardsEmitter
	{
	function addSALTRewards( AddedReward[] calldata addedRewards ) external;

	// Views
	function pendingRewardsForPools( bytes32[] calldata pairs ) external view returns (uint256[] calldata);
	}
