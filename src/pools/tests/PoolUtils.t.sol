// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "../../dev/Deployment.sol";
import "../PoolUtils.sol";


contract TestPoolUtils is Deployment
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


    // A unit test to test _placeInternalSwap limits swapAmountIn based on the reserves
    function testPlaceInternalSwap() public
    	{
       	IERC20 token0 = new TestERC20("TEST", 18);
       	IERC20 token1 = new TestERC20("TEST", 18);

		vm.prank(address(dao));
		poolsConfig.whitelistPool( pools,   token0, token1);

		// Approvals for adding liquidity
		token0.approve(address(collateralAndLiquidity),type(uint256).max);
		token1.approve(address(collateralAndLiquidity),type(uint256).max);
		token0.approve(address(pools),type(uint256).max);

		collateralAndLiquidity.depositLiquidityAndIncreaseShare( token0, token1, 1000 ether, 1000 ether, 0, block.timestamp, false );

		(uint256 swapAmountIn, uint256 swapAmountOut) = PoolUtils._placeInternalSwap( pools, token0, token1, 100 ether, 1000 );

//		console.log( "swapAmountIn: ", swapAmountIn );
//		console.log( "swapAmountOut: ", swapAmountOut );
		assertEq(swapAmountIn, 10000000000000000000 );
		assertEq(swapAmountOut, 9900990099009900990 );
    	}


    // A unit test to test _placeInternalSwap that is small enough to not be limited by the reserves
    function testPlaceSmallInternalSwap() public
    	{
       	IERC20 token0 = new TestERC20("TEST", 18);
       	IERC20 token1 = new TestERC20("TEST", 18);

		vm.prank(address(dao));
		poolsConfig.whitelistPool( pools,   token0, token1);

		// Approvals for adding liquidity
		token0.approve(address(collateralAndLiquidity),type(uint256).max);
		token1.approve(address(collateralAndLiquidity),type(uint256).max);
		token0.approve(address(pools),type(uint256).max);

		collateralAndLiquidity.depositLiquidityAndIncreaseShare( token0, token1, 1000 ether, 1000 ether, 0, block.timestamp, false );

		(uint256 swapAmountIn, uint256 swapAmountOut) = PoolUtils._placeInternalSwap( pools, token0, token1, 1 ether, 1000 );

//		console.log( "swapAmountIn: ", swapAmountIn );
//		console.log( "swapAmountOut: ", swapAmountOut );
		assertEq(swapAmountIn, 1000000000000000000 );
		assertEq(swapAmountOut, 999000999000999000 );
    	}
	}