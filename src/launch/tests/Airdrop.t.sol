// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "forge-std/Test.sol";
import "../../dev/Deployment.sol";
import "../../root_tests/TestERC20.sol";
import "../../ExchangeConfig.sol";
import "../../pools/Pools.sol";
import "../../staking/Liquidity.sol";
import "../../staking/Staking.sol";
import "../../staking/Liquidity.sol";
import "../../rewards/RewardsEmitter.sol";
import "../../pools/PoolsConfig.sol";
import "../../AccessManager.sol";
import "../InitialDistribution.sol";
import "../../Upkeep.sol";
import "../../dao/Proposals.sol";
import "../../dao/DAO.sol";


contract TestAirdrop is Deployment
	{
	uint256 constant public MILLION_ETHER = 1000000 ether;


	// User wallets for testing
    address public constant alice = address(0x1111);
    address public constant bob = address(0x2222);


	constructor()
		{
		// If $COVERAGE=yes, create an instance of the contract so that coverage testing can work
		// Otherwise, what is tested is the actual deployed contract on the blockchain (as specified in Deployment.sol)
		if ( keccak256(bytes(vm.envString("COVERAGE" ))) == keccak256(bytes("yes" )))
			{
			// Transfer the salt from the original initialDistribution to the DEPLOYER
			vm.prank(address(initialDistribution));
			salt.transfer(DEPLOYER, 100 * MILLION_ETHER);

			vm.startPrank(DEPLOYER);

			poolsConfig = new PoolsConfig();

			exchangeConfig = new ExchangeConfig(salt, wbtc, weth, usdc, usdt, teamWallet );

		pools = new Pools(exchangeConfig, poolsConfig);
		staking = new Staking( exchangeConfig, poolsConfig, stakingConfig );
		liquidity = new Liquidity(pools, exchangeConfig, poolsConfig, stakingConfig);

			stakingRewardsEmitter = new RewardsEmitter( staking, exchangeConfig, poolsConfig, rewardsConfig, false );
			liquidityRewardsEmitter = new RewardsEmitter( liquidity, exchangeConfig, poolsConfig, rewardsConfig, true );

			emissions = new Emissions( saltRewards, exchangeConfig, rewardsConfig );

		// Whitelist the pools
		poolsConfig.whitelistPool(salt, usdc);
		poolsConfig.whitelistPool(salt, weth);
		poolsConfig.whitelistPool(weth, usdc);
		poolsConfig.whitelistPool(weth, usdt);
		poolsConfig.whitelistPool(wbtc, usdc);
		poolsConfig.whitelistPool(wbtc, weth);
		poolsConfig.whitelistPool(usdc, usdt);

			proposals = new Proposals( staking, exchangeConfig, poolsConfig, daoConfig );

			address oldDAO = address(dao);
			dao = new DAO( pools, proposals, exchangeConfig, poolsConfig, stakingConfig, rewardsConfig, daoConfig, liquidityRewardsEmitter);

			airdrop1 = new Airdrop(exchangeConfig, IAirdrop(address(0x0)));
			airdrop2 = new Airdrop(exchangeConfig, IAirdrop(address(0x0)));

			accessManager = new AccessManager(dao);

			saltRewards = new SaltRewards(stakingRewardsEmitter, liquidityRewardsEmitter, exchangeConfig, rewardsConfig);

			upkeep = new Upkeep(pools, exchangeConfig, poolsConfig, daoConfig, saltRewards, emissions, dao);

			initialDistribution = new InitialDistribution(salt, poolsConfig, emissions, bootstrapBallot, dao, daoVestingWallet, teamVestingWallet, saltRewards);

			pools.setContracts(dao, liquidity);

			exchangeConfig.setContracts(dao, upkeep, initialDistribution, teamVestingWallet, daoVestingWallet );
			exchangeConfig.setAccessManager(accessManager);

			// Transfer ownership of the newly created config files to the DAO
			Ownable(address(exchangeConfig)).transferOwnership( address(dao) );
			Ownable(address(poolsConfig)).transferOwnership( address(dao) );
			vm.stopPrank();

			vm.startPrank(address(oldDAO));
			Ownable(address(stakingConfig)).transferOwnership( address(dao) );
			Ownable(address(rewardsConfig)).transferOwnership( address(dao) );
			Ownable(address(daoConfig)).transferOwnership( address(dao) );
			vm.stopPrank();

			// Transfer SALT to the new InitialDistribution contract
			vm.startPrank(DEPLOYER);
			salt.transfer(address(initialDistribution), 100 * MILLION_ETHER);
			vm.stopPrank();
			}

		grantAccessAlice();
		grantAccessBob();
		grantAccessCharlie();
		grantAccessDeployer();
		grantAccessDefault();

		whitelistAlice();
		}


	// A unit test to ensure that a authorizeWallet works correctly and cannot be called after claiming is allowed
	function testAirdropAuthorization() external {

    	// Check that Alice is already whitelisted
    	assertEq(airdrop1.airdropForUser(alice), 1000 ether, "Alice should be whitelisted");
    	assertEq(airdrop2.airdropForUser(alice), 1000 ether, "Alice should be whitelisted");

    	assertEq(airdrop1.airdropForUser(bob), 0, "Bob shouldn't be whitelisted");
    	assertEq(airdrop2.airdropForUser(bob), 0, "Bob shouldn't be whitelisted");

    	// Whitelist Bob
    	this.whitelistBob();

    	vm.expectRevert("Wallet already authorized");
    	this.whitelistBob();

    	assertEq(airdrop1.airdropForUser(bob), 1000 ether, "Bob should be whitelisted");
    	assertEq(airdrop2.airdropForUser(bob), 1000 ether, "Bob should be whitelisted");

    	// Try to whitelist when claimingAllowed is true, expect to revert
    	vm.startPrank(address(bootstrapBallot));
    	airdrop1.allowClaiming();

    	vm.expectRevert("Cannot authorize after claiming is allowed");
    	this.whitelistCharlie();
    }



	// A unit test to verify that the `allowClaiming` causes the claimingAllowed() function to return true
	function testAllowClaiming() external {
        // Check that claiming is initially not allowed
        assertFalse(airdrop1.claimingAllowed(), "Claiming 1 should not be allowed initially");
        assertFalse(airdrop2.claimingAllowed(), "Claiming 2 should not be allowed initially");

        vm.startPrank(address(bootstrapBallot));
        initialDistribution.distributionApproved(airdrop1, airdrop2);

        // Get initial salt balance of Airdrop contract
        uint256 initialSaltBalance1 = salt.balanceOf(address(airdrop1));
        uint256 initialSaltBalance2 = salt.balanceOf(address(airdrop2));
        assertEq( initialSaltBalance1, 3000000 ether);
        assertEq( initialSaltBalance2, 3000000 ether);

        // Check that claiming is now allowed
        airdrop1.allowClaiming();
        airdrop2.allowClaiming();

        assertTrue(airdrop1.claimingAllowed(), "Claiming should be allowed for airdrop 1");
        assertTrue(airdrop2.claimingAllowed(), "Claiming should be allowed for airdrop 2");
		 }


	// A unit test to ensure that claimableAmount returns the correct amount after a short amount of elapsed time
	function testClaimAirdrop() external {

    	assertFalse(airdrop1.claimingAllowed(), "Claiming should not be allowed for the test");

		// Revert as claiming is not allowed yet
    	vm.prank(alice);
    	vm.expectRevert("User has no claimable airdrop at this time");
    	airdrop1.claim();

    	// Approve the distribution to allow claiming
    	vm.prank(address(bootstrapBallot));
    	initialDistribution.distributionApproved(airdrop1, airdrop2);

    	vm.prank(address(bootstrapBallot));
		airdrop1.allowClaiming();
    	assertTrue(airdrop1.claimingAllowed(), "Claiming should be allowed for the test");

		vm.prank(address(dao));
		accessManager.excludedCountriesUpdated();

    	// Claim airdrop
    	vm.expectRevert( "User has no claimable airdrop at this time" );
    	vm.prank(alice);
    	airdrop1.claim();

		vm.warp( block.timestamp + 1 days );
		uint256 claimable = airdrop1.claimableAmount(alice);

		assertEq( claimable, 2747252747252747252, "Incorrect claimable amount for airdrop" );

		uint256 aliceBalance = salt.balanceOf( alice );

    	vm.prank(alice);
    	airdrop1.claim();

		assertEq( airdrop1.claimableAmount(alice), 0, "Alice should not be able to immediately claim" );

		uint256 aliceClaimed = salt.balanceOf( alice ) - aliceBalance;

    	// Verify that Alice successfully claimed
    	assertEq( aliceClaimed, claimable, "Incorrect amount claimed by alice" );
    }



    // A unit test that checks if authorizeWallet properly reverts when called by any address other than the BootstrapBallot
    function testAuthorizeWalletReverts() external {
        address unprivilegedUser = address(0xdead);

        vm.expectRevert("Only the BootstrapBallot can call Airdrop.authorizeWallet");
        airdrop1.authorizeWallet(unprivilegedUser, 1000 ether);

        vm.expectRevert("Only the BootstrapBallot can call Airdrop.authorizeWallet");
        airdrop2.authorizeWallet(unprivilegedUser, 1000 ether);
    }




    // A unit test that checks claiming reverts if non-authorized user tries to claim
    function testClaimingNonAuthorized() external {
    	vm.prank(address(bootstrapBallot));
    	initialDistribution.distributionApproved(airdrop1, airdrop2);

        // Claim Airdrop
        vm.expectRevert( "User has no claimable airdrop at this time" );
        vm.prank(bob);
        airdrop1.claim();
    }


    // A unit test to ensure that `claim` updates claimedPerUser mapping correctly for successive claims
    function testSuccessiveClaimsUpdateClaimedPerUserCorrectly() external {
	    	vm.prank(address(bootstrapBallot));
    		initialDistribution.distributionApproved(airdrop1, airdrop2);

            address user = address(0x1);
            uint256 saltAmount = 1000 ether;

            // Authorize user wallet with specific saltAmount before claiming is allowed
            vm.prank(address(bootstrapBallot));
            airdrop1.authorizeWallet(user, saltAmount);

            // Enable claiming
            vm.prank(address(bootstrapBallot));
            airdrop1.allowClaiming();

            // Fast forward to half of the vesting period to claim half of the airdrop
            vm.warp(block.timestamp + (26 weeks));

            // User claims airdrop (expecting half to be claimable)
            vm.prank(user);
            airdrop1.claim();

            // Check claimed amount for user is correct (half of the total airdrop)
            uint256 expectedClaimedAmountFirst = saltAmount / 2;
            assertEq(airdrop1.claimedByUser(user), expectedClaimedAmountFirst, "First claim amount incorrect");

            // Fast forward to the end of the vesting period to claim the rest
            vm.warp(block.timestamp + (26 weeks));

            // User claims the rest of their airdrop
            vm.prank(user);
            airdrop1.claim();

            // Check claimed amount for user is correct (all of the airdrop)
            assertEq(airdrop1.claimedByUser(user), saltAmount, "Second claim amount incorrect");
    }


    // A unit test to verify that after the full VESTING_PERIOD, claimableAmount equals the initial airdropPerUser amount minus already claimed amount
	function testClaimableAmountAfterFullVestingPeriod() external {
	    	vm.prank(address(bootstrapBallot));
    		initialDistribution.distributionApproved(airdrop1, airdrop2);

        vm.prank(address(bootstrapBallot));
        airdrop1.allowClaiming();

        uint256 startTimestamp = airdrop1.claimingStartTimestamp();

        vm.warp(startTimestamp + 26 weeks);

		vm.prank(alice);
		airdrop1.claim();

        assertEq( airdrop1.claimedByUser(alice), 500 ether );
        vm.warp(startTimestamp + 52 weeks);

        assertEq(airdrop1.claimableAmount(alice), 500 ether, "Claimable amount should equal initial airdrop amount minus already claimed amount after full VESTING_PERIOD.");
    }


    // A unit test to confirm that the airdropForUser function returns 0 for wallets that haven't been authorized
	function testAirdropForUnauthorizedWalletReturnsZero() external {
        address unauthorizedWallet = address(0x9191);

        // Expect the airdropForUser function to return 0 for an unauthorized wallet
        uint256 unauthorizedWalletAirdropAmount = airdrop1.airdropForUser(unauthorizedWallet);
        assertEq(unauthorizedWalletAirdropAmount, 0, "Unauthorized wallet should not have any airdrop allocated");
    }


    // A unit test to validate that claimableAmount accurately returns 0 for a user with no airdrop authorized
	function testClaimableAmountForUserWithNoAirdropAuthorized() external {
        address unprivilegedUser = address(0xdead);

        // Authorize claiming mechanism without authorizing any airdrop amount for unprivilegedUser
        vm.startPrank(address(exchangeConfig.initialDistribution().bootstrapBallot()));
        airdrop1.allowClaiming();
        vm.stopPrank();

        // Should accurately return 0 for a user with no airdrop authorized
        uint256 claimableAmount = airdrop1.claimableAmount(unprivilegedUser);
        assertEq(claimableAmount, 0, "claimableAmount should be 0 for user with no airdrop authorized");
    }



    // A unit test to verify that the constructor sets the exchangeConfig and salt variables as expected
	function testConstructorSetsExchangeConfigAndSaltAsExpected() external {
        IExchangeConfig expectedExchangeConfig = exchangeConfig; // Assuming `exchangeConfig` is accessible in the test environment.
        ISalt expectedSalt = salt; // Assuming `salt` is accessible in the test environment.

        // Deploys a new Airdrop contract instance within the test environment.
        Airdrop airdropTestInstance = new Airdrop(expectedExchangeConfig, IAirdrop(address(0x0)));

        // Retrieves the actual `exchangeConfig` and `salt` from the deployed `Airdrop` instance.
        IExchangeConfig actualExchangeConfig = airdropTestInstance.exchangeConfig();
        ISalt actualSalt = airdropTestInstance.salt();

        // Asserts that the actual `exchangeConfig` and `salt` are as expected.
        assertEq(address(actualExchangeConfig), address(expectedExchangeConfig), "Constructor did not set exchangeConfig as expected.");
        assertEq(address(actualSalt), address(expectedSalt), "Constructor did not set salt as expected.");
    }


    // A unit test to ensure that claimingAllowed returns false before allowClaiming is called
	function testClaimingAllowedReturnsFalseBeforeAllowClaiming() external {
        // Check claimingAllowed returns false before allowClaiming is called for airdrop1
        assertFalse(airdrop1.claimingAllowed(), "Claiming should not be allowed initially for airdrop1");

        // Check claimingAllowed returns false before allowClaiming is called for airdrop2
        assertFalse(airdrop2.claimingAllowed(), "Claiming should not be allowed initially for airdrop2");
    }


    // A unit test to check claimableAmount correctly handles scenarios when the full VESTING_PERIOD has not yet passed but some time has elapsed
	function testClaimableAmountBeforeCompleteVesting() external {
	    	vm.prank(address(bootstrapBallot));
    		initialDistribution.distributionApproved(airdrop1, airdrop2);


        address user = alice; // Using alice for this test
        uint256 airdropAmount = 1000 ether; // Assume alice is authorized to claim this amount
        uint256 claimTime = 20 weeks; // Time before the full vesting period has elapsed

        // Set up the environment for the test
        vm.prank(address(bootstrapBallot));
        airdrop1.allowClaiming();

        uint256 claimingStartTimestamp = airdrop1.claimingStartTimestamp();

        // Fast forward time by claimTime
        vm.warp(claimingStartTimestamp + claimTime);

        // Calculate expected amount claimable by this time
        uint256 timeElapsed = claimTime;
        uint256 vestedAmount = (airdropAmount * timeElapsed) / 52 weeks;
        uint256 expectedClaimableAmount = vestedAmount; // No previous claims made

        // Fetch the actual claimable amount
        uint256 actualClaimableAmount = airdrop1.claimableAmount(user);

        // Assert expected claimable amount matches the actual claimable amount
        assertEq(actualClaimableAmount, expectedClaimableAmount, "Claimable amount does not match expected value after partial vesting period has elapsed.");
    }

	}
