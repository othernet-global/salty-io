// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "../dev/Deployment.sol";
import "./ITestUpkeep.sol";


contract TestUpkeep2 is Deployment
	{
    address public constant alice = address(0x1111);


	constructor()
		{
		initializeContracts();

		finalizeBootstrap();

		grantAccessAlice();
		grantAccessBob();
		grantAccessCharlie();
		grantAccessDeployer();
		grantAccessDefault();
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
        ITestUpkeep(address(upkeep)).step1();
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
			upkeep = new Upkeep(pools, exchangeConfig, poolsConfig, daoConfig, stableConfig, priceAggregator, saltRewards, collateralAndLiquidity, emissions, dao);

        assertEq(block.timestamp, upkeep.lastUpkeepTimeEmissions(), "lastUpkeepTimeEmissions was not set correctly in constructor");
        assertEq(block.timestamp, upkeep.lastUpkeepTimeRewardsEmitters(), "lastUpkeepTimeRewardsEmitters was not set correctly in constructor");
    }


    // A unit test to verify that step1() functions correctly
	// 1. Swaps tokens previously sent to the Liquidizer contract for USDS and burns specified amounts of USDS.
    function testSuccessStep1() public
    	{
    	vm.startPrank( address(collateralAndLiquidity));
    	usds.mintTo( address(liquidizer), 30 ether );
    	liquidizer.incrementBurnableUSDS( 20 ether );
    	vm.stopPrank();

		vm.prank(address(collateralAndLiquidity));
		usds.mintTo(DEPLOYER, 100000000 ether );

		vm.startPrank(DEPLOYER);
		wbtc.approve(address(collateralAndLiquidity), type(uint256).max);
		weth.approve(address(collateralAndLiquidity), type(uint256).max);
		dai.approve(address(collateralAndLiquidity), type(uint256).max);
		usds.approve(address(collateralAndLiquidity), type(uint256).max);

		collateralAndLiquidity.depositLiquidityAndIncreaseShare(wbtc, usds, 1000 * 10**8, 30000 * 1000 ether, 0, block.timestamp, false );
		collateralAndLiquidity.depositLiquidityAndIncreaseShare(weth, usds, 1000 ether, 3000 * 1000 ether, 0, block.timestamp, false );
		collateralAndLiquidity.depositLiquidityAndIncreaseShare(dai, usds, 100000 ether, 100000 ether, 0, block.timestamp, false );

        uint256 initialBalance = usds.balanceOf(address(usds));
        assertEq(initialBalance, 0, "Initial USDS balance should be 0");

        // Simulate external conditions - deposit WBTC/WETH/DAI into the Liquidizer contract
        uint256 wbtcAmount = 1 * 10**8;
        uint256 wethAmount = 1 ether;
        uint256 daiAmount = 1000 ether;

        // Transfer tokens to Liquidizer for swapping
        wbtc.transfer(address(liquidizer), wbtcAmount);
        weth.transfer(address(liquidizer), wethAmount);
        dai.transfer(address(liquidizer), daiAmount);

        // Check that the Liquidizer received the tokens
        assertEq(wbtc.balanceOf(address(liquidizer)), wbtcAmount, "Liquidizer should hold WBTC");
        assertEq(weth.balanceOf(address(liquidizer)), wethAmount, "Liquidizer should hold WETH");
        assertEq(dai.balanceOf(address(liquidizer)), daiAmount, "Liquidizer should hold DAI");

		uint256 supply = usds.totalSupply();
		vm.stopPrank();

        // Perform the upkeep call to swap tokens to USDS
        vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step1();

		assertEq( supply - usds.totalSupply(), 20 ether );

        // Check that all WBTC/WETH/DAI has been swapped to USDS (balances are zero and USDS balance increased)
        assertEq(wbtc.balanceOf(address(liquidizer)), 0, "WBTC balance after upkeep should be 0");
        assertEq(weth.balanceOf(address(liquidizer)), 0, "WETH balance after upkeep should be 0");
        assertEq(dai.balanceOf(address(liquidizer)), 0, "DAI balance after upkeep should be 0");

        uint256 newUsdsBalance = usds.balanceOf(address(liquidizer));
        assertEq(newUsdsBalance, 33957131976933957131976 + 30 ether - 20 ether, "USDS balance should have increased");
    	}


    // A unit test to verify that step2() functions correctly
	// 2. Withdraws existing WETH arbitrage profits from the Pools contract and rewards the caller of performUpkeep() with default 5% of the withdrawn amount.
    function testSuccessStep2() public
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
    	ITestUpkeep(address(upkeep)).step2(alice);

    	assertEq( weth.balanceOf(alice), 5 ether );
    	}


	function _setupLiquidity() internal
		{
		vm.prank(address(collateralAndLiquidity));
		usds.mintTo(DEPLOYER, 100000 ether );

		vm.prank(address(teamVestingWallet));
		salt.transfer(DEPLOYER, 100000 ether );

		vm.startPrank(DEPLOYER);
		weth.approve( address(collateralAndLiquidity), 300000 ether);
		usds.approve( address(collateralAndLiquidity), 100000 ether);
		dai.approve( address(collateralAndLiquidity), 100000 ether);
		salt.approve( address(collateralAndLiquidity), 100000 ether);

		collateralAndLiquidity.depositLiquidityAndIncreaseShare(weth, usds, 100000 ether, 100000 ether, 0, block.timestamp, false);
		collateralAndLiquidity.depositLiquidityAndIncreaseShare(weth, dai, 100000 ether, 100000 ether, 0, block.timestamp, false);
		collateralAndLiquidity.depositLiquidityAndIncreaseShare(weth, salt, 100000 ether, 100000 ether, 0, block.timestamp, false);

		vm.stopPrank();
		}


    // A unit test to verify that step3() functions correctly
	// 3. Convert a default 5% of the remaining WETH to USDS/DAI Protocol Owned Liquidity.
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

		(uint256 reservesA, uint256 reservesB) = pools.getPoolReserves(usds, dai);
		assertEq( reservesA, 0);
		assertEq( reservesB, 0);

        vm.startPrank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step2(alice);
    	ITestUpkeep(address(upkeep)).step3();
    	vm.stopPrank();

		// Check that 5% of the remaining WETH (5% of 95 ether) has been converted to USDS/DAI
		(reservesA, reservesB) = pools.getPoolReserves(usds, dai);
		assertEq( reservesA, 2374943595089616621 ); // Close to 2.375 ether
		assertEq( reservesB, 2374943595089616621 ); // Close to 2.375 ether

		uint256 daoLiquidity = collateralAndLiquidity.userShareForPool(address(dao), PoolUtils._poolID(usds, dai));
		assertEq( daoLiquidity, 4749887190179233242 ); // Close to 4.75 ether
    	}


    // A unit test to verify that step3() functions correctly
	// 4. Convert a default 20% of the remaining WETH to SALT/USDS Protocol Owned Liquidity.
    function testSuccessStep4() public
    	{
    	_setupLiquidity();

    	// Mimic depositing arbitrage profits
    	vm.prank(DEPLOYER);
    	weth.transfer(address(dao), 100 ether);

		vm.startPrank(address(dao));
		weth.approve(address(pools), 100 ether );
		pools.deposit( weth, 100 ether);
		vm.stopPrank();

		(uint256 reservesA, uint256 reservesB) = pools.getPoolReserves(salt, usds);
		assertEq( reservesA, 0);
		assertEq( reservesB, 0);

        vm.startPrank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step2(alice);
    	ITestUpkeep(address(upkeep)).step3();
    	ITestUpkeep(address(upkeep)).step4();
    	vm.stopPrank();

		// Check that 20% of the remaining WETH (20% of 90.25 ether) has been converted to SALT/USDS
		(reservesA, reservesB) = pools.getPoolReserves(salt, usds);
		assertEq( reservesA, 9024185567252555456 ); // Close to 9.025 ether
		assertEq( reservesB, 9023756953047895701 ); // Close to 9.025 ether - a little worse because some of the USDS reserve was also used for USDS/DAI POL

		uint256 daoLiquidity = collateralAndLiquidity.userShareForPool(address(dao), PoolUtils._poolID(salt, usds));
		assertEq( daoLiquidity, 18047942520300451157 ); // Close to 18.05 ether
    	}


    // A unit test to verify that step5() functions correctly
	// 5. Convert remaining WETH to SALT and sends it to SaltRewards.
    function testSuccessStep5() public
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
    	ITestUpkeep(address(upkeep)).step2(alice);
    	ITestUpkeep(address(upkeep)).step3();
    	ITestUpkeep(address(upkeep)).step4();
    	ITestUpkeep(address(upkeep)).step5();
    	vm.stopPrank();

		// Check that about 72.2 ether of WETH has been converted to SALT and sent to SaltRewards.
		// SaltRewards would normally have sent 5% to SALT/USDS rewards, 47.5% to stakingRewardsEmitter and 47.5% to liquidityRewardsEmitter,
		// but as there is no WBTC/WETH liquidity yet then arbitrage isn't happening - so the rewards stay in the SaltRewards contract.
		assertEq( salt.balanceOf(address(saltRewards)), 72134892971204582732);
    	}


    // A unit test to verify that step6() functions correctly
	// 6. Sends SALT Emissions to the SaltRewards contract.
    function testSuccessStep6() public
    	{
 		assertEq( salt.balanceOf(address(saltRewards)), 0 );

        vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step6();

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


	function _generateArbitrageProfits( bool despositSaltUSDS ) internal
		{
		/// Pull some SALT from the daoVestingWallet
    	vm.prank(address(daoVestingWallet));
    	salt.transfer(DEPLOYER, 100000 ether);

		// Mint some USDS
		vm.prank(address(collateralAndLiquidity));
		usds.mintTo(DEPLOYER, 1000 ether);

		vm.startPrank(DEPLOYER);
		salt.approve(address(collateralAndLiquidity), type(uint256).max);
		wbtc.approve(address(collateralAndLiquidity), type(uint256).max);
		weth.approve(address(collateralAndLiquidity), type(uint256).max);
		wbtc.approve(address(collateralAndLiquidity), type(uint256).max);
		weth.approve(address(collateralAndLiquidity), type(uint256).max);

		if ( despositSaltUSDS )
			collateralAndLiquidity.depositLiquidityAndIncreaseShare( salt, weth, 1000 ether, 1000 ether, 0, block.timestamp, false );

		collateralAndLiquidity.depositLiquidityAndIncreaseShare( wbtc, salt, 1000 * 10**8, 1000 ether, 0, block.timestamp, false );
		collateralAndLiquidity.depositCollateralAndIncreaseShare( 1000 * 10**8, 1000 ether, 0, block.timestamp, false );

		salt.approve(address(pools), type(uint256).max);
		wbtc.approve(address(pools), type(uint256).max);
		weth.approve(address(pools), type(uint256).max);
		vm.stopPrank();

		// Place some sample trades to create arbitrage profits
		_swapToGenerateProfits();
		}


    // A unit test to verify that step7() functions correctly
	// 7. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter.
    function testSuccessStep7() public
    	{
    	// Generate arbitrage profits for the SALT/WETH, SALT/WBTC and WBTC/WETH pools
		_generateArbitrageProfits(true);

    	// Send some SALT to SaltRewards
    	vm.prank(address(daoVestingWallet));
    	salt.transfer(address(saltRewards), 100 ether );


		// stakingRewardsEmitter and liquidityRewardsEmitter have initial bootstrapping rewards
		bytes32[] memory poolIDsB = new bytes32[](1);
		poolIDsB[0] = PoolUtils._poolID(salt, usds);
		uint256 initialRewardsB = liquidityRewardsEmitter.pendingRewardsForPools(poolIDsB)[0];

		bytes32[] memory poolIDsA = new bytes32[](1);
		poolIDsA[0] = PoolUtils.STAKED_SALT;
		uint256 initialRewardsA = stakingRewardsEmitter.pendingRewardsForPools(poolIDsA)[0];

        vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step7();

		// Check that 10% of the rewards were sent directly to the SALT/USDS liquidityRewardsEmitter
		assertEq( liquidityRewardsEmitter.pendingRewardsForPools(poolIDsB)[0], initialRewardsB + 10 ether );

		// Check that 50% of the remaining 90% were sent to the stakingRewardsEmitter
		assertEq( stakingRewardsEmitter.pendingRewardsForPools(poolIDsA)[0], initialRewardsA + 45 ether );

		bytes32[] memory poolIDs = new bytes32[](4);
		poolIDs[0] = PoolUtils._poolID(salt,weth);
		poolIDs[1] = PoolUtils._poolID(salt,wbtc);
		poolIDs[2] = PoolUtils._poolID(wbtc,weth);
		poolIDs[3] = PoolUtils._poolID(salt,usds);

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


    // A unit test to verify that step8() functions correctly
	// 8. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.
    function testSuccessStep8() public
    	{
    	assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3000000000000000000000005 );  // about 3 million
    	assertEq( salt.balanceOf(address(liquidityRewardsEmitter)), 4999999999999999999999995 ); // about 5 million

    	vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step8();


		bytes32[] memory poolIDsA = new bytes32[](1);
		poolIDsA[0] = PoolUtils.STAKED_SALT;

		// Check that the staking rewards were transferred to the staking contract (default 1% max of 3 million)
		assertEq( staking.totalRewardsForPools(poolIDsA)[0], uint256(3000000 ether) / 100 );

		bytes32[] memory poolIDs = new bytes32[](3);
		poolIDs[0] = PoolUtils._poolID(salt,weth);
		poolIDs[1] = PoolUtils._poolID(salt,wbtc);
		poolIDs[2] = PoolUtils._poolID(wbtc,weth);

		// Check if the rewards were transferred (default 1% max of 5 million / 9 pools) to the liquidity contract
		uint256[] memory rewards = collateralAndLiquidity.totalRewardsForPools(poolIDs);

		assertEq( rewards[0], uint256(5000000 ether) / 9 / 100);
		assertEq( rewards[1], uint256(5000000 ether) / 9 / 100);
		assertEq( rewards[2], uint256(5000000 ether) / 9 / 100);
	  	}


    // A unit test to verify that step9() functions correctly
	// 9. Collect SALT rewards from the DAO's Protocol Owned Liquidity, send 10% to the initial dev team and burn a default 50% of the remaining - the rest stays in the DAO.
    function testSuccessStep9() public
    	{
    	// Form POL
    	vm.prank(address(daoVestingWallet));
		salt.transfer(address(dao), 100 ether);

		vm.prank(address(collateralAndLiquidity));
		usds.mintTo(address(dao),  200 ether);

		vm.prank(DEPLOYER);
		dai.transfer(address(dao),  100 ether);

		vm.startPrank(address(upkeep));
		dao.formPOL(salt, usds, 100 ether, 100 ether);
		dao.formPOL(usds, dai, 100 ether, 100 ether);
		vm.stopPrank();

		// Mimic reward emission.
		AddedReward[] memory addedRewards = new AddedReward[](2);
		addedRewards[0] = AddedReward( PoolUtils._poolID(salt, usds), 100 ether );
		addedRewards[1] = AddedReward( PoolUtils._poolID(usds, dai), 100 ether );

    	vm.startPrank(address(teamVestingWallet));
    	salt.approve(address(collateralAndLiquidity), type(uint256).max);
    	collateralAndLiquidity.addSALTRewards(addedRewards);
    	vm.stopPrank();

		// Initial conditions
		assertEq( salt.balanceOf(teamWallet), 0);
		assertEq( salt.balanceOf(address(dao)), 0);

		uint256 initialSupply = salt.totalSupply();


    	vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step9();


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


    // A unit test to verify that step10() functions correctly
    // 10. Sends SALT from the DAO vesting wallet to the DAO (linear distribution over 10 years).
    function testSuccessStep10() public
    	{
    	assertEq( salt.balanceOf(address(daoVestingWallet)), 25 * 1000000 ether );

		// Warp to the start of when the daoVestingWallet starts to emit as there is an initial one week delay
		vm.warp( daoVestingWallet.start() );

		// 24 hours later
		vm.warp( block.timestamp + 24 hours );

		assertEq( salt.balanceOf(address(dao)), 0 );

    	vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step10();

		// Check that SALT has been sent to DAO.
    	assertEq( salt.balanceOf(address(dao)), uint256( 25 * 1000000 ether ) * 24 hours / (60 * 60 * 24 * 365 * 10) );
    	}


    // A unit test to verify that step10() functions correctly after one year of delay
    // 10. Sends SALT from the DAO vesting wallet to the DAO (linear distribution over 10 years).
    function testSuccessStep10WithOneYearDelay() public
    	{
    	assertEq( salt.balanceOf(address(daoVestingWallet)), 25 * 1000000 ether );

		// Warp to the start of when the daoVestingWallet starts to emit as there is an initial one week delay
		vm.warp( daoVestingWallet.start() );

		// One year later
		vm.warp( block.timestamp + 365 days );

		assertEq( salt.balanceOf(address(dao)), 0 );

    	vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step10();

		// Check that SALT has been sent to DAO.
    	assertEq( salt.balanceOf(address(dao)), uint256( 25 * 1000000 ether ) * 24 hours * 365 / (60 * 60 * 24 * 365 * 10) );
    	}


    // A unit test to verify that step11() functions correctly
	// 11. Sends SALT from the team vesting wallet to the team (linear distribution over 10 years).
    function testSuccessStep11() public
    	{
    	assertEq( salt.balanceOf(address(teamVestingWallet)), 10 * 1000000 ether );

		// Warp to the start of when the teamVestingWallet starts to emit as there is an initial one week delay
		vm.warp( teamVestingWallet.start() );

		// 24 hours later
		vm.warp( block.timestamp + 24 hours );

		assertEq( salt.balanceOf(teamWallet), 0 );

		// Step 16. Send SALT from the team vesting wallet to the team (linear distribution over 10 years).
    	vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step11();

		// Check that SALT has been sent to DAO.
    	assertEq( salt.balanceOf(teamWallet), uint256( 10 * 1000000 ether ) * 24 hours / (60 * 60 * 24 * 365 * 10) );
    	}


	// A unit test to verify all expected outcomes of a performUpkeep call
	function testComprehensivePerformUpkeep() public
		{
		_setupLiquidity();
		_generateArbitrageProfits(false);

    	// Dummy WBTC and WETH to send to Liquidizer
    	vm.prank(DEPLOYER);
    	weth.transfer( address(liquidizer), 50 ether );

    	// Indicate that some USDS should be burned
    	vm.prank( address(collateralAndLiquidity));
    	liquidizer.incrementBurnableUSDS( 40 ether);

    	// Mimic arbitrage profits deposited as WETH for the DAO
    	vm.prank(DEPLOYER);
    	weth.transfer(address(dao), 100 ether);

    	vm.startPrank(address(dao));
    	weth.approve(address(pools), 100 ether);
    	pools.deposit(weth, 100 ether);
    	vm.stopPrank();

		assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3000000000000000000000005 );
		assertEq( salt.balanceOf(address(staking)), 0 );

		assertEq( upkeep.currentRewardsForCallingPerformUpkeep(), 5000049050423279843 );

		uint256 usdsSupply0 = usds.totalSupply();

		// === Perform upkeep ===
		address upkeepCaller = address(0x9999);

		vm.prank(upkeepCaller);
		upkeep.performUpkeep();
		// ==================


		// Check 1. Swap tokens previously sent to the Liquidizer contract for USDS and burn specified amounts of USDS.
		assertEq( usds.balanceOf( address(liquidizer) ), 9975012493753123438 ); // 50 WETH converted to about 50 USDS and then 40 burned

		// 40 ether should have been burnt
		assertEq( usdsSupply0 - usds.totalSupply(), 40 ether );


		// Check Step 2. Withdraw existing WETH arbitrage profits from the Pools contract and reward the caller of performUpkeep() with default 5% of the withdrawn amount.
		// From the directly added 100 ether + arbitrage profits
    	assertEq( weth.balanceOf(upkeepCaller), 5000049050423279843 );


		// Check Step 3. Convert a default 5% of the remaining WETH to USDS/DAI Protocol Owned Liquidity.

		// Check that 5% of the remaining WETH (5% of 95 ether) has been converted to USDS/DAI
		(uint256 reservesA, uint256 reservesB) = pools.getPoolReserves(usds, dai);
		assertEq( reservesA, 2372593734239580153 ); // Close to 2.375 ether
		assertEq( reservesB, 2374966892934008368 ); // Close to 2.375 ether

		uint256 daoLiquidity = collateralAndLiquidity.userShareForPool(address(dao), PoolUtils._poolID(usds, dai));
		assertEq( daoLiquidity, 4747560627173588521 ); // Close to 4.75 ether


		// Check Step 4. Convert a default 20% of the remaining WETH to SALT/USDS Protocol Owned Liquidity.

		// Check that 20% of the remaining WETH (20% of 90.25 ether) has been converted to SALT/USDS
		(reservesA, reservesB) = pools.getPoolReserves(salt, usds);
		assertEq( reservesA, 9024453775958744234 ); // Close to 9.025 ether
		assertEq( reservesB, 9014829003115815807 ); // Close to 9.025 ether - a little worse because some of the USDS reserve was also used for USDS/DAI POL

		daoLiquidity = collateralAndLiquidity.userShareForPool(address(dao), PoolUtils._poolID(salt, usds));
		assertEq( daoLiquidity, 18039282779074560041 ); // Close to 18.05 ether


		// Check Step 5. Convert remaining WETH to SALT and sends it to SaltRewards.
		// Check Step 6. Send SALT Emissions to the SaltRewards contract.
		// Check Step 7. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter.
		// Check Step 8. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.

		// Check that about 72.2 ether of WETH has been converted to SALT and sent to SaltRewards.
		// Emissions also emit about 185715 SALT as 5 days have gone by since the deployment (delay for the bootstrap ballot to complete).
		// This is due to Emissions holding 52 million SALT and emitting at a default rate of .50% / week.

		// As there were profits, SaltRewards distributed the 185715 ether + 72.2 ether rewards
		// 10% to SALT/USDS rewards, 45% to stakingRewardsEmitter and 45% to liquidityRewardsEmitter,
		assertEq( salt.balanceOf(address(saltRewards)), 2 ); // should be basically empty now

		// Additionally stakingRewardsEmitter started with 3 million bootstrapping rewards.
		// liquidityRewardsEmitter started with 5 millions bootstrapping rewards, divided evenly amongst the 9 initial pools.

		// Determine that rewards were sent correctly by the stakingRewardsEmitter and liquidityRewardsEmitter
		bytes32[] memory poolIDsA = new bytes32[](1);
		poolIDsA[0] = PoolUtils.STAKED_SALT;

		// Check that the staking rewards were transferred to the staking contract:
		// 1% max of (3 million bootstrapping in the stakingRewardsEmitter + 45% of 185786 ether sent from saltRewards)
		// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
		uint256 expectedStakingRewardsFromBootstrapping = uint256(3000000 ether) / 100;
    	uint256 expectedStakingRewardsFromArbitrageProfits = uint( 185786 ether * 45 ) / 100 / 100;
		assertEq( staking.totalRewardsForPools(poolIDsA)[0], expectedStakingRewardsFromBootstrapping + expectedStakingRewardsFromArbitrageProfits + 3836898935172364  );

		bytes32[] memory poolIDs = new bytes32[](5);
		poolIDs[0] = PoolUtils._poolID(salt,weth);
		poolIDs[1] = PoolUtils._poolID(salt,wbtc);
		poolIDs[2] = PoolUtils._poolID(wbtc,weth);
		poolIDs[3] = PoolUtils._poolID(salt,usds);
		poolIDs[4] = PoolUtils._poolID(usds,dai);

		// Check if the rewards were transferred to the liquidity contract:
		// 1% max of ( 5 million / 9 pools + 45% of 185786 ether sent from saltRewards).
		// SALT/USDS should received an additional 1% of 10% of 47.185786.
		// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
		uint256[] memory rewards = collateralAndLiquidity.totalRewardsForPools(poolIDs);

		// Expected for all pools
		uint256 expectedLiquidityRewardsFromBootstrapping = uint256(5000000 ether) / 9 / 100;

		// Expected for WBTC/WETH, SALT/WETH and SALT/WTBC
       	uint256 expectedLiquidityRewardsFromArbitrageProfits = uint( 185786 ether * 45 ) / 100 / 100 / 3;

		// Expected for SALT/USDS
       	uint256 expectedAdditionalForSaltUSDS = ( 185786 ether * 10 ) / 100 / 100;

		assertEq( rewards[0], expectedLiquidityRewardsFromBootstrapping + expectedLiquidityRewardsFromArbitrageProfits + 1278966311724122);
		assertEq( rewards[1], expectedLiquidityRewardsFromBootstrapping + expectedLiquidityRewardsFromArbitrageProfits + 1278966311724122);
		assertEq( rewards[2], expectedLiquidityRewardsFromBootstrapping + expectedLiquidityRewardsFromArbitrageProfits + 1278966311724122);
		assertEq( rewards[3], expectedLiquidityRewardsFromBootstrapping + expectedAdditionalForSaltUSDS + 852644207816081);
		assertEq( rewards[4], expectedLiquidityRewardsFromBootstrapping);


		// Check Step 9. Collect SALT rewards from the DAO's Protocol Owned Liquidity: send 10% to the initial dev team and burn a default 50% of the remaining - the rest stays in the DAO.
		// Check Step 10. Sends SALT from the DAO vesting wallet to the DAO (linear distribution over 10 years).
		// Check Step 11. Sends SALT from the team vesting wallet to the team (linear distribution over 10 years).

		// The DAO currently has all of the SALT/USDS and USDS/DAI liquidity - so it will claim all of the above calculated rewards for those two pools.
		uint256 polRewards = rewards[3] + rewards[4];

		// 10% of the POL Rewards for the team wallet
		// The teamVestingWallet contains 10 million SALT and vests over a 10 year period.
		// 100k SALT were removed from it in _setupLiquidity() - so it emits about 13561 in the first 5 days
		assertEq( salt.balanceOf(teamWallet), polRewards / 10 + 13561675228310502283105 );

		// 50% of the remaining rewards are burned
		uint256 halfOfRemaining = ( polRewards * 45 ) / 100;
		assertEq( salt.totalBurned(), halfOfRemaining + 1 );

		// Other 50% should stay in the DAO
		// The daoVestingWallet contains 25 million SALT and vests over a 10 year period.
		// 100k SALT were removed from it in _generateArbitrageProfits() - so it emits about 34110 in the first 5 days
		assertEq( salt.balanceOf(address(dao)), halfOfRemaining + 1 + 34109667998477929984779 );
		}



	function _secondPerformUpkeep() internal
		{

		// Five minute delay before the next performUpkeep
		vm.warp( block.timestamp + 5 minutes );

		_swapToGenerateProfits();

    	// Dummy WBTC and WETH to send to Liquidizer
    	vm.prank(DEPLOYER);
    	weth.transfer( address(liquidizer), 50 ether );

    	// Indicate that some USDS should be burned
    	vm.prank( address(collateralAndLiquidity));
    	liquidizer.incrementBurnableUSDS( 40 ether);

    	// Mimic arbitrage profits deposited as WETH for the DAO
    	vm.prank(DEPLOYER);
    	weth.transfer(address(dao), 100 ether);

    	vm.startPrank(address(dao));
    	weth.approve(address(pools), 100 ether);
    	pools.deposit(weth, 100 ether);
    	vm.stopPrank();

		uint256 usdsSupply0 = usds.totalSupply();

		// === Perform upkeep ===
		address upkeepCaller = address(0x9999);

		vm.prank(upkeepCaller);
		upkeep.performUpkeep();
		// ==================


		// Check 1. Swap tokens previously sent to the Liquidizer contract for USDS and burn specified amounts of USDS.
		assertEq( usds.balanceOf( address(liquidizer) ), 19888727341975663698 ); // 10 USDS originally, 50 WETH converted to about 50 USDS and then 40 burned

		// 40 ether should have been burnt
		assertEq( usdsSupply0 - usds.totalSupply(), 40 ether );


		// Check Step 2. Withdraw existing WETH arbitrage profits from the Pools contract and reward the caller of performUpkeep() with default 5% of the withdrawn amount.
		// From the directly added 100 ether + arbitrage profits
		// earlier profits plus these profits
    	assertEq( weth.balanceOf(upkeepCaller), 10000115834736977295 );


		// Check Step 3. Convert a default 5% of the remaining WETH to USDS/DAI Protocol Owned Liquidity.

		// Check that 5% of the remaining WETH (5% of 95 ether) has been converted to USDS/DAI
		(uint256 reservesA, uint256 reservesB) = pools.getPoolReserves(usds, dai);
		assertEq( reservesA, 4742286491588025880 ); // Close to 2.375 ether * 2
		assertEq( reservesB, 4749829401990042295 ); // Close to 2.375 ether * 2

		uint256 daoLiquidity = collateralAndLiquidity.userShareForPool(address(dao), PoolUtils._poolID(usds, dai));
		assertEq( daoLiquidity, 9492114082483511517 ); // Close to 4.75 ether * 2


		// Check Step 4. Convert a default 20% of the remaining WETH to SALT/USDS Protocol Owned Liquidity.

		// Check that 20% of the remaining WETH (20% of 90.25 ether) has been converted to SALT/USDS
		(reservesA, reservesB) = pools.getPoolReserves(salt, usds);
		assertEq( reservesA, 18034549826583366128 ); // Close to 9.025 ether * 2
		assertEq( reservesB, 18018636175503832889 ); // Close to 9.025 ether * 2 - a little worse because some of the USDS reserve was also used for USDS/DAI POL

		daoLiquidity = collateralAndLiquidity.userShareForPool(address(dao), PoolUtils._poolID(salt, usds));
		assertEq( daoLiquidity, 36053187621633538184 ); // Close to 18.05 ether * 2


		// Check Step 5. Convert remaining WETH to SALT and sends it to SaltRewards.
		// Check Step 6. Send SALT Emissions to the SaltRewards contract.
		// Check Step 7. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter.
		// Check Step 8. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.

		// Check that about 72.2 ether of WETH has been converted to SALT and sent to SaltRewards.
		// Emissions also emit about 185715 SALT as 5 minutes have gone by since the last upkeep.
		// This is due to Emissions holding 129 million SALT and emitting at a default rate of .50% / week.

		// As there were profits, SaltRewards distributed the 201.2 ether(129 + 72.2) rewards
		// 10% to SALT/USDS rewards, 45% to stakingRewardsEmitter and 45% to liquidityRewardsEmitter,
		assertEq( salt.balanceOf(address(saltRewards)), 1 ); // should be basically empty now

		// Additionally stakingRewardsEmitter started with 3 million bootstrapping rewards.
		// liquidityRewardsEmitter started with 5 millions bootstrapping rewards, divided evenly amongst the 9 initial pools.

		// Determine that rewards were sent correctly by the stakingRewardsEmitter and liquidityRewardsEmitter
		bytes32[] memory poolIDsA = new bytes32[](1);
		poolIDsA[0] = PoolUtils.STAKED_SALT;

		// Check that the staking rewards were transferred to the staking contract.
		// Previous staking rewards + the 45% of 201.2
		assertEq( staking.totalRewardsForPools(poolIDsA)[0], 30942042860556487349723  );

		bytes32[] memory poolIDs = new bytes32[](5);
		poolIDs[0] = PoolUtils._poolID(salt,weth);
		poolIDs[1] = PoolUtils._poolID(salt,wbtc);
		poolIDs[2] = PoolUtils._poolID(wbtc,weth);
		poolIDs[3] = PoolUtils._poolID(salt,usds);
		poolIDs[4] = PoolUtils._poolID(usds,dai);

		// Check if the rewards were transferred to the liquidity contract.
		// Previous rewards + 1% max of ( 5 million / 9 pools + 45% of 201.2 ether sent from saltRewards).
		// SALT/USDS receives a bit more as well
		uint256[] memory rewards = collateralAndLiquidity.totalRewardsForPools(poolIDs);

		assertEq( rewards[0], 5854292064629940227685);
		assertEq( rewards[1], 5854292064629940227685);
		assertEq( rewards[2], 5854292064629940227685);
		assertEq( rewards[3], 11494344369665290653209);
		assertEq( rewards[4], 11126689366085590483436);


		// Check Step 9. Collect SALT rewards from the DAO's Protocol Owned Liquidity: send 10% to the initial dev team and burn a default 50% of the remaining - the rest stays in the DAO.
		// Check Step 10. Sends SALT from the DAO vesting wallet to the DAO (linear distribution over 10 years).
		// Check Step 11. Sends SALT from the team vesting wallet to the team (linear distribution over 10 years).

		// Previous rewards plus 10% of the POL Rewards for the team wallet
		assertEq( salt.balanceOf(teamWallet), 14704666211208713417511 );

		// 50% of the remaining rewards are burned
		assertEq( salt.totalBurned(), 5101079286055648734972 );

		// Other 50% should stay in the DAO
		// The daoVestingWallet contains 25 million SALT and vests over a 10 year period.
		// 100k SALT were removed from it in _generateArbitrageProfits() - so it emits about 34110 in the first 5 days
		assertEq( salt.balanceOf(address(dao)), 39234434499145450865870 );

//		console.log( "salt.balanceOf(teamWallet): ", salt.balanceOf(teamWallet) );
//		console.log( "salt.totalBurned(): ", salt.totalBurned() );
//		console.log( "salt.balanceOf(address(dao)): ", salt.balanceOf(address(dao)) );
		}

	// A unit test to verify all expected outcomes of a performUpkeep call followed by another after a five minute delay
	function testDoublePerformUpkeep() public
		{
		_setupLiquidity();
		_generateArbitrageProfits(false);

    	// Dummy WBTC and WETH to send to Liquidizer
    	vm.prank(DEPLOYER);
    	weth.transfer( address(liquidizer), 50 ether );

    	// Indicate that some USDS should be burned
    	vm.prank( address(collateralAndLiquidity));
    	liquidizer.incrementBurnableUSDS( 40 ether);

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
