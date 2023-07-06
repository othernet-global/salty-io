//// SPDX-License-Identifier: BSL 1.1
//pragma solidity ^0.8.12;
//
//import "../uniswap/core/interfaces/IUniswapV2Pair.sol";
//import "../openzeppelin/token/ERC20/IERC20.sol";
//import "../Upkeepable.sol";
//import "../staking/interfaces/IStakingConfig.sol";
//import "../staking/interfaces/IStakingRewards.sol";
//import "./RewardsConfig.sol";
//import "./RewardsEmitter.sol";
//
//
//// Responsible for storing the SALT emissions at launch and then distributing them over time.
//// Default rate of emissions is 0.50% of the remaining SALT balance per week.
//
//contract Emissions is Upkeepable
//    {
//	IStakingConfig public stakingConfig;
//	IStakingRewards public staking;
//
//	RewardsConfig public rewardsConfig;
//	RewardsEmitter public stakingRewardsEmitter;
//	RewardsEmitter public liquidityRewardsEmitter;
//
//	// A special pool that represents staked SALT that is not associated with any particular pool.
//	IUniswapV2Pair public constant STAKED_SALT = IUniswapV2Pair(address(0));
//
//
//    constructor( IStakingConfig _stakingConfig, RewardsConfig _rewardsConfig, IStakingRewards _staking, RewardsEmitter _stakingRewardsEmitter, RewardsEmitter _liquidityRewardsEmitter )
//		{
//		require( address(_stakingConfig) != address(0), "_stakingConfig cannot be address(0)" );
//		require( address(_rewardsConfig) != address(0), "_rewardsConfig cannot be address(0)" );
//		require( address(_staking) != address(0), "_staking cannot be address(0)" );
//		require( address(_stakingRewardsEmitter) != address(0), "_stakingRewardsEmitter cannot be address(0)" );
//		require( address(_liquidityRewardsEmitter) != address(0), "_liquidityRewardsEmitter cannot be address(0)" );
//
//		stakingConfig = _stakingConfig;
//		staking = _staking;
//
//		rewardsConfig = _rewardsConfig;
//		stakingRewardsEmitter = _stakingRewardsEmitter;
//		liquidityRewardsEmitter = _liquidityRewardsEmitter;
//
//		// Approve SALT so rewards can be added to the rewardEmitters from this contract
//		ISalt salt = stakingConfig.salt();
//		salt.approve( address(stakingRewardsEmitter), type(uint256).max );
//		salt.approve( address(liquidityRewardsEmitter), type(uint256).max );
//		}
//
//
//	// Transfer the specified amount of SALT rewards from this contract to the whitelisted pools.
//	// The rewards will be sent proportionally to the number of votes received by each pool
//	function _performUpkeepForLiquidityHolderEmissions( uint256 amountToSend ) internal
//		{
//		IUniswapV2Pair[] memory pools = stakingConfig.whitelistedPools();
//
//		// Based on the xSALT shares (which act as votes) for each pool,
//		// send a proportional amount of rewards to RewardsEmitter.sol for each pool so that they can gradually be distributed
//		uint256[] memory votesForPools = staking.totalSharesForPools( pools );
//
//		// Determine the total pool votes so we can calculate pool percentages
//		uint256 totalPoolVotes = 0;
//		for( uint256 i = 0; i < votesForPools.length; i++ )
//			totalPoolVotes += votesForPools[i];
//
//		// Make sure some votes have been cast
//		if ( totalPoolVotes == 0 )
//			return;
//
//		// Send amountToSend SALT proportional to the votes received by each pool
//		AddedReward[] memory addedRewards = new AddedReward[]( votesForPools.length );
//		for( uint256 i = 0; i < addedRewards.length; i++ )
//			{
//			uint256 rewardsForPool = ( amountToSend * votesForPools[i] ) / totalPoolVotes;
//
//			addedRewards[i] = AddedReward( pools[i], rewardsForPool );
//			}
//
//		// Send the SALT rewards to the LiquidityRewardsEmitter for the liquidity providers
//		liquidityRewardsEmitter.addSALTRewards( addedRewards );
//		}
//
//
//	// Transfer a percent (default 0.50% per week) of the currently held SALT to stakingRewardsEmitter and liquidityRewardsEmitter
//	// The percentage to transfer is interpolated from how long it's been since the last performUpkeep()
//	function _performUpkeep() internal override
//		{
//		uint256 saltBalance = stakingConfig.salt().balanceOf( address( this ) );
//
//		uint256 timeSinceLastUpkeep = timeSinceLastUpkeep();
//		if ( timeSinceLastUpkeep == 0 )
//			return;
//
//		// Cap the timeSinceLastUpkeep at one week (if for some reason it has been longer).
//		// This will cap the emitted rewards at a default of 0.50% in this transaction.
//		if ( timeSinceLastUpkeep >= 1 weeks )
//			timeSinceLastUpkeep = 1 weeks;
//
//		// Target a certain percentage of rewards per week and base what we need to distribute now on how long it has been since the last distribution
//		uint256 saltToSend = ( saltBalance * timeSinceLastUpkeep * rewardsConfig.emissionsWeeklyPercentTimes1000() ) / ( 100 * 1000 weeks );
//
//		if ( saltToSend == 0 )
//			return;
//
//		// Split the emissions between xSALT Holders and Liquidity Providers
//		uint256 xsaltHoldersAmount = ( saltToSend * rewardsConfig.emissionsXSaltHoldersPercent() ) / 100;
//		uint256 liquidityHoldersRewardsAmount = saltToSend - xsaltHoldersAmount;
//
//		// Send SALT rewards to the StakingRewardsEmitter
//		AddedReward[] memory addedRewards = new AddedReward[](1);
//		addedRewards[0] = AddedReward( STAKED_SALT, xsaltHoldersAmount );
//		stakingRewardsEmitter.addSALTRewards( addedRewards );
//
//		// Send the remaining SALT rewards to the liquidity providers (proportional to the votes received by each pool)
//		_performUpkeepForLiquidityHolderEmissions( liquidityHoldersRewardsAmount );
//		}
//	}
