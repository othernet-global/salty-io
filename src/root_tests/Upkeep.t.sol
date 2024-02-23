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

			skip( 1 hours );

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
	// 1. Withdraws existing SALT arbitrage profits from the Pools contract and rewards the caller of performUpkeep() with default 5% of the withdrawn amount.
    function testSuccessStep1() public
    	{
    	// Mimic depositing arbitrage profits
    	vm.prank(address(daoVestingWallet));
    	salt.transfer(address(dao), 100 ether);

		vm.startPrank(address(dao));
		salt.approve(address(pools), 100 ether );
		pools.deposit( salt, 100 ether);
		vm.stopPrank();

		assertEq( salt.balanceOf(alice), 0 );

        vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step1(alice);

    	assertEq( salt.balanceOf(alice), 5 ether );
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
	// 2. Burns 10% of the remaining withdrawn salt and sends 10% to the DAO's reserve.
    function testSuccessStep2() public
    	{
    	_setupLiquidity();

    	// Mimic depositing arbitrage profits
    	vm.prank(address(daoVestingWallet));
    	salt.transfer(address(dao), 100 ether);

		vm.startPrank(address(dao));
		salt.approve(address(pools), 100 ether );
		pools.deposit( salt, 100 ether);
		vm.stopPrank();

		assertEq( salt.totalBurned(), 0 );
		assertEq( salt.balanceOf( address(dao) ), 0 );

        vm.startPrank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step1(alice);
    	ITestUpkeep(address(upkeep)).step2();
    	vm.stopPrank();

		assertEq( salt.totalBurned(), 9.5 ether );
		assertEq( salt.balanceOf( address(dao) ), 9.5 ether );
    	}


    // A unit test to verify that step3() functions correctly
	// 3. Sends the remaining SALT to SaltRewards.
    function testSuccessStep3() public
    	{
    	_setupLiquidity();

    	// Mimic depositing arbitrage profits
    	vm.prank(address(daoVestingWallet));
    	salt.transfer(address(dao), 100 ether);

		vm.startPrank(address(dao));
		salt.approve(address(pools), 100 ether );
		pools.deposit( salt, 100 ether);
		vm.stopPrank();

		assertEq( salt.balanceOf(address(saltRewards)), 0 );

        vm.startPrank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step1(alice);
    	ITestUpkeep(address(upkeep)).step2();
    	ITestUpkeep(address(upkeep)).step3();
    	vm.stopPrank();

		// Check that 76 ether of SALT has been sent to SaltRewards.
		assertEq( salt.balanceOf(address(saltRewards)), 76 ether);
    	}


    // A unit test to verify that step4() functions correctly
	// 4. Sends SALT Emissions to the SaltRewards contract.
    function testSuccessStep4() public
    	{
    	// Wait an hour to generate some emissions
    	skip( 1 hours );

 		assertEq( salt.balanceOf(address(saltRewards)), 0 );

        vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step4();

		// Emissions emit about 1547.6 SALT in one hour.
		// This is due to Emissions holding 52 million SALT and emitting at a default rate of .50% / week.

		assertEq( salt.balanceOf(address(saltRewards)), 1547619047619047619047);
	  	}


	function _swapToGenerateProfits() internal
		{
		vm.startPrank(DEPLOYER);
		pools.depositSwapWithdraw(salt, weth, 10 ether, 0, block.timestamp);
		vm.roll(block.number + 1);
		pools.depositSwapWithdraw(salt, usdc, 10 ether, 0, block.timestamp);
		vm.roll(block.number + 1);
		pools.depositSwapWithdraw(weth, usdc, 10 ether, 0, block.timestamp);
		vm.roll(block.number + 1);
		vm.stopPrank();
		}


	function _generateArbitrageProfits() internal
		{
		/// Pull some SALT from the daoVestingWallet
    	vm.prank(address(daoVestingWallet));
    	salt.transfer(DEPLOYER, 100000 ether);

		vm.startPrank(DEPLOYER);
		salt.approve(address(liquidity), type(uint256).max);
		usdc.approve(address(liquidity), type(uint256).max);
		weth.approve(address(liquidity), type(uint256).max);

		liquidity.depositLiquidityAndIncreaseShare( salt, weth, 1000 ether, 1000 ether, 0, 0, 0, block.timestamp, false );
		liquidity.depositLiquidityAndIncreaseShare( usdc, salt, 1000 * 10**6, 1000 ether, 0, 0, 0, block.timestamp, false );
		liquidity.depositLiquidityAndIncreaseShare( usdc, weth, 1000 * 10**6, 1000 ether, 0, 0, 0, block.timestamp, false );

		salt.approve(address(pools), type(uint256).max);
		usdc.approve(address(pools), type(uint256).max);
		weth.approve(address(pools), type(uint256).max);
		vm.stopPrank();

		// Place some sample trades to create arbitrage profits
		_swapToGenerateProfits();
		}


    // A unit test to verify that step5() functions correctly
	// 5. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter.
    function testSuccessStep5() public
    	{
    	// Wait an hour to generate some emissions
    	skip( 1 hours );

    	// Generate arbitrage profits for the SALT/WETH, SALT/USDC and USDC/WETH pools
		_generateArbitrageProfits();

    	// Send some SALT to SaltRewards
    	vm.prank(address(daoVestingWallet));
    	salt.transfer(address(saltRewards), 100 ether );


		// stakingRewardsEmitter and liquidityRewardsEmitter have initial bootstrapping rewards
		bytes32[] memory poolIDsA = new bytes32[](1);
		poolIDsA[0] = PoolUtils.STAKED_SALT;
		uint256 initialRewardsA = stakingRewardsEmitter.pendingRewardsForPools(poolIDsA)[0];

		bytes32[] memory poolIDsB = new bytes32[](1);
		poolIDsB[0] = PoolUtils._poolID(salt, usdc);
		uint256 initialRewardsB = liquidityRewardsEmitter.pendingRewardsForPools(poolIDsB)[0];

        vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step5();

		assertEq( stakingRewardsEmitter.pendingRewardsForPools(poolIDsA)[0], initialRewardsA + 50 ether );

		bytes32[] memory poolIDs = new bytes32[](4);
		poolIDs[0] = PoolUtils._poolID(salt,weth);
		poolIDs[1] = PoolUtils._poolID(salt,usdc);
		poolIDs[2] = PoolUtils._poolID(usdc,weth);
		poolIDs[3] = PoolUtils._poolID(wbtc,weth);

		// Check that rewards were sent proportionally to the three pools involved in generating the test arbitrage
		assertEq( liquidityRewardsEmitter.pendingRewardsForPools(poolIDs)[0], initialRewardsB + uint256(50 ether) / 3 );
		assertEq( liquidityRewardsEmitter.pendingRewardsForPools(poolIDs)[1], initialRewardsB + uint256(50 ether) / 3 );
		assertEq( liquidityRewardsEmitter.pendingRewardsForPools(poolIDs)[2], initialRewardsB + uint256(50 ether) / 3 );
		assertEq( liquidityRewardsEmitter.pendingRewardsForPools(poolIDs)[3], initialRewardsB );

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
    	// Wait an hour to generate some emissions
       	skip( 1 hours );

    	assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3000000000000000000000005 );  // 3 million
    	assertEq( salt.balanceOf(address(liquidityRewardsEmitter)), 4999999999999999999999995 ); // 5 million

    	vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step6();


		bytes32[] memory poolIDsA = new bytes32[](1);
		poolIDsA[0] = PoolUtils.STAKED_SALT;

		// Check that the staking rewards were transferred to the staking contract.
		// 3 million emitting at 0.75% per day for one hour = 1250
		assertEq( staking.totalRewardsForPools(poolIDsA)[0], uint256(3000000 ether) * 75 / 10000 / 24 );

		bytes32[] memory poolIDs = new bytes32[](3);
		poolIDs[0] = PoolUtils._poolID(salt,weth);
		poolIDs[1] = PoolUtils._poolID(salt,usdc);
		poolIDs[2] = PoolUtils._poolID(usdc,weth);

		// Check if the rewards were transferred (5 million / 8 pools emitting at 0.75% per day for one hour) to the liquidity contract
		uint256[] memory rewards = liquidity.totalRewardsForPools(poolIDs);

		assertEq( rewards[0], uint256(5000000 ether) / numInitialPools * 75 / 10000 / 24);
		assertEq( rewards[1], uint256(5000000 ether) / numInitialPools * 75 / 10000 / 24);
		assertEq( rewards[2], uint256(5000000 ether) / numInitialPools * 75 / 10000 / 24);
	  	}


    // A unit test to verify that step7() functions correctly
    // 7. Sends SALT from the DAO vesting wallet to the DAO (linear distribution over 10 years).
    function testSuccessStep7() public
    	{
    	assertEq( salt.balanceOf(address(daoVestingWallet)), 25 * 1000000 ether );

		// Warp to the start of when the daoVestingWallet starts to emit as there is an initial one week delay
		vm.warp( VestingWallet(payable(daoVestingWallet)).start() );

		// 24 hours later
		vm.warp( block.timestamp + 24 hours );

		assertEq( salt.balanceOf(address(dao)), 0 );

    	vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step7();

		// Check that SALT has been sent to DAO.
    	assertEq( salt.balanceOf(address(dao)), uint256( 25 * 1000000 ether ) * 24 hours / (60 * 60 * 24 * 365 * 10) );
    	}


    // A unit test to verify that step7() functions correctly after one year of delay
    // 7. Sends SALT from the DAO vesting wallet to the DAO (linear distribution over 10 years).
    function testSuccessStep8WithOneYearDelay() public
    	{
    	assertEq( salt.balanceOf(address(daoVestingWallet)), 25 * 1000000 ether );

		// Warp to the start of when the daoVestingWallet starts to emit as there is an initial one week delay
		vm.warp( VestingWallet(payable(daoVestingWallet)).start() );

		// One year later
		vm.warp( block.timestamp + 365 days );

		assertEq( salt.balanceOf(address(dao)), 0 );

    	vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step7();

		// Check that SALT has been sent to DAO.
    	assertEq( salt.balanceOf(address(dao)), uint256( 25 * 1000000 ether ) * 24 hours * 365 / (60 * 60 * 24 * 365 * 10) );
    	}


    // A unit test to verify that step8() functions correctly
	// 8. Sends SALT from the team vesting wallet to the team (linear distribution over 10 years).
    function testSuccessStep8() public
    	{
    	assertEq( salt.balanceOf(address(teamVestingWallet)), 10 * 1000000 ether );

		// Warp to the start of when the teamVestingWallet starts to emit as there is an initial one week delay
		vm.warp( VestingWallet(payable(teamVestingWallet)).start() );

		// 24 hours later
		vm.warp( block.timestamp + 24 hours );

		assertEq( salt.balanceOf(teamWallet), 0 );

    	vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step8();

		// Check that SALT has been sent to DAO.
    	assertEq( salt.balanceOf(teamWallet), uint256( 10 * 1000000 ether ) * 24 hours / (60 * 60 * 24 * 365 * 10) );
    	}


	// A unit test to verify all expected outcomes of a performUpkeep call
	function testComprehensivePerformUpkeep() public
		{
		// Wait an hour for there to be some emissions
		skip( 1 hours );

		_generateArbitrageProfits();

    	// Mimic arbitrage profits deposited as SALT for the DAO
    	vm.prank(DEPLOYER);
    	salt.transfer(address(dao), 100 ether);

    	vm.startPrank(address(dao));
    	salt.approve(address(pools), 100 ether);
    	pools.deposit(salt, 100 ether);
    	vm.stopPrank();

		assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3000000000000000000000005 );
		assertEq( salt.balanceOf(address(staking)), 0 );

		assertEq( upkeep.currentRewardsForCallingPerformUpkeep(), 5003333225751503102 );

		// === Perform upkeep ===
		address upkeepCaller = address(0x9999);

		vm.prank(upkeepCaller);
		upkeep.performUpkeep();
		// ==================

		// Check Step 1. Withdraws deposited SALT arbitrage profits from the Pools contract and rewards the caller of performUpkeep()
		// From the directly added 100 ether + arbitrage profits
    	assertEq( salt.balanceOf(upkeepCaller), 5003333225751503102 );


		// Check Step 2. Burns 10% of the remaining withdrawn salt and sends 10% to the DAO's reserve.

		assertEq( salt.totalBurned(), 9506333128927855893 );

		// Check Step 3. Sends the remaining SALT to SaltRewards.
		// Check Step 4. Send SALT Emissions to the SaltRewards contract.
		// Check Step 5. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter.
		// Check Step 6. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.

		// Check that 76 ether of SALT had been sent to SaltRewards.
		// Emissions also emit about 1488 SALT to SaltRewards as one hour has gone by since the deployment (delay for the bootstrap ballot to complete).
		// This is due to Emissions holding 50 million SALT and emitting at a default rate of .50% / week.

		// As there were profits, SaltRewards distributed the 1488 ether + 72.2 ether rewards to the rewards emitters.
		// 50% to stakingRewardsEmitter and 50% to liquidityRewardsEmitter, 1% / day for one hour.
		assertEq( salt.balanceOf(address(saltRewards)), 1 ); // should be basically empty now

		// Additionally stakingRewardsEmitter started with 3 million bootstrapping rewards.
		// liquidityRewardsEmitter started with 5 million bootstrapping rewards, divided evenly amongst the initial pools.

		// Determine that rewards were sent correctly by the stakingRewardsEmitter and liquidityRewardsEmitter
		bytes32[] memory poolIDsA = new bytes32[](1);
		poolIDsA[0] = PoolUtils.STAKED_SALT;

		// Check that the staking rewards were transferred to the staking contract:
		// One hour of emitted rewards (1% a day) of (3 million bootstrapping in the stakingRewardsEmitter and 50% of 1560.2 ether)
		// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
		assertEq( staking.totalRewardsForPools(poolIDsA)[0], 937753698392601636010  );

		bytes32[] memory poolIDs = new bytes32[](3);
		poolIDs[0] = PoolUtils._poolID(salt,weth);
		poolIDs[1] = PoolUtils._poolID(salt,usdc);
		poolIDs[2] = PoolUtils._poolID(usdc,weth);

		// Check if the rewards were transferred to the liquidity contract:
		// One hour of emitted rewards (1% a day)  / numInitialPools of (5 million bootstrapping and 50% of 1560.2 ether)
		// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
		uint256[] memory rewards = liquidity.totalRewardsForPools(poolIDs);

		assertEq( rewards[0], 223298851845152926289);
		assertEq( rewards[1], 223298851845152926289);
		assertEq( rewards[2], 223298851845152926289);


		// Check Step 7. Sends SALT from the DAO vesting wallet to the DAO (linear distribution over 10 years).
		// Check Step 8. Sends SALT from the team vesting wallet to the team (linear distribution over 10 years).

		// The teamVestingWallet contains 10 million SALT and vests over a 10 year period.
		// It emits about 13561 in the first 5 days + 1 hour (started at the time of contract deployment)
		assertEq( salt.balanceOf(teamWallet), 13812817097919837645865 );

		// The daoVestingWallet contains 25 million SALT and vests over a 10 year period.
		// 100k SALT were removed from it in _generateArbitrageProfits() - so it emits about 34394 in the first 5 days + one hour
		assertEq( salt.balanceOf(address(dao)), 34403420906949323594096 );
		}



	function _secondPerformUpkeep() internal
		{
		// Five minute delay before the next performUpkeep
		vm.warp( block.timestamp + 5 minutes );

		_swapToGenerateProfits();

    	// Mimic arbitrage profits deposited as WETH for the DAO
    	vm.prank(DEPLOYER);
    	salt.transfer(address(dao), 100 ether);

    	vm.startPrank(address(dao));
    	salt.approve(address(pools), 100 ether);
    	pools.deposit(salt, 100 ether);
    	vm.stopPrank();

		// === Perform upkeep ===
		address upkeepCaller = address(0x9999);

		vm.prank(upkeepCaller);
		upkeep.performUpkeep();
		// ==================



		// Check Step 1. Withdraws deposited SALT arbitrage profits from the Pools contract and rewards the caller of performUpkeep()
		// From the directly added 100 ether + arbitrage profits
    	assertEq( salt.balanceOf(upkeepCaller), 10011660298034044844 );


		// Check Step 2. Burns 10% of the remaining withdrawn salt and sends 10% to the DAO's reserve.

		assertEq( salt.totalBurned(), 19022154566264685204 );

		// Check Step 3. Sends the remaining SALT to SaltRewards.
		// Check Step 4. Send SALT Emissions to the SaltRewards contract.
		// Check Step 5. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter.
		// Check Step 6. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.

		// Check that 76 ether of SALT had been sent to SaltRewards.
		// Emissions also emit about 1488 SALT to SaltRewards as one hour has gone by since the deployment (delay for the bootstrap ballot to complete).
		// This is due to Emissions holding 50 million SALT and emitting at a default rate of .50% / week.

		// As there were profits, SaltRewards distributed the 1488 ether + 72.2 ether rewards to the rewards emitters.
		// 50% to stakingRewardsEmitter and 50% to liquidityRewardsEmitter, 1% / day for one hour.
		assertEq( salt.balanceOf(address(saltRewards)), 1 ); // should be basically empty now

		// Additionally stakingRewardsEmitter started with 3 million bootstrapping rewards.
		// liquidityRewardsEmitter started with 5 million bootstrapping rewards, divided evenly amongst the initial pools.

		// Determine that rewards were sent correctly by the stakingRewardsEmitter and liquidityRewardsEmitter
		bytes32[] memory poolIDsA = new bytes32[](1);
		poolIDsA[0] = PoolUtils.STAKED_SALT;

		// Check that the staking rewards were transferred to the staking contract:
		// One hour of emitted rewards (1% a day) of (3 million bootstrapping in the stakingRewardsEmitter and 50% of 1560.2 ether)
		// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
		assertEq( staking.totalRewardsForPools(poolIDsA)[0], 1015878089711651002206  );

		bytes32[] memory poolIDs = new bytes32[](3);
		poolIDs[0] = PoolUtils._poolID(salt,weth);
		poolIDs[1] = PoolUtils._poolID(salt,usdc);
		poolIDs[2] = PoolUtils._poolID(usdc,weth);

		// Check if the rewards were transferred to the liquidity contract:
		// One hour of emitted rewards (1% a day)  / numInitialPools of (5 million bootstrapping and 50% of 1560.2 ether)
		// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
		uint256[] memory rewards = liquidity.totalRewardsForPools(poolIDs);

		assertEq( rewards[0], 241902164576502715021);
		assertEq( rewards[1], 241902164576502715021);
		assertEq( rewards[2], 241902164576502715021);


		// Check Step 7. Sends SALT from the DAO vesting wallet to the DAO (linear distribution over 10 years).
		// Check Step 8. Sends SALT from the team vesting wallet to the team (linear distribution over 10 years).

		// The teamVestingWallet contains 10 million SALT and vests over a 10 year period.
		// It emits about 13561 in the first 5 days + 1 hour (started at the time of contract deployment)
		assertEq( salt.balanceOf(teamWallet), 13822330035514967021816 );

		// The daoVestingWallet contains 25 million SALT and vests over a 10 year period.
		// 100k SALT were removed from it in _generateArbitrageProfits() - so it emits about 34394 in the first 5 days + one hour
		assertEq( salt.balanceOf(address(dao)), 34436623942998532569526 );
		}


	// A unit test to verify all expected outcomes of a performUpkeep call followed by another after a five minute delay
	function testDoublePerformUpkeep() public
		{
		_generateArbitrageProfits();

    	// Mimic arbitrage profits deposited as WETH for the DAO
    	vm.prank(DEPLOYER);
    	salt.transfer(address(dao), 100 ether);

    	vm.startPrank(address(dao));
    	salt.approve(address(pools), 100 ether);
    	pools.deposit(salt, 100 ether);
    	vm.stopPrank();

		skip( 1 hours );

		// === Perform upkeep ===
		address upkeepCaller = address(0x9999);

		vm.prank(upkeepCaller);
		upkeep.performUpkeep();
		// ==================

		_secondPerformUpkeep();
		}


// From https://github.com/code-423n4/2024-01-salty-findings/issues/614
function testFirstLPCanClaimAllRewards() public {

		vm.startPrank(DEPLOYER);
		wbtc.transfer(alice, 1000000 *10**8);
		weth.transfer(alice, 1000000 ether);
		vm.stopPrank();


        assertEq(salt.balanceOf(alice), 0);
        bytes32 poolID1 = PoolUtils._poolID( wbtc, weth );
        bytes32[] memory poolIDs = new bytes32[](1);
        poolIDs[0] = poolID1;

        // Claiming will start right as the BootstrapBallot is finalized - not 2 days later
//        skip(2 days);

	uint256 depositedWBTC = ( 1000 *10**8);
	uint256 depositedWETH = ( 1000 *10**18);

	vm.startPrank(alice);
		wbtc.approve( address(liquidity), type(uint256).max );
        weth.approve( address(liquidity), type(uint256).max );


//		console.log( "BALANCE 1: ", wbtc.balanceOf(alice) );
//		console.log( "BALANCE 2: ", weth.balanceOf(alice) );

        // Alice call upkeep
        vm.expectRevert( "No time since elapsed since last upkeep" );
        upkeep.performUpkeep();
        // check total rewards for pool
        uint256[] memory totalRewards = new uint256[](1);
        totalRewards = liquidity.totalRewardsForPools(poolIDs);
        // Alice will deposit collateral
		liquidity.depositLiquidityAndIncreaseShare( wbtc, weth, depositedWBTC, depositedWETH, 0, 0, 0, block.timestamp, false );
        // check alices rewards
        uint rewardsAlice = liquidity.userRewardForPool(alice, poolIDs[0]);
        liquidity.claimAllRewards(poolIDs);
        vm.stopPrank();

//		console.log( "ALICE REWARDS: ", rewardsAlice );

		assertEq( rewardsAlice, 0 );

        assertEq(totalRewards[0], rewardsAlice);
        assertEq(salt.balanceOf(alice), totalRewards[0]);
    }
	}
