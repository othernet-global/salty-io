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


	constructor()
	PoolStats(deployment.exchangeConfig(), deployment.poolsConfig())
		{
		// Different decimals
		poolID = PoolUtils._poolIDOnly( tokenA, tokenB );

		// Same decimals
		poolID2 = PoolUtils._poolIDOnly( tokenB, tokenC );
		}


    // A unit test for `_updateProfitsFromArbitrage` that verifies the function ignores cases without arbitrage profit
    function testUpdateProfitsFromArbitrage_IgnoreNoProfitCase() public
    	{
        IERC20 arbToken2 = tokenA;
        IERC20 arbToken3 = tokenB;
        uint256 initialProfit;
        uint256 arbitrageProfit = 0;  // no profit

        poolID = PoolUtils._poolIDOnly( arbToken2, arbToken3 );
        initialProfit = _arbitrageProfits[poolID];

        _updateProfitsFromArbitrage(arbToken2, arbToken3, arbitrageProfit);

        assertEq(_arbitrageProfits[poolID], initialProfit, "Profit should not increase when arbitrage profit is zero");
    	}


	// A unit test for `_updateProfitsFromArbitrage` that verifies the function updates profits for whitelisted pairs correctly
	function testUpdateProfitsFromArbitrage_WhitelistedPair() public {
        IERC20 arbToken2 = tokenA;
        IERC20 arbToken3 = tokenB;
        uint256 arbitrageProfit = 1 ether;

        poolID = PoolUtils._poolIDOnly( arbToken2, arbToken3 );

        uint256 initialProfit = _arbitrageProfits[poolID];

        _updateProfitsFromArbitrage(arbToken2, arbToken3, arbitrageProfit);

        assertEq(_arbitrageProfits[poolID], initialProfit + arbitrageProfit, "Profit didn't increase as expected for whitelisted pair");
    }




	// A unit test for `clearProfitsForPools` that verifies the function clears the profits for given pool IDs correctly
	function testClearProfitsForPools() public {
        // Assume initial profits
        _arbitrageProfits[poolID] = 1 ether;

        // Check initial profits
        assertEq(_arbitrageProfits[poolID], 1 ether);

        // Clear profits for the first pool
        bytes32[] memory poolIDs = new bytes32[](1);
        poolIDs[0] = poolID;
		vm.prank(address(deployment.upkeep()));
        this.clearProfitsForPools(poolIDs);

        // Check that the profits for the first pool are cleared
        assertEq(_arbitrageProfits[poolID], 0);

        // Clear profits for the second pool
        poolIDs[0] = poolID2;
		vm.prank(address(deployment.upkeep()));
        this.clearProfitsForPools(poolIDs);

        // Check that the profits for the second pool are cleared
        assertEq(_arbitrageProfits[poolID], 0);
    }


	// A unit test for `clearProfitsForPools` that verifies an exception is thrown when an unauthorized account tries to call it
	function testClearProfitsForPoolsNotAuthorized() public {
        bytes32[] memory poolIDs = new bytes32[](1);
        poolIDs[0] = PoolUtils._poolIDOnly(tokenA, tokenB);

        vm.expectRevert("PoolStats.clearProfitsForPools is only callable from the Upkeep contract");
        this.clearProfitsForPools(poolIDs);
    }


	// A unit test for `clearProfitsForPools` that verifies the function does not clear profits for non-provided pool ids
		function testClearProfitsForNonProvidedPools() public {
    		bytes32[] memory poolIDs = new bytes32[](2);
    		poolIDs[0] = poolID;
    		poolIDs[1] = poolID2;

    		_arbitrageProfits[poolID] = 100 ether;
    		_arbitrageProfits[poolID2] = 50 ether;

    		bytes32[] memory providedPools = new bytes32[](1);
    		providedPools[0] = poolID;

			vm.prank(address(deployment.upkeep()));
    		this.clearProfitsForPools(providedPools);

    		uint256 pool1profit = _arbitrageProfits[poolID];
    		uint256 pool2profit = _arbitrageProfits[poolID2];

    		assertEq(pool1profit, 0, "Expect clearProfitsForPools to clear profits for the supplied pool ID");
    		assertEq(pool2profit, 50 ether, "Expect clearProfitsForPools to leave profits unchanged for not supplied pool ID");
    	}


	// A unit test for `profitsForPools` that verifies it returns zero for pools without profits
	function testPoolWithoutProfits() public
	{
		bytes32 _poolID2 = PoolUtils._poolIDOnly( tokenA, tokenB );
		// Checking initial profit of pool to be zero
		assertEq(_arbitrageProfits[_poolID2], 0, "Initial profit should be zero");
	}


	// A unit test to check constructor that throws error when exchangeConfig address is equal to zero
	function testConstructorAddressZero() public
    {
    vm.expectRevert( "_exchangeConfig cannot be address(0)" );
    new Pools(IExchangeConfig(address(0)), IPoolsConfig(address(0)));
    }



	// A unit test for `profitsForPools` that verifies it returns profits correctly for given pool IDs
	function testProfitsForPoolsSimple() public {

		IERC20 weth = exchangeConfig.weth();

		vm.startPrank(address(deployment.dao()));
		deployment.poolsConfig().whitelistPool( deployment.pools(), tokenA,weth ); // whitelisted index #9
		deployment.poolsConfig().whitelistPool( deployment.pools(), tokenB,weth ); // whitelisted index #10
		deployment.poolsConfig().whitelistPool( deployment.pools(), tokenA,tokenB ); // whitelisted index #11
		vm.stopPrank();

		this.updateArbitrageIndicies();

		_updateProfitsFromArbitrage(tokenA, tokenB, 10 ether);

		bytes32[] memory whitelistedPoolIDs = deployment.poolsConfig().whitelistedPools();

		vm.prank(address(deployment.upkeep()));
		uint256[] memory profits = this.profitsForPools(whitelistedPoolIDs);

		assertEq(profits[9], uint256(10 ether) / 3, "Incorrect profit for pool 0a");
		assertEq(profits[10], uint256(10 ether) / 3, "Incorrect profit for pool 0b");
		assertEq(profits[11], uint256(10 ether) / 3, "Incorrect profit for pool 0c");

		// Clear the profits
		vm.prank(address(deployment.upkeep()));
		this.clearProfitsForPools(whitelistedPoolIDs);

		vm.prank(address(deployment.upkeep()));
		profits = this.profitsForPools(whitelistedPoolIDs);
		assertEq(profits[9], 0, "Profit for pool 0 not cleared");
		assertEq(profits[10], 0, "Profit for pool 0 not cleared");
		assertEq(profits[11], 0, "Profit for pool 0 not cleared");
	}



	// A unit test for `profitsForPools` that verifies it returns profits correctly for given pool IDs
	function testProfitsForPoolsDouble() public {

		IERC20 weth = exchangeConfig.weth();

		vm.startPrank(address(deployment.dao()));
		deployment.poolsConfig().whitelistPool( deployment.pools(), tokenA,weth ); // whitelisted index #9
		deployment.poolsConfig().whitelistPool( deployment.pools(), tokenA,tokenB ); // whitelisted index #10
		deployment.poolsConfig().whitelistPool( deployment.pools(), tokenB,weth ); // whitelisted index #11
		deployment.poolsConfig().whitelistPool( deployment.pools(), tokenB,tokenC ); // whitelisted index #12
		deployment.poolsConfig().whitelistPool( deployment.pools(), tokenC,weth ); // whitelisted index #13
		vm.stopPrank();

		this.updateArbitrageIndicies();

		_updateProfitsFromArbitrage(tokenA, tokenB, 10 ether);
		_updateProfitsFromArbitrage(tokenB, tokenC, 5 ether);

		bytes32[] memory whitelistedPoolIDs = deployment.poolsConfig().whitelistedPools();

		vm.prank(address(deployment.upkeep()));
		uint256[] memory profits = this.profitsForPools(whitelistedPoolIDs);

		assertEq(profits[9], uint256(10 ether) / 3, "Incorrect profit for poolIDs[0]");
		assertEq(profits[10], uint256(10 ether) / 3, "Incorrect profit for poolIDs[1]");
		assertEq(profits[11], uint256(10 ether) / 3 + uint256(5 ether) / 3, "Incorrect profit for poolIDs[2]");
		assertEq(profits[12], uint256(5 ether) / 3, "Incorrect profit for poolIDs[3]");
		assertEq(profits[13], uint256(5 ether) / 3, "Incorrect profit for poolIDs[4]");

		// Clear the profits
		vm.prank(address(deployment.upkeep()));
		this.clearProfitsForPools(whitelistedPoolIDs);

		vm.prank(address(deployment.upkeep()));
		profits = this.profitsForPools(whitelistedPoolIDs);
		assertEq(profits[9], 0, "Profit for pool 0 not cleared");
		assertEq(profits[10], 0, "Profit for pool 0 not cleared");
		assertEq(profits[11], 0, "Profit for pool 0 not cleared");
		assertEq(profits[12], 0, "Profit for pool 0 not cleared");
		assertEq(profits[13], 0, "Profit for pool 0 not cleared");
	}



	// A unit test for updateArbitrageIndicies
	function testUpdateArbitrageIndicies() public
		{
		IERC20 weth = exchangeConfig.weth();

		vm.startPrank(address(deployment.dao()));
		deployment.poolsConfig().whitelistPool( deployment.pools(), tokenA,weth ); // whitelisted index #9
		deployment.poolsConfig().whitelistPool( deployment.pools(), tokenA,tokenB ); // whitelisted index #10
		deployment.poolsConfig().whitelistPool( deployment.pools(), tokenB,weth ); // whitelisted index #11
		vm.stopPrank();

		this.updateArbitrageIndicies();

		bytes32[] memory whitelistedPoolIDs = deployment.poolsConfig().whitelistedPools();

		uint256 index1 = _poolIndex(tokenA, weth, whitelistedPoolIDs );
		uint256 index2 = _poolIndex(tokenA, tokenB, whitelistedPoolIDs );
		uint256 index3 = _poolIndex(tokenB, weth, whitelistedPoolIDs );

		assertEq( index1, 9 );
		assertEq( index2, 10 );
		assertEq( index3, 11 );

		ArbitrageIndicies memory indicies = _arbitrageIndicies[poolID];
		assertEq( indicies.index1, 9 );
		assertEq( indicies.index2, 10 );
		assertEq( indicies.index3, 11 );
		}

	// A unit test for `profitsForPools` that verifies it returns profits correctly for given pool IDs after some pairs have been unwhitelisted (which changes the whitelistedPools order)
	function testProfitsForPoolsAfterUnwhitelist() public {

		IERC20 weth = exchangeConfig.weth();

		vm.startPrank(address(deployment.dao()));
		deployment.poolsConfig().whitelistPool( deployment.pools(), tokenA,weth ); // whitelisted index #9
		deployment.poolsConfig().whitelistPool( deployment.pools(), tokenA,tokenB ); // whitelisted index #10
		deployment.poolsConfig().whitelistPool( deployment.pools(), tokenB,weth ); // whitelisted index #11
		deployment.poolsConfig().whitelistPool( deployment.pools(), tokenC,weth ); // whitelisted index #12
		deployment.poolsConfig().whitelistPool( deployment.pools(), tokenB,tokenC ); // whitelisted index #13 (will become #9 after unwhitelisting tokenA/weth)
		vm.stopPrank();

		this.updateArbitrageIndicies();

		// This will cause tokenB/tokenC to have index #9
		vm.startPrank(address(deployment.dao()));
		deployment.poolsConfig().unwhitelistPool( deployment.pools(), tokenA,weth ); // now whitelisted index #9
		vm.stopPrank();

		this.updateArbitrageIndicies();

		_updateProfitsFromArbitrage(tokenB, tokenC, 10 ether);

		bytes32[] memory whitelistedPoolIDs = deployment.poolsConfig().whitelistedPools();

		vm.prank(address(deployment.upkeep()));
		uint256[] memory profits = this.profitsForPools(whitelistedPoolIDs);

		assertEq(profits[10], 0, "Incorrect profit for poolIDs[1]");
		assertEq(profits[11], uint256(10 ether) / 3, "Incorrect profit for poolIDs[3]");
		assertEq(profits[12], uint256(10 ether) / 3, "Incorrect profit for poolIDs[4]");
		assertEq(profits[9], uint256(10 ether) / 3, "Incorrect profit for poolIDs[0]");
	}




	}

