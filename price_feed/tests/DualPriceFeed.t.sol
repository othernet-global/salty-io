// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.21;

import "forge-std/Test.sol";
import "./TestUniswapFeed.sol";
import "../../Deployment.sol";
import "./ForcedPriceFeed.sol";
import "../DualPriceFeed.sol";


contract TestCoreUniswapFeed is Test, DualPriceFeed, Deployment
	{
	TestUniswapFeed public testUniswapFeed= new TestUniswapFeed( 0xC27D6ACC8560F24681BC475953F27C5F71668448, 0x9014aE623A76499A0f9F326e95f66fc800bF651d, exchangeConfig  );
	IForcedPriceFeed public testChainlinkFeed = new ForcedPriceFeed( 30000 ether, 50000 ether );

	DualPriceFeed public dualPriceFeed;


	constructor()
 	DualPriceFeed( IPriceFeed(address(testChainlinkFeed)), IPriceFeedUniswap(address(testUniswapFeed)) )
 		{
 		dualPriceFeed = new DualPriceFeed( IPriceFeed(address(testChainlinkFeed)), IPriceFeedUniswap(address(testUniswapFeed)) );
		}


	// A unit test that confirms the correct initialization of the chainlinkFeed and uniswapFeed contract addresses in the DualPriceFeed constructor.
	function testConstructorInitialization() public
    	{
    	DualPriceFeed feed = new DualPriceFeed( IPriceFeed(address(testChainlinkFeed)), IPriceFeedUniswap(address(testUniswapFeed)) );

    	assertEq( address(feed.chainlinkFeed()), address(testChainlinkFeed) );
    	assertEq( address(feed.uniswapFeed()), address(testUniswapFeed) );
    	}



	// A unit test that verifies the correct operation of ForcedPriceFeed contract's functions - setBTCPrice, setETHPrice, getPriceBTC, getPriceETH - and their impact on the state of the contract.
	function testForcedPriceFeedOperation() public
    	{
    	uint256 forcedBTCPrice = 40000 ether;
    	uint256 forcedETHPrice = 3000 ether;

    	testChainlinkFeed.setBTCPrice(forcedBTCPrice);
    	testChainlinkFeed.setETHPrice(forcedETHPrice);

    	assertEq(testChainlinkFeed.getPriceBTC(), forcedBTCPrice);
    	assertEq(testChainlinkFeed.getPriceETH(), forcedETHPrice);
    	}


	// A unit test that checks the behavior of the DualPriceFeed contract when the prices from Chainlink and Uniswap diverge significantly and suddenly, simulating a price manipulation attack.
	function testPriceManipulationBTC() public
        {
        uint256 chainlinkPrice = 30000 ether;
        uint256 uniswapPriceWBTC_WETH_5 = 10 ether;
        uint256 uniswapPriceWBTC_WETH_60 = 10 ether;
        uint256 uniswapPriceWETH_USDC_5 = 3050 ether;
        uint256 uniswapPriceWETH_USDC_60 = 4000 ether;

        testChainlinkFeed.setBTCPrice(chainlinkPrice);
        testUniswapFeed.setTwapWBTC_WETH( uniswapPriceWBTC_WETH_5);
        testUniswapFeed.setTwapWETH_USDC( uniswapPriceWETH_USDC_5);

        // Check if the 5 minute TWAP is returned when the price difference is under 3%
        assertEq(dualPriceFeed.getPriceBTC(), uniswapPriceWBTC_WETH_5 * uniswapPriceWETH_USDC_5 / 10**18 );

        // Simulate a price manipulation attack where the prices diverge significantly
        testUniswapFeed.setTwapWBTC_WETH( uniswapPriceWBTC_WETH_60);
        testUniswapFeed.setTwapWETH_USDC( uniswapPriceWETH_USDC_60);

        // Check if the 60 minute TWAP is returned when the price difference is over 3%
        assertEq(dualPriceFeed.getPriceBTC(), uniswapPriceWBTC_WETH_60 * uniswapPriceWETH_USDC_60 / 10**18 );
        }


	// A unit test that checks the behavior of the DualPriceFeed contract when the prices from Chainlink and Uniswap diverge significantly and suddenly, simulating a price manipulation attack.
	function testPriceManipulationETH() public
        {
        uint256 chainlinkPrice = 3000 ether;
        uint256 uniswapPrice5 = 3050 ether;
        uint256 uniswapPrice60 = 4000 ether;

        testChainlinkFeed.setETHPrice(chainlinkPrice);
        testUniswapFeed.setTwapWETH_USDC(uniswapPrice5);

        // Check if the 5 minute TWAP is returned when the price difference is under 3%
        assertEq(dualPriceFeed.getPriceETH(), uniswapPrice5);

        // Simulate a price manipulation attack where the prices diverge significantly
        testUniswapFeed.setTwapWETH_USDC(uniswapPrice60);

        // Check if the 1 hour TWAP is returned when the price difference is over 3%
        assertEq(dualPriceFeed.getPriceETH(), uniswapPrice60);
        }


	// A unit test that verifies that getPriceETH reverts if chainlink or uniswap functions revert
	function testGetPriceETHReverts() public
        {
        // Set chainlinkFeed and uniswapFeed to revert on next call
        testChainlinkFeed.setRevertNext();
        testUniswapFeed.setRevertNext();

        // Expect getPriceETH to revert due to chainlinkFeed.getPriceETH reverting
        vm.expectRevert( "revertNext is true" );
        dualPriceFeed.getPriceETH();

        // Reset chainlinkFeed but keep uniswapFeed to revert
        testChainlinkFeed.setRevertNext();

        // Expect getPriceETH to revert due to uniswapFeed.getTwapWETH reverting
        vm.expectRevert( "revertNext is true" );
        dualPriceFeed.getPriceETH();
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
	}



