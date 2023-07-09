// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.12;


interface IRewardsConfig
	{
	function changeEmissionsWeeklyPercent(bool increase) external; // onlyOwner
	function changeXSaltHoldersPercent(bool increase) external; // onlyOwner
	function changeRewardsEmitterDailyPercent(bool increase) external; // onlyOwner

	// Views
    function emissionsWeeklyPercentTimes1000() external view returns (uint256);
    function emissionsXSaltHoldersPercent() external view returns (uint256);
    function rewardsEmitterDailyPercentTimes1000() external view returns (uint256);
    }