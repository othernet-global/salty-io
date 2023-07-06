//// SPDX-License-Identifier: BSL 1.1
//pragma solidity ^0.8.12;
//
//import "forge-std/Test.sol";
//import "../Proposals.sol";
//import "../DAO.sol";
//import "../../Deployment.sol";
//
//
//contract TestDAO is DAO, Test, Deployment
//	{
//	IStakingConfig public _stakingConfig = IStakingConfig(address(new StakingConfig(IERC20(address(new Salt())))));
//
//	IAccessManager public accessManager = IAccessManager(new TestAccessManager());
//	IDAOConfig public _daoConfig = new DAOConfig();
//    Staking public _staking = new Staking(_stakingConfig,_exchangeConfig);
//	IPOL_Optimizer public constant polOptimizer = IPOL_Optimizer(address(0x8888));
//
//	IRewardsConfig public _rewardsConfig = new RewardsConfig();
//	IStableConfig public _stableConfig = new StableConfig(IPriceFeed(address(_forcedPriceFeed)));
//	Liquidity public _liquidity = new Liquidity(_stakingConfig,_exchangeConfig);
//	RewardsEmitter public _liquidityRewardsEmitter = new RewardsEmitter(_rewardsConfig, _stakingConfig, _liquidity );
//
//	IUniswapV2Pair public _collateralLP = IUniswapV2Pair( _factory.getPair( address(_wbtc), address(_weth) ));
//
//	// User wallets for testing
//    address public constant alice = address(0x1111);
//    address public constant bob = address(0x2222);
//
//
//	constructor()
//    DAO( _stakingConfig, _daoConfig, _exchangeConfig, _staking, _rewardsConfig, _stableConfig, _liquidity, _liquidityRewardsEmitter, _factory )
//		{
//		vm.startPrank( DEV_WALLET );
//		_exchangeConfig.setAccessManager(accessManager);
//		_exchangeConfig.setOptimizer(polOptimizer);
//		_exchangeConfig.setDAO(this);
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
//	// A unit test to check the constructor for different valid inputs such as _stakingConfig, _daoConfig, _exchangeConfig, _staking, _usds, _rewardsConfig, _stableConfig, _liquidity, _liquidityRewardsEmitter, _factory, _wbtc, and _weth, as well as to verify default values set during initialization like websiteURL and excludedCountries. Ensure that the contract fails to deploy when any of these inputs are the zero address.
//	function testConstructor() public {
//        // Create addresses that will act as zero addresses
//        address zeroAddress = address(0);
//
//        // Check constructor fails when _rewardsConfig is the zero address
//        vm.expectRevert("_rewardsConfig cannot be address(0)");
//        new DAO( _stakingConfig, _daoConfig, _exchangeConfig, _staking, IRewardsConfig(zeroAddress), _stableConfig, _liquidity, _liquidityRewardsEmitter, _factory );
//
//        // Check constructor fails when _stableConfig is the zero address
//        vm.expectRevert("_stableConfig cannot be address(0)");
//        new DAO( _stakingConfig, _daoConfig, _exchangeConfig, _staking, _rewardsConfig, IStableConfig(zeroAddress), _liquidity, _liquidityRewardsEmitter, _factory );
//
//        // Check constructor fails when _liquidity is the zero address
//        vm.expectRevert("_liquidity cannot be address(0)");
//        new DAO( _stakingConfig, _daoConfig, _exchangeConfig, _staking, _rewardsConfig, _stableConfig, ILiquidity(zeroAddress), _liquidityRewardsEmitter, _factory );
//
//        // Check constructor fails when _liquidityRewardsEmitter is the zero address
//        vm.expectRevert("_liquidityRewardsEmitter cannot be address(0)");
//        new DAO( _stakingConfig, _daoConfig, _exchangeConfig, _staking, _rewardsConfig, _stableConfig, _liquidity, IRewardsEmitter(zeroAddress), _factory );
//
//        // Check constructor fails when _factory is the zero address
//        vm.expectRevert("_factory cannot be address(0)");
//        new DAO( _stakingConfig, _daoConfig, _exchangeConfig, _staking, _rewardsConfig, _stableConfig, _liquidity, _liquidityRewardsEmitter, IUniswapV2Factory(zeroAddress) );
//
//        // Initialize contract
//        DAO dao = new DAO( _stakingConfig, _daoConfig, _exchangeConfig, _staking, _rewardsConfig, _stableConfig, _liquidity, _liquidityRewardsEmitter, _factory );
//
//        // Check that websiteURL and excludedCountries are set to default values
//        assertEq( dao.websiteURL(), "" );
//        assertEq( dao.excludedCountries("TestCountry"), false );
//    }
//
//
//	// A unit test to verify the _performUpkeep function with different arrays of pools, confirming the correct staking of LP tokens into the liquidity contract in scenarios of both zero and non-zero LP token balances.
//	function testPerformUpkeep() public {
//        // Mock pools
//        vm.startPrank( DEV_WALLET );
//
//        IUniswapV2Pair[] memory pools = new IUniswapV2Pair[](2);
//        pools[0] = IUniswapV2Pair(address(new TestERC20( 18 )));
//        pools[1] = IUniswapV2Pair(address(new TestERC20( 18 )));
//        vm.stopPrank();
//
//        stakingConfig.whitelist(pools[0]);
//        stakingConfig.whitelist(pools[1]);
//
//        // Contract should start with zero balance for the mock pools
//        assertEq(IERC20(address(pools[0])).balanceOf(address(this)), 0, "Initial pool 0 balance should be zero");
//        assertEq(IERC20(address(pools[1])).balanceOf(address(this)), 0, "Initial pool 1 balance should be zero");
//
//        _performUpkeep();  // No reverts expected with zero balances
//
//        assertEq(_liquidity.userShareInfoForPool(address(this), pools[0]).userShare, 0, "Staked balance in pool 0 should be zero");
//        assertEq(_liquidity.userShareInfoForPool(address(this), pools[1]).userShare, 0, "Staked balance in pool 1 should be zero");
//
//        // Send some of the fake LP to this contract
//        vm.startPrank( DEV_WALLET );
//        IERC20(address(pools[0])).transfer( address(this), 1000 ether );
//        IERC20(address(pools[1])).transfer( address(this), 2000 ether );
//        vm.stopPrank();
//
//        assertEq(pools[0].balanceOf(address(this)), 1000 ether, "Pool 0 balance should be 1000 ether");
//        assertEq(pools[1].balanceOf(address(this)), 2000 ether, "Pool 1 balance should be 2000 ether");
//
//        _performUpkeep();  // No reverts expected with non-zero balances
//
//        assertEq(_liquidity.userShareInfoForPool(address(this), pools[0]).userShare, 1000 ether, "Staked balance in pool 0 should be 1000 ether");
//        assertEq(_liquidity.userShareInfoForPool(address(this), pools[1]).userShare, 2000 ether, "Staked balance in pool 1 should be 2000 ether");
//    }
//
//
//
//	// A unit test to assess the _finalizeParameterBallot, _finalizeApprovalBallot, and finalizeBallot functions
//	function testFinalizeBallots() public {
//        // Setup: create various ballots and votes
//        string memory paramBallotName = "bootstrappingRewards";
//        string memory approvalBallotName = "TestApproval";
//
//        vm.startPrank(alice);
//        this.proposeParameterBallot(paramBallotName);
//        uint256 paramBallotId = openBallotsByName[paramBallotName];
//        assertEq(ballotForID(paramBallotId).ballotIsLive, true, "Parameter Ballot not correctly created");
//        _staking.stakeSALT( 5000000 ether );
//        this.castVote(paramBallotId, Vote.INCREASE);
//        vm.stopPrank();
//
//		this.proposeCountryInclusion( approvalBallotName, "USA" );
//        uint256 approvalBallotId = openBallotsByName[approvalBallotName];
//        assertEq(ballotForID(approvalBallotId).ballotIsLive, true, "Approval Ballot not correctly created");
//        this.castVote(approvalBallotId, Vote.YES);
//
//        // Increase block time to finalize ballots
//        vm.warp(block.timestamp + 10 days + 1);
//
//        // Test Parameter Ballot finalization
//        this.finalizeBallot(paramBallotId);
//        assertEq(ballotForID(paramBallotId).ballotIsLive, false, "Parameter Ballot not correctly finalized");
//
//        // Test Approval Ballot finalization
//        this.finalizeBallot(approvalBallotId);
//        assertEq(ballotForID(approvalBallotId).ballotIsLive, false, "Approval Ballot not correctly finalized");
//    }
//
//
//	// A unit test to examine the _executeSetContract function with different contract types like priceFeed, liquidator, AAA, optimizer, accessManager, and to independently test setLiquidator and setAAA functions, ensuring the appropriate contracts are set correctly in the configuration.
//	function testSetContractFunctions() public {
//        // Instantiate mock contracts
//        ILiquidator mockLiquidator = ILiquidator(address(0x12345));
//        IAAA mockAAA = IAAA(address(0x123456));
//        IPOL_Optimizer mockOptimizer = IPOL_Optimizer(address(0x123457));
//        IPriceFeed mockPriceFeed = IPriceFeed(address(0x123458));
//        IAccessManager mockAccessManager = IAccessManager(address(0x123459));
//
//		// Create the ballots
//        vm.startPrank(DEV_WALLET);
//        this.proposeSetContractAddress("setContract:liquidator", address(mockLiquidator));
//        this.proposeSetContractAddress("setContract:AAA", address(mockAAA));
//		this.proposeSetContractAddress("setContract:optimizer", address(mockOptimizer));
//		this.proposeSetContractAddress("setContract:priceFeed", address(mockPriceFeed));
//		this.proposeSetContractAddress("setContract:accessManager", address(mockAccessManager));
//
//        // Test _executeSetContract function
//        _executeSetContract(ballots[openBallotsByName["setContract:liquidator"]]);
//        assertEq(address(_exchangeConfig.liquidator()), address(mockLiquidator));
//
//        _executeSetContract(ballots[openBallotsByName["setContract:AAA"]]);
//        assertEq(address(_exchangeConfig.aaa()), address(mockAAA));
//
//        _executeSetContract(ballots[openBallotsByName["setContract:optimizer"]]);
//        assertEq(address(_exchangeConfig.optimizer()), address(mockOptimizer));
//
//        _executeSetContract(ballots[openBallotsByName["setContract:accessManager"]]);
//        assertEq(address(_exchangeConfig.accessManager()), address(mockAccessManager));
//		vm.stopPrank();
//
//        _executeSetContract(ballots[openBallotsByName["setContract:priceFeed"]]);
//        assertEq(address(_stableConfig.priceFeed()), address(mockPriceFeed));
//
//        // Test setLiquidator function
//        ILiquidator anotherMockLiquidator = ILiquidator(address(0x123123123));
//        vm.startPrank(DEV_WALLET);
//        exchangeConfig.setLiquidator(anotherMockLiquidator);
//        assertEq(address(_exchangeConfig.liquidator()), address(anotherMockLiquidator));
//        vm.stopPrank();
//
//        // Test setAAA function
//        IAAA anotherMockAAA = IAAA(address(0x234234234));
//        vm.startPrank(DEV_WALLET);
//        exchangeConfig.setAAA(anotherMockAAA);
//        assertEq(address(_exchangeConfig.aaa()), address(anotherMockAAA));
//        vm.stopPrank();
//    }
//
//
////	// A unit test to validate the functionality of _executeSetWebsiteURL and _executeApproval function by testing various ballotType values such as UNWHITELIST_TOKEN, SEND_SALT, CALL_CONTRACT, INCLUDE_COUNTRY, EXCLUDE_COUNTRY, SET_CONTRACT, SET_WEBSITE_URL, CONFIRM_SET_CONTRACT, and CONFIRM_SET_WEBSITE_URL. Ensure that the websiteURL is set to the correct URL and the appropriate actions are executed based on the ballotType.
////	function testExecuteSetWebsiteURLAndExecuteApproval() public {
////
////		string memory website0 = this.websiteURL();
////
////		vm.startPrank( DEV_WALLET );
////
////        string memory website = "https://example.com";
////        string memory ballotName = "setWebsite";
////        this.proposeWebsiteUpdate( ballotName, website);
////
////		uint256 ballotID = openBallotsByName[ ballotName ];
////        vm.warp(block.timestamp + 1 weeks);
////        vm.stopPrank();
////
////        vm.startPrank(alice);
////        _staking.stakeSALT( 5000000 ether );
////        this.castVote(ballotID, Vote.YES);
////        vm.stopPrank();
////
////		// This should create the "setWebsite_confirm" ballot
////        this.finalizeBallot(ballotID);
////		uint256 ballotID2 = openBallotsByName[ "setWebsite_confirm" ];
////		assertTrue( ballotID2 != 0, "The confirm ballot doesn't exist" );
////
////        assertEq(this.websiteURL(), website0, "Website should not have changed");
////
////        vm.startPrank(alice);
////        this.castVote(ballotID2, Vote.YES);
////        vm.stopPrank();
////
////        vm.warp(block.timestamp + 1 weeks);
////        this.finalizeBallot(ballotID2);
////
////        assertEq(this.websiteURL(), website, "Website should have changed");
////
////
////        // === UNWHITELIST
//////        _stakingConfig.whitelist( _factory.createPair(address(_wbtc)
////        ballotName = "approveUnwhitelistToken";
////		vm.startPrank( DEV_WALLET );
////		this.proposeTokenUnwhitelisting( "testUnwhitelist", address(_wbtc), "url", "description" );
////		ballotID = openBallotsByName[ "testUnwhitelist" ];
////        vm.warp(block.timestamp + 1 weeks);
////        vm.stopPrank();
////
////        vm.startPrank(alice);
////        this.castVote(ballotID, Vote.YES);
////        vm.stopPrank();
////
////		// This should create the "setWebsite_confirm" ballot
////        this.finalizeBallot(ballotID);
////
//////        assertEq(_stakingConfig.isValidPool(_collateralLP), website0, "Website should not have changed");
////
//////        vm.startPrank(alice);
//////        this.vote(ballotID, Proposals.Vote.YES);
//////        vm.stopPrank();
//////
//////        vm.warp(block.timestamp + 2 weeks);
//////        this.finalizeBallot(ballotID);
//////
//////        ballotName = "approveSendSalt";
//////        ballotID = this.createProposal(ballotName, Proposals.BallotType.SEND_SALT, alice, 1 ether, "", "", 0);
//////        vm.warp(block.timestamp + 1 weeks);
//////
//////        vm.startPrank(alice);
//////        this.vote(ballotID, Proposals.Vote.YES);
//////        vm.stopPrank();
//////
//////        vm.warp(block.timestamp + 2 weeks);
//////        this.finalizeBallot(ballotID);
//////
//////        // Continue in similar way for each BallotType
////    }
////
////
//
//	// A unit test to evaluate the _finalizeTokenWhitelisting function and the sufficientBootstrappingRewardsExistForWhitelisting function by assessing scenarios where the "yes" votes exceed the "no" votes and the contract has enough bootstrapping rewards, as well as cases where the contract lacks sufficient bootstrapping rewards or the "no" votes surpass the "yes" votes. This test also includes testing different SALT balances, ensuring the correct indication of sufficient bootstrapping rewards for whitelisting and the appropriate actions in each scenario.
//	// A unit test to confirm the functionality of the countryIsExcluded function with different country values, including both excluded and non-excluded countries, ensuring correct indication of a country's exclusion status.
//	// A unit test to verify the _executeParameterIncrease and _executeParameterDecrease functions, ensuring they function as expected with different parameters.
//	// A unit test to check the _markBallotAsFinalized function with different ballot ids, ensuring it functions correctly.
//	// A unit test to verify the ability to create and manipulate ballots, with special attention given to the creation of different ballot types and updating vote counts.
//	// A unit test to examine the contract with different users to simulate a real-world situation, including testing voting from multiple addresses and verifying accurate summing of vote counts.
//	// A unit test to attempt various attacks on the contract, including testing if a user can vote more than once on a ballot, vote without sufficient balance, or manipulate the result of a vote, assessing the contract's security robustness.
//    }
//
