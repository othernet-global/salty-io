// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;


interface IPoolStats
	{
	function clearProfitsForPools( bytes32[] calldata poolIDs ) external;
	function updateArbitrageIndicies() external;

	// Views
	function profitsForPools( bytes32[] memory poolIDs ) external view returns (uint256[] memory _profits);
	}

