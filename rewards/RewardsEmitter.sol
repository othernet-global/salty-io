// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.12;

import "../Upkeepable.sol";
import "../staking/interfaces/IStakingConfig.sol";
import "../staking/interfaces/IStakingRewards.sol";
import "./interfaces/IRewardsConfig.sol";
import "../openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/ISalt.sol";


// Stores SALT rewards and distributes default 1% per day to a singular derived SharedRewards contract.
// There will be one RewardsEmitter for each contract derived from SharedRewards - namely Staking, Liquidity and Collateral.
// Staking - allows users to stake SALT and stake xSALT to cast votes for specific pools.
// Liquidity - allows liquidity providers to deposit and stake liquidity.
// Collateral - allows users to deposit and stake BTC/ETH liquidity as collateral for borrowing USDS stablecoin.

contract RewardsEmitter is Upkeepable
    {
	using SafeERC20 for ISalt;

    // The stored SALT rewards by pool that need to be distributed to a StakingRewards.sol contract
    // Only a percentage of these will be distributed per day (inerpolated to a default of 1% per day)
   	mapping(bytes32=>uint256) public pendingRewards;

	IExchangeConfig public exchangeConfig;
	IPoolsConfig public poolsConfig;
	IStakingConfig public stakingConfig;
	IRewardsConfig public rewardsConfig;

	IStakingRewards public stakingRewards;


    constructor( IExchangeConfig _exchangeConfig, IPoolsConfig _poolsConfig, IStakingConfig _stakingConfig, IRewardsConfig _rewardsConfig, IStakingRewards _stakingRewards )
		{
		require( address(_exchangeConfig) != address(0), "_exchangeConfig cannot be address(0)" );
		require( address(_poolsConfig) != address(0), "_poolsConfig cannot be address(0)" );
		require( address(_rewardsConfig) != address(0), "_rewardsConfig cannot be address(0)" );
		require( address(_stakingConfig) != address(0), "_stakingConfig cannot be address(0)" );
		require( address(_stakingRewards) != address(0), "_sharedRewards cannot be address(0)" );

		exchangeConfig = _exchangeConfig;
		poolsConfig = _poolsConfig;
		rewardsConfig = _rewardsConfig;
		stakingConfig = _stakingConfig;
		stakingRewards = _stakingRewards;

		// Make sure to approve SALT so that SALT rewards can be added to the StakingRewards
		exchangeConfig.salt().approve( address(stakingRewards), type(uint256).max );
		}


	// Rewards for later distribution on performUpkeep() can be added from any wallet
	function addSALTRewards( AddedReward[] memory addedRewards ) public nonReentrant
		{
		uint256 sum = 0;
		for( uint256 i = 0; i < addedRewards.length; i++ )
			{
			AddedReward memory addedReward = addedRewards[i];

			require( poolsConfig.isWhitelisted( addedReward.poolID ), "Invalid pool" );

			pendingRewards[ addedReward.poolID ] += addedReward.amountToAdd;
			sum = sum + addedReward.amountToAdd;
			}

		// Transfer the SALT from the caller for all of the specified rewards
		if ( sum > 0 )
			exchangeConfig.salt().safeTransferFrom( msg.sender, address(this), sum );
		}


	// Transfer a percent (default 1% per day) of the currently held rewards to the specified StakingRewards pools.
	// The percentage to transfer is interpolated from how long it's been since the last performUpkeep()
	function _performUpkeep() internal override
		{
		bytes32[] memory pools = poolsConfig.whitelistedPools();

		uint256 timeSinceLastUpkeep = timeSinceLastUpkeep();
		if ( timeSinceLastUpkeep == 0 )
			return;

		// Cap the timeSinceLastUpkeep at one day (if for some reason it has been longer).
		// This will cap the emitted rewards at a default of 1% in this transaction.
		if ( timeSinceLastUpkeep >= 1 days )
        	timeSinceLastUpkeep = 1 days;

		// One array for all the pools
		AddedReward[] memory addedRewards = new AddedReward[]( pools.length );

		// Cached for efficiency
		uint256 numeratorMult = timeSinceLastUpkeep * rewardsConfig.rewardsEmitterDailyPercentTimes1000();
		uint256 denominatorMult = 100 days * 1000; // simplification of ( 100 percent ) * numberSecondsInOneDay * 1000

		for( uint256 i = 0; i < pools.length; i++ )
			{
			bytes32 pool = pools[i];

			// Each pool will send a percentage of the pending rewards base donthe time since the last send
			uint256 amountToAddForPool = ( pendingRewards[pool] * numeratorMult ) / denominatorMult;

			if ( amountToAddForPool != 0 )
				pendingRewards[pool] -= amountToAddForPool;

			addedRewards[i] = AddedReward( pool, amountToAddForPool );
			}

		// Add the rewards so that they can later be claimed by the users proportional to their share of the StakingRewards derived contract( Staking, Liquidity or Collateral)
		stakingRewards.addSALTRewards( addedRewards );
		}


	// === VIEWS ===

	function pendingRewardsForPools( bytes32[] memory pools ) public view returns (uint256[] memory)
		{
		uint256[] memory rewards = new uint256[]( pools.length );

		for( uint256 i = 0; i < rewards.length; i++ )
			rewards[i] = pendingRewards[ pools[i] ];

		return rewards;
		}
	}
