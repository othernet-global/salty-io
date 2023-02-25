// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.17;

import "../Upkeepable.sol";
import "../staking/Staking.sol";
import "../staking/StakingConfig.sol";
import "./RewardsConfig.sol";


// Stores SALT rewards and distributes them at a default rate of 10% per day to Staking.sol
// Once in Staking.sol, the rewards can be claimed by users who have deposited the
// relevant xSALT or LP (depending on if the rewards were deposited with isLP).
// Only stores the SALT rewards transferred in since the last upkeep.

contract RewardsEmitter is Upkeepable
    {
    // The stored SALT rewards by pool/isLP that need to be distributed to Staking.sol
    // Only a percentage of these will be distributed per day
   	mapping(address=>mapping(bool=>uint256)) pendingRewards;		// [poolID][isLP]

	RewardsConfig rewardsConfig;
	StakingConfig stakingConfig;
	Staking staking;


    constructor( address _rewardsConfig, address _stakingConfig, address _staking )
		{
		rewardsConfig = RewardsConfig( _rewardsConfig );
		stakingConfig = StakingConfig( _stakingConfig );
		staking = Staking( _staking );
		}


	function performUpkeep() internal override
		{
		uint256 timeSinceLastUpkeep = timeSinceLastUpkeep();
		if ( timeSinceLastUpkeep == 0 )
			return;

		address[] memory validPools = stakingConfig.whitelistedPools();

		// Construct the arrays for all poolIDs and the true/false isLP
		// poolID STAKING will never really appear with isLP=true, but we'll leave it in for simplicity
		address[] memory poolIDs = new address[]( validPools.length * 2 );
        bool[] memory areLP = new bool[]( poolIDs.length );

		// Half have areLP = true
        for( uint256 i = 0; i < validPools.length; i++ )
        	areLP[i] = true;

		// Cached for efficiency
		uint256 numeratorMult = timeSinceLastUpkeep * rewardsConfig.rewardsEmitterDailyPercent();
		uint256 denominatorMult = 100 days; // ( 100 percent ) * numberSecondsInOneDay

        uint256[] memory amountsToAdd = new uint256[]( poolIDs.length );
		for( uint256 i = 0; i < poolIDs.length; i++ )
			{
			address poolID = poolIDs[i];
			bool isLP = areLP[i];

			// Each poolID/isLP will send a percentage of the pending rewards
			amountsToAdd[i] = ( pendingRewards[poolID][isLP] * numeratorMult ) / denominatorMult;
			}

		staking.addSALTRewards( poolIDs, areLP, amountsToAdd );
		}
	}
