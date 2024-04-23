// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./IPriceFeed.sol";


// Uses Chainlink price oracles to retrieve prices for USDC/USD
// Prices are returned with Chainlink's defualt 8 decimals.
contract CoreChainlinkFeed is IPriceFeed
    {
	// https://docs.chain.link/data-feeds/price-feeds/addresses
	AggregatorV3Interface immutable public CHAINLINK_USDC_USD_FEED;


	constructor( address _CHAINLINK_USDC_USD )
		{
		CHAINLINK_USDC_USD_FEED = AggregatorV3Interface(_CHAINLINK_USDC_USD);
		}


	// Returns zero on any type of failure.
	function latestChainlinkPrice(AggregatorV3Interface chainlinkFeed) public view returns (uint256)
		{
		int256 price = 0;

		try chainlinkFeed.latestRoundData()
		returns (
			uint80, // _roundID
			int256 _price,
			uint256, // _startedAt
			uint256,// _answerTimestamp,
			uint80 // _answeredInRound
		)
			{
			// Make sure that the Chainlink price update has occurred within its 60 minute heartbeat
			// https://docs.chain.link/data-feeds#check-the-timestamp-of-the-latest-answer
			//uint256 answerDelay = block.timestamp - _answerTimestamp;

			// Not really needed just for displaying UI price
//			if ( answerDelay <= MAX_ANSWER_DELAY )
				price = _price;
	//		else
		//		price = 0;
			}
		catch (bytes memory) // Catching any failure
			{
			// In case of failure, price will remain 0
			}

		if ( price < 0 )
			return 0;

		return uint256(price);
		}


	function getPriceUSDC() external view returns (uint256)
		{
		return latestChainlinkPrice( CHAINLINK_USDC_USD_FEED );
		}
    }