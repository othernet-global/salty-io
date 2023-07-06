//// SPDX-License-Identifier: BSL 1.1
//pragma solidity ^0.8.12;
//
//import "forge-std/Test.sol";
//import "../uniswap/core/interfaces/IUniswapV2Factory.sol";
//import "../uniswap/core/interfaces/IUniswapV2Pair.sol";
//import "../interfaces/IAAA.sol";
//import "../Salt.sol";
//import "../stable/USDS.sol";
//import "../stable/tests/IForcedPriceFeed.sol";
//import "../stable/StableConfig.sol";
//import "../staking/interfaces/IStakingConfig.sol";
//import "../staking/StakingConfig.sol";
//import "../interfaces/IPOL_Optimizer.sol";
//import "../ExchangeConfig.sol";
//import "../interfaces/IExchangeConfig.sol";
//import "../stable/Collateral.sol";
//import "../stable/Liquidator.sol";
//import "../staking/Liquidity.sol";
//import "../rewards/RewardsEmitter.sol";
//import "../rewards/interfaces/IRewardsEmitter.sol";
//import "../rewards/RewardsEmitter.sol";
//import "../POL_Optimizer.sol";
//import "../dao/interfaces/IDAO.sol";
//import "../interfaces/IAccessManager.sol";
//import "../tests/TestAccessManager.sol";
//import "../tests/TestERC20.sol";
//
//contract TestOptimizer is Test, POL_Optimizer
//	{
//	IStableConfig public _stableConfig = IStableConfig(address(new StableConfig(IPriceFeed(address(_forcedPriceFeed))) ) );
//	IStakingConfig public _stakingConfig = IStakingConfig(address(new StakingConfig(IERC20(address(new Salt())))));
//	IAccessManager public accessManager = IAccessManager(new TestAccessManager());
//	RewardsConfig public _rewardsConfig = new RewardsConfig();
//
//	ICollateral public _collateral = new Collateral( _collateralLP, _usds, _stableConfig, _stakingConfig, _exchangeConfig );
//	Liquidator public _liquidator = new Liquidator( _collateralLP, _saltyRouter, _collateral, _stableConfig, _exchangeConfig );
//	IDAO public constant dao = IDAO(address(0xDA0));
//    IAAA public constant aaa = IAAA(address(0xc5753E05803832413084aE2dd1565878250A185A));
//
//	Liquidity public _liquidity = new Liquidity(_stakingConfig, _exchangeConfig);
//	IStakingRewards public _liquidityRewards = IStakingRewards(address(_liquidity));
//	IRewardsEmitter public _liquidityRewardsEmitter = new RewardsEmitter(_rewardsConfig, _stakingConfig, _liquidityRewards );
//
//	// User wallets for testing
//    address public constant alice = address(0x1111);
//    address public constant bob = address(0x2222);
//    address public constant charlie = address(0x3333);
//
//
//	constructor()
//		POL_Optimizer( _stakingConfig, _exchangeConfig,  _liquidityRewardsEmitter, _factory, _saltyRouter )
//		{
//		vm.startPrank( DEPLOYER );
//		_exchangeConfig.setDAO(dao);
//		_exchangeConfig.setLiquidator(_liquidator);
//		_exchangeConfig.setAccessManager(accessManager);
//		_exchangeConfig.setOptimizer(this);
//
//		// setCollateral so that usds.mintTo() can be called
//		_usds.setCollateral( _collateral );
//		vm.stopPrank();
//
//		// Mint some USDS to the DEPLOYER
//		vm.prank( address(_collateral) );
//		_usds.mintTo( DEPLOYER, 10000000 ether );
//
//		_stakingConfig.whitelist( _collateralLP );
//
//		// So that SALT rewards can be added
//		_stakingConfig.salt().approve( address(_liquidityRewardsEmitter), type(uint256).max );
//		}
//
//
//    function setUp() public
//    	{
//		assertEq( address(_collateralLP), address(0x8a47e16a804E6d7531e0a8f6031f9Fee12EaeE57), "Unexpected collateralLP" );
//
//    	// The test tokens are held by DEPLOYER
//		vm.startPrank( DEPLOYER );
//
//		// Dev Approvals for adding liquidity
//		_wbtc.approve( address(_saltyRouter), type(uint256).max );
//        _weth.approve( address(_saltyRouter), type(uint256).max );
//        _usdc.approve( address(_saltyRouter), type(uint256).max );
//		_usds.approve( address(_saltyRouter), type(uint256).max );
//
//		// Have DEPLOYER create some initial liquidity on Salty.IO
//		_saltyRouter.addLiquidity( address(_wbtc), address(_weth), 13 * 10 ** 8, 200 ether, 0, 0, DEPLOYER, block.timestamp );
//		_saltyRouter.addLiquidity( address(_wbtc), address(_usdc), 100 * 10 ** 8, 300000 ether, 0, 0, DEPLOYER, block.timestamp );
//		_saltyRouter.addLiquidity( address(_wbtc), address(_usds), 100 * 10 ** 8, 300000 ether, 0, 0, DEPLOYER, block.timestamp );
//		_saltyRouter.addLiquidity( address(_weth), address(_usdc), 1000 ether, 200000 ether, 0, 0, DEPLOYER, block.timestamp );
//		_saltyRouter.addLiquidity( address(_weth), address(_usds), 1000 ether, 200000 ether, 0, 0, DEPLOYER, block.timestamp );
//
//        _wbtc.transfer(alice, 5 * 10 ** 8);
//        _weth.transfer(alice, 5 ether);
//        _usdc.transfer(alice, 5 ether);
//        _usds.transfer(alice, 5 ether);
//        vm.stopPrank();
//
//		// Approvals for swapping
//    	vm.startPrank(alice);
//        _wbtc.approve(address(_saltyRouter), type(uint).max);
//        _weth.approve(address(_saltyRouter), type(uint).max);
//        _usdc.approve(address(_saltyRouter), type(uint).max);
//        _usds.approve(address(_saltyRouter), type(uint).max);
//        vm.stopPrank();
//    	}
//
//
//	// A unit test to verify the constructor with correct initialization parameters. This test should ensure that the contract is deployed correctly with the correct initial state.
//	function testInitializerParameters() public {
//        assertEq(address(this.weth()), address(_weth));
//        assertEq(address(this.stakingConfig()), address(_stakingConfig));
//        assertEq(address(this.liquidityRewardsEmitter()), address(_liquidityRewardsEmitter));
//        assertEq(address(this.saltyFactory()), address(_factory));
//        assertEq(address(this.saltyRouter()), address(_saltyRouter));
//    }
//
//
//	// A unit test to evaluate the maxOfThree function covering cases where a, b, or c is the maximum, and all three are equal.
//	function testMaxOfThree() public {
//        // Case 1: a is maximum
//        assertEq(_maxOfThree(5, 2, 3), 5, "Case 1 failed: a is not maximum");
//
//        // Case 2: b is maximum
//        assertEq(_maxOfThree(1, 6, 4), 6, "Case 2 failed: b is not maximum");
//
//        // Case 3: c is maximum
//        assertEq(_maxOfThree(3, 5, 7), 7, "Case 3 failed: c is not maximum");
//
//        // Case 4: all equal
//        assertEq(_maxOfThree(7, 7, 7), 7, "Case 4 failed: all values are equal");
//
//        // Case 5: all equal zero
//        assertEq(_maxOfThree(0,0,0), 0, "Case 5 failed: all values are equal");
//    }
//
//
//
//	// A unit test to check the lastSwapTimestamp function under various scenarios with different token pairs and different blockTimestamps.
//	function testLastSwapTimestamp() public {
//
//		vm.startPrank(alice);
//
//        // Prepare paths for swaps
//        address[] memory path1 = new address[](2);
//        path1[0] = address(_usds);
//        path1[1] = address(_weth);
//
//        address[] memory path2 = new address[](2);
//        path2[0] = address(_wbtc);
//        path2[1] = address(_weth);
//
//        address[] memory path3 = new address[](2);
//        path3[0] = address(_wbtc);
//        path3[1] = address(_usds);
//
//		uint256 timestamp0 = block.timestamp;
//		vm.warp( block.timestamp + 1 days );
//		uint256 timestamp1 = block.timestamp;
//
//		 _saltyRouter.swapExactTokensForTokens(1 ether, 0, path1, alice, block.timestamp);
//
//        assertEq(timestamp1, this.lastSwapTimestamp(address(_usds), address(_wbtc)), "lastSwapTimestamp not updated" );
//        assertEq(timestamp1, this.lastSwapTimestamp(address(_usds), address(_weth)), "lastSwapTimestamp not updated" );
//        assertEq(timestamp0, this.lastSwapTimestamp(address(_wbtc), address(_weth)), "lastSwapTimestamp should not be updated" );
//
//
//		vm.warp( block.timestamp + 1 days );
//		uint256 timestamp2 = block.timestamp;
//		 _saltyRouter.swapExactTokensForTokens(1 * 10 ** 8, 0, path2, alice, block.timestamp);
//
//        assertEq(timestamp2, this.lastSwapTimestamp(address(_usds), address(_wbtc)), "lastSwapTimestamp not updated" );
//        assertEq(timestamp2, this.lastSwapTimestamp(address(_wbtc), address(_weth)), "lastSwapTimestamp not updated" );
//        assertEq(timestamp1, this.lastSwapTimestamp(address(_usds), address(_weth)), "lastSwapTimestamp should not be updated" );
//
//
//		vm.warp( block.timestamp + 1 days );
//		uint256 timestamp3 = block.timestamp;
//		 _saltyRouter.swapExactTokensForTokens(1 * 10 ** 8, 0, path3, alice, block.timestamp);
//
//        assertEq(timestamp3, this.lastSwapTimestamp(address(_wbtc), address(_usds)), "lastSwapTimestamp not updated" );
//        assertEq(timestamp2, this.lastSwapTimestamp(address(_wbtc), address(_weth)), "lastSwapTimestamp should not be updated" );
//        assertEq(timestamp1, this.lastSwapTimestamp(address(_usds), address(_weth)), "lastSwapTimestamp should not be updated" );
//    }
//
//
//
//
//
//
//
//
//
//	// A unit test to assess the lastSwapTimestamp function in scenarios where one or more pairs returned by the saltyFactory.getPair() do not exist.
//	function testLastSwapTimestampWithNonExistentPair() public {
//        address token0 = address(0xDEAD1);
//        address token1 = address(0xDEAD2);
//
//        // First we ensure that the pair does not exist
//        IUniswapV2Pair nonexistentPair = IUniswapV2Pair(_factory.getPair(token0, token1));
//        assertTrue(nonexistentPair == IUniswapV2Pair(address(0)));
//
//        // Test
//        vm.expectRevert( "Nonexistant pair" );
//        this.lastSwapTimestamp(token0, token1);
//    }
//
//
//	// A unit test to test the _performUpkeep function in a scenario where the balance of WETH in the contract is zero.
//	function testPerformUpkeepWithZeroWETHBalance() public {
//		// Ensure that the WETH balance is 0
//		weth.transfer(DEPLOYER, weth.balanceOf(address(this)));
//
//		// Increase block time by 100 seconds to ensure MINIMUM_TIME_SINCE_LAST_SWAP condition is met
//		vm.warp(block.timestamp + 100);
//
//		// Call the _performUpkeep function
//		_performUpkeep();
//
//		// Assert that the WETH balance is still 0 after the function call
//		assertEq(weth.balanceOf(address(this)), 0);
//	}
//
//
//	// A unit test to test the _performUpkeep function in a scenario where there is no pending reward.
//	function testPerformUpkeepNoPendingReward() public {
//
//        // Call function with 0 WETH balance in the contract
//        _performUpkeep();
//
//        // Use assertEq to check that the contract's WETH balance remains 0
//        assertEq(weth.balanceOf(address(this)), 0);
//
//        // Add WETH balance to the contract
//        uint256 initialBalance = 10 ether;
//		vm.prank( DEPLOYER );
//        _weth.transfer(address(this), initialBalance);
//
//        // Call function again
//        // By default there should be no pending rewards
//        _performUpkeep();
//
//        // Check that the contract's WETH balance is still the same as there are no pending rewards (which are required to determine the best LP to create POL)
//        assertEq(weth.balanceOf(address(this)), initialBalance);
//    }
//
//
//	// A unit test to test the _performUpkeep function where there is a non-zero balance of WETH in the contract and pending rewards, but the elapsed time since the last swap is less than the minimum.
//	function testPerformUpkeepInsufficientElapsedTime() public {
//		// Transfer some initial WETH to this contract
//        uint256 initialWETHBalance = 5 ether;
//        vm.prank( DEPLOYER );
//        weth.transfer(address(this), initialWETHBalance);
//
//		// Perform an initial swap
//        address[] memory path = new address[](2);
//		path[0] = address(_usdc);
//		path[1] = address(_wbtc);
//
//        vm.prank( alice );
//		 _saltyRouter.swapExactTokensForTokens(1 ether, 0, path, alice, block.timestamp);
//
//		// Pass less time than necessary for new optimized liquidity to be formed
//		vm.warp( block.timestamp + 5 seconds );
//
//		// Create an initial reward for the pool which will make it the top rewarded pool
//		IUniswapV2Pair lp = IUniswapV2Pair( _factory.getPair( path[0], path[1]) );
//		_stakingConfig.whitelist( lp );
//
//	    AddedReward[] memory addedRewards = new AddedReward[](1);
//    	addedRewards[0] = AddedReward(lp, 1 ether);
//
//        _liquidityRewardsEmitter.addSALTRewards(addedRewards);
//
//        // Try to perform upkeep, but expect it to do nothing as not enough time has passed
//        _performUpkeep();
//
//        // Assert that the WETH balance of the contract has not changed
//        assertEq(weth.balanceOf(address(this)), initialWETHBalance);
//    }
//
//
//	// A unit test to test the _performUpkeep function in a scenario where a pending reward exists, and the elapsed time since the last swap is more than the minimum.
//	function performUpkeepSufficientElapsedTime( uint256 minutesToDelayAfterSwap) public {
//		// Transfer some initial WETH to this contract
//        uint256 initialWETHBalance = 5 ether;
//        vm.prank( DEPLOYER );
//        weth.transfer(address(this), initialWETHBalance);
//
//		// Perform an initial swap
//		address[] memory path = new address[](2);
//		path[0] = address(_usds);
//		path[1] = address(_wbtc);
//
//		vm.prank( alice );
//		 _saltyRouter.swapExactTokensForTokens(1 ether, 0, path, alice, block.timestamp);
//
//		// Pass time for new optimized liquidity to be formed
//		vm.warp( block.timestamp + minutesToDelayAfterSwap * 1 minutes );
//
//		// Create an initial reward for the pool which will make it the top rewarded pool
//		IUniswapV2Pair lp = IUniswapV2Pair( _factory.getPair( path[0], path[1]) );
//		_stakingConfig.whitelist( lp );
//
//		AddedReward[] memory addedRewards = new AddedReward[](1);
//		addedRewards[0] = AddedReward(lp, 1 ether);
//		_liquidityRewardsEmitter.addSALTRewards(addedRewards);
//
//		uint256 startingBalanceWETH = weth.balanceOf( address(this) );
//
//		// Perform upkeep which will use a percent of WETH dependent on how long has passed since the last swap
//		_performUpkeep();
//
//		uint256 wethToUse = 0;
//
//		// At least one minute since the last swap on the most recent pool to help avoid sandwich attacks
//		// on the swaps from WETH to token0 and token1
//		if ( minutesToDelayAfterSwap * 60 >= MINIMUM_TIME_SINCE_LAST_SWAP )
//			{
//			// Use a percent of the WETH balance based on how many minutes have elapsed since the last
//			// swap that occurred on any of the pools involved in forming LP.
//			// Each minute elapsed will be one percent of WETH used (with a max of default 25%)
//			uint256 percent = minutesToDelayAfterSwap;
//
//			if ( percent > MAX_SWAP_PERCENT )
//				percent = MAX_SWAP_PERCENT;
//
//			wethToUse = ( startingBalanceWETH * percent ) / 100;
//			}
//
//
//		// Assert that the WETH balance of the contract has not changed
//		uint256 wethUsed = startingBalanceWETH - weth.balanceOf( address(this) );
//
//		// Values are rounded for the assert comparisons
//		if ( minutesToDelayAfterSwap == 0 )
//			assertEq( wethUsed, 0 );
//		if ( minutesToDelayAfterSwap == 1 )
//			assertEq( wethUsed / 10 ** 18, ( startingBalanceWETH * 1 ) / 100 / 10 ** 18 );
//		if ( minutesToDelayAfterSwap == 10 )
//			assertEq( wethUsed / 10 ** 18, ( startingBalanceWETH * 10 ) / 100 / 10 ** 18 );
//		if ( minutesToDelayAfterSwap == 25 )
//			assertEq( wethUsed / 10 ** 18, ( startingBalanceWETH * 25 ) / 100 / 10 ** 18 );
//		if ( minutesToDelayAfterSwap == 60 )
//			assertEq( wethUsed / 10 ** 18, ( startingBalanceWETH * 25 ) / 100 / 10 ** 18 );
//	}
//
//
//	// A unit test to test the _performUpkeep function in a scenario where a pending reward exists.
//	// Try delaying after the swap for multiple minutes to test how much of the WETH balance is used to form liquidity
//	function testPerformUpkeepSufficientElapsedTime() public {
//		performUpkeepSufficientElapsedTime(0);
//		performUpkeepSufficientElapsedTime(1);
//		performUpkeepSufficientElapsedTime(10);
//		performUpkeepSufficientElapsedTime(25);
//		performUpkeepSufficientElapsedTime(60);
//		}
//
//
//	// A unit test that checks to see that WETH swapped for the best pool liquidity is deposited in appropriate amounts to the DAO.
//	function testSwapForBestPoolLiquidityDepositsToDAO() public {
//		// Transfer some initial WETH to this contract
//		uint256 initialETH = 20 ether;
//        vm.prank( DEPLOYER );
//        weth.transfer(address(this), initialETH);
//
//		// Perform an initial swap
//		address[] memory path = new address[](2);
//		path[0] = address(_usds);
//		path[1] = address(_weth);
//
//		vm.prank( alice );
//		 _saltyRouter.swapExactTokensForTokens(1 ether, 0, path, alice, block.timestamp);
//
//		// 60 minutes should allow the maximum of 25% of the WETH to be used for optimized liquidity
//		vm.warp( block.timestamp + 60 minutes );
//
//		// Create an initial reward for the pool which will make it the top rewarded pool
//		IUniswapV2Pair lp = IUniswapV2Pair( _factory.getPair( path[0], path[1]) );
//		_stakingConfig.whitelist( lp );
//
//		AddedReward[] memory addedRewards = new AddedReward[](1);
//		addedRewards[0] = AddedReward(lp, 1 ether);
//		_liquidityRewardsEmitter.addSALTRewards(addedRewards);
//
//		assertEq( lp.balanceOf( address(dao) ), 0, "LP balance of the DAO should start at zero" );
//
//		// Perform upkeep which will use a percent of WETH dependent on how long has passed since the last swap
//		_performUpkeep();
//
////		uint256 expectedUsedWETH = initialETH / 4;
////		assertEq( (initialETH - weth.balanceOf(address(this))) / 10 ** 16, expectedUsedWETH / 10 ** 16, "Incorrect amount of WETH used" );
////
////		uint256 daoLP = lp.balanceOf( address(dao) );
////		(uint112 reserve0, uint112 reserve1,) = lp.getReserves();
////
////		if ( address(lp.token0()) == address(_weth) )
////			(reserve0, reserve1) = (reserve1, reserve0 );
////
////		uint256 underlyingWETH = reserve1 * daoLP / lp.totalSupply();
////		//console.log( "UNDERLYING WETH: ", underlyingWETH );
////
////		// Should have about half of the expectedUsedWETH in the underlyingWETH.
////		// The other half would have been swapped for ETH
////		assertEq( underlyingWETH / 10 ** 16, expectedUsedWETH / 2 / 10 ** 16, "Incorrect underlying WETH" );
//    }
//
//
//	// A unit test to examine the findBestPool function in a scenario where no pool is available.
//	function testFindBestPoolWithNoRewardedPools() public {
//        // Find the best pool
//        (uint256 maxRewardsPerShare, IUniswapV2Pair bestPool) = this.findBestPool();
//
//        // Check there is no pool and reward is zero
//        assertEq(maxRewardsPerShare, 0);
//        assertEq(address(bestPool), address(0));
//    }
//
//
//	// A unit test to test the findBestPool function in a scenario where exactly one pool has rewards
//	function testFindBestPool() public {
//		// Create an initial reward for ETH/USDS which will make it the top rewarded pool
//		IUniswapV2Pair ethUSDSPool = IUniswapV2Pair( _factory.getPair( address(_weth), address(_usds)) );
//		_stakingConfig.whitelist( ethUSDSPool );
//
//		AddedReward[] memory addedRewards = new AddedReward[](1);
//		addedRewards[0] = AddedReward(ethUSDSPool, 20 ether);
//		_liquidityRewardsEmitter.addSALTRewards(addedRewards);
//
//		// With pendingRewards but no shares in the pool, the rewardsPerShare should be uint256.max
//		(uint256 maxRewardsPerShare, IUniswapV2Pair bestPool) = this.findBestPool();
//        assertEq(maxRewardsPerShare, type(uint256).max);
//        assertEq(address(bestPool), address(ethUSDSPool));
//
//        // Have DEPLOYER stake some liquidity
//        vm.startPrank( DEPLOYER );
//        ethUSDSPool.approve( address(_liquidity),  type(uint256).max );
//
//        _liquidity.stake( ethUSDSPool, 10 ether );
//
//		// Expected maxRewardsPerShare is 20ether / 10ether * 10**18
//		(maxRewardsPerShare, bestPool) = this.findBestPool();
//        assertEq(maxRewardsPerShare, 2 ether, "Incorrent maxRewardsPerShare" );
//        vm.stopPrank();
//		}
//
//
//	// A unit test to test the findBestPool function in a scenario where there are multiple pools with different pending rewards.
//	function testFindBestPoolWithMultiplePendingRewards() public {
//		// Create an initial reward for ETH/USDS which will make it the top rewarded pool
//		IUniswapV2Pair pool1 = IUniswapV2Pair( _factory.getPair( address(_weth), address(_usds)) );
//		IUniswapV2Pair pool2 = IUniswapV2Pair( _factory.getPair( address(_wbtc), address(_usds)) );
//		IUniswapV2Pair pool3 = IUniswapV2Pair( _factory.getPair( address(_wbtc), address(_weth)) );
//
//		_stakingConfig.whitelist( pool1 );
//		_stakingConfig.whitelist( pool2 );
//		_stakingConfig.whitelist( pool3 );
//
//		AddedReward[] memory addedRewards = new AddedReward[](3);
//		addedRewards[0] = AddedReward(pool1, 1 * 10 ** 8);
//		addedRewards[1] = AddedReward(pool2, 3 * 10 ** 8);
//		addedRewards[2] = AddedReward(pool3, 2 );
//		_liquidityRewardsEmitter.addSALTRewards(addedRewards);
//
//		vm.startPrank(DEPLOYER);
//		pool1.approve( address(_liquidity), 1 * 10 ** 8 );
//		pool2.approve( address(_liquidity), 1 * 10 ** 8 );
//		pool3.approve( address(_liquidity), 1 * 10 ** 8 );
//
////		console.log( "POOL1: ", pool1.balanceOf(address(DEPLOYER)) );
////		console.log( "POOL2: ", pool2.balanceOf(address(DEPLOYER)) );
////		console.log( "POOL3: ", pool3.balanceOf(address(DEPLOYER)) );
//
//		_liquidity.stake( pool1, 1 * 10 ** 8 );
//		_liquidity.stake( pool2, 1 * 10 ** 8 );
//		_liquidity.stake( pool3, 1 * 10 ** 8 );
//		vm.stopPrank();
//
//		(uint256 maxPendingReward, IUniswapV2Pair bestPool) = this.findBestPool();
//
//        assertEq(maxPendingReward, 3 ether);
//        assertEq(address(bestPool), address(pool2));
//		}
//
//
//	// A unit test to test the findBestPool function in a scenario where there are multiple pools with the same pending rewards.
//	function testFindBestPoolWithMultiplePendingSimilarRewards() public {
//		// Create an initial reward for ETH/USDS which will make it the top rewarded pool
//		IUniswapV2Pair pool1 = IUniswapV2Pair( _factory.getPair( address(_weth), address(_usds)) );
//		IUniswapV2Pair pool2 = IUniswapV2Pair( _factory.getPair( address(_wbtc), address(_usds)) );
//		IUniswapV2Pair pool3 = IUniswapV2Pair( _factory.getPair( address(_wbtc), address(_weth)) );
//
//		_stakingConfig.whitelist( pool1 );
//		_stakingConfig.whitelist( pool2 );
//		_stakingConfig.whitelist( pool3 );
//
//		AddedReward[] memory addedRewards = new AddedReward[](3);
//		addedRewards[0] = AddedReward(pool1, 20 * 10 ** 8 );
//		addedRewards[1] = AddedReward(pool2, 20 * 10 ** 8 );
//		addedRewards[2] = AddedReward(pool3, 20 * 10 ** 8 );
//		_liquidityRewardsEmitter.addSALTRewards(addedRewards);
//
//		vm.startPrank(DEPLOYER);
//		pool1.approve( address(_liquidity), 10 * 10 ** 8  );
//		pool2.approve( address(_liquidity), 10 * 10 ** 8  );
//		pool3.approve( address(_liquidity), 10 * 10 ** 8  );
//
//		_liquidity.stake( pool1, 10 * 10 ** 8  );
//		_liquidity.stake( pool2, 10 * 10 ** 8  );
//		_liquidity.stake( pool3, 10 * 10 ** 8  );
//		vm.stopPrank();
//
//		(uint256 maxPendingReward, IUniswapV2Pair bestPool) = this.findBestPool();
//        assertEq(maxPendingReward, 2 ether, "Incorrect maxPendingReward");
//
//		// Not sure of which will be returned as whitelistedPools is an EnumerableSet
//		bool good = ( address(bestPool) == address(pool1) );
//		good = good || ( address(bestPool) == address(pool2) );
//		good = good || ( address(bestPool) == address(pool3) );
//
//        assertTrue( good, "Unrecognized bestPool" );
//		}
//
//
//	// A unit test to test the findBestPool function in a scenario where no whitelisted pools are available.
//		function testFindBestPoolWithNoWhitelistedPools() public {
//            // Set up a state with no available pools
//            _stakingConfig.unwhitelist(_collateralLP);
//
//            // Find the best pool
//            (uint256 maxPendingReward, IUniswapV2Pair bestPool) = this.findBestPool();
//
//            // Check there is no pool and reward is zero
//            assertEq(maxPendingReward, 0);
//            assertEq(address(bestPool), address(0));
//        }
//    }
//
