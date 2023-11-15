// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "openzeppelin-contracts/contracts/access/Ownable.sol";


contract TestChainlinkAggregator is Ownable
    {
	uint256 public forcedPriceWith18Decimals;
	bool public shouldFail = false;
	bool public shouldTimeout = false;


	constructor( uint256 _forcedPriceWith18Decimals )
		{
		forcedPriceWith18Decimals = _forcedPriceWith18Decimals;
		}


	function setPrice( uint256 _forcedPriceWith18Decimals ) public onlyOwner
		{
		forcedPriceWith18Decimals = _forcedPriceWith18Decimals;
		}


	function setShouldFail() public onlyOwner
		{
		shouldFail = true;
		}


	function setShouldTimeout() public onlyOwner
		{
		shouldTimeout = true;
		}


	function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80)
		{
		require( ! shouldFail );

		if ( shouldTimeout )
			return (uint80(0), int256(forcedPriceWith18Decimals), uint256(0), block.timestamp - 61 minutes, uint80(0));

		return (uint80(0), int256(forcedPriceWith18Decimals), uint256(0), block.timestamp - 59 minutes, uint80(0));
		}
    }