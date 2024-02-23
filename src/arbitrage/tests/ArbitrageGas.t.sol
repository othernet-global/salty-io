// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "../../dev/Deployment.sol";


contract TestArbitrage is Deployment
	{
	IERC20 public tokenE;	// similar price to ETH


	constructor()
		{
		// If $COVERAGE=yes, create an instance of the contract so that coverage testing can work
		// Otherwise, what is tested is the actual deployed contract on the blockchain (as specified in Deployment.sol)
		if ( keccak256(bytes(vm.envString("COVERAGE" ))) == keccak256(bytes("yes" )))
			initializeContracts();

		grantAccessDefault();

		finalizeBootstrap();

		vm.prank(address(daoVestingWallet));
		salt.transfer(DEPLOYER, 1000000 ether);

		tokenE = new TestERC20("TEST", 18);

        vm.startPrank(address(dao));
        poolsConfig.whitelistPool(  tokenE, salt);
        poolsConfig.whitelistPool(  tokenE, weth);
        vm.stopPrank();

		vm.startPrank(DEPLOYER);
		weth.transfer(address(this), 1000000 ether);
		salt.transfer(address(this), 1000000 ether);
		vm.stopPrank();

		tokenE.approve( address(pools), type(uint256).max );
   		weth.approve( address(pools), type(uint256).max );
   		salt.approve( address(pools), type(uint256).max );

		tokenE.approve( address(liquidity), type(uint256).max );
   		weth.approve( address(liquidity), type(uint256).max );
   		salt.approve( address(liquidity), type(uint256).max );

		liquidity.depositLiquidityAndIncreaseShare( tokenE, salt, 1000 ether, 1000 ether, 0, 0, 0, block.timestamp, false );
		liquidity.depositLiquidityAndIncreaseShare( tokenE, weth, 1000 ether, 1000 ether, 0, 0, 0, block.timestamp, false );
		liquidity.depositLiquidityAndIncreaseShare( weth, salt, 1000 ether, 1000 ether, 0, 0, 0, block.timestamp, false );

		pools.deposit( tokenE, 100 ether );

		// Initial transactions cost more gas so perform the first ones here
		pools.swap( tokenE, salt, 10 ether, 0, block.timestamp );
		vm.roll(block.number + 1 );

		pools.depositSwapWithdraw( salt, tokenE, 10 ether, 0, block.timestamp );

		vm.roll(block.number + 1 );
		}


	function testGasDepositSwapWithdrawAndArbitrage() public
		{
		uint256 arbProfits = pools.depositedUserBalance(address(dao), salt);

		uint256 gas0 = gasleft();
		uint256 totalOutput = pools.depositSwapWithdraw( tokenE, salt, 100 ether, 0, block.timestamp );

		arbProfits = pools.depositedUserBalance(address(dao), salt) - arbProfits;

		console.log( "DEPOSIT/SWAP/ARB GAS: ", gas0 - gasleft() );
		console.log( "OUTPUT: ", totalOutput );
		console.log( "ARB PROFITS: ", arbProfits );
		}


	function testGasSwapAndArbitrage() public
		{
		uint256 gas0 = gasleft();
		pools.swap( tokenE, salt, 10 ether, 0, block.timestamp );
		console.log( "SWAP/ARB GAS: ", gas0 - gasleft() );
		}


	function testDepositSwapWithdrawAndArbitrage() public
		{
		uint256 amountOut = pools.depositSwapWithdraw( tokenE, weth, 10 ether, 0, block.timestamp );

//		console.log( "amountOut: ", amountOut );
//		console.log( "ending pools balance: ", pools.depositedUserBalance( address(pools), weth ) );

		assertEq( amountOut, 9900982881233894761 );
		assertEq( pools.depositedUserBalance( address(dao), salt ), 66663337341884444 );
		}
	}

