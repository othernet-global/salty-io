// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "forge-std/Test.sol";
import "../../dev/Deployment.sol";
import "../../root_tests/TestERC20.sol";
import "../../ExchangeConfig.sol";
import "../../pools/Pools.sol";
import "../../staking/Liquidity.sol";
import "../../staking/Staking.sol";
import "../../stable/Collateral.sol";
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
			usds = new USDS(wbtc, weth);

			exchangeConfig = new ExchangeConfig(salt, wbtc, weth, dai, usds, teamWallet );

			priceAggregator = new PriceAggregator();
			priceAggregator.setInitialFeeds( IPriceFeed(address(forcedPriceFeed)), IPriceFeed(address(forcedPriceFeed)), IPriceFeed(address(forcedPriceFeed)) );

			pools = new Pools(exchangeConfig, poolsConfig);
			staking = new Staking( exchangeConfig, poolsConfig, stakingConfig );
			liquidity = new Liquidity( pools, exchangeConfig, poolsConfig, stakingConfig );
			collateral = new Collateral(pools, exchangeConfig, poolsConfig, stakingConfig, stableConfig, priceAggregator);

			stakingRewardsEmitter = new RewardsEmitter( staking, exchangeConfig, poolsConfig, rewardsConfig );
			liquidityRewardsEmitter = new RewardsEmitter( liquidity, exchangeConfig, poolsConfig, rewardsConfig );

			emissions = new Emissions( saltRewards, exchangeConfig, rewardsConfig );

			poolsConfig.whitelistPool(pools, salt, wbtc);
			poolsConfig.whitelistPool(pools, salt, weth);
			poolsConfig.whitelistPool(pools, salt, usds);
			poolsConfig.whitelistPool(pools, wbtc, usds);
			poolsConfig.whitelistPool(pools, weth, usds);
			poolsConfig.whitelistPool(pools, wbtc, dai);
			poolsConfig.whitelistPool(pools, weth, dai);
			poolsConfig.whitelistPool(pools, usds, dai);
			poolsConfig.whitelistPool(pools, wbtc, weth);

			proposals = new Proposals( staking, exchangeConfig, poolsConfig, daoConfig );

			address oldDAO = address(dao);
			dao = new DAO( pools, proposals, exchangeConfig, poolsConfig, stakingConfig, rewardsConfig, stableConfig, daoConfig, priceAggregator, liquidityRewardsEmitter);

			airdrop = new Airdrop(exchangeConfig, staking);

			accessManager = new AccessManager(dao);

			exchangeConfig.setAccessManager( accessManager );
			exchangeConfig.setStakingRewardsEmitter( stakingRewardsEmitter);
			exchangeConfig.setLiquidityRewardsEmitter( liquidityRewardsEmitter);
			exchangeConfig.setDAO( dao );
			exchangeConfig.setAirdrop(airdrop);

			saltRewards = new SaltRewards(exchangeConfig, rewardsConfig);

			upkeep = new Upkeep(pools, exchangeConfig, poolsConfig, daoConfig, priceAggregator, saltRewards, liquidity, emissions);
			exchangeConfig.setUpkeep(upkeep);

			bootstrapBallot = new BootstrapBallot(exchangeConfig, airdrop, 60 * 60 * 24 * 3 );
			initialDistribution = new InitialDistribution(salt, poolsConfig, emissions, bootstrapBallot, dao, daoVestingWallet, teamVestingWallet, airdrop, saltRewards, liquidity);
			exchangeConfig.setInitialDistribution(initialDistribution);

			pools.setDAO(dao);

			usds.setContracts(collateral, pools, exchangeConfig );

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

		vm.prank(DEPLOYER);
		airdrop.whitelistWallet(alice);
		}


    // A unit test to check the finalizeBallot function when ballotFinalized is false, the current timestamp is greater than completionTimestamp, and yesVotes are more than noVotes. Verify that the InitialDistribution.distributionApproved function is called.
	function test_finalizeBallot() public {
		vm.startPrank(DEPLOYER);
		airdrop.whitelistWallet(alice);
		airdrop.whitelistWallet(bob);
		vm.stopPrank();

        // Voting stage (yesVotes: 2, noVotes: 0)
        vm.startPrank(alice);
        bootstrapBallot.vote(true);
        vm.stopPrank();

        vm.startPrank(bob);
        bootstrapBallot.vote(true);
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
		vm.startPrank(DEPLOYER);
		airdrop.whitelistWallet(alice);
		airdrop.whitelistWallet(bob);
		vm.stopPrank();

        // Voting stage (yesVotes: 2, noVotes: 0)
        vm.startPrank(alice);
        bootstrapBallot.vote(true);
        vm.stopPrank();

        vm.startPrank(bob);
        bootstrapBallot.vote(true);
        vm.stopPrank();

        // Increase current blocktime to be greater than completionTimestamp
        vm.warp( bootstrapBallot.completionTimestamp() - 1);

		assertEq( salt.balanceOf(address(initialDistribution)), 100000000 ether);

        // Call finalizeBallot()
        vm.expectRevert( "Ballot duration is not yet complete");
        bootstrapBallot.finalizeBallot();

        // Verify that the InitialDistribution.distributionApproved() was called.
		assertEq( salt.balanceOf(address(initialDistribution)), 100000000 ether);
    }


    // A unit test to check the finalizeBallot function when ballotFinalized is already true. Verify that it throws an error stating the ballot has already been finalized.
	function test_finalizeBallotAlreadyFinalized() public {
		vm.startPrank(DEPLOYER);
		airdrop.whitelistWallet(alice);
		airdrop.whitelistWallet(bob);
		vm.stopPrank();

        // Voting stage (yesVotes: 2, noVotes: 0)
        vm.startPrank(alice);
        bootstrapBallot.vote(true);
        vm.stopPrank();

        vm.startPrank(bob);
        bootstrapBallot.vote(true);
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
		vm.startPrank(DEPLOYER);
		airdrop.whitelistWallet(alice);
		airdrop.whitelistWallet(bob);
		vm.stopPrank();

        // Voting stage (yesVotes: 2, noVotes: 0)
        vm.startPrank(alice);
        bootstrapBallot.vote(false);
        vm.stopPrank();

        vm.startPrank(bob);
        bootstrapBallot.vote(false);
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
        vm.startPrank(DEPLOYER);
        airdrop.whitelistWallet(alice);
        airdrop.whitelistWallet(bob);
        airdrop.whitelistWallet(charlie);
        vm.stopPrank();

        // Cast votes (yesVotes: 2, noVotes: 1)
        vm.startPrank(alice);
        bootstrapBallot.vote(true);
        vm.stopPrank();

        vm.startPrank(bob);
        bootstrapBallot.vote(true);
        vm.stopPrank();

        vm.startPrank(charlie);
        bootstrapBallot.vote(false);
        vm.stopPrank();

        // Assertions
        assertEq(bootstrapBallot.yesVotes(), 2, "YES vote count is incorrect");
        assertEq(bootstrapBallot.noVotes(), 1, "NO vote count is incorrect");
        assertTrue(bootstrapBallot.hasVoted(alice), "Alice vote status is incorrect");
        assertTrue(bootstrapBallot.hasVoted(bob), "Bob vote status is incorrect");
        assertTrue(bootstrapBallot.hasVoted(charlie), "Charlie vote status is incorrect");
    }


    // A unit test to check the vote function when the voter is not whitelisted. Verify that it throws an error stating the user is not an airdrop recipient.
	function test_vote_notWhitelisted() public {
    	vm.startPrank(bob);
    	vm.expectRevert("User is not an Airdrop recipient");
    	bootstrapBallot.vote(true);
    	vm.stopPrank();
    }


    // A unit test to check the vote function when the voter lacks exchange access. Verify that it throws an error stating the user does not have exchange access.
	function test_vote_noAccess() public {
        vm.prank(DEPLOYER);
        airdrop.whitelistWallet(bob);

		vm.prank(address(dao));
		accessManager.excludedCountriesUpdated();

    	vm.startPrank(bob);
    	vm.expectRevert("User does not have exchange access");
    	bootstrapBallot.vote(true);
    	vm.stopPrank();
    	}


    // A unit test to check the vote function when the voter has already voted. Verify that it throws an error stating the user already voted.
    function test_votesTwice() public {
        vm.prank(DEPLOYER);
        airdrop.whitelistWallet(alice);

        // Alice casts her vote
        vm.startPrank(alice);
        bootstrapBallot.vote(true);

        // Alice tries to vote again
        vm.expectRevert("User already voted");
        bootstrapBallot.vote(true);
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
		vm.startPrank(alice);
		bootstrapBallot.vote(false);
		vm.stopPrank();

		assertEq(bootstrapBallot.noVotes(), 1);
	}


    // A unit test to check the finalizeBallot function when yesVotes are equal to noVotes. Verify that the InitialDistribution.distributionApproved function is not called.
	function test_finalizeBallotTieVote() public {
		vm.startPrank(DEPLOYER);
		airdrop.whitelistWallet(alice);
		airdrop.whitelistWallet(bob);
		vm.stopPrank();

        // Voting stage (yesVotes: 1, noVotes: 1)
        vm.startPrank(alice);
        bootstrapBallot.vote(true);
        vm.stopPrank();

        vm.startPrank(bob);
        bootstrapBallot.vote(false);
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
            vm.startPrank(DEPLOYER);
            airdrop.whitelistWallet(alice);
            vm.stopPrank();

            // Vote stage
            vm.startPrank(alice);
            bootstrapBallot.vote(true);
            vm.stopPrank();

            // Check if Alice voted
            assertTrue(bootstrapBallot.hasVoted(alice), "User vote not recognized");
        }
	}
