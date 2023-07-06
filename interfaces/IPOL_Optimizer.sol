// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.12;


interface IPOL_Optimizer
	{
	function lastSwapTimestamp( address token0, address token1 ) external view returns (uint32);
	function findBestPool() external view returns (uint256 maxPendingReward, bytes32 bestPool);
	}
