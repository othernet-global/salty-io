// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.17;

import "../openzeppelin/token/ERC20/IERC20.sol";
import "../openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "../openzeppelin/security/ReentrancyGuard.sol";
import "./IStakingConfig.sol";
import "./IStaking.sol";

// Allows staking SALT for xSALT - which is instant
// Allows unstaking xSALT to SALT - which requires time, with less SALT being returned with less unstake time

// Keeps track of the amount of rewards (as SALT) that each wallet is entitled to
// Rewards are kept track for each pool and deposited token (LP tokens and xSALT)
// Functions similarly to LP tokens in terms of accounting and liquidity share

contract Staking is IStaking, ReentrancyGuard
    {
    // A special poolID which represents staked SALT and allows for general staking rewards
    // that are not tied to a specific pool
    address constant STAKING = address(0);

    // Normally one week - can be modified for debugging
	uint256 constant ONE_WEEK = 5 minutes; // 1 weeks;

    // Status values for Unstakes
    uint8 constant PENDING = 1;
    uint8 constant CANCELLED = 2;
	uint8 constant CLAIMED = 3;



    IStakingConfig public immutable stakingConfig;

    // The free xSALT balance for each wallet
    // This is xSALT that hasn't been used yet for voting
    mapping(address=>uint256) public freeXSALT;							// [wallet]

	// The unstakeIDs for each wallet
    mapping(address=>uint256[]) public userUnstakeIDs;				// [wallet]

	// Unstakes by unstakeID
    mapping(uint256=>Unstake) public unstakesByID;						// [unstakeID]

	uint256 public nextUnstakeID;


    // The total SALT rewards and LP or xSALT deposits for particular pools
    mapping(address=>mapping(bool=>uint256)) public totalRewards;			// [poolID][isLP]
    mapping(address=>mapping(bool=>uint256)) public totalDeposits;			// [poolID][isLP]

	// The amount a user has deposited for particular pools (either LP or xSALT)
    mapping(address=>
    	mapping(address=>mapping(bool=>uint256))) public userDeposits;				// [wallet][poolID][isLP]

	// The amount of rewards each user had to borrow when depositing LP or xSALT
	// The rewards are borrowed and deposited so that the ratio of rewards / deposited stays the same
	// It allows us to keep track of owed rewards for users over time (similar to how LP tokens work)
    mapping(address=>
    	mapping(address=>mapping(bool=>uint256))) public borrowedRewards;		// [wallet][poolID][isLP]

	// The earliest time at which the user can modify their deposits for a pool (deposit or withdrawal)
	// defaults to one hour cooldown
    mapping(address=>
    	mapping(address=>mapping(bool=>uint256))) public earliestModificationTime;	// [wallet][poolID][isLP]


	constructor( address _stakingConfig )
		{
		stakingConfig = IStakingConfig( _stakingConfig );
		}


	// === STAKING AND UNSTAKING SALT ===

	function stakeSALT( uint256 amountStaked ) external nonReentrant
		{
		// Deposit the SALT
		stakingConfig.salt().transferFrom( msg.sender, address(this), amountStaked );

		// User now has more free xSALT
		freeXSALT[msg.sender] += amountStaked;

		// Keep track of the staking - for general staking rewards that are not pool specific
		_accountForDeposit( msg.sender, STAKING, false, amountStaked );

		emit eStake( msg.sender, amountStaked );
		}


	// config.minUnstakePercent returned at config.minUnstakeWeeks
	// 100% return at config.maxUnstakeWeeks
	function calculateUnstake( uint256 unstakedXSALT, uint256 numWeeks ) public view returns (uint256)
		{
		uint256 minUnstakeWeeks = stakingConfig.minUnstakeWeeks();
        uint256 maxUnstakeWeeks = stakingConfig.maxUnstakeWeeks();
        uint256 minUnstakePercent = stakingConfig.minUnstakePercent();

		require( numWeeks >= minUnstakeWeeks, "Staking: Unstaking duraiton too short" );
		require( numWeeks <= maxUnstakeWeeks, "Staking: Unstaking duraiton too long" );

		// Multiply by 1000000 for precision
		uint256 percent = 1000000 * minUnstakePercent + ( 1000000 * ( 100 - minUnstakePercent ) * ( numWeeks - minUnstakeWeeks ) ) / ( maxUnstakeWeeks - minUnstakeWeeks );

		return ( unstakedXSALT * percent ) / ( 1000000 * 100 );
		}


	function unstake( uint256 amountUnstaked, uint256 numWeeks ) external nonReentrant
		{
		require( stakingConfig.earlyUnstake() != address(0), "Staking: earlyUnstake has not been set" );
		require( amountUnstaked <= freeXSALT[msg.sender], "Staking: Cannot unstake more than the xSALT balance" );
		require( msg.sender != stakingConfig.saltyPOL(), "Staking: Protocol Owned Liquidity cannot unstake" );

		uint256 claimableSALT = calculateUnstake( amountUnstaked, numWeeks );
		uint256 completionTime = block.timestamp + numWeeks * ONE_WEEK;

		Unstake memory u = Unstake( PENDING, msg.sender, amountUnstaked, claimableSALT, completionTime, nextUnstakeID );

		unstakesByID[nextUnstakeID] = u;
		userUnstakeIDs[msg.sender].push( nextUnstakeID );
		nextUnstakeID++;

		// Unstaking immediately reduces the user's balance
		freeXSALT[msg.sender] -= amountUnstaked;

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

		// User will be able to use the xSALT again
		freeXSALT[msg.sender] += u.unstakedXSALT;

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
		if ( stakingConfig.earlyUnstake() != address(0) )
			{
			// Send the earlyUnstakeFee to EarlyUnstake.sol for later distribution on upkeep
			stakingConfig.salt().transfer( stakingConfig.earlyUnstake(), earlyUnstakeFee );
			}

		stakingConfig.salt().transfer( msg.sender, claimableSALT );

		emit eRecover( msg.sender, unstakeID, claimableSALT );
		}


	// === REWARDS AND DEPOSITS ===

	function _accountForDeposit( address wallet, address poolID, bool isLP, uint256 amountDeposited ) internal
		{
		// Determine the amountBorrowed based on the current ratio of rewards/deposits
        if ( totalDeposits[poolID][isLP] != 0 ) // prevent / 0
        	{
			// Borrow a proportional amount of rewards (as none are really being deposited)
			// We do this to keep the LP proportion the same
			// The user will need to pay this amount back later
	        uint256 toBorrow = ( amountDeposited * totalRewards[poolID][isLP] ) / totalDeposits[poolID][isLP];

	        borrowedRewards[wallet][poolID][isLP] += toBorrow;
	        totalRewards[poolID][isLP] += toBorrow;
	        }

		// Update the deposit balances
		userDeposits[wallet][poolID][isLP] += amountDeposited;
		totalDeposits[poolID][isLP] += amountDeposited;
		}


	function _accountForWithdrawal( address wallet, address poolID, bool isLP, uint256 amountWithdrawn ) internal returns (uint256)
		{
		// Determine the share of the rewards for the amountWithdrawn (includes borrowed rewards)
		uint256 rewardsForAmount = ( totalRewards[poolID][isLP] * amountWithdrawn ) / totalDeposits[poolID][isLP];

		// Determine how much borrowed will need to be returned for the amountWithdrawn (proportional to all borrowed)
		uint256 borrowedForAmount = ( borrowedRewards[wallet][poolID][isLP] * amountWithdrawn ) / userDeposits[wallet][poolID][isLP];

		// Reduce the rewards by the amount borrowed
		uint256 actualRewards = rewardsForAmount - borrowedForAmount;

		// Update totals
		totalRewards[poolID][isLP] -= rewardsForAmount;
		totalDeposits[poolID][isLP] -= amountWithdrawn;

		// Update user deposits and borrowed rewards
		userDeposits[wallet][poolID][isLP] -= amountWithdrawn;
		borrowedRewards[wallet][poolID][isLP] -= borrowedForAmount;

		// Send the actual rewards corresponding to the withdrawal
		if ( actualRewards != 0 )
			stakingConfig.salt().transfer( wallet, actualRewards );

		return actualRewards;
		}


	// Can be added from any wallet
	function addSALTRewards( address[] memory poolIDs, bool[] memory areLPs, uint256[] memory amountsToAdd ) public nonReentrant
		{
		require( ( poolIDs.length == areLPs.length )  && ( poolIDs.length == amountsToAdd.length), "Staking: Array length mismatch" );

		uint256 sum = 0;
		for( uint256 i = 0; i < poolIDs.length; i++ )
			{
			address poolID = poolIDs[i];
			require( stakingConfig.isValidPool( poolID ), "Staking: Invalid poolID" );

			if ( poolID == STAKING )
				require( ! areLPs[i], "Staking pool cannot deposit LP tokens" );

			totalRewards[ poolID ][ areLPs[i] ] += amountsToAdd[i];
			sum = sum + amountsToAdd[i];
			}

		// Transfer in the SALT for all the specified rewards
		if ( sum > 0 )
			stakingConfig.salt().transferFrom( msg.sender, address(this), sum );
		}


	// Deposit LP tokens or xSALT (which is used for voting on pools)
	function deposit( address poolID, bool isLP, uint256 amountDeposited ) public nonReentrant
		{
		// Don't allow calling with poolID 0 - which is adjusted by xSALT staking and unstaking
		require( poolID != STAKING, "Staking: Cannot call on poolID 0" );
		require( stakingConfig.isValidPool( poolID ), "Staking: Invalid poolID" );
		require( amountDeposited != 0, "Staking: Cannot deposit 0" );

		require( block.timestamp >= earliestModificationTime[msg.sender][poolID][isLP], "Staking: Must wait for the one hour cooldown to expire" );

		// Set the next allowed modification time
		earliestModificationTime[msg.sender][poolID][isLP] = block.timestamp + stakingConfig.depositWithdrawalCooldown();

		// Transfer the LP or xSALT from the user
		if ( isLP )
    		{
			// poolID is the LP token
			IERC20 erc20 = IERC20( poolID );

			// Before balance used to check for fee on transfer
			uint256 beforeBalance = erc20.balanceOf( address(this) );

    	    SafeERC20.safeTransferFrom( erc20, msg.sender, address(this), amountDeposited );

			uint256 afterBalance = erc20.balanceOf( address(this) );

			require( afterBalance == ( beforeBalance + amountDeposited ), "Cannot deposit tokens with a fee on transfer" );
    		}
    	else
    		{
    		require( amountDeposited <= freeXSALT[msg.sender], "Staking: Cannot deposit more than the xSALT balance" );

    		freeXSALT[msg.sender] -= amountDeposited;
    		}

		_accountForDeposit( msg.sender, poolID, isLP, amountDeposited );

        emit eDeposit( msg.sender, poolID, isLP, amountDeposited );
		}


	// When withdrawing xSALT, any pending rewards are claimed
	function withdrawAndClaim( address poolID, bool isLP, uint256 amountWithdrawn ) public nonReentrant
		{
		// Don't allow calling with poolID 0 - which is adjusted by xSALT staking and unstaking
		require( poolID != STAKING, "Staking: Cannot call on poolID 0" );
		require( amountWithdrawn != 0, "Staking: Cannot withdraw 0" );

		require( block.timestamp >= earliestModificationTime[msg.sender][poolID][isLP], "Staking: Must wait for the one hour cooldown to expire" );
		require( userDeposits[msg.sender][poolID][isLP] >= amountWithdrawn, "Staking: Only what has been deposited can be withdrawn" );
		require( totalDeposits[poolID][isLP] != 0, "Staking: Cannot withdraw with totalDeposits equal to zero" );

		// Set the next allowed modification time
		earliestModificationTime[msg.sender][poolID][isLP] = block.timestamp + stakingConfig.depositWithdrawalCooldown();

		// Withdraw the deposited LP or xSALT
		if ( isLP )
			{
			require( msg.sender != stakingConfig.saltyPOL(), "Staking: Protocol Owned Liquidity cannot unstake LP" );

			// poolID is the LP token
			IERC20 erc20 = IERC20( poolID );
			SafeERC20.safeTransfer( erc20, msg.sender, amountWithdrawn );
    	    }
    	else
    		freeXSALT[msg.sender] += amountWithdrawn;

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
	function claimRewards( address poolID, bool isLP ) external nonReentrant
		{
		require( stakingConfig.isValidPool( poolID ), "Staking: Invalid poolID" );

		uint256 actualRewards = userRewards( msg.sender, poolID, isLP );

		// Indicate that the user has borrowed what they were just awarded
        borrowedRewards[msg.sender][poolID][isLP] += actualRewards;

		// Send the actual rewards
        stakingConfig.salt().transfer( msg.sender, actualRewards );

   	    emit eClaimRewards( msg.sender, poolID, isLP, actualRewards );
		}


    function claimAllRewards( address[] memory poolIDs, bool isLP ) external nonReentrant
    	{
    	uint256 sum = 0;
		for( uint256 i = 0; i < poolIDs.length; i++ )
			{
			address poolID = poolIDs[i];
			require( stakingConfig.isValidPool( poolID ), "Staking: Invalid poolID" );

			uint256 actualRewards = userRewards( msg.sender, poolID, isLP );

			// Indicate that the user has borrowed what they were just awarded
			borrowedRewards[msg.sender][poolID][isLP] += actualRewards;

			sum = sum + actualRewards;
			}

		// Send the actual rewards
		stakingConfig.salt().transfer( msg.sender, sum );

   	    emit eClaimAllRewards( msg.sender, sum );
    	}


	// ===== VIEWS =====

	function unstakesForUser( address wallet, uint256 start, uint256 end ) public view returns (Unstake[] memory)
		{
		uint256[] memory unstakeIDs = userUnstakeIDs[wallet];

		Unstake[] memory unstakes = new Unstake[]( end - start + 1 );

		uint256 index;
		for( uint256 i = start; i <= end; i++ )
			unstakes[index++] = unstakesByID[ unstakeIDs[i] ];

		return unstakes;
		}


	function unstakesForUser( address wallet ) external view returns (Unstake[] memory)
		{
		uint256[] memory unstakeIDs = userUnstakeIDs[wallet];

		return unstakesForUser( wallet, 0, unstakeIDs.length - 1 );
		}


	function userBalanceXSALT( address wallet ) external view returns (uint256)
		{
		return freeXSALT[wallet];
		}


	function totalDepositsForPools( address[] memory poolIDs, bool isLP ) public view returns (uint256[] memory)
		{
		uint256[] memory deposits = new uint256[]( poolIDs.length );

		for( uint256 i = 0; i < deposits.length; i++ )
			{
			address poolID = poolIDs[i];
			deposits[i] = totalDeposits[poolID][isLP];
			}

		return deposits;
		}


	function totalRewardsForPools( address[] memory poolIDs, bool isLP ) public view returns (uint256[] memory)
		{
		uint256[] memory rewards = new uint256[]( poolIDs.length );

		for( uint256 i = 0; i < rewards.length; i++ )
			{
			address poolID = poolIDs[i];
			rewards[i] = totalRewards[poolID][isLP];
			}

		return rewards;
		}


	function userRewards( address wallet, address poolID, bool isLP ) public view
		returns (uint256)
		{
		if ( totalDeposits[poolID][isLP] == 0 )
			return 0;

		// Determine the share of the rewards for the user based on their deposits
		uint256 rewardsShare = ( totalRewards[poolID][isLP] * userDeposits[wallet][poolID][isLP] ) / totalDeposits[poolID][isLP];

		// Reduce by the amount owed
		return rewardsShare - borrowedRewards[wallet][poolID][isLP];
		}


	// The pending rewards for all pools for a given wallet
	function userRewardsForPools( address wallet, address[] memory poolIDs, bool isLP ) public view returns (uint256[] memory)
		{
		uint256[] memory rewards = new uint256[]( poolIDs.length );

		for( uint256 i = 0; i < rewards.length; i++ )
			{
			address poolID = poolIDs[i];
			rewards[i] = userRewards( wallet, poolID, isLP );
			}

		return rewards;
		}


	// Look through all the valid pools and return what the user has deposited
	// Depending on isLP, either returns the xSALT deposited into each pool
	// Or returns the LP deposited into each pool
	function userDepositsForPools( address wallet, address[] memory poolIDs, bool isLP ) public view returns (uint256[] memory)
		{
		uint256[] memory deposits = new uint256[]( poolIDs.length );

		for( uint256 i = 0; i < deposits.length; i++ )
			{
			address poolID = poolIDs[i];
			deposits[i] = userDeposits[wallet][poolID][isLP];
			}

		return deposits;
		}


	// Time required to modify the xSALT and LP deposits for the various pools
	function userCooldowns( address wallet, address[] memory poolIDs, bool areLPs ) public view returns (uint256[] memory)
		{
		uint256[] memory cooldowns = new uint256[]( poolIDs.length );

		for( uint256 i = 0; i < cooldowns.length; i++ )
			{
			address poolID = poolIDs[i];

			if ( block.timestamp >= earliestModificationTime[wallet][poolID][areLPs] )
				cooldowns[i] = 0;
			else
				cooldowns[i] = earliestModificationTime[wallet][poolID][areLPs] - block.timestamp;
			}

		return cooldowns;
		}


	// The amount of SALT that is currently staked on the platform as xSALT (whether or not the xSALT
	// is deposited and voting for speciifc pools)
	function totalStakedOnPlatform() public view returns (uint256)
		{
		return totalDeposits[STAKING][false];
		}
	}