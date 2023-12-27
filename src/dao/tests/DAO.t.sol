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

		// Mint some USDS to the DEPLOYER and alice
		vm.startPrank( address(collateralAndLiquidity) );
		usds.mintTo( DEPLOYER, 2000000 ether );
		usds.mintTo( alice, 1000000 ether );
		vm.stopPrank();

		vm.prank( DEPLOYER );
		salt.transfer( alice, 10000000 ether );

		// Allow time for proposals
		vm.warp( block.timestamp + 45 days );
		}


    function setUp() public
    	{
    	vm.startPrank( DEPLOYER );
    	usds.approve( address(dao), type(uint256).max );
    	salt.approve( address(staking), type(uint256).max );
    	usds.approve( address(proposals), type(uint256).max );
    	vm.stopPrank();

    	vm.startPrank( alice );
    	usds.approve( address(dao), type(uint256).max );
    	salt.approve( address(staking), type(uint256).max );
    	usds.approve( address(proposals), type(uint256).max );
    	vm.stopPrank();
    	}



	function _parameterValue( Parameters.ParameterTypes parameter ) internal view returns (uint256)
		{
		if ( parameter == Parameters.ParameterTypes.maximumWhitelistedPools )
			return poolsConfig.maximumWhitelistedPools();
		if ( parameter == Parameters.ParameterTypes.maximumInternalSwapPercentTimes1000 )
			return poolsConfig.maximumInternalSwapPercentTimes1000();

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
		else if ( parameter == Parameters.ParameterTypes.percentRewardsSaltUSDS )
			return rewardsConfig.percentRewardsSaltUSDS();

		else if ( parameter == Parameters.ParameterTypes.rewardPercentForCallingLiquidation )
			return stableConfig.rewardPercentForCallingLiquidation();
		else if ( parameter == Parameters.ParameterTypes.maxRewardValueForCallingLiquidation )
			return stableConfig.maxRewardValueForCallingLiquidation();
		else if ( parameter == Parameters.ParameterTypes.minimumCollateralValueForBorrowing )
			return stableConfig.minimumCollateralValueForBorrowing();
		else if ( parameter == Parameters.ParameterTypes.initialCollateralRatioPercent )
			return stableConfig.initialCollateralRatioPercent();
		else if ( parameter == Parameters.ParameterTypes.minimumCollateralRatioPercent )
			return stableConfig.minimumCollateralRatioPercent();
		else if ( parameter == Parameters.ParameterTypes.percentArbitrageProfitsForStablePOL )
			return stableConfig.percentArbitrageProfitsForStablePOL();

		else if ( parameter == Parameters.ParameterTypes.bootstrappingRewards )
			return daoConfig.bootstrappingRewards();
		else if ( parameter == Parameters.ParameterTypes.percentPolRewardsBurned )
			return daoConfig.percentPolRewardsBurned();
		else if ( parameter == Parameters.ParameterTypes.baseBallotQuorumPercentTimes1000 )
			return daoConfig.baseBallotQuorumPercentTimes1000();
		else if ( parameter == Parameters.ParameterTypes.ballotDuration )
			return daoConfig.ballotMinimumDuration();
		else if ( parameter == Parameters.ParameterTypes.requiredProposalPercentStakeTimes1000 )
			return daoConfig.requiredProposalPercentStakeTimes1000();
		else if ( parameter == Parameters.ParameterTypes.maxPendingTokensForWhitelisting )
			return daoConfig.maxPendingTokensForWhitelisting();
		else if ( parameter == Parameters.ParameterTypes.arbitrageProfitsPercentPOL )
			return daoConfig.arbitrageProfitsPercentPOL();
		else if ( parameter == Parameters.ParameterTypes.upkeepRewardPercent )
			return daoConfig.upkeepRewardPercent();

		else if ( parameter == Parameters.ParameterTypes.maximumPriceFeedPercentDifferenceTimes1000 )
			return priceAggregator.maximumPriceFeedPercentDifferenceTimes1000();
		else if ( parameter == Parameters.ParameterTypes.setPriceFeedCooldown )
			return priceAggregator.priceFeedModificationCooldown();

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

		if ( parameterNum != 10 )
		if ( parameterNum != 14 )
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

		if ( parameterNum != 10 )
		if ( parameterNum != 14 )
			assert( newValue < originalValue );
    }


	// A unit test to test all parameters and that a successful INCREASE vote has the expected effects
    function testFinalizeIncreaseParameterBallots() public
    	{
        vm.startPrank(alice);
        staking.stakeSALT( 5000000 ether );

    	for( uint256 i = 0; i < 26; i++ )
	 		_checkFinalizeIncreaseParameterBallot( i );
    	}


	// A unit test to test all parameters and that a successful DECREASE vote has the expected effects
    function testFinalizeDecreaseParameterBallots() public
    	{
        vm.startPrank(alice);
        staking.stakeSALT( 5000000 ether );

    	for( uint256 i = 0; i < 26; i++ )
	 		_checkFinalizeDecreaseParameterBallot( i );
    	}


	// A unit test to test all parameters and that a successful NO_CHANGE vote has the expected effects
    function testFinalizeNoChangeParameterBallots() public
    	{
        vm.startPrank(alice);
        staking.stakeSALT( 5000000 ether );

    	for( uint256 i = 0; i < 26; i++ )
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
		assertTrue( poolsConfig.tokenHasBeenWhitelisted(token, wbtc, weth), "Token not whitelisted" );

		// Check to see that the bootstrapping rewards have been sent
		bytes32[] memory poolIDs = new bytes32[](2);
		poolIDs[0] = PoolUtils._poolID(token,wbtc);
		poolIDs[1] = PoolUtils._poolID(token,weth);

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
		assertFalse( poolsConfig.tokenHasBeenWhitelisted(token, wbtc, weth), "Token should not be whitelisted" );
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
		assertFalse( poolsConfig.tokenHasBeenWhitelisted(token, wbtc, weth), "Token should not be whitelisted" );
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
		assertTrue( poolsConfig.tokenHasBeenWhitelisted(token, wbtc, weth), "Token not whitelisted" );
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

        proposals.proposeCountryExclusion( "US", "description" );
		_voteForAndFinalizeBallot(1, Vote.YES);

		assertTrue( dao.countryIsExcluded( "US" ), "US should be excluded" );
		vm.stopPrank();

		// GeoVersion is now 1 and effectively has cleared access
		bytes memory sig = abi.encodePacked(aliceAccessSignature1);
		vm.prank( alice );
		accessManager.grantAccess(sig);


        vm.startPrank(alice);
        proposals.proposeCountryInclusion( "US", "description" );
		_voteForAndFinalizeBallot(2, Vote.YES);

		assertFalse( dao.countryIsExcluded( "US" ), "US shouldn't be excluded" );
    	}


	// A unit test to test that finalizing a denied include country ballot has the desired effect
    function testIncludeCountryDenied() public
    	{
        vm.startPrank(alice);
        staking.stakeSALT( 1000000 ether );

        proposals.proposeCountryExclusion( "US", "description" );
		_voteForAndFinalizeBallot(1, Vote.YES);

		assertTrue( dao.countryIsExcluded( "US" ), "US should be excluded" );
		vm.stopPrank();

		// GeoVersion is now 1 and effectively has cleared access
		bytes memory sig = abi.encodePacked(aliceAccessSignature1);
		vm.prank( alice );
		accessManager.grantAccess(sig);


        vm.startPrank(alice);
        proposals.proposeCountryInclusion( "US", "description" );
		_voteForAndFinalizeBallot(2, Vote.NO);

		assertTrue( dao.countryIsExcluded( "US" ), "US should be excluded" );
    	}


	// A unit test to test that finalizing an approved exclude country ballot has the desired effect
    function testExcludeCountryApproved() public
    	{
        vm.startPrank(alice);
        staking.stakeSALT( 1000000 ether );

        proposals.proposeCountryExclusion( "US", "description" );
		_voteForAndFinalizeBallot(1, Vote.YES);

		assertTrue( dao.countryIsExcluded( "US" ), "USA should be excluded" );
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


	function _contractForName( string memory contractName ) internal view returns (address)
		{
		bytes32 nameHash = keccak256(bytes(contractName));

		if ( nameHash == keccak256(bytes("accessManager" )))
			return address(exchangeConfig.accessManager());
		if ( nameHash == keccak256(bytes("priceFeed1" )))
			return address(priceAggregator.priceFeed1());
		if ( nameHash == keccak256(bytes("priceFeed2" )))
			return address(priceAggregator.priceFeed2());
		if ( nameHash == keccak256(bytes("priceFeed3" )))
			return address(priceAggregator.priceFeed3());

		return address(0);
		}


    function _checkSetContractApproved( uint256 ballotID, string memory contractName, address newAddress) internal
    	{
        vm.startPrank(alice);
        staking.stakeSALT( 1000000 ether );

        proposals.proposeSetContractAddress( contractName, newAddress, "description" );
		_voteForAndFinalizeBallot(ballotID, Vote.YES);

		// Above finalization should create a confirmation ballot
		_voteForAndFinalizeBallot(ballotID + 1, Vote.YES);

		assertEq( _contractForName(contractName), newAddress, "Contract address should have changed" );
		vm.stopPrank();
    	}


	// A unit test to test that finalizing an approved setContract ballot works with all possible contract options
	function testSetContractApproved() public
		{
		_checkSetContractApproved( 1, "priceFeed1", address(0x1231236 ) );
		vm.warp(block.timestamp + 60 days);
		_checkSetContractApproved( 3, "priceFeed2", address(0x1231237 ) );
		vm.warp(block.timestamp + 60 days);
		_checkSetContractApproved( 5, "priceFeed3", address(0x1231238 ) );

		// Done last to prevent access issues
		_checkSetContractApproved( 7, "accessManager", address( new AccessManager(dao) ) );
		}


    function _checkSetContractDenied1( uint256 ballotID, string memory contractName, address newAddress) internal
    	{
        vm.startPrank(alice);
        staking.stakeSALT( 1000000 ether );

        proposals.proposeSetContractAddress( contractName, newAddress, "description" );
		_voteForAndFinalizeBallot(ballotID, Vote.NO);

		assertFalse( _contractForName(contractName) == newAddress, "Contract address should not have changed" );
		vm.stopPrank();
    	}


	// A unit test to test that  with all possible contract options, finalizing a setContract ballot has no effect when the initial ballot fails
	function testSetContractDenied1() public
		{
		_checkSetContractDenied1( 1, "priceFeed", address(0x1231231 ) );
		_checkSetContractDenied1( 2, "accessManager", address( new AccessManager(dao) ) );
		_checkSetContractDenied1( 3, "stakingRewardsEmitter", address(0x1231233 ) );
		_checkSetContractDenied1( 4, "liquidityRewardsEmitter", address(0x1231234 ) );
		_checkSetContractDenied1( 5, "priceFeed1", address(0x1231236 ) );
		_checkSetContractDenied1( 6, "priceFeed2", address(0x1231237 ) );
		_checkSetContractDenied1( 7, "priceFeed3", address(0x1231238 ) );
		}


    function _checkSetContractDenied2( uint256 ballotID, string memory contractName, address newAddress) internal
    	{
        vm.startPrank(alice);
        staking.stakeSALT( 1000000 ether );

        proposals.proposeSetContractAddress( contractName, newAddress, "description" );
		_voteForAndFinalizeBallot(ballotID, Vote.YES);

		// Above finalization should create a confirmation ballot
		_voteForAndFinalizeBallot(ballotID + 1, Vote.NO);

		assertFalse( _contractForName(contractName) == newAddress, "Contract address should not have changed" );
		vm.stopPrank();
    	}


	// A unit test to test that  with all possible contract options, finalizing a setContract ballot has no effect when the confirm ballot fails
	function testSetContractDenied2() public
		{
		_checkSetContractDenied2( 1, "accessManager", address( new AccessManager(dao) ) );
		_checkSetContractDenied2( 3, "stakingRewardsEmitter", address(0x1231233 ) );
		_checkSetContractDenied2( 5, "liquidityRewardsEmitter", address(0x1231234 ) );
		_checkSetContractDenied2( 7, "priceFeed1", address(0x1231236 ) );
		_checkSetContractDenied2( 9, "priceFeed2", address(0x1231237 ) );
		_checkSetContractDenied2( 11, "priceFeed3", address(0x1231238 ) );
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
        DAO testDAO = new DAO(pools, proposals, exchangeConfig, poolsConfig, stakingConfig, rewardsConfig, stableConfig, daoConfig, priceAggregator, liquidityRewardsEmitter, collateralAndLiquidity );

        assertEq(address(testDAO.pools()), address(pools), "Pools contract address mismatch");
        assertEq(address(testDAO.proposals()), address(proposals), "Proposals contract address mismatch");
        assertEq(address(testDAO.exchangeConfig()), address(exchangeConfig), "ExchangeConfig contract address mismatch");
        assertEq(address(testDAO.poolsConfig()), address(poolsConfig), "PoolsConfig contract address mismatch");
        assertEq(address(testDAO.stakingConfig()), address(stakingConfig), "StakingConfig contract address mismatch");
        assertEq(address(testDAO.rewardsConfig()), address(rewardsConfig), "RewardsConfig contract address mismatch");
        assertEq(address(testDAO.stableConfig()), address(stableConfig), "StableConfig contract address mismatch");
        assertEq(address(testDAO.daoConfig()), address(daoConfig), "DAOConfig contract address mismatch");
        assertEq(address(testDAO.priceAggregator()), address(priceAggregator), "PriceAggregator contract address mismatch");
        assertEq(address(testDAO.liquidityRewardsEmitter()), address(liquidityRewardsEmitter), "LiquidityRewardsEmitter contract address mismatch");
        assertEq(address(testDAO.collateralAndLiquidity()), address(collateralAndLiquidity), "CollateralAndLiquidity contract address mismatch");

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
        dao.withdrawArbitrageProfits(weth);

        uint256 expectedBalance = initialBalance + depositedWETH;

        // Check the result
        uint256 finalBalance = weth.balanceOf(address(exchangeConfig.upkeep()));
        assertEq(finalBalance, expectedBalance, "The final balance is not correct");
    }


	// A unit test to validate that formPOL works correctly and changes balances as expected
	function testFormPOL() public {

		assertEq( collateralAndLiquidity.userShareForPool(address(dao), PoolUtils._poolID(salt, usds)), 0 );

		uint256 saltAmount = 10 ether;
        uint256 usdsAmount = 5 ether;

        uint256 initialDaoSaltBalance = salt.balanceOf(address(dao));
        uint256 initialDaoUsdsBalance = usds.balanceOf(address(dao));

		assertEq( initialDaoSaltBalance, 0 );
		assertEq( initialDaoUsdsBalance, 0 );

		vm.startPrank(DEPLOYER);
        salt.transfer(address(dao), saltAmount);
        usds.transfer(address(dao), usdsAmount);
        vm.stopPrank();

        vm.expectRevert( "DAO.formPOL is only callable from the Upkeep contract" );
        dao.formPOL(salt, usds, saltAmount, usdsAmount);

        vm.prank(address(upkeep));
        dao.formPOL(salt, usds, saltAmount, usdsAmount);

        assertEq(salt.balanceOf(address(dao)), 0, "DAO SALT balance incorrect after formPOL");
        assertEq(usds.balanceOf(address(dao)), 0, "DAO USDS balance incorrect after formPOL");

		bytes32 poolID = PoolUtils._poolID(salt,usds);
		assertTrue( collateralAndLiquidity.userShareForPool(address(dao), poolID) > 0 );
		assertEq( collateralAndLiquidity.userShareForPool(address(dao), poolID), collateralAndLiquidity.totalShares(poolID) );
    }


	// A unit test to validate that unauthorized users cannot call functions restricted to the Upkeep contract
	function testUnauthorizedAccessToUpkeepFunctions() public
    	{
    	vm.startPrank(bob);

    	vm.expectRevert("DAO.withdrawArbitrageProfits is only callable from the Upkeep contract");
    	dao.withdrawArbitrageProfits( weth );

    	vm.expectRevert("DAO.formPOL is only callable from the Upkeep contract");
    	dao.formPOL(salt, usds, 0, 0);

    	vm.expectRevert("DAO.processRewardsFromPOL is only callable from the Upkeep contract");
    	dao.processRewardsFromPOL();

    	vm.expectRevert("DAO.withdrawProtocolOwnedLiquidity is only callable from the Liquidizer contract");
    	dao.withdrawPOL(salt, usds, 1);

    	vm.stopPrank();
    	}



    // A unit test to check if a non-excluded country, countryIsExcluded returns false
    function testCountryIsExcluded() public
        {
        string memory nonExcludedCountry = "Canada";

        bool result = dao.countryIsExcluded(nonExcludedCountry);

        assertEq(result, false, "The country should not be excluded");
        }


    // A unit test to validate that SALT tokens are burned as expected by the processRewardsFromPOL function
    function testProcessRewardsFromPOL() public {

		// Don't proceed with the test if using the live contracts
		if ( keccak256(bytes(vm.envString("COVERAGE" ))) == keccak256(bytes("no" )))
			return;

		vm.warp( block.timestamp - 45 days );

		// DAO needs to form some SALT/USDS and USDS/DAI liquidity to receive some rewards
		vm.prank(address(daoVestingWallet));
		salt.transfer(address(dao), 1000 ether);

		vm.prank(address(collateralAndLiquidity));
		usds.mintTo(address(dao), 2000 ether);

		vm.prank(DEPLOYER);
		dai.transfer(address(dao), 1000 ether);

		assertEq( salt.balanceOf(address(dao)), 1000 ether );
		assertEq( usds.balanceOf(address(dao)), 2000 ether );
		assertEq( dai.balanceOf(address(dao)), 1000 ether );

		// Have the DAO form SALT/USDS and USDS/DAI liquidity
		vm.startPrank(address(upkeep));
		dao.formPOL(salt, usds, 1000 ether, 1000 ether);
		dao.formPOL(usds, dai, 1000 ether, 1000 ether);
		vm.stopPrank();

		// Pass time to allow the liquidityRewardsEmitter to emit rewards
    	vm.warp( block.timestamp + 1 days );

		bytes32[] memory poolIDs = new bytes32[](2);
		poolIDs[0] = PoolUtils._poolID(salt, usds);
		poolIDs[1] = PoolUtils._poolID(usds, dai);

		// Check balances before performUpkeep()
		assertEq( salt.balanceOf( address(teamWallet)), 0 );

   		upkeep.performUpkeep();

		uint256 expectedPOLRewards = 5555555555555555555555 * 2;

		// Team receives 10% of the POL + 16439 from the teamVestingWallet after 6 days
		assertEq( salt.balanceOf(teamWallet), expectedPOLRewards / 10 + 16438387874175545408422 );

		// Burn 50% of the remaining
		assertEq( salt.totalBurned(), expectedPOLRewards * 45 / 100 );

		// DAO balance should be the remaining + 41096 from the daoVestingWallet after 6 days
		// but 15 million SALT were transferred from it for testing so it only emits 16437
		assertEq( salt.balanceOf(address(dao)), expectedPOLRewards * 45 / 100 + 16436744035388127853882 );
   		}


	// A unit test to check that the withdrawPOL function works correctly
	function testWithdrawPOLProperlyWithdrawsLiquidity() public {

		// Have the DAO form some SALT/USDS liquidity for testing
		vm.prank(address(daoVestingWallet));
		salt.transfer(address(dao), 1000 ether);

		vm.prank(address(collateralAndLiquidity));
		usds.mintTo(address(dao), 1000 ether);

		assertEq( salt.balanceOf(address(dao)), 1000 ether );
		assertEq( usds.balanceOf(address(dao)), 1000 ether );

		// Have the DAO form SALT/USDS and USDS/DAI liquidity
		vm.prank(address(upkeep));
		dao.formPOL(salt, usds, 1000 ether, 1000 ether);

		uint256 daoShare = collateralAndLiquidity.userShareForPool(address(dao), PoolUtils._poolID(salt, usds) );

		// Starting liquidator balances
		assertEq( salt.balanceOf(address(liquidizer)), 0);
		assertEq( usds.balanceOf(address(liquidizer)), 0);

        // Assign Liquidizer role to some address (mocking the real Liquidizer contract calling the DAO's withdrawPOL)
		// Check that the DAO doesn't have to obey the liquidity cooldown
        vm.prank(address(liquidizer));
        dao.withdrawPOL(salt, usds, 10);

		// Check that 10% of the share has been removed
		uint256 daoShare2 = collateralAndLiquidity.userShareForPool(address(dao), PoolUtils._poolID(salt, usds) );
		assertEq( daoShare2, daoShare * 90 / 100);

        // Verify tokens are sent to the Liquidizer
		assertEq( salt.balanceOf(address(liquidizer)), 100 ether);
		assertEq( usds.balanceOf(address(liquidizer)), 100 ether);
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
        uint256 initialBallotID = proposals.openBallotsByName("parameter:0");
        assertEq(initialBallotID, 1, "Initial ballot ID should be 1");

        // Warp time to allow for another proposal
        vm.warp(block.timestamp + 1 days);

        // Deployer proposes another parameter change
        vm.startPrank(DEPLOYER);
        proposals.proposeParameterBallot(2, "test");
        vm.stopPrank();

        // Retrieve the second ballot ID
        uint256 secondBallotID = proposals.openBallotsByName("parameter:2");
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
        assertTrue(poolsConfig.tokenHasBeenWhitelisted(test, wbtc, weth), "Token was not whitelisted");

        // Assert the correct amount of bootstrapping rewards have been deducted
        uint256 finalDaoBalance = salt.balanceOf(address(dao));
        assertEq(finalDaoBalance, initialDaoBalance - (bootstrapRewards * 2), "Bootstrapping rewards were not correctly deducted");

        vm.stopPrank();
    }


	// A unit test that verifies the correct calculation and distribution of POL formation when forming POL via the `formPOL` function.
	function testCorrectPOLFormationAndDistribution() public {

        // Forming POL amounts
        uint256 saltAmount = 500 ether;
        uint256 usdsAmount = 500 ether;

        // Transferring tokens to DAO before POL formation
        vm.prank(address(daoVestingWallet));
        salt.transfer(address(dao), saltAmount);

        vm.prank(address(collateralAndLiquidity));
        usds.mintTo(address(dao), usdsAmount);

        // Capture the initial POL state
        bytes32 saltUsdsPoolID = PoolUtils._poolID(salt, usds);
        uint256 initialSaltBalanceDAO = salt.balanceOf(address(dao));
        uint256 initialUsdsBalanceDAO = usds.balanceOf(address(dao));

        // Forming POL
        vm.prank(address(upkeep));
        dao.formPOL(salt, usds, saltAmount, usdsAmount);

        // Capture the post-POL state
        uint256 finalSaltBalanceDAO = salt.balanceOf(address(dao));
        uint256 finalUsdsBalanceDAO = usds.balanceOf(address(dao));
        uint256 finalPoolShareDAO = collateralAndLiquidity.userShareForPool(address(dao), saltUsdsPoolID);

        // Assert POL formation and distribution correctness
        assertEq(finalSaltBalanceDAO, initialSaltBalanceDAO - saltAmount, "Incorrect final SALT balance in DAO");
        assertEq(finalUsdsBalanceDAO, initialUsdsBalanceDAO - usdsAmount, "Incorrect final USDS balance in DAO");
        assertEq(finalPoolShareDAO, 1000 ether, "DAO did not receive pool share tokens");
    }


	// A unit test that ensures DAO can withdraw the correct expected amount of liquidity via `withdrawPOL`, and that the withdrawn amount is correctly routed to the specified beneficiary address.
	function testDAOWithdrawPOL() public {

		// Form 500/500 SALT/USDS POL
		testCorrectPOLFormationAndDistribution();

        // Act
        vm.startPrank(address(liquidizer));
        dao.withdrawPOL(salt, usds, 10);
        vm.stopPrank();

        // Assert
        uint256 finalBalanceA = salt.balanceOf(address(liquidizer));
        uint256 finalBalanceB = usds.balanceOf(address(liquidizer));

        assertEq( finalBalanceA, 50 ether);
        assertEq( finalBalanceB, 50 ether);

		(uint256 reservesA, uint256 reservesB) = pools.getPoolReserves(salt, usds);

        // Beneficiary should have received the correct amounts of tokenA and tokenB
        assertEq(reservesA, 450 ether);
        assertEq(reservesB, 450 ether);
    }

    }

