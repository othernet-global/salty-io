// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.12;

import "../openzeppelin/security/ReentrancyGuard.sol";
import "../openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "../openzeppelin/utils/math/Math.sol";
import "./interfaces/IStakingConfig.sol";
import "./interfaces/IStakingRewards.sol";
import "../interfaces/ISalt.sol";
import "../interfaces/IExchangeConfig.sol";
import "../pools/interfaces/IPoolsConfig.sol";

// This contract allows users to receive rewards (as SALT tokens) for staking shares (which can represent different things as explained below).
// A user's reward is proportional to their share of the stake and is based on their share at the time that rewards are added.
//
// What staked shares represent is specific to the contracts that derive from StakingRewards.
//
// Some examples of what a user's share represents:
// 1. Staking.sol: the amount of SALT staked (staked to the STAKED_SALT pool)
//						 and the amount of xSALT staked (voting) for whitelisted pools
// 2. Liquidity.sol: the amount of LP tokens deposited and staked to specific pools
// 3. Collateral.sol: the amount of WBTC/WETH liquidity deposited as stablecoin collateral

contract StakingRewards is IStakingRewards, ReentrancyGuard
    {
	event eIncreaseShare(address indexed wallet, bytes32 indexed poolID, uint256 amount);
	event eDecreaseShareAndClaim(address indexed wallet, bytes32 indexed poolID, uint256 amount);
	event eClaimRewards(address indexed wallet, bytes32 indexed poolID, uint256 amount);
	event eClaimAllRewards(address indexed wallet, uint256 amount);

	using SafeERC20 for ISalt;


	// The SALT token which will be used for the claimable rewards
	ISalt public salt;

	IExchangeConfig public immutable exchangeConfig;
    IStakingConfig public immutable stakingConfig;
    IPoolsConfig public immutable poolsConfig;

	// A nested mapping that stores the UserShareInfo data for each user and each poolID.
	mapping(address=>mapping(bytes32=>UserShareInfo)) public userPoolInfo;

    // A mapping that stores the total SALT rewards for each poolID.
    mapping(bytes32=>uint256) public totalRewards;

    // A mapping that stores the total shares for each poolID.
    mapping(bytes32=>uint256) public totalShares;

	// A special pool that represents staked SALT that is not associated with any particular pool.
	bytes32 public constant STAKED_SALT = bytes32(0);


	// Constructs a new StakingRewards contract with providing configs
 	constructor( IExchangeConfig _exchangeConfig, IPoolsConfig _poolsConfig, IStakingConfig _stakingConfig )
		{
		require( address(_exchangeConfig) != address(0), "_exchangeConfig cannot be address(0)" );
		require( address(_poolsConfig) != address(0), "_poolsConfig cannot be address(0)" );
		require( address(_stakingConfig) != address(0), "_stakingConfig cannot be address(0)" );

		exchangeConfig = _exchangeConfig;
    	poolsConfig = _poolsConfig;
		stakingConfig = _stakingConfig;

		salt = _exchangeConfig.salt(); // cached for efficiency
        }


	// Increase a user's share for the given whitelisted pool.
	// Requires exchange access for the sender
	function _increaseUserShare( address wallet, bytes32 poolID, uint256 amountToIncrease, bool useCooldown ) internal
		{
		require( poolsConfig.isWhitelisted( poolID ), "Invalid pool" );
		require( amountToIncrease != 0, "Cannot increase zero share" );
		require( exchangeConfig.walletHasAccess(msg.sender), "Sending wallet does not have exchange access" );

		UserShareInfo storage user = userPoolInfo[wallet][poolID];

		if ( useCooldown )
			require( block.timestamp >= user.cooldownExpiration, "Must wait for the cooldown to expire" );

		uint256 existingTotalShares = totalShares[poolID];

		// Determine the virtualRewards added based on the current ratio of rewards/shares.
		// This allows shares to be added and the ratio of rewards/shares to remain unchanged (with proportional virtual rewards being added).
		// The virtual rewards will be deducted later when calculating the user's owed rewards.
        if ( existingTotalShares != 0 ) // prevent / 0
        	{
			// Round up in favor of the protocol.
			uint256 virtualRewardsToAdd = Math.ceilDiv( totalRewards[poolID] * amountToIncrease, existingTotalShares );

			user.virtualRewards += virtualRewardsToAdd;
	        totalRewards[poolID] += virtualRewardsToAdd;
	        }

		// Update the deposit balances
		user.userShare += amountToIncrease;
		totalShares[poolID] = existingTotalShares + amountToIncrease;

		// Update the cooldown expiration
		if ( useCooldown )
			user.cooldownExpiration = block.timestamp + stakingConfig.modificationCooldown();

        emit eIncreaseShare( wallet, poolID, amountToIncrease );
		}


	// Decrease a user's share for the pool and have any pending rewards sent to them.
	// Does not require the pool to be valid (in case the pool was recently unwhitelisted)
	// Does not require exchange access for the sender in case they have assets they need to withdraw and were are not whitelisted
	function _decreaseUserShare( address wallet, bytes32 poolID, uint256 amountToDecrease, bool useCooldown ) internal
		{
		require( amountToDecrease != 0, "Cannot decrease zero share" );

		UserShareInfo storage user = userPoolInfo[wallet][poolID];
		require( amountToDecrease <= user.userShare, "Cannot decrease more than existing user share" );

		if ( useCooldown )
			require( block.timestamp >= user.cooldownExpiration, "Must wait for the cooldown to expire" );

		// Determine the share of the rewards for the amountToDecrease (will include previously added virtual rewards)
		uint256 rewardsForAmount = ( totalRewards[poolID] * amountToDecrease ) / totalShares[poolID];

		// For the amountToDecrease determine the proportion of virtualRewards (proportional to all virtualRewards for the user)
		// Round up in favor of the protocol
		uint256 virtualRewardsToRemove = Math.ceilDiv( user.virtualRewards * amountToDecrease, user.userShare );

		// Update totals
		totalRewards[poolID] -= rewardsForAmount;
		totalShares[poolID] -= amountToDecrease;

		// Update the user's share and virtual rewards
		user.userShare -= amountToDecrease;
		user.virtualRewards -= virtualRewardsToRemove;

		// Reduce the rewards by the amount of virtualRewards for the given amountRemoved
		uint256 actualRewards = rewardsForAmount - virtualRewardsToRemove;

		// Send the actual rewards corresponding to the removal
		if ( actualRewards != 0 )
			{
			// This error should never happen
			require( salt.balanceOf(address(this)) >= actualRewards, "Insufficient SALT balance to send pending rewards" );

			salt.safeTransfer( wallet, actualRewards );
			}

		// Update the cooldown expiration
		if ( useCooldown )
			user.cooldownExpiration = block.timestamp + stakingConfig.modificationCooldown();

   	    emit eDecreaseShareAndClaim( wallet, poolID, actualRewards );
		}


	// ===== PUBLIC FUNCTIONS =====

	// Claims all available SALT rewards from multiple pools for the user.
	// The claimed rewards are added to the user's virtual rewards balance - so that they can't be claimed again later.
     function claimAllRewards( bytes32[] memory poolIDs ) public nonReentrant
    	{
		mapping(bytes32=>UserShareInfo) storage userInfo = userPoolInfo[msg.sender];

    	uint256 sum = 0;
		for( uint256 i = 0; i < poolIDs.length; i++ )
			{
			bytes32 poolID = poolIDs[i];

			uint256 pendingRewards = userPendingReward( msg.sender, poolID );

			// Increase the virtualRewards balance for the user to account for them receiving the rewards
			userInfo[poolID].virtualRewards += pendingRewards;

			sum = sum + pendingRewards;
			}

		// This error should never happen
		require( salt.balanceOf(address(this)) >= sum, "Insufficient SALT balance to send claimed rewards" );

		// Send the actual rewards
		salt.safeTransfer( msg.sender, sum );

   	    emit eClaimAllRewards( msg.sender, sum );
    	}


	// Adds SALT rewards for specific whitelisted pools.
	// There is some risk of addSALTRewards being front run, but there are multiple mechanisms in place to prevent this from being effective.
	// 1. There is a cooldown period of default one hour before shares can be modified once deposited.
	// 2. Staked SALT (required for voting on pools and receiving staking rewards) has a default unstake period of 6 months.
	// 3. Rewards are first placed into a RewardsEmitter which deposits rewards via addSALTRewards at the default rate of 1% per day.
	// 4. Rewards are deposited fairly quickly, with outstanding rewards being transferred within the global performUpkeep function,
	//      which will be called at least every 15 minutes - but likely more often.
	// Example: if $100k rewards were being deposited in a bulk transaction, it would only equate
	// to $1000 (1%) the first day, or $10 in claimable rewards during a 15 minute upkeep period.
 	function addSALTRewards( AddedReward[] memory addedRewards ) public nonReentrant
		{
		uint256 sum = 0;
		for( uint256 i = 0; i < addedRewards.length; i++ )
			{
			AddedReward memory addedReward = addedRewards[i];

			bytes32 poolID = addedReward.poolID;
			require( poolsConfig.isWhitelisted( poolID ), "Invalid pool" );

			uint256 amountToAdd = addedReward.amountToAdd;

			totalRewards[ poolID ] += amountToAdd;
			sum = sum + amountToAdd;
			}

		// Transfer in the SALT for all the specified rewards
		if ( sum > 0 )
			{
			// Transfer the SALT rewards from the sender
			salt.safeTransferFrom( msg.sender, address(this), sum );
			}
		}


	// ===== VIEWS =====

	// Returns the total shares for specified pools.
	function totalSharesForPools( bytes32[] memory poolIDs ) public view returns (uint256[] memory shares)
		{
		shares = new uint256[]( poolIDs.length );

		for( uint256 i = 0; i < shares.length; i++ )
			shares[i] = totalShares[ poolIDs[i] ];
		}


	// Convenience functino of above
	function totalSharesForPool( bytes32 poolID ) public view returns (uint256)
		{
		bytes32[] memory _pools = new bytes32[](1);
		_pools[0] = poolID;

		return totalSharesForPools(_pools)[0];
		}


	// Returns the total rewards for specified pools.
	function totalRewardsForPools( bytes32[] memory poolIDs ) public view returns (uint256[] memory rewards)
		{
		rewards = new uint256[]( poolIDs.length );

		for( uint256 i = 0; i < rewards.length; i++ )
			rewards[i] = totalRewards[ poolIDs[i] ];
		}


	// Returns the user's pending rewards for a specified pool.
	function userPendingReward( address wallet, bytes32 poolID ) public view returns (uint256)
		{
		// If there are no shares for the pool, the user can't have any shares either and there can't be any rewards
		if ( totalShares[poolID] == 0 )
			return 0;

		UserShareInfo memory user = userPoolInfo[wallet][poolID];
		if ( user.userShare == 0 )
			return 0;

		// Determine the share of the rewards for the user based on their deposited share
		uint256 rewardsShare = ( totalRewards[poolID] * user.userShare ) / totalShares[poolID];

		// Reduce by the virtualRewards - as they were only added to keep the share / rewards ratio the same when the used added their share
		return rewardsShare - user.virtualRewards;
		}


	// Returns the user's pending rewards for specified pools.
	function userRewardsForPools( address wallet, bytes32[] memory poolIDs ) public view returns (uint256[] memory rewards)
		{
		rewards = new uint256[]( poolIDs.length );

		for( uint256 i = 0; i < rewards.length; i++ )
			rewards[i] = userPendingReward( wallet, poolIDs[i] );
		}


	// Get the user's shares for specified pools.
	function userShareForPools( address wallet, bytes32[] memory poolIDs ) public view returns (uint256[] memory shares)
		{
		shares = new uint256[]( poolIDs.length );

		mapping(bytes32=>UserShareInfo) storage userInfo = userPoolInfo[wallet];

		for( uint256 i = 0; i < shares.length; i++ )
			shares[i] = userInfo[ poolIDs[i] ].userShare;
		}


	// Get the cooldown time remaining for the user for specified pools.
	function userCooldowns( address wallet, bytes32[] memory poolIDs ) public view returns (uint256[] memory cooldowns)
		{
		cooldowns = new uint256[]( poolIDs.length );

		mapping(bytes32=>UserShareInfo) storage userInfo = userPoolInfo[wallet];

		for( uint256 i = 0; i < cooldowns.length; i++ )
			{
			uint256 cooldownExpiration = userInfo[ poolIDs[i] ].cooldownExpiration;

			if ( block.timestamp >= cooldownExpiration )
				cooldowns[i] = 0;
			else
				cooldowns[i] = cooldownExpiration - block.timestamp;
			}
		}


	// Return a user's UserShareInfo for a given pool
	function userShareInfoForPool( address wallet, bytes32 poolID ) public view returns (UserShareInfo memory)
		{
		return userPoolInfo[wallet][poolID];
		}
	}