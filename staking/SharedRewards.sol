// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.0;

import "../openzeppelin/security/ReentrancyGuard.sol";
import "../openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "../uniswap/core/interfaces/IUniswapV2Pair.sol";
import "../openzeppelin/utils/math/Math.sol";
import "./IStakingConfig.sol";


/**
 * @dev Struct containing information about a SALT reward to be added to a pool.
 * @param poolID The ID of the pool to add the reward to.
 * @param amountToAdd The amount of the reward to add (in SALT).
 */
struct AddedReward
	{
	IUniswapV2Pair poolID;
	uint256 amountToAdd;
	}

/**
 * @dev Struct containing information about a user's share of a pool.
 * @param userShare The user's share of the pool.
 * @param virtualRewards The amount of virtual rewards given to the user when increasing share to keep the ratio
 * of rewards / shares the same before and after the increase.
 * @param cooldownExpiration The earliest time at which a user's share can be modified (share increased or decreased).
 * Defaults to a one hour cooldown.
 */
struct UserShareInfo
	{
	uint256 userShare;
	uint256 virtualRewards;
	uint256 cooldownExpiration;
	}


/***
 * @title SharedRewards
 * @notice This contract allows users to share rewards (as SALT tokens) for specific IUniswapV2Pairs.
 * @notice Users have a certain share of the SALT rewards for each pool.
 * @notice A user's rewards are based on their share at the time the reward was added.
 *
 * There can be multiple SharedRewards for each pool and the shares themselves can represent different things.
 * What the share represents exactly will be specified in the contracts that derive from SharedRewards.
 *
 * Some examples of what a user's share could represent:
 * 1. The amount of SALT staked
 * 2. The amount of xSALT staked (voting) for a specific pool
 * 3. The amount of LP tokens staked from a specific pool
 *
 * All of these examples will have their own mechanisms in which SALT is rewarded to the pools
 * via the addSALTRewards method (typically called during a performUpkeep)
 */
contract SharedRewards is ReentrancyGuard
    {
	using SafeERC20 for IERC20;

	/**
	 * @dev Emitted when a user increases their share of a pool.
	 * @param wallet The address of the user.
	 * @param poolID The ID of the pool.
	 * @param amount The amount of the share increase.
	 */
	event eIncreaseShare(
		address indexed wallet,
		IUniswapV2Pair indexed poolID,
		uint256 amount
	);

	/**
	 * @dev Emitted when a user decreases their share of a pool and claims their rewards.
	 * @param wallet The address of the user.
	 * @param poolID The ID of the pool.
	 * @param amount The amount of share to remove.
	 */
	event eDecreaseShareAndClaim(
		address indexed wallet,
		IUniswapV2Pair indexed poolID,
		uint256 amount
	);

	/**
	 * @dev Emitted when a user claims their available rewards for a specific pool.
	 * @param wallet The address of the user.
	 * @param poolID The ID of the pool.
	 * @param amount The amount of rewards claimed by the user.
	 */
	event eClaimRewards(
		address indexed wallet,
		IUniswapV2Pair indexed poolID,
		uint256 amount
	);

	/**
	 * @dev Emitted when a user claims all their available rewards from multiple pools.
	 * @param wallet The address of the user.
	 * @param amount The total amount of rewards claimed by the user.
	 */
	event eClaimAllRewards(
		address indexed wallet,
		uint256 amount
	);

	// @notice The SALT token which will be used for the claimable rewards
	IERC20 salt;

	// @notice Address of the StakingConfig contract that contains the configuration parameters for the SharedRewards contract.
    IStakingConfig public immutable stakingConfig;

	// @notice A nested mapping that stores the UserShareInfo data for each user and each pool.
	mapping(address=>mapping(IUniswapV2Pair=>UserShareInfo)) private userPoolInfo;

    // @notice A mapping that stores the total SALT rewards for each pool.
    mapping(IUniswapV2Pair=>uint256) public totalRewards;

    // @notice A mapping that stores the total shares for each pool.
    mapping(IUniswapV2Pair=>uint256) public totalShares;

	// @notice A special poolID that represents staked SALT that is not associated with any particular pool.
	IUniswapV2Pair public constant STAKED_SALT = IUniswapV2Pair(address(0));


	/**
	 * @dev Constructs a new SharedRewards contract with the given StakingConfig instance.
	 * @param _stakingConfig Address of the IStakingConfig instance containing configuration information.
	 */
 	constructor( IStakingConfig _stakingConfig )
		{
		require( _stakingConfig != IStakingConfig(address(0)), "StakingConfig cannot be address zero" );

		stakingConfig = _stakingConfig;
		salt = stakingConfig.salt(); // cached for efficiency
		}


	/**
	 * @dev Increase a user's share for the pool.
	 * @param wallet The address of the user.
	 * @param poolID The ID of the pool.
	 * @param amountToIncrease The amount of the share increase.
	 */
	function _increaseUserShare( address wallet, IUniswapV2Pair poolID, uint256 amountToIncrease, bool useCooldown ) internal
		{
		require( stakingConfig.isValidPool( poolID ), "Invalid poolID" );
		require( amountToIncrease != 0, "Cannot increase zero share" );

		UserShareInfo storage user = userPoolInfo[wallet][poolID];

		if ( useCooldown )
			require( block.timestamp >= user.cooldownExpiration, "Must wait for the cooldown to expire" );

		uint256 existingTotalShares = totalShares[poolID];

		// Determine the virtualRewards added based on the current ratio of rewards/shares
        if ( existingTotalShares != 0 ) // prevent / 0
        	{
			// Add a virtual amount of rewards (as no rewards are really being deposited).
			// We do this to keep the proportion of rewards/shares the same after the increase.
			// These will be deducted later from the user's owed rewards.
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


	/**
	 * @dev Decrease a user's share for the pool and claim their rewards.
	 * @param wallet The address of the user.
	 * @param poolID The ID of the pool.
	 * @param amountToDecrease The amount of share to remove.
	 * @return actualRewards The actual rewards corresponding to the removal.
	 */
	function _decreaseUserShare( address wallet, IUniswapV2Pair poolID, uint256 amountToDecrease, bool useCooldown ) internal returns (uint256 actualRewards)
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
		require( virtualRewardsToRemove <= user.virtualRewards, "Virtual rewards to remove cannot exceed the current virtual rewards" );

		// Update totals
		totalRewards[poolID] -= rewardsForAmount;
		totalShares[poolID] -= amountToDecrease;

		// Update the user's share and virtual rewards
		user.userShare -= amountToDecrease;
		user.virtualRewards -= virtualRewardsToRemove;

		// Reduce the rewards by the amount of virtualRewards for the given amountRemoved
		actualRewards = rewardsForAmount - virtualRewardsToRemove;

		// Send the actual rewards corresponding to the removal
		if ( actualRewards != 0 )
			salt.safeTransfer( wallet, actualRewards );

		// Update the cooldown expiration
		if ( useCooldown )
			user.cooldownExpiration = block.timestamp + stakingConfig.modificationCooldown();

   	    emit eDecreaseShareAndClaim( wallet, poolID, actualRewards );
		}


	// ===== PUBLIC FUNCTIONS =====

	/**
	 * @dev Claims all available SALT rewards from multiple pools for the user.
	 * The rewards are first added to their virtual rewards balance and then transferred to their wallet.
	 * @param poolIDs An array of IUniswapV2Pair pool IDs to claim rewards from.
	 */
     function claimAllRewards( IUniswapV2Pair[] memory poolIDs ) public nonReentrant
    	{
		mapping(IUniswapV2Pair=>UserShareInfo) storage userInfo = userPoolInfo[msg.sender];

    	uint256 sum = 0;
		for( uint256 i = 0; i < poolIDs.length; i++ )
			{
			IUniswapV2Pair poolID = poolIDs[i];
			require( stakingConfig.isValidPool( poolID ), "Invalid poolID" );

			uint256 pendingRewards = userPendingReward( msg.sender, poolID );

			// Increase the virtualRewards balance for the user to account for them receiving the rewards
			userInfo[poolID].virtualRewards += pendingRewards;

			sum = sum + pendingRewards;
			}

		// Send the actual rewards
		salt.safeTransfer( msg.sender, sum );

   	    emit eClaimAllRewards( msg.sender, sum );
    	}


	/**
	 * @dev Adds SALT rewards for specific pools.
	 * @dev There is some risk of addSALTRewards being front run, but there are multiple mechanisms in place to prevent this from being effective.
	 * @dev 1. There is a cooldown period of default one hour before shares can be modified once deposited.
     * @dev 2. Staked SALT (required for voting on pools and receiving staking rewards) has a default unstake period of 6 months.
	 * @dev 3. Rewards are first placed into a RewardsEmitter which deposits rewards via addSALTRewards at the default rate of 5% per day.
	 * @dev 4. Rewards are deposited fairly quickly, with outstanding rewards being transferred within the global performUpkeep function,
     * @dev     which will be called at least every 15 minutes - but likely more often.
     * @dev Example: if $100k rewards were being deposited in a bulk transaction, it would only equate
     * @dev to $5000 (5%) the first day, and then $52 in consecutive addSALTRewards calls made every 15 minutes.

	 * @param addedRewards An array of structs containing the poolID and amount of rewards to be added.
	 */
 	function addSALTRewards( AddedReward[] memory addedRewards ) public nonReentrant
		{
		uint256 sum = 0;
		for( uint256 i = 0; i < addedRewards.length; i++ )
			{
			AddedReward memory addedReward = addedRewards[i];

			IUniswapV2Pair poolID = addedReward.poolID;
			require( stakingConfig.isValidPool( poolID ), "Invalid poolID" );

			uint256 amountToAdd = addedReward.amountToAdd;

			totalRewards[ poolID ] += amountToAdd;
			sum = sum + amountToAdd;
			}

		// Transfer in the SALT for all the specified rewards
		if ( sum > 0 )
			salt.safeTransferFrom( msg.sender, address(this), sum );
		}


	// ===== VIEWS =====

	/**
	 * @dev Returns the total shares for specific pools.
	 * @param poolIDs An array of IUniswapV2Pair pool IDs.
	 * @return shares An array containing the total shares for each specified pool.
	 */
	function totalSharesForPools( IUniswapV2Pair[] memory poolIDs ) public view returns (uint256[] memory shares)
		{
		shares = new uint256[]( poolIDs.length );

		for( uint256 i = 0; i < shares.length; i++ )
			shares[i] = totalShares[ poolIDs[i] ];
		}


	/**
	 * @dev Returns the total rewards for specific pools.
	 * @param poolIDs An array of IUniswapV2Pair pool IDs.
	 * @return rewards An array containing the total rewards for each specified pool.
	 */
	function totalRewardsForPools( IUniswapV2Pair[] memory poolIDs ) public view returns (uint256[] memory rewards)
		{
		rewards = new uint256[]( poolIDs.length );

		for( uint256 i = 0; i < rewards.length; i++ )
			rewards[i] = totalRewards[ poolIDs[i] ];
		}


	/**
	 * @dev Returns the user's pending rewards for a specific pool.
	 * @param wallet The user's wallet address.
	 * @param poolID The IUniswapV2Pair pool ID.
	 * @return The user's pending rewards for the specified pool.
	 */
	function userPendingReward( address wallet, IUniswapV2Pair poolID ) public view returns (uint256)
		{
		if ( totalShares[poolID] == 0 )
			{
			return 0;
			}

		UserShareInfo memory user = userPoolInfo[wallet][poolID];

		// Determine the share of the rewards for the user based on their deposits
		uint256 rewardsShare = ( totalRewards[poolID] * user.userShare ) / totalShares[poolID];

		// Reduce by the virtualRewards
		return rewardsShare - user.virtualRewards;
		}


	/**
	 * @dev Returns the user's pending rewards for specific pools.
	 * @param wallet The user's wallet address.
	 * @param poolIDs An array of IUniswapV2Pair pool IDs.
	 * @return rewards An array containing the user's pending rewards for each specified pool.
	 */
	function userRewardsForPools( address wallet, IUniswapV2Pair[] memory poolIDs ) public view returns (uint256[] memory rewards)
		{
		rewards = new uint256[]( poolIDs.length );

		for( uint256 i = 0; i < rewards.length; i++ )
			rewards[i] = userPendingReward( wallet, poolIDs[i] );
		}


	/**
	 * @dev Get the user's share for specific pools.
	 * @param wallet The user's wallet address.
	 * @param poolIDs An array of IUniswapV2Pair pool IDs.
	 * @return shares An array containing the user's share for each specified pool.
	 */
	function userShareForPools( address wallet, IUniswapV2Pair[] memory poolIDs ) public view returns (uint256[] memory shares)
		{
		shares = new uint256[]( poolIDs.length );

		mapping(IUniswapV2Pair=>UserShareInfo) storage userInfo = userPoolInfo[wallet];

		for( uint256 i = 0; i < shares.length; i++ )
			shares[i] = userInfo[ poolIDs[i] ].userShare;
		}


	/**
	 * @dev Get the cooldown time remaining for the user for specific pools.
	 * @param wallet The user's wallet address.
	 * @param poolIDs An array of IUniswapV2Pair pool IDs.
	 * @return cooldowns An array containing the cooldown time remaining for the user for each specified pool.
	 */
	function userCooldowns( address wallet, IUniswapV2Pair[] memory poolIDs ) public view returns (uint256[] memory cooldowns)
		{
		cooldowns = new uint256[]( poolIDs.length );

		mapping(IUniswapV2Pair=>UserShareInfo) storage userInfo = userPoolInfo[wallet];

		for( uint256 i = 0; i < cooldowns.length; i++ )
			{
			uint256 cooldownExpiration = userInfo[ poolIDs[i] ].cooldownExpiration;

			if ( block.timestamp >= cooldownExpiration )
				cooldowns[i] = 0;
			else
				cooldowns[i] = cooldownExpiration - block.timestamp;
			}
		}



	/**
	 * @dev Return a user's UserShareInfo for a given pool
	 * @param wallet The user's wallet address.
	 * @param poolID The pool ID
	 * @return UserShareInfo for the given user and pool
	 */
	function userShareInfoForPool( address wallet, IUniswapV2Pair poolID ) public view returns (UserShareInfo memory)
		{
		return userPoolInfo[wallet][poolID];
		}
	}