// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "../rewards/interfaces/IRewardsConfig.sol";
import "../pools/interfaces/IPoolsConfig.sol";
import "../interfaces/IExchangeConfig.sol";
import "./interfaces/IRewardsEmitter.sol";
import "../interfaces/ISalt.sol";
import "../pools/PoolUtils.sol";


// Stores SALT rewards for later distribution at a default rate of 1% per day to those holding shares in the specified StakingRewards contract.
// The gradual emissions rate is to help offset natural rewards fluctuation and create a more stable yield.
// This also creates an easy mechanism to see what the current yield is for any pool as the emitter acts like an exponential average of the incoming SALT rewards.
// There will be two deplyed RewardsEmitters:
// Staking.sol - allows users to stake SALT to acquire xSALT and distributes rewards to Staking.sol
// Liquidity.sol - allows liquidity providers to deposit and stake collateralAndLiquidity and distributes rewards to CollateralAndLiquidity.sol.
contract RewardsEmitter is IRewardsEmitter, ReentrancyGuard
    {
	using SafeERC20 for ISalt;

	IStakingRewards immutable public stakingRewards;
	IExchangeConfig immutable public exchangeConfig;
	IPoolsConfig immutable public poolsConfig;
	IRewardsConfig immutable public rewardsConfig;
	ISalt immutable public salt;
   	bool immutable isForCollateralAndLiquidity;

	uint256 constant public MAX_TIME_SINCE_LAST_UPKEEP = 1 days;

    // The stored SALT rewards by poolID that need to be distributed to the specified StakingRewards.sol contract.
    // Only a percentage of these will be distributed per day (interpolated to a default of 1% per day).
   	mapping(bytes32=>uint256) public pendingRewards;



    constructor( IStakingRewards _stakingRewards, IExchangeConfig _exchangeConfig, IPoolsConfig _poolsConfig, IRewardsConfig _rewardsConfig, bool _isForCollateralAndLiquidity )
		{
		stakingRewards = _stakingRewards;
		exchangeConfig = _exchangeConfig;
		poolsConfig = _poolsConfig;
		rewardsConfig = _rewardsConfig;
		isForCollateralAndLiquidity = _isForCollateralAndLiquidity;

		salt = _exchangeConfig.salt();

		// Save gas for later reward distribution by approving in advance
		salt.approve(address(stakingRewards), type(uint256).max);
		}


	// Add SALT rewards for later distribution to the specified whitelisted pools.
	// Specified SALT rewards are transfered from the sender.
	// Requires that rewarded pools are whitelisted.
	function addSALTRewards( AddedReward[] calldata addedRewards ) external nonReentrant
		{
		uint256 sum = 0;
		for( uint256 i = 0; i < addedRewards.length; i++ )
			{
			AddedReward memory addedReward = addedRewards[i];
			require( poolsConfig.isWhitelisted( addedReward.poolID ), "Invalid pool" );

			uint256 amountToAdd = addedReward.amountToAdd;
			if ( amountToAdd != 0 )
				{
				// Update pendingRewards so the SALT can be distributed later
				pendingRewards[ addedReward.poolID ] += amountToAdd;
				sum += amountToAdd;
				}
			}

		// Transfer the SALT from the sender for all of the specified rewards
		if ( sum > 0 )
			salt.safeTransferFrom( msg.sender, address(this), sum );
		}


	// Transfer a percent (default 1% per day) of the currently held rewards to the specified StakingRewards pools.
	// The percentage to transfer is interpolated from how long it's been since the last performUpkeep().
	function performUpkeep( uint256 timeSinceLastUpkeep ) external
		{
		require( msg.sender == address(exchangeConfig.upkeep()), "RewardsEmitter.performUpkeep is only callable from the Upkeep contract" );

		if ( timeSinceLastUpkeep == 0 )
			return;

		bytes32[] memory poolIDs;

		 if ( isForCollateralAndLiquidity )
		 	{
		 	// For the liquidityRewardsEmitter, all pools can receive rewards
			poolIDs = poolsConfig.whitelistedPools();
			}
		 else
		 	{
		 	// The stakingRewardsEmitter only distributes rewards to those that have staked SALT
		 	poolIDs = new bytes32[](1);
		 	poolIDs[0] = PoolUtils.STAKED_SALT;
		 	}

		// Cap the timeSinceLastUpkeep at one day (if for some reason it has been longer).
		// This will cap the emitted rewards at a default of 1% in this transaction.
		if ( timeSinceLastUpkeep >= MAX_TIME_SINCE_LAST_UPKEEP )
        	timeSinceLastUpkeep = MAX_TIME_SINCE_LAST_UPKEEP;

		// These are the AddedRewards that will be sent to the specified StakingRewards contract
		AddedReward[] memory addedRewards = new AddedReward[]( poolIDs.length );

		// Rewards to emit = pendingRewards * timeSinceLastUpkeep * rewardsEmitterDailyPercent / oneDay
		uint256 numeratorMult = timeSinceLastUpkeep * rewardsConfig.rewardsEmitterDailyPercentTimes1000();
		uint256 denominatorMult = 1 days * 100000; // simplification of numberSecondsInOneDay * (100 percent) * 1000

		uint256 sum = 0;
		for( uint256 i = 0; i < poolIDs.length; i++ )
			{
			bytes32 poolID = poolIDs[i];

			// Each pool will send a percentage of the pending rewards based on the time elapsed since the last send
			uint256 amountToAddForPool = ( pendingRewards[poolID] * numeratorMult ) / denominatorMult;

			// Reduce the pending rewards so they are not sent again
			if ( amountToAddForPool != 0 )
				{
				pendingRewards[poolID] -= amountToAddForPool;

				sum += amountToAddForPool;
				}

			// Specify the rewards that will be added for the specific pool
			addedRewards[i] = AddedReward( poolID, amountToAddForPool );
			}

		// Add the rewards so that they can later be claimed by the users proportional to their share of the StakingRewards derived contract.
		stakingRewards.addSALTRewards( addedRewards );
		}


	// === VIEWS ===

	function pendingRewardsForPools( bytes32[] calldata pools ) external view returns (uint256[] memory)
		{
		uint256[] memory rewards = new uint256[]( pools.length );

		for( uint256 i = 0; i < rewards.length; i++ )
			rewards[i] = pendingRewards[ pools[i] ];

		return rewards;
		}
	}
