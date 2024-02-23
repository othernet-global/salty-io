// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "../../dev/Deployment.sol";
import "./TestArbitrageSearch.sol";


contract TestArbitrage is Deployment
	{
	address public alice = address(0x1111);


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
		salt.transfer(DEPLOYER, 1000000 ether);
		}


	function _setupTokenForTesting( IERC20 token ) public
		{
		// Whitelist the tokens with SALT and WETH
        vm.startPrank(address(dao));
        poolsConfig.whitelistPool(token, usdc);
        poolsConfig.whitelistPool(token, weth);
        vm.stopPrank();

		vm.startPrank(DEPLOYER);
		salt.transfer(alice, 100000 ether);
		weth.transfer(alice, 100000 ether);
		usdc.transfer(alice, 100000 * 10**6);
		usdt.transfer(alice, 100000 * 10**6);
		vm.stopPrank();

		vm.startPrank(alice);
		token.approve( address(liquidity), type(uint256).max );
   		weth.approve( address(liquidity), type(uint256).max );
   		usdc.approve( address(liquidity), type(uint256).max );
   		usdt.approve( address(liquidity), type(uint256).max );
   		salt.approve( address(liquidity), type(uint256).max );

		token.approve( address(pools), type(uint256).max );
   		weth.approve( address(pools), type(uint256).max );
   		salt.approve( address(pools), type(uint256).max );
   		usdc.approve( address(pools), type(uint256).max );
   		usdt.approve( address(pools), type(uint256).max );

		liquidity.depositLiquidityAndIncreaseShare( token, usdc, 100 ether, 100 *10**6, 0, 0, 0, block.timestamp, false );
		liquidity.depositLiquidityAndIncreaseShare( token, weth, 100 ether, 100 ether, 0, 0, 0, block.timestamp, false );
		liquidity.depositLiquidityAndIncreaseShare( salt, weth, 100 ether, 100 ether, 0, 0, 0, block.timestamp, false );
		liquidity.depositLiquidityAndIncreaseShare( weth, usdc, 100 ether, 100 * 10**6, 0, 0, 0, block.timestamp, false );
		liquidity.depositLiquidityAndIncreaseShare( salt, usdc, 100 ether, 100 * 10**6, 0, 0, 0, block.timestamp, false );
		liquidity.depositLiquidityAndIncreaseShare( usdt, usdc, 100 *10**6, 100 * 10**6, 0, 0, 0, block.timestamp, false );
		liquidity.depositLiquidityAndIncreaseShare( usdt, weth, 100 *10**6, 100 ether, 0, 0, 0, block.timestamp, false );

		pools.deposit( token, 100 ether );
		vm.stopPrank();
		}


	function _setupTokenForTestingNoLiquidity( IERC20 token ) public
		{
		// Whitelist the tokens with SALT and WETH
        vm.startPrank(address(dao));
        poolsConfig.whitelistPool(  token, salt);
        poolsConfig.whitelistPool(  token, weth);
        vm.stopPrank();

		vm.startPrank(DEPLOYER);
		salt.transfer(alice, 1000000 ether);
		weth.transfer(alice, 1000000 ether);
		vm.stopPrank();

		vm.startPrank(alice);
		token.approve( address(pools), type(uint256).max );
   		weth.approve( address(pools), type(uint256).max );
   		salt.approve( address(pools), type(uint256).max );

		token.approve( address(liquidity), type(uint256).max );
   		weth.approve( address(liquidity), type(uint256).max );
   		salt.approve( address(liquidity), type(uint256).max );

		liquidity.depositLiquidityAndIncreaseShare( token, salt, 100 ether, 100 ether, 0, 0, 0, block.timestamp, false );
		liquidity.depositLiquidityAndIncreaseShare( token, weth, 100 ether, 100 ether, 0, 0, 0, block.timestamp, false );
		liquidity.depositLiquidityAndIncreaseShare( salt, weth, 100 ether, 100 ether, 0, 0, 0, block.timestamp, false );

		pools.deposit( token, 100 ether );
		}


	// A unit test that checks reserves and arbitrage profits are correct when then swap preceeding in the arbitrage is in the format
	// swap: USDC->WETH
	// arb: WETH->USDC->USDT->WETH
	function testArbitrage1() public
		{
		assertEq( pools.depositedUserBalance( address(dao), weth ), 0, "starting deposited salt balance should be zero" );

		vm.prank(alice);
		IERC20 token = new TestERC20("TEST", 18);

		_setupTokenForTesting(token);
		vm.startPrank(alice);

		uint256 startingWETH = weth.balanceOf(alice);
		uint256 amountOut = pools.depositSwapWithdraw( usdc, weth, 10 * 10**6, 0, block.timestamp );

		// Check the swap itself (prices not accurate)
		assertEq( amountOut, 9090909090909090909 );
        assertEq( weth.balanceOf(alice) - startingWETH, 9090909090909090909 );

        // Check that the arbitrage swaps happened as expected
        (uint256 reservesA0, uint256 reservesA1) = pools.getPoolReserves(weth, usdc);
        (uint256 reservesB0, uint256 reservesB1) = pools.getPoolReserves(usdc, usdt);
        (uint256 reservesC0, uint256 reservesC1) = pools.getPoolReserves(usdt, weth);

		assertFalse( reservesA0 == (100 ether - amountOut), "Arbitrage did not happen" );
		assertTrue( reservesA0 > ( 100 ether - amountOut), "reservesA0 incorrect" );
		assertTrue( reservesA1 < ( 100 *10**6 + 10 *10**6), "reservesA1 incorrect" );
		assertTrue( reservesB0 > (100 *10**6), "reservesB0 incorrect" );
		assertTrue( reservesB1 < (100 *10**6), "reservesB1 incorrect" );
		assertTrue( reservesC0 > (100 *10**6), "reservesC0 incorrect" );
		assertTrue( reservesC1 < (100 ether), "reservesC1 incorrect" );

//		console.log( "profit: ", pools.depositedUserBalance( address(dao), salt ) );
		assertTrue( pools.depositedUserBalance( address(dao), salt ) > 283* 10**15, "arbitrage profit too low" );
		}


	// A unit test that checks reserves and arbitrage profits are correct when then swap preceeding in the arbitrage is in the format
	// swap: WETH->USDC
	// arb: WETH->USDT->USDC->WETH
	function testArbitrage2() public
		{
		assertEq( pools.depositedUserBalance( address(dao), weth ), 0, "starting deposited salt balance should be zero" );

		vm.prank(alice);
		IERC20 token = new TestERC20("TEST", 18);

		_setupTokenForTesting(token);
		vm.startPrank(alice);

		uint256 startingUSDC = usdc.balanceOf(alice);
		uint256 amountOut = pools.depositSwapWithdraw( weth, usdc, 10 ether, 0, block.timestamp );

		// Check the swap itself (prices not accurate)
		assertEq( amountOut, 9090909 );
        assertEq( usdc.balanceOf(alice) - startingUSDC, 9090909 );

        // Check that the arbitrage swaps happened as expected
        (uint256 reservesA0, uint256 reservesA1) = pools.getPoolReserves(weth, usdt);
        (uint256 reservesB0, uint256 reservesB1) = pools.getPoolReserves(usdt, usdc);
        (uint256 reservesC0, uint256 reservesC1) = pools.getPoolReserves(usdc, weth);

		assertFalse( reservesA0 == (100 ether + 10 ether), "Arbitrage did not happen" );
		assertTrue( reservesA0 > ( 100 ether), "reservesA0 incorrect" );
		assertTrue( reservesA1 < ( 100 *10**6), "reservesA1 incorrect" );
		assertTrue( reservesB0 > (100 *10**6), "reservesB0 incorrect" );
		assertTrue( reservesB1 < (100 *10**6), "reservesB1 incorrect" );
		assertTrue( reservesC0 > (100 *10**6 - amountOut), "reservesC0 incorrect" );
		assertTrue( reservesC1 < (100 ether + 10 ether), "reservesC1 incorrect" );

//		console.log( "profit: ", pools.depositedUserBalance( address(dao), salt ) );
		assertTrue( pools.depositedUserBalance( address(dao), salt ) > 283* 10**15, "arbitrage profit too low" );
		}


	// A unit test that checks reserves and arbitrage profits are correct when then swap preceeding in the arbitrage is in the format
	// swap: WETH->swapTokenOut
	// arb: WETH->USDC->swapTokenOut->WETH
	function testArbitrage3() public
		{
		assertEq( pools.depositedUserBalance( address(dao), weth ), 0, "starting deposited salt balance should be zero" );

		vm.prank(alice);
		IERC20 token = new TestERC20("TEST", 18);

		_setupTokenForTesting(token);
		vm.startPrank(alice);

		uint256 startingBalance = token.balanceOf(alice);
		uint256 amountOut = pools.depositSwapWithdraw( weth, token, 10 ether, 0, block.timestamp );

		// Check the swap itself (prices not accurate)
		assertEq( amountOut, 9090909090909090909 );
        assertEq( token.balanceOf(alice) - startingBalance, 9090909090909090909 );

        // Check that the arbitrage swaps happened as expected
        (uint256 reservesA0, uint256 reservesA1) = pools.getPoolReserves(weth, usdc);
        (uint256 reservesB0, uint256 reservesB1) = pools.getPoolReserves(usdc, token);
        (uint256 reservesC0, uint256 reservesC1) = pools.getPoolReserves(token, weth);

		assertFalse( reservesA0 == (100 ether), "Arbitrage did not happen" );
		assertTrue( reservesA0 > ( 100 ether), "reservesA0 incorrect" );
		assertTrue( reservesA1 < ( 100 *10**6), "reservesA1 incorrect" );
		assertTrue( reservesB0 > (100 *10**6), "reservesB0 incorrect" );
		assertTrue( reservesB1 < (100 ether), "reservesB1 incorrect" );
		assertTrue( reservesC0 > (100 ether - amountOut), "reservesC0 incorrect" );
		assertTrue( reservesC1 < (100 ether + 10 ether), "reservesC1 incorrect" );

//		console.log( "profit: ", pools.depositedUserBalance( address(dao), salt ) );
		assertTrue( pools.depositedUserBalance( address(dao), salt ) > 283* 10**15, "arbitrage profit too low" );
		}


	// A unit test that checks reserves and arbitrage profits are correct when then swap preceeding in the arbitrage is in the format
	// swap: swapTokenIn->WETH
	// arb: WETH->swapTokenIn->USDC->WETH
	function testArbitrage4() public
		{
		assertEq( pools.depositedUserBalance( address(dao), weth ), 0, "starting deposited salt balance should be zero" );

		vm.prank(alice);
		IERC20 token = new TestERC20("TEST", 18);

		_setupTokenForTesting(token);
		vm.startPrank(alice);

		uint256 startingWETH = weth.balanceOf(alice);
		uint256 amountOut = pools.depositSwapWithdraw( token, weth, 10 ether, 0, block.timestamp );

		// Check the swap itself (prices not accurate)
		assertEq( amountOut, 9090909090909090909 );
        assertEq( weth.balanceOf(alice) - startingWETH, 9090909090909090909 );

        // Check that the arbitrage swaps happened as expected
        (uint256 reservesA0, uint256 reservesA1) = pools.getPoolReserves(weth, token);
        (uint256 reservesB0, uint256 reservesB1) = pools.getPoolReserves(token, usdc);
        (uint256 reservesC0, uint256 reservesC1) = pools.getPoolReserves(usdc, weth);

		assertFalse( reservesA0 == (100 ether - amountOut), "Arbitrage did not happen" );

		assertTrue( reservesA0 > ( 100 ether - amountOut), "reservesA0 incorrect" );
		assertTrue( reservesA1 < ( 100 ether + 10 ether), "reservesA1 incorrect" );
		assertTrue( reservesB0 > (100 ether), "reservesB0 incorrect" );
		assertTrue( reservesB1 < (100 *10**6), "reservesB1 incorrect" );
		assertTrue( reservesC0 > (100 *10**6), "reservesC0 incorrect" );
		assertTrue( reservesC1 < (100 ether), "reservesC1 incorrect" );

		assertTrue( pools.depositedUserBalance( address(dao), salt ) > 283* 10**15, "arbitrage profit too low" );
		}


	// A unit test that checks reserves and arbitrage profits are correct when then swap preceeding in the arbitrage is in the format
	// swap: swapTokenIn->swapTokenOut
	// arb: WETH->swapTokenOut->swapTokenIn->WETH
    function testArbitrage5() public
		{
		assertEq( pools.depositedUserBalance( address(dao), weth ), 0, "starting deposited salt balance should be zero" );

		vm.startPrank(alice);
		IERC20 token1 = new TestERC20("TEST", 18);
		IERC20 token2 = new TestERC20("TEST", 18);
		vm.stopPrank();

		_setupTokenForTesting(token1);
		vm.warp( block.timestamp + 1 hours );
		_setupTokenForTesting(token2);

        vm.prank(address(dao));
        poolsConfig.whitelistPool( token1, token2);

		vm.startPrank(alice);
		token1.approve( address(pools), type(uint256).max );
		token2.approve( address(pools), type(uint256).max );

		liquidity.depositLiquidityAndIncreaseShare( token1, token2, 100 ether, 100 ether, 0, 0, 0, block.timestamp, false );

		uint256 startingBalance = token2.balanceOf(alice);
		uint256 amountOut = pools.depositSwapWithdraw( token1, token2, 10 ether, 0, block.timestamp );

		// Check the swap itself (prices not accurate)
		assertEq( amountOut, 9090909090909090909 );
        assertEq( token2.balanceOf(alice) - startingBalance, 9090909090909090909 );

        // Check that the arbitrage swaps happened as expected
        (uint256 reservesA0, uint256 reservesA1) = pools.getPoolReserves(weth, token2);
        (uint256 reservesB0, uint256 reservesB1) = pools.getPoolReserves(token2, token1);
        (uint256 reservesC0, uint256 reservesC1) = pools.getPoolReserves(token1, weth);

		assertFalse( reservesA0 == (100 ether), "Arbitrage did not happen" );
		assertTrue( reservesA0 > ( 100 ether), "reservesA0 incorrect" );
		assertTrue( reservesA1 < ( 100 ether), "reservesA1 incorrect" );
		assertTrue( reservesB0 > (100 ether - amountOut), "reservesB0 incorrect" );
		assertTrue( reservesB1 < (100 ether + 10 ether), "reservesB1 incorrect" );
		assertTrue( reservesC0 > (100 ether), "reservesC0 incorrect" );
		assertTrue( reservesC1 < (100 ether), "reservesC1 incorrect" );

//		console.log( "profit: ", pools.depositedUserBalance( address(dao), salt ) );
		assertTrue( pools.depositedUserBalance( address(dao), salt ) > 283* 10**15, "arbitrage profit too low" );
		}


	// A unit test to check that arbitrage doesn't happen when one of the pools in the arbitrage chain has liquidity less than DUST
	function testArbitrageFailed() public
		{
		assertEq( pools.depositedUserBalance( address(dao), salt ), 0, "starting deposited salt balance should be zero" );

		vm.prank(alice);
		IERC20 token = new TestERC20("TEST", 18);

		_setupTokenForTestingNoLiquidity(token);
		vm.startPrank(alice);

		uint256 startingSALT = salt.balanceOf(alice);
		uint256 amountOut = pools.depositSwapWithdraw( weth, salt, 10 ether, 0, block.timestamp );

		// Check the swap itself (prices not accurate)
		assertEq( amountOut, 9090909090909090909 );
		assertEq( salt.balanceOf(alice) - startingSALT, 9090909090909090909 );

		(uint256 reservesA0,) = pools.getPoolReserves(salt, weth);

		assertTrue( reservesA0 == (100 ether - amountOut), "Arbitrage should not happen" );
		assertEq( pools.depositedUserBalance( address(dao), salt ), 0, "There should be no arbitrage profit" );
		}


	// A unit test that checks that multiple swaps for a single pool all yield arbitrage profit when executed consecutively
	function testSeriesOfTrades() public
		{
		assertEq( pools.depositedUserBalance( address(dao), salt ), 0, "starting deposited salt balance should be zero" );

		vm.prank(alice);
		IERC20 token = new TestERC20("TEST", 18);

		_setupTokenForTesting(token);
		vm.startPrank(alice);

		for( uint256 i = 0; i < 20; i++ )
			{
			uint256 startingDepositSALT = pools.depositedUserBalance( address(dao), salt );

			pools.depositSwapWithdraw( salt, weth, 1 ether, 0, block.timestamp );
			vm.roll(block.number + 1);

			uint256 profit = pools.depositedUserBalance( address(dao), salt ) - startingDepositSALT;
			assertTrue( profit > 4*10**13, "Profit lower than expected" );

//			console.log( i, profit );
			}
		}


	function _setupTokenForTestingMin( IERC20 token ) public
		{
		// Whitelist the tokens with WBTC and WETH
        vm.startPrank(address(dao));
        poolsConfig.whitelistPool(token, salt);
        poolsConfig.whitelistPool(token, weth);
        vm.stopPrank();

		vm.startPrank(DEPLOYER);
		wbtc.transfer(alice, 100000 ether);
		weth.transfer(alice, 100000 ether);
		salt.transfer(alice, 100000 ether);
		usdc.transfer(alice, 100000 *10**6);
		vm.stopPrank();

		vm.startPrank(alice);
		token.approve( address(pools), type(uint256).max );
   		usdc.approve( address(pools), type(uint256).max );
   		weth.approve( address(pools), type(uint256).max );
   		salt.approve( address(pools), type(uint256).max );

		token.approve( address(liquidity), type(uint256).max );
   		usdc.approve( address(liquidity), type(uint256).max );
   		weth.approve( address(liquidity), type(uint256).max );
   		salt.approve( address(liquidity), type(uint256).max );

		liquidity.depositLiquidityAndIncreaseShare( token, weth, 100000, 100000, 0, 0, 0, block.timestamp, false );
		liquidity.depositLiquidityAndIncreaseShare( token, salt, 100000, 100000, 0, 0, 0, block.timestamp, false );
		liquidity.depositLiquidityAndIncreaseShare( salt, usdc, 100000, 100000, 0, 0, 0, block.timestamp, false );
		liquidity.depositLiquidityAndIncreaseShare( weth, usdc, 100000, 100000, 0, 0, 0, block.timestamp, false );
		liquidity.depositLiquidityAndIncreaseShare( salt, weth, 100000, 100000, 0, 0, 0, block.timestamp, false );

		pools.deposit( token, 10000000 );
		}


	// A unit test that checks _determineProfits calculates profits correctly with reserves at minimum values.
	// arb: SALT->WETH->USDC->SALT
	function testArbitrageReservesMin() public
		{
		assertEq( pools.depositedUserBalance( address(dao), salt ), 0, "starting deposited salt balance should be zero" );

		vm.prank(alice);
		IERC20 token = new TestERC20("TEST", 18);

		_setupTokenForTestingMin(token);
		vm.startPrank(alice);

		uint256 startingSALT = salt.balanceOf(alice);
		uint256 amountOut = pools.depositSwapWithdraw( weth, salt, 10000, 0, block.timestamp );

		// Check the swap itself
		assertEq( amountOut, 9090 );
        assertEq( salt.balanceOf(alice) - startingSALT, 9090 );

        // Check that the arbitrage swaps happened as expected
        (uint256 reservesA0, uint256 reservesA1) = pools.getPoolReserves(salt, weth);
        (uint256 reservesB0, uint256 reservesB1) = pools.getPoolReserves(weth, usdc);
        (uint256 reservesC0, uint256 reservesC1) = pools.getPoolReserves(usdc, salt);

		assertFalse( reservesA0 == (100000 - amountOut), "Arbitrage did not happen" );
		assertTrue( reservesA0 > ( 100000 - amountOut), "reservesA0 incorrect" );
		assertTrue( reservesA1 < ( 100000 + 10000), "reservesA1 incorrect" );
		assertTrue( reservesB0 > (100000), "reservesB0 incorrect" );
		assertTrue( reservesB1 < 100000, "reservesB1 incorrect" );
		assertTrue( reservesC0 > 100000, "reservesC0 incorrect" );
		assertTrue( reservesC1 < 100000, "reservesC1 incorrect" );

//		console.log( "profit: ", pools.depositedUserBalance( address(dao), salt ) );
		assertEq( pools.depositedUserBalance( address(dao), salt ), 282, "arbitrage profit incorrect" );
		}
	}

