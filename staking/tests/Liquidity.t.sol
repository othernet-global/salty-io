//// SPDX-License-Identifier: BSL 1.1
//pragma solidity ^0.8.12;
//
//import "forge-std/Test.sol";
//import "../../Deployment.sol";
//import "../../root_tests/TestERC20.sol";
//
//
//contract LiquidityTest is Test, Deployment
//	{
//    bytes32[] public _pools;
//    bytes32 public pool1;
//    bytes32 public pool2;
//
//    address public constant alice = address(0x1111);
//    address public constant bob = address(0x2222);
//    address public constant charlie = address(0x3333);
//
//    address public dao = address(0xDA0);
//
//
//    function setUp() public
//    	{
//        // Deploy mock pool (LP) which mints total supply to this contract
//        pool1 = bytes32(uint256(0x123));
//        pool2 = bytes32(uint256(0x456));
//
//		// Pools for testing
//        _pools = new bytes32[](2);
//        _pools[0] = pool1;
//        _pools[1] = pool2;
//
//        // Whitelist the pools
//        vm.startPrank( DEPLOYER );
//        poolsConfig.whitelistPool(pool1);
//        poolsConfig.whitelistPool(pool2);
//
//        salt.transfer(address(this), 100000 ether);
//
//        vm.stopPrank();
//
//        salt.approve(address(liquidity), type(uint256).max);
//        pool1.approve(address(liquidity), type(uint256).max);
//        pool2.approve(address(liquidity), type(uint256).max);
//
//        // Alice gets some salt and pool lps and approves max to staking
//        pool1.transfer(alice, 1000 ether);
//        pool2.transfer(alice, 1000 ether);
//        vm.startPrank(alice);
//        pool1.approve(address(liquidity), type(uint256).max);
//        pool2.approve(address(liquidity), type(uint256).max);
//		vm.stopPrank();
//
//        // Bob gets some salt and pool lps and approves max to staking
//        pool1.transfer(bob, 1000 ether);
//        pool2.transfer(bob, 1000 ether);
//        vm.startPrank(bob);
//        pool1.approve(address(liquidity), type(uint256).max);
//        pool2.approve(address(liquidity), type(uint256).max);
//		vm.stopPrank();
//
//
//        // Charlie gets some salt and pool lps and approves max to staking
//        pool1.transfer(charlie, 1000 ether);
//        pool2.transfer(charlie, 1000 ether);
//        vm.startPrank(charlie);
//        pool1.approve(address(liquidity), type(uint256).max);
//        pool2.approve(address(liquidity), type(uint256).max);
//		vm.stopPrank();
//
//
//        // DAO gets some salt and pool lps and approves max to staking
//        pool1.transfer(address(dao), 1000 ether);
//        pool2.transfer(address(dao), 1000 ether);
//        vm.startPrank(address(dao));
//        pool1.approve(address(liquidity), type(uint256).max);
//        pool2.approve(address(liquidity), type(uint256).max);
//		vm.stopPrank();
//    	}
//
//
////	function totalStakedForPool( bytes32 poolID ) public view returns (uint256)
////		{
////		bytes32[] memory _pools = new bytes32[](1);
////		_pools[0] = poolID;
////
////		return liquidity.totalSharesForPools(_pools)[0];
////		}
////
////
////	// A unit test where a user stakes a valid amount of LP tokens in a Uniswap pool. Check that the user's share of the pool increases appropriately.
////	function testStakeLP() public {
////		uint256 amountStaked = 10 ether;
////
////		// Check initial balances
////		assertEq(liquidity.userShareInfoForPool(alice, pools[1]).userShare, 0, "Initial staked balance should be zero");
////		assertEq(pools[1].balanceOf(address(liquidity)), 0, "Contract should initially have zero balance" );
////
////		// Stake LP tokens
////		vm.prank(alice);
////		liquidity.stake(pools[1], amountStaked);
////
////		// Check that the user's share of the pool has increased appropriately
////		assertEq(liquidity.userShareInfoForPool(alice, pools[1]).userShare, amountStaked, "Alice's share did not increase as expected" );
////
////		// Check that the total staked for the pool has increased appropriately
////		assertEq(totalStakedForPool(pools[1]), amountStaked, "Total pool stake did not increase as expected" );
////
////		// Check that the contract balance has increased as well
////		assertEq(pools[1].balanceOf(address(liquidity)), amountStaked, "Contract should have an increased balance" );
////	}
////
////
////	// A unit test where a user attempts to stake LP tokens in an invalid pool (pool 0). The function should reject this operation and not modify the user's share of the pool.
////	function testInvalidPoolStake() public {
////		// Alice tries to stake LP tokens in pool 0
////		uint256 amountToStake = 1 ether;
////
////		vm.prank(alice);
////		vm.expectRevert("Cannot stake on the STAKED_SALT pool");
////		liquidity.stake(STAKED_SALT, amountToStake);
////
////		// Check that Alice's share of pool 0 has not changed
////		assertEq(liquidity.userShareInfoForPool(alice, pools[0]).userShare, 0, "Alice's share should not have changed" );
////	}
////
////
////	// A unit test where a user unstakes a valid amount of LP tokens from a Uniswap pool. Check that the user's share of the pool decreases appropriately and the tokens are transferred back.
////	function testValidUnstakeAndClaim() public {
////		// Alice stakes 50 LP in pool 1
////		vm.startPrank(alice);
////		liquidity.stake(pool2, 50 ether);
////
////		vm.warp( block.timestamp + 1 days ); // overcome cooldown
////
////		// Get initial balances and shares
////		uint256 initialAliceLPBalance = pool2.balanceOf(alice);
////		uint256 initialAliceShare = liquidity.userShareInfoForPool(alice, pool2).userShare;
////		uint256 initialContractLPBalance = pool2.balanceOf(address(liquidity));
////
////		// Alice unstakes 10 LP
////		liquidity.unstakeAndClaim(pool2, 10 ether);
////
////		// Check that Alice's LP balance has increased by 10
////		assertEq(pool2.balanceOf(alice), initialAliceLPBalance + 10 ether, "Alice's LP balance should have increased" );
////
////		// Check that Alice's share has decreased
////		assertEq(liquidity.userShareInfoForPool(alice, pool2).userShare, initialAliceShare - 10 ether, "Alice's share should have decreased" );
////
////		// Check that the contract's LP balance has decreased by 10
////		assertEq(pool2.balanceOf(address(liquidity)), initialContractLPBalance - 10 ether, "Contract balance should have decreased" );
////	}
////
////
////	// A unit test where the DAO attempts to unstake LP tokens from a Uniswap pool. The function should reject this operation and not modify the user's share of the pool.
////	function testDAOUnstakeLP() public {
////		// DAO attempts to stake LP tokens
////		vm.startPrank(address(dao));
////		uint256 initialBalance = liquidity.userShareInfoForPool(address(dao), pools[1]).userShare;
////		uint256 amountStaked = 10 ether;
////		liquidity.stake(pools[1], amountStaked);
////		uint256 finalBalance = liquidity.userShareInfoForPool(address(dao), pools[1]).userShare;
////		assertEq(finalBalance, initialBalance + amountStaked, "DAO should be able to stake LP tokens");
////
////		// DAO attempts to unstake LP tokens
////		initialBalance = liquidity.userShareInfoForPool(address(dao), pools[1]).userShare;
////		uint256 amountUnstaked = 5 ether;
////		vm.expectRevert("DAO is not allowed to unstake LP tokens" );
////		liquidity.unstakeAndClaim(pools[1], amountUnstaked);
////		finalBalance = liquidity.userShareInfoForPool(address(dao), pools[1]).userShare;
////		assertEq(finalBalance, initialBalance, "DAO's share should not change after failed unstake attempt");
////		vm.stopPrank();
////	}
////
////
////	// A unit test where a user attempts to unstake more LP tokens than they have staked. The function should reject this operation and not modify the user's share of the pool.
////	function testUnstakeMoreThanStaked() public {
////		// User stakes LP tokens
////		vm.startPrank(alice);
////		uint256 initialBalance = liquidity.userShareInfoForPool(alice, pools[1]).userShare;
////		uint256 amountStaked = 10 ether;
////		liquidity.stake(pools[1], amountStaked);
////		uint256 finalBalance = liquidity.userShareInfoForPool(alice, pools[1]).userShare;
////		assertEq(finalBalance, initialBalance + amountStaked, "User should be able to stake LP tokens");
////
////		// User attempts to unstake more LP tokens than staked
////		initialBalance = liquidity.userShareInfoForPool(alice, pools[1]).userShare;
////		uint256 amountUnstaked = 15 ether; // more than staked
////		vm.expectRevert("Cannot decrease more than existing user share" );
////		liquidity.unstakeAndClaim(pools[1], amountUnstaked);
////		finalBalance = liquidity.userShareInfoForPool(alice, pools[1]).userShare;
////		assertEq(finalBalance, initialBalance, "User's share should not change after failed unstake attempt");
////	}
////
////
////	function check( uint256 shareA, uint256 shareB, uint256 shareC, uint256 rA, uint256 rB, uint256 rC, uint256 vA, uint256 vB, uint256 vC, uint256 sA, uint256 sB, uint256 sC ) public
////		{
////		assertEq( liquidity.userShareInfoForPool(alice, pool2).userShare, shareA, "Share A incorrect" );
////		assertEq( liquidity.userShareInfoForPool(bob, pool2).userShare, shareB, "Share B incorrect" );
////		assertEq( liquidity.userShareInfoForPool(charlie, pool2).userShare, shareC, "Share C incorrect" );
////
////		assertEq( liquidity.userPendingReward( alice, pool2 ), rA, "Incorrect pending rewards A" );
////        assertEq( liquidity.userPendingReward( bob, pool2 ), rB, "Incorrect pending rewards B" );
////        assertEq( liquidity.userPendingReward( charlie, pool2 ), rC, "Incorrect pending rewards C" );
////
////		assertEq( liquidity.userShareInfoForPool(alice, pool2).virtualRewards, vA, "Virtual A incorrect" );
////		assertEq( liquidity.userShareInfoForPool(bob, pool2).virtualRewards, vB, "Virtual B incorrect" );
////		assertEq( liquidity.userShareInfoForPool(charlie, pool2).virtualRewards, vC, "Virtual C incorrect" );
////
////		assertEq( salt.balanceOf(alice), sA, "SALT A incorrect" );
////		assertEq( salt.balanceOf(bob), sB, "SALT B incorrect" );
////		assertEq( salt.balanceOf(charlie), sC, "SALT C incorrect" );
////		}
////
////
////    // Test staking and claiming with multiple users, with Alice, Bob and Charlie each stacking, claiming and unstaking, with rewards being interleaved between each user action.  addSALTRewards should be used to add the rewards with some amount of rewards (between 10 and 100 SALT) being added after each user interaction.
////	function testMultipleUserStakingClaiming() public {
////
////		uint256 startingSaltA = salt.balanceOf(alice);
////		uint256 startingSaltB = salt.balanceOf(bob);
////        uint256 startingSaltC = salt.balanceOf(charlie);
////
////		assertEq( startingSaltA, 0, "Starting SALT A not zero" );
////		assertEq( startingSaltB, 0, "Starting SALT B not zero" );
////        assertEq( startingSaltC, 0, "Starting SALT C not zero" );
////
////        // Alice stakes 50
////        vm.prank(alice);
////        liquidity.stake(pool2, 50 ether);
////		check( 50 ether, 0 ether, 0 ether, 0 ether, 0 ether, 0 ether, 0 ether, 0 ether, 0 ether, 0 ether, 0 ether, 0 ether );
////        AddedReward[] memory rewards = new AddedReward[](1);
////        rewards[0] = AddedReward(pool2, 50 ether);
////        liquidity.addSALTRewards(rewards);
////        vm.warp( block.timestamp + 1 hours );
////		check( 50 ether, 0 ether, 0 ether, 50 ether, 0 ether, 0 ether, 0 ether, 0 ether, 0 ether, 0 ether, 0 ether, 0 ether );
////
////        // Bob stakes 10
////        vm.prank(bob);
////        liquidity.stake(pool2, 10 ether);
////		check( 50 ether, 10 ether, 0 ether, 50 ether, 0 ether, 0 ether, 0 ether, 10 ether, 0 ether, 0 ether, 0 ether, 0 ether );
////        rewards[0] = AddedReward(pool2, 30 ether);
////        liquidity.addSALTRewards(rewards);
////        vm.warp( block.timestamp + 1 hours );
////		check( 50 ether, 10 ether, 0 ether, 75 ether, 5 ether, 0 ether, 0 ether, 10 ether, 0 ether, 0 ether, 0 ether, 0 ether );
////
////		// Alice claims
////        vm.prank(alice);
////        liquidity.claimAllRewards(pools);
////		check( 50 ether, 10 ether, 0 ether, 0 ether, 5 ether, 0 ether, 75 ether, 10 ether, 0 ether, 75 ether, 0 ether, 0 ether );
////        rewards[0] = AddedReward(pool2, 30 ether);
////        liquidity.addSALTRewards(rewards);
////        vm.warp( block.timestamp + 1 hours );
////		check( 50 ether, 10 ether, 0 ether, 25 ether, 10 ether, 0 ether, 75 ether, 10 ether, 0 ether, 75 ether, 0 ether, 0 ether );
////
////        // Charlie stakes 40
////        vm.prank(charlie);
////        liquidity.stake(pool2, 40 ether);
////		check( 50 ether, 10 ether, 40 ether, 25 ether, 10 ether, 0 ether, 75 ether, 10 ether, 80 ether, 75 ether, 0 ether, 0 ether );
////        rewards[0] = AddedReward(pool2, 100 ether);
////        liquidity.addSALTRewards(rewards);
////        vm.warp( block.timestamp + 1 hours );
////		check( 50 ether, 10 ether, 40 ether, 75 ether, 20 ether, 40 ether, 75 ether, 10 ether, 80 ether, 75 ether, 0 ether, 0 ether );
////
////		// Alice unstakes 10
////        vm.prank(alice);
////        liquidity.unstakeAndClaim(pool2, 10 ether);
////		check( 40 ether, 10 ether, 40 ether, 60 ether, 20 ether, 40 ether, 60 ether, 10 ether, 80 ether, 90 ether, 0 ether, 0 ether );
////        rewards[0] = AddedReward(pool2, 90 ether);
////        liquidity.addSALTRewards(rewards);
////        vm.warp( block.timestamp + 1 hours );
////		check( 40 ether, 10 ether, 40 ether, 100 ether, 30 ether, 80 ether, 60 ether, 10 ether, 80 ether, 90 ether, 0 ether, 0 ether );
////
////		// Bob claims
////        vm.prank(bob);
////        liquidity.claimAllRewards(pools);
////		check( 40 ether, 10 ether, 40 ether, 100 ether, 0 ether, 80 ether, 60 ether, 40 ether, 80 ether, 90 ether, 30 ether, 0 ether );
////        rewards[0] = AddedReward(pool2, 90 ether);
////        liquidity.addSALTRewards(rewards);
////        vm.warp( block.timestamp + 1 hours );
////		check( 40 ether, 10 ether, 40 ether, 140 ether, 10 ether, 120 ether, 60 ether, 40 ether, 80 ether, 90 ether, 30 ether, 0 ether );
////
////		// Charlie claims
////        vm.prank(charlie);
////        liquidity.claimAllRewards(pools);
////		check( 40 ether, 10 ether, 40 ether, 140 ether, 10 ether, 0 ether, 60 ether, 40 ether, 200 ether, 90 ether, 30 ether, 120 ether );
////        rewards[0] = AddedReward(pool2, 180 ether);
////        liquidity.addSALTRewards(rewards);
////        vm.warp( block.timestamp + 1 hours );
////		check( 40 ether, 10 ether, 40 ether, 220 ether, 30 ether, 80 ether, 60 ether, 40 ether, 200 ether, 90 ether, 30 ether, 120 ether );
////
////		// Alice adds 100
////        vm.prank(alice);
////        liquidity.stake(pool2, 100 ether);
////		check( 140 ether, 10 ether, 40 ether, 220 ether, 30 ether, 80 ether, 760 ether, 40 ether, 200 ether, 90 ether, 30 ether, 120 ether );
////        rewards[0] = AddedReward(pool2, 190 ether);
////        liquidity.addSALTRewards(rewards);
////        vm.warp( block.timestamp + 1 hours );
////		check( 140 ether, 10 ether, 40 ether, 360 ether, 40 ether, 120 ether, 760 ether, 40 ether, 200 ether, 90 ether, 30 ether, 120 ether );
////
////		// Charlie unstakes all
////        vm.prank(charlie);
////        liquidity.unstakeAndClaim( pool2, 40 ether);
////		check( 140 ether, 10 ether, 0 ether, 360 ether, 40 ether, 0 ether, 760 ether, 40 ether, 0 ether, 90 ether, 30 ether, 240 ether );
////        rewards[0] = AddedReward(pool2, 75 ether);
////        liquidity.addSALTRewards(rewards);
////        vm.warp( block.timestamp + 1 hours );
////		check( 140 ether, 10 ether, 0 ether, 430 ether, 45 ether, 0 ether, 760 ether, 40 ether, 0 ether, 90 ether, 30 ether, 240 ether );
////
////		// Bob unstakes 5
////        vm.prank(bob);
////        liquidity.unstakeAndClaim( pool2, 2 ether);
////		check( 140 ether, 8 ether, 0 ether, 430 ether, 36 ether, 0 ether, 760 ether, 32 ether, 0 ether, 90 ether, 39 ether, 240 ether );
////        rewards[0] = AddedReward(pool2, 74 ether);
////        liquidity.addSALTRewards(rewards);
////        vm.warp( block.timestamp + 1 hours );
////		check( 140 ether, 8 ether, 0 ether, 500 ether, 40 ether, 0 ether, 760 ether, 32 ether, 0 ether, 90 ether, 39 ether, 240 ether );
////
////		// Bob adds 148
////        vm.prank(bob);
////        liquidity.stake(pool2, 148 ether);
////		check( 140 ether, 156 ether, 0 ether, 500 ether, 40 ether, 0 ether, 760 ether, 1364 ether, 0 ether, 90 ether, 39 ether, 240 ether );
////        rewards[0] = AddedReward(pool2, 592 ether);
////        liquidity.addSALTRewards(rewards);
////        vm.warp( block.timestamp + 1 hours );
////		check( 140 ether, 156 ether, 0 ether, 780 ether, 352 ether, 0 ether, 760 ether, 1364 ether, 0 ether, 90 ether, 39 ether, 240 ether );
////    }
////
////
////	// A unit test where a user tries to unstake LP tokens after the cooldown period has not yet expired. This test ensures that the contract rejects the unstake and does not modify the user's share of the pool.
////	function testUnstakeBeforeCooldown() public {
////        // Alice stakes 100 ether of LP tokens
////        vm.startPrank(alice);
////        liquidity.stake(pool1, 100 ether);
////        vm.stopPrank();
////
////        // Confirm the total staked amount for Alice
////        assertEq(liquidity.userShareInfoForPool(alice,pool1).userShare, 100 ether);
////
////        // Alice tries to unstake LP tokens before cooldown period is over
////        vm.startPrank(alice);
////        vm.expectRevert("Must wait for the cooldown to expire" );
////        liquidity.unstakeAndClaim(pool1, 50 ether);
////        vm.stopPrank();
////
////        // Confirm the total staked amount for Alice is still the same
////        assertEq(liquidity.userShareInfoForPool(alice,pool1).userShare, 100 ether);
////    }
//
//	}
