// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;


interface IRewardsConfig
	{
	function changeRewardsEmitterDailyPercent(bool increase) external; // onlyOwner
	function changeEmissionsWeeklyPercent(bool increase) external; // onlyOwner
	function changeStakingRewardsPercent(bool increase) external; // onlyOwner
	function changePercentRewardsSaltUSDC(bool increase) external; // onlyOwner

	// Views
    function emissionsWeeklyPercentTimes1000() external view returns (uint256);
    function rewardsEmitterDailyPercentTimes1000() external view returns (uint256);
    function stakingRewardsPercent() external view returns (uint256);
    function percentRewardsSaltUSDC() external view returns (uint256);
    }