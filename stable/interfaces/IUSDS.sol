// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.12;

import "../../openzeppelin/token/ERC20/IERC20.sol";


interface IUSDS is IERC20
	{
	function mintTo( address wallet, uint256 amount ) external;
	function shouldBurnMoreUSDS( uint256 usdsToBurn ) external;
	}

