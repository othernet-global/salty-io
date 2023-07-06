//// SPDX-License-Identifier: BSL 1.1
//pragma solidity ^0.8.12;
//
//import "forge-std/Test.sol";
//import "../Proposals.sol";
//import "../../staking/interfaces/IStakingConfig.sol";
//import "../../uniswap/core/interfaces/IUniswapV2Factory.sol";
//import "../../uniswap/core/interfaces/IUniswapV2Pair.sol";
//import "../../uniswap/periphery/interfaces/IUniswapV2Router02.sol";
//import "../../Salt.sol";
//import "../../tests/TestAccessManager.sol";
//import "../../staking/StakingConfig.sol";
//import "../../staking/Staking.sol";
//import "../interfaces/IDAOConfig.sol";
//import "..//DAOConfig.sol";
//import "../../stable/USDS.sol";
//import "../../ExchangeConfig.sol";
//
//contract TestProposals is Proposals, Test
//	{
//	address constant public DEV_WALLET = 0x73107dA86708c2DAd0D91388fB057EeE3E2581aF;
//
//	// Deployed resources
//	IUniswapV2Router02 public constant _saltyRouter = IUniswapV2Router02(address(0xcCAA839192E6087F51B95Bf593498C72113D9f65));
//	IUniswapV2Factory public _factory = IUniswapV2Factory(_saltyRouter.factory());
//	IExchangeConfig public _exchangeConfig = _factory.exchangeConfig();
//    IERC20 public _wbtc = IERC20(_exchangeConfig.wbtc());
//    IERC20 public _weth = IERC20(_exchangeConfig.weth());
//    IERC20 public _usdc = IERC20(_exchangeConfig.usdc());
//    USDS public _usds = USDS(_exchangeConfig.usds());
//
//	IStakingConfig public _stakingConfig = IStakingConfig(address(new StakingConfig(IERC20(address(new Salt())))));
//
//	IAccessManager public accessManager = IAccessManager(new TestAccessManager());
//	IDAOConfig public _daoConfig = new DAOConfig();
//    Staking public _staking = new Staking(_stakingConfig,_exchangeConfig);
//	IPOL_Optimizer public constant polOptimizer = IPOL_Optimizer(address(0x8888));
//
//	IUniswapV2Pair public _collateralLP = IUniswapV2Pair( _factory.getPair( address(_wbtc), address(_weth) ));
//
//	// User wallets for testing
//    address public constant alice = address(0x1111);
//    address public constant bob = address(0x2222);
//
//
//	constructor()
//	Proposals( _stakingConfig, _daoConfig, _exchangeConfig, _staking )
//		{
//		vm.startPrank( DEV_WALLET );
//		_exchangeConfig.setAccessManager(accessManager);
//		_exchangeConfig.setOptimizer(polOptimizer);
//
//		// setCollateral can only be called on USDS one time
//		// call it with this address as the Collateral so that usds.mintTo() can be called
//		_usds.setCollateral( ICollateral(address(this)) );
//		vm.stopPrank();
//
//		// Mint some USDS to the DEV_WALLET and alice
//		vm.startPrank( address(this) );
//		_usds.mintTo( DEV_WALLET, 2000000 ether );
//		_usds.mintTo( alice, 1000000 ether );
//		vm.stopPrank();
//
//		stakingConfig.salt().transfer( alice, 10000000 ether );
//		stakingConfig.salt().transfer( DEV_WALLET, 90000000 ether );
//		}
//
//
//    function setUp() public
//    	{
//    	vm.startPrank( DEV_WALLET );
//    	_usds.approve( address(this), type(uint256).max );
//    	stakingConfig.salt().approve( address(_staking), type(uint256).max );
//    	vm.stopPrank();
//
//    	vm.startPrank( alice );
//    	_usds.approve( address(this), type(uint256).max );
//    	stakingConfig.salt().approve( address(_staking), type(uint256).max );
//    	vm.stopPrank();
//    	}
//
//
//	// A unit test that checks the proposeParameterBallot function with different input combinations. Verify that a new proposal gets created and that all necessary state changes occur.
//	function testProposeParameterBallot() public {
//		vm.startPrank( DEV_WALLET );
//
//        // Get initial state before proposing the ballot
//        uint256 initialNextBallotId = this.nextBallotID();
//
//        // Define a ballotName
//        string memory ballotName = "New Proposal";
//
//        // Ensure ballot with ballotName doesn't exist before proposing
//        assertEq(this.openBallotsByName(ballotName), 0);
//
//        // Call proposeParameterBallot
//        this.proposeParameterBallot(ballotName);
//
//        // Check that the next ballot ID has been incremented
//        assertEq(this.nextBallotID(), initialNextBallotId + 1);
//
//        // Check that the ballot with ballotName now exists
//        assert(this.openBallotsByName(ballotName) != 0);
//
//        // Check that the proposed ballot is in the correct state
//        uint256 ballotID = openBallotsByName[ballotName];
//        Ballot memory ballot = ballots[ballotID];
//
//        // Check that the proposed ballot parameters are correct
//        assertEq(ballot.ballotID, initialNextBallotId);
//        assertTrue(ballot.ballotIsLive);
//        assertEq(uint256(ballot.ballotType), uint256(BallotType.PARAMETER));
//        assertEq(ballot.ballotName, ballotName);
//        assertEq(ballot.address1, address(0));
//        assertEq(ballot.number1, 0);
//        assertEq(ballot.string1, "");
//        assertEq(ballot.string2, "");
//        assertEq(ballot.ballotMinimumEndTime, block.timestamp + daoConfig.ballotDuration());
//    }
//
//
//	// A unit test that tries to propose the same ballot name multiple times and a proposal for an already open ballot. This should test the requirement check in the _possiblyCreateProposal function.
//	function testProposeSameBallotNameMultipleTimesAndForOpenBallot() public {
//        // Using address alice for initial proposal
//        vm.startPrank(DEV_WALLET);
//
//        string memory ballotName = "testBallot";
//
//        // Proposing a ParameterBallot for the first time
//        this.proposeParameterBallot(ballotName);
//
//        // Trying to propose the same ballot name again should fail
//        vm.expectRevert("Cannot create a proposal for an open ballot" );
//        this.proposeParameterBallot(ballotName);
//        vm.stopPrank();
//
//		// Make sure another user can't recreate the same ballot either
//		vm.prank(alice);
//        vm.expectRevert("Cannot create a proposal for an open ballot" );
//        this.proposeParameterBallot(ballotName);
//        vm.stopPrank();
//
//        // Increasing block time by ballotDuration to allow for proposal finalization
//        vm.warp(block.timestamp + _daoConfig.ballotDuration());
//
//        // Finalizing the initial ballot
//        _markBallotAsFinalized(ballots[openBallotsByName[ballotName]]);
//
//        // Trying to propose for the already open (but finalized) ballot should succeed
//        vm.prank( DEV_WALLET );
//        this.proposeParameterBallot(ballotName);
//    }
//
//
//	// A unit test that verifies the proposeCountryInclusion and proposeCountryExclusion functions with different country names. Check that the appropriate country name gets stored in the proposal.
//	function testProposeCountryInclusionExclusion() public {
//        string memory inclusionBallotName = "InclusionTest";
//        string memory exclusionBallotName = "ExclusionTest";
//        string memory countryName1 = "TestCountry1";
//        string memory countryName2 = "TestCountry2";
//        uint256 inclusionProposalCost = 5 * _daoConfig.baseProposalCost();
//        uint256 exclusionProposalCost = 5 * _daoConfig.baseProposalCost();
//
//        // Assert initial balances
//        assertEq(_usds.balanceOf(alice), 1000000 ether);
//        assertEq(_usds.balanceOf(bob), 0 ether);
//
//       // Assert reverts if not enough balance
//        vm.warp(block.timestamp + 10 days); // warp forward in time
//        vm.prank(bob);
//        vm.expectRevert( "Sender does not have USDS for proposal cost" );
//        this.proposeCountryInclusion(inclusionBallotName, countryName1);
//
//        // Propose country inclusion
//        vm.prank(alice);
//        this.proposeCountryInclusion(inclusionBallotName, countryName1);
//        uint256 inclusionProposalId = openBallotsByName[inclusionBallotName];
//
//        // Check proposal details
//        Ballot memory inclusionProposal = this.ballotForID(inclusionProposalId);
//        assertEq(inclusionProposal.ballotID, inclusionProposalId);
//        assertTrue(inclusionProposal.ballotIsLive);
//        assertEq(uint256(inclusionProposal.ballotType), uint256(BallotType.INCLUDE_COUNTRY));
//        assertEq(inclusionProposal.ballotName, inclusionBallotName);
//        assertEq(inclusionProposal.string1, countryName1);
//
//        // Assert Alice balance after proposing country inclusion
//        assertEq(_usds.balanceOf(alice), 1000000 ether - inclusionProposalCost);
//
//        // Propose country exclusion
//        vm.prank(alice);
//        this.proposeCountryExclusion(exclusionBallotName, countryName2);
//        uint256 exclusionProposalId = openBallotsByName[exclusionBallotName];
//
//        // Check proposal details
//        Ballot memory exclusionProposal = this.ballotForID(exclusionProposalId);
//        assertEq(exclusionProposal.ballotID, exclusionProposalId);
//        assertTrue(exclusionProposal.ballotIsLive);
//        assertEq(uint256(exclusionProposal.ballotType), uint256(BallotType.EXCLUDE_COUNTRY));
//        assertEq(exclusionProposal.ballotName, exclusionBallotName);
//        assertEq(exclusionProposal.string1, countryName2);
//
//        // Assert Alice balance after proposing country exclusion
//        assertEq(_usds.balanceOf(alice), 1000000 ether - inclusionProposalCost - exclusionProposalCost);
//    }
//
//
//
//	// A unit test that verifies the proposeSetContractAddress function. Test this function with different address values and verify that the new address gets stored in the proposal.
//	function testProposeSetContractAddress() public {
//        vm.startPrank(alice);
//
//        // Check initial state
//        uint256 initialProposalCount = this.nextBallotID() - 1;
//
//        // Try to set an invalid address and expect a revert
//        address newAddress = address(0);
//        vm.expectRevert("Proposed address cannot be address(0)");
//        this.proposeSetContractAddress("Change DAOConfig", newAddress);
//
//        // Use a valid address
//        newAddress = address(0x1111111111111111111111111111111111111112);
//        this.proposeSetContractAddress("Change DAOConfig", newAddress);
//
//        // Check if a new proposal is created
//        uint256 newProposalCount = this.nextBallotID() - 1;
//        assertEq(newProposalCount, initialProposalCount + 1, "New proposal was not created");
//
//        // Get the new proposal
//        Ballot memory ballot = this.ballotForID(newProposalCount);
//
//        // Check if the new proposal has the right new address
//        assertEq(ballot.address1, newAddress, "New proposal has incorrect address");
//
//        vm.stopPrank();
//    }
//
//
//	// A unit test that verifies the proposeWebsiteUpdate function. Check that the correct website URL gets stored in the proposal.
//	function testProposeWebsiteUpdate() public {
//        // Set up
//        vm.startPrank(alice); // Switch to Alice for the test
//
//        // Save off the current nextBallotID before the proposeWebsiteUpdate call
//        uint256 preNextBallotID = this.nextBallotID();
//
//        // Create a ballot with the new website URL
//        string memory ballotName = "Update Website";
//        string memory newWebsiteURL = "https://www.newwebsite.com";
//        this.proposeWebsiteUpdate(ballotName, newWebsiteURL);
//
//        // Verify the nextBallotID has been incremented
//        uint256 postNextBallotID = this.nextBallotID();
//        assertEq(postNextBallotID, preNextBallotID + 1, "nextBallotID should have incremented by 1");
//
//        // Verify the ballot ID associated with the ballotName
//        uint256 ballotID = this.openBallotsByName(ballotName);
//        assertEq(ballotID, preNextBallotID, "The ballot ID should match the preNextBallotID");
//
//        // Retrieve the new ballot
//        Ballot memory ballot = this.ballotForID(ballotID);
//
//        // Verify the ballot details
//        assertEq(ballot.ballotID, ballotID, "Ballot ID is incorrect");
//        assertEq(uint256(ballot.ballotType), uint256(BallotType.SET_WEBSITE_URL), "Ballot type is incorrect");
//        assertEq(ballot.string1, newWebsiteURL, "Website URL is incorrect");
//        assertEq(ballot.ballotName, ballotName, "Ballot name is incorrect");
//        assertTrue(ballot.ballotIsLive, "The ballot should be live");
//    }
//
//
//	// A unit test that verifies the proposeCallContract function. Try this function with different input values and verify the correct values get stored in the proposal.
//	function testProposeCallContract() public {
//        address contractAddress = address(0xBBBB);
//        uint256 number = 12345;
//
//        // Simulate a call from Alice
//        vm.startPrank(alice);
//
//        // Check initial state before proposal
//        assertEq(openBallotsByName["callContractBallot"], 0, "Ballot ID should be 0 before proposal");
//
//        // Make the proposal
//        this.proposeCallContract("callContractBallot", contractAddress, number);
//
//        // Check the proposal was made
//        uint256 ballotId = openBallotsByName["callContractBallot"];
//        assertGt(ballotId, 0, "Ballot ID should be greater than 0 after proposal");
//
//        // Check the proposal values
//        Ballot memory ballot = this.ballotForID(ballotId);
//        assertEq(ballot.ballotName, "callContractBallot", "Ballot name should match");
//        assertEq(uint256(ballot.ballotType), uint256(BallotType.CALL_CONTRACT), "Ballot type should be CALL_CONTRACT");
//        assertEq(ballot.address1, contractAddress, "Contract address should match proposal");
//        assertEq(ballot.number1, number, "Number should match proposal");
//    }
//
//
//	// A unit test for the _markBallotAsFinalized function that confirms if a ballot's status is updated correctly after finalization.
//	function testMarkBallotAsFinalized() public {
//        string memory ballotName = "testBallot";
//
//        vm.startPrank(DEV_WALLET);
//		this.proposeParameterBallot(ballotName);
//
//        uint256 ballotID = openBallotsByName[ballotName];
//        assertEq(ballots[ballotID].ballotIsLive, true);
//
//        // Act
//        _markBallotAsFinalized(ballots[ballotID]);
//
//        // Assert
//        assertEq(ballots[ballotID].ballotIsLive, false);
//        assertEq(openBallotsByName[ballotName], 0);
//
//        // Check revert for non-existent ballot
//        ballotID = openBallotsByName[ballotName];
//        assertEq( ballotID, 0, "Ballot should have been cleared" );
//    }
//
//
//	// A unit test that checks if the castVote function appropriately updates the votesCastForBallot mapping and ballotVoteTotals for the ballot. This should also cover situations where a user tries to vote without voting power and a situation where a user changes their vote.
//	function testCastVote() public {
//        string memory ballotName = "testBallot";
//
//        vm.prank(DEV_WALLET);
//		this.proposeParameterBallot(ballotName);
//		uint256 ballotID = openBallotsByName[ballotName];
//
//        Vote userVote = Vote.YES;
//
//        // User has voting power
//        vm.startPrank(alice);
//        uint256 votingPower = _staking.userShareInfoForPool(alice, STAKED_SALT).userShare;
//        assertEq( votingPower, 0, "Alice should not have any initial xSALT" );
//
//        // Vote.YES is invalid for a Parameter type ballot
//        vm.expectRevert( "Invalid VoteType for Parameter Ballot" );
//		this.castVote(ballotID, userVote);
//
//		// Alice has not staked SALT yet
//        vm.expectRevert( "User does not have any voting power" );
//        userVote = Vote.INCREASE;
//		this.castVote(ballotID, userVote);
//
//		// Stake some salt and vote again
//		votingPower = 1000 ether;
//		_staking.stakeSALT( votingPower );
//        this.castVote(ballotID, userVote);
//
//		UserVote memory lastVote = lastUserVoteForBallot[ballotID][alice];
//
//		assertEq(uint256(lastVote.vote), uint256(userVote), "User vote does not match");
//		assertEq(lastVote.votingPower, votingPower, "Voting power is incorrect");
//
//		assertEq(this.ballotVoteTotals(ballotID), votingPower, "Total votes for ballot is incorrect");
//		assertEq(this.votesCastForBallot(ballotID, userVote), votingPower, "Votes cast for ballot is incorrect");
//
//        // User changes their vote
//        uint256 addedUserVotingPower = 200 ether;
//		_staking.stakeSALT( addedUserVotingPower );
//
//        Vote newUserVote = Vote.DECREASE;
//        this.castVote(ballotID, newUserVote);
//
//        UserVote memory newLastVote = lastUserVoteForBallot[ballotID][alice];
//        assertEq(uint256(newLastVote.vote), uint256(newUserVote), "New user vote does not match");
//        assertEq(newLastVote.votingPower, votingPower + addedUserVotingPower, "New voting power is incorrect");
//
//        assertEq(this.ballotVoteTotals(ballotID), votingPower + addedUserVotingPower, "Total votes for ballot is incorrect after vote change");
//        assertEq(this.votesCastForBallot(ballotID, newUserVote), votingPower + addedUserVotingPower, "Votes cast for ballot is incorrect after vote change");
//        assertEq(this.votesCastForBallot(ballotID, userVote), 0, "The old vote should have no votes cast");
//    }
//
//
//	// A unit test that checks if canFinalizeBallot function returns the correct boolean value under various conditions, including situations where a ballot can be finalized and where it cannot due to ballot not being live, minimum end time not being reached, or not meeting the required quorum.
//	function testCanFinalizeBallot() public {
//        string memory ballotName = "Test Ballot";
//
//        vm.startPrank(alice);
//        this.proposeParameterBallot(ballotName);
//        uint256 ballotID = openBallotsByName[ballotName];
//
//		// Early ballot, no quorum
//        bool canFinalizeBallotStillEarly = this.canFinalizeBallot(ballotID);
//
//		// Ballot reached end time, no quorum
//        vm.warp(block.timestamp + daoConfig.ballotDuration() + 1); // ballot end time reached
//        bool canFinalizeBallotPastEndtime = this.canFinalizeBallot(ballotID);
//
//        // Almost reach quorum
//        _staking.stakeSALT(999999 ether);
//        this.castVote(ballotID, Vote.INCREASE);
//
//		Ballot memory ballot = ballotForID( ballotID );
//
//        bool canFinalizeBallotAlmostAtQuorum = this.canFinalizeBallot(ballotID);
//
//		// Reach quorum
//        _staking.stakeSALT(1 ether);
//        this.castVote(ballotID, Vote.DECREASE);
//
//		ballot = ballotForID( ballotID );
//
//        bool canFinalizeBallotAtQuorum = this.canFinalizeBallot(ballotID);
//
//        // Assert
//        assertEq(canFinalizeBallotStillEarly, false, "Should not be able to finalize live ballot");
//        assertEq(canFinalizeBallotPastEndtime, false, "Should not be able to finalize non-quorum ballot");
//        assertEq(canFinalizeBallotAlmostAtQuorum, false, "Should not be able to finalize ballot if quorum is just beyond the minimum ");
//        assertEq(canFinalizeBallotAtQuorum, true, "Should be able to finalize ballot if quorum is reached and past the minimum end time");
//    }
//
//
//
//	// A unit test for the requiredQuorumForBallotType function that confirms it returns the correct quorum requirement for each type of ballot.
//	function testRequiredQuorumForBallotType() public {
//
//        uint256 saltSupply = stakingConfig.salt().totalSupply();
//        uint256 baseBallotQuorumPercentSupplyTimes1000 = _daoConfig.baseBallotQuorumPercentSupplyTimes1000();
//
//        // Check quorum for Parameter ballot type
//        uint256 expectedQuorum = (1 * saltSupply * baseBallotQuorumPercentSupplyTimes1000) / (1000 * 100);
//        assertEq(this.requiredQuorumForBallotType(BallotType.PARAMETER), expectedQuorum);
//
//        // Check quorum for WhitelistToken ballot type
//        expectedQuorum = (2 * saltSupply * baseBallotQuorumPercentSupplyTimes1000) / (1000 * 100);
//        assertEq(this.requiredQuorumForBallotType(BallotType.WHITELIST_TOKEN), expectedQuorum);
//
//        // Check quorum for UnwhitelistToken ballot type
//        expectedQuorum = (2 * saltSupply * baseBallotQuorumPercentSupplyTimes1000) / (1000 * 100);
//        assertEq(this.requiredQuorumForBallotType(BallotType.UNWHITELIST_TOKEN), expectedQuorum);
//
//        // Check quorum for SendSalt ballot type
//        expectedQuorum = (3 * saltSupply * baseBallotQuorumPercentSupplyTimes1000) / (1000 * 100);
//        assertEq(this.requiredQuorumForBallotType(BallotType.SEND_SALT), expectedQuorum);
//
//        // Check quorum for CallContract ballot type
//        expectedQuorum = (3 * saltSupply * baseBallotQuorumPercentSupplyTimes1000) / (1000 * 100);
//        assertEq(this.requiredQuorumForBallotType(BallotType.CALL_CONTRACT), expectedQuorum);
//
//        // Check quorum for IncludeCountry ballot type
//        expectedQuorum = (3 * saltSupply * baseBallotQuorumPercentSupplyTimes1000) / (1000 * 100);
//        assertEq(this.requiredQuorumForBallotType(BallotType.INCLUDE_COUNTRY), expectedQuorum);
//
//        // Check quorum for ExcludeCountry ballot type
//        expectedQuorum = (3 * saltSupply * baseBallotQuorumPercentSupplyTimes1000) / (1000 * 100);
//        assertEq(this.requiredQuorumForBallotType(BallotType.EXCLUDE_COUNTRY), expectedQuorum);
//
//        // Check quorum for SetContract ballot type
//        expectedQuorum = (3 * saltSupply * baseBallotQuorumPercentSupplyTimes1000) / (1000 * 100);
//        assertEq(this.requiredQuorumForBallotType(BallotType.SET_CONTRACT), expectedQuorum);
//
//        // Check quorum for SetWebsiteUrl ballot type
//        expectedQuorum = (3 * saltSupply * baseBallotQuorumPercentSupplyTimes1000) / (1000 * 100);
//        assertEq(this.requiredQuorumForBallotType(BallotType.SET_WEBSITE_URL), expectedQuorum);
//    }
//
//
//	// A unit test for the totalVotesCastForBallot function that confirms it returns the correct total votes for a given ballot.
//	function testTotalVotesCastForBallot() public
//        {
//        string memory ballotName = "Test Ballot";
//
//		vm.startPrank(alice);
//		this.proposeParameterBallot(ballotName);
//
//		uint256 ballotID = openBallotsByName[ballotName];
//		_staking.stakeSALT( 1000 ether );
//        this.castVote(ballotID, Vote.INCREASE);
//
//		stakingConfig.salt().transfer( DEV_WALLET, 2000 ether );
//        vm.stopPrank();
//
//        vm.startPrank( DEV_WALLET );
//		_staking.stakeSALT( 2000 ether );
//        this.castVote(ballotID, Vote.INCREASE);
//        vm.stopPrank();
//
//        assertEq(ballots[ballotID].ballotIsLive, true);
//        assertEq(totalVotesCastForBallot(ballotID), 3000 ether);
//
//        vm.startPrank( alice );
//		_staking.stakeSALT( 1000 ether );
//        this.castVote(ballotID, Vote.INCREASE);
//        vm.stopPrank();
//
//        assertEq(totalVotesCastForBallot(ballotID), 4000 ether);
//        }
//
//
//	// A unit test that verifies the numberOfOpenBallotsForTokenWhitelisting function and the tokenWhitelistingBallotWithTheMostVotes function. This should include situations where there are multiple open ballots for token whitelisting, and should correctly identify the ballot with the most votes.
//	function testTokenWhitelistingBallots() public {
//		stakingConfig.whitelist( _collateralLP );
//
//        vm.prank(alice);
//        vm.expectRevert( "The token has already been whitelisted" );
//        this.proposeTokenWhitelisting("Ballot2", address(_wbtc), "https://tokenIconURL", "This is a test token");
//
//		stakingConfig.unwhitelist( _collateralLP );
//
//        // Prepare a new whitelisting ballot
//        vm.startPrank(alice);
//        _staking.stakeSALT( 2000000 ether - 1 ); // less than minimum quorum for whitelisting
//        this.proposeTokenWhitelisting("Ballot1", address(_usds), "https://tokenIconURL", "This is a test token");
//
//        // Assert that the number of open ballots for token whitelisting has increased
//        assertEq(this.numberOfOpenBallotsForTokenWhitelisting(), 1, "The number of open ballots for token whitelisting did not increase after a proposal");
//        this.castVote(openBallotsByName["Ballot1"], Vote.YES);
//
//		uint256 ballotID = this.openBallotsByName( "Ballot1" );
//		console.log( "QUORUM: ", requiredQuorumForBallotType( BallotType.WHITELIST_TOKEN ) );
//        console.log( "VOTES: ", totalVotesCastForBallot(ballotID) );
//
//		// Shouldn't have enough votes for quorum yes
//        assertEq(this.tokenWhitelistingBallotWithTheMostVotes(), 0, "The ballot shouldn't have enough votes for quorum yet");
//		vm.stopPrank();
//
//		// 2 million no votes will bring ballot to quorum, but no votes will be more than yes votes
//		vm.startPrank( DEV_WALLET );
//        _staking.stakeSALT( 3000000 ether );
//        assertEq(this.tokenWhitelistingBallotWithTheMostVotes(), 0, "NO > YES should mean no whitelisted ballot");
//		vm.stopPrank();
//
//		// Have alice cast more votes for YES
//		vm.startPrank(alice);
//        _staking.stakeSALT( 10 ether );
//        this.castVote(openBallotsByName["Ballot1"], Vote.YES);
//
//        // The ballot should now be whitelistable
//        assertEq(this.tokenWhitelistingBallotWithTheMostVotes(), openBallotsByName["Ballot1"], "Ballot shoudld be whitelistable");
//
//        // Create a second whitelisting ballot
//        this.proposeTokenWhitelisting("Ballot2", address(_weth), "https://tokenIconURL", "This is another test token");
//        assertEq(this.numberOfOpenBallotsForTokenWhitelisting(), 2, "The number of open ballots for token whitelisting did not increase after a second proposal");
//		vm.stopPrank();
//
//		vm.startPrank( DEV_WALLET );
//        this.castVote(openBallotsByName["Ballot2"], Vote.NO);
//        this.castVote(openBallotsByName["Ballot2"], Vote.YES);
//
//        console.log( "ballot1 id: ", openBallotsByName["Ballot1"] );
//        console.log( "ballot2 id: ", openBallotsByName["Ballot2"] );
//        console.log( "max id: ", this.tokenWhitelistingBallotWithTheMostVotes() );
//
//        assertEq(this.tokenWhitelistingBallotWithTheMostVotes(), openBallotsByName["Ballot2"], "The ballot with the most votes was not updated correctly after a vote");
//    }
//
//
//	// A unit test that verifies the proposeSendSALT function, checking if the user can send SALT, and ensuring that they can't send more than 5% of the existing balance.
//	function testProposeSendSALT() public {
//
//		uint256 contractInitialSaltBalance = 1000000 ether;
//
//		vm.startPrank( DEV_WALLET );
//		stakingConfig.salt().transfer( address(this), contractInitialSaltBalance );
//		vm.stopPrank();
//
//
//		vm.startPrank( alice );
//
//        // Test proposing to send an amount within the limit (less than 5% of the balance)
//        uint256 validAmount = contractInitialSaltBalance / 21; // <5% of the initial balance
//        string memory validBallotName = "validBallot";
//        this.proposeSendSALT(validBallotName, bob, validAmount);
//        uint256 validBallotId = openBallotsByName[validBallotName];
//        Ballot memory validBallot = ballots[validBallotId];
//        assertEq(validBallot.ballotIsLive, true, "The valid ballot should be live");
//        assertEq(validBallot.number1, validAmount, "The proposed amount should be the same as the input amount");
//
//        // Test proposing to send an amount exceeding the limit
//        uint256 excessiveAmount = contractInitialSaltBalance / 19; // > 5% of the initial balance
//
//        string memory excessiveBallotName = "excessiveBallot";
//        vm.expectRevert("Cannot send more than 5% of the existing balance");
//        this.proposeSendSALT(excessiveBallotName, bob, excessiveAmount);
//    }
//
//
//
//	// A unit test for the proposeTokenWhitelisting function that includes the situation where the maximum number of token whitelisting proposals are already pending.
//	function testProposeTokenWhitelistingMaxPending() public {
//        vm.startPrank(DEV_WALLET);
//
//        string memory ballotName = "Token Whitelist Proposal";
//        address tokenAddress = address(0xAbc123);
//        string memory tokenIconURL = "http://test.com/token.png";
//        string memory tokenDescription = "Test Token for Whitelisting";
//        uint256 maxPendingTokensForWhitelisting = _daoConfig.maxPendingTokensForWhitelisting();
//
//        // Create the maximum number of token whitelisting proposals
//        for(uint256 i = 0; i < maxPendingTokensForWhitelisting; i++) {
//            string memory currentBallotName = string(abi.encodePacked(ballotName, " ", i));
//            this.proposeTokenWhitelisting(currentBallotName, tokenAddress, tokenIconURL, tokenDescription);
//        }
//
//        // Attempt to create another token whitelisting proposal beyond the maximum limit
//        string memory overflowBallotName = string(abi.encodePacked(ballotName, " Overflow"));
//        vm.expectRevert("The maximum number of token whitelisting proposals are already pending");
//        this.proposeTokenWhitelisting(overflowBallotName, tokenAddress, tokenIconURL, tokenDescription);
//    }
//
//
//	// A unit test that verifies the proposeTokenUnwhitelisting function. This should include situations where the token is not whitelisted and a situation where the token is whitelisted.
//	function testProposeTokenUnwhitelisting() public {
//
//        // Trying to unwhitelist an unwhitelisted token should fail.
//        vm.expectRevert("Can only unwhitelist a whitelisted token");
//        this.proposeTokenUnwhitelisting("unwhitelist_usds", address(_usds), "test", "test");
//
//        // Whitelist the token (which will be paired with WBTC and WETH)
//		stakingConfig.whitelist( IUniswapV2Pair(_factory.getPair( address(_usds), address(_wbtc))));
//		stakingConfig.whitelist( IUniswapV2Pair(_factory.getPair( address(_usds), address(_weth))));
//
//		vm.startPrank( DEV_WALLET );
//
//        // Unwhitelist the token and expect no revert
//        this.proposeTokenUnwhitelisting("unwhitelist_usds", address(_usds), "test", "test");
//
//        // Get the ballot id
//        uint256 ballotId = openBallotsByName["unwhitelist_usds"];
//        assertEq(uint256(ballots[ballotId].ballotType), uint256(BallotType.UNWHITELIST_TOKEN));
//        assertEq(ballots[ballotId].address1, address(_usds));
//    }
//
//
//	// A unit test that changes votes after unstaking SALT
//	function testChangeVotesAfterUnstakingSALT() public {
//    	vm.startPrank(alice);
//
//    	string memory ballotName = "TestBallot";
//    	address randomAddress = address(0x543210);
//
//    	// Staking SALT
//    	_staking.stakeSALT(100000 ether);
//
//    	// Create a proposal
//    	this.proposeCallContract(ballotName, randomAddress, 1000);
//
//    	uint256 ballotID = openBallotsByName[ballotName];
//    	assertEq(ballots[ballotID].ballotIsLive, true, "Ballot should be live after proposal");
//
//    	// Vote YES
//    	this.castVote(ballotID, Vote.YES);
//
//    	// Assert vote has been casted
//    	assertEq(uint256(lastUserVoteForBallot[ballotID][alice].vote), uint256(Vote.YES), "Vote should have been casted");
//    	assertEq(lastUserVoteForBallot[ballotID][alice].votingPower, 100000 ether, "Vote should have been casted with 100000 ether voting power");
//
//    	// Unstake SALT
//    	_staking.unstake(50000 ether, 2 );
//
//    	// Vote NO
//    	this.castVote(ballotID, Vote.NO);
//
//    	// Assert vote has been changed and voting power decreased
//    	assertEq(uint256(lastUserVoteForBallot[ballotID][alice].vote), uint256(Vote.NO), "Vote should have been changed to NO");
//    	assertEq(lastUserVoteForBallot[ballotID][alice].votingPower, 50000 ether, "Vote should have been casted with 50000 ether voting power after unstaking");
//
//    	// Unstake all remaining SALT
//    	_staking.unstake(50000 ether, 2 );
//
//    	// Expect voting to fail due to lack of voting power
//    	vm.expectRevert("User does not have any voting power");
//    	this.castVote(ballotID, Vote.YES);
//    }
//
//
//	// A unit test with multiple users voting on a parameter ballot and verifying the vote totals
//	function testParameterBallotVoting() public {
//        string memory ballotName = "ParameterBallotTest";
//
//        // Test proposeParameterBallot function
//        vm.startPrank(DEV_WALLET);
//        this.proposeParameterBallot(ballotName);
//        vm.stopPrank();
//
//        uint256 ballotID = this.openBallotsByName(ballotName);
//        Ballot memory ballot = this.ballotForID(ballotID);
//        assertEq(ballot.ballotIsLive, true, "The ballot should be live.");
//
//        // Test multiple users voting on the ballot
//
//        // Voting by DEV_WALLET
//        vm.startPrank(DEV_WALLET);
//        _staking.stakeSALT( 2000000 ether );
//
//
//		vm.expectRevert( "Invalid VoteType for Parameter Ballot" );
//        this.castVote(ballotID, Vote.YES);
//		vm.expectRevert( "Invalid VoteType for Parameter Ballot" );
//        this.castVote(ballotID, Vote.NO);
//
//        this.castVote(ballotID, Vote.INCREASE);
//        stakingConfig.salt().transfer(bob, 1000000 ether);
//        vm.stopPrank();
//
//        // Voting by alice
//        vm.startPrank(alice);
//        _staking.stakeSALT( 1000000 ether );
//        this.castVote(ballotID, Vote.NO_CHANGE);
//        vm.stopPrank();
//
//		// Coting by bob
//        vm.startPrank(bob);
//        stakingConfig.salt().approve( address(_staking), type(uint256).max );
//        stakingConfig.salt().approve( address(this), type(uint256).max );
//        _staking.stakeSALT( 500000 ether );
//        this.castVote(ballotID, Vote.NO_CHANGE);
//        vm.stopPrank();
//
//        // Verify vote totals
//        uint256 increaseVotes = this.votesCastForBallot(ballotID, Vote.INCREASE);
//        uint256 noChangeVotes = this.votesCastForBallot(ballotID, Vote.NO_CHANGE);
//        uint256 totalVotes = this.ballotVoteTotals(ballotID);
//
//        assertEq(increaseVotes, 2000000 ether, "INCREASE votes do not match the sum of votes.");
//        assertEq(noChangeVotes, 1500000 ether, "NO_CHANGE votes do not match the sum of votes.");
//        assertEq(totalVotes, increaseVotes + noChangeVotes, "Total votes do not match the sum of votes.");
//    }
//
//
//	// A unit test with multiple users voting on an approvla ballot and verifying the vote totals
//	function testApprovalBallotVoting() public {
//        string memory ballotName = "ApprovalBallotTest";
//
//        // Test proposeParameterBallot function
//        vm.startPrank(DEV_WALLET);
//        this.proposeCountryInclusion(ballotName, "USA");
//        vm.stopPrank();
//
//        uint256 ballotID = this.openBallotsByName(ballotName);
//        Ballot memory ballot = this.ballotForID(ballotID);
//        assertEq(ballot.ballotIsLive, true, "The ballot should be live.");
//
//        // Test multiple users voting on the ballot
//
//        // Voting by DEV_WALLET
//        vm.startPrank(DEV_WALLET);
//        _staking.stakeSALT( 2000000 ether );
//
//		vm.expectRevert( "Invalid VoteType for Approval Ballot" );
//        this.castVote(ballotID, Vote.INCREASE);
//		vm.expectRevert( "Invalid VoteType for Approval Ballot" );
//        this.castVote(ballotID, Vote.NO_CHANGE);
//		vm.expectRevert( "Invalid VoteType for Approval Ballot" );
//        this.castVote(ballotID, Vote.DECREASE);
//
//
//        this.castVote(ballotID, Vote.YES);
//        stakingConfig.salt().transfer(bob, 1000000 ether);
//        vm.stopPrank();
//
//        // Voting by alice
//        vm.startPrank(alice);
//        _staking.stakeSALT( 1000000 ether );
//        this.castVote(ballotID, Vote.NO);
//        vm.stopPrank();
//
//		// Coting by bob
//        vm.startPrank(bob);
//        stakingConfig.salt().approve( address(_staking), type(uint256).max );
//        stakingConfig.salt().approve( address(this), type(uint256).max );
//        _staking.stakeSALT( 500000 ether );
//        this.castVote(ballotID, Vote.NO);
//        vm.stopPrank();
//
//        // Verify vote totals
//        uint256 yesVotes = this.votesCastForBallot(ballotID, Vote.YES);
//        uint256 noVotes = this.votesCastForBallot(ballotID, Vote.NO);
//        uint256 totalVotes = this.ballotVoteTotals(ballotID);
//
//        assertEq(yesVotes, 2000000 ether, "YES votes do not match the sum of votes.");
//        assertEq(noVotes, 1500000 ether, "NO votes do not match the sum of votes.");
//        assertEq(totalVotes, yesVotes + noVotes, "Total votes do not match the sum of votes.");
//    }
//
//    // A unit test to verify that a user cannot cast a vote on a ballot that is not open for voting.
//    function testUserCannotVoteOnClosedBallot() public {
//        vm.startPrank( alice );
//
//        // Alice proposes a parameter ballot
//        string memory ballotName = "TestBallot";
//        this.proposeParameterBallot( ballotName );
//        uint256 ballotID = openBallotsByName[ballotName];
//
//        // Alice casts a vote on the newly created ballot
//        _staking.stakeSALT( 1000000 ether );
//        this.castVote(ballotID, Vote.INCREASE);
//
//        // Close the ballot
//        ballots[ballotID].ballotIsLive = false;
//
//        // Alice attempts to cast a vote on the closed ballot
//        vm.expectRevert("The specified ballot is not open for voting");
//        this.castVote(ballotID, Vote.DECREASE);
//    }
//
//
//    // A unit test to verify that a user cannot cast an incorrect votetype on a Parameter Ballot
//	function testIncorrectParameterVote() public {
//        string memory ballotName = "ParameterBallotTest";
//
//        // Test proposeParameterBallot function
//        vm.startPrank(DEV_WALLET);
//        this.proposeParameterBallot(ballotName);
//        vm.stopPrank();
//
//        uint256 ballotID = this.openBallotsByName(ballotName);
//
//        // Voting by DEV_WALLET
//        vm.startPrank(DEV_WALLET);
//        _staking.stakeSALT( 2000000 ether );
//
//		vm.expectRevert( "Invalid VoteType for Parameter Ballot" );
//        this.castVote(ballotID, Vote.YES);
//		vm.expectRevert( "Invalid VoteType for Parameter Ballot" );
//        this.castVote(ballotID, Vote.NO);
//
//        vm.stopPrank();
//    }
//
//
//	// A unit test with multiple users voting on an approvla ballot and verifying the vote totals
//	function testIncorrectApprovalVote() public {
//        string memory ballotName = "ApprovalBallotTest";
//
//        // Test proposeParameterBallot function
//        vm.startPrank(DEV_WALLET);
//        this.proposeCountryInclusion(ballotName, "USA");
//        vm.stopPrank();
//
//        uint256 ballotID = this.openBallotsByName(ballotName);
//
//        // Voting by DEV_WALLET
//        vm.startPrank(DEV_WALLET);
//        _staking.stakeSALT( 2000000 ether );
//
//		vm.expectRevert( "Invalid VoteType for Approval Ballot" );
//        this.castVote(ballotID, Vote.INCREASE);
//		vm.expectRevert( "Invalid VoteType for Approval Ballot" );
//        this.castVote(ballotID, Vote.NO_CHANGE);
//		vm.expectRevert( "Invalid VoteType for Approval Ballot" );
//        this.castVote(ballotID, Vote.DECREASE);
//        vm.stopPrank();
//    }
//
//
//    // A unit test to verify that a user cannot propose a token whitelisting if the token has already been whitelisted.
//	function testWhitelistingAlreadyWhitelisted() public {
//
//        // Whitelist the token (which will be paired with WBTC and WETH)
//		stakingConfig.whitelist( IUniswapV2Pair(_factory.getPair( address(_usds), address(_wbtc))));
//		stakingConfig.whitelist( IUniswapV2Pair(_factory.getPair( address(_usds), address(_weth))));
//
//       vm.startPrank(DEV_WALLET);
//
//        vm.expectRevert("The token has already been whitelisted");
//        this.proposeTokenWhitelisting("whitelist_usds", address(_usds), "test", "test");
//		}
//
//
//
//    // A unit test to verify that a user cannot propose a token unwhitelisting if the token has not been whitelisted.
//	function testUnwhitelistingNonWhitelisted() public {
//
//       vm.startPrank(DEV_WALLET);
//
//        vm.expectRevert("Can only unwhitelist a whitelisted token");
//        this.proposeTokenUnwhitelisting("unwhitelist_usds", address(_usds), "test", "test");
//		}
//
//
//    // A unit test to verify that a user cannot propose a parameter ballot if there is already an open one.
//	function testDuplicateProposal() public {
//		string memory ballotName = "Proposal";
//
//		// Test proposeParameterBallot function
//		vm.startPrank(DEV_WALLET);
//		this.proposeCountryInclusion(ballotName, "USA");
//
//		vm.expectRevert( "Cannot create a proposal for an open ballot" );
//		this.proposeCountryInclusion(ballotName, "USA");
//		vm.stopPrank();
//
//	}
//
//    }
//
