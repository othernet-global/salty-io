// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.12;


interface IUpkeepable
	{
	function timeSinceLastUpkeep() external view returns (uint256);

	function performUpkeep() external;
	}
