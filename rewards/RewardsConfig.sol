// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.17;

import "../openzeppelin/access/Ownable2Step.sol";
import "../openzeppelin/token/ERC20/ERC20.sol";


contract RewardsConfig is Ownable2Step
    {
	ERC20 public usdc;

	// The daily target distribution percent per day (of SALT in the emitter contract) for the RewardsEmitter
	uint256 public rewardsEmitterDailyPercent = 10;

	// The share of the stored USDC that is sent to the caller of Upkeep.performUpkeep()
	// Defaults to 1 * 1000
	uint256 public upkeepPercentTimes1000; // x1000 for precision

	// === REWARDS DISTRIBUTION ===
	uint256 public earlyUnstake_votedRewardsPercent = 50;
    uint256 public earlyUnstake_xSaltHoldersPercent = 50;



	constructor( address _usdc )
		{
		usdc = ERC20( _usdc );
		}


	function setEarlyUnstakePercents( uint256 _earlyUnstake_votedRewardsPercent, uint256 _earlyUnstake_xSaltHoldersPercent ) public onlyOwner
		{
		require( ( _earlyUnstake_votedRewardsPercent + earlyUnstake_xSaltHoldersPercent ) == 100, "RewardsConfig: Percentages have to add up to 100" );

		earlyUnstake_votedRewardsPercent = _earlyUnstake_votedRewardsPercent;
		earlyUnstake_xSaltHoldersPercent = _earlyUnstake_xSaltHoldersPercent;
		}


	function setRewardsEmitterDailyPercent( uint256 _rewardsEmitterDailyPercent ) public onlyOwner
		{
		rewardsEmitterDailyPercent = _rewardsEmitterDailyPercent;
		}


	function setUpkeepPercentTimes1000( uint256 _upkeepPercentTimes1000 ) public onlyOwner
		{
		upkeepPercentTimes1000 = _upkeepPercentTimes1000;
		}
    }