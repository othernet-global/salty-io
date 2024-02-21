// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "../../dev/Deployment.sol";


contract TestArbitrage is Deployment
	{
	IERC20 public tokenE;	// similar price to ETH
    IERC20 public tokenB; // similar price to BTC


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

		uint256 priceBTC = priceAggregator.getPriceBTC();
		uint256 priceETH = priceAggregator.getPriceETH();

		tokenE = new TestERC20("TEST", 18);
        tokenB = new TestERC20("TEST", 18);

        vm.startPrank(address(dao));
        poolsConfig.whitelistPool( pools,   tokenE, wbtc);
        poolsConfig.whitelistPool( pools,   tokenE, weth);
        poolsConfig.whitelistPool( pools,   tokenB, wbtc);
        poolsConfig.whitelistPool( pools,   tokenB, weth);
        vm.stopPrank();

		vm.startPrank(DEPLOYER);
		wbtc.transfer(address(this), 1000000 *10**8);
		weth.transfer(address(this), 1000000 ether);
		weth.transfer(address(this), 1000000 ether);
		vm.stopPrank();

		tokenE.approve( address(pools), type(uint256).max );
   		wbtc.approve( address(pools), type(uint256).max );
   		weth.approve( address(pools), type(uint256).max );

		tokenE.approve( address(liquidity), type(uint256).max );
   		wbtc.approve( address(liquidity), type(uint256).max );
   		weth.approve( address(liquidity), type(uint256).max );

		liquidity.depositLiquidityAndIncreaseShare( tokenE, wbtc, 100 ether * priceBTC / priceETH, 100 *10**8, 0, 0, 0, block.timestamp, false );
		liquidity.depositLiquidityAndIncreaseShare( tokenE, weth, 1000 ether, 1000 ether, 0, 0, 0, block.timestamp, false );
		liquidity.depositLiquidityAndIncreaseShare( wbtc, weth, 1000 *10**8, 1000 ether * priceBTC / priceETH, 0, 0, 0, block.timestamp, false );

		pools.deposit( tokenE, 100 ether );

		// Initial transactions cost more gas so perform the first ones here
		pools.swap( tokenE, weth, 10 ether, 0, block.timestamp );
		vm.roll(block.number + 1 );

		pools.depositSwapWithdraw( weth, tokenE, 10 ether, 0, block.timestamp );

		vm.roll(block.number + 1 );
		}


	function testGasDepositSwapWithdrawAndArbitrage() public
		{
		uint256 arbProfits = pools.depositedUserBalance(address(dao), weth);

		uint256 gas0 = gasleft();
		uint256 totalOutput = pools.depositSwapWithdraw( tokenE, weth, 100 ether, 0, block.timestamp );

		console.log( "DEPOSIT/SWAP/ARB GAS: ", gas0 - gasleft() );
		console.log( "OUTPUT: ", totalOutput );
		console.log( "ARB PROFITS: ", arbProfits );
		}


	function testGasSerialSplitDepositSwapWithdrawAndArbitrage() public
		{
		uint256 totalOutput = 0;
		uint256 arbProfits = pools.depositedUserBalance(address(dao), weth);

		uint256 gas0 = gasleft();
		for( uint256 i = 0; i < 10; i++ )
			{
			totalOutput += pools.depositSwapWithdraw( tokenE, weth, 10 ether, 0, block.timestamp );
			vm.roll(block.number + 1 );
			}

		arbProfits = pools.depositedUserBalance(address(dao), weth) - arbProfits;

		console.log( "SERIAL SPLIT DEPOSIT/SWAP/ARB GAS: ", gas0 - gasleft() );
		console.log( "SERIAL SPLIT OUTPUT: ", totalOutput );
		console.log( "SERIAL SPLIT ARB PROFITS: ", arbProfits );
		}


	function testGasSwapAndArbitrage() public
		{
		uint256 gas0 = gasleft();
		pools.swap( tokenE, weth, 10 ether, 0, block.timestamp );
		console.log( "SWAP/ARB GAS: ", gas0 - gasleft() );
		}


	function testDepositSwapWithdrawAndArbitrage() public
		{
		uint256 amountOut = pools.depositSwapWithdraw( tokenE, weth, 10 ether, 0, block.timestamp );

//		console.log( "amountOut: ", amountOut );
//		console.log( "ending pools balance: ", pools.depositedUserBalance( address(pools), weth ) );

		assertEq( amountOut, 9900801949662407685 );
		assertEq( pools.depositedUserBalance( address(dao), weth ), 186746281551137400 );
		}




	}

