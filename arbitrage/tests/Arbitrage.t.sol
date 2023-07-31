// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.21;

import "forge-std/Test.sol";
import "../../root_tests/TestERC20.sol";
import "../../pools/Pools.sol";
import "../../dev/Deployment.sol";
import "../../pools/PoolUtils.sol";
import "../ArbitrageSearch.sol";


contract TestArbitrageGas is Test, Deployment
	{
	address public alice = address(0x1111);


	constructor()
		{
		// If $COVERAGE=yes, create an instance of the contract so that coverage testing can work
		// Otherwise, what is tested is the actual deployed contract on the blockchain (as specified in Deployment.sol)
		if ( keccak256(bytes(vm.envString("COVERAGE" ))) == keccak256(bytes("yes" )))
			{
			vm.prank(DEPLOYER);
			pools = new Pools(exchangeConfig, poolsConfig);

			pools.setDAO(dao);

			IArbitrageSearch arbitrageSearch = new ArbitrageSearch(pools, exchangeConfig);

			vm.prank(address(dao));
			poolsConfig.setArbitrageSearch( arbitrageSearch );
			}
		}


	function _setupTokenForTesting( IERC20 token ) public
		{
		// Whitelist the tokens with WBTC and WETH
        vm.startPrank(address(dao));
        poolsConfig.whitelistPool(token, wbtc);
        poolsConfig.whitelistPool(token, weth);
        vm.stopPrank();

		vm.startPrank(DEPLOYER);
		wbtc.transfer(alice, 1000000 *10**8);
		weth.transfer(alice, 1000000 ether);
		salt.transfer(alice, 1000000 ether);
		vm.stopPrank();

		vm.startPrank(alice);
		token.approve( address(pools), type(uint256).max );
   		wbtc.approve( address(pools), type(uint256).max );
   		weth.approve( address(pools), type(uint256).max );
   		salt.approve( address(pools), type(uint256).max );

		pools.addLiquidity( token, wbtc, 100 ether, 100 *10**8, 0, block.timestamp );
		pools.addLiquidity( token, weth, 100 ether, 100 ether, 0, block.timestamp );
		pools.addLiquidity( salt, wbtc, 100 ether, 100 *10**8, 0, block.timestamp );
		pools.addLiquidity( salt, weth, 100 ether, 100 ether, 0, block.timestamp );
		pools.addLiquidity( wbtc, weth, 1000 *10**8, 1000 ether, 0, block.timestamp );

		pools.deposit( token, 100 ether );
		}


	function _setupTokenForTesting2( IERC20 token ) public
		{
		// Whitelist the tokens with WBTC and WETH
        vm.startPrank(address(dao));
        poolsConfig.whitelistPool(token, wbtc);
        poolsConfig.whitelistPool(token, weth);
        vm.stopPrank();

		vm.startPrank(alice);
		token.approve( address(pools), type(uint256).max );

		pools.addLiquidity( token, wbtc, 100 ether, 100 *10**8, 0, block.timestamp );
		pools.addLiquidity( token, weth, 100 ether, 100 ether, 0, block.timestamp );

		pools.deposit( token, 100 ether );
		}

	function _setupTokenForTestingNoLiquidity( IERC20 token ) public
		{
		// Whitelist the tokens with WBTC and WETH
        vm.startPrank(address(dao));
        poolsConfig.whitelistPool(token, wbtc);
        poolsConfig.whitelistPool(token, weth);
        vm.stopPrank();

		vm.startPrank(DEPLOYER);
		wbtc.transfer(alice, 1000000 *10**8);
		weth.transfer(alice, 1000000 ether);
		salt.transfer(alice, 1000000 ether);
		vm.stopPrank();

		vm.startPrank(alice);
		token.approve( address(pools), type(uint256).max );
   		wbtc.approve( address(pools), type(uint256).max );
   		weth.approve( address(pools), type(uint256).max );
   		salt.approve( address(pools), type(uint256).max );

		pools.addLiquidity( token, wbtc, 100 ether, 100 *10**8, 0, block.timestamp );
		pools.addLiquidity( token, weth, 100 ether, 100 ether, 0, block.timestamp );
		pools.addLiquidity( salt, wbtc, 100 ether, 100 *10**8, 0, block.timestamp );
		pools.addLiquidity( wbtc, weth, 1000 *10**8, 1000 ether, 0, block.timestamp );

		pools.deposit( token, 100 ether );
		}


	// swap: WBTC->WETH
	// arb: WETH->WBTC->SALT->WETH
	function testArbitrage1() public
		{
		assertEq( pools.depositBalance( address(pools), weth ), 0, "starting deposited eth balance should be zero" );

		vm.prank(alice);
		IERC20 token = new TestERC20(18);

		_setupTokenForTesting(token);
		vm.startPrank(alice);

		uint256 startingWETH = weth.balanceOf(alice);
		uint256 amountOut = pools.depositSwapWithdraw( wbtc, weth, 10 *10**8, 0, block.timestamp );

		// Check the swap itself
		assertEq( amountOut, 9900990099009900991 );
        assertEq( weth.balanceOf(alice) - startingWETH, 9900990099009900991 );

        // Check that the arbitrage swaps happened as expected
        (uint256 reservesA0, uint256 reservesA1) = pools.getPoolReserves(weth, wbtc);
        (uint256 reservesB0, uint256 reservesB1) = pools.getPoolReserves(wbtc, salt);
        (uint256 reservesC0, uint256 reservesC1) = pools.getPoolReserves(salt, weth);

		assertFalse( reservesA0 == (1000 ether - amountOut), "Arbitrage did not happen" );
		assertTrue( reservesA0 > ( 1000 ether - amountOut), "reservesA0 incorrect" );
		assertTrue( reservesA1 < ( 100 ether + 1*10**8), "reservesA1 incorrect" );
		assertTrue( reservesB0 > (100 * 10**8), "reservesB0 incorrect" );
		assertTrue( reservesB1 < (100 ether), "reservesB1 incorrect" );
		assertTrue( reservesC0 > (100 ether), "reservesC0 incorrect" );
		assertTrue( reservesC1 < (1000 ether), "reservesC1 incorrect" );

//		console.log( "profit: ", pools.depositBalance( address(pools), weth ) );
		assertTrue( pools.depositBalance( address(pools), weth ) > 2* 10**15, "arbitrage profit too low" );
		}


	// swap: WETH->WBTC
	// arb: WETH->SALT->WBTC->WETH
	function testArbitrage2() public
		{
		assertEq( pools.depositBalance( address(pools), weth ), 0, "starting deposited eth balance should be zero" );

		vm.prank(alice);
		IERC20 token = new TestERC20(18);

		_setupTokenForTesting(token);
		vm.startPrank(alice);

		uint256 startingWBTC = wbtc.balanceOf(alice);
		uint256 amountOut = pools.depositSwapWithdraw( weth, wbtc, 10 ether, 0, block.timestamp );

		// Check the swap itself
		assertEq( amountOut, 990099010 );
        assertEq( wbtc.balanceOf(alice) - startingWBTC, 990099010 );

        // Check that the arbitrage swaps happened as expected
        (uint256 reservesA0, uint256 reservesA1) = pools.getPoolReserves(weth, salt);
        (uint256 reservesB0, uint256 reservesB1) = pools.getPoolReserves(salt, wbtc);
        (uint256 reservesC0, uint256 reservesC1) = pools.getPoolReserves(wbtc, weth);

		assertFalse( reservesA0 == (100 ether), "Arbitrage did not happen" );
		assertTrue( reservesA0 > ( 100 ether), "reservesA0 incorrect" );
		assertTrue( reservesA1 < ( 100 ether), "reservesA1 incorrect" );
		assertTrue( reservesB0 > (100 ether), "reservesB0 incorrect" );
		assertTrue( reservesB1 < (100 ether), "reservesB1 incorrect" );
		assertTrue( reservesC0 > (1000 *10**8 - amountOut), "reservesC0 incorrect" );
		assertTrue( reservesC1 < (1000 ether + 10 ether), "reservesC1 incorrect" );

//		console.log( "profit: ", pools.depositBalance( address(pools), weth ) );
		assertTrue( pools.depositBalance( address(pools), weth ) > 2* 10**15, "arbitrage profit too low" );
		}


	// swap: WETH->token
	// arb: WETH->WBTC->token->WETH
    function testArbitrage3() public
		{
		assertEq( pools.depositBalance( address(pools), weth ), 0, "starting deposited eth balance should be zero" );

		vm.prank(alice);
		IERC20 token = new TestERC20(18);

		_setupTokenForTesting(token);
		vm.startPrank(alice);

		uint256 startingBalance = token.balanceOf(alice);
		uint256 amountOut = pools.depositSwapWithdraw( weth, token, 10 ether, 0, block.timestamp );

		// Check the swap itself
		assertEq( amountOut, 9090909090909090910 );
        assertEq( token.balanceOf(alice) - startingBalance, 9090909090909090910 );

        // Check that the arbitrage swaps happened as expected
        (uint256 reservesA0, uint256 reservesA1) = pools.getPoolReserves(weth, wbtc);
        (uint256 reservesB0, uint256 reservesB1) = pools.getPoolReserves(wbtc, token);
        (uint256 reservesC0, uint256 reservesC1) = pools.getPoolReserves(token, weth);

		assertFalse( reservesA0 == (1000 ether), "Arbitrage did not happen" );
		assertTrue( reservesA0 > ( 1000 ether), "reservesA0 incorrect" );
		assertTrue( reservesA1 < ( 1000 *10**8), "reservesA1 incorrect" );
		assertTrue( reservesB0 > (100 *10**8), "reservesB0 incorrect" );
		assertTrue( reservesB1 < (100 ether), "reservesB1 incorrect" );
		assertTrue( reservesC0 > (100 ether - amountOut), "reservesC0 incorrect" );
		assertTrue( reservesC1 < (1000 ether + 10 ether), "reservesC1 incorrect" );

//		console.log( "profit: ", pools.depositBalance( address(pools), weth ) );
		assertTrue( pools.depositBalance( address(pools), weth ) > 2* 10**15, "arbitrage profit too low" );
		}


	// swap: token->WETH
    // arb: WETH->token->WBTC->WETH
	function testArbitrage4() public
		{
		assertEq( pools.depositBalance( address(pools), weth ), 0, "starting deposited eth balance should be zero" );

		vm.prank(alice);
		IERC20 token = new TestERC20(18);

		_setupTokenForTesting(token);
		vm.startPrank(alice);

		uint256 startingWETH = weth.balanceOf(alice);
		uint256 amountOut = pools.depositSwapWithdraw( token, weth, 1 ether, 0, block.timestamp );

		// Check the swap itself
		assertEq( amountOut, 990099009900990100 );
        assertEq( weth.balanceOf(alice) - startingWETH, 990099009900990100 );

        // Check that the arbitrage swaps happened as expected
        (uint256 reservesA0, uint256 reservesA1) = pools.getPoolReserves(weth, token);
        (uint256 reservesB0, uint256 reservesB1) = pools.getPoolReserves(token, wbtc);
        (uint256 reservesC0, uint256 reservesC1) = pools.getPoolReserves(wbtc, weth);

		assertFalse( reservesA0 == (100 ether - amountOut), "Arbitrage did not happen" );

		assertTrue( reservesA0 > ( 100 ether - amountOut), "reservesA0 incorrect" );
		assertTrue( reservesA1 < ( 100 ether + 1 ether), "reservesA1 incorrect" );
		assertTrue( reservesB0 > (100 ether), "reservesB0 incorrect" );
		assertTrue( reservesB1 < (100 * 10**8), "reservesB1 incorrect" );
		assertTrue( reservesC0 > (100 * 10**8), "reservesC0 incorrect" );
		assertTrue( reservesC1 < (1000 ether), "reservesC1 incorrect" );

		assertTrue( pools.depositBalance( address(pools), weth ) > 2* 10**15, "arbitrage profit too low" );
		}


	// swap: token1->token2
	// arb: WETH->token2->token1->WETH
    function testArbitrage5() public
		{
		assertEq( pools.depositBalance( address(pools), weth ), 0, "starting deposited eth balance should be zero" );

		vm.startPrank(alice);
		IERC20 token1 = new TestERC20(18);
		IERC20 token2 = new TestERC20(18);
		vm.stopPrank();

		_setupTokenForTesting(token1);
		_setupTokenForTesting(token2);

        vm.prank(address(dao));
        poolsConfig.whitelistPool(token1, token2);

		vm.startPrank(alice);
		token1.approve( address(pools), type(uint256).max );
		token2.approve( address(pools), type(uint256).max );

		pools.addLiquidity( token1, token2, 100 ether, 100 ether, 0, block.timestamp );

		uint256 startingBalance = token2.balanceOf(alice);
		uint256 amountOut = pools.depositSwapWithdraw( token1, token2, 1 ether, 0, block.timestamp );

		// Check the swap itself
		assertEq( amountOut, 990099009900990100 );
        assertEq( token2.balanceOf(alice) - startingBalance, 990099009900990100 );

        // Check that the arbitrage swaps happened as expected
        (uint256 reservesA0, uint256 reservesA1) = pools.getPoolReserves(weth, token2);
        (uint256 reservesB0, uint256 reservesB1) = pools.getPoolReserves(token2, token1);
        (uint256 reservesC0, uint256 reservesC1) = pools.getPoolReserves(token1, weth);

		assertFalse( reservesA0 == (100 ether), "Arbitrage did not happen" );
		assertTrue( reservesA0 > ( 100 ether), "reservesA0 incorrect" );
		assertTrue( reservesA1 < ( 100 ether), "reservesA1 incorrect" );
		assertTrue( reservesB0 > (100 ether - amountOut), "reservesB0 incorrect" );
		assertTrue( reservesB1 < (100 ether + 1 ether), "reservesB1 incorrect" );
		assertTrue( reservesC0 > (100 ether), "reservesC0 incorrect" );
		assertTrue( reservesC1 < (100 ether), "reservesC1 incorrect" );

//		console.log( "profit: ", pools.depositBalance( address(pools), weth ) );
		assertTrue( pools.depositBalance( address(pools), weth ) > 2* 10**15, "arbitrage profit too low" );
		}


	// swap: token1->WETH->token2   (intermediate WETH used in swaps without direct pool on exchange)
	// arb: WETH->token1->WBTC->token2->WETH
    function testArbitrageIntermediateWETH() public
		{
		assertEq( pools.depositBalance( address(pools), weth ), 0, "starting deposited eth balance should be zero" );

		vm.startPrank(alice);
		IERC20 token1 = new TestERC20(18);
		IERC20 token2 = new TestERC20(18);
		vm.stopPrank();

		_setupTokenForTesting(token1);
		_setupTokenForTesting2(token2);

		vm.startPrank(alice);
		token1.approve( address(pools), type(uint256).max );
		token2.approve( address(pools), type(uint256).max );

		uint256 startingBalance = token2.balanceOf(alice);
		uint256 amountOut = pools.depositSwapWithdraw( token1, token2, 1 ether, 0, block.timestamp );

		// Check the swap itself
		assertEq( amountOut, 980392156862745100 );
        assertEq( token2.balanceOf(alice) - startingBalance, 980392156862745100 );

        // Check that the arbitrage swaps happened as expected
        (uint256 reservesA0, uint256 reservesA1) = pools.getPoolReserves(weth, token1);
        (uint256 reservesB0, uint256 reservesB1) = pools.getPoolReserves(token1, wbtc);
        (uint256 reservesC0, uint256 reservesC1) = pools.getPoolReserves(wbtc, token2);
        (uint256 reservesD0, uint256 reservesD1) = pools.getPoolReserves(token2, weth);

		assertFalse( reservesA0 == (100 ether), "Arbitrage did not happen" );
		assertEq( reservesA0, 99492543623174198606, "reservesA0 incorrect" );
		assertEq( reservesA1, 100510044630829603835, "reservesA1 incorrect" );
		assertEq( reservesB0, 100489955369170396165, "reservesB0 incorrect" );
		assertEq( reservesB1, 9951243348, "reservesB1 incorrect" );
		assertEq( reservesC0, 10048756652, "reservesC0 incorrect" );
		assertEq( reservesC1, 99514799156865879689, "reservesC1 incorrect" );
		assertEq( reservesD0, 99504808686271375211, "reservesD0 incorrect" );
		assertEq( reservesD1, 100497655661335838603, "reservesD1 incorrect" );

//		console.log( "profit: ", pools.depositBalance( address(pools), weth ) );
		assertEq( pools.depositBalance( address(pools), weth ), 9800715489962791, "arbitrage profit incorrect" );
		}


	// A unit test to check that arbitrage doesn't happen when one of the pools in the arbitrage chain lacks liquidity
	function testArbitrageFailed() public
		{
		assertEq( pools.depositBalance( address(pools), weth ), 0, "starting deposited eth balance should be zero" );

		vm.prank(alice);
		IERC20 token = new TestERC20(18);

		_setupTokenForTestingNoLiquidity(token);
		vm.startPrank(alice);

		uint256 startingWETH = weth.balanceOf(alice);
		uint256 amountOut = pools.depositSwapWithdraw( wbtc, weth, 10 *10**8, 0, block.timestamp );

		// Check the swap itself
		assertEq( amountOut, 9900990099009900991 );
		assertEq( weth.balanceOf(alice) - startingWETH, 9900990099009900991 );

		(uint256 reservesA0,) = pools.getPoolReserves(weth, wbtc);

		assertTrue( reservesA0 == (1000 ether - amountOut), "Arbitrage should not happen" );
		assertEq( pools.depositBalance( address(pools), weth ), 0, "There should be no arbitrage profit" );
		}


	function testSeriesOfTrades() public
		{
		assertEq( pools.depositBalance( address(pools), weth ), 0, "starting deposited eth balance should be zero" );

		vm.prank(alice);
		IERC20 token = new TestERC20(18);

		_setupTokenForTesting(token);
		vm.startPrank(alice);

		for( uint256 i = 0; i < 20; i++ )
			{
			uint256 startingDepositWeth = pools.depositBalance( address(pools), weth );

			pools.depositSwapWithdraw( weth, wbtc, 1 ether, 0, block.timestamp );

			uint256 profit = pools.depositBalance( address(pools), weth ) - startingDepositWeth;
			assertTrue( profit > 3*10**13, "Profit lower than expected" );

//			console.log( i, profit );
			}
		}
	}

