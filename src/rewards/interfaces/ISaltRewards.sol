// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "./IRewardsEmitter.sol";


interface ISaltRewards
	{
	function sendInitialSaltRewards( uint256 liquidityBootstrapAmount, bytes32[] calldata poolIDs ) external;
    function performUpkeep( bytes32[] calldata poolIDs, uint256[] calldata profitsForPools ) external;

    // Views
    function stakingRewardsEmitter() external view returns (IRewardsEmitter);
    function liquidityRewardsEmitter() external view returns (IRewardsEmitter);
    }