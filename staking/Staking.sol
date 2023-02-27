// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.17;

import "../openzeppelin/token/ERC20/ERC20.sol";
import "../openzeppelin/security/ReentrancyGuard.sol";
import "./StakingConfig.sol";
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

    // Status values for Unstakes
    uint256 constant PENDING = 1;
    uint256 constant CANCELLED = 2;
	uint256 constant CLAIMED = 3;


    StakingConfig stakingConfig;


    // The free xSALT balance for each wallet
    // This is xSALT that hasn't been used yet for voting
    mapping(address=>uint256) public freeXSALT;							// [wallet]

	// The unstakeIDs for each wallet
    mapping(address=>uint256[]) public userUnstakeIDs;				// [wallet]

	// Unstakes by unstakeID
    mapping(uint256=>Unstake) public unstakesByID;						// [unstakeID]

	uint256 nextUnstakeID = 0;


    // The total SALT rewards and LP or xSALT deposits for particular pools
    mapping(address=>mapping(bool=>uint256)) public totalRewards;			// [poolID][isLP]
    mapping(address=>mapping(bool=>uint256)) public totalDeposits;			// [poolID][isLP]

	// The amount a user has deposited for particular pools (either LP or xSALT)
    mapping(address=>
    	mapping(address=>mapping(bool=>uint256))) userDeposits;				// [wallet][poolID][isLP]

	// The amount of rewards each user had to borrow when depositing LP or xSALT
	// The rewards are borrowed and deposited so that the ratio of rewards / deposited stays the same
	// It allows us to keep track of owed rewards for users over time (similar to how LP tokens work)
    mapping(address=>
    	mapping(address=>mapping(bool=>uint256))) borrowedRewards;		// [wallet][poolID][isLP]

	// The earliest time at which the user can modify their deposits for a pool (deposit or withdrawal)
	// defaults to one hour cooldown
	mapping(address=>mapping(address=>uint256)) earliestModificationTime; // [wallet][poolID]



	constructor( address _stakingConfig )
		{
		stakingConfig = StakingConfig( _stakingConfig );
		}


	// === STAKING AND UNSTAKING SALT ===

	function stakeSALT( uint256 amountStaked ) external nonReentrant
		{
		address wallet = msg.sender;

		// Deposit the SALT
		stakingConfig.salt().transferFrom( wallet, address(this), amountStaked );

		// User now has more free xSALT
		freeXSALT[wallet] += amountStaked;

		// Keep track of the staking - for general staking rewards that are not pool specific
		_accountForDeposit( wallet, STAKING, false, amountStaked );

		emit eStake( wallet, amountStaked );
		}


	// config.minUnstakePercent returned at config.minUnstakeWeeks
	// 100% return at config.maxUnstakeWeeks
	function calculateUnstake( uint256 unstakedXSALT, uint256 numWeeks ) public view returns (uint256)
		{
		uint256 minUnstakeWeeks = stakingConfig.minUnstakeWeeks();
        uint256 maxUnstakeWeeks = stakingConfig.maxUnstakeWeeks();
        uint256 minUnstakePercent = stakingConfig.minUnstakePercent();

		require( numWeeks >= minUnstakeWeeks, "Staking: Unstaking too short a duration" );
		require( numWeeks <= maxUnstakeWeeks, "Staking: Unstaking too long a duration" );

		// Multiply by 1000000 for precision
		uint256 percent = 1000000 * minUnstakePercent + ( 1000000 * ( 100 - minUnstakePercent ) * ( numWeeks - minUnstakeWeeks ) ) / ( maxUnstakeWeeks - minUnstakeWeeks );

		return ( unstakedXSALT * percent ) / ( 1000000 * 100 );
		}


	function unstake( uint256 amountUnstaked, uint256 numWeeks ) external nonReentrant
		{
		address wallet = msg.sender;

		require( amountUnstaked <= freeXSALT[wallet], "Staking: Cannot unstake more than the xSALT balance" );
		require( wallet != stakingConfig.saltyPOL(), "Staking: Protocol Owned Liquidity cannot unstake" );

		uint256 claimableSALT = calculateUnstake( amountUnstaked, numWeeks );
		uint256 completionTime = block.timestamp + numWeeks * stakingConfig.oneWeek();

		Unstake memory u = Unstake( PENDING, wallet, amountUnstaked, claimableSALT, completionTime, nextUnstakeID );

		unstakesByID[nextUnstakeID] = u;
		userUnstakeIDs[wallet].push( nextUnstakeID );
		nextUnstakeID++;

		// Unstaking immediately reduces the user's balance
		freeXSALT[wallet] -= amountUnstaked;

		// Keep track of the staking - for general staking rewards that are not pool specific
		_accountForWithdrawal( wallet, STAKING, false, amountUnstaked );

		emit eUnstake( wallet, amountUnstaked, numWeeks);
		}


	// Cancel a PENDING unstake
	function cancelUnstake( uint256 unstakeID ) external nonReentrant
		{
		address wallet = msg.sender;

		Unstake storage u = unstakesByID[unstakeID];
		require( u.status == PENDING, "Staking: Only PENDING unstakes can be cancelled" );
		require( block.timestamp < u.completionTime, "Staking: Unstakes that have already completed cannot be cancelled" );
		require( wallet == u.wallet, "Staking: Not the original staker" );

		// User will be able to use the xSALT again
		freeXSALT[wallet] += u.unstakedXSALT;

		// Keep track of the staking - for general staking rewards that are not pool specific
		_accountForDeposit( wallet, STAKING, false, u.unstakedXSALT );

		u.status = CANCELLED;

		emit eCancelUnstake( wallet, unstakeID );
		}


	// Recover the SALT from a given completed unstake
	function recoverSALT( uint256 unstakeID ) external nonReentrant
		{
		address wallet = msg.sender;

		Unstake storage u = unstakesByID[unstakeID];
		require( u.status == PENDING, "Staking: Only PENDING unstakes can be claimed" );
		require( block.timestamp >= u.completionTime, "Staking: Unstake has not completed yet" );
		require( wallet == u.wallet, "Staking: Not the original staker" );

		u.status = CLAIMED;

		uint256 claimableSALT = u.claimableSALT;
		require( claimableSALT <= u.unstakedXSALT, "Staking: Claimable amount has to be less than original stake" );

		stakingConfig.salt().transfer( wallet, claimableSALT );

		// See if the user unstaked early and received only a portion of their original stake
		uint256 earlyUnstakeFee = u.unstakedXSALT - claimableSALT;

		if ( earlyUnstakeFee > 0 )
		if ( stakingConfig.earlyUnstake() != address(0) )
			{
			// Send the earlyUnstakeFee to EarlyUnstake.sol for later distribution on upkeep
			stakingConfig.salt().transfer( stakingConfig.earlyUnstake(), earlyUnstakeFee );
			}

		emit eRecover( wallet, unstakeID, claimableSALT );
		}


	// Transfer xSALT to another wallet
	function transferXSALT( address destination, uint256 amountToTransfer ) public nonReentrant
		{
		address wallet = msg.sender;

		require( destination != address(0), "Staking: Cannot send to address(0)" );
		require( destination != wallet, "Staking: Cannot send to self" );
		require( amountToTransfer <= freeXSALT[wallet], "Staking: Cannot transfer more than the xSALT balance" );
		require( wallet != stakingConfig.saltyPOL(), "Staking: Protocol Owned Liquidity cannot transfer xSALT" );

		freeXSALT[wallet] -= amountToTransfer;
		freeXSALT[destination] += amountToTransfer;

		// Keep track of the staking - for general staking rewards that are not pool specific
		_accountForWithdrawal( wallet, STAKING, false, amountToTransfer );
		_accountForDeposit( destination, STAKING, false, amountToTransfer );

		emit eTransfer( wallet, destination, amountToTransfer );
		}


	// Transfer xSALT to multiple other wallets
	function transferMultipleXSALT( address[] memory destinations, uint256[] memory amountsToTransfer ) external
		{
		for( uint256 i = 0; i < destinations.length; i++ )
			{
			address destination = destinations[i];
			uint256 amountToTransfer = amountsToTransfer[i];

			transferXSALT( destination, amountToTransfer );
			}
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

		// Send the actual rewards corresponding to the withdrawal
		if ( actualRewards != 0 )
			stakingConfig.salt().transfer( wallet, actualRewards );

		// Update totals
		totalRewards[poolID][isLP] -= rewardsForAmount;
		totalDeposits[poolID][isLP] -= amountWithdrawn;

		// Update user deposits and borrowed rewards
		userDeposits[wallet][poolID][isLP] -= amountWithdrawn;
		borrowedRewards[wallet][poolID][isLP] -= borrowedForAmount;

		return actualRewards;
		}


	// Can be added from any wallet
	function addSALTRewards( address[] memory poolIDs, bool[] memory areLPs, uint256[] memory amountsToAdd ) public nonReentrant
		{
		address wallet = msg.sender;

		uint256 sum = 0;
		for( uint256 i = 0; i < poolIDs.length; i++ )
			{
			address poolID = poolIDs[i];
			require( stakingConfig.isValidPool( poolID ), "Staking: Invalid poolID" );

			totalRewards[ poolID ][ areLPs[i] ] += amountsToAdd[i];
			sum = sum + amountsToAdd[i];
			}

		// Transfer in the SALT for all the specified rewards
		if ( sum > 0 )
			stakingConfig.salt().transferFrom( wallet, address(this), sum );
		}


	// Deposit LP tokens or xSALT (which is used for voting on pools)
	function deposit( address poolID, bool isLP, uint256 amountDeposited ) public nonReentrant
		{
		// Don't allow calling with poolID 0 - which is adjusted by xSALT staking and unstaking
		require( poolID != STAKING, "Staking: Cannot call on poolID 0" );
		require( stakingConfig.isValidPool( poolID ), "Staking: Invalid poolID" );
		require( amountDeposited != 0, "Staking: Cannot deposit 0" );

		address wallet = msg.sender;
		require( block.timestamp >= earliestModificationTime[wallet][poolID], "Staking: Must wait for the one hour cooldown to expire" );

		// Transfer the LP or xSALT from the user
		if ( isLP )
    		{
			// poolID is the LP token
			ERC20 erc20 = ERC20( poolID );
    	    erc20.transferFrom( wallet, address(this), amountDeposited );
    		}
    	else
    		{
    		require( amountDeposited <= freeXSALT[wallet], "Staking: Cannot deposit more than the xSALT balance" );

    		freeXSALT[wallet] -= amountDeposited;
    		}

		_accountForDeposit( wallet, poolID, isLP, amountDeposited );

		// Set the next allowed modification time
		earliestModificationTime[wallet][poolID] = block.timestamp + stakingConfig.depositWithdrawalCooldown();

        emit eDeposit( wallet, poolID, isLP, amountDeposited );
		}


	// When withdrawing xSALT, any pending rewards are claimed
	function withdrawAndClaim( address poolID, bool isLP, uint256 amountWithdrawn ) public nonReentrant
		{
		// Don't allow calling with poolID 0 - which is adjusted by xSALT staking and unstaking
		require( poolID != STAKING, "Staking: Cannot call on poolID 0" );
		require( amountWithdrawn != 0, "Staking: Cannot withdraw 0" );

		address wallet = msg.sender;

		require( block.timestamp >= earliestModificationTime[wallet][poolID], "Staking: Must wait for the one hour cooldown to expire" );
		require( userDeposits[wallet][poolID][isLP] >= amountWithdrawn, "Staking: Only what has been deposited can be withdrawn" );
		require( totalDeposits[poolID][isLP] != 0, "Staking: Cannot withdraw with totalDeposits equal to zero" );

		// Withdraw the deposited LP or xSALT
		if ( isLP )
			{
			require( wallet != stakingConfig.saltyPOL(), "Staking: Protocol Owned Liquidity cannot unstake LP" );

			// poolID is the LP token
			ERC20 erc20 = ERC20( poolID );
			erc20.transfer( wallet, amountWithdrawn );
    	    }
    	else
    		freeXSALT[wallet] += amountWithdrawn;

		uint256 actualRewards = _accountForWithdrawal( wallet, poolID, isLP, amountWithdrawn );

		// Set the next allowed modification time
		earliestModificationTime[wallet][poolID] = block.timestamp + stakingConfig.depositWithdrawalCooldown();

   	    emit eWithdrawAndClaim( wallet, poolID, isLP, actualRewards );
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

		address wallet = msg.sender;

		uint256 actualRewards = userRewards( wallet, poolID, isLP );

		// Send the actual rewards
        stakingConfig.salt().transfer( wallet, actualRewards );

		// Indicate that the user has borrowed what they were just awarded
        borrowedRewards[wallet][poolID][isLP] += actualRewards;

   	    emit eClaimRewards( wallet, poolID, isLP, actualRewards );
		}


    function claimAllRewards( address[] memory poolIDs, bool isLP ) external nonReentrant
    	{
		address wallet = msg.sender;

    	uint256 sum = 0;
		for( uint256 i = 0; i < poolIDs.length; i++ )
			{
			address poolID = poolIDs[i];
			require( stakingConfig.isValidPool( poolID ), "Staking: Invalid poolID" );

			uint256 actualRewards = userRewards( wallet, poolID, isLP );

			// Indicate that the user has borrowed what they were just awarded
			borrowedRewards[wallet][poolID][isLP] += actualRewards;

			sum = sum + actualRewards;
			}

		// Send the actual rewards
		stakingConfig.salt().transfer( wallet, sum );

   	    emit eClaimAllRewards( wallet, sum );
    	}


	// ===== VIEWS =====

	function unstakesForUser( address wallet ) external view returns (Unstake[] memory)
		{
		uint256[] memory unstakeIDs = userUnstakeIDs[wallet];

		Unstake[] memory unstakes = new Unstake[]( unstakeIDs.length );

		for( uint256 i = 0; i < unstakes.length; i++ )
			unstakes[i] = unstakesByID[ unstakeIDs[i] ];

		return unstakes;
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


	// Time required to modify the xSALT deposits for the various pools
	function userCooldowns( address wallet, address[] memory poolIDs ) public view returns (uint256[] memory)
		{
		uint256[] memory cooldowns = new uint256[]( poolIDs.length );

		for( uint256 i = 0; i < cooldowns.length; i++ )
			{
			address poolID = poolIDs[i];

			if ( block.timestamp >= earliestModificationTime[wallet][poolID] )
				cooldowns[i] = 0;
			else
				cooldowns[i] = earliestModificationTime[wallet][poolID] - block.timestamp;
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