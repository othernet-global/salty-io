// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./interfaces/IPriceFeed.sol";


// Uses Chainlink price oracles to retrieve prices for BTC and ETH.
// Prices are returned with 18 decimals.
contract CoreChainlinkFeed is IPriceFeed
    {
    uint256 constant MAX_ANSWER_DELAY = 60 minutes;

	// https://docs.chain.link/data-feeds/price-feeds/addresses
	AggregatorV3Interface immutable public CHAINLINK_BTC_USD;
    AggregatorV3Interface immutable public CHAINLINK_ETH_USD;


	constructor( address _CHAINLINK_BTC_USD, address _CHAINLINK_ETH_USD )
		{
		CHAINLINK_BTC_USD = AggregatorV3Interface(_CHAINLINK_BTC_USD);
		CHAINLINK_ETH_USD = AggregatorV3Interface(_CHAINLINK_ETH_USD);
		}


	// Returns a Chainlink oracle price with 18 decimals (converted from Chainlink's 8 decimals).
	// Returns zero on any type of failure.
	function latestChainlinkPrice(AggregatorV3Interface chainlinkFeed) public view returns (uint256)
		{
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
			// Make sure that the Chainlink price update has occurred within its 60 minute heartbeat
			// https://docs.chain.link/data-feeds#check-the-timestamp-of-the-latest-answer
			uint256 answerDelay = block.timestamp - _answerTimestamp;

			if ( answerDelay <= MAX_ANSWER_DELAY )
				price = _price;
			else
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