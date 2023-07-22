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

	IERC20 noToken = IERC20(address(0));


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


		uint256 arbitrageProfitA = testPools.arbitrage( tokens[1], tokens[2], tokens[3], noToken, arbAmountIn, 0);

		uint256 swapOut = testPools.swap( tokens[5], tokens[6], arbAmountIn, 0, block.timestamp);
		swapOut = testPools.swap( tokens[6], tokens[7], swapOut, 0, block.timestamp);
		uint256 arbitrageProfitB = testPools.swap( tokens[7], tokens[5], swapOut, 0, block.timestamp) - arbAmountIn;

		uint256 daoShareOfProfit = ( arbitrageProfitB * poolsConfig.daoPercentShareArbitrage() ) / 100;
		arbitrageProfitB = arbitrageProfitB - daoShareOfProfit;

		assertEq( arbitrageProfitA, arbitrageProfitB );
		}


	function testArbitrage() public
		{
		vm.startPrank( alice );

		_checkArbitrage( 50 ether, 5 ether );
		_checkArbitrage( 100 ether, 1 ether );
		}


	function testExcessiveArbitrage() public
		{
		vm.startPrank( alice );

		uint256 swapAmountIn = 1 ether;
		uint256 arbAmountIn = 100 ether;

		testPools.depositSwapWithdraw( tokens[3], tokens[2], swapAmountIn, 0 ether, block.timestamp );

		vm.expectRevert( "With arbitrage, resulting amountOut must be greater than arbitrageAmountIn" );
		testPools.arbitrage( tokens[1], tokens[2], tokens[3], noToken, arbAmountIn, 0);
		}


	function testArbitrageProfitSplit() public
		{
		vm.startPrank( alice );

		uint256 swapAmountIn = 100 ether;
		uint256 arbAmountIn = 10 ether;

		testPools.depositSwapWithdraw( tokens[3], tokens[2], swapAmountIn, 0 ether, block.timestamp );

		IERC20[] memory pathA = new IERC20[](4);
		pathA[0] = tokens[1];
		pathA[1] = tokens[2];
		pathA[2] = tokens[3];
		pathA[3] = tokens[1];

		uint256 quoteOut = PoolUtils.quoteAmountOut( testPools, pathA, arbAmountIn );
		uint256 expectedProfit = quoteOut - arbAmountIn;

		uint256 startingDepositDAO = testPools.depositBalance( address(dao), tokens[1] );
		uint256 startingDepositArbitrageProfits = testPools.depositBalance( address(testPools), tokens[1] );

		uint256 expectedProfitDAO = ( expectedProfit * poolsConfig.daoPercentShareArbitrage() ) / 100;
		uint256 expectedProfitArbitrageProfits = expectedProfit - expectedProfitDAO;

		uint256 arbitrageProfit = testPools.arbitrage( tokens[1], tokens[2], tokens[3], noToken, arbAmountIn, 0);

		uint256 profitDAO =  testPools.depositBalance( address(dao), tokens[1] ) - startingDepositDAO;
		uint256 profitArbitrageProfits = testPools.depositBalance( address(testPools), tokens[1] ) - startingDepositArbitrageProfits;

		console.log( "expectedProfitDAO: ", expectedProfitDAO );
		console.log( "expectedProfitArbitrageProfits: ", expectedProfitArbitrageProfits );

		assertEq( arbitrageProfit, expectedProfitArbitrageProfits );
		assertEq( profitDAO, expectedProfitDAO );
		assertEq( profitArbitrageProfits, expectedProfitArbitrageProfits );
		}


	// A unit test which tests the _attemptArbitrage function where the initial token in the chain is WETH. The test should confirm that the swapAmountIn is correctly converted to swapAmountInValueInETH.
	function testPossiblyAttemptArbitrageWETH() public
    {
        vm.startPrank( alice );
        uint256 swapAmountIn = 5 ether;

        (uint256 swapAmountInValueInETH,) = testPools.attemptArbitrage( weth, tokens[1], swapAmountIn, true );

        // Ensure that the swapAmountIn is correctly converted to swapAmountInValueInETH
        assertEq(swapAmountInValueInETH, swapAmountIn);
    }


	// A unit test which tests the _attemptArbitrage function where the initial token in the chain is not WETH. The test should confirm that the swapAmountIn is correctly converted to swapAmountInValueInETH using the pool reserves.
	function testNonWETHArbitrageA() public {

		vm.prank(address(dao));
		poolsConfig.whitelistPool( weth, tokens[1] );

		vm.prank(DEPLOYER);
		weth.transfer(alice, 1000 ether);

		vm.startPrank(alice);
       	weth.approve( address(testPools), type(uint256).max );
		testPools.addLiquidity( weth, tokens[1], 500 ether, 1000 ether, 0, block.timestamp );


        (uint256 swapAmountInValueInETH,) = testPools.attemptArbitrage(tokens[1], tokens[2], 10 ether, false);

        assertEq( swapAmountInValueInETH, 5 ether );
    }


	// A unit test which tests the _attemptArbitrage function where the initial token in the chain is not WETH. The test should confirm that the swapAmountIn is correctly converted to swapAmountInValueInETH using the pool reserves.
	function testNonWETHArbitrageB() public {

		vm.prank(address(dao));
		poolsConfig.whitelistPool( weth, tokens[1] );

		vm.prank(DEPLOYER);
		weth.transfer(alice, 1000 ether);

		vm.startPrank(alice);
       	weth.approve( address(testPools), type(uint256).max );
		testPools.addLiquidity( weth, tokens[1], 1000 ether, 500 ether, 0, block.timestamp );


        (uint256 swapAmountInValueInETH,) = testPools.attemptArbitrage(tokens[1], tokens[2], 10 ether, false);

        assertEq( swapAmountInValueInETH, 20 ether );
    }


	// A unit test which tests the _attemptArbitrage function where there is not enough reserves to determine value in ETH. The function should return early and no arbitrage operation should be performed.
	function testLowReserves() public {

		vm.prank(address(dao));
		poolsConfig.whitelistPool( weth, tokens[1] );

		vm.prank(DEPLOYER);
		weth.transfer(alice, 1000 ether);

		vm.startPrank(alice);

        (uint256 swapAmountInValueInETH,) = testPools.attemptArbitrage(tokens[1], tokens[2], 10 ether, false);

        assertEq( swapAmountInValueInETH, 0 ether );
    }

	// A unit test which tests the _attemptArbitrage function where a profitable arbitrage path is found. The function should call _arbitrage with the found arbitrage path and amount.
	}

