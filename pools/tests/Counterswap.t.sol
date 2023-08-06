// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.21;

import "forge-std/Test.sol";
import "../../dev/Deployment.sol";
import "../../root_tests/TestERC20.sol";
import "../Counterswap.sol";


contract TestCounterswap is Test, Deployment
	{
	constructor()
		{
		// If $COVERAGE=yes, create an instance of the contract so that coverage testing can work
		// Otherwise, what is tested is the actual deployed contract on the blockchain (as specified in Deployment.sol)
		if ( keccak256(bytes(vm.envString("COVERAGE" ))) == keccak256(bytes("yes" )))
			{
			vm.prank(DEPLOYER);
			counterswap = new Counterswap(pools, exchangeConfig );

			vm.prank(address(dao));
			poolsConfig.setCounterswap(counterswap);
			}
		}


	// A unit test in which a non-DAO, non-USDS contract attempts to deposit tokens. This should not be allowed, according to the requirements specified in the depositToken function.
	function testNonDAOorUSDSDeposit() public
		{
		// Attempting to deposit tokens from an address that's not the DAO or USDS contract
		IERC20 tokenA = new TestERC20(18);
		IERC20 tokenB = new TestERC20(18);

		vm.expectRevert("Only callable from the DAO or USDS contracts");
		counterswap.depositToken(tokenA, tokenB, 5 ether);
		}


	// A unit test in which the current reserve ratio is favorable to compared to the averageRatio and different deposit amounts are attempted - causing shouldCounterswap to sometimes return true and sometimes return false.
	function _testChangeCounterswapAmounts( IERC20 token0, IERC20 token1, uint256 liquidityB) public {

		if ( address(token0) == address(0))
			return;
		if ( address(token1) == address(0))
			return;
		if ( address(token0) == address(token1))
			return;

		token0.transfer( address(dao), 100000 ether);
		token1.transfer( address(dao), 100000 ether);

        vm.startPrank(address(dao));
		poolsConfig.whitelistPool(token0, token1);
		token0.approve( address(counterswap), type(uint256).max );
		token0.approve( address(pools), type(uint256).max );
		token1.approve( address(pools), type(uint256).max );

		// Add liquidity and place a trade to establish an initial average ratio
		uint256 swapAmountIn = 1 ether;
		uint256 liquidityA = 5000 ether;
		pools.addLiquidity( token0, token1, liquidityA, liquidityB, 0, block.timestamp );
		uint256 swapAmountOut = pools.depositSwapWithdraw( token1, token0, swapAmountIn, 0, block.timestamp);

		// Deposit token0 for counterswapping to token1
		// Deposit an amount that makes the ratio for counterswapping favorable compared to the average ratio
		// when counterswapping amountToDeposit for swapAmountIn
		uint256 amountToDeposit = swapAmountOut - 10000000000000000;
        counterswap.depositToken(token0, token1, amountToDeposit);
		vm.stopPrank();

		// Check the deposited balances
		assertEq( counterswap.depositedTokens(token0, token1), amountToDeposit );
        assertEq( token0.balanceOf( address(counterswap)), 0 );
        assertEq( pools.depositBalance(address(counterswap), token0), amountToDeposit );

        // Checking shouldCounterswap when swapAmountOut is more than the deposited amount
        vm.prank(address(pools));
        bool shouldCounterswapMore = counterswap.shouldCounterswap(token1, token0, swapAmountIn, amountToDeposit + 100);
        assertFalse(shouldCounterswapMore, "shouldCounterswap should return false for swapAmountOut > deposit");

        // Checking shouldCounterswap when swapAmountOut is less than the deposited amount
        vm.prank(address(pools));
        bool shouldCounterswapLess = counterswap.shouldCounterswap(token1, token0, swapAmountIn, amountToDeposit - 100);
        assertTrue(shouldCounterswapLess, "shouldCounterswap should return true for swapAmountOut < deposit");

		// Check the deposited balances
		assertEq( counterswap.depositedTokens(token0, token1), 100 );
        assertEq( token0.balanceOf( address(counterswap)), 0 );

        // Checking shouldCounterswap when the deposited amount has already been depleted
        vm.prank(address(pools));
        bool shouldCounterswapDepleted = counterswap.shouldCounterswap(token1, token0, swapAmountIn, amountToDeposit / 2);
        assertFalse(shouldCounterswapDepleted, "shouldCounterswap should return false when the deposited tokens have been depleted");
    }


	// A unit test in which a token is deposited and then a shouldCounterswap check is made with the deposited and desired token, where the swapAmountOut is more than, less than, and equal to the deposited amount. The test should verify that shouldCounterswap correctly returns true or false based on the recent average ratio and the swap ratio, and that the _depositedTokens mapping is correctly updated.
	function testChangeCounterswapAmounts() public
		{
		// Try multiple times to get the Pools token order to flipped around sometimes
		for( uint256 i = 1; i <= 10; i++ )
			{
			IERC20 tokenA = new TestERC20(18);
			IERC20 tokenB = new TestERC20(18);

			_testChangeCounterswapAmounts(tokenA, tokenB, i * 1000 ether);
			}
		}




	// A unit test in which the current reserve ratio is favorable to compared to the averageRatio and different deposit amounts are attempted - causing shouldCounterswap to sometimes return true and sometimes return false.
	function _testSwapRatios( IERC20 token0, IERC20 token1, uint256 liquidityB) public {

		if ( address(token0) == address(0))
			return;
		if ( address(token1) == address(0))
			return;
		if ( address(token0) == address(token1))
			return;

		token0.transfer( address(dao), 100000 ether);
		token1.transfer( address(dao), 100000 ether);

        vm.startPrank(address(dao));
		poolsConfig.whitelistPool(token0, token1);
		token0.approve( address(counterswap), type(uint256).max );
		token0.approve( address(pools), type(uint256).max );
		token1.approve( address(pools), type(uint256).max );

		// Add liquidity and place a trade to establish an initial average ratio
		uint256 swapAmountIn = 1 ether;
		uint256 liquidityA = 5000 ether;
		pools.addLiquidity( token0, token1, liquidityA, liquidityB, 0, block.timestamp );
		uint256 swapAmountOut = pools.depositSwapWithdraw( token1, token0, swapAmountIn, 0, block.timestamp);

		// Deposit token0 for counterswapping to token1
		// Sufficient amountToDeposit will be deposited and the swapRatio will be adjusted and checked for proper behavior of shouldCounterswap.
		uint256 amountToDeposit = swapAmountOut * 2;
        counterswap.depositToken(token0, token1, amountToDeposit);
		vm.stopPrank();

        // Checking shouldCounterswap with an unfavorable swap ratio
        vm.prank(address(pools));
        bool shouldCounterswapUnfavorable = counterswap.shouldCounterswap(token1, token0, swapAmountIn, swapAmountOut + 10000000000000000);
        assertFalse(shouldCounterswapUnfavorable, "shouldCounterswap should return false with an unfavorable swapRatio");

        // Checking shouldCounterswap with an favorable swap ratio
        vm.prank(address(pools));
        bool shouldCounterswapFavorable = counterswap.shouldCounterswap(token1, token0, swapAmountIn, swapAmountOut - 10000000000000000);
        assertTrue(shouldCounterswapFavorable, "shouldCounterswap should return true with a favorable swap ratio");
    }


	// A unit test in which shouldCounterswap is tested with swapRatios larger and smaller than the current average reserve ratio
	function testSwapRatios() public
		{
		// Try multiple times to get the Pools token order to flipped around sometimes
		for( uint256 i = 1; i <= 10; i++ )
			{
			IERC20 tokenA = new TestERC20(18);
			IERC20 tokenB = new TestERC20(18);

			_testSwapRatios(tokenA, tokenB, i * 1000 ether);
			}
		}


	// A unit test to ensure that the constructor correctly initializes the pools, exchangeConfig, usds, dao, and ZERO variables. The test should verify that these variables are correctly set after the contract is deployed.
	function test_constructor_initializes_variables() public {
    	Counterswap counterswapInstance = new Counterswap(pools, exchangeConfig);

    	assertEq(address(counterswapInstance.pools()), address(pools), "Pools address does not match");
    	assertEq(address(counterswapInstance.exchangeConfig()), address(exchangeConfig), "ExchangeConfig address does not match");
    	assertEq(address(counterswapInstance.usds()), address(exchangeConfig.usds()), "USDS address does not match");
    	assertEq(address(counterswapInstance.dao()), address(exchangeConfig.dao()), "DAO address does not match");

    	bytes16 zeroValue = ABDKMathQuad.fromUInt(0);
    	assertEq(ABDKMathQuad.cmp(counterswapInstance.ZERO(), zeroValue), 0, "ZERO value does not match");
    }


	// A unit test to verify that the constructor fails when the _pools or _exchangeConfig parameters are zero addresses. This should fail according to the requirements specified in the constructor.
	function testConstructorFailsWithZeroAddresses() public {
    	IPools zeroPools = IPools(address(0));
    	IExchangeConfig validExchangeConfig = exchangeConfig; // Assume this is a valid exchange config instance

    	// Test failure when _pools is the zero address
    	vm.expectRevert("_pools cannot be address(0)");
    	new Counterswap(zeroPools, validExchangeConfig);

    	IPools validPools = pools; // Assume this is a valid pools instance
    	IExchangeConfig zeroExchangeConfig = IExchangeConfig(address(0));

    	// Test failure when _exchangeConfig is the zero address
    	vm.expectRevert("_exchangeConfig cannot be address(0)");
    	new Counterswap(validPools, zeroExchangeConfig);
    }
    }


