// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.12;

import "../Upkeepable.sol";
import "../openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "../pools/interfaces/IPoolsConfig.sol";
import "../staking/interfaces/IStakingConfig.sol";
import "../rewards/interfaces/IRewardsConfig.sol";
import "../interfaces/IExchangeConfig.sol";
import "./interfaces/IRewardsEmitter.sol";
import "../interfaces/ISalt.sol";


// Stores SALT rewards for later distribution at a default rate of 1% per day to those holding shares in the specified StakingRewards contract.
// The gradual emissions rate is to help offset the natural rewards fluctuation and create a more stable yield.
// This also creates an easy mechanism to see what the current yield is for any pool as the emitter acts like an exponential average of the incoming SALT rewards.
// There will be one RewardsEmitter for each contract derived from StakingRewards.sol - namely Staking.sol, Liquidity.sol and Collateral.sol.
// Staking.sol - allows users to stake SALT to acquire xSALT and stake xSALT to cast votes for specific pools.
// Liquidity.sol - allows liquidity providers to deposit and stake liquidity.
// Collateral.sol - allows users to deposit and stake WBTC/WETH liquidity as collateral for borrowing USDS stablecoin.

contract RewardsEmitter is Upkeepable, IRewardsEmitter
    {
	using SafeERC20 for ISalt;

    // The stored SALT rewards by poolID that need to be distributed to the specified StakingRewards.sol contract.
    // Only a percentage of these will be distributed per day (interpolated to a default of 1% per day).
   	mapping(bytes32=>uint256) public pendingRewards;

	IStakingRewards public stakingRewards;

	IPoolsConfig public poolsConfig;
	IStakingConfig public stakingConfig;
	IRewardsConfig public rewardsConfig;

	ISalt public salt;


    constructor( IStakingRewards _stakingRewards, IExchangeConfig _exchangeConfig, IPoolsConfig _poolsConfig, IStakingConfig _stakingConfig, IRewardsConfig _rewardsConfig )
		{
		require( address(_stakingRewards) != address(0), "_stakingRewards cannot be address(0)" );
		require( address(_exchangeConfig) != address(0), "_exchangeConfig cannot be address(0)" );
		require( address(_poolsConfig) != address(0), "_poolsConfig cannot be address(0)" );
		require( address(_rewardsConfig) != address(0), "_rewardsConfig cannot be address(0)" );
		require( address(_stakingConfig) != address(0), "_stakingConfig cannot be address(0)" );

		stakingRewards = _stakingRewards;

		poolsConfig = _poolsConfig;
		stakingConfig = _stakingConfig;
		rewardsConfig = _rewardsConfig;

		salt = _exchangeConfig.salt();

		// Make sure to approve SALT so that SALT rewards can be added to the StakingRewards
		salt.approve( address(stakingRewards), type(uint256).max );
		}


	// Rewards for later distribution to the specified whitelisted pools.
	// Specified SALT rewards are transfered from the sender.
	function addSALTRewards( AddedReward[] memory addedRewards ) public nonReentrant
		{
		uint256 sum = 0;
		for( uint256 i = 0; i < addedRewards.length; i++ )
			{
			AddedReward memory addedReward = addedRewards[i];

			require( poolsConfig.isWhitelisted( addedReward.poolID ), "Invalid pool" );

			// Update pendingRewards so the SALT can be distributed later
			pendingRewards[ addedReward.poolID ] += addedReward.amountToAdd;
			sum = sum + addedReward.amountToAdd;
			}

		// Transfer the SALT from the sender for all of the specified rewards
		if ( sum > 0 )
			salt.safeTransferFrom( msg.sender, address(this), sum );
		}


	// Transfer a percent (default 1% per day) of the currently held rewards to the specified StakingRewards pools.
	// The percentage to transfer is interpolated from how long it's been since the last _performUpkeep().
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

		// These are the AddedRewards that will be sent to the specified StakingRewards contract
		AddedReward[] memory addedRewards = new AddedReward[]( pools.length );

		// Cached for efficiency
		// Rewards to emit = pendingRewards * dailyPercent * timeElapsed / oneDay
		uint256 numeratorMult = timeSinceLastUpkeep * rewardsConfig.rewardsEmitterDailyPercentTimes1000();
		uint256 denominatorMult = 100 days * 1000; // simplification of ( 100 percent ) * numberSecondsInOneDay * 1000

		for( uint256 i = 0; i < pools.length; i++ )
			{
			bytes32 poolID = pools[i];

			// Each pool will send a percentage of the pending rewards based on the time elapsed since the last send
			uint256 amountToAddForPool = ( pendingRewards[poolID] * numeratorMult ) / denominatorMult;

			// Reduce the pending rewards so they are not sent again
			if ( amountToAddForPool != 0 )
				pendingRewards[poolID] -= amountToAddForPool;

			// Specify the rewards that will be added for the specific pool
			addedRewards[i] = AddedReward( poolID, amountToAddForPool );
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
