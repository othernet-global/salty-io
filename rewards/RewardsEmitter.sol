// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.17;

import "../Upkeepable.sol";
import "../staking/Staking.sol";
import "../staking/StakingConfig.sol";
import "./RewardsConfig.sol";


// Stores SALT rewards and distributes them at a default rate of 10% per day to Staking.sol
// Once in Staking.sol, the rewards can be claimed by users who have deposited the
// relevant xSALT or LP (depending on if the rewards were deposited with isLP).

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

		stakingConfig.salt().approve( _staking, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff );
		}


	// Can be added from any wallet
	function addSALTRewards( address[] memory poolIDs, bool[] memory areLPs, uint256[] memory amountsToAdd ) public nonReentrant
		{
		require( ( poolIDs.length == areLPs.length )  && ( poolIDs.length == amountsToAdd.length), "RewardsEmitter: Array length mismatch" );

		address wallet = msg.sender;

		uint256 sum = 0;
		for( uint256 i = 0; i < poolIDs.length; i++ )
			{
			address poolID = poolIDs[i];
			require( stakingConfig.isValidPool( poolID ), "RewardsEmitter: Invalid poolID" );

			uint256 amountToAdd = amountsToAdd[i];

			pendingRewards[ poolID ][ areLPs[i] ] += amountToAdd;
			sum = sum + amountToAdd;
			}

		// Transfer in the SALT for all the specified rewards
		if ( sum > 0 )
			stakingConfig.salt().transferFrom( wallet, address(this), sum );
		}


	// Helper function
	function addSALTRewards( address poolID, bool isLP, uint256 amountToAdd ) public
		{
		address[] memory poolIDs = new address[]( 1 );
		bool[] memory areLPs = new bool[]( 1 );
		uint256[] memory amountsToAdd = new uint256[]( 1 );

		poolIDs[0] = poolID;
		areLPs[0] = isLP;
		amountsToAdd[0] = amountToAdd;

		addSALTRewards( poolIDs, areLPs, amountsToAdd );
		}



	// Transfer a percent (default 10% per day) of the currently held rewards to Staking.sol where users can then claim them.
	// The percentage to transfer is interpolated from how long it's been since the last performUpkeep()
	function performUpkeep() internal override
		{
		uint256 timeSinceLastUpkeep = timeSinceLastUpkeep();
		if ( timeSinceLastUpkeep == 0 )
			return;

		address[] memory validPools = stakingConfig.whitelistedPools();

		// Construct the arrays for all poolIDs and the true/false isLP
		// The very last one will be for [0][false] - which specifies generic staked SALT
		address[] memory poolIDs = new address[]( validPools.length * 2 + 1 );
        bool[] memory areLPs = new bool[]( validPools.length * 2 + 1 );

		// Setup the arrays
		uint256 index = 0;
        for( uint256 i = 0; i < validPools.length; i++ )
        	{
        	address poolID = validPools[i];

        	poolIDs[index] = poolID;
        	areLPs[index++] = true; // Half have areLPs = true

        	poolIDs[index] = poolID;
        	areLPs[index++] = false; // Half have areLPs = false
        	}

		// Cached for efficiency
		uint256 numeratorMult = timeSinceLastUpkeep * rewardsConfig.rewardsEmitterDailyPercent();
		uint256 denominatorMult = 100 days; // ( 100 percent ) * numberSecondsInOneDay

		// Don't allow for more than 100 percent (if it's been a long time since the last update for some reason)
		if ( numeratorMult > denominatorMult )
			numeratorMult = denominatorMult;

        uint256[] memory amountsToAdd = new uint256[]( poolIDs.length );
		for( uint256 i = 0; i < poolIDs.length; i++ )
			{
			address poolID = poolIDs[i];
			bool isLP = areLPs[i];

			// Each poolID/isLP will send a percentage of the pending rewards
			uint256 amountToAddForPool = ( pendingRewards[poolID][isLP] * numeratorMult ) / denominatorMult;

			if ( amountToAddForPool != 0 )
				{
				pendingRewards[poolID][isLP] -= amountToAddForPool;
				amountsToAdd[i] = amountToAddForPool;
				}
			}

		// Send the SALT rewards to Staking.sol so that users can claim it based on the
		// amount of xSALT or LP they have staked
		staking.addSALTRewards( poolIDs, areLPs, amountsToAdd );
		}


	// DEBUG
	function returnPendingRewards( address poolID, bool isLP ) public view returns (uint256)
		{
		return pendingRewards[poolID][isLP];
		}
	}
