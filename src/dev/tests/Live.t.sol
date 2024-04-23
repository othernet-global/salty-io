// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "forge-std/Test.sol";
import "../../dev/Deployment.sol";


contract TestLive is Deployment
	{
	using SafeERC20 for IERC20;


	function testApprove() public
		{
		IERC20 tokenB = IERC20(address(0xdAC17F958D2ee523a2206206994597C13D831ec7));

		address wallet = address(0x43cD28520372907Ae0bF6CCa260A50E3D156c486);
		tokenB.safeApprove( wallet, 100 * 10**6 );
		}


	function testLive() public
		{
//		Pools pools = Pools(address(0xF3B07e3968170955503599047aC9FEFbDbC32077));
//
//		IERC20 usdt = IERC20(address(0xdAC17F958D2ee523a2206206994597C13D831ec7));
//
//		usdt.approve(address(pools), 0 );
////		usdt.approve(address(pools), 1000000 );
//
////
		Pools pools = new Pools(exchangeConfig, poolsConfig);
		Liquidity liquidity = new Liquidity( pools, exchangeConfig, poolsConfig, stakingConfig );
		pools.setContracts(dao, liquidity);

		address wallet = address(0x43cD28520372907Ae0bF6CCa260A50E3D156c486);
		vm.startPrank(wallet);

		IERC20 tokenA = IERC20(address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48));
		IERC20 tokenB = IERC20(address(0xdAC17F958D2ee523a2206206994597C13D831ec7));

		if ( tokenA.allowance(wallet, address(liquidity)) > 0 )
			tokenA.safeApprove( address(liquidity), 0 );
		tokenA.safeApprove( address(liquidity), 400 * 10**6 );

		if ( tokenB.allowance(wallet, address(liquidity)) > 0 )
			tokenB.safeApprove( address(liquidity), 0 );
		tokenB.safeApprove( address(liquidity), 400 * 10**6);

		liquidity.depositLiquidityAndIncreaseShare( tokenA, tokenB, 100 * 10**6, 100 * 10**6, 0, 0, 0, block.timestamp, false  );
		vm.warp( block.timestamp + 1 hours );
		liquidity.depositLiquidityAndIncreaseShare( tokenA, tokenB, 100 * 10**6, 101 * 10**6, 0, 0, 0, block.timestamp, false  );
		vm.warp( block.timestamp + 1 hours );
		liquidity.depositLiquidityAndIncreaseShare( tokenA, tokenB, 101 * 10**6, 100 * 10**6, 0, 0, 0, block.timestamp, false  );
		vm.stopPrank();
		}
	}
