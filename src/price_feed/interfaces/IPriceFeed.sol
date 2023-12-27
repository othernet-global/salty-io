// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;


interface IPriceFeed
	{
	// USD prices for BTC and ETH with 18 decimals
	function getPriceBTC() external view returns (uint256);
	function getPriceETH() external view returns (uint256);
	}
