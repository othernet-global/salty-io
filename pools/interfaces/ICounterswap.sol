// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.21;

import "../../openzeppelin/token/ERC20/IERC20.sol";

interface ICounterswap
	{
	function depositTokenForCounterswap( IERC20 tokenToDeposit, IERC20 desiredToken, uint256 amountToDeposit ) external;
	function withdrawTokenFromCounterswap( IERC20 tokenToWithdraw, uint256 amountToWithdraw ) external;

	// Views
	function depositedTokens( IERC20 depositedToken, IERC20 desiredToken ) external returns (uint256);
	}

