// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.21;

import "../openzeppelin/token/ERC20/IERC20.sol";


interface ISalt is IERC20
	{
	function burnTokensInContract() external returns (uint256);
	}
