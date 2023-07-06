//// SPDX-License-Identifier: BSL 1.1
//pragma solidity ^0.8.12;
//
//import "forge-std/Test.sol";
//import "../../Deployment.sol";
//import "../../root_tests/TestERC20.sol";
//
//
//contract TestRewardsEmitter is Test, Deployment
//	{
//    IUniswapV2Pair[] public pools;
//    IUniswapV2Pair public lp;
//    IUniswapV2Pair public lp2;
//
//    address public constant alice = address(0x1111);
//    address public constant bob = address(0x2222);
//    address public constant charlie = address(0x3333);
//
//
//    function setUp() public
//    	{
//        // Deploy mock pool (LP) which mints total supply to this contract
//        lp = IUniswapV2Pair(address(new TestERC20( 18 )));
//        lp2 = IUniswapV2Pair(address(new TestERC20( 18 )));
//
//		// Pools for testing
//        pools = new IUniswapV2Pair[](2);
//        pools[0] = lp;
//        pools[1] = lp2;
//
//        // Whitelist lp
//        vm.startPrank(DEPLOYER);
//        stakingConfig.whitelist(lp);
//        stakingConfig.whitelist(lp2);
//        salt.transfer(address(this), 100000 ether);
//        salt.approve(address(liquidityRewardsEmitter), type(uint256).max);
//        vm.stopPrank();
//
//        // This contract approves max to staking so that SALT rewards can be added
//        salt.approve(address(liquidityRewardsEmitter), type(uint256).max);
//
//        // Alice gets some salt and pool lps and approves max to staking
//        lp.transfer(alice, 1000 ether);
//        lp2.transfer(alice, 1000 ether);
//        salt.transfer(alice, 1000 ether);
//
//        vm.startPrank(alice);
//        salt.approve(address(liquidityRewardsEmitter), type(uint256).max);
//        lp.approve(address(liquidityRewardsEmitter), type(uint256).max);
//        lp2.approve(address(liquidityRewardsEmitter), type(uint256).max);
//        lp.approve(address(liquidity), type(uint256).max);
//        lp2.approve(address(liquidity), type(uint256).max);
//		vm.stopPrank();
//
//        // Bob gets some salt and pool lps and approves max to staking
//        lp.transfer(bob, 1000 ether);
//        lp2.transfer(bob, 1000 ether);
//        salt.transfer(bob, 1000 ether);
//        vm.startPrank(bob);
//
//        salt.approve(address(liquidityRewardsEmitter), type(uint256).max);
//        lp.approve(address(liquidityRewardsEmitter), type(uint256).max);
//        lp2.approve(address(liquidityRewardsEmitter), type(uint256).max);
//        lp.approve(address(liquidity), type(uint256).max);
//        lp2.approve(address(liquidity), type(uint256).max);
//		vm.stopPrank();
//
//
//        // Charlie gets some salt and pool lps and approves max to staking
//        lp.transfer(charlie, 1000 ether);
//        lp2.transfer(charlie, 1000 ether);
//        salt.transfer(charlie, 1000 ether);
//        vm.startPrank(charlie);
//
//        salt.approve(address(liquidityRewardsEmitter), type(uint256).max);
//        lp.approve(address(liquidityRewardsEmitter), type(uint256).max);
//        lp2.approve(address(liquidityRewardsEmitter), type(uint256).max);
//        lp.approve(address(liquidity), type(uint256).max);
//        lp2.approve(address(liquidity), type(uint256).max);
//		vm.stopPrank();
//
//		// Increase rewardsEmitterDailyPercent to 2.5% for testing
//		vm.startPrank(DEPLOYER);
//		for ( uint256 i = 0; i < 6; i++ )
//			rewardsConfig.changeRewardsEmitterDailyPercent(true);
//		vm.stopPrank();
//    	}
//
//
//	function pendingLiquidityRewardsForPool( IUniswapV2Pair pool ) public returns (uint256)
//		{
//		IUniswapV2Pair[] memory pools = new IUniswapV2Pair[](1);
//		pools[0] = pool;
//
//		return liquidityRewardsEmitter.pendingRewardsForPools( pools )[0];
//		}
//
//
//
//	// A unit test in which multiple users try to add SALT rewards to multiple valid pools. Test that the total amount of SALT transferred from the senders to the contract is correct and that pending rewards for each pool is correctly incremented.
//	function testAddSALTRewards() public {
//        // Define rewards to be added
//        AddedReward[] memory addedRewards = new AddedReward[](4);
//        addedRewards[0] = AddedReward({pool: pools[0], amountToAdd: 50 ether});
//        addedRewards[1] = AddedReward({pool: pools[0], amountToAdd: 50 ether});
//        addedRewards[2] = AddedReward({pool: pools[1], amountToAdd: 25 ether});
//        addedRewards[3] = AddedReward({pool: pools[1], amountToAdd: 75 ether});
//
//		uint256 startingA = salt.balanceOf(alice);
//		uint256 startingB = salt.balanceOf(bob);
//		uint256 startingC = salt.balanceOf(charlie);
//
//        // Record initial contract balance
//        uint256 initialContractBalance = salt.balanceOf(address(liquidityRewardsEmitter));
//
//        // Alice, Bob and Charlie each add rewards
//        vm.prank(alice);
//        liquidityRewardsEmitter.addSALTRewards(addedRewards);
//
//        vm.prank(bob);
//        liquidityRewardsEmitter.addSALTRewards(addedRewards);
//
//        vm.prank(charlie);
//        liquidityRewardsEmitter.addSALTRewards(addedRewards);
//
//        // Verify contract balance increased by total added rewards
//        uint256 finalContractBalance = salt.balanceOf(address(liquidityRewardsEmitter));
//        assertEq(finalContractBalance, initialContractBalance + 600 ether);
//
//        // Verify pending rewards for each pool is correctly incremented
//        uint256[] memory poolsPendingRewards = liquidityRewardsEmitter.pendingRewardsForPools(pools);
//        assertEq(poolsPendingRewards[0], 300 ether);
//        assertEq(poolsPendingRewards[1], 300 ether);
//
//        assertEq( startingA - salt.balanceOf(alice), 200 ether );
//		assertEq( startingB - salt.balanceOf(bob), 200 ether );
//		assertEq( startingC - salt.balanceOf(charlie), 200 ether );
//    }
//
//
//	// A unit test in which a user tries to add SALT rewards but does not have enough SALT in their account. Test that the transaction reverts as expected.
//	function testAddSALTRewardsWithInsufficientSALT() public {
//	AddedReward[] memory addedRewards = new AddedReward[](1);
//	addedRewards[0] = AddedReward({pool: lp, amountToAdd: 5000 ether});
//
//    vm.expectRevert("ERC20: transfer amount exceeds balance");
//	vm.prank(alice);
//	liquidityRewardsEmitter.addSALTRewards(addedRewards);
//    }
//
//
//	// A unit test in which a user tries to add SALT rewards to an invalid pool. Test that the transaction reverts as expected.
//	function testAddSALTRewardsToInvalidPool() public {
//        // Invalid pool
//        IUniswapV2Pair invalidPool = IUniswapV2Pair(address(0xDEAD));
//
//        // Define reward to be added
//        AddedReward[] memory addedRewards = new AddedReward[](1);
//        addedRewards[0] = AddedReward(invalidPool, 10 ether);
//
//        // Try to add SALT reward to invalid pool, expect a revert
//        vm.expectRevert("Invalid pool");
//        liquidityRewardsEmitter.addSALTRewards(addedRewards);
//    }
//
//
//	// A unit test where pending rewards are added to multiple pools, then performUpkeep is called. Test that the correct amount of rewards are deducted from each pool's pending rewards.
//	function testPerformUpkeepWithMultiplePools() public {
//        // Add some pending rewards to the pools
//        AddedReward[] memory addedRewards = new AddedReward[](2);
//        addedRewards[0] = AddedReward({pool: pools[0], amountToAdd: 10 ether});
//        addedRewards[1] = AddedReward({pool: pools[1], amountToAdd: 10 ether});
//        liquidityRewardsEmitter.addSALTRewards(addedRewards);
//
//        // Verify that the rewards were added
//        assertEq(pendingLiquidityRewardsForPool(pools[0]), 10 ether);
//        assertEq(pendingLiquidityRewardsForPool(pools[1]), 10 ether);
//
//        // Warp time forward one day
//        vm.warp(block.timestamp + 1 days);
//
//        // Call performUpkeep
//        liquidityRewardsEmitter.performUpkeep();
//
//        // Verify that the correct amount of rewards were deducted from each pool's pending rewards
//        // By default, 5% of the rewards should be deducted per day
//        assertEq(pendingLiquidityRewardsForPool(pools[0]), 9.75 ether); // 10 ether - 2.5%
//        assertEq(pendingLiquidityRewardsForPool(pools[1]), 9.75 ether); // 10 ether - 2.5%
//
//        // Rewards transferred to the liquidity contract
//        assertEq(salt.balanceOf(address(liquidity)), .50 ether);
//    }
//
//
//	// A unit test where the performUpkeep function is called for multiple pools. Test that the correct amount of rewards is transferred for each pool.
//	function testPerformUpkeep() public {
//        // Alice, Bob, and Charlie deposit their LP tokens into pool[1]
//        vm.prank(alice);
//        liquidity.stake(pools[1], 100 ether);
//
//        vm.prank(bob);
//        liquidity.stake(pools[1], 100 ether);
//
//        vm.prank(charlie);
//        liquidity.stake(pools[1], 100 ether);
//
//        // Adding rewards to the pools
//        AddedReward[] memory addedRewards = new AddedReward[](2);
//        addedRewards[0] = AddedReward({pool: pools[0], amountToAdd: 100 ether});
//        addedRewards[1] = AddedReward({pool: pools[1], amountToAdd: 100 ether});
//        liquidityRewardsEmitter.addSALTRewards(addedRewards);
//
//        // Before upkeep, rewards should be 100 ether for each pool
//        assertEq(pendingLiquidityRewardsForPool(pools[0]), 100 ether);
//        assertEq(pendingLiquidityRewardsForPool(pools[1]), 100 ether);
//
//        // Perform upkeep after 1 day for pools[0] and pools[1]
//        vm.warp(block.timestamp + 1 days);
//        liquidityRewardsEmitter.performUpkeep();
//
//        // After upkeep, rewards should be reduced by 2.5% (increased from default) for each pool
//        assertEq(pendingLiquidityRewardsForPool(pools[0]), 97.5 ether );
//        assertEq(pendingLiquidityRewardsForPool(pools[1]), 97.5 ether );
//
//		// Make sure the correct amount of rewards have been added to the pools
//		assertEq( liquidity.totalRewardsForPools(pools)[0], 2.5 ether, "Incorrect total rewards in pool[0]" );
//		assertEq( liquidity.totalRewardsForPools(pools)[1], 2.5 ether, "Incorrect total rewards in pool[1]" );
//
//        // Check if the correct amount of rewards was transferred to each user
//        assertEq(liquidity.userPendingReward(alice, pools[1]), 0.833333333333333333 ether); // 2.5% of 100 ether divided by 3 users
//        assertEq(liquidity.userPendingReward(bob, pools[1]), 0.833333333333333333 ether);
//        assertEq(liquidity.userPendingReward(charlie, pools[1]), 0.833333333333333333 ether);
//    }
//
//
//	// A unit test where the pendingRewardsForPools function is called for multiple pools. Test that it correctly returns the amount of pending rewards for each pool.
//	function testPendingRewardsForPools() public {
//        // Alice stakes in both pools
//        vm.startPrank(alice);
//        liquidity.stake(lp, 50 ether);
//        liquidity.stake(lp2, 50 ether);
//        vm.stopPrank();
//
//        // Bob stakes in both pools
//        vm.startPrank(bob);
//        liquidity.stake(lp, 30 ether);
//        liquidity.stake(lp2, 70 ether);
//        vm.stopPrank();
//
//        // Charlie stakes in both pools
//        vm.startPrank(charlie);
//        liquidity.stake(lp, 20 ether);
//        liquidity.stake(lp2, 80 ether);
//        vm.stopPrank();
//
//        // Advance the time by 1 day
//        vm.warp(block.timestamp + 1 days);
//
//        // Add rewards to the pools
//        AddedReward[] memory addedRewards = new AddedReward[](2);
//        addedRewards[0] = AddedReward({pool: lp, amountToAdd: 10 ether});
//        addedRewards[1] = AddedReward({pool: lp2, amountToAdd: 20 ether});
//        liquidityRewardsEmitter.addSALTRewards(addedRewards);
//
//        // Check pending rewards
//        uint256[] memory rewards = liquidityRewardsEmitter.pendingRewardsForPools(pools);
//
//        assertEq(rewards[0], 10 ether, "Incorrect pending rewards for pool 1");
//        assertEq(rewards[1], 20 ether, "Incorrect pending rewards for pool 2");
//    }
//
//
//	// A unit test that attempts to add SALT rewards to a pool when the contract does not have approval to transfer SALT. Test that the transaction reverts as expected.
//	function testAddSALTRewardsWithoutApproval() public {
//        salt.approve(address(liquidityRewardsEmitter), 0); // Removing approval for SALT transfer
//
//        AddedReward[] memory addedRewards = new AddedReward[](1);
//        addedRewards[0] = AddedReward(pools[0], 10 ether);
//
//        vm.expectRevert("Insufficient allowance to add rewards");
//        liquidityRewardsEmitter.addSALTRewards(addedRewards);
//    }
//
//
//	// A stress test in which a high volume of SALT rewards is added and distributed across multiple pools. Test that the contract can handle the high volume of transactions and that the balances and distributions remain accurate.
//	function testHighVolumeStress() public {
//        // Array to store added rewards
//        AddedReward[] memory addedRewards = new AddedReward[](2);
//        addedRewards[0] = AddedReward(pools[0], 100000 ether);
//        addedRewards[1] = AddedReward(pools[1], 100000 ether);
//
//		vm.prank(DEPLOYER);
//        liquidityRewardsEmitter.addSALTRewards(addedRewards);
//
//        // Verify that the pending rewards for each pool match the added amounts
//        uint256[] memory pendingRewards = liquidityRewardsEmitter.pendingRewardsForPools(pools);
//        assertEq(pendingRewards[0], 100000 ether);
//        assertEq(pendingRewards[1], 100000 ether);
//
//        // Increase block timestamp by one day
//        vm.warp(block.timestamp + 1 days);
//
//        // Perform upkeep on the pools
//        liquidityRewardsEmitter.performUpkeep();
//
//        // Verify that 5% of the rewards have been distributed (default daily distribution rate)
//        pendingRewards = liquidityRewardsEmitter.pendingRewardsForPools(pools);
//        assertEq(pendingRewards[0], 97500 ether);  // 100000 ether - 2.5%
//        assertEq(pendingRewards[1], 97500 ether);  // 100000 ether - 2.5%
//    }
//
//
//	// A unit test where a user tries to perform upkeep without any rewards added. Test that the function performs as expected and does not revert.
//	function testPerformUpkeepNoRewards() public {
//        // Perform initial upkeep without any rewards added
//        vm.prank(alice);
//        liquidityRewardsEmitter.performUpkeep();
//
//        // Verify that no SALT rewards are distributed for both pools
//        uint256[] memory pendingRewards = liquidityRewardsEmitter.pendingRewardsForPools(pools);
//        assertEq( pendingRewards[0], 0);
//        assertEq( pendingRewards[1], 0);
//
//        // Warp time by 1 day
//        vm.warp(block.timestamp + 1 days);
//
//        // Perform upkeep again
//        vm.prank(alice);
//        liquidityRewardsEmitter.performUpkeep();
//
//        // Verify that no SALT rewards are distributed for both pools, even after 1 day
//        pendingRewards = liquidityRewardsEmitter.pendingRewardsForPools(pools);
//        assertEq( pendingRewards[0], 0);
//        assertEq( pendingRewards[1], 0);
//    }
//
//
//	// An edge case unit test where the amount to add for SALT rewards is 0. Test that the function behaves as expected and does not revert or misbehave.
//	function testAddZeroSALTRewards() public
//    {
//        // Alice tries to add 0 SALT rewards for pool[1]
//        AddedReward[] memory addedRewards = new AddedReward[](1);
//        addedRewards[0] = AddedReward({pool: pools[1], amountToAdd: 0 ether});
//        vm.prank(alice);
//        liquidityRewardsEmitter.addSALTRewards(addedRewards);
//
//        // Ensure that the function did not revert and that the pending rewards for pool[1] is still 0
//        assertEq(pendingLiquidityRewardsForPool(pools[1]), 0 ether);
//
//        // Perform upkeep
//        liquidityRewardsEmitter.performUpkeep();
//
//        // Ensure that the function did not revert and that the pending rewards for pool[1] is still 0
//        assertEq(pendingLiquidityRewardsForPool(pools[1]), 0 ether);
//
//        // Ensure that Alice's balance did not change
//        assertEq(salt.balanceOf(alice), 1000 ether);
//    }
//
//
//	// A test that emits rewards amounts with delay between performUpkeep calls of 1 hour, 12 hours, 24 hours, and 48 hours.
//	function testEmittingRewardsWithDifferentDelays() public {
//
//		 // Reset the performUpkeep() timer
//        liquidityRewardsEmitter.performUpkeep();
//
//        // Add some SALT rewards to the pool
//        AddedReward[] memory addedRewards = new AddedReward[](1);
//        addedRewards[0] = AddedReward(pools[1], 1000 ether);
//        liquidityRewardsEmitter.addSALTRewards(addedRewards);
//
//		uint256 denominatorMult = 100 days * 1000;
//
//        // Perform upkeep after 1 hour
//        vm.warp(block.timestamp + 1 hours);
//        liquidityRewardsEmitter.performUpkeep();
//
//        // Check rewards
//        uint256 pendingRewards = liquidityRewardsEmitter.pendingRewardsForPools(pools)[1];
//		uint256 numeratorMult = 1 hours * rewardsConfig.rewardsEmitterDailyPercentTimes1000();
//
//		uint256 expectedPendingRewards = 1000 ether  - ( 1000 ether * numeratorMult ) / denominatorMult;
//        assertEq(pendingRewards, expectedPendingRewards, "Incorrect pending rewards after 1 hour" );
//
//
//        // Perform upkeep after 12 more hours
//        vm.warp(block.timestamp + 12 hours);
//        liquidityRewardsEmitter.performUpkeep();
//
//        // Check rewards
//        pendingRewards = liquidityRewardsEmitter.pendingRewardsForPools(pools)[1];
//		numeratorMult = 12 hours * rewardsConfig.rewardsEmitterDailyPercentTimes1000();
//
//		expectedPendingRewards = expectedPendingRewards  - ( expectedPendingRewards * numeratorMult ) / denominatorMult;
//        assertEq(pendingRewards, expectedPendingRewards, "Incorrect pending rewards after 12 hours" );
//
//
//        // Perform upkeep after 24 more hours
//        vm.warp(block.timestamp + 24 hours);
//       liquidityRewardsEmitter.performUpkeep();
//
//        // Check rewards
//        pendingRewards = liquidityRewardsEmitter.pendingRewardsForPools(pools)[1];
//		numeratorMult = 24 hours * rewardsConfig.rewardsEmitterDailyPercentTimes1000();
//
//		expectedPendingRewards = expectedPendingRewards  - ( expectedPendingRewards * numeratorMult ) / denominatorMult;
//        assertEq(pendingRewards, expectedPendingRewards, "Incorrect pending rewards after 24 hours" );
//
//
//        // Perform upkeep after 48 more hours
//        vm.warp(block.timestamp + 48 hours);
//       liquidityRewardsEmitter.performUpkeep();
//
//        // Check rewards - will be capped at 24 hours of delay
//        pendingRewards = liquidityRewardsEmitter.pendingRewardsForPools(pools)[1];
//		numeratorMult = 24 hours * rewardsConfig.rewardsEmitterDailyPercentTimes1000();
//
//		expectedPendingRewards = expectedPendingRewards  - ( expectedPendingRewards * numeratorMult ) / denominatorMult;
//        assertEq(pendingRewards, expectedPendingRewards, "Incorrect pending rewards after 48 hours" );
//    }
//
//
//    // A unit test that verifies that the RewardsEmitter contract properly handles scenarios where the daily rewards percentage is changed.
//    function testChangeRewardsEmitterDailyPercent() public
//    {
//        // Lower the daily percent to 1%
//        vm.startPrank(DEPLOYER);
//        for( uint256 i = 0; i < 6; i++ )
//	        rewardsConfig.changeRewardsEmitterDailyPercent(false);
//        vm.stopPrank();
//
//
//		 // Reset the performUpkeep() timer
//        liquidityRewardsEmitter.performUpkeep();
//
//        // Add some SALT rewards to the pool
//        AddedReward[] memory addedRewards = new AddedReward[](1);
//        addedRewards[0] = AddedReward(lp, 1000 ether);
//        liquidityRewardsEmitter.addSALTRewards(addedRewards);
//
//        // Perform upkeep to distribute rewards
//        vm.warp( block.timestamp + 1 days );
//        liquidityRewardsEmitter.performUpkeep();
//
//		uint256 rewards0 = pendingLiquidityRewardsForPool(lp);
//
//        // Setup
//        uint256 oldDailyPercent = rewardsConfig.rewardsEmitterDailyPercentTimes1000();
//        uint256 prevReward = pendingLiquidityRewardsForPool(lp);
//
//        // Change daily rewards percent
//        vm.startPrank(DEPLOYER);
//        for( uint256 i = 0; i < 6; i++ )
//	        rewardsConfig.changeRewardsEmitterDailyPercent(true);
//        vm.stopPrank();
//
//        uint256 newDailyPercent = rewardsConfig.rewardsEmitterDailyPercentTimes1000();
//        assertTrue(newDailyPercent > oldDailyPercent, "New daily percent should be greater than old daily percent");
//
//        vm.warp( block.timestamp + 1 days );
//        liquidityRewardsEmitter.performUpkeep();
//		uint256 rewards1 = pendingLiquidityRewardsForPool(lp);
//
//		console.log( " (rewards0 - 1000 ether): ",  1000 ether - rewards0 );
//		console.log( " (rewards1 - rewards0): ",  rewards0 - rewards1 );
//
//		assertTrue( (rewards0 - rewards1) > (1000 ether - rewards0), "Distributed rewards should have increased" );
//
//    }
//
//
//
//	}
//
