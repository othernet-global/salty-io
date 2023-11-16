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

			poolsConfig.whitelistPool(  salt, wbtc);
			poolsConfig.whitelistPool(  salt, weth);
			poolsConfig.whitelistPool(  salt, usds);
			poolsConfig.whitelistPool(  wbtc, usds);
			poolsConfig.whitelistPool(  weth, usds);
			poolsConfig.whitelistPool(  wbtc, dai);
			poolsConfig.whitelistPool(  weth, dai);
			poolsConfig.whitelistPool(  usds, dai);
			poolsConfig.whitelistPool(  wbtc, weth);

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
		uint256[] memory regionalVotes = new uint256[](5);
		bootstrapBallot.vote(true, regionalVotes, sig);
        vm.stopPrank();

		sig = abi.encodePacked(bobVotingSignature);
        vm.startPrank(bob);
		bootstrapBallot.vote(true, regionalVotes, sig);
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
		uint256[] memory regionalVotes = new uint256[](5);
		bootstrapBallot.vote(true, regionalVotes, sig);
        vm.stopPrank();

		sig = abi.encodePacked(bobVotingSignature);
        vm.startPrank(bob);
		bootstrapBallot.vote(true, regionalVotes, sig);
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
		uint256[] memory regionalVotes = new uint256[](5);
		bootstrapBallot.vote(true, regionalVotes, sig);
        vm.stopPrank();

		sig = abi.encodePacked(bobVotingSignature);
        vm.startPrank(bob);
		bootstrapBallot.vote(true, regionalVotes, sig);
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
		uint256[] memory regionalVotes = new uint256[](5);
		bootstrapBallot.vote(false, regionalVotes, sig);
        vm.stopPrank();

		sig = abi.encodePacked(bobVotingSignature);
        vm.startPrank(bob);
		bootstrapBallot.vote(false, regionalVotes, sig);
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
		uint256[] memory regionalVotes = new uint256[](5);
		bootstrapBallot.vote(true, regionalVotes, sig);
        vm.stopPrank();

		sig = abi.encodePacked(bobVotingSignature);
        vm.startPrank(bob);
		bootstrapBallot.vote(true, regionalVotes, sig);
        vm.stopPrank();

		sig = abi.encodePacked(charlieVotingSignature);
        vm.startPrank(charlie);
		bootstrapBallot.vote(false, regionalVotes, sig);
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
		uint256[] memory regionalVotes = new uint256[](5);
		bootstrapBallot.vote(true, regionalVotes, sig);

        // Alice tries to vote again
        vm.expectRevert("User already voted");
		bootstrapBallot.vote(true, regionalVotes, sig);
        vm.stopPrank();
    }


    // A unit test to check the constructor when supplied parameters are address(0). Verify that it throws an error stating "_exchangeConfig cannot be address(0)" or "_airdrop cannot be address(0)".
    function test_constructor() public {
    	vm.expectRevert( "_exchangeConfig cannot be address(0)" );
   		bootstrapBallot = new BootstrapBallot( IExchangeConfig(address(0)), airdrop, 60 * 60 * 24 * 3 );

    	vm.expectRevert( "_airdrop cannot be address(0)" );
   		bootstrapBallot = new BootstrapBallot( exchangeConfig, IAirdrop(address(0)), 60 * 60 * 24 * 3 );

    	vm.expectRevert( "ballotDuration cannot be zero" );
   		bootstrapBallot = new BootstrapBallot( exchangeConfig, airdrop, 0 );
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
		uint256[] memory regionalVotes = new uint256[](5);
		bootstrapBallot.vote(false, regionalVotes, sig);
		vm.stopPrank();

		assertEq(bootstrapBallot.startExchangeNo(), 1);
	}


    // A unit test to check the finalizeBallot function when yesVotes are equal to noVotes. Verify that the InitialDistribution.distributionApproved function is not called.
	function test_finalizeBallotTieVote() public {
		bytes memory sig = abi.encodePacked(aliceVotingSignature);

        // Voting stage (yesVotes: 1, noVotes: 1)
        vm.startPrank(alice);
		uint256[] memory regionalVotes = new uint256[](5);
		bootstrapBallot.vote(true, regionalVotes, sig);
        vm.stopPrank();

		sig = abi.encodePacked(bobVotingSignature);
        vm.startPrank(bob);
		bootstrapBallot.vote(false, regionalVotes, sig);
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
			uint256[] memory regionalVotes = new uint256[](5);
			bootstrapBallot.vote(true, regionalVotes,sig);
            vm.stopPrank();

            // Check if Alice voted
            assertTrue(bootstrapBallot.hasVoted(alice), "User vote not recognized");
        }



        // A unit test to check that regional exclusion tallies update correct on voting
        function _testRegionalExclusionVoting( uint256 votingIndex ) public {
            assertTrue(bootstrapBallot.initialGeoExclusionYes()[votingIndex] == 0, "Shouldn't be an initial yes vote");

		bytes memory sig = abi.encodePacked(aliceVotingSignature);

            // Vote stage
            vm.startPrank(alice);
			uint256[] memory regionalVotes = new uint256[](5);
			regionalVotes[votingIndex] = 1; // yes on exclusion
			bootstrapBallot.vote(true, regionalVotes, sig);
            vm.stopPrank();

            assertTrue(bootstrapBallot.initialGeoExclusionYes()[votingIndex] == 1, "User vote not recognized");
        }


		function testRegionalExclusionVoting0() public
			{
			_testRegionalExclusionVoting(0);
			}


		function testRegionalExclusionVoting1() public
			{
			_testRegionalExclusionVoting(1);
			}


		function testRegionalExclusionVoting2() public
			{
			_testRegionalExclusionVoting(2);
			}


		function testRegionalExclusionVoting3() public
			{
			_testRegionalExclusionVoting(3);
			}


		function testRegionalExclusionVoting4() public
			{
			_testRegionalExclusionVoting(4);
			}


        // A unit test to check that regional exclusion tallies update correct on voting
        function _testRegionalExclusionVotingNo( uint256 votingIndex ) public {
            assertTrue(bootstrapBallot.initialGeoExclusionNo()[votingIndex] == 0, "Shouldn't be an initial yes vote");

		bytes memory sig = abi.encodePacked(aliceVotingSignature);

            // Vote stage
            vm.startPrank(alice);
			uint256[] memory regionalVotes = new uint256[](5);
			regionalVotes[votingIndex] = 2; // no on exclusion
			bootstrapBallot.vote(false, regionalVotes, sig);
            vm.stopPrank();

            assertTrue(bootstrapBallot.initialGeoExclusionNo()[votingIndex] == 1, "User vote not recognized");
        }


		function testRegionalExclusionVotingNo0() public
			{
			_testRegionalExclusionVotingNo(0);
			}


		function testRegionalExclusionVotingNo1() public
			{
			_testRegionalExclusionVotingNo(1);
			}


		function testRegionalExclusionVotingNo2() public
			{
			_testRegionalExclusionVotingNo(2);
			}


		function testRegionalExclusionVotingNo3() public
			{
			_testRegionalExclusionVotingNo(3);
			}


		function testRegionalExclusionVotingNo4() public
			{
			_testRegionalExclusionVotingNo(4);
			}



        // A unit test to check that regional exclusion tallies update correct on voting
        function testMultipleRegionalExclusionVotes() public {
            assertTrue(bootstrapBallot.initialGeoExclusionNo()[0] == 0, "Shouldn't be an initial yes vote");
            assertTrue(bootstrapBallot.initialGeoExclusionYes()[0] == 0, "Shouldn't be an initial yes vote");

            // Vote stage
		bytes memory sig = abi.encodePacked(aliceVotingSignature);

            vm.startPrank(alice);
			uint256[] memory regionalVotes = new uint256[](5);
			regionalVotes[0] = 1; // yes on exclusion
			bootstrapBallot.vote(true, regionalVotes, sig);
            vm.stopPrank();

		sig = abi.encodePacked(bobVotingSignature);

            vm.startPrank(bob);
			regionalVotes = new uint256[](5);
			regionalVotes[0] = 1; // yes on exclusion
			bootstrapBallot.vote(true, regionalVotes, sig);
            vm.stopPrank();


		sig = abi.encodePacked(charlieVotingSignature);
            vm.startPrank(charlie);
			regionalVotes = new uint256[](5);
			regionalVotes[0] = 2; // no on exclusion
			bootstrapBallot.vote(true, regionalVotes, sig);
            vm.stopPrank();

            assertTrue(bootstrapBallot.initialGeoExclusionYes()[0] == 2, "User votes not recognized");
            assertTrue(bootstrapBallot.initialGeoExclusionNo()[0] == 1, "User votes not recognized");
        }





	// A unit test which checks that an incorrect signature for airdrop whitelisting fails
	function testIncorrectVotingSignature() public
		{
		bytes memory sig = abi.encodePacked(hex"1234567890");

		uint256[] memory regionalVotes = new uint256[](5);
        vm.startPrank(alice);

		vm.expectRevert();
		bootstrapBallot.vote(true, regionalVotes, sig);
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
		uint256[] memory regionalVotes = new uint256[](5);

		vm.expectRevert();
        vm.startPrank(alice);
		bootstrapBallot.vote(true, regionalVotes, sig);
        vm.stopPrank();
        }


	// A unit test that verifies the signature validation logic in vote(), to check when it's correct and incorrect.
	function testVoteSignatureValidation() public {
    		// Assume these bytes represent a valid and invalid signature for demonstration purposes
    		bytes memory validSignature = abi.encodePacked(aliceVotingSignature); // aliceVotingSignature should be a predefined valid signature corresponding to Alice
    		bytes memory invalidSignature = new bytes(65); // Just an arbitrary invalid signature

    		uint256[] memory regionalVotes = new uint256[](5); // Empty regionalVotes array for simplicity.

    		// Attempted vote with incorrect signature should be reverted
    		vm.startPrank(alice);
    		vm.expectRevert("Incorrect BootstrapBallot.vote signatory");
    		bootstrapBallot.vote(true, regionalVotes, invalidSignature);
    		vm.stopPrank();


    		// Successful vote with correct signature
    		uint256 beforeYesCount = bootstrapBallot.startExchangeYes();
    		uint256 beforeNoCount = bootstrapBallot.startExchangeNo();

    		vm.startPrank(alice);
    		bootstrapBallot.vote(true, regionalVotes, validSignature);
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
        uint256[] memory regionalVotesAlice = new uint256[](5); // example regional votes setup, can be adjusted
        vm.startPrank(alice);
        bootstrapBallot.vote(true, regionalVotesAlice, aliceSig);
        vm.stopPrank();

        // Bob also votes YES with some regional exclusion votes, sig provided by deployment context
        bytes memory bobSig = abi.encodePacked(bobVotingSignature); // assuming bobVotingSignature is provided
        uint256[] memory regionalVotesBob = new uint256[](5); // example regional votes setup, can be adjusted
        vm.startPrank(bob);
        bootstrapBallot.vote(true, regionalVotesBob, bobSig);
        vm.stopPrank();

        // Charlie votes NO with some regional exclusion votes, sig provided by deployment context
        bytes memory charlieSig = abi.encodePacked(charlieVotingSignature); // assuming charlieVotingSignature is provided
        uint256[] memory regionalVotesCharlie = new uint256[](5); // example regional votes setup, can be adjusted
        vm.startPrank(charlie);
        bootstrapBallot.vote(false, regionalVotesCharlie, charlieSig);
        vm.stopPrank();

        // Assert: Ensure `startExchangeApproved` is false initially
        assertEq(pools.exchangeStarted(), false);

        // Act: Warp to a future time when the ballot completion is due and finalize the ballot
        vm.warp(bootstrapBallot.completionTimestamp() + 1); // assuming completionTimestamp is provided
        bootstrapBallot.finalizeBallot();

        // Assert: Check if `startExchangeApproved` becomes true
        assertEq(pools.exchangeStarted(), true, "startExchangeApproved should be true after ballot finalization with majority YES votes");
    }


    // A unit test that confirms finalizeBallot does not execute after ballotFinalized is already true.
	function testFinalizeBallotUnsuccessfulAfterAlreadyFinalizedAndStarted() public {
        // Set initial votes (yesVotes: 2, noVotes: 1)
        vm.startPrank(alice);
        uint256[] memory regionalVotesAlice = new uint256[](5);
        bytes memory sigAlice = abi.encodePacked(aliceVotingSignature);
        bootstrapBallot.vote(true, regionalVotesAlice, sigAlice);
        vm.stopPrank();

        vm.startPrank(bob);
        uint256[] memory regionalVotesBob = new uint256[](5);
        bytes memory sigBob = abi.encodePacked(bobVotingSignature);
        bootstrapBallot.vote(true, regionalVotesBob, sigBob);
        vm.stopPrank();

        vm.startPrank(charlie);
        uint256[] memory regionalVotesCharlie = new uint256[](5);
        bytes memory sigCharlie = abi.encodePacked(charlieVotingSignature);
        bootstrapBallot.vote(false, regionalVotesCharlie, sigCharlie);
        vm.stopPrank();

        // Move time forward to finalize the ballot
        vm.warp(bootstrapBallot.completionTimestamp());

        // Finalize ballot successfully for the first time
        bootstrapBallot.finalizeBallot();

        // Ensure that ballotFinalized = true and startExchangeApproved = true
        assertTrue(bootstrapBallot.ballotFinalized());
        assertTrue(pools.exchangeStarted());

        // Prepare to finalize the ballot again, expecting revert due to already being finalized
        vm.expectRevert("Ballot has already been finalized");
        bootstrapBallot.finalizeBallot();
    }


    // A unit test that checks the correct exception is thrown if vote() is called with a votesRegionalExclusions array of incorrect size (not 5).
	function testVoteWrongRegionalVotesSize() public {
        // Set initial votes (yesVotes: 2, noVotes: 1)
        vm.startPrank(alice);
        uint256[] memory regionalVotesAlice = new uint256[](6);
        bytes memory sigAlice = abi.encodePacked(aliceVotingSignature);

        vm.expectRevert( "Incorrect length for votesRegionalExclusions" );
        bootstrapBallot.vote(true, regionalVotesAlice, sigAlice);
        vm.stopPrank();
    }


    // A unit test that confirms finalizeBallot does not execute after ballotFinalized is already true with a failed vote.
	function testFinalizeBallotUnsuccessfulAfterAlreadyFinalizedAndNotStarted() public {
        // Set initial votes (yesVotes: 1, noVotes: 2)
        vm.startPrank(alice);
        uint256[] memory regionalVotesAlice = new uint256[](5);
        bytes memory sigAlice = abi.encodePacked(aliceVotingSignature);
        bootstrapBallot.vote(true, regionalVotesAlice, sigAlice);
        vm.stopPrank();

        vm.startPrank(bob);
        uint256[] memory regionalVotesBob = new uint256[](5);
        bytes memory sigBob = abi.encodePacked(bobVotingSignature);
        bootstrapBallot.vote(false, regionalVotesBob, sigBob);
        vm.stopPrank();

        vm.startPrank(charlie);
        uint256[] memory regionalVotesCharlie = new uint256[](5);
        bytes memory sigCharlie = abi.encodePacked(charlieVotingSignature);
        bootstrapBallot.vote(false, regionalVotesCharlie, sigCharlie);
        vm.stopPrank();

        // Move time forward to finalize the ballot
        vm.warp(bootstrapBallot.completionTimestamp());

        // Finalize ballot successfully for the first time
        bootstrapBallot.finalizeBallot();

        // Ensure that ballotFinalized = true and startExchangeApproved = true
        assertTrue(bootstrapBallot.ballotFinalized());
        assertTrue(! pools.exchangeStarted());

        // Prepare to finalize the ballot again, expecting revert due to already being finalized
        vm.expectRevert("Ballot has already been finalized");
        bootstrapBallot.finalizeBallot();
    }


    // A unit test that verifies the vote() function does not authorize the user for the airdrop if the signature is incorrect.
    function testVoteWithIncorrectSignatureDoesNotAuthorizeForAirdrop() public {
        bytes memory incorrectSignature = new bytes(65);
        uint256[] memory regionalVotes = new uint256[](5); // Dummy regional votes
        address voter = alice; // Replace with actual voter address if needed

        vm.startPrank(voter);
        // Expect a revert with a specific error message related to incorrect signature verification
        vm.expectRevert("Incorrect BootstrapBallot.vote signatory");
        bootstrapBallot.vote(true, regionalVotes, incorrectSignature); // External call to vote function
        vm.stopPrank();

        // Assert that the voter has not been authorized for the airdrop after the failed vote attempt
        assertEq(airdrop.isAuthorized(voter), false, "Voter should not be authorized for airdrop after voting with an incorrect signature");
    }


    // A unit test that checks if vote() properly increments the correct exclusion counters based on regional vote selections, including mixed yes/no/abstain combinations.
    function testVoteProperlyIncrementsExclusionCounters() public {
        // Prepare signatures and other data for voters
        uint256[] memory regionalVotesAlice = new uint256[](5);
        uint256[] memory regionalVotesBob = new uint256[](5);
        uint256[] memory regionalVotesCharlie = new uint256[](5);

        // Set up different regional vote options for alice, bob, and charlie
        regionalVotesAlice[0] = 1; // Alice votes "yes" on exclusion for region 0
        regionalVotesAlice[2] = 2; // Alice votes "no" on exclusion for region 2
        regionalVotesBob[1] = 1; // Bob votes "yes" on exclusion for region 1
        regionalVotesBob[3] = 2; // Bob votes "no" on exclusion for region 3
        regionalVotesCharlie[4] = 1; // Charlie votes "yes" on exclusion for region 4

        // Cast votes
        vm.prank(alice);
        bootstrapBallot.vote(true, regionalVotesAlice, aliceVotingSignature);

        vm.prank(bob);
        bootstrapBallot.vote(true, regionalVotesBob, bobVotingSignature);

        vm.prank(charlie);
        bootstrapBallot.vote(false, regionalVotesCharlie, charlieVotingSignature); // Charlie also votes "no" for exchange start

        // Retrieve updated exclusion tallies
        uint256[] memory geoExclusionYes = bootstrapBallot.initialGeoExclusionYes();
        uint256[] memory geoExclusionNo = bootstrapBallot.initialGeoExclusionNo();

        // Verify tally updates
        assertEq(geoExclusionYes[0], 1, "Region 0 YES votes should be 1"); // Alice voted "yes" on exclusion
        assertEq(geoExclusionNo[0], 0, "Region 0 NO votes should be 0");

        assertEq(geoExclusionYes[1], 1, "Region 1 YES votes should be 1"); // Bob voted "yes" on exclusion
        assertEq(geoExclusionNo[1], 0, "Region 1 NO votes should be 0");

        assertEq(geoExclusionYes[2], 0, "Region 2 YES votes should be 0");
        assertEq(geoExclusionNo[2], 1, "Region 2 NO votes should be 1"); // Alice voted "no" on exclusion

        assertEq(geoExclusionYes[3], 0, "Region 3 YES votes should be 0");
        assertEq(geoExclusionNo[3], 1, "Region 3 NO votes should be 1"); // Bob voted "no" on exclusion

        assertEq(geoExclusionYes[4], 1, "Region 4 YES votes should be 1"); // Charlie voted "yes" on exclusion
        assertEq(geoExclusionNo[4], 0, "Region 4 NO votes should be 0");

        // Ensure the exchange start no-vote of Charlie is accounted for
        uint256 startExchangeYesCount = bootstrapBallot.startExchangeYes();
        uint256 startExchangeNoCount = bootstrapBallot.startExchangeNo();
        assertEq(startExchangeYesCount, 2, "Start exchange YES vote count should be 2"); // Alice and Bob voted "yes"
        assertEq(startExchangeNoCount, 1, "Start exchange NO vote count should be 1"); // Charlie voted "no"
    }

	}
