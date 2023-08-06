// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.21;

import "../../openzeppelin/token/ERC20/IERC20.sol";


interface ICounterswap
	{
	function depositToken( IERC20 tokenToDeposit, IERC20 desiredToken, uint256 amountToDeposit ) external;
	function shouldCounterswap( IERC20 swapTokenIn, IERC20 swapTokenOut, uint256 swapAmountIn, uint256 swapAmountOut ) external returns (bool _shouldCounterswap);

	// Views
	function depositedTokens( IERC20 depositedToken, IERC20 desiredToken ) external returns (uint256);
	}

