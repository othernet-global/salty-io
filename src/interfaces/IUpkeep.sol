// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;


interface IUpkeep
	{
	function performUpkeep() external;

	// Views
	function currentRewardsForCallingPerformUpkeep() external returns (uint256);
	function lastUpkeepTimeEmissions() external returns (uint256);
	function lastUpkeepTimeRewardsEmitters() external returns (uint256);
	}
