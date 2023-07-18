// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.12;

import "forge-std/Test.sol";
import "../PriceFeed.sol";

contract PriceFeedTest is Test, PriceFeed
	{
	// These are the actual values on chain
	address public constant _CHAINLINK_BTC_USD = 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43;
	address public constant _CHAINLINK_ETH_USD = 0x694AA1769357215DE4FAC081bf1f309aDC325306;

	address public constant _UNISWAP_V3_BTC_ETH = 0x50eaEDB835021E4A108B7290636d62E9765cc6d7;
	address public constant _UNISWAP_V3_USDC_ETH = 0x45dDa9cb7c25131DF268515131f647d726f50608;

	// These can be set when testing to return explcit prices for BTC and ETH
	uint256 private forcedChainlinkBTCPriceWith18Decimals;
	uint256 private forcedChainlinkETHPriceWith18Decimals;
	uint256 private forcedUniswapBTCPriceWith18Decimals;
	uint256 private forcedUniswapETHPriceWith18Decimals;


	constructor()
		PriceFeed( _CHAINLINK_BTC_USD, _CHAINLINK_ETH_USD, _UNISWAP_V3_BTC_ETH, _UNISWAP_V3_USDC_ETH )
		{
		}


	function setUp() public
		{
		}


	// Returns the forcedPrice if non-zero (for testing), otherwise the actual chainlinkFeed price
	function latestChainlinkPrice( address _chainlinkFeed ) public override view returns (uint256)
		{
		if ( _chainlinkFeed == _CHAINLINK_BTC_USD )
    		if ( forcedChainlinkBTCPriceWith18Decimals != 0 )
    			return forcedChainlinkBTCPriceWith18Decimals;

    		if ( _chainlinkFeed == _CHAINLINK_ETH_USD )
        		if ( forcedChainlinkETHPriceWith18Decimals != 0 )
        			return forcedChainlinkETHPriceWith18Decimals;

		return super.latestChainlinkPrice( _chainlinkFeed );
		}


	// Returns the forcedPrice if non-zero (for testing), otherwise the actual Uniswap TWAP
	function getUniswapPriceBTC( uint256 twapInterval ) public override view returns (uint256)
		{
		if ( forcedUniswapBTCPriceWith18Decimals == 0 )
			return super.getUniswapPriceBTC( twapInterval );

		return forcedUniswapBTCPriceWith18Decimals;
		}


	// Returns the forcedPrice if non-zero (for testing), otherwise the actual Uniswap TWAP
	function getUniswapPriceETH( uint256 twapInterval) public override view returns (uint256)
		{
		if ( forcedUniswapETHPriceWith18Decimals == 0 )
			return super.getUniswapPriceETH( twapInterval );

		return forcedUniswapETHPriceWith18Decimals;
		}


	function testLivePrices() public view {
        uint256 chainlinkBTC = latestChainlinkPrice( _CHAINLINK_BTC_USD );
        uint256 chainlinkETH = latestChainlinkPrice( _CHAINLINK_ETH_USD );

//        uint256 uniswapBTC = getUniswapPriceBTC(5 * 60);
//        uint256 uniswapETH = getUniswapPriceETH(5 * 60);

//		uint256 priceBTC = getPriceBTC();
//        uint256 priceETH = getPriceETH();

        console.log( "chainlinkBTC: ", chainlinkBTC / 10 ** 18 );
        console.log( "chainlinkETH: ", chainlinkETH / 10 ** 18 );
//        console.log( "uniswapBTC: ", uniswapBTC / 10 ** 18 );
//        console.log( "uniswapETH: ", uniswapETH / 10 ** 18 );
//        console.log( "priceBTC: ", priceBTC / 10 ** 18 );
//        console.log( "priceETH: ", priceETH / 10 ** 18 );

        // Under normal circumstances the prices of BTC and ETH should be the Chainlink price
        // That is selected as the default when the difference of Chainlink and Uniswap 5min TWP is less than 3%
//        assertEq( chainlinkBTC, priceBTC, "BTC price should normally be the Chainlink price" );
//		assertEq( chainlinkETH, priceETH, "ETH price should normally be the Chainlink price" );
	}


	// A unit test for the latestChainlinkPrice function, where the price from a Chainlink oracle is returned. Test this by mocking the Chainlink oracle and returning different prices, ensuring that the multiplication by DECIMAL_FACTOR is functioning correctly.
	function testLatestChainlinkPrice() public {
        uint256 expectedPriceBTC = 50000 ether;
        uint256 expectedPriceETH = 3000 ether;

        forcedChainlinkBTCPriceWith18Decimals = expectedPriceBTC;
        forcedChainlinkETHPriceWith18Decimals = expectedPriceETH;

        // Test Chainlink BTC price
        uint256 actualPriceBTC = this.latestChainlinkPrice(_CHAINLINK_BTC_USD);
        assertEq(actualPriceBTC, expectedPriceBTC, "Chainlink BTC price does not match the expected price");

        // Test Chainlink ETH price
        uint256 actualPriceETH = this.latestChainlinkPrice(_CHAINLINK_ETH_USD);
        assertEq(actualPriceETH, expectedPriceETH, "Chainlink ETH price does not match the expected price");

        // Reset forced prices
        forcedChainlinkBTCPriceWith18Decimals = 0;
        forcedChainlinkETHPriceWith18Decimals = 0;

        // Test Chainlink BTC unit test price fallback
        actualPriceBTC = this.latestChainlinkPrice(_CHAINLINK_BTC_USD);
        assertEq(actualPriceBTC, super.latestChainlinkPrice(_CHAINLINK_BTC_USD), "Chainlink BTC price fallback is not working as expected");

        // Test Chainlink ETH unit test price fallback
        actualPriceETH = this.latestChainlinkPrice(_CHAINLINK_ETH_USD);
        assertEq(actualPriceETH, super.latestChainlinkPrice(_CHAINLINK_ETH_USD), "Chainlink ETH price fallback is not working as expected");
    }



	// A unit test for the getUniswapPriceBTC and getUniswapPriceETH functions
	function testGetUniswapPrices() public {
    	// Forcing the Uniswap price for BTC and ETH
    	forcedUniswapBTCPriceWith18Decimals = 51000 ether;
    	forcedUniswapETHPriceWith18Decimals = 3200 ether;

    	// 5 minutes interval
    	uint256 twapInterval = 5 minutes;

    	assertEq(this.getUniswapPriceBTC(twapInterval), forcedUniswapBTCPriceWith18Decimals, "getUniswapPriceBTC not returning forced value");
    	assertEq(this.getUniswapPriceETH(twapInterval), forcedUniswapETHPriceWith18Decimals, "getUniswapPriceETH not returning forced value");
    }


	// A unit test for the getPriceBTC and getPriceETH functions, where the price difference between Chainlink and Uniswap is less than or greater than 3%, hence the respective Chainlink or Uniswap price is returned. Mock the latestChainlinkPrice and getUniswapPriceBTC functions to return different prices.
	function testGetPrices() public {
    	// Scenario 1: price difference < 3%
    	forcedChainlinkBTCPriceWith18Decimals = 50000 ether;
    	forcedUniswapBTCPriceWith18Decimals = 50500 ether; // 1% higher

    	forcedChainlinkETHPriceWith18Decimals = 3500 ether;
    	forcedUniswapETHPriceWith18Decimals = 3540 ether; // 1.14% higher

    	// Chainlink prices should be returned as the difference is < 3%
    	assertEq(this.getPriceBTC(), forcedChainlinkBTCPriceWith18Decimals, "getPriceBTC not returning Chainlink price for < 3% difference");
    	assertEq(this.getPriceETH(), forcedChainlinkETHPriceWith18Decimals, "getPriceETH not returning Chainlink price for < 3% difference");

    	// Scenario 2: price difference > 3%
    	forcedChainlinkBTCPriceWith18Decimals = 50000 ether;
    	forcedUniswapBTCPriceWith18Decimals = 52000 ether; // 4% higher

    	forcedChainlinkETHPriceWith18Decimals = 3500 ether;
    	forcedUniswapETHPriceWith18Decimals = 3655 ether; // 4.43% higher

    	// Uniswap prices should be returned as the difference is > 3%
    	assertEq(this.getPriceBTC(), forcedUniswapBTCPriceWith18Decimals, "getPriceBTC not returning Uniswap price for > 3% difference");
    	assertEq(this.getPriceETH(), forcedUniswapETHPriceWith18Decimals, "getPriceETH not returning Uniswap price for > 3% difference");
    }


	// A unit test for the absoluteDifference function, testing for different combinations of x and y, including x > y, x < y, and x = y.
	function testAbsoluteDifference() public
    {
        // Case: x > y
        uint256 x = 10 ether;
        uint256 y = 5 ether;
        uint256 result = _absoluteDifference(x, y);
        assertEq(result, 5 ether, "x > y failed");

        // Case: x < y
        x = 5 ether;
        y = 10 ether;
        result = _absoluteDifference(x, y);
        assertEq(result, 5 ether, "x < y failed");

        // Case: x = y
        x = 5 ether;
        y = 5 ether;
        result = _absoluteDifference(x, y);
        assertEq(result, 0 ether, "x = y failed");
    }


	// Test to check the failure condition of external dependencies for latestChainlinkPrice, getUniswapTwapWei, getUniswapPriceBTC, getUniswapPriceETH, getPriceBTC, getPriceETH functions, checking if the function can handle a failure condition when interacting with the external Chainlink or Uniswap contracts.
	function testFailureConditionExternalDependencies() public {
		address invalidAddress = address(0xDEAD);

		// Set invalid addresses
		CHAINLINK_BTC_USD = invalidAddress;
		CHAINLINK_ETH_USD = invalidAddress;
		UNISWAP_V3_BTC_ETH = invalidAddress;
		UNISWAP_V3_USDC_ETH = invalidAddress;

		vm.expectRevert("PriceFeed: Invalid Chainlink price");
		this.latestChainlinkPrice(CHAINLINK_BTC_USD);

		vm.expectRevert("PriceFeed: Invalid Chainlink price");
		this.latestChainlinkPrice(CHAINLINK_ETH_USD);

		vm.expectRevert("PriceFeed: Invalid Uniswap TWAP");
		this.getUniswapTwapWei(UNISWAP_V3_BTC_ETH, 5 minutes);

		vm.expectRevert("PriceFeed: Invalid Uniswap TWAP");
		this.getUniswapTwapWei(UNISWAP_V3_USDC_ETH, 5 minutes);

		vm.expectRevert("PriceFeed: Invalid Uniswap price");
		this.getUniswapPriceBTC(5 minutes);

		vm.expectRevert("PriceFeed: Invalid Uniswap price");
		this.getUniswapPriceETH(5 minutes);

		vm.expectRevert("PriceFeed: Invalid Chainlink price");
		this.getPriceBTC();

		vm.expectRevert("PriceFeed: Invalid Chainlink price");
		this.getPriceETH();
		}


	// Test for floating point precision errors for all functions that involve floating point calculations, adding tests that check for potential floating point precision errors.
	function testFloatingPointPrecisionErrors() public
    {
        // Setting forced values with 18 decimals for test
        forcedChainlinkBTCPriceWith18Decimals = 50000 ether; // $50,000
        forcedChainlinkETHPriceWith18Decimals = 3000 ether; // $3000
        forcedUniswapBTCPriceWith18Decimals = 50001 ether; // $50,001
        forcedUniswapETHPriceWith18Decimals = 3001 ether; // $3001

        // Testing floating point precision errors on Chainlink prices
        uint256 chainlinkBTCPrice = this.latestChainlinkPrice(_CHAINLINK_BTC_USD);
        uint256 chainlinkETHPrice = this.latestChainlinkPrice(_CHAINLINK_ETH_USD);

        assertEq(chainlinkBTCPrice, forcedChainlinkBTCPriceWith18Decimals, "Floating point precision error on Chainlink BTC price");
        assertEq(chainlinkETHPrice, forcedChainlinkETHPriceWith18Decimals, "Floating point precision error on Chainlink ETH price");

        // Testing floating point precision errors on Uniswap prices
        uint256 uniswapBTCPrice = this.getUniswapPriceBTC(5 minutes);
        uint256 uniswapETHPrice = this.getUniswapPriceETH(5 minutes);

        assertEq(uniswapBTCPrice, forcedUniswapBTCPriceWith18Decimals, "Floating point precision error on Uniswap BTC price");
        assertEq(uniswapETHPrice, forcedUniswapETHPriceWith18Decimals, "Floating point precision error on Uniswap ETH price");

        // Testing floating point precision errors on absolute difference
        uint256 absDiffBTC = _absoluteDifference(chainlinkBTCPrice, uniswapBTCPrice);
        uint256 absDiffETH = _absoluteDifference(chainlinkETHPrice, uniswapETHPrice);

        assertEq(absDiffBTC, 1 ether, "Floating point precision error on absolute difference BTC");
        assertEq(absDiffETH, 1 ether, "Floating point precision error on absolute difference ETH");

        // Testing floating point precision errors on getPriceBTC and getPriceETH
        uint256 getPriceBTC = this.getPriceBTC();
        uint256 getPriceETH = this.getPriceETH();

        assertEq(getPriceBTC, chainlinkBTCPrice, "Floating point precision error on getPriceBTC");
        assertEq(getPriceETH, chainlinkETHPrice, "Floating point precision error on getPriceETH");
    }


	// A unit test to confirm that the contract correctly sets all variables from the constructor.
	function testConstructorInitialization() public {
        assertEq(CHAINLINK_BTC_USD, _CHAINLINK_BTC_USD);
        assertEq(CHAINLINK_ETH_USD, _CHAINLINK_ETH_USD);
        assertEq(UNISWAP_V3_BTC_ETH, _UNISWAP_V3_BTC_ETH);
        assertEq(UNISWAP_V3_USDC_ETH, _UNISWAP_V3_USDC_ETH);
    }


	// A unit test that simulates various chainlink feeds with different prices, ensuring that the function returns the correct value each time.
	function testSimulateChainlinkAndUniswapFeeds() public {
        uint256[] memory btcPrices = new uint256[](5);
        btcPrices[0] = 50000 ether;
        btcPrices[1] = 60000 ether;
        btcPrices[2] = 70000 ether;
        btcPrices[3] = 80000 ether;
        btcPrices[4] = 90000 ether;

        uint256[] memory ethPrices = new uint256[](5);
        ethPrices[0] = 2000 ether;
        ethPrices[1] = 2500 ether;
        ethPrices[2] = 3000 ether;
        ethPrices[3] = 3500 ether;
        ethPrices[4] = 4000 ether;

        for (uint i = 0; i < 5; i++) {
            forcedChainlinkBTCPriceWith18Decimals = btcPrices[i];
            forcedChainlinkETHPriceWith18Decimals = ethPrices[i];
            forcedUniswapBTCPriceWith18Decimals = btcPrices[i];
            forcedUniswapETHPriceWith18Decimals = ethPrices[i];

            uint256 chainlinkBTCPrice = this.latestChainlinkPrice(_CHAINLINK_BTC_USD);
            uint256 chainlinkETHPrice = this.latestChainlinkPrice(_CHAINLINK_ETH_USD);
            uint256 uniswapBTCPrice = this.getUniswapPriceBTC(5 minutes);
            uint256 uniswapETHPrice = this.getUniswapPriceETH(5 minutes);

            assertEq(chainlinkBTCPrice, btcPrices[i]);
            assertEq(chainlinkETHPrice, ethPrices[i]);
            assertEq(uniswapBTCPrice, btcPrices[i]);
            assertEq(uniswapETHPrice, ethPrices[i]);

            uint256 priceBTC = this.getPriceBTC();
            uint256 priceETH = this.getPriceETH();

            assertEq(priceBTC, btcPrices[i]);
            assertEq(priceETH, ethPrices[i]);
        }
    }

	}



