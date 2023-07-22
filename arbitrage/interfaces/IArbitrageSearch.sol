// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.20;

import "../../openzeppelin/token/ERC20/IERC20.sol";


interface IArbitrageSearch
	{
	// Given a swapPath and the swapAmountIn as an equivalent amount of ETH find a profitable circular arbitrage path and amount of WETH to start the arbitrage trade with
	function findArbitrage( IERC20 swapTokenIn, IERC20 swapTokenOut, uint256 swapAmountInValueInETH, bool isDirectlyPooled ) external returns (IERC20 tokenIn, IERC20 tokenA, IERC20 tokenB, IERC20 tokenC, uint256 arbAmountIn);
	}
