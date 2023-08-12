// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;


interface ISaltRewards
	{
	function addSALTRewards(uint256 amount) external;
	function performUpkeep( bytes32[] calldata poolIDs, uint256[] calldata profitsForPools ) external;
    }