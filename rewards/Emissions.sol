// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "../interfaces/ISalt.sol";
import "../interfaces/IExchangeConfig.sol";
import "./interfaces/IEmissions.sol";
import "../rewards/interfaces/IRewardsConfig.sol";


// Responsible for storing the SALT emissions at launch and then distributing them over time.
// The emissions are gradually distributed to the stakingRewardsEmitter and liquidityRewardsEmitter on performUpkeep (via the SaltRewards contract).
// Default rate of emissions is 0.50% of the remaining SALT balance per week (interpolated based on the time elapsed since the last performUpkeep call).

contract Emissions is IEmissions
    {
    IPools immutable public pools;
	IExchangeConfig immutable public exchangeConfig;
	IRewardsConfig immutable public rewardsConfig;
	ISalt immutable public salt;


    constructor( IPools _pools, IExchangeConfig _exchangeConfig, IRewardsConfig _rewardsConfig )
		{
		require( address(_pools) != address(0), "_pools cannot be address(0)" );
		require( address(_exchangeConfig) != address(0), "_exchangeConfig cannot be address(0)" );
		require( address(_rewardsConfig) != address(0), "_rewardsConfig cannot be address(0)" );

		pools = _pools;
		exchangeConfig = _exchangeConfig;
		rewardsConfig = _rewardsConfig;

		// Cached for efficiency
		salt = _exchangeConfig.salt();
		}


	// Transfer a percent (default 0.50% per week) of the currently held SALT to the stakingRewardsEmitter and liquidityRewardsEmitter (via SaltRewards).
	// The percentage to transfer is interpolated from how long it's been since the last performUpkeep() call.
	function performUpkeep(uint256 timeSinceLastUpkeep) public
		{
		require( msg.sender == address(exchangeConfig.dao()), "Emissions.performUpkeep only callable from the DAO contract" );

		if ( timeSinceLastUpkeep == 0 )
			return;

		// Cap the timeSinceLastUpkeep at one week (if for some reason it has been longer).
		// This will cap the emitted rewards at a default of 0.50% in this transaction.
		if ( timeSinceLastUpkeep >= 1 weeks )
			timeSinceLastUpkeep = 1 weeks;

		uint256 saltBalance = salt.balanceOf( address( this ) );

		// Target a certain percentage of rewards per week and base what we need to distribute now on how long it has been since the last distribution
		uint256 saltToSend = ( saltBalance * timeSinceLastUpkeep * rewardsConfig.emissionsWeeklyPercentTimes1000() ) / ( 100 * 1000 weeks );
		if ( saltToSend == 0 )
			return;

		salt.approve( address(pools), saltToSend );
		ISaltRewards(address(pools)).addSALTRewards(saltToSend);
		}
	}
