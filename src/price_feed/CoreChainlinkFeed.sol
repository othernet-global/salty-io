// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./interfaces/IPriceFeed.sol";


// Uses Chainlink price oracles to retrieve prices for BTC and ETH.
// Prices are returned with 18 decimals.
contract CoreChainlinkFeed is IPriceFeed
    {
	// https://docs.chain.link/data-feeds/price-feeds/addresses
	address immutable public CHAINLINK_BTC_USD;
    address immutable public CHAINLINK_ETH_USD;


	constructor( address _CHAINLINK_BTC_USD, address _CHAINLINK_ETH_USD )
		{
		require( _CHAINLINK_BTC_USD != address(0), "_CHAINLINK_BTC_USD cannot be address(0)" );
		require( _CHAINLINK_ETH_USD != address(0), "_CHAINLINK_ETH_USD cannot be address(0)" );

		CHAINLINK_BTC_USD = _CHAINLINK_BTC_USD;
		CHAINLINK_ETH_USD = _CHAINLINK_ETH_USD;
		}


	// Returns a Chainlink oracle price with 18 decimals (converted from Chainlink's 8 decimals).
	// Returns zero on any type of failure.
	function latestChainlinkPrice(address _chainlinkFeed) public view returns (uint256)
		{
		AggregatorV3Interface chainlinkFeed = AggregatorV3Interface(_chainlinkFeed);

		int256 price = 0;

		try chainlinkFeed.latestRoundData()
		returns (
			uint80, // _roundID
			int256 _price,
			uint256, // _startedAt
			uint256 _answerTimestamp,
			uint80 // _answeredInRound
		)
			{
			price = _price;

			// Make sure that the Chainlink price update has occurred within its 60 minute heartbeat
			// https://docs.chain.link/data-feeds#check-the-timestamp-of-the-latest-answer
			uint256 answerDelay = block.timestamp - _answerTimestamp;

			if ( answerDelay > 60 minutes )
				price = 0;
			}
		catch (bytes memory) // Catching any failure
			{
			// In case of failure, price will remain 0
			}

		if ( price < 0 )
			return 0;

		// Convert the 8 decimals from the Chainlink price to 18 decimals
		return uint256(price) * 10**10;
		}


	function getPriceBTC() external view returns (uint256)
		{
		return latestChainlinkPrice( CHAINLINK_BTC_USD );
		}


	function getPriceETH() external view returns (uint256)
		{
		return latestChainlinkPrice( CHAINLINK_ETH_USD );
		}
    }