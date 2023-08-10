// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.21;

import "forge-std/Test.sol";
import "../../dev/Deployment.sol";
import "../../root_tests/TestERC20.sol";
import "../Pools.sol";
import "./TestPools.sol";


contract TestCounterswap2 is Test, Deployment
	{
	TestPools public _pools;
	ICounterswap public _counterswap;


	constructor()
		{
		_pools = new TestPools(exchangeConfig, rewardsConfig, poolsConfig);
		_pools.setDAO(dao);

		_counterswap = ICounterswap(address(_pools));
		}


	// A unit test in which a non-DAO, non-USDS contract attempts to deposit tokens. This should not be allowed, according to the requirements specified in the depositToken function.
	function testNonDAOorUSDSDeposit() public
		{
		// Attempting to deposit tokens from an address that's not the DAO or USDS contract
		IERC20 tokenA = new TestERC20(18);
		IERC20 tokenB = new TestERC20(18);

		vm.expectRevert("Counterswap.depositTokenForCounterswap only callable from the DAO or USDS contracts");
		_counterswap.depositTokenForCounterswap(tokenA, tokenB, 5 ether);
		}


	// A unit test in which the current reserve ratio is favorable compared to the averageRatio and different deposit amounts are attempted - causing shouldCounterswap to sometimes return true and sometimes return false.
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
		poolsConfig.whitelistPool(_pools, token0, token1);
		token0.approve( address(_counterswap), type(uint256).max );
		token0.approve( address(_pools), type(uint256).max );
		token1.approve( address(_pools), type(uint256).max );

		// Add liquidity and place a trade to establish an initial average ratio
		uint256 swapAmountIn = 1 ether;
		uint256 liquidityA = 5000 ether;
		_pools.addLiquidity( token0, token1, liquidityA, liquidityB, 0, block.timestamp );
		uint256 swapAmountOut = _pools.depositSwapWithdraw( token1, token0, swapAmountIn, 0, block.timestamp);

		// Deposit token0 for counterswapping to token1
		// Deposit an amount that makes the ratio for counterswapping favorable compared to the average ratio
		// when counterswapping amountToDeposit for swapAmountIn
		uint256 amountToDeposit = swapAmountOut - 10000000000000000;
        _counterswap.depositTokenForCounterswap(token0, token1, amountToDeposit);
		vm.stopPrank();

		// Check the deposited balances
		assertEq( _counterswap.depositedTokens(token0, token1), amountToDeposit );
        assertEq( _pools.depositedBalance(address(_counterswap), token0), amountToDeposit );

        // Checking shouldCounterswap when swapAmountOut is more than the deposited amount
        bool shouldCounterswapMore = _pools.shouldCounterswap(token1, token0, swapAmountIn, amountToDeposit + 100);
        assertFalse(shouldCounterswapMore, "shouldCounterswap should return false for swapAmountOut > deposit");

        // Checking shouldCounterswap when swapAmountOut is less than the deposited amount
        bool shouldCounterswapLess = _pools.shouldCounterswap(token1, token0, swapAmountIn, amountToDeposit - 100);
        assertTrue(shouldCounterswapLess, "shouldCounterswap should return true for swapAmountOut < deposit");

		// Check the deposited balances
		assertEq( _counterswap.depositedTokens(token0, token1), 100 );

        // Checking shouldCounterswap when the deposited amount has already been depleted
        bool shouldCounterswapDepleted = _pools.shouldCounterswap(token1, token0, swapAmountIn, amountToDeposit / 2);
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
		poolsConfig.whitelistPool(_pools, token0, token1);
		token0.approve( address(_counterswap), type(uint256).max );
		token0.approve( address(_pools), type(uint256).max );
		token1.approve( address(_pools), type(uint256).max );

		// Add liquidity and place a trade to establish an initial average ratio
		uint256 swapAmountIn = 1 ether;
		uint256 liquidityA = 5000 ether;
		_pools.addLiquidity( token0, token1, liquidityA, liquidityB, 0, block.timestamp );
		uint256 swapAmountOut = _pools.depositSwapWithdraw( token1, token0, swapAmountIn, 0, block.timestamp);

		// Deposit token0 for counterswapping to token1
		// Sufficient amountToDeposit will be deposited and the swapRatio will be adjusted and checked for proper behavior of shouldCounterswap.
		uint256 amountToDeposit = swapAmountOut * 2;
        _counterswap.depositTokenForCounterswap(token0, token1, amountToDeposit);
		vm.stopPrank();

        // Checking shouldCounterswap with an unfavorable swap ratio
        vm.prank(address(_pools));
        bool shouldCounterswapUnfavorable = _pools.shouldCounterswap(token1, token0, swapAmountIn, swapAmountOut + 10000000000000000);
        assertFalse(shouldCounterswapUnfavorable, "shouldCounterswap should return false with an unfavorable swapRatio");

        // Checking shouldCounterswap with an favorable swap ratio
        vm.prank(address(_pools));
        bool shouldCounterswapFavorable = _pools.shouldCounterswap(token1, token0, swapAmountIn, swapAmountOut - 10000000000000000);
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


	// A unit test to ensure that the constructor correctly initializes the _pools, exchangeConfig, usds, dao, and ZERO variables. The test should verify that these variables are correctly set after the contract is deployed.
	function test_constructor_initializes_variables() public {
    	Counterswap counterswapInstance = new Counterswap(_pools, exchangeConfig);

    	assertEq(address(counterswapInstance.pools()), address(_pools), "Pools address does not match");
    	assertEq(address(counterswapInstance.usds()), address(exchangeConfig.usds()), "USDS address does not match");

    	bytes16 zeroValue = ABDKMathQuad.fromUInt(0);
    	assertEq(ABDKMathQuad.cmp(counterswapInstance.ZERO(), zeroValue), 0, "ZERO value does not match");
    }


	// A unit test to verify that the constructor fails when the _pools or _exchangeConfig parameters are zero addresses. This should fail according to the requirements specified in the constructor.
	function testConstructorFailsWithZeroAddresses() public {
    	IPools zeroPools = IPools(address(0));
    	IExchangeConfig zeroExchangeConfig = IExchangeConfig(address(0));

    	// Test failure when _pools is the zero address
    	vm.expectRevert("_pools cannot be address(0)");
    	new Counterswap(zeroPools, exchangeConfig);

    	// Test failure when _exchangeConfig is the zero address
    	vm.expectRevert("_exchangeConfig cannot be address(0)");
    	new Counterswap(_pools, zeroExchangeConfig);
    }


	// A unit test to verify that the depositToken function correctly transfers the tokens from the caller to the contract, deposits them into the Pools contract, and updates the _depositedTokens mapping.
	function testDepositToken() public {
        // Creating new ERC20 tokens
        IERC20 tokenToDeposit = new TestERC20(18);
        IERC20 desiredToken = new TestERC20(18);

        // Initial setup for transferring and approving tokens
        uint256 amountToDeposit = 5 ether;
        tokenToDeposit.transfer(address(dao), amountToDeposit);
        vm.startPrank(address(dao));
        tokenToDeposit.approve(address(_counterswap), amountToDeposit);

        // Check the initial balance of the Pools contract
        uint256 initialPoolBalance = _pools.depositedBalance(address(_counterswap), tokenToDeposit);
        assertEq(initialPoolBalance, 0);

        // Check the initial _depositedTokens mapping
        assertEq(_counterswap.depositedTokens(tokenToDeposit, desiredToken), 0);

        // Perform the depositToken operation
        _counterswap.depositTokenForCounterswap(tokenToDeposit, desiredToken, amountToDeposit);

        // Check the updated balance of the Pools contract
        uint256 updatedPoolBalance = _pools.depositedBalance(address(_counterswap), tokenToDeposit);
        assertEq(updatedPoolBalance, amountToDeposit);

        // Check the updated _depositedTokens mapping
        assertEq(_counterswap.depositedTokens(tokenToDeposit, desiredToken), amountToDeposit);

        vm.stopPrank();
    }


	// A unit test to verify that the withdrawToken function fails when called by an address other than the DAO or USDS contracts.
    function testWithdrawTokenPermission() public {
    	IERC20 tokenToWithdraw = new TestERC20(18);
    	uint256 amountToWithdraw = 5 ether;

    	// Attempting to withdraw tokens from an address that's not the DAO or USDS contract
    	vm.expectRevert("Counterswap.withdrawTokenFromCounterswap only callable from the DAO or USDS contracts");
    	_counterswap.withdrawTokenFromCounterswap(tokenToWithdraw, amountToWithdraw);
    }


	// A unit test to verify that the withdrawToken function correctly withdraws tokens from the Pools contract and transfers them to the caller.
	function testWithdrawToken() public {
    	uint256 amountToDeposit = 5 ether;
    	uint256 amountToWithdraw = 3 ether;

    	IERC20 tokenToWithdraw = new TestERC20(18);
    	tokenToWithdraw.transfer( address(_counterswap), amountToDeposit);

		// Have counterswap deposit into _pools to mimic counterswaps resulting in tokens
		vm.startPrank(address(_counterswap));
		tokenToWithdraw.approve( address(_pools), amountToDeposit );
		_pools.deposit( tokenToWithdraw, amountToDeposit);

    	// Check the deposited balance before withdrawal
    	assertEq(_pools.depositedBalance( address(_counterswap), tokenToWithdraw), amountToDeposit);
    	vm.stopPrank();

    	// Withdraw tokens
    	vm.prank(address(dao));
    	_counterswap.withdrawTokenFromCounterswap(tokenToWithdraw, amountToWithdraw);

    	// Verify that the tokens have been withdrawn from the Pools contract
    	assertEq(_pools.depositedBalance( address(_counterswap), tokenToWithdraw), amountToDeposit - amountToWithdraw);

    	// Verify that the tokens have been transferred to the caller
    	assertEq(tokenToWithdraw.balanceOf(address(dao)), amountToWithdraw);
    }


	// A unit test in which the shouldCounterswap function is called with an average ratio of zero, ensuring it returns false.
	function testShouldCounterswapWithZeroAverageRatio() public {
        // Define some arbitrary ERC20 tokens
        IERC20 tokenA = new TestERC20(18);
        IERC20 tokenB = new TestERC20(18);

        // Transfer and approve tokens to manipulate balances
        tokenA.transfer(address(dao), 100000 ether);
        tokenB.transfer(address(dao), 100000 ether);

        // Prank the DAO and set up the environment
        vm.startPrank(address(dao));
        poolsConfig.whitelistPool(_pools, tokenA, tokenB);
        tokenA.approve(address(_counterswap), type(uint256).max);
        tokenA.approve(address(_pools), type(uint256).max);
        tokenB.approve(address(_pools), type(uint256).max);

        // Add liquidity to the pool, but do not place a trade to keep average ratio at zero
        uint256 liquidityA = 5000 ether;
        uint256 liquidityB = 1000 ether;
        _pools.addLiquidity(tokenA, tokenB, liquidityA, liquidityB, 0, block.timestamp);

        // Attempt to call shouldCounterswap with arbitrary values; it should return false due to average ratio being zero
        uint256 swapAmountIn = 1 ether;
        uint256 swapAmountOut = 1 ether; // arbitrary as it doesn't affect the outcome
        vm.stopPrank();

		vm.prank( address(_pools) );
        bool shouldCounterswapResult = _pools.shouldCounterswap(tokenA, tokenB, swapAmountIn, swapAmountOut);
        assertFalse(shouldCounterswapResult, "shouldCounterswap should return false with zero average ratio");

    }

    }


