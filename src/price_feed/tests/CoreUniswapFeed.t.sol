// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "../../dev/Deployment.sol";
import "./TestUniswapFeed.sol";


contract TestCoreUniswapFeed is Deployment
	{
	TestUniswapFeed public testUniswapFeed;


	constructor()
		{
		testUniswapFeed = new TestUniswapFeed( _testBTC, _testETH, _testUSDC, UNISWAP_V3_BTC_ETH, UNISWAP_V3_USDC_ETH );
		}



	// A unit test that checks if getTwapWBTC, getTwapWETH, and getUniswapTwapWei return zero when the _getUniswapTwapWei function fails or returns zero for any of the underlying pools. This can be done by making the _getUniswapTwapWei function throw an error or return zero, and checking that the other functions return zero as well.
	function testGetTwapFailure() public
        {
        uint256 twapInterval = 1;

        // Set the revertNext flag
        testUniswapFeed.setRevertNext();

		IUniswapV3Pool UNISWAP_V3_WBTC_WETH = testUniswapFeed.UNISWAP_V3_WBTC_WETH();
		IUniswapV3Pool UNISWAP_V3_WETH_USDC = testUniswapFeed.UNISWAP_V3_WETH_USDC();

        // Call getUniswapTwapWei with the UNISWAP_V3_WBTC_WETH pool and check the result
        vm.expectRevert( "revertNext is true" );
        testUniswapFeed.getUniswapTwapWei(UNISWAP_V3_WBTC_WETH, twapInterval);

        // Call getUniswapTwapWei with the UNISWAP_V3_WETH_USDC pool and check the result
        vm.expectRevert( "revertNext is true" );
        testUniswapFeed.getUniswapTwapWei(UNISWAP_V3_WETH_USDC, twapInterval);

        // Call getTwapWBTC and check the result
        vm.expectRevert( "revertNext is true" );
        testUniswapFeed.getTwapWBTC(twapInterval);

        // Call getTwapWETH and check the result
        vm.expectRevert( "revertNext is true" );
        testUniswapFeed.getTwapWETH(twapInterval);
        }


// A unit test that checks whether the constructor of the CoreUniswapFeed contract correctly determines the token order based on the addresses of the WBTC, WETH, and USDC tokens.
function testCoreUniswapFeedConstructor( address _wbtc, address _weth, address _usdc ) public
    {
    if ( ( _wbtc == address(0) ) || ( _weth == address(0) ) || ( _usdc == address(0) ) )
    	return;

	testUniswapFeed = new TestUniswapFeed( IERC20(_wbtc), IERC20(_weth), IERC20(_usdc), UNISWAP_V3_BTC_ETH, UNISWAP_V3_USDC_ETH );

    // Check if WBTC/WETH order is correctly determined
    bool expectedWbtcWethFlipped = address(_weth) < address(_wbtc);
    assertEq(testUniswapFeed.wbtc_wethFlipped(), expectedWbtcWethFlipped, "WBTC/WETH order incorrectly determined in constructor");

    // Check if WETH/USDC order is correctly determined
    bool expectedWethUsdcFlipped = address(_usdc) < address(_weth);
    assertEq(testUniswapFeed.weth_usdcFlipped(), expectedWethUsdcFlipped, "WETH/USDC order incorrectly determined in constructor");

    // Set forced TWAPs
    uint256 forcedTWAP_WBTC_WETH = 2 ether;
    uint256 forcedTWAP_WETH_USDC = 3 ether;
    testUniswapFeed.setTwapWBTC_WETH(forcedTWAP_WBTC_WETH);
    testUniswapFeed.setTwapWETH_USDC(forcedTWAP_WETH_USDC);

    // Get TWAPs
    uint256 twapWBTC = testUniswapFeed.getTwapWBTC(1);
    uint256 twapWETH = testUniswapFeed.getTwapWETH(1);

    if ( expectedWbtcWethFlipped )
    	forcedTWAP_WBTC_WETH = 10 ** 36 / forcedTWAP_WBTC_WETH;

    if ( ! expectedWethUsdcFlipped )
    	forcedTWAP_WETH_USDC = 10 ** 36 / forcedTWAP_WETH_USDC;

    uint256 expectedTwapWBTC = ( forcedTWAP_WETH_USDC * 10**18) / forcedTWAP_WBTC_WETH;
    uint256 expectedTwapWETH = forcedTWAP_WETH_USDC;

    // Check if the TWAPs are as expected
    assertEq(twapWBTC, expectedTwapWBTC, "WBTC TWAP not as expected when token order is flipped");
    assertEq(twapWETH, expectedTwapWETH, "WETH TWAP not as expected when token order is flipped");
}


	// A unit test that verifies the CoreUniswapFeed contract initialization with valid WBTC/WETH, WETH/USDC pool addresses and ExchangeConfig contract address. Check that the contract addresses are set correctly, and the address comparison for WBTC/WETH and WETH/USDC orders are done correctly.
	function testCoreUniswapFeedInitialization() public {
        // Create a new TestUniswapFeed contract
        TestUniswapFeed newUniswapFeed = new TestUniswapFeed(_testBTC, _testETH, _testUSDC, UNISWAP_V3_BTC_ETH, UNISWAP_V3_USDC_ETH);

        // Check if the pool addresses are set correctly
        assertEq(address(newUniswapFeed.UNISWAP_V3_WBTC_WETH()), UNISWAP_V3_BTC_ETH, "WBTC/WETH pool address not set correctly in constructor");
        assertEq(address(newUniswapFeed.UNISWAP_V3_WETH_USDC()), UNISWAP_V3_USDC_ETH, "WETH/USDC pool address not set correctly in constructor");

        // Check if the ExchangeConfig address is set correctly
        assertEq(address(newUniswapFeed.wbtc()), address(exchangeConfig.wbtc()), "WBTC token address not set correctly in constructor");
        assertEq(address(newUniswapFeed.weth()), address(exchangeConfig.weth()), "WETH token address not set correctly in constructor");

        // Check if the WBTC/WETH and WETH/USDC orders are determined correctly
        bool expectedWbtcWethFlipped = address(exchangeConfig.weth()) < address(exchangeConfig.wbtc());
        bool expectedWethUsdcFlipped = address(testUniswapFeed.usdc()) < address(exchangeConfig.weth());

        assertEq(newUniswapFeed.wbtc_wethFlipped(), expectedWbtcWethFlipped, "WBTC/WETH order incorrectly determined in constructor");
        assertEq(newUniswapFeed.weth_usdcFlipped(), expectedWethUsdcFlipped, "WETH/USDC order incorrectly determined in constructor");
    }

	}



