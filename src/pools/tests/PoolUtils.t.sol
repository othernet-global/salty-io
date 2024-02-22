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
		salt.transfer(address(liquidity), 1000000 ether);
		vm.stopPrank();

		vm.startPrank( DEPLOYER );
		for( uint256 i = 0; i < 10; i++ )
			{
			tokens[i] = new TestERC20("TEST", 18);
        	tokens[i].approve( address(pools), type(uint256).max );
        	tokens[i].approve( address(liquidity), type(uint256).max );

        	tokens[i].transfer(address(this), 100000 ether );
        	tokens[i].transfer(address(dao), 100000 ether );
        	tokens[i].transfer(address(liquidity), 100000 ether );
			}
		vm.stopPrank();

		for( uint256 i = 0; i < 9; i++ )
			{
			vm.prank(address(dao));
			poolsConfig.whitelistPool( pools,    tokens[i], tokens[i + 1] );

			vm.prank(DEPLOYER);
			liquidity.depositLiquidityAndIncreaseShare( tokens[i], tokens[i + 1], 500 ether, 500 ether, 0, 0, 0, block.timestamp, false );
			}

		vm.prank(address(dao));
		poolsConfig.whitelistPool( pools,    tokens[5], tokens[7] );
		vm.prank(address(dao));
		poolsConfig.whitelistPool( pools,    tokens[0], tokens[9] );

		vm.startPrank( DEPLOYER );
		liquidity.depositLiquidityAndIncreaseShare( tokens[5], tokens[7], 1000 ether, 1000 ether, 0, 0, 0, block.timestamp, false );

		pools.deposit( tokens[5], 1000 ether );
		pools.deposit( tokens[6], 1000 ether );
		pools.deposit( tokens[7], 1000 ether );
		pools.deposit( tokens[8], 1000 ether );

		liquidity.depositLiquidityAndIncreaseShare( tokens[0], tokens[9], 1000000000 ether, 2000000000 ether, 0, 0, 0, block.timestamp, false );
		vm.stopPrank();

		for( uint256 i = 0; i < 10; i++ )
			{
        	tokens[i].approve( address(pools), type(uint256).max );
        	tokens[i].approve( address(liquidity), type(uint256).max );
        	}

		for( uint256 i = 0; i < 9; i++ )
			{
			pools.deposit( tokens[i], 1000 ether );
			liquidity.depositLiquidityAndIncreaseShare( tokens[i], tokens[i + 1], 500 ether, 500 ether, 0, 0, 0, block.timestamp, false );
        	}

		vm.startPrank(address(liquidity));
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
	}