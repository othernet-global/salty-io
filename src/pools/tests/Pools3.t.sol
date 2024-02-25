// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "../../dev/Deployment.sol";
import "../PoolUtils.sol";


contract TestPools3 is Deployment
	{
	address public alice = address(0x1111);


	constructor()
		{
		// If $COVERAGE=yes, create an instance of the contract so that coverage testing can work
		// Otherwise, what is tested is the actual deployed contract on the blockchain (as specified in Deployment.sol)
		if ( keccak256(bytes(vm.envString("COVERAGE" ))) == keccak256(bytes("yes" )))
			initializeContracts();

		grantAccessDefault();

		finalizeBootstrap();
		}


	function testSwap() public
		{
		vm.prank(DEPLOYER);
		weth.transfer(address(this), 1000000 ether );

		TestERC20 tokenA = new TestERC20("TEST", 18);
		TestERC20 tokenB = new TestERC20("TEST", 18);

		vm.startPrank(address(dao));
		poolsConfig.whitelistPool( tokenA, tokenB );
		poolsConfig.whitelistPool( tokenA, weth );
		poolsConfig.whitelistPool( tokenB, weth );
		vm.stopPrank();

		tokenA.approve( address(liquidity), type(uint256).max );
		tokenB.approve( address(liquidity), type(uint256).max );
		weth.approve( address(liquidity), type(uint256).max );

		tokenA.approve( address(pools), type(uint256).max );

		liquidity.depositLiquidityAndIncreaseShare(tokenA, tokenB, 1000 ether, 1000 ether, 0, 0, 0, block.timestamp, false);
		liquidity.depositLiquidityAndIncreaseShare(tokenA, weth, 1000 ether, 1000 ether, 0, 0, 0, block.timestamp, false);
		liquidity.depositLiquidityAndIncreaseShare(tokenB, weth, 1000 ether, 1000 ether, 0, 0, 0, block.timestamp, false);

		pools.depositSwapWithdraw(tokenA, tokenB, 10 ether, 0, block.timestamp );
		}
    }