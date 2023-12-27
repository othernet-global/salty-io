// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "../../dev/Deployment.sol";
import "./TestSaltRewards.sol";


contract TestSaltRewards2 is Deployment
	{
    address public constant alice = address(0x1111);
    address public constant bob = address(0x2222);
    address public constant charlie = address(0x3333);



    function setUp() public
    	{
		// If $COVERAGE=yes, create an instance of the contract so that coverage testing can work
		// Otherwise, what is tested is the actual deployed contract on the blockchain (as specified in Deployment.sol)
		if ( keccak256(bytes(vm.envString("COVERAGE" ))) == keccak256(bytes("yes" )))
			initializeContracts();

		// Transfer the salt from the original initialDistribution to the DEPLOYER
		vm.prank(address(initialDistribution));
		salt.transfer(DEPLOYER, 100000000 ether);
    	}


    // A unit test to ensure that the _sendStakingRewards function correctly transfers the pendingStakingRewards to the stakingRewardsEmitter and resets the pendingStakingRewards to zero.
 function testSendStakingRewards() public {
 		TestSaltRewards _saltRewards = new TestSaltRewards(stakingRewardsEmitter, liquidityRewardsEmitter, exchangeConfig, rewardsConfig);

		vm.prank(DEPLOYER);
		salt.transfer(address(_saltRewards), 10 ether);

         // Initializing the pending staking rewards
         uint256 initialPendingStakingRewards = 10 ether;

         // Initializing the balance of contract before running the function
     	uint256 initialSaltContractBalance = salt.balanceOf(address(_saltRewards));

         // Set the initial balance of stakingRewardsEmitter
         uint256 initialStakingRewardsEmitterBalance = salt.balanceOf(address(stakingRewardsEmitter));

         // Running _sendStakingRewards function
         _saltRewards.sendStakingRewards(initialPendingStakingRewards);

         // Expectations after running the function
         uint256 expectedStakingRewardsEmitterBalance = initialPendingStakingRewards + initialStakingRewardsEmitterBalance;
         uint256 expectedSaltContractBalance = initialSaltContractBalance - initialPendingStakingRewards;

         // Verifying the changes in the balances and the pending staking rewards
         assertEq(salt.balanceOf(address(stakingRewardsEmitter)), expectedStakingRewardsEmitterBalance, "StakingRewardsEmitter hasn't received the correct amount of Salt");
         assertEq(salt.balanceOf(address(_saltRewards)), expectedSaltContractBalance, "_sendStakingRewards hasn't deducted the correct amount of Salt from the contract balance");
     }


    // A unit test to verify the _sendLiquidityRewards function with a non-zero total profits and non-zero pending rewards, ensuring that the correct amount is transferred each pool's liquidityRewardsEmitter and the pendingLiquidityRewards and pendingRewardsSaltUSDS fields are reset to zero.
    function testSendLiquidityRewards() public {
        TestSaltRewards _saltRewards = new TestSaltRewards(stakingRewardsEmitter, liquidityRewardsEmitter, exchangeConfig, rewardsConfig);

    	vm.prank(DEPLOYER);
        salt.transfer(address(_saltRewards), 50 ether);

		IERC20 token1 = new TestERC20( "TEST", 18 );
		IERC20 token2 = new TestERC20( "TEST", 18 );

		vm.prank(address(dao));
		poolsConfig.whitelistPool( pools,   token1, token2);

        bytes32[] memory poolIDs = new bytes32[](2);
        poolIDs[0] = PoolUtils._poolID(salt,usds);
		poolIDs[1] = PoolUtils._poolID(token1, token2);

        uint256[] memory profitsForPools = new uint256[](2);
        profitsForPools[0] = 10 ether;
        profitsForPools[1] = 20 ether;

        // Initializing the pending rewards
        uint256 initialPendingLiquidityRewards = 40 ether; // for other pools
        uint256 initialPendingRewardsSaltUSDS = 1 ether; // for SALT/USDS pool

        // Balance of contract before running sendLiquidityRewards
        uint256 initialSaltContractBalance = salt.balanceOf(address(_saltRewards));

    	// Balance of liquidityRewardsEmitter before running sendLiquidityRewards
        uint256 initialLiquidityRewardsEmitterBalance = salt.balanceOf(address(liquidityRewardsEmitter));

        // Run _sendLiquidityRewards function
        _saltRewards.sendLiquidityRewards(initialPendingLiquidityRewards, initialPendingRewardsSaltUSDS, poolIDs, profitsForPools);

        // Expectations after running the function
        uint256 expectedLiquidityRewardsEmitterBalance = initialLiquidityRewardsEmitterBalance + initialPendingLiquidityRewards + initialPendingRewardsSaltUSDS;
        uint256 expectedSaltContractBalance = initialSaltContractBalance - initialPendingLiquidityRewards - initialPendingRewardsSaltUSDS;

        // Verifying the changes in the balances and the pending rewards
        assertEq(salt.balanceOf(address(liquidityRewardsEmitter)), expectedLiquidityRewardsEmitterBalance - 1, "LiquidityRewardsEmitter hasn't received the correct amount of Salt");
        assertEq(salt.balanceOf(address(_saltRewards)), expectedSaltContractBalance + 1, "_sendLiquidityRewards hasn't deducted the correct amount of Salt from the contract balance");

        // Should set  pendingRewardsSaltUSDS to the remaining SALT that wasn't sent
        assertEq(salt.balanceOf(address(_saltRewards)), 9000000000000000001, "_sendLiquidityRewards didn't set pendingRewardsSaltUSDS to 0");

        uint256[] memory pendingRewards = liquidityRewardsEmitter.pendingRewardsForPools(poolIDs);
        assertEq( pendingRewards[0], initialPendingLiquidityRewards * 1 / 3 + 1 ether );
        assertEq( pendingRewards[1], initialPendingLiquidityRewards * 2 / 3 );
    }


    // A unit test to ensure that _sendLiquidityRewards function does not transfer any rewards when total profits are zero.
    function testSendLiquidityRewardsZeroProfits() public {
    	TestSaltRewards _saltRewards = new TestSaltRewards(stakingRewardsEmitter, liquidityRewardsEmitter, exchangeConfig, rewardsConfig);

    	vm.prank(DEPLOYER);
    	salt.transfer(address(_saltRewards), 10 ether);

    	// Initializing the pending liquidity rewards
    	uint256 initialPendingLiquidityRewards = 10 ether;

    	// Running _sendLiquidityRewards function with zero total profits
    	bytes32[] memory poolIDs = new bytes32[](0);
    	uint256[] memory profitsForPools = new uint256[](0);
    	_saltRewards.sendLiquidityRewards(initialPendingLiquidityRewards, 0, poolIDs, profitsForPools);

    	// Since total profits are zero, no rewards should be transferred
    	assertEq(salt.balanceOf(address(liquidityRewardsEmitter)), 0, "No liquidity rewards should be transferred for zero profits");
    	assertEq(salt.balanceOf(address(_saltRewards)), 10 ether, "No liquidity rewards should be deducted for zero profits");
    }


    // A unit test to ensure that the _sendInitialLiquidityRewards function correctly divides the liquidityBootstrapAmount amongst the initial pools and sends the amount to liquidityRewardsEmitter.
        function testSendInitialLiquidityRewards() public {
            TestSaltRewards _saltRewards = new TestSaltRewards(stakingRewardsEmitter, liquidityRewardsEmitter, exchangeConfig, rewardsConfig);

            bytes32[] memory poolIDs = new bytes32[](3);
            poolIDs[0] = PoolUtils._poolID(salt, usds);
            poolIDs[1] = PoolUtils._poolID(wbtc, weth);
            poolIDs[2] = PoolUtils._poolID(weth, usds);

            uint256 liquidityBootstrapAmount = 900 ether;

            // move tokens to rewards contract
            vm.prank(DEPLOYER);
            salt.transfer(address(_saltRewards), liquidityBootstrapAmount);

            uint256 initialLiquidityEmitterBalance = salt.balanceOf(address(liquidityRewardsEmitter));

            // run `_sendInitialLiquidityRewards` function
            _saltRewards.sendInitialLiquidityRewards(liquidityBootstrapAmount, poolIDs);

            // verify the correct amount was transferred to liquidityRewardsEmitter
            uint256 expectedLiquidityEmitterBalance = initialLiquidityEmitterBalance + liquidityBootstrapAmount;
            assertEq(salt.balanceOf(address(liquidityRewardsEmitter)), expectedLiquidityEmitterBalance, "LiquidityRewardsEmitter hasn't received the correct amount of Salt");

            uint256 expectedPerPool = liquidityBootstrapAmount / 3;
            uint256[] memory pendingRewards = liquidityRewardsEmitter.pendingRewardsForPools(poolIDs);

            assertEq( pendingRewards[0], expectedPerPool );
            assertEq( pendingRewards[1], expectedPerPool );
            assertEq( pendingRewards[2], expectedPerPool );
        }


    // A unit test to check the _sendInitialStakingRewards function ensuring that the stakingBootstrapAmount is correctly transferred to the stakingRewardsEmitter.
    function testSendInitialStakingRewards() public {
    	TestSaltRewards _saltRewards = new TestSaltRewards(stakingRewardsEmitter, liquidityRewardsEmitter, exchangeConfig, rewardsConfig);

    	vm.prank(DEPLOYER);
    	salt.transfer(address(_saltRewards), 10 ether);

    	// Initializing the staking bootstrap amount
    	uint256 stakingBootstrapAmount = 10 ether;

    	// Initializing the balance of contract before running the function
    	uint256 initialSaltContractBalance = salt.balanceOf(address(_saltRewards));

    	// Initialize the initial balance of stakingRewardsEmitter
    	uint256 initialStakingRewardsEmitterBalance = salt.balanceOf(address(stakingRewardsEmitter));

    	// Running _sendInitialStakingRewards function
    	_saltRewards.sendInitialStakingRewards(stakingBootstrapAmount);

    	// Expectations after running the function
    	uint256 expectedStakingRewardsEmitterBalance = stakingBootstrapAmount + initialStakingRewardsEmitterBalance;
    	uint256 expectedSaltContractBalance = initialSaltContractBalance - stakingBootstrapAmount;

    	// Verifying the changes in the balances after running the function
    	assertEq(salt.balanceOf(address(stakingRewardsEmitter)), expectedStakingRewardsEmitterBalance, "StakingRewardsEmitter hasn't received the correct amount of Salt");
    	assertEq(salt.balanceOf(address(_saltRewards)), expectedSaltContractBalance, "_sendInitialStakingRewards hasn't deducted the correct amount of Salt from the contract balance");
    }


    // A unit test to check the sendInitialSaltRewards function ensuring that it cannot be called by any other address other than the initialDistribution address set in the constructor.
    function testSendInitialSaltRewards_onlyCallableByInitialDistribution() public {
        TestSaltRewards _saltRewards = new TestSaltRewards(stakingRewardsEmitter, liquidityRewardsEmitter, exchangeConfig, rewardsConfig);

        vm.prank(DEPLOYER);
        salt.transfer(address(_saltRewards), 8 ether);

        uint256 liquidityBootstrapAmount = 5 ether;

        bytes32[] memory poolIDs = new bytes32[](1);
        poolIDs[0] = PoolUtils._poolID(salt, usds);

        // Expect revert because the caller is not the initialDistribution
        vm.expectRevert("SaltRewards.sendInitialRewards is only callable from the InitialDistribution contract");
        _saltRewards.sendInitialSaltRewards(liquidityBootstrapAmount, poolIDs);

        // Change the caller to the initialDistribution
        vm.prank(address(initialDistribution));
        _saltRewards.sendInitialSaltRewards(liquidityBootstrapAmount, poolIDs);
    }


    // A unit test to validate that the performUpkeep function works correctly when called by the upkeep address and the pendingStakingRewards and pendingLiquidityRewards fields are non-zero and check if the balance of contract is decreased by the sent amount.
    function testPerformUpkeepSuccess() public
    {
        TestSaltRewards _saltRewards = new TestSaltRewards(stakingRewardsEmitter, liquidityRewardsEmitter, exchangeConfig, rewardsConfig);

		uint256 saltRewards = 30 ether;
        vm.prank(DEPLOYER);
        salt.transfer(address(_saltRewards), saltRewards);


        // Create dummy poolIds and profitsForPools arrays
		IERC20 token1 = new TestERC20( "TEST", 18 );
		IERC20 token2 = new TestERC20( "TEST", 18 );

		vm.prank(address(dao));
		poolsConfig.whitelistPool( pools,   token1, token2);

        bytes32[] memory poolIDs = new bytes32[](2);
        poolIDs[0] = PoolUtils._poolID(salt,usds);
		poolIDs[1] = PoolUtils._poolID(token1, token2);

        uint256[] memory profitsForPools = new uint256[](2);
        profitsForPools[0] = 10 ether;
        profitsForPools[1] = 20 ether;


        // Running performUpkeep function
        vm.prank(address(exchangeConfig.upkeep()));
        _saltRewards.performUpkeep(poolIDs, profitsForPools);

        // Expectations after running the function
        uint256 directSaltUSDSRewards = saltRewards / 10;
        uint256 expectedStakingRewardsEmitterBalance = (saltRewards - directSaltUSDSRewards ) / 2;
        uint256 expectedLiquidityRewardsEmitterBalance = (saltRewards - directSaltUSDSRewards ) / 2 + directSaltUSDSRewards;

        // Verifying the changes in the balances, pending staking rewards and pending liquidity rewards
        assertEq(salt.balanceOf(address(_saltRewards)), 0, "performUpkeep hasn't deducted the correct amount of Salt from the contract balance");
        assertEq(salt.balanceOf(address(stakingRewardsEmitter)), expectedStakingRewardsEmitterBalance, "StakingRewardsEmitter hasn't received the correct amount of Salt");
        assertEq(salt.balanceOf(address(liquidityRewardsEmitter)), expectedLiquidityRewardsEmitterBalance, "LiquidityRewardsEmitter hasn't received the correct amount of Salt");
    }



    // A unit test to check the performUpkeep function when it's called by an address other than the upkeep address, ensuring that it reverts with the correct error message.
    function testPerformUpkeep_NotUpkeepAddress() public
    {
        TestSaltRewards _saltRewards = new TestSaltRewards(stakingRewardsEmitter, liquidityRewardsEmitter, exchangeConfig, rewardsConfig);

        vm.prank(charlie); // Assuming charlie is not an upkeep address

        bytes32[] memory poolIDs = new bytes32[](0);
        uint256[] memory profitsForPools = new uint256[](0);

        // Expect the performUpkeep to revert because it's called by an address other than the upkeep address
        vm.expectRevert("SaltRewards.performUpkeep is only callable from the Upkeep contract");
        _saltRewards.performUpkeep(poolIDs, profitsForPools);
    }


    // A unit test to check that the performUpkeep function does not perform any actions when the pendingStakingRewards or pendingLiquidityRewards are zero.
    function testPerformUpkeepWithZeroRewards() public
    	{
    	TestSaltRewards _saltRewards = new TestSaltRewards(stakingRewardsEmitter, liquidityRewardsEmitter, exchangeConfig, rewardsConfig);
    	vm.prank(DEPLOYER);

    	// No rewards are transferred to _saltRewards


    	// Initial balances to be compared with final balances
    	uint256 initialContractBalance = salt.balanceOf(address(_saltRewards));
    	uint256 initialStakingRewardsEmitterBalance = salt.balanceOf(address(stakingRewardsEmitter));
    	uint256 initialLiquidityRewardsEmitterBalance = salt.balanceOf(address(liquidityRewardsEmitter));


        // Create dummy poolIds and profitsForPools arrays
		IERC20 token1 = new TestERC20( "TEST", 18 );
		IERC20 token2 = new TestERC20( "TEST", 18 );

		vm.prank(address(dao));
		poolsConfig.whitelistPool( pools,   token1, token2);

        bytes32[] memory poolIDs = new bytes32[](2);
        poolIDs[0] = PoolUtils._poolID(salt,usds);
		poolIDs[1] = PoolUtils._poolID(token1, token2);

        uint256[] memory profitsForPools = new uint256[](2);
        profitsForPools[0] = 10 ether;
        profitsForPools[1] = 20 ether;


    	// Perform upkeep
    	vm.prank(address(upkeep));
    	_saltRewards.performUpkeep(poolIDs, profitsForPools);

    	// Final balances
    	uint256 finalContractBalance = salt.balanceOf(address(_saltRewards));
    	uint256 finalStakingRewardsEmitterBalance = salt.balanceOf(address(stakingRewardsEmitter));
    	uint256 finalLiquidityRewardsEmitterBalance = salt.balanceOf(address(liquidityRewardsEmitter));

    	// Asserts
    	assertEq(finalContractBalance, initialContractBalance, "The contracts balance was changed, but it shouldn't have!");
    	assertEq(finalStakingRewardsEmitterBalance, initialStakingRewardsEmitterBalance, "The Staking Rewards Emitter's balance was changed, but it shouldn't have!");
    	assertEq(finalLiquidityRewardsEmitterBalance, initialLiquidityRewardsEmitterBalance, "The Liquidity Rewards Emitter's balance was changed, but it shouldn't have!");
    	}


	// A unit test to validate that any leftover SALT dust is added to pendingRewardsSaltUSDS after executing the _sendLiquidityRewards function
	    function testAddDustToPendingRewardsSaltUSDS() public {
            TestSaltRewards _saltRewards = new TestSaltRewards(stakingRewardsEmitter, liquidityRewardsEmitter, exchangeConfig, rewardsConfig);

            vm.prank(DEPLOYER);
            salt.transfer(address(_saltRewards), 50 ether);

            bytes32[] memory poolIDs = new bytes32[](1);
            poolIDs[0] = PoolUtils._poolID(salt,usds);

            uint256[] memory profitsForPools = new uint256[](1);
            profitsForPools[0] = 10 ether;

            // Balance of contract before running sendLiquidityRewards
			_saltRewards.sendStakingRewards(0 ether);
            _saltRewards.sendLiquidityRewards(40 ether, 1 ether, poolIDs, profitsForPools);

            // It should be equal to the dust remaining in the contract plus the initial pendingRewardsSaltUSDS
            assertEq(salt.balanceOf(address(_saltRewards)), 9 ether, "The remaining dust was not added to pendingRewardsSaltUSDS");
        }


    // A unit test that ensures proper amount of direct rewards for the SALT/USDS pool is calculated and sent in _sendLiquidityRewards()
    function testDirectRewardsForSaltUSDSPool() public {
        TestSaltRewards _saltRewards = new TestSaltRewards(stakingRewardsEmitter, liquidityRewardsEmitter, exchangeConfig, rewardsConfig);

        vm.prank(DEPLOYER);
        salt.transfer(address(_saltRewards), 100 ether);

        IERC20 token1 = new TestERC20("TOKEN1", 18);
        IERC20 token2 = new TestERC20("TOKEN2", 18);
        bytes32 saltUSDSPoolID = PoolUtils._poolID(salt, usds);
        bytes32 tokenPoolID = PoolUtils._poolID(token1, token2);

        vm.prank(address(dao));
        poolsConfig.whitelistPool( pools, token1, token2);

        bytes32[] memory poolIDs = new bytes32[](2);
        poolIDs[0] = saltUSDSPoolID;
        poolIDs[1] = tokenPoolID;

        uint256[] memory profitsForPools = new uint256[](2);
        profitsForPools[0] = 0; // SALT/USDS pool doesn't generate profits through this mechanism
        profitsForPools[1] = 50 ether; // profits generated by TOKEN1/TOKEN2 pool

        uint256 liquidityRewardsAmount = 80 ether;
        uint256 directRewardsForSaltUSDS = 10 ether;
        uint256 totalProfits = profitsForPools[1]; // Only TOKEN1/TOKEN2 pool has profits

        vm.prank(address(dao));
        _saltRewards.sendLiquidityRewards(liquidityRewardsAmount, directRewardsForSaltUSDS, poolIDs, profitsForPools);

        uint256 sentToSaltUSDS = directRewardsForSaltUSDS +
                                 (liquidityRewardsAmount * profitsForPools[0] / totalProfits);
        uint256 sentToTokenPool = liquidityRewardsAmount * profitsForPools[1] / totalProfits;

        // Total distributed should equal the direct rewards plus calculated rewards based on profits
        uint256 totalDistributed = sentToSaltUSDS + sentToTokenPool;
        uint256 balanceAfterDistribution = salt.balanceOf(address(_saltRewards));

        // Total expected distributed equals liquidityRewardsAmount plus directRewardsForSaltUSDS,
        // and the required balance after distribution is the initial balance minus the total distributed
        uint256 expectedTotalDistributed = liquidityRewardsAmount + directRewardsForSaltUSDS;
        uint256 expectedBalanceAfterDistribution = 100 ether - expectedTotalDistributed;

        assertEq(totalDistributed, expectedTotalDistributed, "Incorrect total rewards distributed");
        assertEq(balanceAfterDistribution, expectedBalanceAfterDistribution, "Incorrect balance after distributing rewards");
    }


    // A unit test that checks if rewards are proportionally distributed to each pool according to their profits in _sendLiquidityRewards()
	function testRewardDistributionProportionalToProfits() public {
            TestSaltRewards saltRewards = new TestSaltRewards(
                stakingRewardsEmitter,
                liquidityRewardsEmitter,
                exchangeConfig,
                rewardsConfig
            );

            vm.prank(DEPLOYER);
            salt.transfer(address(saltRewards), 30 ether);

            IERC20 tokenA = new TestERC20("TESTA", 18);
            IERC20 tokenB = new TestERC20("TESTB", 18);

            vm.prank(address(dao));
            poolsConfig.whitelistPool(pools, tokenA, tokenB);

            bytes32 poolIdA = PoolUtils._poolID(salt,usds);
            bytes32 poolIdB = PoolUtils._poolID(tokenA, tokenB);
            bytes32[] memory poolIDs = new bytes32[](2);
            poolIDs[0] = poolIdA;
            poolIDs[1] = poolIdB;

            uint256 profitA = 15 ether;
            uint256 profitB = 5 ether;
            uint256 totalProfits = profitA + profitB;
            uint256[] memory profitsForPools = new uint256[](2);
            profitsForPools[0] = profitA;
            profitsForPools[1] = profitB;

            uint256 liquidityRewardsAmount = 10 ether; // total rewards to be distributed
            uint256 directRewardsForSaltUSDS = 2 ether; // direct rewards to SALT/USDS pool
            uint256 expectedRewardsForPoolA = (liquidityRewardsAmount * profitA / totalProfits) + directRewardsForSaltUSDS;
            uint256 expectedRewardsForPoolB = (liquidityRewardsAmount * profitB / totalProfits);

            // Both pools should now have a pending reward that's directly proportional to their profits contribution
            uint256 initialPendingRewardsA = liquidityRewardsEmitter.pendingRewardsForPools(poolIDs)[0];
            uint256 initialPendingRewardsB = liquidityRewardsEmitter.pendingRewardsForPools(poolIDs)[1];

            saltRewards.sendLiquidityRewards(
                liquidityRewardsAmount,
                directRewardsForSaltUSDS,
                poolIDs,
                profitsForPools
            );

            uint256 finalPendingRewardsA = liquidityRewardsEmitter.pendingRewardsForPools(poolIDs)[0];
            uint256 finalPendingRewardsB = liquidityRewardsEmitter.pendingRewardsForPools(poolIDs)[1];

            assertEq(finalPendingRewardsA, initialPendingRewardsA + expectedRewardsForPoolA, "Pool A did not receive correct rewards based on profits");
            assertEq(finalPendingRewardsB, initialPendingRewardsB + expectedRewardsForPoolB, "Pool B did not receive correct rewards based on profits");
        }


    // A unit test that validates that the staking rewards are sent to the stakingRewardsEmitter correctly
	function testStakingRewardsSentToStakingRewardsEmitter() public {
		TestSaltRewards saltRewards = new TestSaltRewards(
			stakingRewardsEmitter,
			liquidityRewardsEmitter,
			exchangeConfig,
			rewardsConfig
		);

		// Arrange
        uint256 stakingRewardsAmount = 5 ether;

        vm.startPrank(DEPLOYER);
        salt.transfer(address(saltRewards), stakingRewardsAmount);
        vm.stopPrank();

        uint256 initialStakingRewardsEmitterBalance = salt.balanceOf(address(stakingRewardsEmitter));

        // Act
        saltRewards.sendStakingRewards(stakingRewardsAmount);

        // Assert
        uint256 expectedStakingRewardsEmitterBalance = initialStakingRewardsEmitterBalance + stakingRewardsAmount;
        uint256 contractBalanceAfterTransfer = salt.balanceOf(address(this));
        uint256 stakingRewardsEmitterBalanceAfterTransfer = salt.balanceOf(address(stakingRewardsEmitter));

        assertEq(contractBalanceAfterTransfer, 0, "Contract balance should be 0 after sending rewards");
        assertEq(stakingRewardsEmitterBalanceAfterTransfer, expectedStakingRewardsEmitterBalance, "stakingRewardsEmitter balance should be increased by stakingRewardsAmount");
    }


    // A unit test that verifies if _sendInitialLiquidityRewards evenly divides the bootstrap amount across all initial pools
	function testSendInitialLiquidityRewardsEvenDivision() public {
        TestSaltRewards _saltRewards = new TestSaltRewards(stakingRewardsEmitter, liquidityRewardsEmitter, exchangeConfig, rewardsConfig);

        uint256 initialPoolsCount = 4;
        bytes32[] memory poolIDs = new bytes32[](initialPoolsCount);
        poolIDs[0] = PoolUtils._poolID(salt, usds);
        poolIDs[1] = PoolUtils._poolID(wbtc, weth);
        poolIDs[2] = PoolUtils._poolID(weth, usds);
        poolIDs[3] = PoolUtils._poolID(salt, wbtc);

        uint256 liquidityBootstrapAmount = 1000 ether;

        // move tokens to rewards contract
        vm.prank(DEPLOYER);
        salt.transfer(address(_saltRewards), liquidityBootstrapAmount);

        uint256 initialLiquidityEmitterBalance = salt.balanceOf(address(liquidityRewardsEmitter));

        // run `_sendInitialLiquidityRewards` function
        _saltRewards.sendInitialLiquidityRewards(liquidityBootstrapAmount, poolIDs);

        // verify the correct amount was transferred to liquidityRewardsEmitter
        uint256 expectedLiquidityEmitterBalance = initialLiquidityEmitterBalance + liquidityBootstrapAmount;
        assertEq(salt.balanceOf(address(liquidityRewardsEmitter)), expectedLiquidityEmitterBalance, "LiquidityRewardsEmitter hasn't received the correct amount of Salt");

        uint256 expectedPerPoolAmount = liquidityBootstrapAmount / initialPoolsCount;
        uint256[] memory pendingRewards = liquidityRewardsEmitter.pendingRewardsForPools(poolIDs);

        for (uint256 i = 0; i < initialPoolsCount; i++) {
            assertEq(pendingRewards[i], expectedPerPoolAmount, "Pool did not receive the expected amount of initial liquidity rewards");
        }
    }


    // A unit test that _sendInitialStakingRewards sends the correct staking bootstrap amount to the stakingRewardsEmitter
	function testSendInitialStakingRewardsTransfersCorrectAmount() public {
        TestSaltRewards _saltRewards = new TestSaltRewards(stakingRewardsEmitter, liquidityRewardsEmitter, exchangeConfig, rewardsConfig);

        vm.prank(DEPLOYER);
        salt.transfer(address(_saltRewards), 5 ether);

        uint256 stakingBootstrapAmount = 5 ether;

        uint256 initialStakingRewardsEmitterBalance = salt.balanceOf(address(stakingRewardsEmitter));

        vm.prank(DEPLOYER);
        _saltRewards.sendInitialStakingRewards(stakingBootstrapAmount);

        uint256 finalStakingRewardsEmitterBalance = salt.balanceOf(address(stakingRewardsEmitter));
        uint256 expectedStakingRewardsEmitterBalance = initialStakingRewardsEmitterBalance + stakingBootstrapAmount;

        assertEq(finalStakingRewardsEmitterBalance, expectedStakingRewardsEmitterBalance, "StakingRewardsEmitter did not receive the correct bootstrap amount");
    }


    // A unit test that confirms no action is taken in performUpkeep when saltRewardsToDistribute is zero
    function testPerformUpkeep_NoActionWhenSaltRewardsToDistributeIsZero() public {

        TestSaltRewards testSaltRewards2 = new TestSaltRewards(stakingRewardsEmitter, liquidityRewardsEmitter, exchangeConfig, rewardsConfig);


        // Arrange: We will not transfer any SALT to the SaltRewards contract,
        // so the balance should be zero.

        // Act: Call the performUpkeep function
        bytes32[] memory poolIDs = new bytes32[](0);
        uint256[] memory profitsForPools = new uint256[](0);
        vm.prank(address(exchangeConfig.upkeep()));
        testSaltRewards2.performUpkeep(poolIDs, profitsForPools);

        // Assert: Since there is 0 SALT to distribute, no action should be taken,
        // and balances should remain unchanged.
        assertEq(salt.balanceOf(address(stakingRewardsEmitter)), 0, "No SALT should have been distributed to the stakingRewardsEmitter");
        assertEq(salt.balanceOf(address(liquidityRewardsEmitter)), 0, "No SALT should have been distributed to the liquidityRewardsEmitter");
        assertEq(salt.balanceOf(address(testSaltRewards2)), 0, "No SALT should have been distributed at all");
    }


    // A unit test for _sendLiquidityRewards to ensure directRewardsForSaltUSDS is not included for other pool IDs except saltUSDSPoolID
    function testSendLiquidityRewardsExcludesDirectRewardsForNonSaltUSDSPools() public {
        TestSaltRewards _saltRewards = new TestSaltRewards(stakingRewardsEmitter, liquidityRewardsEmitter, exchangeConfig, rewardsConfig);

        vm.prank(DEPLOYER);
        salt.transfer(address(_saltRewards), 100 ether);

		IERC20 newToken = new TestERC20( "TEST", 18 );

        bytes32 saltUSDSPoolIDTest = PoolUtils._poolID(salt, usds);
        bytes32 otherPoolIDTest = PoolUtils._poolID(newToken, usds);

		vm.prank(address(dao));
		poolsConfig.whitelistPool(pools, newToken, usds);

        // Set pool IDs and profits with one pool being the saltUSDSPoolID and another being any other pool
        bytes32[] memory poolIDs = new bytes32[](2);
        poolIDs[0] = saltUSDSPoolIDTest;
        poolIDs[1] = otherPoolIDTest;

        uint256[] memory profitsForPools = new uint256[](2);
        profitsForPools[0] = 10 ether; // Profits for saltUSDSPoolID
        profitsForPools[1] = 20 ether; // Profits for otherPoolIDTest

        // Balance of contract before running sendLiquidityRewards
        uint256 initialSaltContractBalance = salt.balanceOf(address(_saltRewards));

        // Call sendLiquidityRewards, which should include directRewardsForSaltUSDSPoolID only for saltUSDSPoolID
        _saltRewards.sendLiquidityRewards(40 ether, 1 ether, poolIDs, profitsForPools);

        // There should be no revert, but let's calculate the rewards we expect to be sent
        uint256 totalProfits = profitsForPools[0] + profitsForPools[1];
        uint256 saltUSDSPoolRewards = 1 ether + (40 ether * profitsForPools[0]) / totalProfits;
        uint256 otherPoolRewards = (40 ether * profitsForPools[1]) / totalProfits;

        // Retrieve pending rewards from emitter to check correct distribution
        uint256[] memory pendingRewards = liquidityRewardsEmitter.pendingRewardsForPools(poolIDs);

        // Expectations after running the function. Ensure that directRewardsForSaltUSDS is not included for otherPoolIDTest
        assertEq(salt.balanceOf(address(_saltRewards)), initialSaltContractBalance - 40 ether - 1 ether + 1, "SendLiquidityRewards did not emit correct SALT from contract balance.");
        assertEq(pendingRewards[0], saltUSDSPoolRewards, "SendLiquidityRewards did not allocate correct SALT to saltUSDSPoolID with direct rewards.");
        assertEq(pendingRewards[1], otherPoolRewards, "SendLiquidityRewards incorrectly allocated direct SALT rewards to pools other than saltUSDSPoolID.");
    }
	}

