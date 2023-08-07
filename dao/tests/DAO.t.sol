// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.21;

import "forge-std/Test.sol";
import "../Proposals.sol";
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
import "../DAO.sol";
import "./TestCallReceiver.sol";
import "../../price_feed/PriceAggregator.sol";
import "../../AccessManager.sol";


contract TestDAO is Test, Deployment
	{
	// User wallets for testing
    address public constant alice = address(0x1111);
    address public constant bob = address(0x2222);


	constructor()
		{
		// If $COVERAGE=yes, create an instance of the contract so that coverage testing can work
		// Otherwise, what is tested is the actual deployed contract on the blockchain (as specified in Deployment.sol)
		if ( keccak256(bytes(vm.envString("COVERAGE" ))) == keccak256(bytes("yes" )))
			{
			vm.startPrank(DEPLOYER);

			poolsConfig = new PoolsConfig();

			priceAggregator = new PriceAggregator();
			priceAggregator.setInitialFeeds( IPriceFeed(address(forcedPriceFeed)), IPriceFeed(address(forcedPriceFeed)), IPriceFeed(address(forcedPriceFeed)) );

			// Because USDS already set the Collateral on deployment and it can only be done once, we have to recreate USDS as well
			// That cascades into recreating multiple other contracts as well.
			usds = new USDS( poolsConfig, wbtc, weth );

			exchangeConfig = new ExchangeConfig(salt, wbtc, weth, usdc, usds );
			pools = new Pools( exchangeConfig, poolsConfig );

			staking = new Staking( exchangeConfig, poolsConfig, stakingConfig );
			liquidity = new Liquidity( pools, exchangeConfig, poolsConfig, stakingConfig );
			collateral = new Collateral(pools, exchangeConfig, poolsConfig, stakingConfig, stableConfig, priceAggregator);

			stakingRewardsEmitter = new RewardsEmitter( staking, exchangeConfig, poolsConfig, stakingConfig, rewardsConfig );
			liquidityRewardsEmitter = new RewardsEmitter( liquidity, exchangeConfig, poolsConfig, stakingConfig, rewardsConfig );

			emissions = new Emissions( exchangeConfig, rewardsConfig );

			proposals = new Proposals( staking, exchangeConfig, poolsConfig, stakingConfig, daoConfig );

			address oldDAO = address(dao);
			dao = new DAO( pools, proposals, exchangeConfig, poolsConfig, stakingConfig, rewardsConfig, stableConfig, daoConfig, priceAggregator, liquidity, liquidityRewardsEmitter );

			accessManager = new AccessManager(dao);

			exchangeConfig.setDAO( dao );
			exchangeConfig.setAccessManager( accessManager );
			usds.setPools( pools );
			usds.setCollateral( collateral );
			usds.setDAO( dao );

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
			}

		// Mint some USDS to the DEPLOYER and alice
		vm.startPrank( address(collateral) );
		usds.mintTo( DEPLOYER, 2000000 ether );
		usds.mintTo( alice, 1000000 ether );
		vm.stopPrank();

		vm.startPrank( DEPLOYER );
		salt.transfer( alice, 10000000 ether );
		salt.transfer( DEPLOYER, 90000000 ether );
		vm.stopPrank();
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
		else if ( parameter == Parameters.ParameterTypes.daoPercentShareArbitrage )
			return poolsConfig.daoPercentShareArbitrage();

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

		else if ( parameter == Parameters.ParameterTypes.bootstrappingRewards )
			return daoConfig.bootstrappingRewards();
		else if ( parameter == Parameters.ParameterTypes.percentPolRewardsBurned )
			return daoConfig.percentPolRewardsBurned();
		else if ( parameter == Parameters.ParameterTypes.baseBallotQuorumPercentTimes1000 )
			return daoConfig.baseBallotQuorumPercentTimes1000();
		else if ( parameter == Parameters.ParameterTypes.ballotDuration )
			return daoConfig.ballotDuration();
		else if ( parameter == Parameters.ParameterTypes.baseProposalCost )
			return daoConfig.baseProposalCost();
		else if ( parameter == Parameters.ParameterTypes.maxPendingTokensForWhitelisting )
			return daoConfig.maxPendingTokensForWhitelisting();
		else if ( parameter == Parameters.ParameterTypes.daoArbitragePercent )
			return daoConfig.daoArbitragePercent();
		else if ( parameter == Parameters.ParameterTypes.upkeepRewardPercent )
			return daoConfig.upkeepRewardPercent();

		else if ( parameter == Parameters.ParameterTypes.maximumPriceFeedPercentDifferenceTimes1000 )
			return priceAggregator.maximumPriceFeedPercentDifferenceTimes1000();
		else if ( parameter == Parameters.ParameterTypes.setPriceFeedCooldown )
			return priceAggregator.setPriceFeedCooldown();

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

		if ( parameterNum != 9 )
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

		uint256 ballotID = parameterNum + 1;
		uint256 originalValue = _parameterValue( Parameters.ParameterTypes( parameterNum ) );

        proposals.proposeParameterBallot(parameterNum, "description" );
        assertEq(proposals.ballotForID(ballotID).ballotIsLive, true, "Parameter Ballot not correctly created");

        proposals.castVote(ballotID, Vote.DECREASE);

        // Increase block time to finalize the ballot
        vm.warp(block.timestamp + 11 days );

        // Test Parameter Ballot finalization
        dao.finalizeBallot(ballotID);
        assertEq(proposals.ballotForID(ballotID).ballotIsLive, false, "Parameter Ballot not correctly finalized");

		uint256 newValue = _parameterValue( Parameters.ParameterTypes( parameterNum ) );

		if ( parameterNum != 2 )
		if ( parameterNum != 9 )
		if ( parameterNum != 13 )
			assert( newValue < originalValue );
    }


	// A unit test to test all parameters and that a successful INCREASE vote has the expected effects
    function testFinalizeIncreaseParameterBallots() public
    	{
        vm.startPrank(alice);
        staking.stakeSALT( 5000000 ether );

    	for( uint256 i = 0; i < 23; i++ )
	 		_checkFinalizeIncreaseParameterBallot( i );
    	}


	// A unit test to test all parameters and that a successful DECREASE vote has the expected effects
    function testFinalizeDecreaseParameterBallots() public
    	{
        vm.startPrank(alice);
        staking.stakeSALT( 5000000 ether );

    	for( uint256 i = 0; i < 23; i++ )
	 		_checkFinalizeDecreaseParameterBallot( i );
    	}


	// A unit test to test all parameters and that a successful NO_CHANGE vote has the expected effects
    function testFinalizeNoChangeParameterBallots() public
    	{
        vm.startPrank(alice);
        staking.stakeSALT( 5000000 ether );

    	for( uint256 i = 0; i < 23; i++ )
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

       	IERC20 token = new TestERC20(18);

        proposals.proposeTokenWhitelisting( token, "", "" );

		uint256 ballotID = 1;
        proposals.castVote(ballotID, Vote.YES);

        // Increase block time to finalize the ballot
        vm.warp(block.timestamp + 11 days );

        // Test Parameter Ballot finalization
		salt.transfer( address(dao), 199999 ether );

		vm.expectRevert( "Whitelisting is not currently possible due to insufficient bootstrapping rewards" );
        dao.finalizeBallot(ballotID);

		salt.transfer( address(dao), 5 ether );
        dao.finalizeBallot(ballotID);

		// Check for the effects of the vote
		assertTrue( poolsConfig.tokenHasBeenWhitelisted(token, wbtc, weth), "Token not whitelisted" );
    	}


	// A unit test to test that finalizing a denied whitelist token ballot has the desired effect
    function testWhitelistTokenDenied() public
    	{
        vm.startPrank(alice);
        staking.stakeSALT( 1000000 ether );

       	IERC20 token = new TestERC20(18);
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

       	IERC20 token = new TestERC20(18);
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

       	IERC20 token = new TestERC20(18);
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

		assertTrue( dao.countryIsExcluded( "US" ), "US should be excluded" );
    	}


	// A unit test to test that finalizing a denied exclude country ballot has the desired effect
    function testExcludeCountryDenied() public
    	{
        vm.startPrank(alice);
        staking.stakeSALT( 1000000 ether );

        proposals.proposeCountryExclusion( "US", "description" );
		_voteForAndFinalizeBallot(1, Vote.NO);

		assertFalse( dao.countryIsExcluded( "US" ), "US shouldn't be excluded" );
    	}


	function _contractForName( string memory contractName ) internal view returns (address)
		{
		bytes32 nameHash = keccak256(bytes(contractName));

		if ( nameHash == keccak256(bytes("arbitrageSearch" )))
			return address(poolsConfig.arbitrageSearch());
		if ( nameHash == keccak256(bytes("counterswap" )))
			return address(poolsConfig.counterswap());
		if ( nameHash == keccak256(bytes("accessManager" )))
			return address(exchangeConfig.accessManager());
		if ( nameHash == keccak256(bytes("stakingRewardsEmitter" )))
			return address(exchangeConfig.stakingRewardsEmitter());
		if ( nameHash == keccak256(bytes("liquidityRewardsEmitter" )))
			return address(exchangeConfig.liquidityRewardsEmitter());
		if ( nameHash == keccak256(bytes("priceFeed1" )))
			return address(priceAggregator.priceFeed1());
		if ( nameHash == keccak256(bytes("priceFeed2" )))
			return address(priceAggregator.priceFeed2());
		if ( nameHash == keccak256(bytes("priceFeed3" )))
			return address(priceAggregator.priceFeed3());
		if ( nameHash == keccak256(bytes("saltRewards" )))
			return address(exchangeConfig.saltRewards());

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
		_checkSetContractApproved( 1, "arbitrageSearch", address(0x1231230 ) );
		_checkSetContractApproved( 3, "accessManager", address( new AccessManager(dao) ) );
		_checkSetContractApproved( 5, "stakingRewardsEmitter", address(0x1231233 ) );
		_checkSetContractApproved( 7, "liquidityRewardsEmitter", address(0x1231234 ) );
		_checkSetContractApproved( 9, "priceFeed1", address(0x1231236 ) );
		vm.warp(block.timestamp + 60 days);
		_checkSetContractApproved( 11, "priceFeed2", address(0x1231237 ) );
		vm.warp(block.timestamp + 60 days);
		_checkSetContractApproved( 13, "priceFeed3", address(0x1231238 ) );
		_checkSetContractApproved( 15, "saltRewards", address(0x1231239 ) );
		_checkSetContractApproved( 17, "counterswap", address(0x1231249 ) );
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
		_checkSetContractDenied1( 1, "arbitrageSearch", address(0x1231230 ) );
		_checkSetContractDenied1( 2, "priceFeed", address(0x1231231 ) );
		_checkSetContractDenied1( 3, "accessManager", address( new AccessManager(dao) ) );
		_checkSetContractDenied1( 4, "stakingRewardsEmitter", address(0x1231233 ) );
		_checkSetContractDenied1( 5, "liquidityRewardsEmitter", address(0x1231234 ) );
		_checkSetContractDenied1( 6, "priceFeed1", address(0x1231236 ) );
		_checkSetContractDenied1( 7, "priceFeed2", address(0x1231237 ) );
		_checkSetContractDenied1( 8, "priceFeed3", address(0x1231238 ) );
		_checkSetContractDenied1( 9, "saltRewards", address(0x1231239 ) );
		_checkSetContractDenied1( 10, "counterswap", address(0x1231249 ) );
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
		_checkSetContractDenied2( 1, "arbitrageSearch", address(0x1231230 ) );
		_checkSetContractDenied2( 3, "accessManager", address( new AccessManager(dao) ) );
		_checkSetContractDenied2( 5, "stakingRewardsEmitter", address(0x1231233 ) );
		_checkSetContractDenied2( 7, "liquidityRewardsEmitter", address(0x1231234 ) );
		_checkSetContractDenied2( 9, "priceFeed1", address(0x1231236 ) );
		_checkSetContractDenied2( 11, "priceFeed2", address(0x1231237 ) );
		_checkSetContractDenied2( 13, "priceFeed3", address(0x1231238 ) );
		_checkSetContractDenied2( 15, "saltRewards", address(0x1231239 ) );
		_checkSetContractDenied2( 17, "counterswap", address(0x1231249 ) );
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
        DAO testDAO = new DAO(pools, proposals, exchangeConfig, poolsConfig, stakingConfig, rewardsConfig, stableConfig, daoConfig, priceAggregator, liquidity, liquidityRewardsEmitter);

        assertEq(address(testDAO.pools()), address(pools), "Pools contract address mismatch");
        assertEq(address(testDAO.proposals()), address(proposals), "Proposals contract address mismatch");
        assertEq(address(testDAO.exchangeConfig()), address(exchangeConfig), "ExchangeConfig contract address mismatch");
        assertEq(address(testDAO.poolsConfig()), address(poolsConfig), "PoolsConfig contract address mismatch");
        assertEq(address(testDAO.stakingConfig()), address(stakingConfig), "StakingConfig contract address mismatch");
        assertEq(address(testDAO.rewardsConfig()), address(rewardsConfig), "RewardsConfig contract address mismatch");
        assertEq(address(testDAO.stableConfig()), address(stableConfig), "StableConfig contract address mismatch");
        assertEq(address(testDAO.daoConfig()), address(daoConfig), "DAOConfig contract address mismatch");
        assertEq(address(testDAO.priceAggregator()), address(priceAggregator), "PriceAggregator contract address mismatch");
        assertEq(address(testDAO.liquidity()), address(liquidity), "Liquidity contract address mismatch");
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


	// A unit test to test performUpkeep works correctly
    }

