// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.12;

import "./ICollateral.sol";


interface ILiquidator
	{
	function increaseUSDSToBurn( uint256 amountToBurnLater ) external;

	function collateral() external returns (ICollateral);
	}
