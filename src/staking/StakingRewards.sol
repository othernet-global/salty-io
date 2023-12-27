// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "openzeppelin-contracts/contracts/utils/math/Math.sol";
import "../pools/interfaces/IPoolsConfig.sol";
import "../interfaces/IExchangeConfig.sol";
import "./interfaces/IStakingRewards.sol";
import "./interfaces/IStakingConfig.sol";
import "../interfaces/ISalt.sol";

// This contract allows users to receive rewards (as SALT tokens) for staking SALT or liquidity shares.
// A user's reward is proportional to their share of the stake and is based on their share at the time that rewards are added.
//
// What staked shares represent is specific to the contracts that derive from StakingRewards.
//
// 1. Staking.sol: shares represent the amount of SALT staked (staked to the STAKED_SALT pool)
// 2. Liquidity.sol: shares represent the amount of liquidity deposited and staked to specific pools

abstract contract StakingRewards is IStakingRewards, ReentrancyGuard
    {
	event UserShareIncreased(address indexed wallet, bytes32 indexed poolID, uint256 amountIncreased);
	event UserShareDecreased(address indexed wallet, bytes32 indexed poolID, uint256 amountDecreased, uint256 claimedRewards);
	event RewardsClaimed(address indexed wallet, uint256 claimedRewards);
	event SaltRewardsAdded(bytes32 indexed poolID, uint256 amountAdded);

	using SafeERC20 for ISalt;

	ISalt immutable public salt;
	IExchangeConfig immutable public exchangeConfig;
    IStakingConfig immutable public stakingConfig;
    IPoolsConfig immutable public poolsConfig;

	// A nested mapping that stores the UserShareInfo data for each user and each poolID.
	mapping(address=>mapping(bytes32=>UserShareInfo)) private _userShareInfo;

    // A mapping that stores the total pending SALT rewards for each poolID.
    mapping(bytes32=>uint256) public totalRewards;

    // A mapping that stores the total shares for each poolID.
    mapping(bytes32=>uint256) public totalShares;


	// Constructs a new StakingRewards contract with providing configs
 	constructor( IExchangeConfig _exchangeConfig, IPoolsConfig _poolsConfig, IStakingConfig _stakingConfig )
		{
		exchangeConfig = _exchangeConfig;
    	poolsConfig = _poolsConfig;
		stakingConfig = _stakingConfig;

		salt = _exchangeConfig.salt(); // cached for efficiency
        }


	// Increase a user's share for the given whitelisted pool.
	function _increaseUserShare( address wallet, bytes32 poolID, uint256 increaseShareAmount, bool useCooldown ) internal
		{
		require( poolsConfig.isWhitelisted( poolID ), "Invalid pool" );
		require( increaseShareAmount != 0, "Cannot increase zero share" );

		UserShareInfo storage user = _userShareInfo[wallet][poolID];

		if ( useCooldown )
		if ( msg.sender != address(exchangeConfig.dao()) ) // DAO doesn't use the cooldown
			{
			require( block.timestamp >= user.cooldownExpiration, "Must wait for the cooldown to expire" );

			// Update the cooldown expiration for future transactions
			user.cooldownExpiration = block.timestamp + stakingConfig.modificationCooldown();
			}

		uint256 existingTotalShares = totalShares[poolID];

		// Determine the amount of virtualRewards to add based on the current ratio of rewards/shares.
		// The ratio of virtualRewards/increaseShareAmount is the same as totalRewards/totalShares for the pool.
		// The virtual rewards will be deducted later when calculating the user's owed rewards.
        if ( existingTotalShares != 0 ) // prevent / 0
        	{
			// Round up in favor of the protocol.
			uint256 virtualRewardsToAdd = Math.ceilDiv( totalRewards[poolID] * increaseShareAmount, existingTotalShares );

			user.virtualRewards += uint128(virtualRewardsToAdd);
	        totalRewards[poolID] += uint128(virtualRewardsToAdd);
	        }

		// Update the deposit balances
		user.userShare += uint128(increaseShareAmount);
		totalShares[poolID] = existingTotalShares + increaseShareAmount;

		emit UserShareIncreased(wallet, poolID, increaseShareAmount);
		}


	// Decrease a user's share for the pool and have any pending rewards sent to them.
	// Does not require the pool to be valid (in case the pool was recently unwhitelisted).
	function _decreaseUserShare( address wallet, bytes32 poolID, uint256 decreaseShareAmount, bool useCooldown ) internal
		{
		require( decreaseShareAmount != 0, "Cannot decrease zero share" );

		UserShareInfo storage user = _userShareInfo[wallet][poolID];
		require( decreaseShareAmount <= user.userShare, "Cannot decrease more than existing user share" );

		if ( useCooldown )
		if ( msg.sender != address(exchangeConfig.dao()) ) // DAO doesn't use the cooldown
			{
			require( block.timestamp >= user.cooldownExpiration, "Must wait for the cooldown to expire" );

			// Update the cooldown expiration for future transactions
			user.cooldownExpiration = block.timestamp + stakingConfig.modificationCooldown();
			}

		// Determine the share of the rewards for the amountToDecrease (will include previously added virtual rewards)
		uint256 rewardsForAmount = ( totalRewards[poolID] * decreaseShareAmount ) / totalShares[poolID];

		// For the amountToDecrease determine the proportion of virtualRewards (proportional to all virtualRewards for the user)
		// Round virtualRewards down in favor of the protocol
		uint256 virtualRewardsToRemove = (user.virtualRewards * decreaseShareAmount) / user.userShare;

		// Update totals
		totalRewards[poolID] -= rewardsForAmount;
		totalShares[poolID] -= decreaseShareAmount;

		// Update the user's share and virtual rewards
		user.userShare -= uint128(decreaseShareAmount);
		user.virtualRewards -= uint128(virtualRewardsToRemove);

		uint256 claimableRewards = 0;

		// Some of the rewardsForAmount are actually virtualRewards and can't be claimed.
		// In the event that virtualRewards are greater than actual rewards - claimableRewards will stay zero.
		if ( virtualRewardsToRemove < rewardsForAmount )
			claimableRewards = rewardsForAmount - virtualRewardsToRemove;

		// Send the claimable rewards
		if ( claimableRewards != 0 )
			salt.safeTransfer( wallet, claimableRewards );

		emit UserShareDecreased(wallet, poolID, decreaseShareAmount, claimableRewards);
		}


	// ===== PUBLIC FUNCTIONS =====

	// Claim all available SALT rewards from multiple pools for the user.
	// The claimed rewards are added to the user's virtual rewards balance - so that they can't be claimed again later.
     function claimAllRewards( bytes32[] calldata poolIDs ) external nonReentrant returns (uint256 claimableRewards)
    	{
		mapping(bytes32=>UserShareInfo) storage userInfo = _userShareInfo[msg.sender];

		claimableRewards = 0;
		for( uint256 i = 0; i < poolIDs.length; i++ )
			{
			bytes32 poolID = poolIDs[i];

			uint256 pendingRewards = userRewardForPool( msg.sender, poolID );

			// Increase the virtualRewards balance for the user to account for them receiving the rewards without withdrawing
			userInfo[poolID].virtualRewards += uint128(pendingRewards);

			claimableRewards += pendingRewards;
			}

		if ( claimableRewards > 0 )
			{
			// Send the actual rewards
			salt.safeTransfer( msg.sender, claimableRewards );

			emit RewardsClaimed(msg.sender, claimableRewards);
			}
    	}


	// Adds SALT rewards for specific whitelisted pools.
	// There is some risk of addSALTRewards being frontrun to hunt rewards, but there are multiple mechanisms in place to prevent this from being effective.
	// 1. There is a cooldown period of default one hour before shares can be withdrawn once deposited.
	// 2. Staked SALT has a default unstake period of 52 weeks.
	// 3. Rewards are first placed into a RewardsEmitter which deposits rewards via addSALTRewards at the default rate of 1% per day.
	// 4. Rewards are deposited fairly often, with outstanding rewards being transferred with a frequency proportional to the activity of the exchange.
	// Example: if $100k rewards were being deposited in a bulk transaction, it would only equate to $1000 (1%) the first day,
	// or $10 in claimable rewards during a 15 minute upkeep period.
 	function addSALTRewards( AddedReward[] calldata addedRewards ) external nonReentrant
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

			emit SaltRewardsAdded(poolID, amountToAdd);
			}

		// Transfer in the SALT for all the specified rewards
		if ( sum > 0 )
			{
			// Transfer the SALT rewards from the sender
			salt.safeTransferFrom( msg.sender, address(this), sum );
			}
		}


	// === VIEWS ===

	// Returns the total shares for specified pools.
	function totalSharesForPools( bytes32[] calldata poolIDs ) external view returns (uint256[] memory shares)
		{
		shares = new uint256[]( poolIDs.length );

		for( uint256 i = 0; i < shares.length; i++ )
			shares[i] = totalShares[ poolIDs[i] ];
		}


	// Returns the total rewards for specified pools.
	function totalRewardsForPools( bytes32[] calldata poolIDs ) external view returns (uint256[] memory rewards)
		{
		rewards = new uint256[]( poolIDs.length );

		for( uint256 i = 0; i < rewards.length; i++ )
			rewards[i] = totalRewards[ poolIDs[i] ];
		}


	// Returns the user's pending rewards for a specified pool.
	function userRewardForPool( address wallet, bytes32 poolID ) public view returns (uint256)
		{
		// If there are no shares for the pool, the user can't have any shares either and there can't be any rewards
		if ( totalShares[poolID] == 0 )
			return 0;

		UserShareInfo memory user = _userShareInfo[wallet][poolID];
		if ( user.userShare == 0 )
			return 0;

		// Determine the share of the rewards for the user based on their deposited share
		uint256 rewardsShare = ( totalRewards[poolID] * user.userShare ) / totalShares[poolID];

		// Reduce by the virtualRewards - as they were only added to keep the share / rewards ratio the same when the used added their share

		// In the event that virtualRewards exceeds rewardsShare due to precision loss - just return zero
		if ( user.virtualRewards > rewardsShare )
			return 0;

		return rewardsShare - user.virtualRewards;
		}


	// Returns the user's pending rewards for specified pools.
	function userRewardsForPools( address wallet, bytes32[] calldata poolIDs ) external view returns (uint256[] memory rewards)
		{
		rewards = new uint256[]( poolIDs.length );

		for( uint256 i = 0; i < rewards.length; i++ )
			rewards[i] = userRewardForPool( wallet, poolIDs[i] );
		}


	// Get the user's shares for a specified pool.
	function userShareForPool( address wallet, bytes32 poolID ) public view returns (uint256)
		{
		return _userShareInfo[wallet][poolID].userShare;
		}


	// Get the user's shares for specified pools.
	function userShareForPools( address wallet, bytes32[] calldata poolIDs ) external view returns (uint256[] memory shares)
		{
		shares = new uint256[]( poolIDs.length );

		for( uint256 i = 0; i < shares.length; i++ )
			shares[i] = _userShareInfo[wallet][ poolIDs[i] ].userShare;
		}


	// Get the user's virtual rewards for a specified pool.
	function userVirtualRewardsForPool( address wallet, bytes32 poolID ) public view returns (uint256)
		{
		return _userShareInfo[wallet][poolID].virtualRewards;
		}


	// Get the cooldown time remaining for the user for specified pools.
	function userCooldowns( address wallet, bytes32[] calldata poolIDs ) external view returns (uint256[] memory cooldowns)
		{
		cooldowns = new uint256[]( poolIDs.length );

		mapping(bytes32=>UserShareInfo) storage userInfo = _userShareInfo[wallet];

		for( uint256 i = 0; i < cooldowns.length; i++ )
			{
			uint256 cooldownExpiration = userInfo[ poolIDs[i] ].cooldownExpiration;

			if ( block.timestamp >= cooldownExpiration )
				cooldowns[i] = 0;
			else
				cooldowns[i] = cooldownExpiration - block.timestamp;
			}
		}
	}