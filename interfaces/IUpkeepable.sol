// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.21;


interface IUpkeepable
	{
	function performUpkeep() external;

	// Views
	function timeSinceLastUpkeep() external view returns (uint256);
	}
