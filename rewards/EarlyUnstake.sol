// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.17;

import "../Upkeepable.sol";
import "./VotedRewards.sol";
import "./RewardsEmitter.sol";


// Stores the SALT early unstake fees that happen when the user unstakes for less than the maximum time
// Only stores the SALT transferred in since the last upkeep.

contract EarlyUnstake is Upkeepable
    {
    VotedRewards votedRewards;
	RewardsEmitter rewardsEmitter;


    constructor( address _votedRewards, address _rewardsEmitter )
		{
		votedRewards = VotedRewards( _votedRewards );
		rewardsEmitter = RewardsEmitter( _rewardsEmitter );
		}


	function performUpkeep() internal override
		{
		address[] memory poolIDs = stakingConfig.whitelistedPools();

		// Looking at the xSALT deposits (which act as votes) for each pool,
		// we'll send a proportional amount of rewards to RewardsEmitter.sol for each pool
		uint256[] memory votesForPools = staking.totalDepositsForPools( poolIDs, false );

		// Determine the total pool votes so we can calculate pool percentages
		uint256 totalPoolVotes = 0;
		for( uint256 i = 0; i < votesForPools.length; i++ )
			totalPoolVotes += votesForPools[i];

		// Make sure some votes have been cast
		if ( totalPoolVotes == 0 )
			return;

		uint256 saltBalance = stakingConfig.salt().balanceOf( address( this ) );

		// The rewards we are adding will be claimable by those who have staked LP.
		// So, specify areLPs = true for the added rewards
		bool[] memory areLPs = new bool[]( votesForPools.length );
		for( uint256 i = 0; i < areLPs.length; i++ )
			areLPs[i] = true;

		// The entire SALT balance will be sent - proportional to the votes received by each pool
		uint256[] memory amountsToAdd = new uint256[]( votesForPools.length );
		for( uint256 i = 0; i < amountsToAdd.length; i++ )
			amountsToAdd[i] = ( saltBalance * votesForPools[i] ) / totalPoolVotes;

		// Send the SALT to the RewardsEmitter
		rewardsEmitter.addSALTRewards( poolIDs, areLPs, amountsToAdd );
		}
	}
