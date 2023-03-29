// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.17;

import "../openzeppelin/access/Ownable2Step.sol";
import "../openzeppelin/token/ERC20/ERC20.sol";


contract RewardsConfig is Ownable2Step
    {
	// The daily target distribution percent per day (of SALT in the emitter contract) for the RewardsEmitter
	uint256 public rewardsEmitterDailyPercent = 10;

	// The share of the stored USDC that is sent to the caller of Upkeep.performUpkeep()
	uint256 public upkeepPercentTimes1000 = 1 * 1000; // x1000 for precision

	// === REWARDS DISTRIBUTION ===

	// The weekly percent of SALT emissions that will be distributed from Emissions.sol
	uint256 public emissions_weeklyPercentTimes1000 = 1 * 1000;  // x1000 for precision
	uint256 public emissions_votedRewardsPercent = 50;
    uint256 public emissions_xSaltHoldersPercent = 50;

	uint256 public earlyUnstake_votedRewardsPercent = 50;
    uint256 public earlyUnstake_xSaltHoldersPercent = 50;



	constructor()
		{
		}


	function setEmissionsParams( uint256 _emissions_weeklyPercentTimes1000, uint256 _emissions_votedRewardsPercent, uint256 _emissions_xSaltHoldersPercent ) public onlyOwner
		{
		require( _emissions_weeklyPercentTimes1000 <= 100 * 1000, "RewardsConfig: emissions rate too high" );
		require( ( _emissions_votedRewardsPercent + _emissions_xSaltHoldersPercent ) == 100, "RewardsConfig: Percentages have to add up to 100" );

		emissions_weeklyPercentTimes1000 = _emissions_weeklyPercentTimes1000;
		emissions_votedRewardsPercent = _emissions_votedRewardsPercent;
		emissions_xSaltHoldersPercent = _emissions_xSaltHoldersPercent;
		}


	function setEarlyUnstakePercents( uint256 _earlyUnstake_votedRewardsPercent, uint256 _earlyUnstake_xSaltHoldersPercent ) public onlyOwner
		{
		require( ( _earlyUnstake_votedRewardsPercent + earlyUnstake_xSaltHoldersPercent ) == 100, "RewardsConfig: Percentages have to add up to 100" );

		earlyUnstake_votedRewardsPercent = _earlyUnstake_votedRewardsPercent;
		earlyUnstake_xSaltHoldersPercent = _earlyUnstake_xSaltHoldersPercent;
		}


	function setRewardsEmitterDailyPercent( uint256 _rewardsEmitterDailyPercent ) public onlyOwner
		{
		require( _rewardsEmitterDailyPercent <= 100, "RewardsConfig: emitter daily percent must be less than 100" );

		rewardsEmitterDailyPercent = _rewardsEmitterDailyPercent;
		}


	function setUpkeepPercentTimes1000( uint256 _upkeepPercentTimes1000 ) public onlyOwner
		{
		upkeepPercentTimes1000 = _upkeepPercentTimes1000;
		}
    }