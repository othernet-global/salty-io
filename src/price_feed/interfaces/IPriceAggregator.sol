// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "./IPriceFeed.sol";


interface IPriceAggregator
	{
	// Views
	function maximumPriceFeedPercentDifferenceTimes1000() external view returns (uint256);

	function priceFeed1() external view returns (IPriceFeed);
	function priceFeed2() external view returns (IPriceFeed);
	function priceFeed3() external view returns (IPriceFeed);
	function getPriceBTC() external view returns (uint256);
	function getPriceETH() external view returns (uint256);
	}
