// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.12;

import "./IPriceFeed.sol";


interface IStableConfig
	{
	function setPriceFeed( IPriceFeed _priceFeed ) external; // onlyOwner
	function changeRewardPercentForCallingLiquidation(bool increase) external; // onlyOwner
	function changeMaxRewardValueForCallingLiquidation(bool increase) external; // onlyOwner
	function changeMinimumCollateralValueForBorrowing(bool increase) external; // onlyOwner
	function changeInitialCollateralRatioPercent(bool increase) external; // onlyOwner
	function changeMinimumCollateralRatioPercent(bool increase) external; // onlyOwner
	function changeMaximumLiquidationSlippagePercentTimes1000(bool increase) external; // onlyOwner
	function changePercentSwapToUSDS(bool increase) external; // onlyOwner

	// Views
    function priceFeed() external view returns (IPriceFeed);
    function rewardPercentForCallingLiquidation() external view returns (uint256);
    function maxRewardValueForCallingLiquidation() external view returns (uint256);
    function minimumCollateralValueForBorrowing() external view returns (uint256);
	function initialCollateralRatioPercent() external view returns (uint256);
	function minimumCollateralRatioPercent() external view returns (uint256);
	function maximumLiquidationSlippagePercentTimes1000() external view returns (uint256);
	function percentSwapToUSDS() external view returns (uint256);
	}
