// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "forge-std/Test.sol";
import "../Pools.sol";
import "../../dev/Deployment.sol";
import "../PoolStats.sol";
import "../PoolUtils.sol";
import "../../root_tests/TestERC20.sol";


contract TestPoolStats is Test, PoolStats
	{
	Deployment public deployment = new Deployment();

	IERC20 public wbtc = deployment.wbtc();

	IERC20 public tokenA = new TestERC20("TEST", 6);
	IERC20 public tokenB = new TestERC20("TEST", 18);
	IERC20 public tokenC = new TestERC20("TEST", 18);

	bytes32 public poolID;
	bytes32 public poolID2;

	uint256 numInitialTokens;


	constructor()
	PoolStats(deployment.exchangeConfig(), deployment.poolsConfig())
		{
		// Different decimals
		poolID = PoolUtils._poolID( tokenA, tokenB );

		// Same decimals
		poolID2 = PoolUtils._poolID( tokenB, tokenC );

		numInitialTokens = deployment.poolsConfig().numberOfWhitelistedPools();
		}


    // A unit test for `_updateProfitsFromArbitrage` that verifies the function ignores cases without arbitrage profit
    function testUpdateProfitsFromArbitrage_IgnoreNoProfitCase() public
    	{
        IERC20 arbToken2 = tokenA;
        IERC20 arbToken3 = tokenB;
        uint256 initialProfit;
        uint256 arbitrageProfit = 0;  // no profit

        poolID = PoolUtils._poolID( arbToken2, arbToken3 );
        initialProfit = _arbitrageProfits[poolID];

        _updateProfitsFromArbitrage(arbToken2, arbToken3, arbitrageProfit);

        assertEq(_arbitrageProfits[poolID], initialProfit, "Profit should not increase when arbitrage profit is zero");
    	}


	// A unit test for `_updateProfitsFromArbitrage` that verifies the function updates profits for whitelisted pairs correctly
	function testUpdateProfitsFromArbitrage_WhitelistedPair() public {
        IERC20 arbToken2 = tokenA;
        IERC20 arbToken3 = tokenB;
        uint256 arbitrageProfit = 1 ether;

        poolID = PoolUtils._poolID( arbToken2, arbToken3 );

        uint256 initialProfit = _arbitrageProfits[poolID];

        _updateProfitsFromArbitrage(arbToken2, arbToken3, arbitrageProfit);

        assertEq(_arbitrageProfits[poolID], initialProfit + arbitrageProfit, "Profit didn't increase as expected for whitelisted pair");
    }



	// A unit test for `clearProfitsForPools` that verifies an exception is thrown when an unauthorized account tries to call it
	function testClearProfitsForPoolsNotAuthorized() public {
        bytes32[] memory poolIDs = new bytes32[](1);
        poolIDs[0] = PoolUtils._poolID(tokenA, tokenB);

        vm.expectRevert("PoolStats.clearProfitsForPools is only callable from the Upkeep contract");
        this.clearProfitsForPools();
    }


	// A unit test for `profitsForPools` that verifies it returns zero for pools without profits
	function testPoolWithoutProfits() public
	{
		bytes32 _poolID2 = PoolUtils._poolID( tokenA, tokenB );
		// Checking initial profit of pool to be zero
		assertEq(_arbitrageProfits[_poolID2], 0, "Initial profit should be zero");
	}


	// A unit test for `profitsForPools` that verifies it returns profits correctly for given pool IDs
	function testProfitsForPoolsSimple() public {

		IERC20 weth = exchangeConfig.weth();

		vm.startPrank(address(deployment.dao()));
		deployment.poolsConfig().whitelistPool( tokenA,weth ); // whitelisted index #9
		deployment.poolsConfig().whitelistPool( tokenB,weth ); // whitelisted index #10
		deployment.poolsConfig().whitelistPool( tokenA,tokenB ); // whitelisted index #11
		vm.stopPrank();

		this.updateArbitrageIndicies();

		_updateProfitsFromArbitrage(tokenA, tokenB, 10 ether);

		vm.prank(address(deployment.upkeep()));
		uint256[] memory profits = this.profitsForWhitelistedPools();

		assertEq(profits[numInitialTokens+0], uint256(10 ether) / 3, "Incorrect profit for pool 0a");
		assertEq(profits[numInitialTokens+1], uint256(10 ether) / 3, "Incorrect profit for pool 0b");
		assertEq(profits[numInitialTokens+2], uint256(10 ether) / 3, "Incorrect profit for pool 0c");

		// Clear the profits
		vm.prank(address(deployment.upkeep()));
		this.clearProfitsForPools();

		vm.prank(address(deployment.upkeep()));
		profits = this.profitsForWhitelistedPools();
		assertEq(profits[numInitialTokens+0], 0, "Profit for pool 0 not cleared");
		assertEq(profits[numInitialTokens+1], 0, "Profit for pool 0 not cleared");
		assertEq(profits[numInitialTokens+2], 0, "Profit for pool 0 not cleared");
	}



	// A unit test for `profitsForPools` that verifies it returns profits correctly for given pool IDs
	function testProfitsForPoolsDouble() public {

		IERC20 weth = exchangeConfig.weth();

		vm.startPrank(address(deployment.dao()));
		deployment.poolsConfig().whitelistPool( tokenA,weth ); // whitelisted index #9
		deployment.poolsConfig().whitelistPool( tokenA,tokenB ); // whitelisted index #10
		deployment.poolsConfig().whitelistPool( tokenB,weth ); // whitelisted index #11
		deployment.poolsConfig().whitelistPool( tokenB,tokenC ); // whitelisted index #12
		deployment.poolsConfig().whitelistPool( tokenC,weth ); // whitelisted index #13
		vm.stopPrank();

		this.updateArbitrageIndicies();

		_updateProfitsFromArbitrage(tokenA, tokenB, 10 ether);
		_updateProfitsFromArbitrage(tokenB, tokenC, 5 ether);

		vm.prank(address(deployment.upkeep()));
		uint256[] memory profits = this.profitsForWhitelistedPools();

		assertEq(profits[numInitialTokens+0], uint256(10 ether) / 3, "Incorrect profit for poolIDs[0]");
		assertEq(profits[numInitialTokens+1], uint256(10 ether) / 3, "Incorrect profit for poolIDs[1]");
		assertEq(profits[numInitialTokens+2], uint256(10 ether) / 3 + uint256(5 ether) / 3, "Incorrect profit for poolIDs[2]");
		assertEq(profits[numInitialTokens+3], uint256(5 ether) / 3, "Incorrect profit for poolIDs[3]");
		assertEq(profits[numInitialTokens+4], uint256(5 ether) / 3, "Incorrect profit for poolIDs[4]");
//
//		// Clear the profits
//		vm.prank(address(deployment.upkeep()));
//		this.clearProfitsForPools(whitelistedPoolIDs);
//
//		vm.prank(address(deployment.upkeep()));
//		(profits,) = this.profitsForWhitelistedPools();
//		assertEq(profits[9], 0, "Profit for pool 0 not cleared");
//		assertEq(profits[10], 0, "Profit for pool 0 not cleared");
//		assertEq(profits[11], 0, "Profit for pool 0 not cleared");
//		assertEq(profits[12], 0, "Profit for pool 0 not cleared");
//		assertEq(profits[13], 0, "Profit for pool 0 not cleared");
	}



	// A unit test for updateArbitrageIndicies
	function testUpdateArbitrageIndicies() public
		{
		IERC20 weth = exchangeConfig.weth();

		vm.startPrank(address(deployment.dao()));
		deployment.poolsConfig().whitelistPool( tokenA,weth ); // whitelisted index #9
		deployment.poolsConfig().whitelistPool( tokenA,tokenB ); // whitelisted index #10
		deployment.poolsConfig().whitelistPool( tokenB,weth ); // whitelisted index #11
		vm.stopPrank();

		this.updateArbitrageIndicies();

		bytes32[] memory whitelistedPoolIDs = deployment.poolsConfig().whitelistedPools();

		uint256 index1 = _poolIndex(tokenA, weth, whitelistedPoolIDs );
		uint256 index2 = _poolIndex(tokenA, tokenB, whitelistedPoolIDs );
		uint256 index3 = _poolIndex(tokenB, weth, whitelistedPoolIDs );

		assertEq( index1, numInitialTokens + 0 );
		assertEq( index2, numInitialTokens + 1 );
		assertEq( index3, numInitialTokens + 2 );

		ArbitrageIndicies memory indicies = _arbitrageIndicies[poolID];
		assertEq( indicies.index1, numInitialTokens + 0 );
		assertEq( indicies.index2, numInitialTokens + 1 );
		assertEq( indicies.index3, numInitialTokens + 2 );
		}

	// A unit test for `profitsForPools` that verifies it returns profits correctly for given pool IDs after some pairs have been unwhitelisted (which changes the whitelistedPools order)
	function testProfitsForPoolsAfterUnwhitelist() public {

		IERC20 weth = exchangeConfig.weth();

		vm.startPrank(address(deployment.dao()));
		deployment.poolsConfig().whitelistPool( tokenA,weth ); // whitelisted index #9
		deployment.poolsConfig().whitelistPool( tokenA,tokenB ); // whitelisted index #10
		deployment.poolsConfig().whitelistPool( tokenB,weth ); // whitelisted index #11
		deployment.poolsConfig().whitelistPool( tokenC,weth ); // whitelisted index #12
		deployment.poolsConfig().whitelistPool( tokenB,tokenC ); // whitelisted index #13 (will become #9 after unwhitelisting tokenA/salt)
		vm.stopPrank();

		this.updateArbitrageIndicies();

		// This will cause tokenB/tokenC to have index #9
		vm.startPrank(address(deployment.dao()));
		deployment.poolsConfig().unwhitelistPool( tokenA,weth ); // now whitelisted index #9
		vm.stopPrank();

		this.updateArbitrageIndicies();

		_updateProfitsFromArbitrage(tokenB, tokenC, 10 ether);

		vm.prank(address(deployment.upkeep()));
		uint256[] memory profits = this.profitsForWhitelistedPools();

		assertEq(profits[numInitialTokens+1], 0, "Incorrect profit for poolIDs[1]");
		assertEq(profits[numInitialTokens+2], uint256(10 ether) / 3, "Incorrect profit for poolIDs[3]");
		assertEq(profits[numInitialTokens+3], uint256(10 ether) / 3, "Incorrect profit for poolIDs[4]");
		assertEq(profits[numInitialTokens+0], uint256(10 ether) / 3, "Incorrect profit for poolIDs[0]");
	}



	function updateProfitsFromArbitrage( IERC20 arbToken2, IERC20 arbToken3, uint256 arbitrageProfit ) public
		{
		_updateProfitsFromArbitrage(arbToken2, arbToken3, arbitrageProfit);
		}


	// A unit test that ensures `_calculateArbitrageProfits` correctly calculates and distributes arbitrage profits to the correct pools
	function testCalculateArbitrageProfits() public {
		IERC20 weth = deployment.weth();

        // Given three pools contributing to arbitrage profit
        vm.startPrank(address(deployment.dao()));
        deployment.poolsConfig().whitelistPool( tokenA, weth);
        deployment.poolsConfig().whitelistPool( tokenB, weth);
        deployment.poolsConfig().whitelistPool( tokenA, tokenB);
        vm.stopPrank();

        // Update arbitrage indicies
       	this.updateArbitrageIndicies();

        // Assume an arbitrage profit on tokenA->tokenB pool
        uint256 arbitrageProfit = 30 ether; // Total arbitrage profit for simplification
        this.updateProfitsFromArbitrage(tokenA, tokenB, arbitrageProfit);

        uint256[] memory profits = this.profitsForWhitelistedPools();

        // Expect profits to be distributed equally to contributing pools
        uint256 expectedProfitPerPool = arbitrageProfit / 3;
        assertEq(profits[numInitialTokens+0], expectedProfitPerPool, "Incorrect arbitrage profit distribution for WETH-tokenA pool");
        assertEq(profits[numInitialTokens+1], expectedProfitPerPool, "Incorrect arbitrage profit distribution for WETH-tokenB pool");
        assertEq(profits[numInitialTokens+2], expectedProfitPerPool, "Incorrect arbitrage profit distribution for tokenA-tokenB pool");
    }


    // A unit test that confirms the `profitsForPools` function correctly computes the share of profits per pool
	function testProfitsForPoolsCorrectShare() public {
        // Assume three pools (tokenA/tokenB, tokenB/tokenC, tokenC/tokenA) with different contributions to arbitrage profits:
        // tokenA/tokenB contributes with 20 ether
        // tokenB/tokenC contributes with 30 ether
        // tokenC/tokenA contributes with 50 ether

        IERC20 tokenD = new TestERC20("TEST", 18); // new token for creating new pool id

        // Whitelist pools
        vm.startPrank(address(deployment.dao()));
        deployment.poolsConfig().whitelistPool( tokenA, tokenB);
        deployment.poolsConfig().whitelistPool( tokenB, tokenC);
        deployment.poolsConfig().whitelistPool( tokenC, tokenD);
        vm.stopPrank();

        // Update arbitrage indicies
        this.updateArbitrageIndicies();

        // Set arbitrage profits
        this.updateProfitsFromArbitrage(tokenA, tokenB, 20 ether);
        this.updateProfitsFromArbitrage(tokenB, tokenC, 30 ether);
        this.updateProfitsFromArbitrage(tokenC, tokenD, 50 ether);

        // Get profits for whitelisted pools
        uint256[] memory profits = this.profitsForWhitelistedPools();

        // Fetch the pool IDs
        bytes32 poolIDAB = PoolUtils._poolID(tokenA, tokenB);
        bytes32 poolIDBC = PoolUtils._poolID(tokenB, tokenC);
        bytes32 poolIDCD = PoolUtils._poolID(tokenC, tokenD);

        // Fetch the pool indexes
        bytes32[] memory whitelistedPools = poolsConfig.whitelistedPools();
        uint64 indexAB = _poolIndex(tokenA, tokenB, whitelistedPools);
        uint64 indexBC = _poolIndex(tokenB, tokenC, whitelistedPools);
        uint64 indexCD = _poolIndex(tokenC, tokenD, whitelistedPools);

//		console.log( "indexAB: ", indexAB );
//		console.log( "indexBC: ", indexBC );
//		console.log( "indexCD: ", indexCD );


        // Calculate expected profits distributed per pool
        uint256 totalProfitAB = _arbitrageProfits[poolIDAB];
        uint256 totalProfitBC = _arbitrageProfits[poolIDBC];
        uint256 totalProfitCD = _arbitrageProfits[poolIDCD];
        uint256 expectedProfitPerPoolAB = totalProfitAB / 3;
        uint256 expectedProfitPerPoolBC = totalProfitBC / 3;
        uint256 expectedProfitPerPoolCD = totalProfitCD / 3;

        // Verify that each pool has received the correct share of profits
        assertEq(profits[indexAB], expectedProfitPerPoolAB, "Pool tokenA/tokenB received incorrect share of profits");
        assertEq(profits[indexBC], expectedProfitPerPoolBC, "Pool tokenB/tokenC received incorrect share of profits");
        assertEq(profits[indexCD], expectedProfitPerPoolCD, "Pool tokenC/tokenD received incorrect share of profits");
    }


    // A unit test that confirms `_calculateArbitrageProfits` correctly calculates zero profits when arbitrageProfits for all pools are zero
    function testCalculateArbitrageProfits_ZeroProfits() public {
        bytes32[] memory poolIDs = poolsConfig.whitelistedPools();
        uint256[] memory calculatedProfits = new uint256[](poolIDs.length);

        // Assume zero arbitrage profits for any pool
        for (uint256 i = 0; i < poolIDs.length; i++) {
            _arbitrageProfits[poolIDs[i]] = 0;
        }

        _calculateArbitrageProfits(poolIDs, calculatedProfits);

        // All profited amounts should be zero
        for (uint256 i = 0; i < calculatedProfits.length; i++) {
            assertEq(calculatedProfits[i], 0, "Arbitrage profit should be zero");
        }
	}


    // A unit test to ensure that profits are calculated correctly when some pools contribute to multiple arbitrage opportunities
	function testCalculateMultipleArbitrageProfits() public {
        // Setup the environment: whitelist pools and update arbitrage indices
        vm.startPrank(address(deployment.dao()));
        deployment.poolsConfig().whitelistPool( tokenA, tokenB); // whitelisted pool #1
        deployment.poolsConfig().whitelistPool( tokenB, tokenC); // whitelisted pool #2
        deployment.poolsConfig().whitelistPool( tokenA, tokenC); // whitelisted pool #3
        deployment.poolsConfig().whitelistPool( _weth, tokenC); // whitelisted pool #4 that contributes to multiple arbitrage opportunities
        vm.stopPrank();

        this.updateArbitrageIndicies();

        // Simulate arbitrage profits for different arbitrage paths
        this.updateProfitsFromArbitrage(tokenA, tokenB, 15 ether);
        this.updateProfitsFromArbitrage(tokenB, tokenC, 20 ether);
        this.updateProfitsFromArbitrage(tokenA, tokenC, 10 ether);

        // Retrieve the arbitrage profits
        uint256[] memory profits = this.profitsForWhitelistedPools();

        // Calculating expected profits
        // Pool 1 = tokenA -> tokenB contributes to one arbitrage: 15 ether / 3
        uint256 expectedProfitPool1 = uint256(15 * 10**18) / 3;
        // Pool 2 = tokenB -> tokenC contributes to one arbitrage: 20 ether / 3
        uint256 expectedProfitPool2 = uint256(20 * 10**18) / 3;
        // Pool 3 = tokenA -> tokenC contributes to one arbitrage: 10 ether / 3
        uint256 expectedProfitPool3 = uint256(10 * 10**18) / 3;
        // Pool 4 = WETH -> tokenC contributes to two arbitrage paths: tokenB->tokenC->WETH and tokenA->tokenC->WETH
        uint256 expectedProfitPool4 = uint256(20 * 10**18) / 3 + uint256(10 * 10**18) / 3;

        // Verifying that each pool received the correct amount of profits
        // We use the whitelisted pool indices here, which would have been updated after whitelisting the pools
        bytes32[] memory whitelistedPoolIDs = deployment.poolsConfig().whitelistedPools();
        assertEq(profits[_poolIndex(tokenA, tokenB, whitelistedPoolIDs)], expectedProfitPool1, "Incorrect profit for tokenA -> tokenB pool");
        assertEq(profits[_poolIndex(tokenB, tokenC, whitelistedPoolIDs)], expectedProfitPool2, "Incorrect profit for tokenB -> tokenC pool");
        assertEq(profits[_poolIndex(tokenA, tokenC, whitelistedPoolIDs)], expectedProfitPool3, "Incorrect profit for tokenA -> tokenC pool");
        assertEq(profits[_poolIndex(_weth, tokenC, whitelistedPoolIDs)], expectedProfitPool4, "Incorrect profit for WETH -> tokenC pool that contributes to multiple arbitrages");
    }
	}

