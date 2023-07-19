// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.12;

import "../openzeppelin/token/ERC20/IERC20.sol";


interface IAAA
	{
	function depositOwnedWETH() external;
	function transferAssetsIfReplaced() external;
	function attemptArbitrage( address swapper, IERC20[] memory swapPath, uint256 amountIn ) external;
	}
