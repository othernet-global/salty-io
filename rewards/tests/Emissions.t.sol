//// SPDX-License-Identifier: BSL 1.1
//pragma solidity ^0.8.12;
//
//import "forge-std/Test.sol";
//import "../../Deployment.sol";
//import "../../root_tests/TestERC20.sol";
//
//
//contract TestEmissions is Test, Deployment
//	{
//	address public alice = address(0x1111);
//	address public bob = address(0x2222);
//
//	IUniswapV2Pair public pool1 = IUniswapV2Pair(address( new TestERC20( 18 ) ));
//	IUniswapV2Pair public pool2 = IUniswapV2Pair(address( new TestERC20( 18 ) ));
//
//
//    function setUp() public
//    	{
//    	vm.startPrank( DEPLOYER );
//
//		// Whitelist pools
//		stakingConfig.whitelist(pool1);
//		stakingConfig.whitelist(pool2);
//
//		// Add SALT to the contract (for the emissions)
//		salt.transfer(address(this), 1000 ether);
//
//		// Send some SALT to alice and bob
//		salt.transfer(alice, 100 ether);
//		salt.transfer(bob, 100 ether);
//		vm.stopPrank();
//
//		vm.prank(alice);
//		salt.approve( address(staking), type(uint256).max );
//
//		vm.prank(bob);
//		salt.approve( address(staking), type(uint256).max );
//
//		// Increase emissionsWeeklyPercent to 1% weekly for testing (.50% default + 2x 0.25% increment)
//    	vm.startPrank( DEPLOYER );
//		rewardsConfig.changeEmissionsWeeklyPercent(true);
//        rewardsConfig.changeEmissionsWeeklyPercent(true);
//        vm.stopPrank();
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
//	function pendingStakingRewardsForPool( IUniswapV2Pair pool ) public returns (uint256)
//		{
//		IUniswapV2Pair[] memory pools = new IUniswapV2Pair[](1);
//		pools[0] = pool;
//
//		return stakingRewardsEmitter.pendingRewardsForPools( pools )[0];
//		}
//
//
//	// A unit test to ensure that the constructor correctly approves the maximum amount of SALT tokens for the stakingRewardsEmitter and liquidityRewardsEmitter.
//	function testConstructorApprovals() public {
//    assertEq(salt.allowance(address(emissions), address(stakingRewardsEmitter)), type(uint256).max);
//    assertEq(salt.allowance(address(emissions), address(liquidityRewardsEmitter)), type(uint256).max);
//    }
//
//
//	// A unit test to check the performUpkeepForLiquidityHolderEmissions function when there are multiple whitelisted pools with different shares. Verify that the amount of SALT tokens sent to each RewardsEmitter is proportional to the votes received by each pool.
//	function testPerformUpkeepForLiquidityHolderEmissions() public {
//
//		// Reset the performUpkeep timestamp
//        emissions.performUpkeep();
//
//        // Alice and Bob deposit votes for pools
//        vm.startPrank(alice);
//        staking.stakeSALT(5 ether);
//        staking.depositVotes(pool1, 4 ether);
//        staking.depositVotes(pool2, 1 ether);
//        vm.stopPrank();
//
//        vm.startPrank(bob);
//        staking.stakeSALT(5 ether);
//        staking.depositVotes(pool1, 2 ether);
//        staking.depositVotes(pool2, 3 ether);
//        vm.stopPrank();
//
//		// Emissions.performUpkeep should cap the transferred rewards at one week of duration
//		// We'll try with two weeks and make sure that it is capped
//		vm.warp( block.timestamp + 2 weeks );
//
//        uint256 amountToSend = 100 ether;
//        salt.transfer( address(emissions), amountToSend );
//        emissions.performUpkeep();
//
//        // For a delay of more than one week, performUpkeep will send 1% (as modified in the constructor) of the SALT balance in the Emissions contract to the liquidityRewardsEmitter
//        // Half of that will go to liquidity and half to the xSALT holders
//        uint256 saltRewardsForLiquidity = amountToSend / 100 / 2;
//
//        // Check that the amount of SALT sent to each RewardsEmitter is proportional to the votes received by each pool
//        uint256 pool1Rewards = pendingLiquidityRewardsForPool(pool1);
//        uint256 pool2Rewards = pendingLiquidityRewardsForPool(pool2);
//
//        // Pool 1 has 6 votes and Pool 2 has 4 votes, so the ratios should be 6:4 or 3:2.
//        assertEq(pool1Rewards, (saltRewardsForLiquidity * 3) / 5);
//        assertEq(pool2Rewards, (saltRewardsForLiquidity * 2) / 5);
//    }
//
//
//	// A unit test to check the performUpkeepForLiquidityHolderEmissions function when the total number of pool votes is zero, ensuring the function does not perform any actions.
//	function testPerformUpkeepForLiquidityHolderEmissionsWithZeroTotalPoolVotes() public {
//		// Reset the performUpkeep timestamp
//        emissions.performUpkeep();
//
//		// Emissions.performUpkeep should cap the transferred rewards at one week of duration
//		// We'll try with two weeks and make sure that it is capped
//		vm.warp( block.timestamp + 2 weeks );
//
//        uint256 amountToSend = 100 ether;
//        salt.transfer( address(emissions), amountToSend );
//        emissions.performUpkeep();
//
//        // Check that the amount of SALT sent to each RewardsEmitter is proportional to the votes received by each pool
//        uint256 pool1Rewards = pendingLiquidityRewardsForPool(pool1);
//        uint256 pool2Rewards = pendingLiquidityRewardsForPool(pool2);
//
//        // There shoudl be no rewards as there were no votes
//        assertEq(pool1Rewards, 0 );
//        assertEq(pool2Rewards, 0 );
//    }
//
//
//	// A unit test to check the _performUpkeep function when the timeSinceLastUpkeep is zero. Verify that the function does not perform any actions.
//	function testPerformUpkeepWithZeroTimeSinceLastUpkeep() public {
//
//		// Transfer the initial rewards
//        salt.transfer( address(emissions), 100 ether );
//
//        // Alice and Bob deposit votes for pools
//        vm.startPrank(alice);
//        staking.stakeSALT(5 ether);
//        staking.depositVotes(pool1, 4 ether);
//        staking.depositVotes(pool2, 1 ether);
//        vm.stopPrank();
//
//        vm.startPrank(bob);
//        staking.stakeSALT(5 ether);
//        staking.depositVotes(pool1, 2 ether);
//        staking.depositVotes(pool2, 3 ether);
//        vm.stopPrank();
//
//        emissions.performUpkeep();
//
//        // Call _performUpkeep function
//        uint256 initialSaltBalance = salt.balanceOf(address(this));
//        emissions.performUpkeep();
//
//        // Since timeSinceLastUpkeep was zero, no actions should be taken
//        // Therefore, the SALT balance should be the same
//        uint256 finalSaltBalance = salt.balanceOf(address(this));
//        assertEq(initialSaltBalance, finalSaltBalance);
//    }
//
//
//	// A unit test to check the _performUpkeep function when the balance of SALT in the contract is zero. Verify that the function does not perform any actions.
//	function testPerformUpkeepWithZeroSaltBalance() public {
//		// Transfer the initial rewards
//        salt.transfer( address(emissions), 100 ether );
//
//        // Alice stakes and deposits votes for pools
//        vm.startPrank(alice);
//        staking.stakeSALT(5 ether);
//        staking.depositVotes(pool1, 2 ether);
//        staking.depositVotes(pool2, 3 ether);
//        vm.stopPrank();
//
//        // Bob stakes and deposits votes for pools
//        vm.startPrank(bob);
//        staking.stakeSALT(5 ether);
//        staking.depositVotes(pool1, 3 ether);
//        staking.depositVotes(pool2, 2 ether);
//        vm.stopPrank();
//
//        // Transfer out all SALT from the contract to achieve zero balance
//        salt.transfer(alice, salt.balanceOf(address(this)));
//
//		vm.warp( block.timestamp + 2 weeks );
//
//        // Call _performUpkeep function
//        uint256 initialSaltBalance = salt.balanceOf(address(this));
//        emissions.performUpkeep();
//
//        // Since the SALT balance was zero, no actions should be taken
//        uint256 finalSaltBalance = salt.balanceOf(address(this));
//        assertEq(initialSaltBalance, finalSaltBalance);
//    }
//
//
//	// A unit test to check the _performUpkeep function when the SALT balance, timeSinceLastUpkeep, and weekly emission rate are all non-zero. Verify that the amount of SALT sent to the stakingRewardsEmitter and liquidityRewardsEmitter is correct and proportional to the configured percentage.  Multiple timeSinceLastUpkeep values should be simulated.
//	function testPerformUpkeepWithNonZeroValues() public {
//
//		// Transfer the initial rewards
//        salt.transfer( address(emissions), 100 ether );
//
//		emissions.performUpkeep();
//
//		// Alice stakes and deposits votes for pools
//		vm.startPrank(alice);
//		staking.stakeSALT(5 ether);
//		staking.depositVotes(pool1, 2 ether);
//		staking.depositVotes(pool2, 3 ether);
//		vm.stopPrank();
//
//		// Bob stakes and deposits votes for pools
//		vm.startPrank(bob);
//		staking.stakeSALT(10 ether);
//		staking.depositVotes(pool1, 3 ether);
//		staking.depositVotes(pool2, 7 ether);
//		vm.stopPrank();
//
//		// Set timeSinceLastUpkeep to different non-zero values
//		uint256[] memory upkeepIntervals = new uint256[](5);
//		upkeepIntervals[0] = 15 minutes;
//		upkeepIntervals[1] = 1 hours;
//		upkeepIntervals[2] = 24 hours;
//		upkeepIntervals[3] = 1 weeks;
//		upkeepIntervals[4] = 2 weeks;
//
////		console.log( "SALT BALANCE: ", salt.balanceOf( address(emissions) ) );
//
//		// 1 % weekly and 75% for xSaltHolders
//		vm.startPrank( DEPLOYER );
//		for( uint256 i = 0; i < 5; i++ )
//			rewardsConfig.changeXSaltHoldersPercent(true);
//		vm.stopPrank();
//
//		for (uint256 i = 0; i < upkeepIntervals.length; i++) {
//			uint256 initialBalanceStakingRewardsEmitter = salt.balanceOf(address(stakingRewardsEmitter));
//			uint256 initialBalanceLiquidityRewardsEmitter = salt.balanceOf(address(liquidityRewardsEmitter));
//
//			vm.warp(block.timestamp + upkeepIntervals[i]);
//
//			uint256 saltBalance = salt.balanceOf(address(emissions));
//
//			// Interval is capped at one week
//			uint256 interval = upkeepIntervals[i];
//			if ( interval > 1 weeks )
//				interval = 1 weeks;
//
//			uint256 expectedDistribution = ( saltBalance * interval * rewardsConfig.emissionsWeeklyPercentTimes1000() ) / ( 100 * 1000 weeks );
//			emissions.performUpkeep();
//
//			uint256 finalBalanceStakingRewardsEmitter = salt.balanceOf(address(stakingRewardsEmitter));
//			uint256 finalBalanceLiquidityRewardsEmitter = salt.balanceOf(address(liquidityRewardsEmitter));
//
//			uint256 xsaltHoldersExpectedAmount = ( expectedDistribution * 75 ) / 100;
//			uint256 liquidityHoldersRewardsExpectedAmount = expectedDistribution - xsaltHoldersExpectedAmount;
//
////			console.log( "xsaltHoldersExpectedAmount: ", xsaltHoldersExpectedAmount );
////			console.log( "liquidityHoldersRewardsExpectedAmount: ", liquidityHoldersRewardsExpectedAmount );
//
//			// Remove the significance of the last three digits for the check
//			assertEq(( finalBalanceStakingRewardsEmitter - initialBalanceStakingRewardsEmitter ) / 1000, xsaltHoldersExpectedAmount / 1000 );
//			assertEq(( finalBalanceLiquidityRewardsEmitter - initialBalanceLiquidityRewardsEmitter ) / 1000, liquidityHoldersRewardsExpectedAmount / 1000 );
//		}
//	}
//
//
//	// A unit test in which 10 ether votes are deposited into pool1 and pool2 and performUpkeep is called, then 10 ether more is deposited into pool2, 1 day passes and performUpkeep is called. Checks that the proper amount of SALT rewards is deposited in _liquidtity for pool1 and pool2 each time.
//	function testPerformUpkeep() public {
//
//        emissions.performUpkeep();
//
//		// Transfer the initial rewards
//        salt.transfer( address(emissions), 100 ether );
//
//        vm.startPrank(alice);
//        staking.stakeSALT( 30 ether );
//        staking.depositVotes(pool1, 10 ether);
//        staking.depositVotes(pool2, 10 ether);
//		vm.stopPrank();
//
//		vm.warp( block.timestamp + 1 days );
//
//		uint256 saltBalance = salt.balanceOf(address(emissions));
//		uint256 expectedDistribution = ( saltBalance * ( 1 days ) * rewardsConfig.emissionsWeeklyPercentTimes1000() ) / ( 100 * 1000 weeks );
//
//		// Liquidity gets 50% by default
//		expectedDistribution = expectedDistribution / 2;
//
//        // Call performUpkeep to send emissions to liquidityRewardsEmitter
//        emissions.performUpkeep();
//
//
//        // Check that the amount of SALT sent to each RewardsEmitter is proportional to the votes received by each pool
//        uint256 pool1Rewards = pendingLiquidityRewardsForPool(pool1);
//        uint256 pool2Rewards = pendingLiquidityRewardsForPool(pool2);
//
//        assertEq(pool1Rewards, (expectedDistribution * 10) / 20);
//        assertEq(pool2Rewards, (expectedDistribution * 10) / 20);
//
//		// Deposit more votes for pool2 and wait two days
//        vm.prank(alice);
//        staking.depositVotes(pool2, 10 ether);
//
//		vm.warp( block.timestamp + 2 days );
//
//		uint256 saltBalance2 = salt.balanceOf(address(emissions));
//		uint256 expectedDistribution2 = ( saltBalance2 * ( 2 days ) * rewardsConfig.emissionsWeeklyPercentTimes1000() ) / ( 100 * 1000 weeks );
//
//		// Liquidity gets 50% by default
//		expectedDistribution2 = expectedDistribution2 / 2;
//
//        // Call performUpkeep to send emissions to liquidityRewardsEmitter proportional to the
//        // 10 ether voted for pool1 and 20 ether voted for pool2
//        emissions.performUpkeep();
//
//
//        uint256 pool1Rewards2 = pendingLiquidityRewardsForPool(pool1);
//        uint256 pool2Rewards2 = pendingLiquidityRewardsForPool(pool2);
//
//		// Get rid ot he last digit (in wei) to account for possible rounding errors
//        assertEq(pool1Rewards2 / 10, ( pool1Rewards + (expectedDistribution2 * 10 ) / 30 ) / 10 );
//        assertEq(pool2Rewards2 / 10, ( pool2Rewards + (expectedDistribution2 * 20) / 30 ) / 10);
//    }
//
//
//	// A unit test to check the _performUpkeep function when there are a large number of whitelisted pools. This test is to ensure the contract can handle a large number of pools without any issues.
//	function testPerformUpkeepWithMaximumWhitelist() public {
//		// Transfer the initial rewards
//        salt.transfer( address(emissions), 100 ether );
//
//		vm.prank(alice);
//		staking.stakeSALT( 100 ether );
//
//		vm.prank(bob);
//		staking.stakeSALT( 100 ether );
//
//		uint256 initialNumberOfPools = stakingConfig.numberOfWhitelistedPools();
//		uint256 numMaxPools = stakingConfig.maximumWhitelistedPools();
//
//        // Let's create and whitelist a large number of pools, up to the maximum limit
//        for(uint i = 0; i < numMaxPools - initialNumberOfPools; i++) {
//
//        	vm.startPrank(DEPLOYER);
//            IUniswapV2Pair pool = IUniswapV2Pair(address( new TestERC20( 18 ) ));  // Make sure these addresses don't overlap with any existing ones
//            stakingConfig.whitelist(pool);
//            vm.stopPrank();
//
//       	 // Let's stake some SALT for Alice and Bob in a few random pools (remember, pool[0] cannot receive votes)
//			vm.prank(alice);
//			staking.depositVotes(pool, 5 ether / numMaxPools );
//
//			vm.prank(bob);
//			staking.depositVotes(pool, 5 ether / numMaxPools );
//        }
//
//        // Let's warp to the future
//        vm.warp(block.timestamp + 1 weeks);
//
//        // Run _performUpkeep and expect no reverts
//        emissions.performUpkeep();
//    }
//
//	}
