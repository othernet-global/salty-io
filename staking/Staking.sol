// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.12;

import "../openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "./StakingRewards.sol";
import "../interfaces/ISalt.sol";
import "./interfaces/IStaking.sol";


// Staking SALT provides xSALT at a 1:1 ratio.
// Unstaking xSALT to reclaim SALT has a default duration of six months and a minimum duration of two weeks.
// By default, unstaking for two weeks allow 50% of the SALT to be reclaimed, while unstaking for the full six months allows 100% to be reclaimed.

contract Staking is IStaking, StakingRewards
    {
	event eStake(address indexed wallet, uint256 amount);
	event eUnstake(uint256 unstakedID, address indexed wallet, uint256 amount, uint256 numWeeks);
	event eRecover(address indexed wallet, uint256 indexed unstakeID, uint256 amount);
	event eCancelUnstake(address indexed wallet, uint256 indexed unstakeID);
	event eDepositVotes(address indexed wallet, bytes32 pool, uint256 amount);
	event eRemoveVotes(address indexed wallet, bytes32 pool, uint256 amount);

	struct UserStakingInfo
		{
	    uint256 freeXSALT;					// The free xSALT balance for the user. xSALT that hasn't been deposited yet for voting and can be unstaked.
    	uint256[] userUnstakeIDs;		// The unstakeIDs for the user
		}

	using SafeERC20 for ISalt;


	//  Mapping of user addresses to staking information.
	mapping(address => UserStakingInfo) public userStakingInfo;

	// Mapping of unstake IDs to their corresponding unstake information.
    mapping(uint256=>Unstake) private _unstakesByID;
	uint256 public nextUnstakeID;


	constructor( IExchangeConfig _exchangeConfig, IPoolsConfig _poolsConfig, IStakingConfig _stakingConfig )
		StakingRewards( _exchangeConfig, _poolsConfig, _stakingConfig )
		{
		}


	// Stake a given amount of SALT and immediately receive the same amount of xSALT
	function stakeSALT( uint256 amountToStake ) external nonReentrant
		{
		require( exchangeConfig.walletHasAccess(msg.sender), "Sending wallet does not have exchange access" );

		UserStakingInfo storage user = userStakingInfo[msg.sender];

		// The SALT will be converted instantly to xSALT
		user.freeXSALT += amountToStake;

		// Update the user's share of the rewards for staked SALT
		// No cooldown as it takes default 6 months to unstake the SALT anyways
		_increaseUserShare( msg.sender, STAKED_SALT, amountToStake, false );

		// Transfer the SALT from the user's wallet
		require( salt.allowance(msg.sender, address(this)) >= amountToStake, "Insufficient allowance to stake" );
		require( salt.balanceOf(address(msg.sender)) >= amountToStake, "Insufficient SALT balance to stake");
		salt.safeTransferFrom( msg.sender, address(this), amountToStake );

		emit eStake( msg.sender, amountToStake );
		}


	// Calculate the reclaimable amount of SALT based on the amount of xSALT unstaked and unstake duration
	function calculateUnstake( uint256 unstakedXSALT, uint256 numWeeks ) public view returns (uint256)
		{
		uint256 minUnstakeWeeks = stakingConfig.minUnstakeWeeks();
        uint256 maxUnstakeWeeks = stakingConfig.maxUnstakeWeeks();
        uint256 minUnstakePercent = stakingConfig.minUnstakePercent();

		require( numWeeks >= minUnstakeWeeks, "Unstaking duration too short" );
		require( numWeeks <= maxUnstakeWeeks, "Unstaking duration too long" );

		uint256 percentAboveMinimum = 100 - minUnstakePercent;
		uint256 unstakeRange = maxUnstakeWeeks - minUnstakeWeeks;

		uint256 numerator = unstakedXSALT * ( minUnstakePercent * unstakeRange + percentAboveMinimum * ( numWeeks - minUnstakeWeeks ) );
    	return numerator / ( 100 * unstakeRange );
		}


	// Unstake a given amount of xSALT over a certain duration.
	function unstake( uint256 amountUnstaked, uint256 numWeeks ) external nonReentrant returns (uint256 unstakeID)
		{
		UserStakingInfo storage user = userStakingInfo[msg.sender];

		require( msg.sender != address(exchangeConfig.dao()), "DAO cannot unstake" );
		require( amountUnstaked <= user.freeXSALT, "Cannot unstake more than the xSALT balance" );

		uint256 claimableSALT = calculateUnstake( amountUnstaked, numWeeks );
		uint256 completionTime = block.timestamp + numWeeks * ( 1 weeks );

		Unstake memory u = Unstake( UnstakeState.PENDING, msg.sender, amountUnstaked, claimableSALT, completionTime, nextUnstakeID );

		_unstakesByID[nextUnstakeID] = u;
		user.userUnstakeIDs.push( nextUnstakeID );

		// Unstaking immediately reduces the user's xSALT balance even though there will be a delay to convert it back to SALT
		user.freeXSALT -= amountUnstaked;

		// Reduce the user's share of the rewards for staked SALT
		_decreaseUserShare( msg.sender, STAKED_SALT, amountUnstaked, false );

		emit eUnstake( nextUnstakeID, msg.sender, amountUnstaked, numWeeks);

		unstakeID = nextUnstakeID;
		nextUnstakeID++;
		}


	// Cancel a pending unstake.
	function cancelUnstake( uint256 unstakeID ) external nonReentrant
		{
		Unstake storage unstake = _unstakesByID[unstakeID];

		require( unstake.status == UnstakeState.PENDING, "Only PENDING unstakes can be cancelled" );
		require( block.timestamp < unstake.completionTime, "Unstakes that have already completed cannot be cancelled" );
		require( msg.sender == unstake.wallet, "Not the original staker" );

		UserStakingInfo storage user = userStakingInfo[msg.sender];

		// User will be able to use the xSALT again immediately
		user.freeXSALT += unstake.unstakedXSALT;

		// Update the user's share of the rewards for staked SALT
		_increaseUserShare( msg.sender, STAKED_SALT, unstake.unstakedXSALT, false );

		unstake.status = UnstakeState.CANCELLED;

		emit eCancelUnstake( msg.sender, unstakeID );
		}


	// Recover claimable SALT from a completed unstake
	function recoverSALT( uint256 unstakeID ) external nonReentrant
		{
		Unstake storage u = _unstakesByID[unstakeID];
		require( u.status == UnstakeState.PENDING, "Only PENDING unstakes can be claimed" );
		require( block.timestamp >= u.completionTime, "Unstake has not completed yet" );
		require( msg.sender == u.wallet, "Not the original staker" );

		u.status = UnstakeState.CLAIMED;

		uint256 claimableSALT = u.claimableSALT;
		require( claimableSALT <= u.unstakedXSALT, "Claimable amount can't be more than the original stake" );

		// See if the user unstaked early and received only a portion of their original stake
		// The portion they did not receive will be considered the earlyUnstakeFee
		uint256 earlyUnstakeFee = u.unstakedXSALT - claimableSALT;

		// Burn 100% of the earlyUnstakeFee
		if ( earlyUnstakeFee > 0 )
			{
			// Send the earlyUnstakeFee to the SALT contract and burn it

			// This error should never happen (as the user had there SALT staked in this contract)
			require( salt.balanceOf(address(this)) >= earlyUnstakeFee, "Insufficient SALT balance to burn earlyUnstakeFee");

			salt.safeTransfer( address(exchangeConfig.salt()), earlyUnstakeFee );
            salt.burnTokensInContract();
            }

		// Send the reclaimed SALT back to the user

		// This error should never happen (as the user had there SALT staked in this contract)
		require( salt.balanceOf(address(this)) >= claimableSALT, "Insufficient balance to send claimed SALT");

		salt.safeTransfer( msg.sender, claimableSALT );

		emit eRecover( msg.sender, unstakeID, claimableSALT );
		}


	// ===== VOTING =====

	// Deposit xSALT to vote for a given whitelisted pool.
	function depositVotes( bytes32 poolID, uint256 amountToVote ) public nonReentrant
		{
		UserStakingInfo storage user = userStakingInfo[msg.sender];

		// Don't allow voting for the STAKED_SALT pool
		require( poolID != STAKED_SALT, "Cannot vote for the STAKED_SALT pool" );

		// Reduce the user's available free xSALT by the amount they are depositing
   		require( amountToVote <= user.freeXSALT, "Cannot vote with more than the available xSALT balance" );
   		user.freeXSALT -= amountToVote;

		// Update the user's share of the rewards for the pool
		// Cooldown activated to prevent reward hunting for pool voting
   		_increaseUserShare( msg.sender, poolID, amountToVote, true );

   		emit eDepositVotes( msg.sender, poolID, amountToVote );
		}


	// Withdraw xSALT votes from a specified pool and claim any pending rewards.
	function removeVotesAndClaim( bytes32 poolID, uint256 amountRemoved ) public nonReentrant
		{
		// Don't allow calling with pool 0
		require( poolID != STAKED_SALT, "Cannot remove votes from the STAKED_SALT pool" );
		require( amountRemoved != 0, "Cannot remove zero votes" );

		// Increase the user's available xSALT by the amount they are withdrawing
		// Note that balance checks will be done within _decreaseUserShare below
		UserStakingInfo storage user = userStakingInfo[msg.sender];
   		user.freeXSALT += amountRemoved;

		// Update the user's share of the rewards for the pool and claim any pending rewards
		// Cooldown activated to prevent reward hunting for pool voting
		_decreaseUserShare( msg.sender, poolID, amountRemoved, true );

   		emit eRemoveVotes( msg.sender, poolID, amountRemoved );
		}


	// ===== VIEWS =====

	// Retrieve all pending unstakes associated with a user within a specific range.
	function unstakesForUser( address wallet, uint256 start, uint256 end ) public view returns (Unstake[] memory) {
        UserStakingInfo storage user = userStakingInfo[wallet];

        // Check if start and end are within the bounds of the array
        require(end >= start, "Invalid range: end cannot be less than start");
        require(user.userUnstakeIDs.length > end, "Invalid range: end is out of bounds");
        require(start >= 0 && start < user.userUnstakeIDs.length, "Invalid range: start is out of bounds");

        Unstake[] memory unstakes = new Unstake[](end - start + 1);

        uint256 index;
        for(uint256 i = start; i <= end; i++)
            unstakes[index++] = _unstakesByID[ user.userUnstakeIDs[i]];

        return unstakes;
    }


	// Retrieve all pending unstakes associated with a user.
	function unstakesForUser( address wallet ) external view returns (Unstake[] memory)
		{
		UserStakingInfo storage user = userStakingInfo[wallet];

		// Check to see how many unstakes the user has
		uint256[] memory unstakeIDs = user.userUnstakeIDs;
		if ( unstakeIDs.length == 0 )
			return new Unstake[](0);

		// Return them all
		return unstakesForUser( wallet, 0, unstakeIDs.length - 1 );
		}


	// Retrieve a user's free xSALT balance (which hasn't yet been deposited to vote for any pools).
	function userBalanceXSALT( address wallet ) external view returns (uint256)
		{
		return userStakingInfo[wallet].freeXSALT;
		}


	// Retrieve the total amount of SALT staked on the platform.
	function totalStakedOnPlatform() public view returns (uint256)
		{
		return totalShares[STAKED_SALT];
		}


	// Returns the unstakeIDs for the user
	function userUnstakeIDs( address user ) public view returns (uint256[] memory)
		{
		return userStakingInfo[user].userUnstakeIDs;
		}


	function unstakeByID(uint256 id) external view returns (Unstake memory)
		{
		return _unstakesByID[id];
		}
	}