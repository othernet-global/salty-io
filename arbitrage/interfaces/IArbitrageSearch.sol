// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.12;

import "../openzeppelin/token/ERC20/IERC20.sol";


interface IArbitrageSearch
	{
	function findArbitrage( IERC20[] calldata swapPath, uint256 amountIn ) external returns (IERC20[] memory arbPath, uint256 arbAmount);
	}
