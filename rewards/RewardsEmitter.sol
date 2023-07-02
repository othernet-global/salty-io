//// SPDX-License-Identifier: BSL 1.1
//pragma solidity ^0.8.12;
//
//import "../Upkeepable.sol";
//import "../staking/interfaces/IStakingConfig.sol";
//import "../staking/interfaces/IStakingRewards.sol";
//import "../uniswap/core/interfaces/IUniswapV2Pair.sol";
//import "./interfaces/IRewardsConfig.sol";
//
//
//// Stores SALT rewards and distributes default 1% per day to a singular derived SharedRewards contract.
//// There will be one RewardsEmitter for each contract derived from SharedRewards - namely Staking, Liquidity and Collateral.
//// Staking - allows users to stake SALT and stake xSALT to cast votes for specific pools.
//// Liquidity - allows liquidity providers to stake LP tokens.
//// Collateral - allows users to stake BTC/ETH LP as collateral for borrowing USDS stablecoin.
//
//contract RewardsEmitter is Upkeepable
//    {
//	using SafeERC20 for ISalt;
//
//    // The stored SALT rewards by pool that need to be distributed to a StakingRewards.sol contract
//    // Only a percentage of these will be distributed per day (inerpolated to a default of 1% per day)
//   	mapping(IUniswapV2Pair=>uint256) public pendingRewards;
//
//	IRewardsConfig public rewardsConfig;
//	IStakingConfig public stakingConfig;
//	IStakingRewards public sharedRewards;
//
//
//    constructor( IRewardsConfig _rewardsConfig, IStakingConfig _stakingConfig, IStakingRewards _sharedRewards )
//		{
//		require( address(_rewardsConfig) != address(0), "_rewardsConfig cannot be address(0)" );
//		require( address(_stakingConfig) != address(0), "_stakingConfig cannot be address(0)" );
//		require( address(_sharedRewards) != address(0), "_sharedRewards cannot be address(0)" );
//
//		rewardsConfig = _rewardsConfig;
//		stakingConfig = _stakingConfig;
//		sharedRewards = _sharedRewards;
//
//		// Make sure to approve SALT so that SALT rewards can be added to sharedRewards
//		stakingConfig.salt().approve( address(sharedRewards), type(uint256).max );
//		}
//
//
//	// Rewards for later distribution on performUpkeep() can be added from any wallet
//	function addSALTRewards( AddedReward[] memory addedRewards ) public nonReentrant
//		{
//		uint256 sum = 0;
//		for( uint256 i = 0; i < addedRewards.length; i++ )
//			{
//			AddedReward memory addedReward = addedRewards[i];
//
//			IUniswapV2Pair pool = addedReward.pool;
//			require( stakingConfig.isValidPool( pool ), "Invalid pool" );
//
//			uint256 amountToAdd = addedReward.amountToAdd;
//
//			pendingRewards[ pool ] += amountToAdd;
//			sum = sum + amountToAdd;
//			}
//
//		// Transfer the SALT from the caller for all of the specified rewards
//		if ( sum > 0 )
//			{
//			require( stakingConfig.salt().allowance(msg.sender, address(this)) >= sum, "Insufficient allowance to add rewards" );
//			require( stakingConfig.salt().balanceOf(msg.sender) >= sum, "Insufficient SALT balance to add rewards" );
//			stakingConfig.salt().safeTransferFrom( msg.sender, address(this), sum );
//			}
//		}
//
//
//	// Transfer a percent (default 1% per day) of the currently held rewards to the specified SharedRewards pools.
//	// The percentage to transfer is interpolated from how long it's been since the last performUpkeep()
//	function _performUpkeep() internal override
//		{
//		IUniswapV2Pair[] memory pools = stakingConfig.whitelistedPools();
//
//		uint256 timeSinceLastUpkeep = timeSinceLastUpkeep();
//		if ( timeSinceLastUpkeep == 0 )
//			return;
//
//		// Cap the timeSinceLastUpkeep at one day (if for some reason it has been longer).
//		// This will cap the emitted rewards at a default of 1% in this transaction.
//		if ( timeSinceLastUpkeep >= 1 days )
//        	timeSinceLastUpkeep = 1 days;
//
//		// One array for all the pools
//		AddedReward[] memory addedRewards = new AddedReward[]( pools.length );
//
//		// Cached for efficiency
//		uint256 numeratorMult = timeSinceLastUpkeep * rewardsConfig.rewardsEmitterDailyPercentTimes1000();
//		uint256 denominatorMult = 100 days * 1000; // simplification of ( 100 percent ) * numberSecondsInOneDay * 1000
//
//		for( uint256 i = 0; i < pools.length; i++ )
//			{
//			IUniswapV2Pair pool = pools[i];
//
//			// Each pool/isLP will send a percentage of the pending rewards
//			uint256 amountToAddForPool = ( pendingRewards[pool] * numeratorMult ) / denominatorMult;
//
//			if ( amountToAddForPool != 0 )
//				pendingRewards[pool] -= amountToAddForPool;
//
//			addedRewards[i] = AddedReward( pool, amountToAddForPool );
//			}
//
//		// Add the rewards so that they can later be claimed by the users proportional to their share
//		// of the derived SharedRewards contract (Staking.sol, Liquidity.sol or Collateral.sol)
//		sharedRewards.addSALTRewards( addedRewards );
//		}
//
//
//	// === VIEWS ===
//
//	function pendingRewardsForPools( IUniswapV2Pair[] memory pools ) public view returns (uint256[] memory)
//		{
//		uint256[] memory rewards = new uint256[]( pools.length );
//
//		for( uint256 i = 0; i < rewards.length; i++ )
//			rewards[i] = pendingRewards[ pools[i] ];
//
//		return rewards;
//		}
//	}
