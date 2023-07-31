// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.21;

import "forge-std/Test.sol";
import "./TestUniswapFeed.sol";
import "../../dev/Deployment.sol";
import "./ForcedPriceFeed.sol";
import "../PriceAggregator.sol";


contract TestPriceAggreagator is Test, Deployment
	{
	IForcedPriceFeed public priceFeed1;
	IForcedPriceFeed public priceFeed2;
	IForcedPriceFeed public priceFeed3;


	constructor()
 		{
 		priceFeed1 = new ForcedPriceFeed(30000 ether, 3000 ether );
 		priceFeed2 = new ForcedPriceFeed(30100 ether, 3050 ether );
 		priceFeed3 = new ForcedPriceFeed(30500 ether, 3010 ether );

		priceAggregator = new PriceAggregator();
		priceAggregator.setInitialFeeds( IPriceFeed(address(priceFeed1)), IPriceFeed(address(priceFeed2)), IPriceFeed(address(priceFeed3)) );
		}


	// A unit test that verifies the correct operation of the setInitialFeeds function. This test should check that the function correctly sets the initial price feeds, that it cannot be called more than once, and that it reverts if any of the price feed addresses are zero.
	function testSetInitialFeeds() public
    {
        // Setup
        IPriceFeed newPriceFeed1 = IPriceFeed(address(new ForcedPriceFeed(1 ether, 1 ether)));
        IPriceFeed newPriceFeed2 = IPriceFeed(address(new ForcedPriceFeed(2 ether, 2 ether)));
        IPriceFeed newPriceFeed3 = IPriceFeed(address(new ForcedPriceFeed(3 ether, 3 ether)));

        PriceAggregator newPriceAggregator = new PriceAggregator();

        // Test successful call
        newPriceAggregator.setInitialFeeds(newPriceFeed1, newPriceFeed2, newPriceFeed3);
        assertEq(address(newPriceAggregator.priceFeed1()), address(newPriceFeed1));
        assertEq(address(newPriceAggregator.priceFeed2()), address(newPriceFeed2));
        assertEq(address(newPriceAggregator.priceFeed3()), address(newPriceFeed3));

        // Test revert when function is called more than once
        vm.expectRevert("setInitialFeeds() can only be called once");
        newPriceAggregator.setInitialFeeds(newPriceFeed1, newPriceFeed2, newPriceFeed3);

        // Test revert when any of the price feed addresses are zero
        newPriceAggregator = new PriceAggregator();
        vm.expectRevert("_priceFeed1 cannot be address(0)");
        newPriceAggregator.setInitialFeeds(IPriceFeed(address(0)), newPriceFeed2, newPriceFeed3);

        vm.expectRevert("_priceFeed2 cannot be address(0)");
        newPriceAggregator.setInitialFeeds(newPriceFeed1, IPriceFeed(address(0)), newPriceFeed3);

        vm.expectRevert("_priceFeed3 cannot be address(0)");
        newPriceAggregator.setInitialFeeds(newPriceFeed1, newPriceFeed2, IPriceFeed(address(0)));
    }


	// A unit test that checks the operation of the _aggregatePrices function. Should only be tested through external calls. This test should verify that the function correctly aggregates the prices from the price feeds when only two of the price feeds return non-zero prices, that it reverts if there are not at least two non-zero prices or if the closest two prices are more than the maximum allowed difference apart, and that the function correctly calculates the average of the two non-zero prices.
	function testAggregatePrices() public
    {
        // Setup
        priceFeed1.setBTCPrice(0 ether);  // Setting 0 price to priceFeed1
        priceFeed2.setBTCPrice(50000 ether);  // Setting a price to priceFeed2
        priceFeed3.setBTCPrice(51000 ether);  // Setting a price close to priceFeed2 to priceFeed3

        // Test aggregating the prices correctly from the price feeds when only two of the price feeds return non-zero prices
        priceAggregator.performUpkeep();  // This will internally call _aggregatePrices
        assertEq(priceAggregator.getPriceBTC(), 50500 ether);  // The average of priceFeed2 and priceFeed3

        // Test reverts if there are not at least two non-zero prices
        priceFeed2.setBTCPrice(0 ether);  // Setting 0 price to priceFeed2 as well
        priceAggregator.performUpkeep();  // This will internally call _aggregatePrices

        vm.expectRevert( "Invalid WBTC price" );
        priceAggregator.getPriceBTC();

        // Test reverts if the closest two prices are more than the maximum allowed difference apart
        priceFeed2.setBTCPrice(50000 ether);  // Resetting priceFeed2's price
        priceFeed3.setBTCPrice(52600 ether);  // Setting a price more than 5% different from priceFeed2 to priceFeed3
        priceAggregator.performUpkeep();  // This will internally call _aggregatePrices

        vm.expectRevert( "Invalid WBTC price" );
        priceAggregator.getPriceBTC();

        // Test correctly calculates the average of the two non-zero prices
        priceFeed3.setBTCPrice(51000 ether);  // Resetting priceFeed3's price
        priceAggregator.performUpkeep();  // This will internally call _aggregatePrices
        assertEq(priceAggregator.getPriceBTC(), 50500 ether);  // The average of priceFeed2 and priceFeed3

		// Test price1 and price2 the closest and within range
        priceFeed1.setBTCPrice(50100 ether);
        priceFeed2.setBTCPrice(50000 ether);
        priceFeed3.setBTCPrice(50200 ether);
        priceAggregator.performUpkeep();  // This will internally call _aggregatePrices
        assertEq(priceAggregator.getPriceBTC(), 50050 ether);  // The average of priceFeed1 and priceFeed2

		// Test price2 and price3 the closest and within range
        priceFeed1.setBTCPrice(49000 ether);
        priceFeed2.setBTCPrice(50100 ether);
        priceFeed3.setBTCPrice(50200 ether);
        priceAggregator.performUpkeep();  // This will internally call _aggregatePrices
        assertEq(priceAggregator.getPriceBTC(), 50150 ether);  // The average of priceFeed2 and priceFeed3

		// Test price1 and price3 the closest and within range
        priceFeed1.setBTCPrice(49000 ether);
        priceFeed2.setBTCPrice(52100 ether);
        priceFeed3.setBTCPrice(50000 ether);
        priceAggregator.performUpkeep();  // This will internally call _aggregatePrices
        assertEq(priceAggregator.getPriceBTC(), 49500 ether);  // The average of priceFeed1 and priceFeed3




		// Test price1 and price2 the closest and out of range
        priceFeed1.setBTCPrice(60100 ether);
        priceFeed2.setBTCPrice(50000 ether);
        priceFeed3.setBTCPrice(0 ether);
        priceAggregator.performUpkeep();  // This will internally call _aggregatePrices

        vm.expectRevert( "Invalid WBTC price" );
        priceAggregator.getPriceBTC();

		// Test price2 and price3 the closest and out of range
        priceFeed1.setBTCPrice(0 ether);
        priceFeed2.setBTCPrice(50100 ether);
        priceFeed3.setBTCPrice(60200 ether);
        priceAggregator.performUpkeep();  // This will internally call _aggregatePrices

        vm.expectRevert( "Invalid WBTC price" );
        priceAggregator.getPriceBTC();

		// Test price1 and price3 the closest and out of range
        priceFeed1.setBTCPrice(69000 ether);
        priceFeed2.setBTCPrice(0 ether);
        priceFeed3.setBTCPrice(50000 ether);
        priceAggregator.performUpkeep();  // This will internally call _aggregatePrices

        vm.expectRevert( "Invalid WBTC price" );
        priceAggregator.getPriceBTC();

    }
	}



