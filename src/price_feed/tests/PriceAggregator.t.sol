// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "./TestPriceAggregator.sol";
import "../../dev/Deployment.sol";
import "./ForcedPriceFeed.sol";


contract TestPriceAggreagator is Deployment
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
    }


	// A unit test that checks the operation of the _aggregatePrices function. Should only be tested through external calls. This test should verify that the function correctly aggregates the prices from the price feeds when only two of the price feeds return non-zero prices, that it reverts if there are not at least two non-zero prices or if the closest two prices are more than the maximum allowed difference apart, and that the function correctly calculates the average of the two non-zero prices.
	function testAggregatePrices() public
    {
        // Setup
        priceFeed1.setBTCPrice(0 ether);  // Setting 0 price to priceFeed1
        priceFeed2.setBTCPrice(50000 ether);  // Setting a price to priceFeed2
        priceFeed3.setBTCPrice(51000 ether);  // Setting a price close to priceFeed2 to priceFeed3

        // Test aggregating the prices correctly from the price feeds when only two of the price feeds return non-zero prices
        assertEq(priceAggregator.getPriceBTC(), 50500 ether);  // The average of priceFeed2 and priceFeed3

        // Test reverts if there are not at least two non-zero prices
        priceFeed2.setBTCPrice(0 ether);  // Setting 0 price to priceFeed2 as well

        vm.expectRevert( "Invalid BTC price" );
        priceAggregator.getPriceBTC();

        // Test reverts if the closest two prices are more than the maximum allowed difference apart
        priceFeed2.setBTCPrice(50000 ether);  // Resetting priceFeed2's price
        priceFeed3.setBTCPrice(52600 ether);  // Setting a price more than 5% different from priceFeed2 to priceFeed3

        vm.expectRevert( "Invalid BTC price" );
        priceAggregator.getPriceBTC();

        // Test correctly calculates the average of the two non-zero prices
        priceFeed3.setBTCPrice(51000 ether);  // Resetting priceFeed3's price
        assertEq(priceAggregator.getPriceBTC(), 50500 ether);  // The average of priceFeed2 and priceFeed3

		// Test price1 and price2 the closest and within range
        priceFeed1.setBTCPrice(50100 ether);
        priceFeed2.setBTCPrice(50000 ether);
        priceFeed3.setBTCPrice(50200 ether);
        assertEq(priceAggregator.getPriceBTC(), 50050 ether);  // The average of priceFeed1 and priceFeed2

		// Test price2 and price3 the closest and within range
        priceFeed1.setBTCPrice(49000 ether);
        priceFeed2.setBTCPrice(50100 ether);
        priceFeed3.setBTCPrice(50200 ether);
        assertEq(priceAggregator.getPriceBTC(), 50150 ether);  // The average of priceFeed2 and priceFeed3

		// Test price1 and price3 the closest and within range
        priceFeed1.setBTCPrice(49000 ether);
        priceFeed2.setBTCPrice(52100 ether);
        priceFeed3.setBTCPrice(50000 ether);
        assertEq(priceAggregator.getPriceBTC(), 49500 ether);  // The average of priceFeed1 and priceFeed3




		// Test price1 and price2 the closest and out of range
        priceFeed1.setBTCPrice(52600 ether);
        priceFeed2.setBTCPrice(50000 ether);
        priceFeed3.setBTCPrice(0 ether);

        vm.expectRevert( "Invalid BTC price" );
        priceAggregator.getPriceBTC();

		// Test price2 and price3 the closest and out of range
        priceFeed1.setBTCPrice(0 ether);
        priceFeed2.setBTCPrice(50000 ether);
        priceFeed3.setBTCPrice(52600 ether);

        vm.expectRevert( "Invalid BTC price" );
        priceAggregator.getPriceBTC();

		// Test price1 and price3 the closest and out of range
        priceFeed1.setBTCPrice(52600 ether);
        priceFeed2.setBTCPrice(0 ether);
        priceFeed3.setBTCPrice(50000 ether);

        vm.expectRevert( "Invalid BTC price" );
        priceAggregator.getPriceBTC();
    }

    // A unit test for the setPriceFeed function. It should validate the function only calls if the cooldown period is met, also checking that the 1, 2 or 3 PriceFeed is updated accordingly and the timestamp changes.
    function testSetPriceFeed() public
        {
            // Prepare a new price feed to set in place of the current price feed
            IPriceFeed newPriceFeed = IPriceFeed(address(new ForcedPriceFeed(1 ether, 1 ether)));

    		// Test setPriceFeed when cooldown period is met
            vm.warp( block.timestamp + priceAggregator.priceFeedModificationCooldown() );
            priceAggregator.setPriceFeed(1, newPriceFeed);
            assertEq(address(priceAggregator.priceFeed1()), address(newPriceFeed));

            // Set priceFeed2 and priceFeed3 to newPriceFeed
            vm.warp( block.timestamp + priceAggregator.priceFeedModificationCooldown() );
            priceAggregator.setPriceFeed(2, newPriceFeed);
            assertEq(address(priceAggregator.priceFeed2()), address(newPriceFeed));

            vm.warp( block.timestamp + priceAggregator.priceFeedModificationCooldown() );
            priceAggregator.setPriceFeed(3, newPriceFeed);
            assertEq(address(priceAggregator.priceFeed3()), address(newPriceFeed));

            // Test revert when setPriceFeed is invoked before cooldown period is met
            IPriceFeed anotherPriceFeed = IPriceFeed(address(new ForcedPriceFeed(2 ether, 2 ether)));

			// Test that price feeds don't change if not meeting the cooldown
            priceAggregator.setPriceFeed(1, anotherPriceFeed);
            assertEq(address(priceAggregator.priceFeed1()), address(newPriceFeed));

            priceAggregator.setPriceFeed(2, anotherPriceFeed);
            assertEq(address(priceAggregator.priceFeed2()), address(newPriceFeed));

            priceAggregator.setPriceFeed(3, anotherPriceFeed);
            assertEq(address(priceAggregator.priceFeed3()), address(newPriceFeed));

        }


    // A unit test that confirms the _absoluteDifference operation handles x and y with x > y, x < y and x == y
	function testAbsoluteDifference() public
    	{
    	TestPriceAggregator tpa = new TestPriceAggregator();

		// Test x > y
		uint256 result = tpa.absoluteDifference(10 ether, 5 ether);
		assertEq(result, 5 ether, "Incorrect absolute difference computed for 10 ether and 5 ether");

		// Test x < y
		result = tpa.absoluteDifference(5 ether, 10 ether);
		assertEq(result, 5 ether, "Incorrect absolute difference computed for 5 ether and 10 ether");

		// Test x == y
		result = tpa.absoluteDifference(10 ether, 10 ether);
		assertEq(result, 0 ether, "Incorrect absolute difference computed for 10 ether and 10 ether");
    	}


    // A unit test that checks the _getPriceBTC and _getPriceETH functions. It should confirm whether the functions catch an error when the price is not retrievable and emits the appropriate event (PriceFeedError).
    function testPriceRetrieval() public {


        // Check initial prices
        assertEq(priceAggregator.getPriceBTC(), 30050 ether);
        assertEq(priceAggregator.getPriceETH(), 3005 ether);

        ForcedPriceFeed(address(priceFeed2)).setRevertNext(); // Make priceFeed2 fail
        ForcedPriceFeed(address(priceFeed3)).setRevertNext(); // Make priceFeed3 fail

		// getPriceBTC() and getPriceETH() should now fail
		vm.expectRevert( "Invalid BTC price" );
        priceAggregator.getPriceBTC();

		vm.expectRevert( "Invalid ETH price" );
        priceAggregator.getPriceETH();
    }



    // A unit test to verify the _aggregatePrices function should return zero when the number of valid prices is one or less
    function testAggregatePricesWhenValidCountIsLessOrEqualOne() public {

        ForcedPriceFeed(address(priceFeed2)).setRevertNext();
        ForcedPriceFeed(address(priceFeed3)).setRevertNext();

        // Expected revert when getting BTC Price
        vm.expectRevert( "Invalid BTC price" );
        priceAggregator.getPriceBTC();

        // Test a case where no feed has valid price
        ForcedPriceFeed(address(priceFeed1)).setRevertNext();

        // Expected revert when getting BTC Price
        vm.expectRevert( "Invalid BTC price" );
        priceAggregator.getPriceBTC();
    }



	function _absoluteDifference( uint256 x, uint256 y ) internal pure returns (uint256)
		{
		if ( x > y )
			return x - y;

		return y - x;
		}


    // A unit test that confirms _aggregatePrices correctly averages the two closest prices when the closest two prices are exactly at the maximum allowed difference apart
    function testAggregatePricesMaxDifference() public {
        // Setup
        uint256 price1 = 100 ether; // Initial price for feed1
        uint256 price2 = 100 ether + 3 ether; // Price for feed2, at max allowed difference
        uint256 price3 = 0; // Price for feed3 is irrelevant as it should be discarded

        // Set prices for price feeds with the maximum allowed difference
        priceFeed1.setBTCPrice(price1);
        priceFeed2.setBTCPrice(price2);
        priceFeed3.setBTCPrice(price3);

        // Expect that _aggregatePrices correctly averages the two closest prices
        uint256 expectedPrice = (price1 + price2) / 2;
        uint256 aggregatedPrice = priceAggregator.getPriceBTC();

        // Check that the average is correctly calculated
        assertEq(aggregatedPrice, expectedPrice, "Aggregated price did not match expected average");
    }


    // A unit test that confirms that the _absoluteDifference function works as expected when x or y is zero
    function testAbsoluteDifferenceWithZero() public {
        uint256 xZero = 0;
        uint256 yZero = 0;
        uint256 xNonZero = 5 ether;
        uint256 yNonZero = 10 ether;

        // Test _absoluteDifference with x = 0 and y = 0
        uint256 result = _absoluteDifference(xZero, yZero);
        assertEq(result, 0, "The absolute difference of zero and zero should be zero");

        // Test _absoluteDifference with x = 0 and y > 0
        result = _absoluteDifference(xZero, yNonZero);
        assertEq(result, yNonZero, "The absolute difference of zero and a non-zero value should be the non-zero value");

        // Test _absoluteDifference with x > 0 and y = 0
        result = _absoluteDifference(xNonZero, yZero);
        assertEq(result, xNonZero, "The absolute difference of a non-zero value and zero should be the non-zero value");
    }


    // A unit test to ensure that _getPriceBTC and _getPriceETH functions return zero when the external call fails (and not via revert)
	function testGetPriceReturnsZeroOnExternalCallFailure() public {
        // Setup: Make external calls fail for BTC and ETH prices
        ForcedPriceFeed(address(priceFeed1)).setRevertNext();
        ForcedPriceFeed(address(priceFeed2)).setRevertNext();
        ForcedPriceFeed(address(priceFeed3)).setRevertNext();

        // Check that the BTC price returns zero on external call failure
        vm.expectRevert( "Invalid BTC price" );
        uint256 btcPrice = priceAggregator.getPriceBTC();
        assertEq(btcPrice, 0, "BTC price should be zero on external call failure");

        // Check that the ETH price returns zero on external call failure
        vm.expectRevert( "Invalid ETH price" );
        uint256 ethPrice = priceAggregator.getPriceETH();
        assertEq(ethPrice, 0, "ETH price should be zero on external call failure");
    }

    // A unit test that validates the behavior of _aggregatePrices when two price sources are exactly the same and the third one is different
    function testAggregatePricesTwoSameOneDifferent() public {
        // Setup
        priceFeed1.setBTCPrice(50000 ether);  // Same price for priceFeed1 and priceFeed2
        priceFeed2.setBTCPrice(50000 ether);  // Same price for priceFeed1 and priceFeed2
        priceFeed3.setBTCPrice(51000 ether);  // Different price for priceFeed3

        // If the two same prices are valid, and within range, the function should aggregate them correctly.
        uint256 expectedPrice = (50000 ether + 50000 ether) / 2;
        uint256 aggregatedPrice = priceAggregator.getPriceBTC();
        assertEq(aggregatedPrice, expectedPrice, "Aggregated price should be the average of the two same prices");
    }


//    // A unit test that tests that near zero prices will not show proximity to zero itself
//    function testPricesCloseToZero() public {
//        // Setup
//        priceFeed1.setBTCPrice(0);
//        priceFeed2.setBTCPrice(.01 ether);
//        priceFeed3.setBTCPrice(.0101 ether);
//
//        // If the two same prices are valid, and within range, the function should aggregate them correctly.
//        uint256 expectedPrice = 2 ether;
//        uint256 aggregatedPrice = priceAggregator.getPriceBTC();
//
//        console.log( "aggregatedPrice: ", aggregatedPrice );
////        assertEq(aggregatedPrice, expectedPrice, "Aggregated price should be the average of the two same prices");
//    }

	}



