// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;


interface IPoolStats
	{
	function clearProfitsForPools( bytes32[] memory poolIDs ) external;

	// Views
	function lastSwapTimestamp( bytes32 poolID ) external returns (uint256 _lastSwapTimestamp);
	function profitsForPools( bytes32[] memory poolIDs ) external returns (uint256[] memory _profits);
	}

