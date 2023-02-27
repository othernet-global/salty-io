// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.17;


import "../openzeppelin/token/ERC20/ERC20.sol";
import "../staking/StakingConfig.sol";
import "../Upkeepable.sol";
import "./RewardsConfig.sol";
import "./VotedRewards.sol";
import "./RewardsEmitter.sol";


// Stores the SALT early unstake fees that happen when the user unstakes for less than the maximum time
// Only stores the SALT transferred in since the last upkeep.

contract EarlyUnstake is Upkeepable
    {
    StakingConfig stakingConfig;
    RewardsConfig rewardsConfig;
    address votedRewards;
	RewardsEmitter rewardsEmitter;


    constructor( address _stakingConfig, address _rewardsConfig, address _votedRewards, address _rewardsEmitter )
		{
		stakingConfig = StakingConfig( _stakingConfig );
		rewardsConfig = RewardsConfig( _rewardsConfig );
		votedRewards = _votedRewards;
		rewardsEmitter = RewardsEmitter( _rewardsEmitter );

		stakingConfig.salt().approve( _rewardsEmitter, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff );
		}


	function performUpkeep() internal override
		{
		ERC20 salt = stakingConfig.salt();

		uint256 saltBalance = stakingConfig.salt().balanceOf( address( this ) );

		uint256 votedRewardsAmount = ( saltBalance * rewardsConfig.earlyUnstake_votedRewardsPercent() ) / 100;
		uint256 xsaltHoldersAmount = saltBalance - votedRewardsAmount;

		// Send a portion to be distributed to pools proportional to pool votes received
		salt.transfer( address(votedRewards), votedRewardsAmount );

		// Send a portion to xSALT holders
		uint256[] memory poolIDs = new uint256[]( 1 );
		uint256[] memory areLPs = new uint256[]( 1 );
		uint256[] memory amountsToAdd = new uint256[]( 1 );

		poolIDs[0] = address(0); // STAKING pool
		areLPs[0] = false; // for xSALT holders
		amountsToAdd[0] = xsaltHoldersAmount;

		// Send the SALT to the RewardsEmitter
		rewardsEmitter.addSALTRewards( poolIDs, areLPs, amountsToAdd );
		}
	}
