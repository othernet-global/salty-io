// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.21;

import "forge-std/Test.sol";
import "../../root_tests/TestERC20.sol";
import "../Pools.sol";
import "../../dev/Deployment.sol";
import "../PoolUtils.sol";
import "../Counterswap.sol";


contract TestPoolsAndCounterswap is Test, Deployment
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
			{
			vm.prank(DEPLOYER);
			pools = new Pools(exchangeConfig, poolsConfig);
			pools.setDAO(dao);

			counterswap = new Counterswap(pools, exchangeConfig );
			vm.prank(address(dao));
			poolsConfig.setCounterswap(counterswap);
			}
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

		salt.transfer(alice, 1000 ether);
		weth.transfer(alice, 1000 ether);

		pools.addLiquidity( salt, weth, 1000 ether, 2000 ether, 0, block.timestamp);
		vm.stopPrank();

		vm.startPrank(alice);
		salt.approve( address(pools), type(uint256).max );
		weth.approve( address(pools), type(uint256).max );
		vm.stopPrank();
		}


	function _prepareCounterswap() internal
		{
		// Establish the average price in PoolStats by placing a normal swap
		vm.startPrank(alice);
		pools.depositSwapWithdraw( salt, weth, 10 ether, 0, block.timestamp );
		vm.warp( block.timestamp + 5 minutes );
		vm.stopPrank();

		// Deposit into counterswap indicated the protocol's intention to place a weth->salt trade
		vm.startPrank(address(dao));
		weth.approve( address(counterswap), 10000 ether);
		counterswap.depositToken(weth, salt, 100 ether);
		vm.stopPrank();
		}


	// A unit test to check that counterswap behaves as expected with whitelisted pairs.
	function testSuccessfulCounterswap() public
		{
		_prepareCounterswap();

		// Initial stats
		uint256 startingDeposited = counterswap.depositedTokens(weth, salt);
		(uint256 startingReserve0, uint256 startingReserve1) = pools.getPoolReserves( weth, salt );

		// Try a successful counterswap from SALT->WETH
		vm.prank(alice);
		uint256 wethOut = pools.depositSwapWithdraw( salt, weth, 10 ether, 0, block.timestamp );

		// Determine how much of the WETH deposited into the Counterswap contract was used
		uint256 usedWETHFromCounterswap = startingDeposited - counterswap.depositedTokens(weth, salt);
		uint256 wethThatShouldStillBeDepositedInCounterswap = 100 ether - usedWETHFromCounterswap;

		assertEq( usedWETHFromCounterswap, wethOut, "Incorrect usedWETHFromCounterswap" );
		assertEq( counterswap.depositedTokens(weth, salt), wethThatShouldStillBeDepositedInCounterswap );

		// Check the updated token balances deposited into the Pools contract itself are correct
		assertEq( pools.depositBalance( address(counterswap), weth), wethThatShouldStillBeDepositedInCounterswap );

		// Counterswap should have acquire the SALT from the user's trade
		assertEq( pools.depositBalance( address(counterswap), salt), 10 ether );

		// Reserves should have remained essentially the same (as the counterswap undid the user's swap within the same transaction)
		(uint256 reserve0, uint256 reserve1) = pools.getPoolReserves( weth, salt );
		assertEq( reserve0, startingReserve0, "Incorrect reserve0" );
		assertEq( reserve1, startingReserve1 - 1, "Incorrect reserve1" );
		}


	// A unit test to check that counterswap is not executed when the current prices of the tokens are not favorable compared to the recent average ratio fo the two tokens.
	function testCounterswapWithUnfavorablePrice() public
		{
		_prepareCounterswap();

		// Initial stats
		uint256 startingDeposited = counterswap.depositedTokens(weth, salt);

		// Try with prices that are not favorable compared to the recent average
		vm.warp( block.timestamp + 5 minutes );

		vm.prank(alice);
		// Trading in the same direction as the counterswap we want to perform is not good for the exchange rate for the intended swap
		pools.depositSwapWithdraw( weth, salt, 100 ether, 0, block.timestamp );

		startingDeposited = counterswap.depositedTokens(weth, salt);
		vm.warp( block.timestamp + 5 minutes );

		vm.prank(alice);
		pools.depositSwapWithdraw( salt, weth, 200 ether, 0, block.timestamp );

		uint256 usedWETHFromCounterswap = startingDeposited - counterswap.depositedTokens(weth, salt);
		assertEq( usedWETHFromCounterswap, 0, "Counterswap should not have been used when token prices are not favorable" );
		assertEq( pools.depositBalance( address(counterswap), weth), startingDeposited );
		assertEq( pools.depositBalance( address(counterswap), salt), 0 );
		}


	// A unit test to check that counterswap is not executed when the user's swapAmountOut is larger than the amount deposited in the Counterswap contract
	function testCounterswapWithExcessiveSwapAmount() public
		{
		_prepareCounterswap();

		// Initial stats
		uint256 startingDeposited = counterswap.depositedTokens(weth, salt);

		// Try with excessively large swapOutput which will exceed the deposited amount
		startingDeposited = counterswap.depositedTokens(weth, salt);
		vm.warp( block.timestamp + 5 minutes );

		vm.prank(alice);

		// Trade is in the correct direciton and prices should be good, but the user's amountOut is larger than what we have deposited
		pools.depositSwapWithdraw( salt, weth, 200 ether, 0, block.timestamp );

		uint256 usedWETHFromCounterswap = startingDeposited - counterswap.depositedTokens(weth, salt);
		assertEq( usedWETHFromCounterswap, 0, "Counterswap should not have been used for an excessively large swap" );

		assertEq( pools.depositBalance( address(counterswap), weth), startingDeposited );
		assertEq( pools.depositBalance( address(counterswap), salt), 0 );
		}
	}