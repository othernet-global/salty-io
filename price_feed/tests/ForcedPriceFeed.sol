// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.20;

import "../../openzeppelin/access/Ownable.sol";


// For testing liquidation which requires that collteral has insufficient value to proceed
contract ForcedPriceFeed is Ownable
    {
	uint256 public forcedPriceBTCWith18Decimals;
	uint256 public forcedPriceETHWith18Decimals;


	constructor( uint256 _forcedPriceBTCWith18Decimals, uint256 _forcedPriceETHWith18Decimals )
		{
		forcedPriceBTCWith18Decimals = _forcedPriceBTCWith18Decimals;
		forcedPriceETHWith18Decimals = _forcedPriceETHWith18Decimals;
		}


	function setBTCPrice( uint256 _forcedPriceBTCWith18Decimals ) public onlyOwner
		{
		forcedPriceBTCWith18Decimals = _forcedPriceBTCWith18Decimals;
		}


	function setETHPrice( uint256 _forcedPriceETHWith18Decimals ) public onlyOwner
		{
		forcedPriceETHWith18Decimals = _forcedPriceETHWith18Decimals;
		}


	function getPriceBTC() external view returns (uint256)
		{
		return forcedPriceBTCWith18Decimals;
		}


	function getPriceETH() external view returns (uint256)
		{
		return forcedPriceETHWith18Decimals;
		}
    }