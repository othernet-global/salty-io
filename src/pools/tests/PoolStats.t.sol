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
        bool isWhitelistedPair = true;
        IERC20 arbToken2 = tokenA;
        IERC20 arbToken3 = tokenB;
        uint256 initialProfit;
        uint256 arbitrageProfit = 0;  // no profit

        poolID = PoolUtils._poolIDOnly( arbToken2, arbToken3 );
        initialProfit = _whitelistedArbitrage[poolID];

        _updateProfitsFromArbitrage(isWhitelistedPair, arbToken2, arbToken3, arbitrageProfit);

        assertEq(_whitelistedArbitrage[poolID], initialProfit, "Profit should not increase when arbitrage profit is zero");
    	}


	// A unit test for `_updateProfitsFromArbitrage` that verifies the function updates profits for whitelisted pairs correctly
	function testUpdateProfitsFromArbitrage_WhitelistedPair() public {
        bool isWhitelistedPair = true;
        IERC20 arbToken2 = tokenA;
        IERC20 arbToken3 = tokenB;
        uint256 arbitrageProfit = 1 ether;

        poolID = PoolUtils._poolIDOnly( arbToken2, arbToken3 );

        uint256 initialProfit = _whitelistedArbitrage[poolID];

        _updateProfitsFromArbitrage(isWhitelistedPair, arbToken2, arbToken3, arbitrageProfit);

        assertEq(_whitelistedArbitrage[poolID], initialProfit + arbitrageProfit, "Profit didn't increase as expected for whitelisted pair");
    }


	// A unit test for `_updateProfitsFromArbitrage` that checks the function updates profits for non-whitelisted pairs correctly
	 function testUpdateProfitsFromArbitrage_UpdateNonWhitelistedPairs() public
     {
        bool isWhitelistedPair = false;
        uint256 arbitrageProfit = 1 ether;  // profit

        _updateProfitsFromArbitrage(isWhitelistedPair, tokenA, tokenC, arbitrageProfit);

        poolID = PoolUtils._poolIDOnly( tokenA, tokenC );

        // Check that the profits for the non-whitelisted pairs are updated correctly
        assertEq(_unwhitelistedArbitrage[poolID], arbitrageProfit, "Profit for the pair should be updated");
    }


	// A unit test for `clearProfitsForPools` that verifies the function clears the profits for given pool IDs correctly
	function testClearProfitsForPools() public {
        // Assume initial profits
        _whitelistedArbitrage[poolID] = 1 ether;
        _unwhitelistedArbitrage[poolID2] = 2 ether;

        // Check initial profits
        assertEq(_whitelistedArbitrage[poolID], 1 ether);
        assertEq(_unwhitelistedArbitrage[poolID2], 2 ether);

        // Clear profits for the first pool
        bytes32[] memory poolIDs = new bytes32[](1);
        poolIDs[0] = poolID;
		vm.prank(address(deployment.upkeep()));
        this.clearProfitsForPools(poolIDs);

        // Check that the profits for the first pool are cleared
        assertEq(_whitelistedArbitrage[poolID], 0);
        assertEq(_unwhitelistedArbitrage[poolID2], 2 ether);

        // Clear profits for the second pool
        poolIDs[0] = poolID2;
		vm.prank(address(deployment.upkeep()));
        this.clearProfitsForPools(poolIDs);

        // Check that the profits for the second pool are cleared
        assertEq(_whitelistedArbitrage[poolID], 0);
        assertEq(_unwhitelistedArbitrage[poolID2], 0);
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

    		_unwhitelistedArbitrage[poolID] = 100 ether;
    		_unwhitelistedArbitrage[poolID2] = 50 ether;

    		bytes32[] memory providedPools = new bytes32[](1);
    		providedPools[0] = poolID;

			vm.prank(address(deployment.upkeep()));
    		this.clearProfitsForPools(providedPools);

    		uint256 pool1profit = _unwhitelistedArbitrage[poolID];
    		uint256 pool2profit = _unwhitelistedArbitrage[poolID2];

    		assertEq(pool1profit, 0, "Expect clearProfitsForPools to clear profits for the supplied pool ID");
    		assertEq(pool2profit, 50 ether, "Expect clearProfitsForPools to leave profits unchanged for not supplied pool ID");
    	}


	// A unit test for `profitsForPools` that verifies it returns zero for pools without profits
	function testPoolWithoutProfits() public
	{
		bytes32 _poolID2 = PoolUtils._poolIDOnly( tokenA, tokenB );
		// Checking initial profit of pool to be zero
		assertEq(_unwhitelistedArbitrage[_poolID2], 0, "Initial profit should be zero");
	}


	// A unit test to check constructor that throws error when exchangeConfig address is equal to zero
	function testConstructorAddressZero() public
    {
    vm.expectRevert( "_exchangeConfig cannot be address(0)" );
    new PoolStats(IExchangeConfig(address(0)), IPoolsConfig(address(0)));
    }



	// A unit test for `profitsForPools` that verifies it returns profits correctly for given pool IDs
	function testProfitsForPoolsSimple() public {

		IERC20 weth = exchangeConfig.weth();

		vm.startPrank(address(deployment.dao()));
		deployment.poolsConfig().whitelistPool( tokenA,weth );
		deployment.poolsConfig().whitelistPool( tokenB,weth );
		deployment.poolsConfig().whitelistPool( tokenA,tokenB );
		vm.stopPrank();

		_updateProfitsFromArbitrage(true, tokenA, tokenB, 10 ether);

		bytes32[] memory poolIDs = new bytes32[](3);
		poolIDs[0] = PoolUtils._poolIDOnly(tokenA, tokenB);
		poolIDs[1] = PoolUtils._poolIDOnly(tokenA, weth);
		poolIDs[2] = PoolUtils._poolIDOnly(tokenB, weth);

		vm.prank(address(deployment.upkeep()));
		uint256[] memory profits = this.profitsForPools(poolIDs);

		assertEq(profits[0], uint256(10 ether) / 3, "Incorrect profit for pool 0a");
		assertEq(profits[1], uint256(10 ether) / 3, "Incorrect profit for pool 0b");
		assertEq(profits[2], uint256(10 ether) / 3, "Incorrect profit for pool 0c");

		// Clear the profits
		vm.prank(address(deployment.upkeep()));
		this.clearProfitsForPools(poolIDs);

		vm.prank(address(deployment.upkeep()));
		profits = this.profitsForPools(poolIDs);
		assertEq(profits[0], 0, "Profit for pool 0 not cleared");
		assertEq(profits[1], 0, "Profit for pool 0 not cleared");
		assertEq(profits[2], 0, "Profit for pool 0 not cleared");
	}



	// A unit test for `profitsForPools` that verifies it returns profits correctly for given pool IDs
	function testProfitsForPoolsDoulble() public {

		IERC20 weth = exchangeConfig.weth();

		vm.startPrank(address(deployment.dao()));
		deployment.poolsConfig().whitelistPool( tokenA,weth );
		deployment.poolsConfig().whitelistPool( tokenB,weth );
		deployment.poolsConfig().whitelistPool( tokenA,tokenB );
		deployment.poolsConfig().whitelistPool( tokenB,weth );
		deployment.poolsConfig().whitelistPool( tokenC,weth );
		deployment.poolsConfig().whitelistPool( tokenB,tokenC );
		vm.stopPrank();

		_updateProfitsFromArbitrage(true, tokenA, tokenB, 10 ether);
		_updateProfitsFromArbitrage(true, tokenB, tokenC, 5 ether);

		bytes32[] memory poolIDs = new bytes32[](5);
		poolIDs[0] = PoolUtils._poolIDOnly(tokenA, tokenB);
		poolIDs[1] = PoolUtils._poolIDOnly(tokenA, weth);
		poolIDs[2] = PoolUtils._poolIDOnly(tokenB, weth);

		poolIDs[3] = PoolUtils._poolIDOnly(tokenB, tokenC);
		poolIDs[4] = PoolUtils._poolIDOnly(tokenC, weth);

		vm.prank(address(deployment.upkeep()));
		uint256[] memory profits = this.profitsForPools(poolIDs);

		assertEq(profits[0], uint256(10 ether) / 3, "Incorrect profit for poolIDs[0]");
		assertEq(profits[1], uint256(10 ether) / 3, "Incorrect profit for poolIDs[1]");
		assertEq(profits[2], uint256(10 ether) / 3 + uint256(5 ether) / 3, "Incorrect profit for poolIDs[2]");
		assertEq(profits[3], uint256(5 ether) / 3, "Incorrect profit for poolIDs[3]");
		assertEq(profits[4], uint256(5 ether) / 3, "Incorrect profit for poolIDs[4]");

		// Clear the profits
		vm.prank(address(deployment.upkeep()));
		this.clearProfitsForPools(poolIDs);

		vm.prank(address(deployment.upkeep()));
		profits = this.profitsForPools(poolIDs);
		assertEq(profits[0], 0, "Profit for pool 0 not cleared");
		assertEq(profits[1], 0, "Profit for pool 0 not cleared");
		assertEq(profits[2], 0, "Profit for pool 0 not cleared");
		assertEq(profits[3], 0, "Profit for pool 0 not cleared");
		assertEq(profits[4], 0, "Profit for pool 0 not cleared");
	}

	}

