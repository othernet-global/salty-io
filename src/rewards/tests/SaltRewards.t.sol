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
        poolIDs[0] = PoolUtils._poolIDOnly(salt,usds);
		poolIDs[1] = PoolUtils._poolIDOnly(token1, token2);

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
            poolIDs[0] = PoolUtils._poolIDOnly(salt, usds);
            poolIDs[1] = PoolUtils._poolIDOnly(wbtc, weth);
            poolIDs[2] = PoolUtils._poolIDOnly(weth, usds);

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
        poolIDs[0] = PoolUtils._poolIDOnly(salt, usds);

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
        poolIDs[0] = PoolUtils._poolIDOnly(salt,usds);
		poolIDs[1] = PoolUtils._poolIDOnly(token1, token2);

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
        poolIDs[0] = PoolUtils._poolIDOnly(salt,usds);
		poolIDs[1] = PoolUtils._poolIDOnly(token1, token2);

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
            poolIDs[0] = PoolUtils._poolIDOnly(salt,usds);

            uint256[] memory profitsForPools = new uint256[](1);
            profitsForPools[0] = 10 ether;

            // Balance of contract before running sendLiquidityRewards
			_saltRewards.sendStakingRewards(0 ether);
            _saltRewards.sendLiquidityRewards(40 ether, 1 ether, poolIDs, profitsForPools);

            // It should be equal to the dust remaining in the contract plus the initial pendingRewardsSaltUSDS
            assertEq(salt.balanceOf(address(_saltRewards)), 9 ether, "The remaining dust was not added to pendingRewardsSaltUSDS");
        }


	}

