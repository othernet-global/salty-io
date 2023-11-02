// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "../../dev/Deployment.sol";


contract TestPoolsAndCounterswap is Deployment
	{
	address public alice = address(0x1111);
	address public bob = address(0x2222);
	address public charlie = address(0x3333);

	address public counterswapAddress = Counterswap.WETH_TO_SALT;


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


	function setUp() public
		{
		vm.startPrank(DEPLOYER);
		salt.transfer(address(dao), 1000000 ether );
		weth.transfer(address(dao), 1000000 ether );

		// Create SALT/WETH liquidity
		vm.startPrank(address(dao));
		salt.approve( address(pools), type(uint256).max );
		weth.approve( address(pools), type(uint256).max );
		salt.approve( address(collateralAndLiquidity), type(uint256).max );
		weth.approve( address(collateralAndLiquidity), type(uint256).max );

		salt.transfer(alice, 1000 ether);
		weth.transfer(alice, 1000 ether);

		collateralAndLiquidity.depositLiquidityAndIncreaseShare( salt, weth, 1000 ether, 2000 ether, 0, block.timestamp, true);
		vm.stopPrank();

		vm.startPrank(alice);
		salt.approve( address(pools), type(uint256).max );
		weth.approve( address(pools), type(uint256).max );
		salt.approve( address(collateralAndLiquidity), type(uint256).max );
		weth.approve( address(collateralAndLiquidity), type(uint256).max );
		vm.stopPrank();
		}


	function _prepareCounterswap() internal
		{
		// Establish the average price in PoolStats by placing a normal swap
		vm.startPrank(alice);
		pools.depositSwapWithdraw( salt, weth, 10 ether, 0, block.timestamp, true );
		vm.roll( block.number + 1 );
		vm.stopPrank();

		vm.prank(address(dao));
		weth.transfer(address(upkeep), 10000 ether);

		vm.startPrank(address(upkeep));
		weth.approve(address(pools), type(uint256).max);
		pools.depositTokenForCounterswap(counterswapAddress, weth, 100 ether);
		vm.stopPrank();
		}


	// A unit test to check that counterswap fails with a swap in the same block
	function testUnsuccessfulCounterswap() public
		{
		_prepareCounterswap();

		uint256 startingDeposited = pools.depositedUserBalance( counterswapAddress, weth );

		// Initial swap and counterswap
		vm.prank(alice);
		pools.depositSwapWithdraw( salt, weth, 10 ether, 0, block.timestamp, true );

		uint256 usedWETHFromCounterswap0 = startingDeposited - pools.depositedUserBalance( counterswapAddress, weth );
		uint256 wethThatShouldStillBeDepositedInCounterswap0 = 100 ether - usedWETHFromCounterswap0;

//		console.log( "usedWETHFromCounterswap0: ", usedWETHFromCounterswap0 );
//		console.log( "wethThatShouldStillBeDepositedInCounterswap0: ", wethThatShouldStillBeDepositedInCounterswap0 );

		// Initial stats
		startingDeposited = pools.depositedUserBalance( counterswapAddress, weth );
		(uint256 startingReserve0, uint256 startingReserve1) = pools.getPoolReserves( weth, salt );

		// Try an unsuccessful counterswap from SALT->WETH (unsuccessful as a swap occured in the same block)
		vm.prank(alice);
		uint256 wethOut = pools.depositSwapWithdraw( salt, weth, 10 ether, 0, block.timestamp, true );


		// Determine how much of the WETH deposited into the Counterswap contract was used
		uint256 usedWETHFromCounterswap = startingDeposited - pools.depositedUserBalance( counterswapAddress, weth );
		assertEq( usedWETHFromCounterswap, 0, "Incorrect usedWETHFromCounterswap" );

		// Check the updated token balances deposited into the Pools contract itself are correct
		assertEq( pools.depositedUserBalance( counterswapAddress, weth), wethThatShouldStillBeDepositedInCounterswap0 );

		// Counterswap should have acquired the SALT from only the first swap
		assertEq( pools.depositedUserBalance( counterswapAddress, salt), 10 ether );

		// Reserves shouldn't have changed as the counterswap didn't undo the user swap
		(uint256 reserve0, uint256 reserve1) = pools.getPoolReserves( weth, salt );
		assertEq( reserve0, startingReserve0 - wethOut, "Incorrect reserve0" );
		assertEq( reserve1, startingReserve1 + 10 ether, "Incorrect reserve1" );
		}


	// A unit test to check that counterswap behaves as expected with whitelisted pairs.
	function testSuccessfulCounterswap() public
		{
		_prepareCounterswap();

		uint256 startingDeposited = pools.depositedUserBalance( counterswapAddress, weth );

		// Initial swap and counterswap
		vm.prank(alice);
		pools.depositSwapWithdraw( salt, weth, 10 ether, 0, block.timestamp, true );

		uint256 usedWETHFromCounterswap0 = startingDeposited - pools.depositedUserBalance( counterswapAddress, weth );
		uint256 wethThatShouldStillBeDepositedInCounterswap0 = 100 ether - usedWETHFromCounterswap0;

//		console.log( "usedWETHFromCounterswap0: ", usedWETHFromCounterswap0 );
//		console.log( "wethThatShouldStillBeDepositedInCounterswap0: ", wethThatShouldStillBeDepositedInCounterswap0 );

		// Need to roll into the next block as counterswap won't happen if a swap occurred on the same block
		vm.roll( block.number + 1 );


		// Initial stats
		startingDeposited = pools.depositedUserBalance( counterswapAddress, weth );
		(uint256 startingReserve0, uint256 startingReserve1) = pools.getPoolReserves( weth, salt );

		// Try a successful counterswap from SALT->WETH (which will happen inside of the depositSwapWithdraw transaction)
		vm.prank(alice);
		uint256 wethOut = pools.depositSwapWithdraw( salt, weth, 10 ether, 0, block.timestamp, true );


		// Determine how much of the WETH deposited into the Counterswap contract was used
		uint256 usedWETHFromCounterswap = startingDeposited - pools.depositedUserBalance( counterswapAddress, weth );
		uint256 wethThatShouldStillBeDepositedInCounterswap = wethThatShouldStillBeDepositedInCounterswap0 - usedWETHFromCounterswap;

		assertEq( usedWETHFromCounterswap, wethOut, "Incorrect usedWETHFromCounterswap" );

		// Check the updated token balances deposited into the Pools contract itself are correct
		assertEq( pools.depositedUserBalance( counterswapAddress, weth), wethThatShouldStillBeDepositedInCounterswap );

		// Counterswap should have acquire the SALT from both user trades
		assertEq( pools.depositedUserBalance( counterswapAddress, salt), 20 ether );

		// Reserves should have remained essentially the same (as the counterswap undid the user's swap within the same transaction)
		(uint256 reserve0, uint256 reserve1) = pools.getPoolReserves( weth, salt );
		assertEq( reserve0, startingReserve0, "Incorrect reserve0" );
		assertEq( reserve1, startingReserve1 + 1, "Incorrect reserve1" );
		}


	// A unit test to check that counterswap is not executed when the user's swapAmountOut is larger than the amount deposited in the Counterswap contract
	function testCounterswapWithExcessiveSwapAmount() public
		{
		_prepareCounterswap();

		// Initial stats
		uint256 startingDeposited = pools.depositedUserBalance( counterswapAddress, weth );
		vm.warp( block.timestamp + 5 minutes );

		vm.prank(alice);

		// Trade is in the correct direciton and prices should be good, but the user's amountOut is larger than what we have deposited for coutnerswap
		pools.depositSwapWithdraw( salt, weth, 200 ether, 0, block.timestamp, true );

		uint256 usedWETHFromCounterswap = startingDeposited - pools.depositedUserBalance( counterswapAddress, weth );
		assertEq( usedWETHFromCounterswap, 0, "Counterswap should not have been used for an excessively large swap" );

		assertEq( pools.depositedUserBalance( counterswapAddress, weth), startingDeposited );
		assertEq( pools.depositedUserBalance( counterswapAddress, salt), 0 );
		}
	}