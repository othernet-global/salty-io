// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.17;

import "../Upkeepable.sol";
import "../staking/Staking.sol";
import "./RewardsEmitter.sol";
import "../openzeppelin/security/PullPayment.sol";


// Stores SALT and distributes it at upkeep to RewardsEmitter.sol
// based on the votes (as deposited xSALT) that each pool has received at the moment of upkeep.
// Only stores the SALT rewards transferred in since the last upkeep.

contract VotedRewards is Upkeepable
    {
    StakingConfig stakingConfig;
    Staking staking;
	RewardsEmitter rewardsEmitter;


    constructor( address _stakingConfig, address _staking, address _rewardsEmitter )
		{
		stakingConfig = StakingConfig( _stakingConfig );
		staking = Staking( _staking );
		rewardsEmitter = RewardsEmitter( _rewardsEmitter );
		}


	function performUpkeep() internal override
		{
		address[] memory poolIDs = stakingConfig.whitelistedPools();

		// Looking at the xSALT deposits (which act as votes) for each pool,
		// we'll send a proportional amount of rewards to Staking.sol for each pool
		uint256[] memory votesForPools = staking.totalDepositsForPools( poolIDs, false );

		// Determine the total pool votes so we can calculate pool percentages
		uint256 totalPoolVotes = 0;
		for( uint256 i = 0; i < votesForPools.length; i++ )
			totalPoolVotes += votesForPools[i];

		uint256 saltBalance = stakingConfig.salt().balanceOf( address( this ) );

		// The rewards we are adding will be claimable by those who have staked LP.
		// So, specify areLPs = true
		bool[] memory areLPs = new bool[]( votesForPools.length );
		for( uint256 i = 0; i < areLPs.length; i++ )
			areLPs[i] = true;

		uint256[] memory amountsToAdd = new uint256[]( votesForPools.length );
		for( uint256 i = 0; i < amountsToAdd.length; i++ )
			amountsToAdd[i] = ( saltBalance * votesForPools[i] ) / totalPoolVotes;

		rewardsEmitter.addSALTRewards( poolIDs, areLPs, amountsToAdd );
		}
	}
