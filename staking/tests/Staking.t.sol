// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.12;

import "forge-std/Test.sol";
import "../../Deployment.sol";
import "../../root_tests/TestERC20.sol";
import "../../pools/PoolUtils.sol";
import "../Staking.sol";


contract StakingTest is Test, Deployment
	{
    bytes32[] public poolIDs;

    address public constant alice = address(0x1111);
    address public constant bob = address(0x2222);
    address public constant charlie = address(0x3333);


	constructor()
		{
		// If $COVERAGE=yes, create an instance of the contract so that coverage testing can work
		// Otherwise, what is tested is the actual deployed contract on the blockchain (as specified in Deployment.sol)
		if ( keccak256(bytes(vm.envString("COVERAGE" ))) == keccak256(bytes("yes" )))
			{
			vm.prank(DEPLOYER);
			staking = new Staking(exchangeConfig, poolsConfig, stakingConfig);
			}
		}


    function setUp() public
    	{
    	IERC20 token1 = new TestERC20( 18 );
		IERC20 token2 = new TestERC20( 18 );
		IERC20 token3 = new TestERC20( 18 );

        poolIDs = new bytes32[](3);
        poolIDs[0] = STAKED_SALT;
        (poolIDs[1],) = PoolUtils.poolID(token1, token2);
        (poolIDs[2],) = PoolUtils.poolID(token2, token3);

        // Whitelist lp
		vm.startPrank( address(dao) );
        poolsConfig.whitelistPool(token1, token2);
        poolsConfig.whitelistPool(token2, token3);
		vm.stopPrank();

		vm.prank(DEPLOYER);
		salt.transfer( address(this), 100000 ether );

        // This contract approves max to staking so that SALT rewards can be added
        salt.approve(address(staking), type(uint256).max);

        // Alice gets some salt and pool lps and approves max to staking
        salt.transfer(alice, 100 ether);
        vm.prank(alice);
        salt.approve(address(staking), type(uint256).max);

        // Bob gets some salt and pool lps and approves max to staking
        salt.transfer(bob, 100 ether);
        vm.prank(bob);
        salt.approve(address(staking), type(uint256).max);

        // Charlie gets some salt and pool lps and approves max to staking
        salt.transfer(charlie, 100 ether);
        vm.prank(charlie);
        salt.approve(address(staking), type(uint256).max);
    	}


	function totalStakedForPool( bytes32 poolID ) public view returns (uint256)
		{
		bytes32[] memory _poolIDs = new bytes32[](1);
		_poolIDs[0] = poolID;

		return staking.totalSharesForPools(_poolIDs)[0];
		}


	// A unit test which tests a user stakes various amounts of SALT tokens and checks that the user's freeXSALT, total shares of STAKED_SALT and the contract's SALT balance are updated correctly.
	function testStakingVariousAmounts() public {
	uint256 startingBalance = salt.balanceOf( address(staking) );

    // Alice stakes 5 ether of SALT tokens
    vm.prank(alice);
    staking.stakeSALT(5 ether);
    assertEq(staking.userFreeXSalt(alice), 5 ether);
    assertEq(staking.userShareForPool(alice, STAKED_SALT), 5 ether);
    assertEq(salt.balanceOf(address(staking)) - startingBalance, 5 ether);


    // Bob stakes 10 ether of SALT tokens
    vm.prank(bob);
    staking.stakeSALT(10 ether);
    assertEq(staking.userFreeXSalt(bob), 10 ether);
    assertEq(staking.userShareForPool(bob, STAKED_SALT), 10 ether);
    assertEq(salt.balanceOf(address(staking)) - startingBalance, 15 ether);

    // Charlie stakes 20 ether of SALT tokens
    vm.prank(charlie);
    staking.stakeSALT(20 ether);
    assertEq(staking.userFreeXSalt(charlie), 20 ether);
    assertEq(staking.userShareForPool(charlie, STAKED_SALT), 20 ether);
    assertEq(salt.balanceOf(address(staking)) - startingBalance, 35 ether);

    // Alice stakes an additional 3 ether of SALT tokens
    vm.prank(alice);
    staking.stakeSALT(3 ether);
    assertEq(staking.userFreeXSalt(alice), 8 ether);
    assertEq(staking.userShareForPool(alice, STAKED_SALT), 8 ether);
    assertEq(salt.balanceOf(address(staking)) - startingBalance, 38 ether);
    }


	// A unit test which tests a user trying to unstake more SALT tokens than they have staked, and checks that the transaction reverts with an appropriate error message.
	function testUnstakeMoreThanStaked() public {
	// Alice stakes 5 SALT
	vm.prank(alice);
	staking.stakeSALT(5 ether);

	// Try to unstake 10 SALT, which is more than Alice has staked
	vm.expectRevert("Cannot unstake more than the xSALT balance");
	staking.unstake(10 ether, 4);
	}


	// A unit test which tests a user unstaking SALT tokens with various numbers of weeks for the unstaking duration, including edge cases like minimum and maximum weeks allowed, and checks that the resulting claimable SALT and completion time are calculated correctly.
	function testUnstakingSALTWithVariousDurations() public {

	vm.startPrank(alice);

    uint256 initialStake = 100 ether;

    // Alice stakes SALT
    staking.stakeSALT(initialStake);

    // Set different unstaking durations
    uint256[] memory durations = new uint256[](3);
    durations[0] = stakingConfig.minUnstakeWeeks();
    durations[1] = 14;
    durations[2] = stakingConfig.maxUnstakeWeeks();

	// Test unstaking with different durations
	for (uint256 i = 0; i < durations.length; i++)
		{
		uint256 unstakeAmount = 20 ether;
		uint256 duration = durations[i];

		// Unstake SALT
		uint256 unstakeID = staking.unstake(unstakeAmount, duration);
		Unstake memory unstake = staking.unstakeByID(unstakeID);

		// Check unstake info
		assertEq(unstake.wallet, alice);
		assertEq(unstake.unstakedXSALT, unstakeAmount);
		assertEq(unstake.completionTime, block.timestamp + duration * 1 weeks);

		// Calculate expected claimable SALT
		uint256 expectedClaimableSALT0 = staking.calculateUnstake(unstakeAmount, duration);
		uint256 expectedClaimableSALT;
		if ( i == 0 )
			expectedClaimableSALT =10 ether;
		if ( i == 1 )
			expectedClaimableSALT =15 ether;
		if ( i == 2 )
			expectedClaimableSALT =20 ether;

		assertEq(expectedClaimableSALT0, expectedClaimableSALT);
		assertEq(unstake.claimableSALT, expectedClaimableSALT);

		// Warp time to complete unstaking
		vm.warp(unstake.completionTime);

		// Recover SALT
		uint256 saltBalance = salt.balanceOf(alice);
		staking.recoverSALT(unstakeID);

		// Check recovered SALT
		assertEq(salt.balanceOf(alice) - saltBalance, expectedClaimableSALT);
		}
   	}


	function totalStakedOnPlatform() internal view returns (uint256)
		{
		bytes32[] memory pools = new bytes32[](1);
		pools[0] = STAKED_SALT;
	
		return staking.totalSharesForPools(pools)[0];
		}
		
		
	// A unit test which tests a user unstaking SALT tokens, and checks that the user's freeXSALT, total shares of STAKED_SALT, the unstakeByID mapping, and the user's unstakeIDs are updated correctly.
	function testUnstake() public {
    uint256 stakeAmount = 10 ether;

    vm.startPrank(alice);
    staking.stakeSALT(stakeAmount);

    uint256 unstakeAmount = 5 ether;
    uint256 numWeeks = 4;
	uint256 unstakeID = staking.unstake(unstakeAmount, numWeeks);
	Unstake memory unstake = staking.unstakeByID(unstakeID);

	assertEq(unstake.wallet, alice);
	assertEq(unstake.unstakedXSALT, unstakeAmount);
	assertEq(unstake.completionTime, block.timestamp + numWeeks * (1 weeks));

	uint256 userFreeXSALT = staking.userFreeXSalt(alice);
	assertEq(userFreeXSALT, stakeAmount - unstakeAmount);

	uint256 totalStaked = totalStakedOnPlatform();
	assertEq(totalStaked, stakeAmount - unstakeAmount);

	uint256[] memory userUnstakeIDs = staking.userUnstakeIDs(alice);
	assertEq(userUnstakeIDs[userUnstakeIDs.length - 1], unstakeID);
    }


	// A unit test which tests a user cancelling an unstake request in various scenarios, such as before and after the unstake completion time, and checks that the user's freeXSALT, total shares of STAKED_SALT, and the unstakeByID mapping are updated correctly.
	function testCancelUnstake() public {
	vm.startPrank(alice);

	// Alice stakes 10 ether
	staking.stakeSALT(10 ether);
	assertEq(staking.userFreeXSalt(alice), 10 ether);
	assertEq(totalStakedOnPlatform(), 10 ether);

	// Alice creates an unstake request with 5 ether for 3 weeks
	uint256 unstakeID = staking.unstake(5 ether, 3);
	assertEq(staking.userFreeXSalt(alice), 5 ether);
	assertEq(totalStakedOnPlatform(), 5 ether);

	// Alice cancels the unstake request before the completion time
	vm.warp(block.timestamp + 2 weeks);
	staking.cancelUnstake(unstakeID);
	assertEq(staking.userFreeXSalt(alice), 10 ether);
	assertEq(totalStakedOnPlatform(), 10 ether);
	assertTrue(uint256(staking.unstakeByID(unstakeID).status) == uint256(UnstakeState.CANCELLED));

	// Try to cancel the unstake again
	vm.expectRevert("Only PENDING unstakes can be cancelled");
	staking.cancelUnstake(unstakeID);

	// Alice creates another unstake request with 5 ether for 4 weeks
	unstakeID = staking.unstake(5 ether, 4);
	assertEq(staking.userFreeXSalt(alice), 5 ether);
	assertEq(totalStakedOnPlatform(), 5 ether);

	// Alice tries to cancel the unstake request after the completion time
	vm.warp(block.timestamp + 5 weeks);
	vm.expectRevert("Unstakes that have already completed cannot be cancelled");
	staking.cancelUnstake(unstakeID);

	// Alice's freeXSALT and total shares of STAKED_SALT remain the same
	assertEq(staking.userFreeXSalt(alice), 5 ether);
	assertEq(totalStakedOnPlatform(), 5 ether);
	}


	// A unit test which tests a user recovering SALT tokens after unstaking in various scenarios, such as early unstaking with a fee, and checks that the user's SALT balance, the unstakeByID mapping, and the earlyUnstake fee distribution are updated correctly.
	function testRecoverSALTAfterUnstaking() public {
	vm.startPrank(alice);

	// Alice stakes 5 ether of SALT
	staking.stakeSALT(5 ether);

	uint256 startingSaltSupply = salt.totalSupply();

	// Unstake with 3 weeks penalty
	uint256 unstakeID = staking.unstake(5 ether, 3);

	// Verify that unstake is pending
	Unstake memory u = staking.unstakeByID(unstakeID);
	assertEq(uint256(u.status), uint256(UnstakeState.PENDING));

	// Alice's xSALT balance should be 0
	assertEq(staking.userFreeXSalt(alice), 0 ether);

	// Advance time by 3 weeks
	vm.warp(block.timestamp + 3 * 1 weeks);

	// Alice recovers her SALT
	staking.recoverSALT(unstakeID);

	// Verify that unstake is claimed
	u = staking.unstakeByID(unstakeID);
	assertEq(uint256(u.status), uint256(UnstakeState.CLAIMED));

	// Alice should have received the expected amount of SALT
	uint256 claimableSALT = u.claimableSALT;
	assertEq(salt.balanceOf(alice), 95 ether + claimableSALT);

	// Verify the earlyUnstakeFee was burnt
	uint256 earlyUnstakeFee = u.unstakedXSALT - claimableSALT;

	uint256 burnedSalt = startingSaltSupply - salt.totalSupply();
	assertEq( burnedSalt, earlyUnstakeFee);
	}


	// A unit test which tests a user depositing votes for various poolIDs and amounts of SALT tokens, and checks that the user's freeXSALT, total shares for the pool, and the user's pool shares are updated correctly.
	function testDepositVotesForVariousPoolsAndAmounts() public {
    vm.startPrank(alice);

	uint256 initialStake = 10 ether;
	uint256[] memory voteAmounts = new uint256[](2);
	voteAmounts[0] = 8 ether;
	voteAmounts[1] = 2 ether;

	// Alice stakes 10 ether
	staking.stakeSALT(initialStake);

	// Check Alice's free xSALT balance
	assertEq(staking.userFreeXSalt(alice), initialStake);

	// Alice votes for pool[1] and pool[2]
	uint256[] memory poolIDsToVote = new uint256[](2);
	poolIDsToVote[0] = 1;
	poolIDsToVote[1] = 2;

	uint256 xsaltBalance = staking.userFreeXSalt(alice);
	for(uint256 i = 0; i < poolIDsToVote.length; i++) {
		staking.depositVotes(poolIDs[poolIDsToVote[i]], voteAmounts[i]);

		// Check freeXSALT, total shares for the pool, and user's pool shares
		assertEq(staking.userFreeXSalt(alice), xsaltBalance - voteAmounts[i]);
		assertEq(totalStakedForPool(poolIDs[poolIDsToVote[i]]), voteAmounts[i]);
		assertEq(staking.userShareForPool(alice, poolIDs[poolIDsToVote[i]]), voteAmounts[i]);

		xsaltBalance = staking.userFreeXSalt(alice);
	}

	// After voting for both poolIDs, Alice should have no free xSALT left
	assertEq(staking.userFreeXSalt(alice), 0);
    }


	// A unit test which tests a user trying to deposit more votes than their available freeXSALT balance, and checks that the transaction reverts with an appropriate error message.
	function testDepositVotesExceedsFreeXSALT() public {
		vm.startPrank(alice);

        // Alice stakes 5 ether
        staking.stakeSALT(5 ether);

        // Check that the balance of xSALT for Alice is 5 ether
        assertEq(staking.userFreeXSalt(alice), 5 ether);

        // Try to deposit more votes than the available freeXSALT balance
        // This should cause a revert
        vm.expectRevert("Cannot vote with more than the available xSALT balance");
        staking.depositVotes(poolIDs[1], 10 ether);
    }


	// A unit test which tests a user removing votes and claiming rewards for various poolIDs and amounts of SALT tokens, and checks that the user's freeXSALT, total shares for the pool, the user's pool shares, and the user's SALT balance are updated correctly.
	function testUserRemovesVotesAndClaimsRewards() public {
        // Set up initial staking for Alice in pool 1 and pool 2
        vm.startPrank(alice);
        staking.stakeSALT(5 ether);
        staking.depositVotes(poolIDs[1], 3 ether);
        staking.depositVotes(poolIDs[2], 2 ether);
        vm.warp(block.timestamp + 1 days);  // Simulate one day passing

        // Verify initial state
        assertEq(staking.userFreeXSalt(alice), 0 ether);
        assertEq(totalStakedForPool(poolIDs[1]), 3 ether);
        assertEq(totalStakedForPool(poolIDs[2]), 2 ether);
        assertEq(staking.userShareForPool(alice, poolIDs[1]), 3 ether);
        assertEq(staking.userShareForPool(alice, poolIDs[2]), 2 ether);
        assertEq(staking.userPendingReward(alice, poolIDs[1]), 0 ether);  // No rewards yet
        assertEq(staking.userPendingReward(alice, poolIDs[2]), 0 ether);

        // Alice removes votes and claims rewards from pool 1
        staking.removeVotesAndClaim(poolIDs[1], 3 ether);

        // Verify state after removing votes and claiming rewards from pool 1
        assertEq(staking.userFreeXSalt(alice), 3 ether);
        assertEq(totalStakedForPool(poolIDs[1]), 0 ether);
        assertEq(staking.userShareForPool(alice, poolIDs[1]), 0 ether);
        assertEq(staking.userPendingReward(alice, poolIDs[1]), 0 ether);  // Rewards should have been claimed

        // Alice removes votes and claims rewards from pool 2
        staking.removeVotesAndClaim(poolIDs[2], 2 ether);

        // Verify state after removing votes and claiming rewards from pool 2
        assertEq(staking.userFreeXSalt(alice), 5 ether);
        assertEq(totalStakedForPool(poolIDs[2]), 0 ether);
        assertEq(staking.userShareForPool(alice, poolIDs[2]), 0 ether);
        assertEq(staking.userPendingReward(alice, poolIDs[2]), 0 ether);  // Rewards should have been claimed
    }


	// A unit test which tests the unstakesForUser function for a user with various numbers of unstake requests, and checks that the returned Unstake structs array is accurate.
	function testUnstakesForUser() public {
        vm.startPrank(alice);

        Unstake[] memory noUnstakes = staking.unstakesForUser(alice);
        assertEq( noUnstakes.length, 0 );

        // stake some SALT
        uint256 amountToStake = 10 ether;
        staking.stakeSALT(amountToStake);

        staking.unstake(2 ether, 5);
        staking.unstake(3 ether, 6);
        staking.unstake(4 ether, 7);

        // unstake with different weeks to create multiple unstake requests
        Unstake[] memory unstakes = staking.unstakesForUser(alice);

        // Check the length of the returned array
        assertEq(unstakes.length, 3);

        // Check the details of each unstake struct
        Unstake memory unstake1 = unstakes[0];
        Unstake memory unstake2 = unstakes[1];
        Unstake memory unstake3 = unstakes[2];

        assertEq(uint256(unstake1.status), uint256(UnstakeState.PENDING));
        assertEq(unstake1.wallet, alice);
        assertEq(unstake1.unstakedXSALT, 2 ether);

        assertEq(uint256(unstake2.status), uint256(UnstakeState.PENDING));
        assertEq(unstake2.wallet, alice);
        assertEq(unstake2.unstakedXSALT, 3 ether);

        assertEq(uint256(unstake3.status), uint256(UnstakeState.PENDING));
        assertEq(unstake3.wallet, alice);
        assertEq(unstake3.unstakedXSALT, 4 ether);
    }


	// A unit test which tests the userFreeXSalt function for various users and checks that the returned freeXSALT balance is accurate.
	function testUserBalanceXSALT2() public {
        // Alice stakes 5 ether
        vm.prank(alice);
        staking.stakeSALT(5 ether);
        assertEq(staking.userFreeXSalt(alice), 5 ether);

        // Bob stakes 10 ether
        vm.prank(bob);
        staking.stakeSALT(10 ether);
        assertEq(staking.userFreeXSalt(bob), 10 ether);

        // Charlie stakes 20 ether
        vm.prank(charlie);
        staking.stakeSALT(20 ether);
        assertEq(staking.userFreeXSalt(charlie), 20 ether);

        // Alice unstakes 2 ether
        vm.prank(alice);
        uint256 unstakeID = staking.unstake(2 ether, 5);
        Unstake memory unstakeInfo = staking.unstakeByID(unstakeID);
        assertEq(unstakeInfo.unstakedXSALT, 2 ether);
        assertEq(staking.userFreeXSalt(alice), 3 ether);

        // Bob unstakes 5 ether
        vm.prank(bob);
        unstakeID = staking.unstake(5 ether, 5);
        unstakeInfo = staking.unstakeByID(unstakeID);
        assertEq(unstakeInfo.unstakedXSALT, 5 ether);
        assertEq(staking.userFreeXSalt(bob), 5 ether);

        // Charlie unstakes 10 ether
        vm.prank(charlie);
        unstakeID = staking.unstake(10 ether, 5);
        unstakeInfo = staking.unstakeByID(unstakeID);
        assertEq(unstakeInfo.unstakedXSALT, 10 ether);
        assertEq(staking.userFreeXSalt(charlie), 10 ether);
    }


	// A unit test which tests the totalStakedOnPlatform function and checks that the returned total amount of staked SALT is accurate.
	function testUserBalanceXSALT() public {
        // Alice stakes 50 ether (SALT)
        vm.prank(alice);
        staking.stakeSALT(50 ether);
        assertEq(staking.userFreeXSalt(alice), 50 ether);

        // Bob stakes 70 ether (SALT)
        vm.prank(bob);
        staking.stakeSALT(70 ether);
        assertEq(staking.userFreeXSalt(bob), 70 ether);

        // Charlie stakes 30 ether (SALT)
        vm.prank(charlie);
        staking.stakeSALT(30 ether);
        assertEq(staking.userFreeXSalt(charlie), 30 ether);

        // Alice unstakes 20 ether
        vm.prank(alice);
        uint256 aliceUnstakeID = staking.unstake(20 ether, 4);
        // Check Alice's new balance
        assertEq(staking.userFreeXSalt(alice), 30 ether);

        // Bob unstakes 50 ether
        vm.prank(bob);
        staking.unstake(50 ether, 4);
        // Check Bob's new balance
        assertEq(staking.userFreeXSalt(bob), 20 ether);

        // Charlie unstakes 10 ether
        vm.prank(charlie);
        staking.unstake(10 ether, 4);
        // Check Charlie's new balance
        assertEq(staking.userFreeXSalt(charlie), 20 ether);

        // Alice cancels unstake
        vm.prank(alice);
        staking.cancelUnstake(aliceUnstakeID);
        // Check Alice's new balance
        assertEq(staking.userFreeXSalt(alice), 50 ether);

        uint256 totalStaked = totalStakedOnPlatform();
       	assertEq(totalStaked, 90 ether);

    }


	// A unit test which tests the userUnstakeIDs function for various users and checks that the returned array of unstake IDs is accurate.
	function testUserUnstakeIDs() public {
        // Alice stakes 10 ether
        vm.startPrank(alice);
        staking.stakeSALT(10 ether);
        assertEq(staking.userFreeXSalt(alice), 10 ether);

        // Alice unstakes 5 ether for 3 weeks
        uint256 aliceUnstakeID1 = staking.unstake(5 ether, 3);
        assertEq(staking.unstakeByID(aliceUnstakeID1).unstakedXSALT, 5 ether);

        // Alice unstakes another 2 ether for 2 weeks
        uint256 aliceUnstakeID2 = staking.unstake(2 ether, 2);
        assertEq(staking.unstakeByID(aliceUnstakeID2).unstakedXSALT, 2 ether);

        // Check that Alice's unstake IDs are correct
        assertEq(staking.userUnstakeIDs(alice).length, 2);
        assertEq(staking.userUnstakeIDs(alice)[0], aliceUnstakeID1);
        assertEq(staking.userUnstakeIDs(alice)[1], aliceUnstakeID2);

		vm.stopPrank();

        // Bob stakes 20 ether
        vm.startPrank(bob);
        staking.stakeSALT(20 ether);
        assertEq(staking.userFreeXSalt(bob), 20 ether);

        // Bob unstakes 10 ether for 4 weeks
        uint256 bobUnstakeID1 = staking.unstake(10 ether, 4);
        assertEq(staking.unstakeByID(bobUnstakeID1).unstakedXSALT, 10 ether);

        // Check that Bob's unstake IDs are correct
        assertEq(staking.userUnstakeIDs(bob).length, 1);
        assertEq(staking.userUnstakeIDs(bob)[0], bobUnstakeID1);

        // Charlie doesn't stake anything, so he should have no unstake IDs
        assertEq(staking.userUnstakeIDs(charlie).length, 0);
    }


	// A unit test which tests multiple users staking SALT tokens simultaneously and checks that the users' freeXSALT, total shares of STAKED_SALT, and the contract's SALT balance are updated correctly without conflicts.
	function testSimultaneousStaking() public {
        uint256 initialSaltBalance = salt.balanceOf(address(staking));
        uint256 aliceStakeAmount = 10 ether;
        uint256 bobStakeAmount = 20 ether;
        uint256 charlieStakeAmount = 30 ether;

        // Alice stakes
        vm.prank(alice);
        staking.stakeSALT(aliceStakeAmount);

        // Bob stakes
        vm.prank(bob);
        staking.stakeSALT(bobStakeAmount);

        // Charlie stakes
        vm.prank(charlie);
        staking.stakeSALT(charlieStakeAmount);

        // Check that freeXSALT, totalShares and contract's SALT balance are updated correctly
        assertEq(staking.userFreeXSalt(alice), aliceStakeAmount);
        assertEq(staking.userFreeXSalt(bob), bobStakeAmount);
        assertEq(staking.userFreeXSalt(charlie), charlieStakeAmount);

        assertEq(totalStakedForPool(STAKED_SALT), aliceStakeAmount + bobStakeAmount + charlieStakeAmount);
        assertEq(salt.balanceOf(address(staking)), initialSaltBalance + aliceStakeAmount + bobStakeAmount + charlieStakeAmount);
    }


	// A unit test which tests multiple users depositing and removing votes simultaneously for various poolIDs and amounts of SALT tokens, and checks that the users' freeXSALT, total shares for the pool, and the user's pool shares are updated correctly without conflicts.
	function testDepositAndRemoveVotes() public {
        vm.startPrank(alice);
        staking.stakeSALT(50 ether);
        staking.depositVotes(poolIDs[1], 20 ether);
        assertEq(staking.userFreeXSalt(alice), 30 ether);
        assertEq(totalStakedForPool(poolIDs[1]), 20 ether);
        assertEq(staking.userShareForPool(alice, poolIDs[1]), 20 ether);
        vm.stopPrank();

        vm.startPrank(bob);
        staking.stakeSALT(40 ether);
        staking.depositVotes(poolIDs[1], 15 ether);
        assertEq(staking.userFreeXSalt(bob), 25 ether);
        assertEq(totalStakedForPool(poolIDs[1]), 35 ether);
        assertEq(staking.userShareForPool(bob, poolIDs[1]), 15 ether);
        vm.stopPrank();

        vm.startPrank(charlie);
        staking.stakeSALT(60 ether);
        staking.depositVotes(poolIDs[2], 30 ether);
        assertEq(staking.userFreeXSalt(charlie), 30 ether);
        assertEq(totalStakedForPool(poolIDs[2]), 30 ether);
        assertEq(staking.userShareForPool(charlie, poolIDs[2]), 30 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 weeks);

        vm.startPrank(alice);
        staking.removeVotesAndClaim(poolIDs[1], 10 ether);
        assertEq(staking.userFreeXSalt(alice), 40 ether);
        assertEq(totalStakedForPool(poolIDs[1]), 25 ether);
        assertEq(staking.userShareForPool(alice, poolIDs[1]), 10 ether);
        vm.stopPrank();

        vm.startPrank(bob);
        staking.removeVotesAndClaim(poolIDs[1], 5 ether);
        assertEq(staking.userFreeXSalt(bob), 30 ether);
        assertEq(totalStakedForPool(poolIDs[1]), 20 ether);
        assertEq(staking.userShareForPool(bob, poolIDs[1]), 10 ether);
        vm.stopPrank();

        vm.startPrank(charlie);
        staking.removeVotesAndClaim(poolIDs[2], 10 ether);
        assertEq(staking.userFreeXSalt(charlie), 40 ether);
        assertEq(totalStakedForPool(poolIDs[2]), 20 ether);
        assertEq(staking.userShareForPool(charlie, poolIDs[2]), 20 ether);
        vm.stopPrank();
    }


	// A unit test which tests a user trying to stake a negative amount of SALT tokens and checks that the transaction reverts with an appropriate error message.
	function testStakeNegativeAmount() public {
        uint256 initialBalance = staking.userFreeXSalt(alice);
        uint256 amountToStake = uint256(int256(-1));

        vm.expectRevert("ERC20: transfer amount exceeds balance");
        vm.prank(alice);
        staking.stakeSALT(amountToStake);

        // Assert that Alice's balance remains unchanged
        assertEq(staking.userFreeXSalt(alice), initialBalance);
    }


	// A unit test which tests a user trying to unstake a negative amount of SALT tokens and checks that the transaction reverts with an appropriate error message.
	 function testUnstakeNegativeAmount() public {
            vm.startPrank(alice);
            uint256 amountToStake = 5 ether;
            staking.stakeSALT(amountToStake);

            uint256 unstakeAmount = uint256(int256(-1));

            vm.expectRevert("Cannot unstake more than the xSALT balance");
            staking.unstake(unstakeAmount, 4);
            vm.stopPrank();
        }


	// A unit test which tests a user trying to deposit a negative amount of votes and checks that the transaction reverts with an appropriate error message.
	function testUserDepositNegativeVotes() public {
		vm.startPrank(alice);
        // Assume Alice has some free xSALT to vote with
        staking.stakeSALT(10 ether);

        // Attempt to deposit negative votes, expecting a revert
        vm.expectRevert("Cannot vote with more than the available xSALT balance");
        staking.depositVotes(poolIDs[1], uint256(int256(-1 ether)));
    }


	// A unit test which tests a user trying to remove a negative amount of votes and checks that the transaction reverts with an appropriate error message.
	function testRemoveNegativeVotesRevert() public {
        vm.startPrank(alice);

        // Assuming alice initially staked some SALT to have xSALT
        staking.stakeSALT(10 ether);

        // Alice deposits votes to pool[1] with all xSALT
        staking.depositVotes(poolIDs[1], 10 ether);

        // Alice tries to remove negative votes
        uint256 negativeVotes = uint256(int256(-5 ether));
        vm.expectRevert("Cannot decrease more than existing user share");
        staking.removeVotesAndClaim(poolIDs[1], negativeVotes);

        vm.stopPrank();
    }


	// A unit test which tests multiple users trying to cancel each other's unstake requests and checks that only the original staker can cancel the request.
	function testCancelUnstake2() public {
        uint256 amountToStake = 10 ether;

        // Alice stakes SALT
        vm.prank(alice);
        staking.stakeSALT(amountToStake);
        assertEq(staking.userFreeXSalt(alice), amountToStake);

        // Alice unstakes
        vm.prank(alice);
        uint256 aliceUnstakeID = staking.unstake(amountToStake, 4);
        assertEq(staking.userFreeXSalt(alice), 0);

        // Bob tries to cancel Alice's unstake request, should revert
        vm.prank(bob);
        vm.expectRevert("Not the original staker");
        staking.cancelUnstake(aliceUnstakeID);

        // Charlie tries to cancel Alice's unstake request, should revert
        vm.prank(charlie);
        vm.expectRevert("Not the original staker");
        staking.cancelUnstake(aliceUnstakeID);

        // Alice cancels her unstake request
        vm.prank(alice);
        staking.cancelUnstake(aliceUnstakeID);
        assertEq(staking.userFreeXSalt(alice), amountToStake);

        // Verify unstake status is CANCELLED
        Unstake memory unstake = staking.unstakeByID(aliceUnstakeID);
        assertEq(uint256(unstake.status), uint256(UnstakeState.CANCELLED));
    }


	// A unit test which tests multiple users trying to recover each other's SALT tokens after unstaking and checks that only the original staker can recover the tokens.
	 function testRecoverSalt() public {
            // Alice, Bob and Charlie stake 50 SALT each
            vm.prank(alice);
            staking.stakeSALT(50 ether);
            vm.prank(bob);
            staking.stakeSALT(50 ether);
            vm.prank(charlie);
            staking.stakeSALT(50 ether);

            // Ensure they have staked correctly
            assertEq(staking.userFreeXSalt(alice), 50 ether);
            assertEq(staking.userFreeXSalt(bob), 50 ether);
            assertEq(staking.userFreeXSalt(charlie), 50 ether);

            // They unstake after a week
            vm.prank(alice);
            uint256 aliceUnstakeID = staking.unstake(10 ether, 2);
            vm.prank(bob);
            uint256 bobUnstakeID = staking.unstake(20 ether, 2);
            vm.prank(charlie);
            uint256 charlieUnstakeID = staking.unstake(30 ether, 2);

            // Warp time by a week
            vm.warp(block.timestamp + 2 weeks);

            // They try to recover each other's SALT
            vm.startPrank(alice);
            vm.expectRevert("Not the original staker");
            staking.recoverSALT(bobUnstakeID);
            vm.expectRevert("Not the original staker");
            staking.recoverSALT(charlieUnstakeID);
            vm.stopPrank();

            vm.startPrank(bob);
            vm.expectRevert("Not the original staker");
            staking.recoverSALT(aliceUnstakeID);
            vm.expectRevert("Not the original staker");
            staking.recoverSALT(charlieUnstakeID);
            vm.stopPrank();

            vm.startPrank(charlie);
            vm.expectRevert("Not the original staker");
            staking.recoverSALT(aliceUnstakeID);
            vm.expectRevert("Not the original staker");
            staking.recoverSALT(bobUnstakeID);
            vm.stopPrank();

            // They recover their own SALT
            uint256 aliceSalt = salt.balanceOf(alice);
	 		uint256 bobSalt = salt.balanceOf(bob);
            uint256 charlieSalt = salt.balanceOf(charlie);

            vm.prank(alice);
            staking.recoverSALT(aliceUnstakeID);
            vm.prank(bob);
            staking.recoverSALT(bobUnstakeID);
            vm.prank(charlie);
            staking.recoverSALT(charlieUnstakeID);

            // Check the amount of SALT that was recovered
            // With a two week unstake, only 50% of the originally staked SALT is recovered
            assertEq(salt.balanceOf(alice) - aliceSalt, 5 ether);
            assertEq(salt.balanceOf(bob) - bobSalt, 10 ether);
            assertEq(salt.balanceOf(charlie) - charlieSalt, 15 ether);

            // Check the final xSALT balances
            assertEq(staking.userFreeXSalt(alice), 40 ether);
            assertEq(staking.userFreeXSalt(bob), 30 ether);
            assertEq(staking.userFreeXSalt(charlie), 20 ether);
        }


	// A unit test to check if the contract reverts when trying to stake an amount of SALT greater than the user's balance.
	function testStakeExcessSALT() public {
		vm.startPrank(alice);

        uint256 initialAliceBalance = salt.balanceOf(alice);
        uint256 excessAmount = initialAliceBalance + 1 ether;

        vm.expectRevert("ERC20: transfer amount exceeds balance");
        staking.stakeSALT(excessAmount);
    }


	// A unit test to check if the contract reverts when trying to unstake using an invalid unstakeID.
	function testInvalidUnstakeID() public
        {
        uint256 invalidUnstakeID = type(uint256).max;  // Assuming max uint256 is an invalid unstakeID

        vm.startPrank(alice);

        vm.expectRevert("Only PENDING unstakes can be claimed");
        staking.recoverSALT(invalidUnstakeID);
        }


	// A unit test to check if the contract reverts when trying to cancel an already completed unstake.
	function testCancelCompletedUnstakeRevert() public {
        // User Alice unstakes
        uint256 amountToStake = 10 ether;
        uint256 numWeeks = 6;

        vm.startPrank(alice);
        staking.stakeSALT(amountToStake);
        uint256 unstakeID = staking.unstake(amountToStake, numWeeks);

        // Increase block time to complete unstake
        uint256 secondsIntoTheFuture = numWeeks * 1 weeks;
        vm.warp(block.timestamp + secondsIntoTheFuture);

        // User Alice tries to cancel the completed unstake
        vm.expectRevert("Unstakes that have already completed cannot be cancelled");
        staking.cancelUnstake(unstakeID);
    }


	// A unit test to check if the contract reverts when trying to recover SALT from a non-PENDING unstake.
	function testRecoverSALTFromNonPendingUnstake() public {
        uint256 amountToStake = 10 ether;
        uint256 numWeeks = 10;

        // Alice stakes some SALT
        vm.startPrank(alice);
        staking.stakeSALT(amountToStake);

        // Alice unstakes the xSALT
        uint256 unstakeID = staking.unstake(amountToStake, numWeeks);

        // Wait for a few seconds
        vm.warp(block.timestamp + 1);

        // Alice cancels the unstake
        staking.cancelUnstake(unstakeID);

        // Now Alice tries to recover the SALT from the cancelled unstake
        vm.expectRevert("Only PENDING unstakes can be claimed");
        staking.recoverSALT(unstakeID);
    }


	// A unit test to check if the contract reverts when trying to remove more votes than the current user share.
	function testRemoveMoreVotesThanCurrentShare() public {
        // Preparations
        vm.startPrank(alice);
        staking.stakeSALT(50 ether);
        staking.depositVotes(poolIDs[1], 30 ether);

        // Trying to remove more votes than available
        vm.expectRevert("Cannot decrease more than existing user share");
        staking.removeVotesAndClaim(poolIDs[1], 60 ether);
    }


	// A unit test to check if the contract reverts when trying to recover SALT from an unstake that does not belong to the sender.
	function testRecoverSALTFromUnstakeNotBelongingToSender() public {

		uint256 aliceStartingBalance = salt.balanceOf(alice);

        // Alice stakes some SALT
        vm.startPrank(alice);
        staking.stakeSALT(10 ether);

        // Alice unstakes
        uint256 unstakeID = staking.unstake(5 ether, 26);
        vm.stopPrank();

        // Bob tries to recover SALT from Alice's unstake
        vm.startPrank(bob);
        vm.expectRevert("Unstake has not completed yet");
        staking.recoverSALT(unstakeID);

        // Warp into the future to complete unstaking duration
        vm.warp(block.timestamp + 26 weeks);

        // Bob tries to recover SALT again from Alice's unstake after it completed
        vm.expectRevert("Not the original staker");
        staking.recoverSALT(unstakeID);
		vm.stopPrank();

        // Alice should still be able to recover her SALT
        vm.prank(alice);
        staking.recoverSALT(unstakeID);

        // Verify that Alice's SALT balance increased
        assertEq(salt.balanceOf(alice), aliceStartingBalance - 5 ether);
        }
	}
