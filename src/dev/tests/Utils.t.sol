// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "../../dev/Deployment.sol";
import "../../dev/Utils.sol";


contract TestUtils is Deployment
	{
    bytes32[] public poolIDs;
    bytes32 public pool1;
    bytes32 public pool2;

    IERC20 public token1;
    IERC20 public token2;
    IERC20 public token3;

    address public constant alice = address(0x1111);
    address public constant bob = address(0x2222);
    address public constant charlie = address(0x3333);


    function setUp() public
    	{
		initializeContracts();

		grantAccessAlice();
		grantAccessBob();
		grantAccessCharlie();
		grantAccessDeployer();
		grantAccessDefault();

		finalizeBootstrap();

		vm.prank(address(daoVestingWallet));
		salt.transfer(DEPLOYER, 1000000 ether);

    	token1 = new TestERC20("TEST", 18);
		token2 = new TestERC20("TEST", 18);
		token3 = new TestERC20("TEST", 18);

        pool1 = PoolUtils._poolID(token1, token2);
        pool2 = PoolUtils._poolID(token2, token3);

        poolIDs = new bytes32[](2);
        poolIDs[0] = pool1;
        poolIDs[1] = pool2;

        // Whitelist the _pools
		vm.startPrank( address(dao) );
        poolsConfig.whitelistPool( pools,   token1, token2);
        poolsConfig.whitelistPool( pools,   token2, token3);
        vm.stopPrank();

		vm.prank(DEPLOYER);
		salt.transfer( address(this), 100000 ether );


        salt.approve(address(collateralAndLiquidity), type(uint256).max);

        // Alice gets some salt and pool lps and approves max to staking
        token1.transfer(alice, 1000 ether);
        token2.transfer(alice, 1000 ether);
        token3.transfer(alice, 1000 ether);
        vm.startPrank(alice);
        token1.approve(address(collateralAndLiquidity), type(uint256).max);
        token2.approve(address(collateralAndLiquidity), type(uint256).max);
        token3.approve(address(collateralAndLiquidity), type(uint256).max);
		vm.stopPrank();

        // Bob gets some salt and pool lps and approves max to staking
        token1.transfer(bob, 1000 ether);
        token2.transfer(bob, 1000 ether);
        token3.transfer(bob, 1000 ether);
        vm.startPrank(bob);
        token1.approve(address(collateralAndLiquidity), type(uint256).max);
        token2.approve(address(collateralAndLiquidity), type(uint256).max);
        token3.approve(address(collateralAndLiquidity), type(uint256).max);
		vm.stopPrank();


        // Charlie gets some salt and pool lps and approves max to staking
        token1.transfer(charlie, 1000 ether);
        token2.transfer(charlie, 1000 ether);
        token3.transfer(charlie, 1000 ether);
        vm.startPrank(charlie);
        token1.approve(address(collateralAndLiquidity), type(uint256).max);
        token2.approve(address(collateralAndLiquidity), type(uint256).max);
        token3.approve(address(collateralAndLiquidity), type(uint256).max);
		vm.stopPrank();


        // DAO gets some salt and pool lps and approves max to staking
        token1.transfer(address(dao), 1000 ether);
        token2.transfer(address(dao), 1000 ether);
        token3.transfer(address(dao), 1000 ether);
        vm.startPrank(address(dao));
        token1.approve(address(collateralAndLiquidity), type(uint256).max);
        token2.approve(address(collateralAndLiquidity), type(uint256).max);
        token3.approve(address(collateralAndLiquidity), type(uint256).max);
		vm.stopPrank();
    	}


	function testAddLiquidityEstimate1() public {

		vm.startPrank(alice);

		token1.approve( address(pools), type(uint256).max );

		collateralAndLiquidity.depositLiquidityAndIncreaseShare( token1, token2, 100 ether, 200 ether, 0 ether, block.timestamp, false );
		pools.depositSwapWithdraw( token1, token2, 50 ether, 0, block.timestamp );

//		console.log( "INITIAL LIQUIDITY: ", collateralAndLiquidity.totalShares( PoolUtils._poolID( token1, token2 ) ) );

		vm.warp( block.timestamp + 1 hours );


		Utils utils = new Utils();

		uint256 addAmount1 = 0;
		uint256 addAmount2 = 30 ether;

	 	// Determine how much needs to be automatically swapped before the liquidity is added
		(uint256 reserves1, uint256 reserves2) = pools.getPoolReserves(token1, token2);
		(uint256 swapAmount1,uint256 swapAmount2 ) = utils.determineZapSwapAmount( reserves1, reserves2, addAmount1, addAmount2 );

		IERC20[] memory swapPath = new IERC20[](2);

		uint256 estimate;

	 	if ( swapAmount1 > 0 )
	 		{
			swapPath[0] = token1;
			swapPath[1] = token2;

	 		uint256 amountOut = utils.quoteAmountOut( pools, swapPath, swapAmount1 );
//	 		console.log( "AMOUNT OUT 1->2: ",  amountOut );

	 		addAmount1 = addAmount1 - swapAmount1;
	 		addAmount2 = addAmount2 + amountOut;

//			console.log( "ESTIMATED ZAPPED AMOUNTS: ", addAmount1, addAmount2 );
			estimate = utils.estimateAddedLiquidity(reserves1 + swapAmount1, reserves2 - amountOut, addAmount1, addAmount2, collateralAndLiquidity.totalShares( PoolUtils._poolID( token1, token2 ) ));
//			console.log( "ES: ", estimate );
	 		}

	 	if ( swapAmount2 > 0 )
	 		{
			swapPath[0] = token2;
			swapPath[1] = token1;

	 		uint256 amountOut = utils.quoteAmountOut( pools, swapPath, swapAmount2 );
//	 		console.log( "AMOUNT OUT 2->1: ",  amountOut );

	 		addAmount1 = addAmount1 + amountOut;
	 		addAmount2 = addAmount2 - swapAmount2;

//			console.log( "ESTIMATED ZAPPED AMOUNTS: ", addAmount1, addAmount2 );
			estimate = utils.estimateAddedLiquidity(reserves1 - amountOut, reserves2 + swapAmount2, addAmount1, addAmount2, collateralAndLiquidity.totalShares( PoolUtils._poolID( token1, token2 ) ));
//			console.log( "ES: ", estimate );
	 		}

		(,, uint256 addedLiquidity) = collateralAndLiquidity.depositLiquidityAndIncreaseShare( token1, token2, 0, 30 ether, 0, block.timestamp, true );
//		console.log( "AD: ", addedLiquidity );

		assertEq( estimate / 10, addedLiquidity / 10 );

//		(,, addedLiquidity) = collateralAndLiquidity.depositLiquidityAndIncreaseShare( token1, token2, 30 ether, 0 ether, 0 ether, block.timestamp, true );
	    }




	function testAddLiquidityEstimate2() public {

		vm.startPrank(alice);

		token1.approve( address(pools), type(uint256).max );

		collateralAndLiquidity.depositLiquidityAndIncreaseShare( token1, token2, 100 ether, 200 ether, 0 ether, block.timestamp, false );
		pools.depositSwapWithdraw( token1, token2, 50 ether, 0, block.timestamp );

//		console.log( "INITIAL LIQUIDITY: ", collateralAndLiquidity.totalShares( PoolUtils._poolID( token1, token2 ) ) );

		vm.warp( block.timestamp + 1 hours );


		Utils utils = new Utils();

		uint256 addAmount1 = 30 ether;
		uint256 addAmount2 = 0;

	 	// Determine how much needs to be automatically swapped before the liquidity is added
		(uint256 reserves1, uint256 reserves2) = pools.getPoolReserves(token1, token2);
		(uint256 swapAmount1,uint256 swapAmount2 ) = utils.determineZapSwapAmount( reserves1, reserves2, addAmount1, addAmount2 );

		IERC20[] memory swapPath = new IERC20[](2);

		uint256 estimate;

	 	if ( swapAmount1 > 0 )
	 		{
			swapPath[0] = token1;
			swapPath[1] = token2;

	 		uint256 amountOut = utils.quoteAmountOut( pools, swapPath, swapAmount1 );
//	 		console.log( "AMOUNT OUT 1->2: ",  amountOut );

	 		addAmount1 = addAmount1 - swapAmount1;
	 		addAmount2 = addAmount2 + amountOut;

//			console.log( "ESTIMATED ZAPPED AMOUNTS: ", addAmount1, addAmount2 );
			estimate = utils.estimateAddedLiquidity(reserves1 + swapAmount1, reserves2 - amountOut, addAmount1, addAmount2, collateralAndLiquidity.totalShares( PoolUtils._poolID( token1, token2 ) ));
//			console.log( "ES: ", estimate );
	 		}

	 	if ( swapAmount2 > 0 )
	 		{
			swapPath[0] = token2;
			swapPath[1] = token1;

	 		uint256 amountOut = utils.quoteAmountOut( pools, swapPath, swapAmount2 );
//	 		console.log( "AMOUNT OUT 2->1: ",  amountOut );

	 		addAmount1 = addAmount1 + amountOut;
	 		addAmount2 = addAmount2 - swapAmount2;

//			console.log( "ESTIMATED ZAPPED AMOUNTS: ", addAmount1, addAmount2 );
			estimate = utils.estimateAddedLiquidity(reserves1 - amountOut, reserves2 + swapAmount2, addAmount1, addAmount2, collateralAndLiquidity.totalShares( PoolUtils._poolID( token1, token2 ) ));
//			console.log( "ES: ", estimate );
	 		}

		(,, uint256 addedLiquidity) = collateralAndLiquidity.depositLiquidityAndIncreaseShare( token1, token2, 30 ether, 0, 0, block.timestamp, true );
//		console.log( "AD: ", addedLiquidity );

		assertEq( estimate / 10, addedLiquidity / 10 );

//		(,, addedLiquidity) = collateralAndLiquidity.depositLiquidityAndIncreaseShare( token1, token2, 30 ether, 0 ether, 0 ether, block.timestamp, true );
	    }
	}
