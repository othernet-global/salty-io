// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.20;

import "forge-std/Test.sol";
import "../../root_tests/TestERC20.sol";
import "../Pools.sol";
import "../../Deployment.sol";
import "../PoolUtils.sol";
import "./TestPools.sol";


contract TestArbitrage is Test, Deployment
	{
	TestERC20[] private tokens = new TestERC20[](10);

	address public alice = address(0x1111);
	address public bob = address(0x2222);
	address public charlie = address(0x3333);

	TestPools public testPools;


	constructor()
		{
		testPools = new TestPools();
		}


	function setUp() public
		{
		vm.startPrank( alice );

		for( uint256 i = 0; i < 10; i++ )
			tokens[i] = new TestERC20( 18 );
		vm.stopPrank();

		for( uint256 i = 0; i < 9; i++ )
			{
			vm.prank(address(dao));
			poolsConfig.whitelistPool( tokens[i], tokens[i + 1] );

			vm.startPrank( alice );
        	tokens[i].approve( address(testPools), type(uint256).max );
        	tokens[i+1].approve( address(testPools), type(uint256).max );
			testPools.addLiquidity( tokens[i], tokens[i + 1], 1000 ether, 1000 ether, 0, block.timestamp );
			vm.stopPrank();
			}

		vm.startPrank(address(dao));
		poolsConfig.whitelistPool( tokens[7], tokens[5] );
		poolsConfig.whitelistPool( tokens[3], tokens[1] );
		vm.stopPrank();

		vm.startPrank( alice );
		testPools.addLiquidity( tokens[7], tokens[5], 1000 ether, 1000 ether, 0, block.timestamp );
		testPools.addLiquidity( tokens[3], tokens[1], 1000 ether, 1000 ether, 0, block.timestamp );

		testPools.deposit( tokens[1], 1000 ether );
		testPools.deposit( tokens[5], 1000 ether );
		vm.stopPrank();
		}


	function _checkArbitrage( uint256 swapAmountIn, uint256 arbAmountIn ) public
		{
		testPools.depositSwapWithdraw( tokens[7], tokens[6], swapAmountIn, 0 ether, block.timestamp );
		testPools.depositSwapWithdraw( tokens[3], tokens[2], swapAmountIn, 0 ether, block.timestamp );

		// Two arbitrage chains will be tested:
		// 1->2->3->1 after a swap from 3->2
		// and 5->6->7->5 after a swap from 7->6


		IERC20[] memory pathA = new IERC20[](4);
		pathA[0] = tokens[1];
		pathA[1] = tokens[2];
		pathA[2] = tokens[3];
		pathA[3] = tokens[1];

		IERC20[] memory pathB1 = new IERC20[](3);
		pathB1[0] = tokens[5];
		pathB1[1] = tokens[6];
		pathB1[2] = tokens[7];

		IERC20[] memory pathB2 = new IERC20[](2);
		pathB2[0] = tokens[7];
		pathB2[1] = tokens[5];

		uint256 arbitrageProfitA = testPools.arbitrage( pathA, arbAmountIn, 0);

		uint256 swapOut = testPools.swap( pathB1, arbAmountIn, 0, block.timestamp);
		uint256 arbitrageProfitB = testPools.swap( pathB2, swapOut, 0, block.timestamp) - arbAmountIn;

		uint256 daoShareOfProfit = ( arbitrageProfitB * poolsConfig.daoPercentShareArbitrage() ) / 100;
		arbitrageProfitB = arbitrageProfitB - daoShareOfProfit;

		assertEq( arbitrageProfitA, arbitrageProfitB );
		}


	function testArbitrage() public
		{
		vm.startPrank( alice );
		_checkArbitrage( 50 ether, 5 ether );
		}
    }

