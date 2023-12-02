// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";


interface ISalt is IERC20
	{
	function burnTokensInContract() external;

	// Views
	function totalBurned() external view returns (uint256);
	}
