// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "forge-std/Test.sol";
import "../../dev/Deployment.sol";
import "../../root_tests/TestERC20.sol";
import "../../ExchangeConfig.sol";
import "../../pools/Pools.sol";
import "../../staking/Liquidity.sol";
import "../../staking/Staking.sol";
import "../../stable/CollateralAndLiquidity.sol";
import "../../rewards/RewardsEmitter.sol";
import "../../price_feed/tests/IForcedPriceFeed.sol";
import "../../pools/PoolsConfig.sol";
import "../../price_feed/PriceAggregator.sol";
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
			usds = new USDS();

			exchangeConfig = new ExchangeConfig(salt, wbtc, weth, dai, usds, managedTeamWallet );

			priceAggregator = new PriceAggregator();
			priceAggregator.setInitialFeeds( IPriceFeed(address(forcedPriceFeed)), IPriceFeed(address(forcedPriceFeed)), IPriceFeed(address(forcedPriceFeed)) );

		liquidizer = new Liquidizer(exchangeConfig, poolsConfig);
		pools = new Pools(exchangeConfig, poolsConfig);
		staking = new Staking( exchangeConfig, poolsConfig, stakingConfig );
		collateralAndLiquidity = new CollateralAndLiquidity(pools, exchangeConfig, poolsConfig, stakingConfig, stableConfig, priceAggregator, liquidizer);
		liquidizer.setContracts(collateralAndLiquidity, pools, dao);

			stakingRewardsEmitter = new RewardsEmitter( staking, exchangeConfig, poolsConfig, rewardsConfig, false );
			liquidityRewardsEmitter = new RewardsEmitter( collateralAndLiquidity, exchangeConfig, poolsConfig, rewardsConfig, true );

			emissions = new Emissions( saltRewards, exchangeConfig, rewardsConfig );

			poolsConfig.whitelistPool( pools,   salt, wbtc);
			poolsConfig.whitelistPool( pools,   salt, weth);
			poolsConfig.whitelistPool( pools,   salt, usds);
			poolsConfig.whitelistPool( pools,   wbtc, usds);
			poolsConfig.whitelistPool( pools,   weth, usds);
			poolsConfig.whitelistPool( pools,   wbtc, dai);
			poolsConfig.whitelistPool( pools,   weth, dai);
			poolsConfig.whitelistPool( pools,   usds, dai);
			poolsConfig.whitelistPool( pools,   wbtc, weth);

			proposals = new Proposals( staking, exchangeConfig, poolsConfig, daoConfig );

			address oldDAO = address(dao);
			dao = new DAO( pools, proposals, exchangeConfig, poolsConfig, stakingConfig, rewardsConfig, stableConfig, daoConfig, priceAggregator, liquidityRewardsEmitter, collateralAndLiquidity);

			airdrop = new Airdrop(exchangeConfig, staking);

			accessManager = new AccessManager(dao);

			saltRewards = new SaltRewards(stakingRewardsEmitter, liquidityRewardsEmitter, exchangeConfig, rewardsConfig);

			upkeep = new Upkeep(pools, exchangeConfig, poolsConfig, daoConfig, stableConfig, priceAggregator, saltRewards, collateralAndLiquidity, emissions, dao);

			bootstrapBallot = new BootstrapBallot(exchangeConfig, airdrop, 60 * 60 * 24 * 3 );
			initialDistribution = new InitialDistribution(salt, poolsConfig, emissions, bootstrapBallot, dao, daoVestingWallet, teamVestingWallet, airdrop, saltRewards, collateralAndLiquidity);

			pools.setContracts(dao, collateralAndLiquidity);

			usds.setCollateralAndLiquidity(collateralAndLiquidity);

			exchangeConfig.setContracts(dao, upkeep, initialDistribution, airdrop, teamVestingWallet, daoVestingWallet );
			exchangeConfig.setAccessManager(accessManager);

			// Transfer ownership of the newly created config files to the DAO
			Ownable(address(exchangeConfig)).transferOwnership( address(dao) );
			Ownable(address(poolsConfig)).transferOwnership( address(dao) );
			Ownable(address(priceAggregator)).transferOwnership(address(dao));
			vm.stopPrank();

			vm.startPrank(address(oldDAO));
			Ownable(address(stakingConfig)).transferOwnership( address(dao) );
			Ownable(address(rewardsConfig)).transferOwnership( address(dao) );
			Ownable(address(stableConfig)).transferOwnership( address(dao) );
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
		bootstrapBallot.vote(true, sig);
        vm.stopPrank();

		sig = abi.encodePacked(bobVotingSignature);
        vm.startPrank(bob);
		bootstrapBallot.vote(true, sig);
        vm.stopPrank();

        // Increase current blocktime to be greater than completionTimestamp
        vm.warp( bootstrapBallot.completionTimestamp());

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
		bootstrapBallot.vote(true, sig);
        vm.stopPrank();

		sig = abi.encodePacked(bobVotingSignature);
        vm.startPrank(bob);
		bootstrapBallot.vote(true, sig);
        vm.stopPrank();

        // Increase current blocktime to be greater than completionTimestamp
        vm.warp( bootstrapBallot.completionTimestamp() - 1);

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
		bootstrapBallot.vote(true, sig);
        vm.stopPrank();

		sig = abi.encodePacked(bobVotingSignature);
        vm.startPrank(bob);
		bootstrapBallot.vote(true, sig);
        vm.stopPrank();

        // Increase current blocktime to be greater than completionTimestamp
        vm.warp( bootstrapBallot.completionTimestamp());

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
		bootstrapBallot.vote(false, sig);
        vm.stopPrank();

		sig = abi.encodePacked(bobVotingSignature);
        vm.startPrank(bob);
		bootstrapBallot.vote(false, sig);
        vm.stopPrank();

        // Increase current blocktime to be greater than completionTimestamp
        vm.warp( bootstrapBallot.completionTimestamp());

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
		bootstrapBallot.vote(true, sig);
        vm.stopPrank();

		sig = abi.encodePacked(bobVotingSignature);
        vm.startPrank(bob);
		bootstrapBallot.vote(true, sig);
        vm.stopPrank();

		sig = abi.encodePacked(charlieVotingSignature);
        vm.startPrank(charlie);
		bootstrapBallot.vote(false, sig);
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
		bootstrapBallot.vote(true, sig);

        // Alice tries to vote again
        vm.expectRevert("User already voted");
		bootstrapBallot.vote(true, sig);
        vm.stopPrank();
    }


    // A unit test to check the completionTimestamp is correctly set equal to the current block timestamp plus the ballot duration in constructor.
    function test_completionTimestamp() public {
    	// Store the current block timestamp before constructing the contract
    	uint256 startTime = block.timestamp;

    	// Construct the contract with 1 hour ballotDuration
    	uint256 ballotDuration = 60 * 60;
    	BootstrapBallot bootstrapBallot = new BootstrapBallot(exchangeConfig, airdrop, ballotDuration);

    	// Check that completionTimestamp equals startTime plus ballotDuration
    	assertEq(bootstrapBallot.completionTimestamp(), startTime + ballotDuration);
    }


    // A unit test to check the ballotFinalized remains false after constructor.
	function testBallotFinalizedRemainsFalseAfterConstructor() public {
		assertEq(bootstrapBallot.ballotFinalized(), false);
	}


    // A unit test to check the vote function when a voter votes No. Verify that the noVotes count is correctly incremented.
	function test_vote_No() public {
		bytes memory sig = abi.encodePacked(aliceVotingSignature);

		vm.startPrank(alice);
		bootstrapBallot.vote(false, sig);
		vm.stopPrank();

		assertEq(bootstrapBallot.startExchangeNo(), 1);
	}


    // A unit test to check the finalizeBallot function when yesVotes are equal to noVotes. Verify that the InitialDistribution.distributionApproved function is not called.
	function test_finalizeBallotTieVote() public {
		bytes memory sig = abi.encodePacked(aliceVotingSignature);

        // Voting stage (yesVotes: 1, noVotes: 1)
        vm.startPrank(alice);
		bootstrapBallot.vote(true, sig);
        vm.stopPrank();

		sig = abi.encodePacked(bobVotingSignature);
        vm.startPrank(bob);
		bootstrapBallot.vote(false, sig);
        vm.stopPrank();

        // Increase current blocktime to be greater than completionTimestamp
        vm.warp( bootstrapBallot.completionTimestamp());

		assertEq( salt.balanceOf(address(initialDistribution)), 100000000 ether);

        // Call finalizeBallot()
        bootstrapBallot.finalizeBallot();

        // Verify that the InitialDistribution.distributionApproved() was called.
		assertEq( salt.balanceOf(address(initialDistribution)), 100000000 ether);
    }


    // A unit test to check the finalizeBallot function when no one has voted. In this case, the InitialDistribution.distributionApproved function should not be called, and ballotFinalized turns into true.
    function test_finalizeBallotnoVotes() public {

        // Increase current blocktime to be greater than completionTimestamp
        vm.warp( bootstrapBallot.completionTimestamp());

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
			bootstrapBallot.vote(true,sig);
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
		bootstrapBallot.vote(true, sig);
        vm.stopPrank();
		}


	// A unit test to ensure that only the bootstrapBallot can call Airdrop.authorizeWallet
	function testAuthorizationRestrictions() public
		{
		vm.expectRevert("Only the BootstrapBallot can call Airdrop.authorizeWallet");
		vm.prank( address(0x12345) );
		airdrop.authorizeWallet(address(0x1111));
		}


    // A unit test to check the the the signature has to be correct oto have the user vote
	function testVoteSignatureRequirement() public {
		bytes memory sig = abi.encodePacked(hex"123456");

		vm.expectRevert();
        vm.startPrank(alice);
		bootstrapBallot.vote(true, sig);
        vm.stopPrank();
        }


	// A unit test that verifies the signature validation logic in vote(), to check when it's correct and incorrect.
	function testVoteSignatureValidation() public {
    		// Assume these bytes represent a valid and invalid signature for demonstration purposes
    		bytes memory validSignature = abi.encodePacked(aliceVotingSignature); // aliceVotingSignature should be a predefined valid signature corresponding to Alice
    		bytes memory invalidSignature = new bytes(65); // Just an arbitrary invalid signature

    		// Attempted vote with incorrect signature should be reverted
    		vm.startPrank(alice);
    		vm.expectRevert("Incorrect BootstrapBallot.vote signatory");
    		bootstrapBallot.vote(true, invalidSignature);
    		vm.stopPrank();


    		// Successful vote with correct signature
    		uint256 beforeYesCount = bootstrapBallot.startExchangeYes();
    		uint256 beforeNoCount = bootstrapBallot.startExchangeNo();

    		vm.startPrank(alice);
    		bootstrapBallot.vote(true, validSignature);
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
        bootstrapBallot.vote(true, aliceSig);
        vm.stopPrank();

        // Bob also votes YES with some regional exclusion votes, sig provided by deployment context
        bytes memory bobSig = abi.encodePacked(bobVotingSignature); // assuming bobVotingSignature is provided
        vm.startPrank(bob);
        bootstrapBallot.vote(true, bobSig);
        vm.stopPrank();

        // Charlie votes NO with some regional exclusion votes, sig provided by deployment context
        bytes memory charlieSig = abi.encodePacked(charlieVotingSignature); // assuming charlieVotingSignature is provided
        vm.startPrank(charlie);
        bootstrapBallot.vote(false, charlieSig);
        vm.stopPrank();

        // Assert: Ensure `startExchangeApproved` is false initially
        assertEq(pools.exchangeIsLive(), false);

        // Act: Warp to a future time when the ballot completion is due and finalize the ballot
        vm.warp(bootstrapBallot.completionTimestamp() + 1); // assuming completionTimestamp is provided
        bootstrapBallot.finalizeBallot();

        // Assert: Check if `startExchangeApproved` becomes true
        assertEq(pools.exchangeIsLive(), true, "startExchangeApproved should be true after ballot finalization with majority YES votes");
    }


    // A unit test that confirms finalizeBallot does not execute after ballotFinalized is already true.
	function testFinalizeBallotUnsuccessfulAfterAlreadyFinalizedAndStarted() public {
        // Set initial votes (yesVotes: 2, noVotes: 1)
        vm.startPrank(alice);
        bytes memory sigAlice = abi.encodePacked(aliceVotingSignature);
        bootstrapBallot.vote(true, sigAlice);
        vm.stopPrank();

        vm.startPrank(bob);
        bytes memory sigBob = abi.encodePacked(bobVotingSignature);
        bootstrapBallot.vote(true, sigBob);
        vm.stopPrank();

        vm.startPrank(charlie);
        bytes memory sigCharlie = abi.encodePacked(charlieVotingSignature);
        bootstrapBallot.vote(false, sigCharlie);
        vm.stopPrank();

        // Move time forward to finalize the ballot
        vm.warp(bootstrapBallot.completionTimestamp());

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
        bootstrapBallot.vote(true, sigAlice);
        vm.stopPrank();

        vm.startPrank(bob);
        bytes memory sigBob = abi.encodePacked(bobVotingSignature);
        bootstrapBallot.vote(false, sigBob);
        vm.stopPrank();

        vm.startPrank(charlie);
        bytes memory sigCharlie = abi.encodePacked(charlieVotingSignature);
        bootstrapBallot.vote(false, sigCharlie);
        vm.stopPrank();

        // Move time forward to finalize the ballot
        vm.warp(bootstrapBallot.completionTimestamp());

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
        vm.expectRevert("Incorrect BootstrapBallot.vote signatory");
        bootstrapBallot.vote(true, incorrectSignature); // External call to vote function
        vm.stopPrank();

        // Assert that the voter has not been authorized for the airdrop after the failed vote attempt
        assertEq(airdrop.isAuthorized(voter), false, "Voter should not be authorized for airdrop after voting with an incorrect signature");
    }


	function testVotingSignature() public
		{
		bytes memory deployerVotingSignature = hex"cb4e1eb53165e70808a1d2597fedee93ce65e200ea3da08acab7fb1f8bc7b148317f66499a4ec7f7c93fb6f87d68a80ddd9adeabba6f355d9ff5a93a8b88b7631b";

		vm.prank(DEPLOYER);
		bootstrapBallot.vote( true, deployerVotingSignature );
		}
	}
