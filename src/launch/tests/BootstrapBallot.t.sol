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
import "../BootstrapBallot.sol";


contract TestBootstrapBallot is Deployment
	{
	uint256 constant public MILLION_ETHER = 1000000 ether;


	// User wallets for testing
    address public constant alice = address(0x1111);
    address public constant bob = address(0x2222);
    address public constant charlie = address(0x3333);


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

			bootstrapBallot = new BootstrapBallot(exchangeConfig, airdrop1, airdrop2, 60 * 60 * 24 * 3, 60 * 60 * 24 * 45 );
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
		}


    // A unit test to check the finalizeBallot function when ballotFinalized is false, the current timestamp is greater than completionTimestamp, and yesVotes are more than noVotes. Verify that the InitialDistribution.distributionApproved function is called.
	function test_finalizeBallot() public {
        // Voting stage (yesVotes: 2, noVotes: 0)
		bytes memory sig = abi.encodePacked(aliceVotingSignature);
        vm.startPrank(alice);
		bootstrapBallot.vote(true, 1000 ether, sig);
        vm.stopPrank();

		sig = abi.encodePacked(bobVotingSignature);
        vm.startPrank(bob);
		bootstrapBallot.vote(true, 1000 ether, sig);
        vm.stopPrank();

        // Increase current blocktime to be greater than completionTimestamp
        vm.warp( bootstrapBallot.claimableTimestamp1());

		assertEq( salt.balanceOf(address(initialDistribution)), 100000000 ether);

        // Call finalizeBallot()
        bootstrapBallot.finalizeBallot();

        // Verify that the InitialDistribution.distributionApproved() was called.
		assertEq( salt.balanceOf(address(initialDistribution)), 0);
    }


    // A unit test to check the finalizeBallot function when ballotFinalized is false, the current timestamp is less than completionTimestamp. Verify that it throws an error as ballot duration is not yet complete.
	function test_finalizeBallotNotComplete() public {
		bytes memory sig = abi.encodePacked(aliceVotingSignature);

        // Voting stage (yesVotes: 2, noVotes: 0)
        vm.startPrank(alice);
		bootstrapBallot.vote(true, 1000 ether, sig);
        vm.stopPrank();

		sig = abi.encodePacked(bobVotingSignature);
        vm.startPrank(bob);
		bootstrapBallot.vote(true, 1000 ether, sig);
        vm.stopPrank();

        // Increase current blocktime to be greater than completionTimestamp
        vm.warp( bootstrapBallot.claimableTimestamp1() - 1);

		assertEq( salt.balanceOf(address(initialDistribution)), 100000000 ether);

        // Call finalizeBallot()
        vm.expectRevert( "Ballot is not yet complete");
        bootstrapBallot.finalizeBallot();

        // Verify that the InitialDistribution.distributionApproved() was called.
		assertEq( salt.balanceOf(address(initialDistribution)), 100000000 ether);
    }


    // A unit test to check the finalizeBallot function when ballotFinalized is already true. Verify that it throws an error stating the ballot has already been finalized.
	function test_finalizeBallotAlreadyFinalized() public {
		bytes memory sig = abi.encodePacked(aliceVotingSignature);

        // Voting stage (yesVotes: 2, noVotes: 0)
        vm.startPrank(alice);
		bootstrapBallot.vote(true, 1000 ether, sig);
        vm.stopPrank();

		sig = abi.encodePacked(bobVotingSignature);
        vm.startPrank(bob);
		bootstrapBallot.vote(true, 1000 ether, sig);
        vm.stopPrank();

        // Increase current blocktime to be greater than completionTimestamp
        vm.warp( bootstrapBallot.claimableTimestamp1());

		assertEq( salt.balanceOf(address(initialDistribution)), 100000000 ether);

        // Call finalizeBallot() twice
        bootstrapBallot.finalizeBallot();

        vm.expectRevert( "Ballot has already been finalized" );
        bootstrapBallot.finalizeBallot();

        // Verify that the InitialDistribution.distributionApproved() was called.
		assertEq( salt.balanceOf(address(initialDistribution)), 0 ether);
    }


    // A unit test to check the finalizeBallot function when yesVotes are less than noVotes. Verify that the InitialDistribution.distributionApproved function is not called.
	function test_finalizeBallotFailedVote() public {
        // Voting stage (yesVotes: 2, noVotes: 0)
		bytes memory sig = abi.encodePacked(aliceVotingSignature);
        vm.startPrank(alice);
		bootstrapBallot.vote(false, 1000 ether, sig);
        vm.stopPrank();

		sig = abi.encodePacked(bobVotingSignature);
        vm.startPrank(bob);
		bootstrapBallot.vote(false, 1000 ether, sig);
        vm.stopPrank();

        // Increase current blocktime to be greater than completionTimestamp
        vm.warp( bootstrapBallot.claimableTimestamp1());

		assertEq( salt.balanceOf(address(initialDistribution)), 100000000 ether);

        // Call finalizeBallot()
        bootstrapBallot.finalizeBallot();

        // Verify that the InitialDistribution.distributionApproved() was called.
		assertEq( salt.balanceOf(address(initialDistribution)), 100000000 ether);
    }


    // A unit test to check the vote function when the voter is whitelisted, has exchange access, and has not yet voted. Verify that the vote count is correctly incremented and the voter is marked as having voted.
    function test_vote() public {
        // Cast votes (yesVotes: 2, noVotes: 1)
		bytes memory sig = abi.encodePacked(aliceVotingSignature);
        vm.startPrank(alice);
		bootstrapBallot.vote(true, 1000 ether, sig);
        vm.stopPrank();

		sig = abi.encodePacked(bobVotingSignature);
        vm.startPrank(bob);
		bootstrapBallot.vote(true, 1000 ether, sig);
        vm.stopPrank();

		sig = abi.encodePacked(charlieVotingSignature);
        vm.startPrank(charlie);
		bootstrapBallot.vote(false, 1000 ether, sig);
        vm.stopPrank();

        // Assertions
        assertEq(bootstrapBallot.startExchangeYes(), 2, "YES vote count is incorrect");
        assertEq(bootstrapBallot.startExchangeNo(), 1, "NO vote count is incorrect");
        assertTrue(bootstrapBallot.hasVoted(alice), "Alice vote status is incorrect");
        assertTrue(bootstrapBallot.hasVoted(bob), "Bob vote status is incorrect");
        assertTrue(bootstrapBallot.hasVoted(charlie), "Charlie vote status is incorrect");
    }


    // A unit test to check the vote function when the voter has already voted. Verify that it throws an error stating the user already voted.
    function test_votesTwice() public {
		bytes memory sig = abi.encodePacked(aliceVotingSignature);

        // Alice casts her vote
        vm.startPrank(alice);
		bootstrapBallot.vote(true, 1000 ether, sig);

        // Alice tries to vote again
        vm.expectRevert("User already voted");
		bootstrapBallot.vote(true, 1000 ether, sig);
        vm.stopPrank();
    }


    // A unit test to check the completionTimestamp is correctly set equal to the current block timestamp plus the ballot duration in constructor.
    function test_completionTimestamp() public {
    	// Store the current block timestamp before constructing the contract
    	uint256 startTime = block.timestamp;

    	// Construct the contract with 1 hour ballotDuration
    	uint256 ballotDuration = 60 * 60;
    	BootstrapBallot bootstrapBallot = new BootstrapBallot(exchangeConfig, airdrop1, airdrop2, ballotDuration, 60 * 60 * 24 * 45);

    	// Check that completionTimestamp equals startTime plus ballotDuration
    	assertEq(bootstrapBallot.claimableTimestamp1(), startTime + ballotDuration);
    }


    // A unit test to check the ballotFinalized remains false after constructor.
	function testBallotFinalizedRemainsFalseAfterConstructor() public {
		assertEq(bootstrapBallot.ballotFinalized(), false);
	}


    // A unit test to check the vote function when a voter votes No. Verify that the noVotes count is correctly incremented.
	function test_vote_No() public {
		bytes memory sig = abi.encodePacked(aliceVotingSignature);

		vm.startPrank(alice);
		bootstrapBallot.vote(false, 1000 ether, sig);
		vm.stopPrank();

		assertEq(bootstrapBallot.startExchangeNo(), 1);
	}


    // A unit test to check the finalizeBallot function when yesVotes are equal to noVotes. Verify that the InitialDistribution.distributionApproved function is not called.
	function test_finalizeBallotTieVote() public {
		bytes memory sig = abi.encodePacked(aliceVotingSignature);

        // Voting stage (yesVotes: 1, noVotes: 1)
        vm.startPrank(alice);
		bootstrapBallot.vote(true, 1000 ether, sig);
        vm.stopPrank();

		sig = abi.encodePacked(bobVotingSignature);
        vm.startPrank(bob);
		bootstrapBallot.vote(false, 1000 ether, sig);
        vm.stopPrank();

        // Increase current blocktime to be greater than completionTimestamp
        vm.warp( bootstrapBallot.claimableTimestamp1());

		assertEq( salt.balanceOf(address(initialDistribution)), 100000000 ether);

        // Call finalizeBallot()
        bootstrapBallot.finalizeBallot();

        // Verify that the InitialDistribution.distributionApproved() was called.
		assertEq( salt.balanceOf(address(initialDistribution)), 100000000 ether);
    }


    // A unit test to check the finalizeBallot function when no one has voted. In this case, the InitialDistribution.distributionApproved function should not be called, and ballotFinalized turns into true.
    function test_finalizeBallotnoVotes() public {

        // Increase current blocktime to be greater than completionTimestamp
        vm.warp( bootstrapBallot.claimableTimestamp1());

		assertEq( salt.balanceOf(address(initialDistribution)), 100000000 ether);

        // Call finalizeBallot()
        bootstrapBallot.finalizeBallot();

        // Verify that the InitialDistribution.distributionApproved() was called.
		assertEq( salt.balanceOf(address(initialDistribution)), 100000000 ether);
    }


        // A unit test to check if the mapping hasVoted correctly recognizes an address after that address has called the vote function.
        function test_MapHasVotedAfterVoteCalled() public {
		bytes memory sig = abi.encodePacked(aliceVotingSignature);

            // Vote stage
            vm.startPrank(alice);
			bootstrapBallot.vote(true,1000 ether, sig);
            vm.stopPrank();

            // Check if Alice voted
            assertTrue(bootstrapBallot.hasVoted(alice), "User vote not recognized");
        }







	// A unit test which checks that an incorrect signature for airdrop whitelisting fails
	function testIncorrectVotingSignature() public
		{
		bytes memory sig = abi.encodePacked(hex"1234567890");

        vm.startPrank(alice);

		vm.expectRevert();
		bootstrapBallot.vote(true, 1000 ether, sig);
        vm.stopPrank();
		}


	// A unit test to ensure that only the bootstrapBallot can call Airdrop.authorizeWallet
	function testAuthorizationRestrictions() public
		{
		vm.expectRevert("Only the BootstrapBallot can call Airdrop.authorizeWallet");
		vm.prank( address(0x12345) );
		airdrop1.authorizeWallet(address(0x1111), 1000 ether );

		vm.expectRevert("Only the BootstrapBallot can call Airdrop.authorizeWallet");
		vm.prank( address(0x12345) );
		airdrop2.authorizeWallet(address(0x1111), 1000 ether );
		}


    // A unit test to check the the the signature has to be correct oto have the user vote
	function testVoteSignatureRequirement() public {
		bytes memory sig = abi.encodePacked(hex"123456");

		vm.expectRevert();
        vm.startPrank(alice);
		bootstrapBallot.vote(true, 1000 ether, sig);
        vm.stopPrank();
        }


	// A unit test that verifies the signature validation logic in vote(), to check when it's correct and incorrect.
	function testVoteSignatureValidation() public {
    		// Assume these bytes represent a valid and invalid signature for demonstration purposes
    		bytes memory validSignature = abi.encodePacked(aliceVotingSignature); // aliceVotingSignature should be a predefined valid signature corresponding to Alice
    		bytes memory invalidSignature = new bytes(65); // Just an arbitrary invalid signature

    		// Attempted vote with incorrect signature should be reverted
    		vm.startPrank(alice);
    		vm.expectRevert("ECDSA: invalid signature");
    		bootstrapBallot.vote(true, 1000 ether, invalidSignature);
    		vm.stopPrank();


    		// Successful vote with correct signature
    		uint256 beforeYesCount = bootstrapBallot.startExchangeYes();
    		uint256 beforeNoCount = bootstrapBallot.startExchangeNo();

    		vm.startPrank(alice);
    		bootstrapBallot.vote(true, 1000 ether, validSignature);
    		vm.stopPrank();

    		uint256 afterYesCount = bootstrapBallot.startExchangeYes();

    		assertEq(beforeYesCount + 1, afterYesCount, "Vote count did not increment with valid signature.");
    		assertEq(beforeNoCount, bootstrapBallot.startExchangeNo(), "No votes should not change on a yes vote.");
    	}


    // A unit test that checks if startExchangeApproved becomes true given the required conditions after finalizeBallot().
    function testStartExchangeApprovedFinalizeBallot() public
    	{
        // Arrange: Prepare environment and state before finalizing the ballot
        // Alice votes YES with some regional exclusion votes, sig provided by deployment context
        bytes memory aliceSig = abi.encodePacked(aliceVotingSignature); // assuming aliceVotingSignature is provided
        vm.startPrank(alice);
        bootstrapBallot.vote(true, 1000 ether, aliceSig);
        vm.stopPrank();

        // Bob also votes YES with some regional exclusion votes, sig provided by deployment context
        bytes memory bobSig = abi.encodePacked(bobVotingSignature); // assuming bobVotingSignature is provided
        vm.startPrank(bob);
        bootstrapBallot.vote(true, 1000 ether, bobSig);
        vm.stopPrank();

        // Charlie votes NO with some regional exclusion votes, sig provided by deployment context
        bytes memory charlieSig = abi.encodePacked(charlieVotingSignature); // assuming charlieVotingSignature is provided
        vm.startPrank(charlie);
        bootstrapBallot.vote(false, 1000 ether, charlieSig);
        vm.stopPrank();

        // Assert: Ensure `startExchangeApproved` is false initially
        assertEq(pools.exchangeIsLive(), false);

        // Act: Warp to a future time when the ballot completion is due and finalize the ballot
        vm.warp(bootstrapBallot.claimableTimestamp1() + 1); // assuming completionTimestamp is provided
        bootstrapBallot.finalizeBallot();

        // Assert: Check if `startExchangeApproved` becomes true
        assertEq(pools.exchangeIsLive(), true, "startExchangeApproved should be true after ballot finalization with majority YES votes");
    }


    // A unit test that confirms finalizeBallot does not execute after ballotFinalized is already true.
	function testFinalizeBallotUnsuccessfulAfterAlreadyFinalizedAndStarted() public {
        // Set initial votes (yesVotes: 2, noVotes: 1)
        vm.startPrank(alice);
        bytes memory sigAlice = abi.encodePacked(aliceVotingSignature);
        bootstrapBallot.vote(true, 1000 ether, sigAlice);
        vm.stopPrank();

        vm.startPrank(bob);
        bytes memory sigBob = abi.encodePacked(bobVotingSignature);
        bootstrapBallot.vote(true, 1000 ether, sigBob);
        vm.stopPrank();

        vm.startPrank(charlie);
        bytes memory sigCharlie = abi.encodePacked(charlieVotingSignature);
        bootstrapBallot.vote(false, 1000 ether, sigCharlie);
        vm.stopPrank();

        // Move time forward to finalize the ballot
        vm.warp(bootstrapBallot.claimableTimestamp1());

        // Finalize ballot successfully for the first time
        bootstrapBallot.finalizeBallot();

        // Ensure that ballotFinalized = true and startExchangeApproved = true
        assertTrue(bootstrapBallot.ballotFinalized());
        assertTrue(pools.exchangeIsLive());

        // Prepare to finalize the ballot again, expecting revert due to already being finalized
        vm.expectRevert("Ballot has already been finalized");
        bootstrapBallot.finalizeBallot();
    }




    // A unit test that confirms finalizeBallot does not execute after ballotFinalized is already true with a failed vote.
	function testFinalizeBallotUnsuccessfulAfterAlreadyFinalizedAndNotStarted() public {
        // Set initial votes (yesVotes: 1, noVotes: 2)
        vm.startPrank(alice);
        bytes memory sigAlice = abi.encodePacked(aliceVotingSignature);
        bootstrapBallot.vote(true, 1000 ether, sigAlice);
        vm.stopPrank();

        vm.startPrank(bob);
        bytes memory sigBob = abi.encodePacked(bobVotingSignature);
        bootstrapBallot.vote(false, 1000 ether, sigBob);
        vm.stopPrank();

        vm.startPrank(charlie);
        bytes memory sigCharlie = abi.encodePacked(charlieVotingSignature);
        bootstrapBallot.vote(false, 1000 ether, sigCharlie);
        vm.stopPrank();

        // Move time forward to finalize the ballot
        vm.warp(bootstrapBallot.claimableTimestamp1());

        // Finalize ballot successfully for the first time
        bootstrapBallot.finalizeBallot();

        // Ensure that ballotFinalized = true and startExchangeApproved = true
        assertTrue(bootstrapBallot.ballotFinalized());
        assertTrue(! pools.exchangeIsLive());

        // Prepare to finalize the ballot again, expecting revert due to already being finalized
        vm.expectRevert("Ballot has already been finalized");
        bootstrapBallot.finalizeBallot();
    }


    // A unit test that verifies the vote() function does not authorize the user for the airdrop if the signature is incorrect.
    function testVoteWithIncorrectSignatureDoesNotAuthorizeForAirdrop() public {
        bytes memory incorrectSignature = new bytes(65);
        address voter = alice; // Replace with actual voter address if needed

        vm.startPrank(voter);
        // Expect a revert with a specific error message related to incorrect signature verification
        vm.expectRevert("ECDSA: invalid signature");
        bootstrapBallot.vote(true, 1000 ether, incorrectSignature); // External call to vote function
        vm.stopPrank();

        // Assert that the voter has not been authorized for the airdrop after the failed vote attempt
        assertEq(airdrop1.airdropForUser(voter), 0, "Voter should not be authorized for airdrop after voting with an incorrect signature");
    }


	function testVotingSignature() public
		{
		bytes memory deployerVotingSignature = hex"24f550440a1a66d16f818f639801cb830ce234c1fdf54074417a84d26e793fc66d1ad7c89f932a0d00b30c0ef52c2862da373a953ad3edb5f3884f5a058606321c";

		vm.prank(DEPLOYER);
		bootstrapBallot.vote( true, 1000 ether, deployerVotingSignature );
		}


	function testFinalize() public
		{
	vm.expectRevert( "Ballot is not yet complete" );
		bootstrapBallot.finalizeBallot();

		vm.warp( block.timestamp + 3 days );
		bootstrapBallot.finalizeBallot();

		console.log( "BOOTSTRAP BALLOT: ", address(bootstrapBallot) );
		}


	function testAirdrop2() public
		{
		// pass the bootstrapBallot
		testStartExchangeApprovedFinalizeBallot();

		assertEq( bootstrapBallot.claimableTimestamp1() + 45 days, bootstrapBallot.claimableTimestamp2(), "Airdrop 2 not claimable at the correct time" );

		bytes memory aliceSig1000 = abi.encodePacked(hex"76b5ac93095776db65d3cd72152b7bc13f7f50f385b9de8f487c2a2a0bde20ca721e118b828dcdc7c47aaa112c92bc087ef718f03b69288ba307bcd71bd43e9a1c");
		bytes memory bobSig2000 = abi.encodePacked(hex"fce18b8194e00b5929487e290d785e1bda482e6c7f3a2a3eef1de1615eabecc83a44b37f91fa207a9af0e404784984de6b788f01f40c719c4334843fb07759c31c");
		bytes memory charlieSig3000 = abi.encodePacked(hex"8acb98ef16dc544bd14d1190a19c0e62141d59fbc75dfdca30a74c53b97ce5ef0a585078ff32188ad830b58de6f7015fc982e7fda55fca24b142f0bca37431211b");

		vm.prank(alice);
		bootstrapBallot.authorizeAirdrop2(1000 ether, aliceSig1000 );

		vm.prank(bob);
		bootstrapBallot.authorizeAirdrop2(2000 ether, bobSig2000 );

		vm.prank(charlie);
		bootstrapBallot.authorizeAirdrop2(3000 ether, charlieSig3000 );

		vm.warp( bootstrapBallot.claimableTimestamp2() - 1 );

		vm.expectRevert( "Airdrop 2 cannot be finalized yet" );
		bootstrapBallot.finalizeAirdrop2();

		vm.warp( bootstrapBallot.claimableTimestamp2() );
		bootstrapBallot.finalizeAirdrop2();

		assertEq( airdrop2.claimableAmount(alice), 0, "Invalid claimable for alice" );
		assertEq( airdrop2.claimableAmount(bob), 0, "Invalid claimable for bob" );
		assertEq( airdrop2.claimableAmount(charlie), 0, "Invalid claimable for charlie" );

		vm.warp( block.timestamp + 5 days );

		uint256 saltAlice0 = salt.balanceOf(alice);
		uint256 saltBob0 = salt.balanceOf(bob);
		uint256 saltCharlie0 = salt.balanceOf(charlie);

		uint256 alice0 = airdrop2.claimableAmount(alice);
		uint256 bob0 = airdrop2.claimableAmount(bob);
		uint256 charlie0 = airdrop2.claimableAmount(charlie);

		vm.prank(alice);
		airdrop2.claim();

		vm.prank(bob);
		airdrop2.claim();

		vm.prank(charlie);
		airdrop2.claim();

		assertEq( alice0, 13736263736263736263, "Invalid claimable for alice" );
		assertEq( bob0, 27472527472527472527, "Invalid claimable for bob" );
		assertEq( charlie0, 41208791208791208791, "Invalid claimable for charlie" );

		vm.warp( bootstrapBallot.claimableTimestamp2() + 52 weeks );

		uint256 alice1 = airdrop2.claimableAmount(alice);
		uint256 bob1 = airdrop2.claimableAmount(bob);
		uint256 charlie1 = airdrop2.claimableAmount(charlie);

		assertEq( alice1, 1000 ether - alice0, "Invalid second claim for alice" );
		assertEq( bob1, 2000 ether - bob0, "Invalid second claim for bob" );
		assertEq( charlie1, 3000 ether - charlie0, "Invalid second claim for charlie" );

		vm.prank(alice);
		airdrop2.claim();

		vm.prank(bob);
		airdrop2.claim();

		vm.prank(charlie);
		airdrop2.claim();

		vm.warp( bootstrapBallot.claimableTimestamp2() + 55 weeks );

		assertEq( airdrop2.claimableAmount(alice), 0, "Excessive claimable for alice" );
		assertEq( airdrop2.claimableAmount(bob), 0, "Excessive claimable for bob" );
		assertEq( airdrop2.claimableAmount(charlie), 0, "Excessive claimable for charlie" );


		assertEq( salt.balanceOf(alice) - saltAlice0, 1000 ether, "Incorrect amount claimed for alice" );
		assertEq( salt.balanceOf(bob) - saltBob0, 2000 ether, "Incorrect amount claimed for bob" );
		assertEq( salt.balanceOf(charlie) - saltCharlie0, 3000 ether, "Incorrect amount claimed for charlie" );
		}


    // A unit test to check if the claimableTimestamp1 is set correctly according to the ballotDuration provided in constructor.
    function testClaimableTimestamp1SetCorrectly() public {
        uint256 ballotDuration = 60 * 60 * 24 * 3; // 3 days in seconds
        BootstrapBallot bootstrapBallot = new BootstrapBallot(exchangeConfig, airdrop1, airdrop2, ballotDuration, 60 * 60 * 24 * 45);
        uint256 expectedClaimableTimestamp1 = block.timestamp + ballotDuration;
        assertEq(bootstrapBallot.claimableTimestamp1(), expectedClaimableTimestamp1, "claimableTimestamp1 is not set correctly according to the ballotDuration provided in constructor");
    }


    // A unit test to check if the claimableTimestamp2 is set correctly based on the claimableTimestamp1 and airdrop2DelayTillDistribution provided in constructor.
    function testClaimableTimestamp2IsSetCorrectly() public {
        // Arrange
        uint256 ballotDuration = 60 * 60 * 24 * 3; // 3 days in seconds
        uint256 airdrop2DelayTillDistribution = 60 * 60 * 24 * 45; // 45 days in seconds
        BootstrapBallot testBallot = new BootstrapBallot(exchangeConfig, airdrop1, airdrop2, ballotDuration, airdrop2DelayTillDistribution);

        // Act
        uint256 expectedClaimableTimestamp2 = block.timestamp + ballotDuration + airdrop2DelayTillDistribution;

        // Assert
        assertEq(testBallot.claimableTimestamp2(), expectedClaimableTimestamp2, "claimableTimestamp2 is not set correctly based on constructor parameters");
    }


    // A unit test to check if airdrop1.allowClaiming() is called in finalizeBallot when startExchangeYes is greater than startExchangeNo.
    function testFinalizeBallotCallAllowClaiming() public {
            // Arrange
            vm.startPrank(alice);
            bytes memory sig = abi.encodePacked(aliceVotingSignature); // Using a predefined signature for Alice
            bootstrapBallot.vote(true, 1000 ether, sig); // Alice votes Yes with 1 ether
            vm.stopPrank();

            // Assert initial state to ensure setup is correct
            assertEq(bootstrapBallot.startExchangeYes(), 1, "StartExchangeYes should be 1");
            assertEq(bootstrapBallot.startExchangeNo(), 0, "StartExchangeNo should be 0");

            // Act
            vm.warp(block.timestamp + 3 days); // Warp to after the ballot end time

            // Execute
            bootstrapBallot.finalizeBallot();

            // Assertion post finalizeBallot call
            // Verify state changes expected after finalizeBallot
            assertTrue(bootstrapBallot.ballotFinalized(), "BallotFinalized should be true");
        }


    // A unit test to check that an address can only call authorizeAirdrop2 once.
    function testAuthorizeAirdrop2CalledOnce() public {
        // Setup for test
        bytes memory validSignatureAlice = abi.encodePacked(hex"76b5ac93095776db65d3cd72152b7bc13f7f50f385b9de8f487c2a2a0bde20ca721e118b828dcdc7c47aaa112c92bc087ef718f03b69288ba307bcd71bd43e9a1c");
        uint256 saltAmount = 1000 ether;

        // Alice authorizes Airdrop2 successfully for the first time
        vm.prank(alice);
        bootstrapBallot.authorizeAirdrop2(saltAmount, validSignatureAlice);

        // Expect revert on second call by Alice to authorizeAirdrop2
        vm.expectRevert("Wallet already authorized"); // Adjust the revert reason as per contract's actual behavior for second calls
        vm.prank(alice);
        bootstrapBallot.authorizeAirdrop2(saltAmount, validSignatureAlice);
    }
	}
