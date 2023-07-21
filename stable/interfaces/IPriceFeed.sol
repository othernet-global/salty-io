// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.20;


interface IPriceFeed
	{
	function getPriceBTC() external view returns (uint256);
	function getPriceETH() external view returns (uint256);
	}
