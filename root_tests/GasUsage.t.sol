//// SPDX-License-Identifier: BSL 1.1
//pragma solidity =0.8.20;
//
//import "forge-std/Test.sol";
//import "../Deployment.sol";
//import "../tests/TestERC20.sol";
//
//
//contract TestGasUsage is Test, Deployment
//	{
//    function setUp() public
//    	{
//        // Whitelist lp
//        vm.startPrank(DEPLOYER);
//        salt.approve(address(liquidityRewardsEmitter), type(uint256).max);
//        vm.stopPrank();
//    	}
//
//
//	// Determine gas usage when whitelisting a maximum number of pools (100)
//	function testGasUsage1() public {
//
//		vm.startPrank(DEPLOYER);
//		for( uint256 i = 0; i < 10; i++ )
//			stakingConfig.changeMaximumWhitelistedPools(true);
//
//		uint256 startingNumPools = stakingConfig.numberOfWhitelistedPools();
//		for( uint256 i = startingNumPools; i < 100; i++ )
//			{
//			IUniswapV2Pair pool = IUniswapV2Pair(address(new TestERC20( 18 )));
//			stakingConfig.whitelist( pool );
//
//	        AddedReward[] memory addedRewards = new AddedReward[](1);
//    	    addedRewards[0] = AddedReward(pool, 10 ether);
//	        liquidityRewardsEmitter.addSALTRewards(addedRewards);
//			}
//		vm.stopPrank();
//
////		console.log( "numberOfWhitelistedPools: ", stakingConfig.numberOfWhitelistedPools() );
//    }
//
//	// Determine gas usage when whitelisting a maximum number of pools (100)
//	function testGasUsage2() public {
//
//		vm.startPrank(DEPLOYER);
//		for( uint256 i = 0; i < 10; i++ )
//			stakingConfig.changeMaximumWhitelistedPools(true);
//
//		uint256 startingNumPools = stakingConfig.numberOfWhitelistedPools();
//		for( uint256 i = startingNumPools; i < 100; i++ )
//			{
//			IUniswapV2Pair pool = IUniswapV2Pair(address(new TestERC20( 18 )));
//			stakingConfig.whitelist( pool );
//
//	        AddedReward[] memory addedRewards = new AddedReward[](1);
//    	    addedRewards[0] = AddedReward(pool, 10 ether);
//	        liquidityRewardsEmitter.addSALTRewards(addedRewards);
//			}
//		vm.stopPrank();
//
//		// 2.5m gas to run performUpkeep on 100 whitelisted pools
//		liquidityRewardsEmitter.performUpkeep();
//
////		console.log( "numberOfWhitelistedPools: ", stakingConfig.numberOfWhitelistedPools() );
//    }
//
//
//
//	// Determine gas usage when whitelisting a maximum number of pools (100)
//	function testMinGasUsage1() public {
//
//		vm.startPrank(DEPLOYER);
//		IUniswapV2Pair[] memory pools = stakingConfig.whitelistedPools();
//
//		for( uint256 i = 0; i < pools.length; i++ )
//			stakingConfig.unwhitelist( pools[i] );
//
//        AddedReward[] memory addedRewards = new AddedReward[](20);
//		for( uint256 i = 0; i < 20; i++ )
//			{
//			IUniswapV2Pair pool = IUniswapV2Pair(address(new TestERC20( 18 )));
//			stakingConfig.whitelist( pool );
//
//    	    addedRewards[i] = AddedReward(pool, 10 ether);
//			}
//
//        liquidityRewardsEmitter.addSALTRewards(addedRewards);
//		vm.stopPrank();
//
////		console.log( "numberOfWhitelistedPools: ", stakingConfig.numberOfWhitelistedPools() );
//    }
//
//	// Determine gas usage when whitelisting a maximum number of pools (100)
//	function testMinGasUsage2() public {
//
//		vm.startPrank(DEPLOYER);
//		IUniswapV2Pair[] memory pools = stakingConfig.whitelistedPools();
//
//		for( uint256 i = 0; i < pools.length; i++ )
//			stakingConfig.unwhitelist( pools[i] );
//
//        AddedReward[] memory addedRewards = new AddedReward[](20);
//		for( uint256 i = 0; i < 20; i++ )
//			{
//			IUniswapV2Pair pool = IUniswapV2Pair(address(new TestERC20( 18 )));
//			stakingConfig.whitelist( pool );
//
//    	    addedRewards[i] = AddedReward(pool, 10 ether);
//			}
//
//        liquidityRewardsEmitter.addSALTRewards(addedRewards);
//
//		// 287k for RewardsEmitter.performUpkeep with initial pools
//		pools = stakingConfig.whitelistedPools();
//		liquidityRewardsEmitter.performUpkeep();
//
//		vm.stopPrank();
//
////		console.log( "numberOfWhitelistedPools: ", stakingConfig.numberOfWhitelistedPools() );
//    }
//
//
//	// Determine gas usage when whitelisting a maximum number of pools (100)
//	function testMinGasUsage3() public {
//
//		vm.startPrank(DEPLOYER);
//		IUniswapV2Pair[] memory pools = stakingConfig.whitelistedPools();
//
//		for( uint256 i = 0; i < pools.length; i++ )
//			stakingConfig.unwhitelist( pools[i] );
//
//        AddedReward[] memory addedRewards = new AddedReward[](20);
//		for( uint256 i = 0; i < 20; i++ )
//			{
//			IUniswapV2Pair pool = IUniswapV2Pair(address(new TestERC20( 18 )));
//			stakingConfig.whitelist( pool );
//
//    	    addedRewards[i] = AddedReward(pool, 10 ether);
//			}
//
//        liquidityRewardsEmitter.addSALTRewards(addedRewards);
//
//		// 287k for RewardsEmitter.performUpkeep with initial pools
//		pools = stakingConfig.whitelistedPools();
//		liquidityRewardsEmitter.performUpkeep();
//
//		vm.warp( block.timestamp + 1 days );
//		liquidityRewardsEmitter.performUpkeep();
//
//		vm.stopPrank();
//
////		console.log( "numberOfWhitelistedPools: ", stakingConfig.numberOfWhitelistedPools() );
//    }
//
//
//	// Determine gas usage when whitelisting a maximum number of pools (100)
//	function testMinEmissionsGasUsage1() public {
//
//		vm.startPrank(DEPLOYER);
//		IUniswapV2Pair[] memory pools = stakingConfig.whitelistedPools();
//
//		for( uint256 i = 0; i < pools.length; i++ )
//			stakingConfig.unwhitelist( pools[i] );
//
//		for( uint256 i = 0; i < 20; i++ )
//			{
//			IUniswapV2Pair pool = IUniswapV2Pair(address(new TestERC20( 18 )));
//			stakingConfig.whitelist( pool );
//
//        	pool.approve(address(liquidity), type(uint256).max);
//        	liquidity.stake(pool, 10 ether);
//			}
//
//		salt.transfer( address(emissions), 1000 ether );
//
//		vm.stopPrank();
//    }
//
//
//	// Determine gas usage when whitelisting a maximum number of pools (100)
//	function testMinEmissionsGasUsage2() public {
//
//		vm.startPrank(DEPLOYER);
//		IUniswapV2Pair[] memory pools = stakingConfig.whitelistedPools();
//
//		for( uint256 i = 0; i < pools.length; i++ )
//			stakingConfig.unwhitelist( pools[i] );
//
//		for( uint256 i = 0; i < 20; i++ )
//			{
//			IUniswapV2Pair pool = IUniswapV2Pair(address(new TestERC20( 18 )));
//			stakingConfig.whitelist( pool );
//
//        	pool.approve(address(liquidity), type(uint256).max);
//        	liquidity.stake(pool, 10 ether);
//			}
//
//		salt.transfer( address(emissions), 1000 ether );
//		emissions.performUpkeep();
//
//		vm.stopPrank();
//    }
//
//
//	// Determine gas usage when whitelisting a maximum number of pools (100)
//	function testMinEmissionsGasUsage3() public {
//
//		vm.startPrank(DEPLOYER);
//		IUniswapV2Pair[] memory pools = stakingConfig.whitelistedPools();
//
//		for( uint256 i = 0; i < pools.length; i++ )
//			stakingConfig.unwhitelist( pools[i] );
//
//		for( uint256 i = 0; i < 20; i++ )
//			{
//			IUniswapV2Pair pool = IUniswapV2Pair(address(new TestERC20( 18 )));
//			stakingConfig.whitelist( pool );
//
//        	pool.approve(address(liquidity), type(uint256).max);
//        	liquidity.stake(pool, 10 ether);
//			}
//
//		salt.transfer( address(emissions), 1000 ether );
//		emissions.performUpkeep();
//
//		vm.warp( block.timestamp + 1 days );
//		emissions.performUpkeep();
//		vm.stopPrank();
//    }
//
//	}
//
