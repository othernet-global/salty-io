// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "../../dev/Deployment.sol";
import "./TestCallReceiver.sol";


contract TestDAO is Deployment
	{
	// User wallets for testing
    address public constant alice = address(0x1111);
    address public constant bob = address(0x2222);


	constructor()
		{
		// If $COVERAGE=yes, create an instance of the contract so that coverage testing can work
		// Otherwise, what is tested is the actual deployed contract on the blockchain (as specified in Deployment.sol)
		if ( keccak256(bytes(vm.envString("COVERAGE" ))) == keccak256(bytes("yes" )))
			initializeContracts();

		grantAccessAlice();
		grantAccessBob();
		grantAccessCharlie();
		grantAccessDeployer();
		grantAccessDefault();

		finalizeBootstrap();

		vm.prank(address(daoVestingWallet));
		salt.transfer(DEPLOYER, 15000000 ether);

		vm.startPrank( DEPLOYER );
		salt.transfer( alice, 10000000 ether );
		usdc.transfer( DEPLOYER, 2000000 * 10**6 );
		usdc.transfer( alice, 1000000 * 10**6 );
		vm.stopPrank();

		// Allow time for proposals
		vm.warp( block.timestamp + 45 days );
		}


    function setUp() public
    	{
    	vm.startPrank( DEPLOYER );
    	usdc.approve( address(dao), type(uint256).max );
    	salt.approve( address(staking), type(uint256).max );
    	usdc.approve( address(proposals), type(uint256).max );
    	vm.stopPrank();

    	vm.startPrank( alice );
    	usdc.approve( address(dao), type(uint256).max );
    	salt.approve( address(staking), type(uint256).max );
    	usdc.approve( address(proposals), type(uint256).max );
    	vm.stopPrank();
    	}



	function _parameterValue( Parameters.ParameterTypes parameter ) internal view returns (uint256)
		{
		if ( parameter == Parameters.ParameterTypes.maximumWhitelistedPools )
			return poolsConfig.maximumWhitelistedPools();

		else if ( parameter == Parameters.ParameterTypes.minUnstakeWeeks )
			return stakingConfig.minUnstakeWeeks();
		else if ( parameter == Parameters.ParameterTypes.maxUnstakeWeeks )
			return stakingConfig.maxUnstakeWeeks();
		else if ( parameter == Parameters.ParameterTypes.minUnstakePercent )
			return stakingConfig.minUnstakePercent();
		else if ( parameter == Parameters.ParameterTypes.modificationCooldown )
			return stakingConfig.modificationCooldown();

		else if ( parameter == Parameters.ParameterTypes.rewardsEmitterDailyPercentTimes1000 )
			return rewardsConfig.rewardsEmitterDailyPercentTimes1000();
		else if ( parameter == Parameters.ParameterTypes.emissionsWeeklyPercentTimes1000 )
			return rewardsConfig.emissionsWeeklyPercentTimes1000();
		else if ( parameter == Parameters.ParameterTypes.stakingRewardsPercent )
			return rewardsConfig.stakingRewardsPercent();

		else if ( parameter == Parameters.ParameterTypes.bootstrappingRewards )
			return daoConfig.bootstrappingRewards();
		else if ( parameter == Parameters.ParameterTypes.percentRewardsBurned )
			return daoConfig.percentRewardsBurned();
		else if ( parameter == Parameters.ParameterTypes.baseBallotQuorumPercentTimes1000 )
			return daoConfig.baseBallotQuorumPercentTimes1000();
		else if ( parameter == Parameters.ParameterTypes.ballotDuration )
			return daoConfig.ballotMinimumDuration();
		else if ( parameter == Parameters.ParameterTypes.requiredProposalPercentStakeTimes1000 )
			return daoConfig.requiredProposalPercentStakeTimes1000();
		else if ( parameter == Parameters.ParameterTypes.percentRewardsForReserve )
			return daoConfig.percentRewardsForReserve();
		else if ( parameter == Parameters.ParameterTypes.upkeepRewardPercent )
			return daoConfig.upkeepRewardPercent();
		else if ( parameter == Parameters.ParameterTypes.ballotMaximumDuration )
			return daoConfig.ballotMaximumDuration();

		require(false, "Invalid ParameterType" );
		return 0;
		}


	function _checkFinalizeIncreaseParameterBallot( uint256 parameterNum  ) internal {

		uint256 ballotID = parameterNum + 1;
		uint256 originalValue = _parameterValue( Parameters.ParameterTypes( parameterNum ) );

        proposals.proposeParameterBallot(parameterNum, "description" );
        assertEq(proposals.ballotForID(ballotID).ballotIsLive, true, "Parameter Ballot not correctly created");

        proposals.castVote(ballotID, Vote.INCREASE);

        // Increase block time to finalize the ballot
        vm.warp(block.timestamp + 11 days );

        // Test Parameter Ballot finalization
        dao.finalizeBallot(ballotID);
        assertEq(proposals.ballotForID(ballotID).ballotIsLive, false, "Parameter Ballot not correctly finalized");

		uint256 newValue = _parameterValue( Parameters.ParameterTypes( parameterNum ) );

		assert( newValue > originalValue );
    }


	function _checkFinalizeNoChangeParameterBallot( uint256 parameterNum  ) internal {

		uint256 ballotID = parameterNum + 1;
		uint256 originalValue = _parameterValue( Parameters.ParameterTypes( parameterNum ) );

        proposals.proposeParameterBallot(parameterNum, "description" );
        assertEq(proposals.ballotForID(ballotID).ballotIsLive, true, "Parameter Ballot not correctly created");

        proposals.castVote(ballotID, Vote.NO_CHANGE);

        // Increase block time to finalize the ballot
        vm.warp(block.timestamp + 11 days );

        // Test Parameter Ballot finalization
        dao.finalizeBallot(ballotID);
        assertEq(proposals.ballotForID(ballotID).ballotIsLive, false, "Parameter Ballot not correctly finalized");

		uint256 newValue = _parameterValue( Parameters.ParameterTypes( parameterNum ) );

		assert( newValue == originalValue );
    }


	function _checkFinalizeDecreaseParameterBallot( uint256 parameterNum  ) internal {

//		console.log( "PARAM: ", parameterNum );
		uint256 ballotID = parameterNum + 1;
		uint256 originalValue = _parameterValue( Parameters.ParameterTypes( parameterNum ) );

//		console.log( "\ta" );
        proposals.proposeParameterBallot(parameterNum, "description" );
        assertEq(proposals.ballotForID(ballotID).ballotIsLive, true, "Parameter Ballot not correctly created");

//		console.log( "\tb" );
        proposals.castVote(ballotID, Vote.DECREASE);

//		console.log( "\tc" );
        // Increase block time to finalize the ballot
        vm.warp(block.timestamp + 11 days );

        // Test Parameter Ballot finalization
        dao.finalizeBallot(ballotID);
        assertEq(proposals.ballotForID(ballotID).ballotIsLive, false, "Parameter Ballot not correctly finalized");

//		console.log( "\td" );
		uint256 newValue = _parameterValue( Parameters.ParameterTypes( parameterNum ) );

		if ( parameterNum != 1 )
			assert( newValue < originalValue );
    }


	// A unit test to test all parameters and that a successful INCREASE vote has the expected effects
    function testFinalizeIncreaseParameterBallots() public
    	{
        vm.startPrank(alice);
        staking.stakeSALT( 5000000 ether );

    	for( uint256 i = 0; i < 16; i++ )
	 		_checkFinalizeIncreaseParameterBallot( i );
    	}


	// A unit test to test all parameters and that a successful DECREASE vote has the expected effects
    function testFinalizeDecreaseParameterBallots() public
    	{
        vm.startPrank(alice);
        staking.stakeSALT( 5000000 ether );

    	for( uint256 i = 0; i < 16; i++ )
	 		_checkFinalizeDecreaseParameterBallot( i );
    	}


	// A unit test to test all parameters and that a successful NO_CHANGE vote has the expected effects
    function testFinalizeNoChangeParameterBallots() public
    	{
        vm.startPrank(alice);
        staking.stakeSALT( 5000000 ether );

    	for( uint256 i = 0; i < 16; i++ )
	 		_checkFinalizeNoChangeParameterBallot( i );
    	}


	function _voteForAndFinalizeBallot( uint256 ballotID, Vote vote ) internal
		{
        assertEq(proposals.ballotForID(ballotID).ballotIsLive, true, "Ballot not correctly created");

        proposals.castVote(ballotID, vote);

        // Increase block time to finalize the ballot
        vm.warp(block.timestamp + 11 days );

        // Test Parameter Ballot finalization
        dao.finalizeBallot(ballotID);
        assertEq(proposals.ballotForID(ballotID).ballotIsLive, false, "Ballot not correctly finalized");
		}


	// A unit test to test that finalizing an approved whitelist token ballot has the desired effect
    function testWhitelistTokenApproved() public
    	{
        vm.startPrank(alice);
        staking.stakeSALT( 1000000 ether );

       	IERC20 token = new TestERC20("TEST", 18);
        proposals.proposeTokenWhitelisting( token, "", "" );

		uint256 ballotID = 1;
        proposals.castVote(ballotID, Vote.YES);

        // Increase block time to finalize the ballot
        vm.warp(block.timestamp + 11 days );

        // Test Parameter Ballot finalization
		salt.transfer( address(dao), 399999 ether );

		vm.expectRevert( "Whitelisting is not currently possible due to insufficient bootstrapping rewards" );
        dao.finalizeBallot(ballotID);

		salt.transfer( address(dao), 5 ether );

    	uint256 startingBalanceDAO = salt.balanceOf(address(dao));
        dao.finalizeBallot(ballotID);

		// Check for the effects of the vote
		assertTrue( poolsConfig.tokenHasBeenWhitelisted(token, weth, usdc), "Token not whitelisted" );

		// Check to see that the bootstrapping rewards have been sent
		bytes32[] memory poolIDs = new bytes32[](2);
		poolIDs[0] = PoolUtils._poolID(token,weth);
		poolIDs[1] = PoolUtils._poolID(token,usdc);

		uint256[] memory pendingRewards = liquidityRewardsEmitter.pendingRewardsForPools( poolIDs );

		assertEq( pendingRewards[0], daoConfig.bootstrappingRewards() );
		assertEq( pendingRewards[1], daoConfig.bootstrappingRewards() );

		uint256 sentFromDAO = startingBalanceDAO - salt.balanceOf(address(dao));
		assertEq( sentFromDAO, daoConfig.bootstrappingRewards() * 2 );
    	}


	// A unit test to test that finalizing a denied whitelist token ballot has the desired effect
    function testWhitelistTokenDenied() public
    	{
        vm.startPrank(alice);
        staking.stakeSALT( 1000000 ether );

       	IERC20 token = new TestERC20("TEST", 18);
		salt.transfer( address(dao), 1000000 ether );

        proposals.proposeTokenWhitelisting( token, "", "description"  );
		_voteForAndFinalizeBallot(1, Vote.NO);

		// Check for the effects of the vote
		assertFalse( poolsConfig.tokenHasBeenWhitelisted(token, weth, usdc), "Token should not be whitelisted" );
    	}


	// A unit test to test that finalizing an approved whitelist token ballot has the desired effect
    function testUnwhitelistTokenApproved() public
    	{
        vm.startPrank(alice);
        staking.stakeSALT( 1000000 ether );

       	IERC20 token = new TestERC20("TEST", 18);
		salt.transfer( address(dao), 1000000 ether );

        proposals.proposeTokenWhitelisting( token, "", "" );
		_voteForAndFinalizeBallot(1, Vote.YES);

        proposals.proposeTokenUnwhitelisting( token, "", "" );
		_voteForAndFinalizeBallot(2, Vote.YES);

		// Check for the effects of the vote
		assertFalse( poolsConfig.tokenHasBeenWhitelisted(token, weth, usdc), "Token should not be whitelisted" );
    	}


	// A unit test to test that finalizing a denied whitelist token ballot has the desired effect
    function testUnwhitelistTokenDenied() public
    	{
        vm.startPrank(alice);
        staking.stakeSALT( 1000000 ether );

       	IERC20 token = new TestERC20("TEST", 18);
		salt.transfer( address(dao), 1000000 ether );

        proposals.proposeTokenWhitelisting( token, "", "" );
		_voteForAndFinalizeBallot(1, Vote.YES);

        proposals.proposeTokenUnwhitelisting( token, "", "" );
		_voteForAndFinalizeBallot(2, Vote.NO);

		// Check for the effects of the vote
		assertTrue( poolsConfig.tokenHasBeenWhitelisted(token, weth, usdc), "Token not whitelisted" );
    	}


	// A unit test to test that finalizing an approved send SALT ballot has the desired effect
    function testSendSaltApproved() public
    	{
        vm.startPrank(alice);
        staking.stakeSALT( 1000000 ether );

		salt.transfer( address(dao), 1000000 ether );

        proposals.proposeSendSALT( bob, 123 ether, "description" );
		_voteForAndFinalizeBallot(1, Vote.YES);

		// Check for the effects of the vote
		assertEq( salt.balanceOf( bob ), 123 ether, "Bob didn't receive SALT" );
    	}


	// A unit test to test that finalizing a denied send SALT ballot has the desired effect
    function testSendSaltDenied() public
    	{
        vm.startPrank(alice);
        staking.stakeSALT( 1000000 ether );

		salt.transfer( address(dao), 1000000 ether );

        proposals.proposeSendSALT( bob, 123 ether, "description" );
		_voteForAndFinalizeBallot(1, Vote.NO);

		// Check for the effects of the vote
		assertEq( salt.balanceOf( bob ), 0, "Bob shouldn't receive SALT" );
    	}


	// A unit test to test that finalizing an approved call contract ballot has the desired effect
    function testCallContractApproved() public
    	{
        vm.startPrank(alice);
        staking.stakeSALT( 1000000 ether );

		TestCallReceiver testReceiver = new TestCallReceiver();

        proposals.proposeCallContract( address(testReceiver), 123, "description" );
		_voteForAndFinalizeBallot(1, Vote.YES);

		// Check for the effects of the vote
		assertEq( testReceiver.value(), 123, "Receiver didn't receive the call" );
    	}


	// A unit test to test that finalizing a denied call contract ballot has the desired effect
    function testCallContractDenied() public
    	{
        vm.startPrank(alice);
        staking.stakeSALT( 1000000 ether );

		TestCallReceiver testReceiver = new TestCallReceiver();

        proposals.proposeCallContract( address(testReceiver), 123, "description" );
		_voteForAndFinalizeBallot(1, Vote.NO);

		// Check for the effects of the vote
		assertTrue( testReceiver.value() != 123, "Receiver shouldn't receive the call" );
    	}


	// A unit test to test that finalizing an approved include country ballot has the desired effect
    function testIncludeCountryApproved() public
    	{
        vm.startPrank(alice);
        staking.stakeSALT( 1000000 ether );

        proposals.proposeCountryExclusion( "ZZ", "description" );
		_voteForAndFinalizeBallot(1, Vote.YES);

		assertTrue( dao.countryIsExcluded( "ZZ" ), "Country should be excluded" );
		vm.stopPrank();

		// GeoVersion is now 1 and effectively has cleared access
		bytes memory sig = abi.encodePacked(aliceAccessSignature1);
		vm.prank( alice );
		accessManager.grantAccess(sig);


        vm.startPrank(alice);
        proposals.proposeCountryInclusion( "ZZ", "description" );
		_voteForAndFinalizeBallot(2, Vote.YES);

		assertFalse( dao.countryIsExcluded( "ZZ" ), "Country shouldn't be excluded" );
    	}


	// A unit test to test that finalizing a denied include country ballot has the desired effect
    function testIncludeCountryDenied() public
    	{
        vm.startPrank(alice);
        staking.stakeSALT( 1000000 ether );

        proposals.proposeCountryExclusion( "ZZ", "description" );
		_voteForAndFinalizeBallot(1, Vote.YES);

		assertTrue( dao.countryIsExcluded( "ZZ" ), "Country should be excluded" );
		vm.stopPrank();

		// GeoVersion is now 1 and effectively has cleared access
		bytes memory sig = abi.encodePacked(aliceAccessSignature1);
		vm.prank( alice );
		accessManager.grantAccess(sig);


        vm.startPrank(alice);
        proposals.proposeCountryInclusion( "ZZ", "description" );
		_voteForAndFinalizeBallot(2, Vote.NO);

		assertTrue( dao.countryIsExcluded( "ZZ" ), "Country should be excluded" );
    	}


	// A unit test to test that finalizing an approved exclude country ballot has the desired effect
    function testExcludeCountryApproved() public
    	{
        vm.startPrank(alice);
        staking.stakeSALT( 1000000 ether );

        proposals.proposeCountryExclusion( "ZZ", "description" );
		_voteForAndFinalizeBallot(1, Vote.YES);

		assertTrue( dao.countryIsExcluded( "ZZ" ), "Country should be excluded" );
    	}


	// A unit test to test that finalizing a denied exclude country ballot has the desired effect
    function testExcludeCountryDenied() public
    	{
        vm.startPrank(alice);
        staking.stakeSALT( 1000000 ether );

        proposals.proposeCountryExclusion( "ZZ", "description" );
		_voteForAndFinalizeBallot(1, Vote.NO);

		assertFalse( dao.countryIsExcluded( "ZZ" ), "ZZ shouldn't be excluded" );
    	}



    function _checkAccessManagerApproved( uint256 ballotID, address newAddress) internal
    	{
        vm.startPrank(alice);
        staking.stakeSALT( 1000000 ether );

        proposals.proposeSetAccessManager( newAddress, "description" );
		_voteForAndFinalizeBallot(ballotID, Vote.YES);

		// Above finalization should create a confirmation ballot
		_voteForAndFinalizeBallot(ballotID + 1, Vote.YES);

		assertEq( address(exchangeConfig.accessManager()), newAddress, "AccessManager should have changed" );
		vm.stopPrank();
    	}


	// A unit test to test that finalizing an approved setContract ballot works with all possible contract options
	function testSetContractApproved() public
		{
		// Done last to prevent access issues
		_checkAccessManagerApproved( 1, address( new AccessManager(dao) ) );
		}


    function _checkSetAccessManagerDenied1( uint256 ballotID, address newAddress) internal
    	{
        vm.startPrank(alice);
        staking.stakeSALT( 1000000 ether );

        proposals.proposeSetAccessManager( newAddress, "description" );
		_voteForAndFinalizeBallot(ballotID, Vote.NO);

		assertFalse( address(exchangeConfig.accessManager()) == newAddress, "Contract address should not have changed" );
		vm.stopPrank();
    	}


	// A unit test to test that  with all possible contract options, finalizing a setContract ballot has no effect when the initial ballot fails
	function testSetContractDenied1() public
		{
		_checkSetAccessManagerDenied1( 1, address( new AccessManager(dao) ) );
		}


    function _checkSetContractDenied2( uint256 ballotID, address newAddress) internal
    	{
        vm.startPrank(alice);
        staking.stakeSALT( 1000000 ether );

        proposals.proposeSetAccessManager(newAddress, "description" );
		_voteForAndFinalizeBallot(ballotID, Vote.YES);

		// Above finalization should create a confirmation ballot
		_voteForAndFinalizeBallot(ballotID + 1, Vote.NO);

		assertFalse( address(exchangeConfig.accessManager()) == newAddress, "Contract address should not have changed" );
		vm.stopPrank();
    	}


	// A unit test to test that  with all possible contract options, finalizing a setContract ballot has no effect when the confirm ballot fails
	function testSetContractDenied2() public
		{
		_checkSetContractDenied2( 1, address( new AccessManager(dao) ) );
		}


	// A unit test to test that finalizing an approved websiteUpdate ballot has the desired effect
    function testSetWebsiteApproved() public
    	{
        vm.startPrank(alice);
        staking.stakeSALT( 1000000 ether );

        proposals.proposeWebsiteUpdate( "websiteURL",  "description" );
		_voteForAndFinalizeBallot(1, Vote.YES);

		// Above finalization should create a confirmation ballot
		_voteForAndFinalizeBallot(2, Vote.YES);

		assertEq( dao.websiteURL(), "websiteURL", "Website URL should have changed" );
		vm.stopPrank();
    	}


	// A unit test to test that finalizing a websiteUpdate ballot in which the initial ballot fails has no effect
    function testSetWebsiteDenied1() public
    	{
        vm.startPrank(alice);
        staking.stakeSALT( 1000000 ether );

        proposals.proposeWebsiteUpdate( "websiteURL",  "description" );
		_voteForAndFinalizeBallot(1, Vote.NO);

		assertEq( dao.websiteURL(), "", "Website URL should not have changed" );
		vm.stopPrank();
    	}


	// A unit test to test that finalizing a websiteUpdate ballot in which the confirmation ballot fails has no effect
    function testSetWebsiteDenied2() public
    	{
        vm.startPrank(alice);
        staking.stakeSALT( 1000000 ether );

        proposals.proposeWebsiteUpdate( "websiteURL",  "description" );
		_voteForAndFinalizeBallot(1, Vote.YES);

		// Above finalization should create a confirmation ballot
		_voteForAndFinalizeBallot(2, Vote.NO);

		assertEq( dao.websiteURL(), "", "Website URL should not have changed" );
		vm.stopPrank();
    	}


	// A unit test to check the constructor of the contract.
	function testDAOConstructor() public {

        vm.startPrank(DEPLOYER);
        DAO testDAO = new DAO(pools, proposals, exchangeConfig, poolsConfig, stakingConfig, rewardsConfig, daoConfig, liquidityRewardsEmitter );

        assertEq(address(testDAO.pools()), address(pools), "Pools contract address mismatch");
        assertEq(address(testDAO.proposals()), address(proposals), "Proposals contract address mismatch");
        assertEq(address(testDAO.exchangeConfig()), address(exchangeConfig), "ExchangeConfig contract address mismatch");
        assertEq(address(testDAO.poolsConfig()), address(poolsConfig), "PoolsConfig contract address mismatch");
        assertEq(address(testDAO.stakingConfig()), address(stakingConfig), "StakingConfig contract address mismatch");
        assertEq(address(testDAO.rewardsConfig()), address(rewardsConfig), "RewardsConfig contract address mismatch");
        assertEq(address(testDAO.daoConfig()), address(daoConfig), "DAOConfig contract address mismatch");
        assertEq(address(testDAO.liquidityRewardsEmitter()), address(liquidityRewardsEmitter), "LiquidityRewardsEmitter contract address mismatch");

        vm.stopPrank();
    }


	// A unit test to validate the finalizeBallot function with ballots that should not yet be finalizable.
	function testFinalizeBallotWithNotFinalizableBallots() public {
        vm.startPrank(alice);
        staking.stakeSALT(5 ether);

        // Propose a parameter ballot
        proposals.proposeParameterBallot(0, "description");

        // Get the ballot ID
        uint256 ballotID = 1;

        // Assert that the ballot is live
        assertEq(proposals.ballotForID(ballotID).ballotIsLive, true, "Parameter Ballot not correctly created");

        // Cast a vote
        proposals.castVote(ballotID, Vote.INCREASE);

        // Try to finalize the ballot immediately (should not be possible, hence expecting a revert)
        vm.expectRevert("The ballot is not yet able to be finalized");
        dao.finalizeBallot(ballotID);

        vm.warp( block.timestamp + 11 days );

		// No quorum yet
        vm.expectRevert("The ballot is not yet able to be finalized");
        dao.finalizeBallot(ballotID);

		// Should work
        staking.stakeSALT(5000000 ether);
        proposals.castVote(ballotID, Vote.INCREASE);

        dao.finalizeBallot(ballotID);

		// Shouldn't work
        vm.expectRevert("The ballot is not yet able to be finalized");
        dao.finalizeBallot(ballotID);
        }


	// A unit test which checks that you can still see ballots after they are finalized
	function testFinalizedBallotsStillVisible() public {
        vm.startPrank(alice);
        staking.stakeSALT(5000000 ether);

        // Propose a parameter ballot
        proposals.proposeParameterBallot(0, "description");

        // Get the ballot ID
        uint256 ballotID = 1;
        vm.warp( block.timestamp + 11 days );

	    proposals.castVote(ballotID, Vote.INCREASE);

        dao.finalizeBallot(ballotID);

        Ballot memory ballot = proposals.ballotForID(ballotID);
        assertEq( ballot.ballotID, ballotID );
        }


	// A unit test to test that withdrawArbitrageProfits works as expected and sends the correct amount to the Upkeep contract
	function testWithdrawArbitrageProfits() public {
        // Initial setup
        uint256 initialBalance = weth.balanceOf(address(exchangeConfig.upkeep()));

		vm.prank(address(DEPLOYER));
		weth.transfer(address(dao), 1000 ether);

        vm.startPrank(address(dao));
        weth.approve(address(pools), 1000 ether);
        pools.deposit(weth, 1000 ether);

        uint256 depositedWETH = pools.depositedUserBalance(address(dao), weth);
        assertEq( depositedWETH, 1000 ether, "DAO should have 1000 ether deposited" );
        vm.stopPrank();

        // Call the function
        vm.prank(address(upkeep));
        dao.withdrawFromDAO(weth);

        uint256 expectedBalance = initialBalance + depositedWETH;

        // Check the result
        uint256 finalBalance = weth.balanceOf(address(exchangeConfig.upkeep()));
        assertEq(finalBalance, expectedBalance - 1, "The final balance is not correct");
    }



	// A unit test to validate that unauthorized users cannot call functions restricted to the Upkeep contract
	function testUnauthorizedAccessToUpkeepFunctions() public
    	{
    	vm.startPrank(bob);

    	vm.expectRevert("DAO.withdrawFromDAO is only callable from the Upkeep contract");
    	dao.withdrawFromDAO( weth );

    	vm.stopPrank();
    	}


    // A unit test to check if a non-excluded country, countryIsExcluded returns false
    function testCountryIsExcluded() public
        {
        string memory nonExcludedCountry = "Canada";

        bool result = dao.countryIsExcluded(nonExcludedCountry);

        assertEq(result, false, "The country should not be excluded");
        }


	// A unit test that validates that a ballot ID is correctly incremented after each proposal to ensure unique references to different ballots.
	function testIncrementingBallotID() public {

		vm.startPrank(DEPLOYER);
		salt.approve(address(staking), type(uint256).max);
		staking.stakeSALT(1000 ether);
		vm.stopPrank();

		vm.startPrank(alice);
		salt.approve(address(staking), type(uint256).max);
		staking.stakeSALT(1000 ether);
		vm.stopPrank();

        // Alice proposes a parameter change
        vm.startPrank(alice);
        proposals.proposeParameterBallot(0, "test");
        vm.stopPrank();

        // Retrieve the initial ballot ID
        uint256 initialBallotID = proposals.openBallotsByName("parameter:0test");
        assertEq(initialBallotID, 1, "Initial ballot ID should be 1");

        // Warp time to allow for another proposal
        vm.warp(block.timestamp + 1 days);

        // Deployer proposes another parameter change
        vm.startPrank(DEPLOYER);
        proposals.proposeParameterBallot(2, "test");
        vm.stopPrank();

        // Retrieve the second ballot ID
        uint256 secondBallotID = proposals.openBallotsByName("parameter:2test");
        assertEq(secondBallotID, initialBallotID + 1, "Second ballot ID should increment by 1");
    }


	// A unit test that verifies the quorum is reached when the required amount of voting power is achieved and not before.
	function testQuorumReachedNotBeforeVotingPower() public {
        // Set up the parameters for the proposal
        uint256 proposalNum = 0; // Assuming an enumeration starting at 0 for parameter proposals
        address proposer = alice;

        // Alice stakes her SALT to get voting power
        vm.prank(address(daoVestingWallet));
        salt.transfer(proposer, 1000000 ether);

        vm.startPrank(proposer);
        staking.stakeSALT(499999 ether);

        // Propose a parameter ballot
        proposals.proposeParameterBallot(proposalNum, "Increase max pools count");
		vm.stopPrank();

        uint256 ballotID = 1;

        // Expect revert because quorum has not yet been reached and do a premature finalization attempt
        vm.expectRevert("The ballot is not yet able to be finalized");
        dao.finalizeBallot(ballotID);

        // Cast a vote, but not enough for quorum
        vm.startPrank(proposer);
        proposals.castVote(ballotID, Vote.NO_CHANGE);
        vm.stopPrank();

        // Increase block time to finalize the ballot
        vm.warp(block.timestamp + daoConfig.ballotMinimumDuration());

        // Expect revert because quorum is still not reached
        vm.expectRevert("The ballot is not yet able to be finalized");
        dao.finalizeBallot(ballotID);

        // Now, increase votes to reach quorum
        vm.startPrank(proposer);
        staking.stakeSALT(2 ether);
        vm.stopPrank();

//		console.log( "REQUIRED QUORUM: ", proposals.requiredQuorumForBallotType(BallotType.PARAMETER) );
//		console.log( "SALT STAKED: ", staking.totalShares(PoolUtils.STAKED_SALT) );
//
        vm.expectRevert("The ballot is not yet able to be finalized");
        dao.finalizeBallot(ballotID);


        // Recast with increased votes
        vm.startPrank(proposer);
        proposals.castVote(ballotID, Vote.NO_CHANGE);
        vm.stopPrank();

        // Now it should be possible to finalize the ballot without reverting
        dao.finalizeBallot(ballotID);

        // Check that the ballot is finalized
        bool isBallotFinalized = proposals.ballotForID(ballotID).ballotIsLive;
        assertEq(isBallotFinalized, false, "Ballot should be finalized");
    }


	// A unit test that a successful reward sending operation after whitelisting a token balances bootstrap rewards correctly and does not distribute funds when the balance is insufficient.
	function testSuccessfulRewardDistributionAfterWhitelisting() public
		{
		// Alice stakes her SALT to get voting power
		vm.startPrank(address(daoVestingWallet));
		salt.transfer(alice, 1000000 ether);				// for staking and voting
		salt.transfer(address(dao), 1000000 ether); // bootstrapping rewards
		vm.stopPrank();

		vm.startPrank(alice);
		staking.stakeSALT(500000 ether);

		IERC20 test = new TestERC20( "TEST", 18 );

		// Propose a whitelisting ballot
		proposals.proposeTokenWhitelisting(test, "url", "description");
		vm.stopPrank();

		uint256 ballotID = 1;

		vm.startPrank(alice);
		proposals.castVote(ballotID, Vote.YES);

		// Increase block time to finalize the ballot
		vm.warp(block.timestamp + daoConfig.ballotMinimumDuration());

		uint256 bootstrapRewards = daoConfig.bootstrappingRewards();
        uint256 initialDaoBalance = salt.balanceOf(address(dao));
        require(initialDaoBalance > bootstrapRewards * 2, "Insufficient SALT in DAO for rewards bootstrapping");

        dao.finalizeBallot(ballotID);


        // Assert that the token has been whitelisted
        assertTrue(poolsConfig.tokenHasBeenWhitelisted(test, weth, usdc), "Token was not whitelisted");

        // Assert the correct amount of bootstrapping rewards have been deducted
        uint256 finalDaoBalance = salt.balanceOf(address(dao));
        assertEq(finalDaoBalance, initialDaoBalance - (bootstrapRewards * 2), "Bootstrapping rewards were not correctly deducted");

        vm.stopPrank();
    }


    // A unit test to verify that ballots cannot be manually removed before their maximum timestamp has been reached
	function testEarlyManualRemoval() public
		{
		// Alice stakes her SALT to get voting power
		vm.startPrank(address(daoVestingWallet));
		salt.transfer(alice, 1000000 ether);				// for staking and voting
		salt.transfer(address(dao), 1000000 ether); // bootstrapping rewards
		vm.stopPrank();

		vm.startPrank(alice);
		staking.stakeSALT(500000 ether);

		IERC20 test = new TestERC20( "TEST", 18 );

		// Propose a whitelisting ballot
		proposals.proposeTokenWhitelisting(test, "url", "description");

		uint256 ballotID = 1;

		// Increase block time to finalize the ballot
		skip( daoConfig.ballotMaximumDuration() - 1);

		vm.expectRevert( "The ballot is not yet able to be manually removed" );
		dao.manuallyRemoveBallot(ballotID);
		}


    // A unit test to ensure that ballots can be manually removed when their maximum timestamp has been reached
	function testManualRemoval() public
		{
		// Alice stakes her SALT to get voting power
		vm.startPrank(address(daoVestingWallet));
		salt.transfer(alice, 1000000 ether);				// for staking and voting
		salt.transfer(address(dao), 1000000 ether); // bootstrapping rewards
		vm.stopPrank();

		vm.startPrank(alice);
		staking.stakeSALT(500000 ether);

		IERC20 test = new TestERC20( "TEST", 18 );

		// Propose a whitelisting ballot
		proposals.proposeTokenWhitelisting(test, "url", "description");

		uint256 ballotID = 1;

		// Increase block time to finalize the ballot
		skip( daoConfig.ballotMaximumDuration() + 1);

		dao.manuallyRemoveBallot(ballotID);
        assertEq(proposals.ballotForID(ballotID).ballotIsLive, false, "Ballot should have been removed");
		}


	// A unit test to make sure that a ballot can be recreated after it is manually removed
	function testRecreateAfterManualRemoval() public
		{
		// Alice stakes her SALT to get voting power
		vm.startPrank(address(daoVestingWallet));
		salt.transfer(alice, 1000000 ether);				// for staking and voting
		salt.transfer(address(dao), 1000000 ether); // bootstrapping rewards
		vm.stopPrank();

		vm.startPrank(alice);
		staking.stakeSALT(500000 ether);

		IERC20 test = new TestERC20( "TEST", 18 );

		// Propose a whitelisting ballot
		proposals.proposeTokenWhitelisting(test, "url", "description");

		uint256 ballotID = 1;

		// Increase block time to finalize the ballot
		skip( daoConfig.ballotMaximumDuration() + 1);

		// Propose a whitelisting ballot
		vm.expectRevert( "Users can only have one active proposal at a time" );
		proposals.proposeTokenWhitelisting(test, "url", "description");

		dao.manuallyRemoveBallot(ballotID);
        assertEq(proposals.ballotForID(ballotID).ballotIsLive, false, "Ballot should have been removed");

   		proposals.proposeTokenWhitelisting(test, "url", "description");
		}


	// A unit test to make sure that manually removing a ballot does not execute it
	function testManualRemovalDoesNotExecute() public
		{
		// Alice stakes her SALT to get voting power
		vm.startPrank(address(daoVestingWallet));
		salt.transfer(alice, 1000000 ether);				// for staking and voting
		salt.transfer(address(dao), 1000000 ether); // bootstrapping rewards
		vm.stopPrank();

		vm.startPrank(alice);
		staking.stakeSALT(500000 ether);

		IERC20 token = new TestERC20( "TEST", 18 );

		// Propose a whitelisting ballot
		proposals.proposeTokenWhitelisting(token, "url", "description");

		uint256 ballotID = 1;

		// Increase block time to finalize the ballot
		skip( daoConfig.ballotMaximumDuration() + 1);

		dao.manuallyRemoveBallot(ballotID);
        assertEq(proposals.ballotForID(ballotID).ballotIsLive, false, "Ballot should have been removed");

        assertFalse( poolsConfig.tokenHasBeenWhitelisted(token, weth, usdc), "Token should not have been whitelisted" );
		}



    function testCallContractApproveRevertHandled() public {
        // Arrange
        vm.startPrank(alice);
        staking.stakeSALT(1000000 ether);

        TestERC20 brokenReceiver = new TestERC20( "TEST", 18 );

        uint256 ballotID = proposals.proposeCallContract(address(brokenReceiver), 123, "description" );

        _voteForAndFinalizeBallot(ballotID, Vote.YES);
    }
    }

