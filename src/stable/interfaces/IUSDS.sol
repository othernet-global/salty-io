// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "./ICollateralAndLiquidity.sol";


interface IUSDS is IERC20
	{
	function setCollateralAndLiquidity( ICollateralAndLiquidity _collateralAndLiquidity ) external; // onlyOwner
	function mintTo( address wallet, uint256 amount ) external;
	function burnTokensInContract() external;
	}

