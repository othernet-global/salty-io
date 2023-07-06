//// SPDX-License-Identifier: BSL 1.1
//pragma solidity ^0.8.12;
//
//import "forge-std/Test.sol";
//import "../StableConfig.sol";
//
//contract TestStableConfig is Test, StableConfig
//	{
//	IPriceFeed public _forcedPriceFeed = IPriceFeed(address(0xDEE776893503EFB20e6fC7173E9c03911F28233E));
//
//
//	constructor()
//	StableConfig( _forcedPriceFeed )
//		{
//		}
//
//
//	function testRemainingRatioAfterReward() public
//		{
//		increaseMinimumCollateralRatioPercent(); // => 111%
//		increaseRewardPercentForCallingLiquidation(); // ==> 6%
//
//		uint256 startingMinimumCollateralRatioPercent = minimumCollateralRatioPercent;
//		decreaseMinimumCollateralRatioPercent();
//		assertEq( minimumCollateralRatioPercent, startingMinimumCollateralRatioPercent, "minimumCollateralRatioPercent shouldn't change due to 105 minimum buffer with reward percent" );
//
//		uint256 startingRewardPercentForCallingLiquidation = rewardPercentForCallingLiquidation;
//		increaseRewardPercentForCallingLiquidation();
//		assertEq( rewardPercentForCallingLiquidation, startingRewardPercentForCallingLiquidation, "rewardPercentForCallingLiquidation shouldn't change due to 105 minimum buffer with minimumCollateralRatioPercent" );
//		}
//	}
