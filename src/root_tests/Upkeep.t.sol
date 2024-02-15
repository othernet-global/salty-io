// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "../dev/Deployment.sol";
import "./ITestUpkeep.sol";


contract TestUpkeep2 is Deployment
	{
    address public constant alice = address(0x1111);

	uint256 numInitialPools;


	constructor()
		{
		initializeContracts();

		finalizeBootstrap();

		grantAccessAlice();
		grantAccessBob();
		grantAccessCharlie();
		grantAccessDeployer();
		grantAccessDefault();

		numInitialPools = poolsConfig.numberOfWhitelistedPools();
		}




    // A unit test to check the performUpkeep function and ensure that lastUpkeepTimeEmissions and lastUpkeepTimeRewardsEmitters are updated.
    function testPerformUpkeep() public
    {
        // Arrange
        vm.prank(DEPLOYER);

        uint256 blockTimeStampBefore = block.timestamp;
        vm.warp( blockTimeStampBefore + 90 ); // Advance the timestamp by 90 seconds

        // Act
        upkeep.performUpkeep();

        // Assert
        uint256 lastUpkeepTimeEmissions = upkeep.lastUpkeepTimeEmissions();
        uint256 lastUpkeepTimeRewardsEmitters = upkeep.lastUpkeepTimeRewardsEmitters();

        assertEq(lastUpkeepTimeEmissions, blockTimeStampBefore + 90, "lastUpkeepTime is not updated");
        assertEq(lastUpkeepTimeRewardsEmitters, blockTimeStampBefore + 90, "lastUpkeepTime is not updated");
    }


    // A unit test to verify the onlySameContract modifier. Test by calling a function with the modifier from another contract and ensure it reverts with the correct error message.
	function testUpkeepModifier() public {
        vm.expectRevert("Only callable from within the same contract");
        ITestUpkeep(address(upkeep)).step1( alice );
    }


    // A unit test to verify the performUpkeep function when it is called multiple times in quick succession. Ensure that the lastUpkeepTime is correctly updated on each call.
    function testUpdateLastUpkeepTime() public {

            for (uint i=0; i < 5; i++)
            	{
            	uint256 timeIncrease = i * 1 hours;

                // Increase block time
                vm.warp(block.timestamp + timeIncrease);

                // Execute the performUpkeep function
                upkeep.performUpkeep();

                // Check if lastUpkeepTime has updated correctly
                assertEq(upkeep.lastUpkeepTimeEmissions(), block.timestamp, "Incorrect lastUpkeepTimeEmissions");
                assertEq(upkeep.lastUpkeepTimeRewardsEmitters(), block.timestamp, "Incorrect lastUpkeepTimeRewardsEmitters");
            	}
        }

    // A unit test to verify that upon deployment, the constructor sets the lastUpkeepTime to the current block's timestamp.
    function test_constructor() public {
			upkeep = new Upkeep(pools, exchangeConfig, poolsConfig, daoConfig, saltRewards, emissions, dao);

        assertEq(block.timestamp, upkeep.lastUpkeepTimeEmissions(), "lastUpkeepTimeEmissions was not set correctly in constructor");
        assertEq(block.timestamp, upkeep.lastUpkeepTimeRewardsEmitters(), "lastUpkeepTimeRewardsEmitters was not set correctly in constructor");
    }


    // A unit test to verify that step1() functions correctly
	// 1. Withdraws existing WETH arbitrage profits from the Pools contract and rewards the caller of performUpkeep() with default 5% of the withdrawn amount.
    function testSuccessStep1() public
    	{
    	// Mimic depositing arbitrage profits
    	vm.prank(DEPLOYER);
    	weth.transfer(address(dao), 100 ether);

		vm.startPrank(address(dao));
		weth.approve(address(pools), 100 ether );
		pools.deposit( weth, 100 ether);
		vm.stopPrank();

		assertEq( weth.balanceOf(alice), 0 );

        vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step1(alice);

    	assertEq( weth.balanceOf(alice), 5 ether );
    	}


	function _setupLiquidity() internal
		{
		vm.prank(address(teamVestingWallet));
		salt.transfer(DEPLOYER, 100000 ether );

		vm.startPrank(DEPLOYER);
		weth.approve( address(liquidity), 300000 ether);
		usdc.approve( address(liquidity), 100000 ether);
		salt.approve( address(liquidity), 100000 ether);

		liquidity.depositLiquidityAndIncreaseShare(weth, usdc, 100000 ether, 100000 * 10**6, 0, 0, 0, block.timestamp, false);
		liquidity.depositLiquidityAndIncreaseShare(weth, salt, 100000 ether, 100000 ether, 0, 0, 0, block.timestamp, false);

		vm.stopPrank();
		}


    // A unit test to verify that step2() functions correctly
	// 2. Convert a default 20% of the remaining WETH to SALT/USDC Protocol Owned Liquidity.
    function testSuccessStep2() public
    	{
    	_setupLiquidity();

    	// Mimic depositing arbitrage profits
    	vm.prank(DEPLOYER);
    	weth.transfer(address(dao), 100 ether);

		vm.startPrank(address(dao));
		weth.approve(address(pools), 100 ether );
		pools.deposit( weth, 100 ether);
		vm.stopPrank();

		(uint256 reservesA, uint256 reservesB) = pools.getPoolReserves(salt, usdc);
		assertEq( reservesA, 0);
		assertEq( reservesB, 0);

        vm.startPrank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step1(alice);
    	ITestUpkeep(address(upkeep)).step2();
    	vm.stopPrank();

		// Check that 20% of the remaining WETH (20% of 95 ether) has been converted to SALT/USDC
		(reservesA, reservesB) = pools.getPoolReserves(salt, usdc);
		assertEq( reservesA, 9499097585729355711 ); // Close to 9.5
		assertEq( reservesB, 9499097 ); // Close to 9.5

		uint256 daoLiquidity = liquidity.userShareForPool(address(dao), PoolUtils._poolID(salt, usdc));
		assertEq( daoLiquidity, 9499097585738854808 ); // Close to 9.5
    	}


    // A unit test to verify that step3() functions correctly
	// 3. Convert remaining WETH to SALT and sends it to SaltRewards.
    function testSuccessStep3() public
    	{
    	_setupLiquidity();

    	// Mimic depositing arbitrage profits
    	vm.prank(DEPLOYER);
    	weth.transfer(address(dao), 100 ether);

		vm.startPrank(address(dao));
		weth.approve(address(pools), 100 ether );
		pools.deposit( weth, 100 ether);
		vm.stopPrank();

		assertEq( salt.balanceOf(address(saltRewards)), 0 );

        vm.startPrank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step1(alice);
    	ITestUpkeep(address(upkeep)).step2();
    	ITestUpkeep(address(upkeep)).step3();
    	vm.stopPrank();

		// Check that about 76 ether of WETH has been converted to SALT and sent to SaltRewards.
		// SaltRewards would normally have sent 5% to SALT/USDC rewards, 47.5% to stakingRewardsEmitter and 47.5% to liquidityRewardsEmitter,
		// but as there is no WBTC/WETH liquidity yet then arbitrage isn't happening - so the rewards stay in the SaltRewards contract.
		assertEq( salt.balanceOf(address(saltRewards)), 75927862363514041184);
    	}


    // A unit test to verify that step4() functions correctly
	// 4. Sends SALT Emissions to the SaltRewards contract.
    function testSuccessStep4() public
    	{
 		assertEq( salt.balanceOf(address(saltRewards)), 0 );

        vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step4();

		// Emissions emit about 185715 SALT as 5 days have gone by since the deployment (delay for the bootstrap ballot to complete).
		// This is due to Emissions holding 52 million SALT and emitting at a default rate of .50% / week.

		assertEq( salt.balanceOf(address(saltRewards)), 185714715608465608465608);
	  	}


	function _swapToGenerateProfits() internal
		{
		vm.startPrank(DEPLOYER);
		pools.depositSwapWithdraw(salt, weth, 1 ether, 0, block.timestamp);
		pools.depositSwapWithdraw(salt, wbtc, 1 ether, 0, block.timestamp);
		pools.depositSwapWithdraw(weth, wbtc, 1 ether, 0, block.timestamp);
		vm.stopPrank();
		}


	function _generateArbitrageProfits( bool despositSaltUSDC ) internal
		{
		/// Pull some SALT from the daoVestingWallet
    	vm.prank(address(daoVestingWallet));
    	salt.transfer(DEPLOYER, 100000 ether);

		vm.startPrank(DEPLOYER);
		salt.approve(address(liquidity), type(uint256).max);
		wbtc.approve(address(liquidity), type(uint256).max);
		weth.approve(address(liquidity), type(uint256).max);

		if ( despositSaltUSDC )
			liquidity.depositLiquidityAndIncreaseShare( salt, weth, 1000 ether, 1000 ether, 0, 0, 0, block.timestamp, false );

		liquidity.depositLiquidityAndIncreaseShare( wbtc, salt, 1000 * 10**8, 1000 ether, 0, 0, 0, block.timestamp, false );
		liquidity.depositLiquidityAndIncreaseShare( wbtc, weth, 1000 * 10**8, 1000 ether, 0, 0, 0, block.timestamp, false );

		salt.approve(address(pools), type(uint256).max);
		wbtc.approve(address(pools), type(uint256).max);
		weth.approve(address(pools), type(uint256).max);
		vm.stopPrank();

		// Place some sample trades to create arbitrage profits
		_swapToGenerateProfits();
		}


    // A unit test to verify that step5() functions correctly
	// 5. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter.
    function testSuccessStep5() public
    	{
    	// Generate arbitrage profits for the SALT/WETH, SALT/WBTC and WBTC/WETH pools
		_generateArbitrageProfits(true);

    	// Send some SALT to SaltRewards
    	vm.prank(address(daoVestingWallet));
    	salt.transfer(address(saltRewards), 100 ether );


		// stakingRewardsEmitter and liquidityRewardsEmitter have initial bootstrapping rewards
		bytes32[] memory poolIDsB = new bytes32[](1);
		poolIDsB[0] = PoolUtils._poolID(salt, usdc);
		uint256 initialRewardsB = liquidityRewardsEmitter.pendingRewardsForPools(poolIDsB)[0];

		bytes32[] memory poolIDsA = new bytes32[](1);
		poolIDsA[0] = PoolUtils.STAKED_SALT;
		uint256 initialRewardsA = stakingRewardsEmitter.pendingRewardsForPools(poolIDsA)[0];

        vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step5();

		// Check that 10% of the rewards were sent directly to the SALT/USDC liquidityRewardsEmitter
		assertEq( liquidityRewardsEmitter.pendingRewardsForPools(poolIDsB)[0], initialRewardsB + 10 ether );

		// Check that 50% of the remaining 90% were sent to the stakingRewardsEmitter
		assertEq( stakingRewardsEmitter.pendingRewardsForPools(poolIDsA)[0], initialRewardsA + 45 ether );

		bytes32[] memory poolIDs = new bytes32[](4);
		poolIDs[0] = PoolUtils._poolID(salt,weth);
		poolIDs[1] = PoolUtils._poolID(salt,wbtc);
		poolIDs[2] = PoolUtils._poolID(wbtc,weth);
		poolIDs[3] = PoolUtils._poolID(salt,usdc);

		// Check that rewards were sent proportionally to the three pools involved in generating the test arbitrage
		assertEq( liquidityRewardsEmitter.pendingRewardsForPools(poolIDs)[0], initialRewardsB + uint256(45 ether) / 3 );
		assertEq( liquidityRewardsEmitter.pendingRewardsForPools(poolIDs)[1], initialRewardsB + uint256(45 ether) / 3 );
		assertEq( liquidityRewardsEmitter.pendingRewardsForPools(poolIDs)[2], initialRewardsB + uint256(45 ether) / 3 );

		// Check that the rewards were reset
		vm.prank(address(upkeep));
		uint256[] memory profitsForPools = IPoolStats(address(pools)).profitsForWhitelistedPools();
		for( uint256 i = 0; i < profitsForPools.length; i++ )
			assertEq( profitsForPools[i], 0 );
	  	}


    // A unit test to verify that step6() functions correctly
	// 6. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.
    function testSuccessStep6() public
    	{
    	assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3000000000000000000000005 );  // about 3 million
    	assertEq( salt.balanceOf(address(liquidityRewardsEmitter)), 4999999999999999999999995 ); // about 5 million

    	vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step6();


		bytes32[] memory poolIDsA = new bytes32[](1);
		poolIDsA[0] = PoolUtils.STAKED_SALT;

		// Check that the staking rewards were transferred to the staking contract (default 1% max of 3 million)
		assertEq( staking.totalRewardsForPools(poolIDsA)[0], uint256(3000000 ether) / 100 );

		bytes32[] memory poolIDs = new bytes32[](3);
		poolIDs[0] = PoolUtils._poolID(salt,weth);
		poolIDs[1] = PoolUtils._poolID(salt,wbtc);
		poolIDs[2] = PoolUtils._poolID(wbtc,weth);

		// Check if the rewards were transferred (default 1% max of 5 million / 9 pools) to the liquidity contract
		uint256[] memory rewards = liquidity.totalRewardsForPools(poolIDs);

		assertEq( rewards[0], uint256(5000000 ether) / numInitialPools / 100);
		assertEq( rewards[1], uint256(5000000 ether) / numInitialPools / 100);
		assertEq( rewards[2], uint256(5000000 ether) / numInitialPools / 100);
	  	}


    // A unit test to verify that step7() functions correctly
	// 7. Collect SALT rewards from the DAO's Protocol Owned Liquidity, send 10% to the initial dev team and burn a default 50% of the remaining - the rest stays in the DAO.
    function testSuccessStep7() public
    	{
    	// Form POL
    	vm.prank(address(daoVestingWallet));
		salt.transfer(address(dao), 100 ether);

		vm.prank(DEPLOYER);
		usdc.transfer(address(dao),  200 * 10**6);

		vm.startPrank(address(upkeep));
		dao.formPOL(salt, usdc, 100 ether, 100 * 10**6);
		vm.stopPrank();

		// Mimic reward emission.
		AddedReward[] memory addedRewards = new AddedReward[](1);
		addedRewards[0] = AddedReward( PoolUtils._poolID(salt, usdc), 200 ether );

    	vm.startPrank(address(teamVestingWallet));
    	salt.approve(address(liquidity), type(uint256).max);
    	liquidity.addSALTRewards(addedRewards);
    	vm.stopPrank();

		// Initial conditions
		assertEq( salt.balanceOf(teamWallet), 0);
		assertEq( salt.balanceOf(address(dao)), 0);

		uint256 initialSupply = salt.totalSupply();


    	vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step7();


		// Check teamWallet transfer
		// 10% of the 200 rewards
		assertEq( salt.balanceOf(teamWallet), 20 ether);

		// Check the amount burned
		// 50% of the remaining 180
		uint256 amountBurned = initialSupply - salt.totalSupply();
		uint256 expectedAmountBurned = 180 ether * 50 / 100;
		assertEq( amountBurned, expectedAmountBurned );

		// Check that the remaining SALT stays in the DAO contract
		assertEq( salt.balanceOf(address(dao)), 180 ether - expectedAmountBurned );
	  	}


    // A unit test to verify that step8() functions correctly
    // 8. Sends SALT from the DAO vesting wallet to the DAO (linear distribution over 10 years).
    function testSuccessStep8() public
    	{
    	assertEq( salt.balanceOf(address(daoVestingWallet)), 25 * 1000000 ether );

		// Warp to the start of when the daoVestingWallet starts to emit as there is an initial one week delay
		vm.warp( daoVestingWallet.start() );

		// 24 hours later
		vm.warp( block.timestamp + 24 hours );

		assertEq( salt.balanceOf(address(dao)), 0 );

    	vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step8();

		// Check that SALT has been sent to DAO.
    	assertEq( salt.balanceOf(address(dao)), uint256( 25 * 1000000 ether ) * 24 hours / (60 * 60 * 24 * 365 * 10) );
    	}


    // A unit test to verify that step8() functions correctly after one year of delay
    // 8. Sends SALT from the DAO vesting wallet to the DAO (linear distribution over 10 years).
    function testSuccessStep8WithOneYearDelay() public
    	{
    	assertEq( salt.balanceOf(address(daoVestingWallet)), 25 * 1000000 ether );

		// Warp to the start of when the daoVestingWallet starts to emit as there is an initial one week delay
		vm.warp( daoVestingWallet.start() );

		// One year later
		vm.warp( block.timestamp + 365 days );

		assertEq( salt.balanceOf(address(dao)), 0 );

    	vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step8();

		// Check that SALT has been sent to DAO.
    	assertEq( salt.balanceOf(address(dao)), uint256( 25 * 1000000 ether ) * 24 hours * 365 / (60 * 60 * 24 * 365 * 10) );
    	}


    // A unit test to verify that step9() functions correctly
	// 9. Sends SALT from the team vesting wallet to the team (linear distribution over 10 years).
    function testSuccessStep9() public
    	{
    	assertEq( salt.balanceOf(address(teamVestingWallet)), 10 * 1000000 ether );

		// Warp to the start of when the teamVestingWallet starts to emit as there is an initial one week delay
		vm.warp( teamVestingWallet.start() );

		// 24 hours later
		vm.warp( block.timestamp + 24 hours );

		assertEq( salt.balanceOf(teamWallet), 0 );

		// Step 16. Send SALT from the team vesting wallet to the team (linear distribution over 10 years).
    	vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step9();

		// Check that SALT has been sent to DAO.
    	assertEq( salt.balanceOf(teamWallet), uint256( 10 * 1000000 ether ) * 24 hours / (60 * 60 * 24 * 365 * 10) );
    	}


	// A unit test to verify all expected outcomes of a performUpkeep call
	function testComprehensivePerformUpkeep() public
		{
		_setupLiquidity();
		_generateArbitrageProfits(false);

    	// Mimic arbitrage profits deposited as WETH for the DAO
    	vm.prank(DEPLOYER);
    	weth.transfer(address(dao), 100 ether);

    	vm.startPrank(address(dao));
    	weth.approve(address(pools), 100 ether);
    	pools.deposit(weth, 100 ether);
    	vm.stopPrank();

		assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3000000000000000000000005 );
		assertEq( salt.balanceOf(address(staking)), 0 );

		assertEq( upkeep.currentRewardsForCallingPerformUpkeep(), 5000049714925620913 );

		// === Perform upkeep ===
		address upkeepCaller = address(0x9999);

		vm.prank(upkeepCaller);
		upkeep.performUpkeep();
		// ==================


		// Check Step 1. Withdraw existing WETH arbitrage profits from the Pools contract and reward the caller of performUpkeep() with default 5% of the withdrawn amount.
		// From the directly added 100 ether + arbitrage profits
    	assertEq( weth.balanceOf(upkeepCaller), 5000049714925620913 );


		// Check Step 2. Convert a default 20% of the remaining WETH to SALT/USDC Protocol Owned Liquidity.

		// Check that 20% of the remaining WETH (20% of 95 ether) has been converted to SALT/USDC POL
		(uint256 reservesA, uint256 reservesB) = pools.getPoolReserves(salt, usdc);

		// SALT and USDC for testing are paired with WETH 1:1
		assertEq( reservesA, 9499381149785288726 ); // Close to 9.5 SALT
		assertEq( reservesB, 9499192 ); // Close to 9.5 USDC

		uint256 daoLiquidity = liquidity.userShareForPool(address(dao), PoolUtils._poolID(salt, usdc));
		assertEq( daoLiquidity, 9499381149794787918 );


		// Check Step 3. Convert remaining WETH to SALT and sends it to SaltRewards.
		// Check Step 4. Send SALT Emissions to the SaltRewards contract.
		// Check Step 5. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter.
		// Check Step 6. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.

		// Check that about 72.2 ether of WETH has been converted to SALT and sent to SaltRewards.
		// Emissions also emit about 185715 SALT as 5 days have gone by since the deployment (delay for the bootstrap ballot to complete).
		// This is due to Emissions holding 52 million SALT and emitting at a default rate of .50% / week.

		// As there were profits, SaltRewards distributed the 185715 ether + 72.2 ether rewards
		// 10% to SALT/USDC rewards, 45% to stakingRewardsEmitter and 45% to liquidityRewardsEmitter,
		assertEq( salt.balanceOf(address(saltRewards)), 0 ); // should be basically empty now

		// Additionally stakingRewardsEmitter started with 3 million bootstrapping rewards.
		// liquidityRewardsEmitter started with 5 million bootstrapping rewards, divided evenly amongst the initial pools.

		// Determine that rewards were sent correctly by the stakingRewardsEmitter and liquidityRewardsEmitter
		bytes32[] memory poolIDsA = new bytes32[](1);
		poolIDsA[0] = PoolUtils.STAKED_SALT;

		// Check that the staking rewards were transferred to the staking contract:
		// 1% max of (3 million bootstrapping in the stakingRewardsEmitter + 45% of 185786 ether sent from saltRewards)
		// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
//		uint256 expectedStakingRewardsFromBootstrapping = uint256(3000000 ether) / 100;
//    	uint256 expectedStakingRewardsFromArbitrageProfits = uint( 185786 ether * 45 ) / 100 / 100;
		assertEq( staking.totalRewardsForPools(poolIDsA)[0], 30836057906135699563712  );

		bytes32[] memory poolIDs = new bytes32[](4);
		poolIDs[0] = PoolUtils._poolID(salt,weth);
		poolIDs[1] = PoolUtils._poolID(salt,wbtc);
		poolIDs[2] = PoolUtils._poolID(wbtc,weth);
		poolIDs[3] = PoolUtils._poolID(salt,usdc);

		// Check if the rewards were transferred to the liquidity contract:
		// 1% max of ( 5 million / numInitialPools + 45% of 185786 ether sent from saltRewards).
		// SALT/USDC should received an additional 1% of 10% of 47.185786.
		// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
		uint256[] memory rewards = liquidity.totalRewardsForPools(poolIDs);

		// Expected for all pools
//		uint256 expectedLiquidityRewardsFromBootstrapping = uint256(5000000 ether) / numInitialPools / 100;

		// Expected for WBTC/WETH, SALT/WETH and SALT/WTBC
//       	uint256 expectedLiquidityRewardsFromArbitrageProfits = uint( 185786 ether * 45 ) / 100 / 100 / 3;

		// Expected for SALT/USDC
//       	uint256 expectedAdditionalForSaltUSDC = ( 185786 ether * 10 ) / 100 / 100;

		assertEq( rewards[0], 5834241524267455410126);
		assertEq( rewards[1], 5834241524267455410126);
		assertEq( rewards[2], 5834241524267455410126);
		assertEq( rewards[3], 5741346201363488791936 );


		// Check Step 7. Collect SALT rewards from the DAO's Protocol Owned Liquidity: send 10% to the initial dev team and burn a default 50% of the remaining - the rest stays in the DAO.
		// Check Step 8. Sends SALT from the DAO vesting wallet to the DAO (linear distribution over 10 years).
		// Check Step 9. Sends SALT from the team vesting wallet to the team (linear distribution over 10 years).

		// The DAO currently has all of the SALT/USDC liquidity - so it will claim all of the above calculated rewards for the pool.
		uint256 polRewards = rewards[3];

		// 10% of the POL Rewards for the team wallet
		// The teamVestingWallet contains 10 million SALT and vests over a 10 year period.
		// 100k SALT were removed from it in _setupLiquidity() - so it emits about 13561 in the first 5 days
		assertEq( salt.balanceOf(teamWallet), polRewards / 10 + 13561675228310502283105 );

		// 50% of the remaining rewards are burned
//		uint256 halfOfRemaining = ( polRewards * 45 ) / 100;
		assertEq( salt.totalBurned(), 2583605790613569956371 );

		// Other 50% should stay in the DAO
		// The daoVestingWallet contains 25 million SALT and vests over a 10 year period.
		// 100k SALT were removed from it in _generateArbitrageProfits() - so it emits about 34110 in the first 5 days
		assertEq( salt.balanceOf(address(dao)), 36693273789091499941151 );
		}



	function _secondPerformUpkeep() internal
		{
		// Five minute delay before the next performUpkeep
		vm.warp( block.timestamp + 5 minutes );

		_swapToGenerateProfits();

    	// Mimic arbitrage profits deposited as WETH for the DAO
    	vm.prank(DEPLOYER);
    	weth.transfer(address(dao), 100 ether);

    	vm.startPrank(address(dao));
    	weth.approve(address(pools), 100 ether);
    	pools.deposit(weth, 100 ether);
    	vm.stopPrank();

		// === Perform upkeep ===
		address upkeepCaller = address(0x9999);

		vm.prank(upkeepCaller);
		upkeep.performUpkeep();
		// ==================


		// Check Step 1. Withdraw existing WETH arbitrage profits from the Pools contract and reward the caller of performUpkeep() with default 5% of the withdrawn amount.
		// From the directly added 100 ether + arbitrage profits
    	assertEq( weth.balanceOf(upkeepCaller), 10000114027868444000 );


		// Check Step 2. Convert a default 20% of the remaining WETH to SALT/USDC Protocol Owned Liquidity.

		// Check that 20% of the remaining WETH (20% of 95 ether) has been converted to SALT/USDC
		(uint256 reservesA, uint256 reservesB) = pools.getPoolReserves(salt, usdc);
		assertEq( reservesA, 18982837084300280125 ); // Close to 19
		assertEq( reservesB, 18996601 ); // Close to 19

		uint256 daoLiquidity = liquidity.userShareForPool(address(dao), PoolUtils._poolID(salt, usdc));
		assertEq( daoLiquidity, 18989907293828063072 ); // Close to 19


		// Check Step 3. Convert remaining WETH to SALT and sends it to SaltRewards.
		// Check Step 4. Send SALT Emissions to the SaltRewards contract.
		// Check Step 5. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter.
		// Check Step 6. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.

		// Check that about 72.2 ether of WETH has been converted to SALT and sent to SaltRewards.
		// Emissions also emit about 185715 SALT as 5 days have gone by since the deployment (delay for the bootstrap ballot to complete).
		// This is due to Emissions holding 52 million SALT and emitting at a default rate of .50% / week.

		// As there were profits, SaltRewards distributed the 185715 ether + 72.2 ether rewards
		// 10% to SALT/USDC rewards, 45% to stakingRewardsEmitter and 45% to liquidityRewardsEmitter,
		assertEq( salt.balanceOf(address(saltRewards)), 2 ); // should be basically empty now

		// Additionally stakingRewardsEmitter started with 3 million bootstrapping rewards.
		// liquidityRewardsEmitter started with 5 million bootstrapping rewards, divided evenly amongst the initial pools.

		// Determine that rewards were sent correctly by the stakingRewardsEmitter and liquidityRewardsEmitter
		bytes32[] memory poolIDsA = new bytes32[](1);
		poolIDsA[0] = PoolUtils.STAKED_SALT;

		// Check that the staking rewards were transferred to the staking contract:
		// 1% max of (3 million bootstrapping in the stakingRewardsEmitter + 45% of 185786 ether sent from saltRewards)
		// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
		assertEq( staking.totalRewardsForPools(poolIDsA)[0], 30942060047541364171204  );

		bytes32[] memory poolIDs = new bytes32[](4);
		poolIDs[0] = PoolUtils._poolID(salt,weth);
		poolIDs[1] = PoolUtils._poolID(salt,wbtc);
		poolIDs[2] = PoolUtils._poolID(wbtc,weth);
		poolIDs[3] = PoolUtils._poolID(salt,usdc);

		// Check if the rewards were transferred to the liquidity contract:
		// 1% max of ( 5 million / numInitialPools + 45% of 185786 ether sent from saltRewards).
		// SALT/USDC should received an additional 1% of 10% of 47.185786.
		// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
		uint256[] memory rewards = liquidity.totalRewardsForPools(poolIDs);

		assertEq( rewards[0], 5854297793624899168178);
		assertEq( rewards[1], 5854297793624899168178);
		assertEq( rewards[2], 5854297793624899168178);
		assertEq( rewards[3], 11497077098578557782888);


		// Check Step 7. Collect SALT rewards from the DAO's Protocol Owned Liquidity: send 10% to the initial dev team and burn a default 50% of the remaining - the rest stays in the DAO.
		// Check Step 8. Sends SALT from the DAO vesting wallet to the DAO (linear distribution over 10 years).
		// Check Step 9. Sends SALT from the team vesting wallet to the team (linear distribution over 10 years).

		// The DAO currently has all of the SALT/USDC liquidity - so it will claim all of the above calculated rewards for the pool.
//		uint256 polRewards = rewards[3];

		// 10% of the POL Rewards for the team wallet
		// The teamVestingWallet contains 10 million SALT and vests over a 10 year period.
		// 100k SALT were removed from it in _setupLiquidity() - so it emits about 13561 in the first 5 days
		assertEq( salt.balanceOf(teamWallet), 14147201315363932902433 );

		// 50% of the remaining rewards are burned
		assertEq( salt.totalBurned(), 2592487254754136417120 );

		// Other 50% should stay in the DAO
		// The daoVestingWallet contains 25 million SALT and vests over a 10 year period.
		// 100k SALT were removed from it in _generateArbitrageProfits() - so it emits about 34110 in the first 5 days
		assertEq( salt.balanceOf(address(dao)), 36725842467843938548019 );
		}


	// A unit test to verify all expected outcomes of a performUpkeep call followed by another after a five minute delay
	function testDoublePerformUpkeep() public
		{
		_setupLiquidity();
		_generateArbitrageProfits(false);

    	// Mimic arbitrage profits deposited as WETH for the DAO
    	vm.prank(DEPLOYER);
    	weth.transfer(address(dao), 100 ether);

    	vm.startPrank(address(dao));
    	weth.approve(address(pools), 100 ether);
    	pools.deposit(weth, 100 ether);
    	vm.stopPrank();

		// === Perform upkeep ===
		address upkeepCaller = address(0x9999);

		vm.prank(upkeepCaller);
		upkeep.performUpkeep();
		// ==================

		_secondPerformUpkeep();
		}
	}
