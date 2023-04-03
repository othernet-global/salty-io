// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.0;

import "../Upkeepable.sol";
import "../staking/StakingConfig.sol";
import "./RewardsConfig.sol";
import "./VotedRewards.sol";
import "./RewardsEmitter.sol";

// Responsible for storing the SALT emissions and distributing them over time
// Default rate of emissions is 1% of the current SALT balance per week

contract Emissions is Upkeepable
    {
    StakingConfig stakingConfig;
    RewardsConfig rewardsConfig;
    VotedRewards votedRewards;
	RewardsEmitter rewardsEmitter;


    constructor( address _stakingConfig, address _rewardsConfig, address _votedRewards, address _rewardsEmitter )
		{
		stakingConfig = StakingConfig( _stakingConfig );
		rewardsConfig = RewardsConfig( _rewardsConfig );
		votedRewards = VotedRewards( _votedRewards );
		rewardsEmitter = RewardsEmitter( _rewardsEmitter );

		stakingConfig.salt().approve( _rewardsEmitter, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff );
		}


	function performUpkeep() internal override
		{
		uint256 saltBalance = stakingConfig.salt().balanceOf( address( this ) );

		uint256 timeSinceLastUpkeep = timeSinceLastUpkeep();
		if ( timeSinceLastUpkeep == 0 )
			return;

		uint256 saltToSend = ( saltBalance * timeSinceLastUpkeep * rewardsConfig.emissions_weeklyPercentTimes1000() ) / ( 100 * 1000 weeks );

		uint256 votedRewardsAmount = ( saltToSend * rewardsConfig.emissions_votedRewardsPercent() ) / 100;
		uint256 xsaltHoldersAmount = saltToSend - votedRewardsAmount;

		// Send a portion to be distributed to pools proportional to pool votes received
		require( stakingConfig.salt().transfer( address(votedRewards), votedRewardsAmount ), "Transfer failed" );

		// Send the SALT to the RewardsEmitter for [STAKING][false]
		rewardsEmitter.addSALTRewards( IUniswapV2Pair(address(0)), false, xsaltHoldersAmount );
		}
	}
