// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "../../dev/Deployment.sol";
import "../PoolUtils.sol";


contract TestPools2 is Deployment
	{
	TestERC20[] private tokens = new TestERC20[](10);

	address public alice = address(0x1111);
	address public bob = address(0x2222);
	address public charlie = address(0x3333);


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

		vm.startPrank(address(daoVestingWallet));
		salt.transfer(DEPLOYER, 1000000 ether);
		salt.transfer(address(collateralAndLiquidity), 1000000 ether);
		vm.stopPrank();

		vm.startPrank( DEPLOYER );
		for( uint256 i = 0; i < 10; i++ )
			{
			tokens[i] = new TestERC20("TEST", 18);
        	tokens[i].approve( address(pools), type(uint256).max );
        	tokens[i].approve( address(collateralAndLiquidity), type(uint256).max );

        	tokens[i].transfer(address(this), 100000 ether );
        	tokens[i].transfer(address(dao), 100000 ether );
        	tokens[i].transfer(address(collateralAndLiquidity), 100000 ether );
			}
		vm.stopPrank();

		for( uint256 i = 0; i < 9; i++ )
			{
			vm.prank(address(dao));
			poolsConfig.whitelistPool( pools,    tokens[i], tokens[i + 1] );

			vm.prank(DEPLOYER);
			collateralAndLiquidity.depositLiquidityAndIncreaseShare( tokens[i], tokens[i + 1], 500 ether, 500 ether, 0, block.timestamp, false );
			}

		vm.prank(address(dao));
		poolsConfig.whitelistPool( pools,    tokens[5], tokens[7] );
		vm.prank(address(dao));
		poolsConfig.whitelistPool( pools,    tokens[0], tokens[9] );

		vm.startPrank( DEPLOYER );
		collateralAndLiquidity.depositLiquidityAndIncreaseShare( tokens[5], tokens[7], 1000 ether, 1000 ether, 0, block.timestamp, false );

		pools.deposit( tokens[5], 1000 ether );
		pools.deposit( tokens[6], 1000 ether );
		pools.deposit( tokens[7], 1000 ether );
		pools.deposit( tokens[8], 1000 ether );

		collateralAndLiquidity.depositLiquidityAndIncreaseShare( tokens[0], tokens[9], 1000000000 ether, 2000000000 ether, 0, block.timestamp, false );
		vm.stopPrank();

		for( uint256 i = 0; i < 10; i++ )
			{
        	tokens[i].approve( address(pools), type(uint256).max );
        	tokens[i].approve( address(collateralAndLiquidity), type(uint256).max );
        	}

		for( uint256 i = 0; i < 9; i++ )
			{
			pools.deposit( tokens[i], 1000 ether );
			collateralAndLiquidity.depositLiquidityAndIncreaseShare( tokens[i], tokens[i + 1], 500 ether, 500 ether, 0, block.timestamp, false );
        	}

		vm.startPrank(address(collateralAndLiquidity));
		for( uint256 i = 0; i < 10; i++ )
			{
        	tokens[i].approve( address(pools), type(uint256).max );
//			pools.deposit( tokens[i], 1000 ether );
        	}
		tokens[5].approve(address(pools), type(uint256).max );
    	vm.stopPrank();

		vm.startPrank(address(dao));
		tokens[5].approve(address(pools), type(uint256).max );
		pools.deposit(tokens[5], 1 ether);
		vm.stopPrank();

		tokens[5].approve(address(pools), type(uint256).max );
		pools.deposit(tokens[5], 1 ether);
		}


	// A unit test that checks `addLiquidity` with a reversed token order (`tokenB`, `tokenA` instead of `tokenA`, `tokenB`) to ensure that liquidity is added correctly regardless of the order.
	function testAddLiquidityWithReversedTokenOrder() public {

        // Create two new tokens
		vm.startPrank(address(collateralAndLiquidity));
        IERC20 tokenA = new TestERC20( "TEST", 18 );
        IERC20 tokenB = new TestERC20( "TEST", 18 );
        vm.stopPrank();

		vm.prank(address(dao));
		poolsConfig.whitelistPool( pools, tokenA, tokenB);

		vm.startPrank(address(collateralAndLiquidity));
		tokenA.approve(address(pools), type(uint256).max);
		tokenB.approve(address(pools), type(uint256).max);

		// 100 / 1000 tokenA and tokenB
		// Add in the order that will require flipping within addLiquidity
		(bytes32 poolID, bool flipped) = PoolUtils._poolIDAndFlipped(tokenA, tokenB);
		if ( flipped)
	        pools.addLiquidity(tokenA, tokenB, 100 ether, 1000 ether, 0, collateralAndLiquidity.totalShares(poolID));
		else
	        pools.addLiquidity(tokenB, tokenA, 1000 ether, 100 ether, 0, collateralAndLiquidity.totalShares(poolID));

        // Get the new reserves after adding liquidity
        (uint256 reservesA, uint256 reservesB) = pools.getPoolReserves(tokenA, tokenB);

        // Assert that liquidity was added correctly regardless of the order
        assertEq(reservesA, 100 ether, "Reserve for tokenA did not increase correctly.");
        assertEq(reservesB, 1000 ether, "Reserve for tokenB did not increase correctly.");
    }



    // A unit test that tests withdrawal fails if a user tries to withdraw more tokens than they have deposited.
    function testWithdrawalMoreThanDeposit() public {
        vm.startPrank(DEPLOYER);
        TestERC20 token = tokens[1]; // Choose arbitrary token for this test, assumes the contract setup has already been done.

        token.approve(address(pools), type(uint256).max);
        uint256 depositAmount = 1 ether;
        uint256 withdrawAmount = 5 ether; // More than deposited

        pools.deposit(token, depositAmount);

        // Ensure user cannot withdraw more than they have deposited
        vm.expectRevert("Insufficient balance to withdraw specified amount");
        pools.withdraw(token, withdrawAmount);
        vm.stopPrank();
    }


    // A unit test that verifies that `addLiquidity` respects the deposited token ratio when reserves are non-zero.
    function testAddLiquidityRespectsTokenRatioWithNonZeroReserves() public {
        // Create two new tokens
		vm.startPrank(address(collateralAndLiquidity));
        IERC20 tokenA = new TestERC20( "TEST", 18 );
        IERC20 tokenB = new TestERC20( "TEST", 18 );
        vm.stopPrank();

		vm.prank(address(dao));
		poolsConfig.whitelistPool( pools, tokenA, tokenB);

		vm.startPrank(address(collateralAndLiquidity));
		tokenA.approve(address(pools), type(uint256).max);
		tokenB.approve(address(pools), type(uint256).max);

		pools.addLiquidity(tokenA, tokenB, 1000 ether, 2000 ether, 0, collateralAndLiquidity.totalShares(PoolUtils._poolID(tokenA, tokenB)));
		pools.addLiquidity(tokenA, tokenB, 500 ether, 500 ether, 0, collateralAndLiquidity.totalShares(PoolUtils._poolID(tokenA, tokenB)));

        // Get the new reserves after adding liquidity
        (uint256 reservesA, uint256 reservesB) = pools.getPoolReserves(tokenA, tokenB);

        // Assert that liquidity was added correctly regardless of the order
        assertEq(reservesA, 1250 ether, "Reserve for tokenA did not increase correctly.");
        assertEq(reservesB, 2500 ether, "Reserve for tokenB did not increase correctly.");
    }


    // A unit test that checks if the total liquidity adjusts correctly after multiple sequential adds and removes of liquidity by different users.
function testSequentialLiquidityAdjustment() public {

	bytes32[] memory poolIDs = new bytes32[](1);
	poolIDs[0] = PoolUtils._poolID( tokens[1], tokens[2] );

    uint256 initialTotalLiquidity = collateralAndLiquidity.totalSharesForPools(poolIDs)[0];
    uint256 liquidityAddedByAlice;
    uint256 liquidityAddedByBob;
    uint256 liquidityAddedByCharlie;

	vm.startPrank(DEPLOYER);
	tokens[1].transfer(alice, 10000 ether);
	tokens[2].transfer(alice, 10000 ether);
	tokens[1].transfer(bob, 10000 ether);
	tokens[2].transfer(bob, 10000 ether);
	tokens[1].transfer(charlie, 10000 ether);
	tokens[2].transfer(charlie, 10000 ether);
	vm.stopPrank();

	vm.startPrank(alice);
	tokens[1].approve(address(collateralAndLiquidity), type(uint256).max);
	tokens[2].approve(address(collateralAndLiquidity), type(uint256).max);
	vm.stopPrank();

	vm.startPrank(bob);
	tokens[1].approve(address(collateralAndLiquidity), type(uint256).max);
	tokens[2].approve(address(collateralAndLiquidity), type(uint256).max);
	vm.stopPrank();

	vm.startPrank(charlie);
	tokens[1].approve(address(collateralAndLiquidity), type(uint256).max);
	tokens[2].approve(address(collateralAndLiquidity), type(uint256).max);
	vm.stopPrank();

    // Alice adds liquidity
    vm.prank(alice);
    (,,liquidityAddedByAlice) = collateralAndLiquidity.depositLiquidityAndIncreaseShare(tokens[1], tokens[2], 5 ether, 5 ether, 0, block.timestamp, false);

    // Check liquidity adjustment for Alice
    uint256 newTotalLiquidity = collateralAndLiquidity.totalSharesForPools(poolIDs)[0];
    assertEq(newTotalLiquidity, initialTotalLiquidity + liquidityAddedByAlice, "Total liquidity does not match after Alice adds liquidity");

    // Bob adds liquidity
    vm.prank(bob);
    (,,liquidityAddedByBob) =collateralAndLiquidity.depositLiquidityAndIncreaseShare(tokens[1], tokens[2], 3 ether, 3 ether, 0, block.timestamp, false);

    // Check liquidity adjustment for Bob
    newTotalLiquidity = collateralAndLiquidity.totalSharesForPools(poolIDs)[0];
    assertEq(newTotalLiquidity, initialTotalLiquidity + liquidityAddedByAlice + liquidityAddedByBob, "Total liquidity does not match after Bob adds liquidity");

    // Charlie adds liquidity
    vm.prank(charlie);
    (,,liquidityAddedByCharlie) = collateralAndLiquidity.depositLiquidityAndIncreaseShare(tokens[1], tokens[2], 2 ether, 2 ether, 0, block.timestamp, false);

    // Check liquidity adjustment for Charlie
    newTotalLiquidity = collateralAndLiquidity.totalSharesForPools(poolIDs)[0];
    assertEq(newTotalLiquidity, initialTotalLiquidity + liquidityAddedByAlice + liquidityAddedByBob + liquidityAddedByCharlie, "Total liquidity does not match after Charlie adds liquidity");

	vm.warp( block.timestamp + 1 hours );

    // Alice removes liquidity
    vm.prank(alice);
    uint256 liquidityToRemoveByAlice = liquidityAddedByAlice / 2;
    collateralAndLiquidity.withdrawLiquidityAndClaim(tokens[1], tokens[2], liquidityToRemoveByAlice, 0, 0, block.timestamp);

    // Check liquidity adjustment for Alice removing liquidity
    newTotalLiquidity = collateralAndLiquidity.totalSharesForPools(poolIDs)[0];
    assertEq(newTotalLiquidity, initialTotalLiquidity + liquidityAddedByAlice / 2 + liquidityAddedByBob + liquidityAddedByCharlie, "Total liquidity does not match after Alice removes liquidity");

    // Bob removes liquidity
    vm.prank(bob);
    uint256 liquidityToRemoveByBob = liquidityAddedByBob / 2;
    collateralAndLiquidity.withdrawLiquidityAndClaim(tokens[1], tokens[2], liquidityToRemoveByBob, 0, 0, block.timestamp);

    // Check liquidity adjustment for Bob removing liquidity
    newTotalLiquidity = collateralAndLiquidity.totalSharesForPools(poolIDs)[0];
    assertEq(newTotalLiquidity, initialTotalLiquidity + liquidityAddedByAlice / 2 + liquidityAddedByBob / 2 + liquidityAddedByCharlie, "Total liquidity does not match after Bob removes liquidity");

    // Charlie removes all liquidity
    vm.prank(charlie);
    collateralAndLiquidity.withdrawLiquidityAndClaim(tokens[1], tokens[2], liquidityAddedByCharlie, 0, 0, block.timestamp);

    // Check liquidity adjustment for Charlie removing all liquidity
    newTotalLiquidity = collateralAndLiquidity.totalSharesForPools(poolIDs)[0];
    assertEq(newTotalLiquidity, initialTotalLiquidity + liquidityAddedByAlice / 2 + liquidityAddedByBob / 2, "Total liquidity does not match after Charlie removes all liquidity");
}


    // A unit test that checks if the protocol correctly handles deposits and withdraws of dust amounts (just above and just below the PoolUtils.DUST limit).
	function testDepositAndWithdrawDustAmounts() public {
        uint256 dust = PoolUtils.DUST;
        IERC20 token = tokens[0]; // Use the first token for simplicity
        uint256 justAboveDust = dust + 1;
        uint256 justBelowDust = dust - 1;

        // Expect a revert for attempting to deposit dust amount
        vm.expectRevert("Deposit amount too small");
        pools.deposit(token, justBelowDust);

        // Expect a revert for attempting to withdraw dust amount
        vm.expectRevert("Withdraw amount too small");
        pools.withdraw(token, justBelowDust);

        // Deposit a small amount just above dust
        vm.startPrank(DEPLOYER);
        token.approve(address(pools), justAboveDust);
        pools.deposit(token, justAboveDust);

        // Check that the deposit was successful
        assertEq(pools.depositedUserBalance(DEPLOYER, token), justAboveDust);

        // Withdraw the same amount, just above dust
        pools.withdraw(token, justAboveDust);

        // Check that the withdrawal was successful and user balance is back to 0
        assertEq(pools.depositedUserBalance(DEPLOYER, token), 0);
    }


    // A unit test that ensures `addLiquidity` reverts if called before the exchange is live (`_startExchangeApproved` set to true).
	function testAddRemoveLiquidityBeforeExchangeLive() public {
		pools = new Pools(exchangeConfig, poolsConfig);
		pools.setContracts(dao, collateralAndLiquidity);

        // Starting with `addLiquidity` call
        vm.startPrank(address(collateralAndLiquidity));

        // Expect revert when calling `addLiquidity` before exchange is live
        uint256 totalShares = collateralAndLiquidity.totalShares(PoolUtils._poolID(tokens[0], tokens[1]));
        vm.expectRevert("The exchange is not yet live");
        pools.addLiquidity(tokens[0], tokens[1], 1 ether, 1 ether, 0, totalShares);
    }


    // A unit test that checks the exact amount of tokens transferred after calling `deposit`.
    function testDepositTransfersExactAmount() public {
        // Arbitrarily choosing token index 1 for this test
        TestERC20 token = tokens[1];
        address user = address(this); // Using the test contract itself as the user

        // Starting balances
        uint256 userBalanceBefore = token.balanceOf(user);
        uint256 contractBalanceBefore = token.balanceOf(address(pools));

        uint256 depositAmount = 1000 ether;

        // Approve and deposit the tokens
        vm.startPrank(user);
        token.approve(address(pools), depositAmount);
        pools.deposit(token, depositAmount);
        vm.stopPrank();

        // Ending balances
        uint256 userBalanceAfter = token.balanceOf(user);
        uint256 contractBalanceAfter = token.balanceOf(address(pools));

        // Make sure the balances are updated correctly
        assertEq(userBalanceBefore - depositAmount, userBalanceAfter, "Incorrect user balance after deposit");
        assertEq(contractBalanceBefore + depositAmount, contractBalanceAfter, "Incorrect contract balance after deposit");
    }


    // A unit test that ensures `withdraw` transfers the exact amount of tokens back to the user.
    function testWithdrawTransfersExactTokenAmount() public {
        // Amount to test withdraw
        uint256 withdrawAmount = 500 ether;

        // Ensure Alice has enough tokens to withdraw
        TestERC20 token = tokens[0];
        vm.startPrank(DEPLOYER);
        token.transfer(address(pools), withdrawAmount);
        pools.deposit(token, withdrawAmount);

        uint256 aliceInitialTokenBalance = token.balanceOf(DEPLOYER);

        // Perform the external call to withdraw
        pools.withdraw(token, withdrawAmount);
        vm.stopPrank();

        uint256 aliceFinalTokenBalance = token.balanceOf(DEPLOYER);
        assertEq(aliceFinalTokenBalance, aliceInitialTokenBalance + withdrawAmount);
    }


    // A unit test that checks the behavior when calling `withdraw` with amount greater than the token balance of the contract.
    function testWithdrawWithExcessiveAmount() public {
        // Initializing variables outside for reuse
        IERC20 token;
        uint256 excessiveAmount;

        // Set test case for withdraw with amount greater than the token balance of the contract for an arbitrary token
        token = tokens[0]; // Assume tokens[0] is the target token for which the balance will be checked
        excessiveAmount = token.balanceOf(address(pools)) + 1 ether; // Amount greater than the contract's balance

        // Expect the contract to revert due to insufficient token balance
        vm.expectRevert("Insufficient balance to withdraw specified amount");

        // Attempt to withdraw the excessive amount
        pools.withdraw(token, excessiveAmount);
    }


    // A unit test that attempts a swap with a zero `minAmountOut`, expecting success under normal conditions.
    function testSwapWithZeroMinAmountOut() public {
        vm.startPrank(DEPLOYER);
        IERC20 tokenIn = tokens[0];
        IERC20 tokenOut = tokens[1];
        uint256 swapAmountIn = 1 ether;

        // Ensure sufficient balance of tokenIn is deposited for the swap
        tokenIn.approve(address(pools), swapAmountIn);
        pools.deposit(tokenIn, swapAmountIn);

        // Attempt a swap with a zero `minAmountOut`, expecting success
        pools.swap(tokenIn, tokenOut, swapAmountIn, 0, block.timestamp + 1 minutes);

        // Get the amount out after swap
        uint256 swapAmountOut = pools.depositedUserBalance(DEPLOYER, tokenOut);

        // Ensure swapAmountOut is greater than zero
        assertTrue(swapAmountOut > 0, "Swap amount out should be greater than zero.");

        vm.stopPrank();
    }


   	// A unit test that checks balance consistency of `_userDeposits` mapping after several deposit and withdrawal actions by the same user.
	function testBalanceConsistencyAfterMultipleDepositAndWithdrawActions() public {
        uint256 initialBalance = pools.depositedUserBalance(alice, tokens[0]);
        uint256 depositAmount1 = 1 ether;
        uint256 withdrawAmount1 = 0.5 ether;
        uint256 depositAmount2 = 2 ether;
        uint256 withdrawAmount2 = 1 ether;

        // DEPLOYER deposits first amount
        vm.startPrank(DEPLOYER);
        tokens[0].approve(address(pools), type(uint256).max);
        tokens[1].approve(address(pools), type(uint256).max);
        pools.deposit(tokens[0], depositAmount1);
        uint256 balanceAfterDeposit1 = pools.depositedUserBalance(DEPLOYER, tokens[0]);
        assertEq(initialBalance + depositAmount1, balanceAfterDeposit1);

        // DEPLOYER withdraws first amount
        pools.withdraw(tokens[0], withdrawAmount1);
        uint256 balanceAfterWithdraw1 = pools.depositedUserBalance(DEPLOYER, tokens[0]);
        assertEq(balanceAfterDeposit1 - withdrawAmount1, balanceAfterWithdraw1);

        // DEPLOYER deposits second amount
        pools.deposit(tokens[0], depositAmount2);
        uint256 balanceAfterDeposit2 = pools.depositedUserBalance(DEPLOYER, tokens[0]);
        assertEq(balanceAfterWithdraw1 + depositAmount2, balanceAfterDeposit2);

        // DEPLOYER withdraws second amount
        pools.withdraw(tokens[0], withdrawAmount2);
        uint256 balanceAfterWithdraw2 = pools.depositedUserBalance(DEPLOYER, tokens[0]);
        assertEq(balanceAfterDeposit2 - withdrawAmount2, balanceAfterWithdraw2);
    }


    // A unit test that confirms the swap function properly reverts when the deadline is set in the past.
    function testSwapRevertsWhenDeadlinePast() public {
        vm.startPrank(address(collateralAndLiquidity));
        IERC20 tokenIn = tokens[2];
        IERC20 tokenOut = tokens[3];
        uint256 swapAmountIn = 10 ether;
        uint256 minAmountOut = 1 ether;

        // Deposit the swap amount into the Pools contract
        pools.deposit(tokenIn, swapAmountIn);

        // Set the deadline to the past
        uint256 deadline = block.timestamp - 1;

        // Expect the swap to revert due to the deadline being in the past
        vm.expectRevert("TX EXPIRED");
        pools.swap(tokenIn, tokenOut, swapAmountIn, minAmountOut, deadline);
        vm.stopPrank();
    }


    // A unit test that verifies correct transfer of `swapAmountOut` to the sender after calling `depositSwapWithdraw`.
	function testCorrectSwapAmountTransferToSender() public {
        vm.startPrank(address(DEPLOYER));

        // Starting balance of the recipient
        uint256 startBalanceTokenOut = tokens[5].balanceOf(address(DEPLOYER));

        // Define amount to swap
        uint256 swapAmountIn = 1 ether;

        // Get the result of calling depositSwapWithdraw
        uint256 swapAmountOut = pools.depositSwapWithdraw(tokens[5], tokens[7], swapAmountIn, 0, block.timestamp + 1 minutes);

        // Ending balance of the recipient
        uint256 endBalanceTokenOut = tokens[7].balanceOf(address(DEPLOYER));

        // Assert the correct amount has been transfered
        assertEq(endBalanceTokenOut - startBalanceTokenOut, swapAmountOut, "Incorrect swap amount transfered to the sender");

        vm.stopPrank();
    }


    // A unit test that confirms deposit reverts when depositing an amount larger than user's token balance.
	function testDepositRevertsWhenExceedingBalance() public {
        vm.startPrank(alice);
		tokens[0].approve(address(pools), type(uint256).max);

        // Alice attempts to deposit more tokens than her balance
        uint256 aliceBalance = tokens[0].balanceOf(alice);
        uint256 depositAmount = aliceBalance + 1 ether; // Deposit amount greater than balance

        vm.expectRevert("ERC20: transfer amount exceeds balance");
        pools.deposit(tokens[0], depositAmount);

        vm.stopPrank();
        }


    // A unit test to ensure non-existing token pairs cannot execute swap.
	function testNonExistingTokenPairsCannotExecuteSwap() public {
        // Arrange
        TestERC20 nonExistingToken = new TestERC20("NONEXIST", 18);
        uint256 swapAmountIn = 1 ether;
        uint256 minAmountOut = 1; // arbitraty min amount out
        uint256 deadline = block.timestamp + 1 hours; // arbitrary deadline in the future

        // Assert that the pair is not whitelisted
        bool isWhitelisted = poolsConfig.isWhitelisted(PoolUtils._poolID(nonExistingToken, tokens[0]));
        assertEq(isWhitelisted, false, "Non-existing token pair should not be whitelisted");

        // Act & Assert
        vm.expectRevert("Insufficient deposited token balance of initial token");
        pools.swap(nonExistingToken, tokens[0], swapAmountIn, minAmountOut, deadline);
    }


    // A unit test that demonstrates failure to swap due to insufficient output amount caused by slippage.
	function testSwapInsufficientOutputAmountDueToSlippage() public {
        IERC20 testTokenIn = tokens[2];
        IERC20 testTokenOut = tokens[3];
        uint256 amountIn = 10 ether;
        uint256 depositedBalanceBefore = pools.depositedUserBalance(address(collateralAndLiquidity), IERC20(testTokenOut));

        vm.startPrank(address(collateralAndLiquidity));
        testTokenIn.approve(address(pools), type(uint256).max);
        pools.deposit(IERC20(testTokenIn), amountIn);
        vm.expectRevert("Insufficient resulting token amount");
        pools.swap(IERC20(testTokenIn), IERC20(testTokenOut), amountIn, amountIn, block.timestamp + 1 minutes);
        vm.stopPrank();

        uint256 depositedBalanceAfter = pools.depositedUserBalance(address(collateralAndLiquidity), IERC20(testTokenOut));
        assertEq(depositedBalanceBefore, depositedBalanceAfter, "Balance should not change due to failed swap");
    }


    // A unit test to validate that depositSwapWithdraw returns a correct output amount for a given input amount.
	function testDepositSwapWithdrawOutputsCorrectly() public {
        IERC20 tokenIn = tokens[2];
        IERC20 tokenOut = tokens[3];
        uint256 initialAmount = 200 ether;
        uint256 expectedAmountOut = 166.666666666666666666 ether;

        // Deposit `initialAmount` of `tokenIn` by the user
        vm.startPrank(address(collateralAndLiquidity));
        tokenIn.approve(address(pools), initialAmount);
        pools.deposit(tokenIn, initialAmount);

        // Perform depositSwapWithdraw
        uint256 minAmountOut = 160 ether; // An example minimum acceptable amount out
        uint256 deadline = block.timestamp + 1 hours; // Example deadline
        uint256 actualAmountOut = pools.swap(tokenIn, tokenOut, initialAmount, minAmountOut, deadline);

        // Assert that the outputs match expected
        assertEq(actualAmountOut, expectedAmountOut, "Incorrect output amount");

        vm.stopPrank();
        }


    // A unit test that checks double swap (tokenA -> tokenB -> tokenC) matches two single swaps (tokenA->tokenB) and (tokenB->tokenC)
    function testDoubleSwapMatchesExpectedOutput() public {

  		(uint256 reservesA1, uint256 reservesB1) = pools.getPoolReserves(tokens[0], tokens[1]);
  		(uint256 reservesC1, uint256 reservesD1) = pools.getPoolReserves(tokens[1], tokens[2]);

  		(uint256 reservesA2, uint256 reservesB2) = pools.getPoolReserves(tokens[3], tokens[4]);
  		(uint256 reservesC2, uint256 reservesD2) = pools.getPoolReserves(tokens[4], tokens[5]);

		// Make sure the starting reserves match
		assertEq( reservesA1, reservesA2 );
		assertEq( reservesB1, reservesB2 );
		assertEq( reservesC1, reservesC2 );
		assertEq( reservesD1, reservesD2 );

		vm.startPrank(DEPLOYER);
		tokens[0].approve(address(pools), type(uint256).max);
		tokens[3].approve(address(pools), type(uint256).max);
		tokens[4].approve(address(pools), type(uint256).max);


		uint256 amountOut1 = pools.depositDoubleSwapWithdraw(tokens[0], tokens[1], tokens[2], 100 ether, 0, block.timestamp);

		uint256 amountOut2a = pools.depositSwapWithdraw(tokens[3], tokens[4], 100 ether, 0, block.timestamp);
		uint256 amountOut2b = pools.depositSwapWithdraw(tokens[4], tokens[5], amountOut2a, 0, block.timestamp);

		assertEq( amountOut1, amountOut2b);
    }



    // A unit test that confirms successful token withdrawal decrements user's deposit balance.
    function testSuccessfulTokenWithdrawalDecrementsDepositBalance() public {
        vm.startPrank(address(collateralAndLiquidity));

        // Initial deposit
        uint256 depositAmount = 500 ether;
        pools.deposit(tokens[2], depositAmount);

        // Check initial deposit balance
        uint256 initialDepositBalance = pools.depositedUserBalance(address(collateralAndLiquidity), tokens[2]);
        assertEq(initialDepositBalance, depositAmount, "Initial deposit balance incorrect");

        // Withdraw tokens
        uint256 withdrawalAmount = 100 ether;
        pools.withdraw(tokens[2], withdrawalAmount);

        // Check deposit balance after withdrawal
        uint256 afterWithdrawalDepositBalance = pools.depositedUserBalance(address(collateralAndLiquidity), tokens[2]);
        assertEq(afterWithdrawalDepositBalance, depositAmount - withdrawalAmount, "Deposit balance after withdrawal incorrect");

        vm.stopPrank();
    }


    // A unit test to confirm that a swap resulting in reserves falling below PoolUtils.DUST reverts.
    function testSwapReserveBelowDust() public {
        // Create two new tokens
		vm.startPrank(address(collateralAndLiquidity));
        IERC20 tokenA = new TestERC20( "TEST", 18 );
        IERC20 tokenB = new TestERC20( "TEST", 18 );
        vm.stopPrank();

		vm.prank(address(dao));
		poolsConfig.whitelistPool( pools, tokenA, tokenB);

		vm.startPrank(address(collateralAndLiquidity));
		tokenA.approve(address(pools), type(uint256).max);
		tokenB.approve(address(pools), type(uint256).max);

		pools.addLiquidity(tokenA, tokenB, PoolUtils.DUST + 1, PoolUtils.DUST + 1, 0, collateralAndLiquidity.totalShares(PoolUtils._poolID(tokenA, tokenB)));

        vm.expectRevert("Insufficient reserves after swap");
        pools.depositSwapWithdraw(tokenA, tokenB, 50, 0, block.timestamp + 1 minutes);
    }


    // A unit test that simulates lack of arbitrage opportunity due to unfavorable reserves balance.
	function testLackOfArbitrageOpportunity() public {

		// Initial swap
		vm.prank(address(DEPLOYER));
		pools.depositSwapWithdraw(tokens[0], tokens[1], 100 ether, 0, block.timestamp);

		// No arbitrage should happen with this trade as the reserves are already too far out of balance
		uint256 daoBalance = pools.depositedUserBalance(address(dao), salt);
		pools.depositSwapWithdraw(tokens[1], tokens[0], 1 ether, 0, block.timestamp);
		uint256 daoBalance2 = pools.depositedUserBalance(address(dao), salt);

		assertEq( daoBalance, daoBalance2);
    }


    // A unit test to check for proper handling of maximum liquidity removal in removeLiquidity.
    function testMaximumLiquidityRemoval() public {
		vm.startPrank(address(collateralAndLiquidity));
		IERC20 tokenA = new TestERC20( "TEST", 18 );
		IERC20 tokenB = new TestERC20( "TEST", 18 );
		vm.stopPrank();

		vm.prank(address(dao));
		poolsConfig.whitelistPool( pools, tokenA, tokenB);

		vm.startPrank(address(collateralAndLiquidity));
		tokenA.approve(address(pools), type(uint256).max);
		tokenB.approve(address(pools), type(uint256).max);

		pools.addLiquidity(tokenA, tokenB, 100 ether, 100 ether, 0, 0);

		uint256 totalShares = 200 ether;
		pools.removeLiquidity(tokenA, tokenB, 200 ether * ( 100 ether - 100 ) / ( 100 ether ), 0, 0, totalShares);

		(uint256 reservesA, uint256 reservesB) = pools.getPoolReserves(tokenA, tokenB);

		// Ensure that DUST remains
		assertEq( reservesA, PoolUtils.DUST );
		assertEq( reservesB, PoolUtils.DUST );

		// Ensure that liquidity can be added back in
		pools.addLiquidity(tokenA, tokenB, 100 ether, 100 ether, 0, 0);
		}
    }