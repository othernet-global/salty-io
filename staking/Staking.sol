// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.0;

import "../openzeppelin/token/ERC20/IERC20.sol";
import "../openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "../openzeppelin/security/ReentrancyGuard.sol";
import "../uniswap/core/interfaces/IUniswapV2Pair.sol";
import "./IStakingConfig.sol";
import "./SharedRewards.sol";

/**
 * @title Staking
 * @dev A contract for staking and unstaking SALT tokens with an optional lock-up period for higher returns.
 *      Users can also vote on various pools using their staked SALT tokens and receive rewards for doing so.
 *      There is also an option for early unstaking with a penalty fee that is collected and distributed later.
 */
 contract Staking is SharedRewards
    {
	using SafeERC20 for IERC20;

	/**
	 * @dev Enum representing the possible states of an unstake request:
	 * NONE: The default state, indicating that no unstake request has been made.
	 * PENDING: The state indicating that an unstake request has been made, but has not yet completed.
	 * CANCELLED: The state indicating that a pending unstake request has been cancelled by the user.
	 * CLAIMED: The state indicating that a pending unstake request has been completed and the user can claim their SALT tokens.
	 */
    enum UnstakeState { NONE, PENDING, CANCELLED, CLAIMED }

	/**
	 * @dev Struct containing information about a pending unstake request.
	 * @param status The status of the unstake request, represented by the UnstakeState enum.
	 * @param wallet The address of the account requesting the unstake.
	 * @param unstakedXSALT The amount of xSALT being unstaked.
	 * @param claimableSALT The amount of SALT that will be claimable upon completion of the unstake.
	 * @param completionTime The timestamp at which the unstake will be completed.
	 * @param unstakeID The unique ID of the unstake request.
	 */
     struct Unstake
        {
        uint8 status;

        address wallet;
        uint256 unstakedXSALT;
        uint256 claimableSALT;
        uint256 completionTime;

        uint256 unstakeID;
        }

	/**
	 * @dev Struct containing information about a user's staking balance and unstake requests.
	 * @param freeXSALT The amount of xSALT that the user currently has available for voting or further staking.
	 * @param userUnstakeIDs An array of IDs corresponding to the user's pending unstake requests.
	 */
	struct UserStakingInfo
		{
	    // The free xSALT balance for the user
	    // This is xSALT that hasn't been deposited yet for voting
	    uint256 freeXSALT;

		// The unstakeIDs for the user
    	uint256[] userUnstakeIDs;
		}


	/**
	 * @dev Event emitted when a user stakes SALT.
	 * @param wallet Address of the user's wallet.
	 * @param amount Amount of SALT staked.
	 */
     event eStake(
        address indexed wallet,
        uint256 amount );

	/**
	 * @dev Event emitted when a user initiates an unstake.
	 * @param wallet Address of the user's wallet.
	 * @param amount Amount of SALT being unstaked (converted to xSALT).
	 * @param numWeeks Number of weeks the unstake will take to complete.
	 */
     event eUnstake(
     	uint256 unstakedID,
        address indexed wallet,
        uint256 amount,
        uint256 numWeeks );

	/**
	 * @dev Event emitted when a user recovers their SALT after an unstake has completed.
	 * @param wallet Address of the user's wallet.
	 * @param unstakeID ID of the unstake being claimed.
	 * @param amount Amount of SALT being claimed.
	 */
    event eRecover(
        address indexed wallet,
        uint256 indexed unstakeID,
        uint256 amount );

	/**
	 * @dev Event emitted when a user cancels a pending unstake.
	 * @param wallet Address of the user's wallet.
	 * @param unstakeID ID of the unstake being cancelled.
	 */
     event eCancelUnstake(
        address indexed wallet,
        uint256 indexed unstakeID );

	/**
	 * @dev Event emitted when the user deposits xSALT to vote for a pool
	 * @param wallet Address of the user's wallet.
	 * @param poolID The corresponding pool
	 * @param amount Amount of xSALT being used for voting
	 */
     event eDepositVotes(
        address indexed wallet,
        IUniswapV2Pair poolID,
        uint256 amount );

	/**
	 * @dev Event emitted when the user removes xSALT votes from a pool
	 * @param wallet Address of the user's wallet.
	 * @param poolID The corresponding pool
	 * @param amount Amount of xSALT votes being removed
	 */
     event eRemoveVotes(
        address indexed wallet,
        IUniswapV2Pair poolID,
        uint256 amount );


	//  @dev Mapping of user addresses to their staking information.
	mapping(address => UserStakingInfo) public userStakingInfo;

	// @dev Mapping of unstake IDs to their corresponding unstake information.
    mapping(uint256=>Unstake) public unstakesByID;

	// @dev Variable to hold the ID of the next unstake.
	uint256 public nextUnstakeID;


	/**
     * @dev Constructor that sets the staking configuration.
     * @param _stakingConfig The address of the staking configuration smart contract.
     */
	constructor( IStakingConfig _stakingConfig )
		SharedRewards( _stakingConfig )
		{
		}


	/**
     * @dev Function for users to stake SALT and receive xSALT in return.
     * @param amountToStake The amount of SALT that the user wants to stake.
     */
	function stakeSALT( uint256 amountToStake ) external nonReentrant
		{
		UserStakingInfo storage user = userStakingInfo[msg.sender];

		// The SALT will be converted instantly to xSALT
		user.freeXSALT += amountToStake;

		// Update the user's share of the rewards for staked SALT
		_increaseUserShare( msg.sender, STAKED_SALT, amountToStake, false );

		// Transfer the SALT from the user's wallet
		stakingConfig.salt().safeTransferFrom( msg.sender, address(this), amountToStake );

		emit eStake( msg.sender, amountToStake );
		}


	/**
     * @dev Function for calculating the claimable amount for an unstake.
     * @param unstakedXSALT The amount of xSALT being unstaked.
     * @param numWeeks The number of weeks until the unstake can be completed.
     * @return The claimable SALT amount.
     */
	function calculateUnstake( uint256 unstakedXSALT, uint256 numWeeks ) public view returns (uint256)
		{
		UnstakeParams memory unstakeParams = stakingConfig.unstakeParams();

		uint256 minUnstakeWeeks = unstakeParams.minUnstakeWeeks;
        uint256 maxUnstakeWeeks = unstakeParams.maxUnstakeWeeks;
        uint256 minUnstakePercent = unstakeParams.minUnstakePercent;

		require( numWeeks >= minUnstakeWeeks, "Unstaking duration too short" );
		require( numWeeks <= maxUnstakeWeeks, "Unstaking duration too long" );

		uint256 percentAboveMinimum = 100 - minUnstakePercent;
		uint256 unstakeRange = maxUnstakeWeeks - minUnstakeWeeks;

		uint256 numerator = unstakedXSALT * ( minUnstakePercent * unstakeRange + percentAboveMinimum * ( numWeeks - minUnstakeWeeks ) );
    	return numerator / ( 100 * unstakeRange );
		}

	/**
     * @dev Function for initiating a pending unstake.
     * @param amountUnstaked The amount of xSALT being unstaked.
     * @param numWeeks The number of weeks until the unstake can be completed.
     * @return unstakeID The unstakeID for the unstaked position
     */
	function unstake( uint256 amountUnstaked, uint256 numWeeks ) external nonReentrant returns (uint256 unstakeID)
		{
		UserStakingInfo storage user = userStakingInfo[msg.sender];

		require( msg.sender != stakingConfig.saltyDAO(), "DAO cannot unstake" );
		require( amountUnstaked <= user.freeXSALT, "Cannot unstake more than the xSALT balance" );

		uint256 claimableSALT = calculateUnstake( amountUnstaked, numWeeks );
		uint256 completionTime = block.timestamp + numWeeks * ( 1 weeks );

		Unstake memory u = Unstake( uint8(UnstakeState.PENDING), msg.sender, amountUnstaked, claimableSALT, completionTime, nextUnstakeID );

		unstakesByID[nextUnstakeID] = u;
		user.userUnstakeIDs.push( nextUnstakeID );

		// Unstaking immediately reduces the user's xSALT balance as it will be converted back to SALT
		user.freeXSALT -= amountUnstaked;

		// Update the user's share of the rewards for staked SALT
		_decreaseUserShare( msg.sender, STAKED_SALT, amountUnstaked, false );

		emit eUnstake( nextUnstakeID, msg.sender, amountUnstaked, numWeeks);

		unstakeID = nextUnstakeID;
		nextUnstakeID++;
		}


	/**
     * @dev Function for cancelling a pending unstake.
     * @param unstakeID The ID of the unstake to be cancelled.
     */
	function cancelUnstake( uint256 unstakeID ) external nonReentrant
		{
		Unstake storage u = unstakesByID[unstakeID];

		require( u.status == uint8(UnstakeState.PENDING), "Only PENDING unstakes can be cancelled" );
		require( block.timestamp < u.completionTime, "Unstakes that have already completed cannot be cancelled" );
		require( msg.sender == u.wallet, "Not the original staker" );

		UserStakingInfo storage user = userStakingInfo[msg.sender];

		// User will be able to use the xSALT again
		user.freeXSALT += u.unstakedXSALT;

		// Update the user's share of the rewards for staked SALT
		_increaseUserShare( msg.sender, STAKED_SALT, u.unstakedXSALT, false );

		u.status = uint8(UnstakeState.CANCELLED);

		emit eCancelUnstake( msg.sender, unstakeID );
		}


	/**
     * @dev Function for users to claim their claimable SALT after completing an unstake.
     * @param unstakeID The ID of the unstake to be completed.
     */
	function recoverSALT( uint256 unstakeID ) external nonReentrant
		{
		Unstake storage u = unstakesByID[unstakeID];
		require( u.status == uint8(UnstakeState.PENDING), "Only PENDING unstakes can be claimed" );
		require( block.timestamp >= u.completionTime, "Unstake has not completed yet" );
		require( msg.sender == u.wallet, "Not the original staker" );

		u.status = uint8(UnstakeState.CLAIMED);

		uint256 claimableSALT = u.claimableSALT;
		require( claimableSALT <= u.unstakedXSALT, "Claimable amount can't be more than the original stake" );

		// See if the user unstaked early and received only a portion of their original stake
		uint256 earlyUnstakeFee = u.unstakedXSALT - claimableSALT;

		if ( earlyUnstakeFee > 0 )
			{
            if ( stakingConfig.earlyUnstake() != address(0) )
            	{
                // Send the earlyUnstakeFee to EarlyUnstake.sol for later distribution on upkeep
                stakingConfig.salt().safeTransfer(stakingConfig.earlyUnstake(), earlyUnstakeFee);
            	}
            else
            	{
                // If earlyUnstake is not set, then send the user all the SALT they originally staked
                claimableSALT = u.unstakedXSALT;
            	}
        	}

		stakingConfig.salt().safeTransfer( msg.sender, claimableSALT );

		emit eRecover( msg.sender, unstakeID, claimableSALT );
		}


	// ===== VOTING =====

	/**
     * @dev Function for users to deposit xSALT into a voting pool.
     * @param poolID The ID of the voting pool.
     * @param amountToVote The amount of xSALT being deposited for voting.
     */
	function depositVotes( IUniswapV2Pair poolID, uint256 amountToVote ) public nonReentrant
		{
		UserStakingInfo storage user = userStakingInfo[msg.sender];

		// Don't allow voting for the STAKED_SALT pool
		require( poolID != STAKED_SALT, "Cannot vote for poolID 0" );

		// Reduce the user's available xSALT by the amount they are depositing
   		require( amountToVote <= user.freeXSALT, "Cannot vote with more than the available xSALT balance" );
   		user.freeXSALT -= amountToVote;

		// Update the user's share of the rewards for the pool
   		_increaseUserShare( msg.sender, poolID, amountToVote, true );

   		emit eDepositVotes( msg.sender, poolID, amountToVote );
		}


	/**
     * @dev Function for users to withdraw xSALT from a voting pool and claim rewards.
     * @param poolID The ID of the voting pool.
     * @param amountRemoved The amount of votes being removed by withdrawing xSALT.
     */
	function removeVotesAndClaim( IUniswapV2Pair poolID, uint256 amountRemoved ) public nonReentrant
		{
		// Don't allow calling with poolID 0
		require( poolID != STAKED_SALT, "Cannot remove votes from poolID 0" );
		require( amountRemoved != 0, "Cannot remove zero votes" );

		// Increase the user's available xSALT by the amount they are withdrawing
		// Note that balance checks will be done within _decreaseUserShare below
		UserStakingInfo storage user = userStakingInfo[msg.sender];
   		user.freeXSALT += amountRemoved;

		// Update the user's share of the rewards for the pool
		_decreaseUserShare( msg.sender, poolID, amountRemoved, true );

   		emit eRemoveVotes( msg.sender, poolID, amountRemoved );
		}


	// ===== VIEWS =====

	/**
     * @dev Function for retrieving all unstakes associated with a user within a specific range.
     * @param wallet The address of the user.
     * @param start The starting index of the range.
     * @param end The ending index of the range.
     * @return An array of Unstake structs.
     */
	 function unstakesForUser( address wallet, uint256 start, uint256 end ) public view returns (Unstake[] memory)
  		{
		UserStakingInfo storage user = userStakingInfo[wallet];
		Unstake[] memory unstakes = new Unstake[]( end - start + 1 );

		uint256 index;
		for( uint256 i = start; i <= end; i++ )
			unstakes[index++] = unstakesByID[ user.userUnstakeIDs[i]];

		return unstakes;
		}


	/**
     * @dev Function for retrieving all unstakes associated with a user.
     * @param wallet The address of the user.
     * @return An array of Unstake structs.
     */
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


	/**
     * @dev Function for retrieving a user's xSALT balance.
     * @param wallet The address of the user.
     * @return The user's xSALT balance.
     */
	function userBalanceXSALT( address wallet ) external view returns (uint256)
		{
		return userStakingInfo[wallet].freeXSALT;
		}


	/**
     * @dev Function for retrieving the total amount of SALT staked on the platform.
     * @return The total amount of staked SALT.
     */
	function totalStakedOnPlatform() public view returns (uint256)
		{
		return totalShares[STAKED_SALT];
		}
	}