// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.0;

import "../openzeppelin/token/ERC20/IERC20.sol";
import "../openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "../openzeppelin/security/ReentrancyGuard.sol";
import "../openzeppelin/utils/math/Math.sol";
import "../uniswap/core/interfaces/IUniswapV2Pair.sol";
import "./IStakingConfig.sol";
import "./IStaking.sol";

// Allows staking SALT for xSALT - which is instant
// Allows unstaking xSALT to SALT - which requires time, with less SALT being returned with less unstake time

// Keeps track of the amount of rewards (as SALT) that each wallet is entitled to
// Rewards are kept track for each pool and deposited token (LP tokens and xSALT)
// Functions similarly to LP tokens in terms of accounting and liquidity share

contract Staking is IStaking, ReentrancyGuard
    {
	using SafeERC20 for IERC20;

	struct UserInfo
		{
	    // The free xSALT balance for each wallet
	    // This is xSALT that hasn't been used yet for voting
	    uint256 freeXSALT;

		// The unstakeIDs for each wallet
    	uint256[] userUnstakeIDs;

		// The amount a user has deposited for [poolID][isLP]
    	mapping(IUniswapV2Pair => mapping(bool => uint256)) userDeposits;

		// The amount of rewards each user had to borrow when depositing into [poolID][isLP]
		// The rewards are borrowed and deposited so that the ratio of rewards / deposited stays the same
		// It allows us to keep track of owed rewards for users over time (similar to how LP tokens work)
    	mapping(IUniswapV2Pair => mapping(bool => uint256)) borrowedRewards;

		// The earliest time at which the user can modify their deposits for a [poolID][isLP] (deposit or withdrawal)
		// defaults to one hour cooldown
		mapping(IUniswapV2Pair => mapping(bool => uint256)) earliestModificationTime;
		}

    struct Unstake
        {
        uint8 status;

        address wallet;
        uint256 unstakedXSALT;
        uint256 claimableSALT;
        uint256 completionTime;

        uint256 unstakeID;
        }

    // Values for Unstake.status
    uint8 public constant PENDING = 1;
    uint8 public constant CANCELLED = 2;
	uint8 public constant CLAIMED = 3;

    // A special poolID which represents staked SALT and allows for general staking rewards
    // that are not tied to a specific pool
    IUniswapV2Pair public constant STAKING = IUniswapV2Pair(address(0));


    IStakingConfig public immutable stakingConfig;

	mapping(address => UserInfo) public userInfo;

	// Unstakes by unstakeID
    mapping(uint256=>Unstake) public unstakesByID;									// [unstakeID]

	uint256 public nextUnstakeID;

    // The total SALT rewards and LP or xSALT deposits for particular pools
    mapping(IUniswapV2Pair=>mapping(bool=>uint256)) public totalRewards;			// [poolID][isLP]
    mapping(IUniswapV2Pair=>mapping(bool=>uint256)) public totalDeposits;			// [poolID][isLP]



	constructor( IStakingConfig _stakingConfig )
		{
		stakingConfig = IStakingConfig( _stakingConfig );
		}


	// === STAKING AND UNSTAKING SALT ===

	function stakeSALT( uint256 amountStaked ) external nonReentrant
		{
		UserInfo storage user = userInfo[msg.sender];

		// User now has more free xSALT
		user.freeXSALT += amountStaked;

		// Keep track of the staking - for general staking rewards that are not pool specific
		_accountForDeposit( msg.sender, STAKING, false, amountStaked );

		// Deposit the SALT
		require( stakingConfig.salt().transferFrom( msg.sender, address(this), amountStaked ), "Transfer failed" );

		emit eStake( msg.sender, amountStaked );
		}


	// UnstakeParams.minUnstakePercent returned at UnstakeParams.minUnstakeWeeks
	// 100% return at UnstakeParams.maxUnstakeWeeks
	function calculateUnstake( uint256 unstakedXSALT, uint256 numWeeks ) public view returns (uint256)
		{
		UnstakeParams memory unstakeParams = stakingConfig.unstakeParams();

		uint256 minUnstakeWeeks = unstakeParams.minUnstakeWeeks;
        uint256 maxUnstakeWeeks = unstakeParams.maxUnstakeWeeks;
        uint256 minUnstakePercent = unstakeParams.minUnstakePercent;

		require( numWeeks >= minUnstakeWeeks, "Staking: Unstaking duration too short" );
		require( numWeeks <= maxUnstakeWeeks, "Staking: Unstaking duration too long" );

		uint256 percentAboveMinimum = 100 - minUnstakePercent;
		uint256 unstakeRange = maxUnstakeWeeks - minUnstakeWeeks;

		uint256 numerator = unstakedXSALT * ( minUnstakePercent * unstakeRange + percentAboveMinimum * ( numWeeks - minUnstakeWeeks ) );
    	return numerator / ( 100 * unstakeRange );
		}


	function unstake( uint256 amountUnstaked, uint256 numWeeks ) external nonReentrant
		{
		UserInfo storage user = userInfo[msg.sender];

		require( amountUnstaked <= user.freeXSALT, "Staking: Cannot unstake more than the xSALT balance" );
		require( msg.sender != stakingConfig.saltyDAO(), "Staking: DAO cannot unstake" );

		uint256 claimableSALT = calculateUnstake( amountUnstaked, numWeeks );
		uint256 completionTime = block.timestamp + numWeeks * stakingConfig.oneWeek();

		Unstake memory u = Unstake( PENDING, msg.sender, amountUnstaked, claimableSALT, completionTime, nextUnstakeID );

		unstakesByID[nextUnstakeID] = u;
		user.userUnstakeIDs.push( nextUnstakeID );
		nextUnstakeID++;

		// Unstaking immediately reduces the user's balance
		user.freeXSALT -= amountUnstaked;

		// Keep track of the staking - for general staking rewards that are not pool specific
		_accountForWithdrawal( msg.sender, STAKING, false, amountUnstaked );

		emit eUnstake( msg.sender, amountUnstaked, numWeeks);
		}


	// Cancel a PENDING unstake
	function cancelUnstake( uint256 unstakeID ) external nonReentrant
		{
		Unstake storage u = unstakesByID[unstakeID];

		require( u.status == PENDING, "Staking: Only PENDING unstakes can be cancelled" );
		require( block.timestamp < u.completionTime, "Staking: Unstakes that have already completed cannot be cancelled" );
		require( msg.sender == u.wallet, "Staking: Not the original staker" );

		UserInfo storage user = userInfo[msg.sender];

		// User will be able to use the xSALT again
		user.freeXSALT += u.unstakedXSALT;

		// Keep track of the staking - for general staking rewards that are not pool specific
		_accountForDeposit( msg.sender, STAKING, false, u.unstakedXSALT );

		u.status = CANCELLED;

		emit eCancelUnstake( msg.sender, unstakeID );
		}


	// Recover the SALT from a given completed unstake
	function recoverSALT( uint256 unstakeID ) external nonReentrant
		{
		Unstake storage u = unstakesByID[unstakeID];
		require( u.status == PENDING, "Staking: Only PENDING unstakes can be claimed" );
		require( block.timestamp >= u.completionTime, "Staking: Unstake has not completed yet" );
		require( msg.sender == u.wallet, "Staking: Not the original staker" );

		u.status = CLAIMED;

		uint256 claimableSALT = u.claimableSALT;
		require( claimableSALT <= u.unstakedXSALT, "Staking: Claimable amount has to be less than original stake" );

		// See if the user unstaked early and received only a portion of their original stake
		uint256 earlyUnstakeFee = u.unstakedXSALT - claimableSALT;

		if ( earlyUnstakeFee > 0 )
			{
            if ( stakingConfig.earlyUnstake() != address(0) )
            	{
                // Send the earlyUnstakeFee to EarlyUnstake.sol for later distribution on upkeep
                require( stakingConfig.salt().transfer(stakingConfig.earlyUnstake(), earlyUnstakeFee), "Transfer failed" );
            	}
            else
            	{
                // If the early unstake address is not set, then send the user all the SALT they staked
                claimableSALT = u.unstakedXSALT;
            	}
        	}

		require( stakingConfig.salt().transfer( msg.sender, claimableSALT ), "Transfer failed" );

		emit eRecover( msg.sender, unstakeID, claimableSALT );
		}


	// === REWARDS AND DEPOSITS ===

	function _accountForDeposit( address wallet, IUniswapV2Pair poolID, bool isLP, uint256 amountDeposited ) internal
		{
		UserInfo storage user = userInfo[wallet];

		mapping(bool=>uint256) storage poolDeposits = totalDeposits[poolID];
		uint256 existingDeposit = poolDeposits[isLP];

		// Determine the amountBorrowed based on the current ratio of rewards/deposits
        if ( existingDeposit != 0 ) // prevent / 0
        	{
			// Borrow a proportional amount of rewards (as none are really being deposited)
			// We do this to keep the LP proportion the same
			// The user will need to pay this amount back later
	        uint256 toBorrow = Math.ceilDiv( amountDeposited * totalRewards[poolID][isLP], existingDeposit );

	       user.borrowedRewards[poolID][isLP] += toBorrow;
	        totalRewards[poolID][isLP] += toBorrow;
	        }

		// Update the deposit balances
		user.userDeposits[poolID][isLP] += amountDeposited;
		poolDeposits[isLP] = existingDeposit + amountDeposited;
		}


	function _accountForWithdrawal( address wallet, IUniswapV2Pair poolID, bool isLP, uint256 amountWithdrawn ) internal returns (uint256)
		{
		UserInfo storage user = userInfo[wallet];

		// Determine the share of the rewards for the amountWithdrawn (includes borrowed rewards)
		uint256 rewardsForAmount = ( totalRewards[poolID][isLP] * amountWithdrawn ) / totalDeposits[poolID][isLP];

		// Determine how much borrowed will need to be returned for the amountWithdrawn (proportional to all borrowed)
		uint256 borrowedForAmount = Math.ceilDiv( user.borrowedRewards[poolID][isLP] * amountWithdrawn, user.userDeposits[poolID][isLP] );

		// Reduce the rewards by the amount borrowed
		uint256 actualRewards = rewardsForAmount - borrowedForAmount;

		// Update totals
		totalRewards[poolID][isLP] -= rewardsForAmount;
		totalDeposits[poolID][isLP] -= amountWithdrawn;

		// Update user deposits and borrowed rewards
		user.userDeposits[poolID][isLP] -= amountWithdrawn;
		user.borrowedRewards[poolID][isLP] -= borrowedForAmount;

		// Send the actual rewards corresponding to the withdrawal
		if ( actualRewards != 0 )
			require( stakingConfig.salt().transfer( wallet, actualRewards ), "Transfer failed" );

		return actualRewards;
		}


	// Can be added from any wallet
	function addSALTRewards( AddedReward[] memory addedRewards ) public nonReentrant
		{
		uint256 sum = 0;
		for( uint256 i = 0; i < addedRewards.length; i++ )
			{
			AddedReward memory addedReward = addedRewards[i];

			IUniswapV2Pair poolID = addedReward.poolID;
			require( stakingConfig.isValidPool( poolID ), "Staking: Invalid poolID" );

			bool isLP = addedReward.isLP;

			if ( poolID == STAKING )
				require( ! isLP, "Staking pool cannot deposit LP tokens" );

			uint256 amountToAdd = addedReward.amountToAdd;

			totalRewards[ poolID ][ isLP ] += amountToAdd;
			sum = sum + amountToAdd;
			}

		// Transfer in the SALT for all the specified rewards
		if ( sum > 0 )
			require( stakingConfig.salt().transferFrom( msg.sender, address(this), sum ), "Transfer failed" );
		}


	// Deposit LP tokens or xSALT (which is used for voting on pools)
	function deposit( IUniswapV2Pair poolID, bool isLP, uint256 amountDeposited ) public nonReentrant
		{
		UserInfo storage user = userInfo[msg.sender];

		// Don't allow calling with poolID 0 - which is adjusted by xSALT staking and unstaking
		require( poolID != STAKING, "Staking: Cannot call on poolID 0" );
		require( stakingConfig.isValidPool( poolID ), "Staking: Invalid poolID" );
		require( amountDeposited != 0, "Staking: Cannot deposit 0" );

		require( block.timestamp >= user.earliestModificationTime[poolID][isLP], "Staking: Must wait for the one hour cooldown to expire" );

		// Set the next allowed modification time
		user.earliestModificationTime[poolID][isLP] = block.timestamp + stakingConfig.depositWithdrawalCooldown();

		// Transfer the LP or xSALT from the user
		if ( isLP )
    		{
			// poolID is the LP token
			IERC20 erc20 = IERC20( address(poolID) );

			// Before balance used to check for fee on transfer
			uint256 beforeBalance = erc20.balanceOf( address(this) );

			erc20.safeTransferFrom(msg.sender, address(this), amountDeposited );

			uint256 afterBalance = erc20.balanceOf( address(this) );

			require( afterBalance == ( beforeBalance + amountDeposited ), "Cannot deposit tokens with a fee on transfer" );
    		}
    	else
    		{
    		require( amountDeposited <= user.freeXSALT, "Staking: Cannot deposit more than the xSALT balance" );

    		user.freeXSALT -= amountDeposited;
    		}

		_accountForDeposit( msg.sender, poolID, isLP, amountDeposited );

        emit eDeposit( msg.sender, poolID, isLP, amountDeposited );
		}


	// When withdrawing xSALT, any pending rewards are claimed
	function withdrawAndClaim( IUniswapV2Pair poolID, bool isLP, uint256 amountWithdrawn ) public nonReentrant
		{
		// Don't allow calling with poolID 0 - which is adjusted by xSALT staking and unstaking
		require( poolID != STAKING, "Staking: Cannot call on poolID 0" );
		require( amountWithdrawn != 0, "Staking: Cannot withdraw 0" );

		UserInfo storage user = userInfo[msg.sender];

		require( block.timestamp >= user.earliestModificationTime[poolID][isLP], "Staking: Must wait for the one hour cooldown to expire" );
		require( user.userDeposits[poolID][isLP] >= amountWithdrawn, "Staking: Only what has been deposited can be withdrawn" );

		// Set the next allowed modification time
		user.earliestModificationTime[poolID][isLP] = block.timestamp + stakingConfig.depositWithdrawalCooldown();

		// Withdraw the deposited LP or xSALT
		if ( isLP )
			{
			require( msg.sender != stakingConfig.saltyDAO(), "Staking: DAO cannot unstake LP" );

			// poolID is the LP token
			IERC20 erc20 = IERC20( address(poolID) );
			erc20.safeTransfer( msg.sender, amountWithdrawn );
    	    }
    	else
    		user.freeXSALT += amountWithdrawn;

		uint256 actualRewards = _accountForWithdrawal( msg.sender, poolID, isLP, amountWithdrawn );

   	    emit eWithdrawAndClaim( msg.sender, poolID, isLP, actualRewards );
		}


	// User claims all available rewards from the pool, but leaves their deposited xSALT or LP in place
	// Basically the call just gives the user the reward, and then increases their borrowed balance
	// by the amount they claim
	//
	// Essentially this is like having the user:
	// 1. Withdraw all deposits and pendingRewards
	// 2. Redeposit the deposits that were withdrawn - which will then borrow rewards to keep the pool balanced
	//
	// As the ratio of rewards / deposits hasn't changed, the amount of borrowed rewards added
	// is the same as the amount of pendingRewards that were withdrawn
	function claimRewards( IUniswapV2Pair poolID, bool isLP ) external nonReentrant
		{
		require( stakingConfig.isValidPool( poolID ), "Staking: Invalid poolID" );

		uint256 actualRewards = userRewards( msg.sender, poolID, isLP );

		UserInfo storage user = userInfo[msg.sender];

		// Indicate that the user has borrowed what they were just awarded
        user.borrowedRewards[poolID][isLP] += actualRewards;

		// Send the actual rewards
        require( stakingConfig.salt().transfer( msg.sender, actualRewards ), "Transfer failed" );

   	    emit eClaimRewards( msg.sender, poolID, isLP, actualRewards );
		}


    function claimAllRewards( IUniswapV2Pair[] memory poolIDs, bool isLP ) external nonReentrant
    	{
		UserInfo storage user = userInfo[msg.sender];

    	uint256 sum = 0;
		for( uint256 i = 0; i < poolIDs.length; i++ )
			{
			IUniswapV2Pair poolID = poolIDs[i];
			require( stakingConfig.isValidPool( poolID ), "Staking: Invalid poolID" );

			uint256 actualRewards = userRewards( msg.sender, poolID, isLP );

			// Indicate that the user has borrowed what they were just awarded
			user.borrowedRewards[poolID][isLP] += actualRewards;

			sum = sum + actualRewards;
			}

		// Send the actual rewards
		require( stakingConfig.salt().transfer( msg.sender, sum ), "Transfer failed" );

   	    emit eClaimAllRewards( msg.sender, sum );
    	}


	// ===== VIEWS =====

	 function unstakesForUser( address wallet, uint256 start, uint256 end ) public view returns (Unstake[] memory)
  		{
		UserInfo storage user = userInfo[wallet];
		Unstake[] memory unstakes = new Unstake[]( end - start + 1 );

		uint256 index;
		for( uint256 i = start; i <= end; i++ )
			unstakes[index++] = unstakesByID[ user.userUnstakeIDs[i]];

		return unstakes;
		}


	function unstakesForUser( address wallet ) external view returns (Unstake[] memory)
		{
		UserInfo storage user = userInfo[wallet];

		uint256[] memory unstakeIDs = user.userUnstakeIDs;
		if ( unstakeIDs.length == 0 )
			return new Unstake[](0);

		return unstakesForUser( wallet, 0, unstakeIDs.length - 1 );
		}


	function userBalanceXSALT( address wallet ) external view returns (uint256)
		{
		UserInfo storage user = userInfo[wallet];

		return user.freeXSALT;
		}


	function totalDepositsForPools( IUniswapV2Pair[] memory poolIDs, bool isLP ) public view returns (uint256[] memory)
		{
		uint256[] memory deposits = new uint256[]( poolIDs.length );

		for( uint256 i = 0; i < deposits.length; i++ )
			{
			IUniswapV2Pair poolID = poolIDs[i];
			deposits[i] = totalDeposits[poolID][isLP];
			}

		return deposits;
		}


	function totalRewardsForPools( IUniswapV2Pair[] memory poolIDs, bool isLP ) public view returns (uint256[] memory)
		{
		uint256[] memory rewards = new uint256[]( poolIDs.length );

		for( uint256 i = 0; i < rewards.length; i++ )
			{
			IUniswapV2Pair poolID = poolIDs[i];
			rewards[i] = totalRewards[poolID][isLP];
			}

		return rewards;
		}


	function userRewards( address wallet, IUniswapV2Pair poolID, bool isLP ) public view
		returns (uint256)
		{
		if ( totalDeposits[poolID][isLP] == 0 )
			return 0;

		UserInfo storage user = userInfo[wallet];

		// Determine the share of the rewards for the user based on their deposits
		uint256 rewardsShare = ( totalRewards[poolID][isLP] * user.userDeposits[poolID][isLP] ) / totalDeposits[poolID][isLP];

		// Reduce by the amount owed
		return rewardsShare - user.borrowedRewards[poolID][isLP];
		}


	// The pending rewards for all pools for a given wallet
	function userRewardsForPools( address wallet, IUniswapV2Pair[] memory poolIDs, bool isLP ) public view returns (uint256[] memory)
		{
		uint256[] memory rewards = new uint256[]( poolIDs.length );

		for( uint256 i = 0; i < rewards.length; i++ )
			{
			IUniswapV2Pair poolID = poolIDs[i];
			rewards[i] = userRewards( wallet, poolID, isLP );
			}

		return rewards;
		}


	// Look through all the valid pools and return what the user has deposited
	// Depending on isLP, either returns the xSALT deposited into each pool
	// Or returns the LP deposited into each pool
	function userDepositsForPools( address wallet, IUniswapV2Pair[] memory poolIDs, bool isLP ) public view returns (uint256[] memory)
		{
		uint256[] memory deposits = new uint256[]( poolIDs.length );

		UserInfo storage user = userInfo[wallet];

		for( uint256 i = 0; i < deposits.length; i++ )
			{
			IUniswapV2Pair poolID = poolIDs[i];
			deposits[i] = user.userDeposits[poolID][isLP];
			}

		return deposits;
		}


	// Time required to modify the xSALT and LP deposits for the various pools
	function userCooldowns( address wallet, IUniswapV2Pair[] memory poolIDs, bool areLPs ) public view returns (uint256[] memory cooldowns)
		{
		cooldowns = new uint256[]( poolIDs.length );

		UserInfo storage user = userInfo[wallet];

		for( uint256 i = 0; i < cooldowns.length; i++ )
			{
			IUniswapV2Pair poolID = poolIDs[i];

			uint256 cooldown = user.earliestModificationTime[poolID][areLPs];
			if ( block.timestamp >= cooldown )
				cooldowns[i] = 0;
			else
				cooldowns[i] = cooldown - block.timestamp;
			}
		}


	// The amount of SALT that is currently staked on the platform as xSALT (whether or not the xSALT
	// is deposited and voting for speciifc pools)
	function totalStakedOnPlatform() public view returns (uint256)
		{
		return totalDeposits[STAKING][false];
		}
	}