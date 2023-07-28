// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.21;

import "../../openzeppelin/token/ERC20/IERC20.sol";


interface IArbitrageSearch
	{
	function findArbitrage( IERC20 swapTokenIn, IERC20 swapTokenOut, uint256 swapAmountInValueInETH, bool isWhitelistedPair ) external returns (IERC20[] memory arbitrageSwapPath, uint256 arbAmountIn);
	}
