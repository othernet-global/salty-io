// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;


interface IPriceFeed
	{
	function getPriceUSDC() external view returns (uint256);
	}
