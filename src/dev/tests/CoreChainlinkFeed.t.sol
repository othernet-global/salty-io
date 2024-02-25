// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "../../dev/Deployment.sol";
import "../CoreChainlinkFeed.sol";
import "../../dev/Utils.sol";
import "../IPriceFeed.sol";

contract TestUtils is Deployment
	{

	IPriceFeed public priceFeed;


    function setUp() public
    	{
    	if ( DEBUG ) // Sepolia?
	    	priceFeed  = new CoreChainlinkFeed(address(0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E));
	    else
	    	priceFeed  = new CoreChainlinkFeed(address(0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6));
		}


	function testPriceFeed() public view
		{
		uint256 price = priceFeed.getPriceUSDC();

		console.log( "USDC PRICE: ", price );
	    }
	}
