// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.21;

import "forge-std/Test.sol";
import "../USDS.sol";
import "../../dev/Deployment.sol";


contract USDSTest is Test, Deployment
	{
	constructor()
		{
		// If $COVERAGE=yes, create an instance of the contract so that coverage testing can work
		// Otherwise, what is tested is the actual deployed contract on the blockchain (as specified in Deployment.sol)
		if ( keccak256(bytes(vm.envString("COVERAGE" ))) == keccak256(bytes("yes" )))
			{
			vm.startPrank(DEPLOYER);

			usds = new USDS(priceAggregator, stableConfig, wbtc, weth);
			usds.setCollateral(collateral);
			usds.setPools(pools);

			vm.stopPrank();

			vm.startPrank(address(dao));
			poolsConfig.whitelistPool( usds, wbtc );
			poolsConfig.whitelistPool( usds, weth );
			vm.stopPrank();
			}

		priceAggregator.performUpkeep();
		}


	// // A unit test in which the collateral address is set for the first time. This test should validate that the collateral address is correctly updated and can only be set once.
	function testSetCollateralOnlyOnce() public {
		address firstAddress = address(0x5555);
		address secondAddress = address(0x6666);

		// New USDS in case Collateral was set in the deployed version already
		usds = new USDS(priceAggregator, stableConfig, wbtc, weth);

		// Initial set up
		assertEq(address(usds.collateral()), address(0));

		// Try setting the collateral address for the first time
		usds.setCollateral(ICollateral(firstAddress));
		assertEq(address(usds.collateral()), address(firstAddress));

		// Try setting the collateral address for the second time
		vm.expectRevert("setCollateral can only be called once");
		usds.setCollateral(ICollateral(secondAddress));

		// Validate that the collateral address did not change
		assertEq(address(usds.collateral()), address(firstAddress));
	}


	// A unit test in which the pools address is set for the first time. This test should validate that the pools address is correctly updated and can only be set once.
	function testSetPoolsOnlyOnce() public {
		address firstAddress = address(0x5555);
		address secondAddress = address(0x6666);

		// New USDS in case Colalteral was set in the deployed version already
		usds = new USDS(priceAggregator, stableConfig, wbtc, weth);

		// Initial set up
		assertEq(address(usds.pools()), address(0));

		// Try setting the collateral address for the first time
		usds.setPools(IPools(firstAddress));
		assertEq(address(usds.pools()), address(firstAddress));

		// Try setting the collateral address for the second time
		vm.expectRevert("setPools can only be called once");
		usds.setPools(IPools(secondAddress));

		// Validate that the collateral address did not change
		assertEq(address(usds.pools()), address(firstAddress));
	}


	// A unit test where a different address attempts to call the mintTo function. This test should validate that only the collateral address is allowed to mint tokens.
	function testOnlyCollateralCanMint() public {
        address otherAddress = address(0x6666);
        address wallet = address(0x7777);
        uint256 mintAmount = 1 ether;

        // Try minting from the collateral address
        vm.prank(address(collateral));
        usds.mintTo(wallet, mintAmount);
        assertEq(usds.balanceOf(wallet), mintAmount);

        // Try minting from a different address
        vm.expectRevert("Can only mint from the Collateral contract");
        vm.prank(otherAddress);
        usds.mintTo(wallet, mintAmount);

        // Validate that the balance did not increase
        assertEq(usds.balanceOf(wallet), mintAmount);
    }


	// A unit test where an attempt is made to burn more USD than is available in the contract.
	function testBurnMoreThanAvailable() public {
        uint256 usdsToBurn = 2 ether; // Amount greater than current balance

        assertEq(usds.usdsThatShouldBeBurned(), 0 ether);

        // Try burning more than available
        vm.prank(address(collateral));
        usds.shouldBurnMoreUSDS(usdsToBurn);

        // Validate that the amount that should be burnt is set correctly
        assertEq(usds.usdsThatShouldBeBurned(), usdsToBurn);
}


   // A unit test where a different address attempts to call the shouldBurnMoreUSDS function. This test should validate that only the collateral address is allowed to signal the contract to burn tokens.
   function testOnlyCollateralCanSignalBurn2() public {
		   address otherAddress = address(0x6666);
		   uint256 amountToBurn = 1 ether;

		   vm.prank(address(collateral));
		   usds.shouldBurnMoreUSDS(amountToBurn);
		   assertEq(usds.usdsThatShouldBeBurned(), amountToBurn);

		   // Try signalling burn from a non-collateral address
		   vm.expectRevert("Not the Collateral contract");
		   vm.prank(otherAddress);
		   usds.shouldBurnMoreUSDS(amountToBurn);
   }

	// A unit test in which the collateral address is set for the first time. This test should validate that the collateral address is correctly updated.
	function testSetCollateralInitial() public {
    	address collateralAddress = address(0x5555);

    	// New USDS instance in case Collateral was set in the deployed version already
    	USDS newUSDS = new USDS(priceAggregator, stableConfig, wbtc, weth);

    	// Initial set up
    	assertEq(address(newUSDS.collateral()), address(0));

    	// Set the collateral address for the first time
    	newUSDS.setCollateral(ICollateral(collateralAddress));

    	// Validate that the collateral address is correctly updated
    	assertEq(address(newUSDS.collateral()), collateralAddress);
    }


	// A unit test where a different address attempts to call the mintTo function. This test should validate that only the collateral address is allowed to mint tokens.
	function testOnlyCollateralCanMint2() public {
        address otherAddress = address(0x6666);
        address wallet = address(0x7777);
        uint256 mintAmount = 1 ether;

        // Set up a new instance of USDS and set collateral
        // Mint from the collateral address
        vm.prank(address(collateral));
        usds.mintTo(wallet, mintAmount);
        assertEq(usds.balanceOf(wallet), mintAmount);

        // Attempt to mint from a different address
        vm.expectRevert("Can only mint from the Collateral contract");
        vm.prank(otherAddress);
        usds.mintTo(wallet, mintAmount);

        // Validate that the balance did not increase
        assertEq(usds.balanceOf(wallet), mintAmount);
    }


	// A unit test where a different address attempts to call the shouldBurnMoreUSDS function. This test should validate that only the collateral address is allowed to signal the contract to burn tokens.
	function testOnlyCollateralCanSignalBurn() public {
        address otherAddress = address(0x6666);
        uint256 burnAmount = 1 ether;

        // Set up a new instance of USDS and set collateral
        // Signal burn from the collateral address
        vm.prank(address(collateral));
        usds.shouldBurnMoreUSDS(burnAmount);
        assertEq(usds.usdsThatShouldBeBurned(), burnAmount);

        // Attempt to signal burn from a different address
        vm.expectRevert("Not the Collateral contract");
        vm.prank(otherAddress);
        usds.shouldBurnMoreUSDS(burnAmount);
    }


	// A unit test where a call is made to mintTo function without calling the setCollateral function first. This test will validate that before the mint operation can be made, the Collateral contract has to be set.
    function testMintWithoutSettingCollateral() public {
        address wallet = address(0x7777);
        uint256 mintAmount = 1 ether;

        // Try minting without setting the collateral address first
        vm.expectRevert("Can only mint from the Collateral contract");
        usds.mintTo(wallet, mintAmount);

        // Validate that the balance did not increase
        assertEq(usds.balanceOf(wallet), 0);
    }


	// A unit test where a call is made to shouldBurnMoreUSDS function without calling the setCollateral function first. This test will validate that before the burn operation can be made, the Collateral contract has to be set.
    function testShouldBurnMoreUSDSWithoutCollateralSet() public {
        uint256 usdsToBurn = 1 ether;

        // New USDS instance in case Collateral was set in the deployed version already
        USDS newUSDS = new USDS(priceAggregator, stableConfig, wbtc, weth);

        // Expect revert as the Collateral contract is not set yet
        vm.expectRevert("Not the Collateral contract");
        newUSDS.shouldBurnMoreUSDS(usdsToBurn);
    }

	// A unit test to check if an incorrect or zero address is provided to the constructor of USDS. The test should fail since these addresses would be invalid.
	// A unit test to check if an incorrect or zero address is provided to the constructor of USDS.
    function testInvalidAddressInConstructor() public {
        address zeroAddress = address(0);
        address wbtcAddress = address(0x1111); // Suppose this is a valid wbtc address
        address wethAddress = address(0x2222); // Suppose this is a valid weth address

        // Test with zero address as priceAggregator
        vm.expectRevert("_priceAggregator cannot be address(0)");
        USDS newUSDS = new USDS(IPriceAggregator(zeroAddress), IStableConfig(zeroAddress), IERC20(wbtcAddress), IERC20(wethAddress));

        // Test with zero address as stableConfig
        vm.expectRevert("_stableConfig cannot be address(0)");
        newUSDS = new USDS(priceAggregator, IStableConfig(zeroAddress), IERC20(wbtcAddress), IERC20(wethAddress));

        // Test with zero address as wbtc
        vm.expectRevert("_wbtc cannot be address(0)");
        newUSDS = new USDS(priceAggregator, stableConfig, IERC20(zeroAddress), IERC20(wethAddress));

        // Test with zero address as weth
        vm.expectRevert("_weth cannot be address(0)");
        newUSDS = new USDS(priceAggregator, stableConfig, IERC20(wbtcAddress), IERC20(zeroAddress));
    }


	// A unit test which tries to mint USDS to a zero address. The test should fail since minting to zero addresses should be prohibited.
    function testMintToZeroAddress() public {
        address zeroAddress = address(0);
        uint256 mintAmount = 1 ether;

        // Attempt to mint to a zero address
        vm.expectRevert("Cannot mint to address(0)");
        vm.prank(address(collateral));
        usds.mintTo(zeroAddress, mintAmount);
    }

	// A unit test which tries to mint a zero amount of USDS. The test should not increase the total supply of the USDS.
    function testMintZeroUSDS() public {
        address wallet = address(0x7777);
        uint256 zeroAmount = 0 ether;

        // Store the total supply before minting
        uint256 totalSupplyBeforeMint = usds.totalSupply();

        // Try minting zero USDS from the collateral address
        vm.prank(address(collateral));
        usds.mintTo(wallet, zeroAmount);

        // The balance of the wallet should not increase
        assertEq(usds.balanceOf(wallet), 0 ether);

        // The total supply of USDS should not increase
        assertEq(usds.totalSupply(), totalSupplyBeforeMint);
    }


	// A unit test that sets an invalid or zero address for the Pools contract.
    function testSetInvalidPoolsAddress() public {
        // New USDS in case Pools was set in the deployed version already
        usds = new USDS(priceAggregator, stableConfig, wbtc, weth);

        // Attempt to set the pools address to an invalid or zero address
        vm.expectRevert("_pools cannot be address(0)");
        usds.setPools(IPools(address(0)));

        // Validate that the pools address did not change
        assertEq(address(usds.pools()), address(0));
    }


	// A unit test to check for integer overflow/underflow in burn, and mint functions.
	// A unit test to check for integer overflow/underflow in burn, mint, and swap functions.
    function testCheckForIntegerOverflowUnderflow() public {
        vm.startPrank(address(collateral));

        uint256 maxUint = type(uint256).max;
        address wallet = address(0x7777);

        // Test overflow in mintTo function
        usds.mintTo(wallet, maxUint);

        vm.expectRevert();
        usds.mintTo(wallet, 1);

        // Test underflow in shouldBurnMoreUSDS function
        vm.prank(address(collateral));
        usds.shouldBurnMoreUSDS(maxUint);

        vm.expectRevert();
        usds.shouldBurnMoreUSDS(1);
    }

	// A unit test calling performUpkeep when usdsThatShouldBeBurned is 0. It should return immediately and not perform any action.
    function testPerformUpkeepWithNoUsdsToBurn() public {
    	// Ensure that usdsThatShouldBeBurned is 0
    	assertEq(usds.usdsThatShouldBeBurned(), 0 ether);

    	// Capture the initial balances
    	uint256 initialUsdsBalance = usds.balanceOf(address(usds));
    	uint256 initialWbtcBalance = wbtc.balanceOf(address(usds));
    	uint256 initialWethBalance = weth.balanceOf(address(usds));

    	// Call performUpkeep
    	usds.performUpkeep();

    	// Check that balances have not changed
    	assertEq(usds.balanceOf(address(usds)), initialUsdsBalance);
    	assertEq(wbtc.balanceOf(address(usds)), initialWbtcBalance);
    	assertEq(weth.balanceOf(address(usds)), initialWethBalance);

    	// Check that usdsThatShouldBeBurned is still 0
    	assertEq(usds.usdsThatShouldBeBurned(), 0 ether);
    }


	// A unit test that checks USDS balance more than usdsThatShouldBeBurned when performUpkeep called, and confirm USDS.totalSupply is adjusted accordingly
    function testUSDSBalanceMoreThanBurnedOnUpkeep() public {
        uint256 initialUSDS = 10 ether;
        uint256 usdsToBurn = 5 ether;

        // Set up a new instance of USDS and set collateral
        // Mint some USDS to the contract itself
        vm.prank(address(collateral));
        usds.mintTo(address(usds), initialUSDS);

        // Set the amount of USDS that should be burned
        vm.prank(address(collateral));
        usds.shouldBurnMoreUSDS(usdsToBurn);

        // The balance of USDS should be equal to the initial amount
        assertEq(usds.balanceOf(address(usds)), initialUSDS);
        assertEq(usds.totalSupply(), initialUSDS);

        // The amount of USDS that should be burned should be equal to usdsToBurn
        assertEq(usds.usdsThatShouldBeBurned(), usdsToBurn);

        // Call performUpkeep
        usds.performUpkeep();

        // The balance of USDS should be equal to the initial amount minus the amount that should have been burned
        assertEq(usds.balanceOf(address(usds)), initialUSDS - usdsToBurn);
        assertEq(usds.totalSupply(), initialUSDS - usdsToBurn);

        // The amount of USDS that should be burned should be 0 now
        assertEq(usds.usdsThatShouldBeBurned(), 0);
    }


	// A unit test that checks USDS balance is less than usdsThatShouldBeBurned and WBTC and WETH sufficient to cover usdsThatShouldBeBurned when performUpkeep called.  Checks that the amount swapped compared to the PriceAggregator prices, and amount burned are correct.
	function testPerformUpkeepWithInsufficientUSDSAndSufficientWBTC_WETH() public {
        uint256 usdsToBurn = 500 ether;
        uint256 wbtcDeposit = 1 *10**8; // WBTC has 8 decimals
        uint256 wethDeposit = 10 ether;  // WETH has 18 decimals

		// PriceAggregator returns prices with 18 decimals
		priceAggregator.performUpkeep();
		uint256 btcPrice = priceAggregator.getPriceBTC();
        uint256 ethPrice = priceAggregator.getPriceETH();

        // Set up USDS.usdsToBurn
        vm.prank(address(collateral));
        usds.shouldBurnMoreUSDS(usdsToBurn);
        assertEq(usds.usdsThatShouldBeBurned(), usdsToBurn);

        // USDS contract initially starts with zero USDS
        assertEq(usds.balanceOf(address(usds)), 0);

		// Set up the BTC/USDS pools
        vm.prank(address(collateral));
        usds.mintTo(address(DEPLOYER), 1234567 ether);

        vm.startPrank(DEPLOYER);
		usds.approve( address(pools), type(uint256).max );
		wbtc.approve( address(pools), type(uint256).max );
		weth.approve( address(pools), type(uint256).max );

		pools.addLiquidity( wbtc, usds, 10 *10**8, 10 * btcPrice, 0, block.timestamp );
		pools.addLiquidity( weth, usds, 100 ether, 100 * ethPrice, 0, block.timestamp );

        // Deposit WBTC and WETH into this contract (to simulate WBTC/WETH transfer here from liquidated collateral)
        wbtc.transfer(address(usds), wbtcDeposit);
        weth.transfer(address(usds), wethDeposit);

		vm.stopPrank();

        // Ensure that the USDS balance is less than the amount that should be burned
        assert(usds.balanceOf(address(this)) < usdsToBurn);

        // Perform upkeep
        uint256 initialTotalSupply = usds.totalSupply();
        usds.performUpkeep();

		// Check that 5% of the WBTC and WETH in the contract was converted to USDS
        uint256 usdsBurned = initialTotalSupply - usds.totalSupply();

		// Check usdsBurned is correct
		assertEq( usdsBurned, usdsToBurn, "Incorrect amount of USDS burned" );
    }


   	// A unit test that checks USDS balance less than usdsThatShouldBeBurned and WBTC and WETH insufficient to cover usdsThatShouldBeBurned when performUpkeep called
	function testPerformUpkeepWithInsufficientUSDSAndInsufficientWBTC_WETH() public {
        uint256 usdsToBurn = 50000 ether;
        uint256 wbtcDeposit = 1 *10**8; // WBTC has 8 decimals
        uint256 wethDeposit = 10 ether;  // WETH has 18 decimals

		// PriceAggregator returns prices with 18 decimals
		uint256 btcPrice = priceAggregator.getPriceBTC();
        uint256 ethPrice = priceAggregator.getPriceETH();

        // Set up USDS.usdsToBurn
        vm.prank(address(collateral));
        usds.shouldBurnMoreUSDS(usdsToBurn);
        assertEq(usds.usdsThatShouldBeBurned(), usdsToBurn);

        // USDS contract initially starts with zero USDS
        assertEq(usds.balanceOf(address(usds)), 0);

		// Set up the BTC/USDS pools
        vm.prank(address(collateral));
        usds.mintTo(address(DEPLOYER), 100000000 ether);

        vm.startPrank(DEPLOYER);
		usds.approve( address(pools), type(uint256).max );
		wbtc.approve( address(pools), type(uint256).max );
		weth.approve( address(pools), type(uint256).max );

		pools.addLiquidity( wbtc, usds, 100 *10**8, 100 * btcPrice, 0, block.timestamp );
		pools.addLiquidity( weth, usds, 1000 ether, 1000 * ethPrice, 0, block.timestamp );

        // Deposit WBTC and WETH into this contract (to simulate WBTC/WETH transfer here from liquidated collateral)
        wbtc.transfer(address(usds), wbtcDeposit);
        weth.transfer(address(usds), wethDeposit);

		vm.stopPrank();

        // Ensure that the USDS balance is less than the amount that should be burned
        assert(usds.balanceOf(address(this)) < usdsToBurn);

        // Perform upkeep
        uint256 initialTotalSupply = usds.totalSupply();
        usds.performUpkeep();

		// Check that 5% of the WBTC and WETH in the contract was converted to USDS
        uint256 usdsBurned = initialTotalSupply - usds.totalSupply();
		uint256 shouldHaveBurned = ( wbtcDeposit * 5 / 100 ) * btcPrice / 10**8 + ( wethDeposit * 5 / 100 ) * ethPrice / 10**18;

		// Check usdsBurned is correct within .10%
		assertTrue( usdsBurned >= shouldHaveBurned - shouldHaveBurned * 1 / 1000, "Incorrect amount of USDS burned" );
		assertTrue( usdsBurned <= shouldHaveBurned + shouldHaveBurned * 1 / 1000, "Incorrect amount of USDS burned" );
    }



	// A unit test that checks that BTC and ETH are not swapped if slippage is too high compared to what the PriceAggregator is showing pricewise.
	function testPerformUpkeepWithSkewedPriceFeedPrices() public {
 	       uint256 usdsToBurn = 500 ether;
            uint256 wbtcDeposit = 1 *10**8; // WBTC has 8 decimals
            uint256 wethDeposit = 10 ether;  // WETH has 18 decimals

    		// Skew the BTC price so that the swap fails
    		uint256 btcPrice0 = priceAggregator.getPriceBTC();
			uint256 ethPrice0 = priceAggregator.getPriceETH();

    		uint256 btcPrice = btcPrice0 - btcPrice0 * 11 / 1000;
            uint256 ethPrice = ethPrice0 - ethPrice0 * 11 / 1000;

            // Set up USDS.usdsToBurn
            vm.prank(address(collateral));
            usds.shouldBurnMoreUSDS(usdsToBurn);
            assertEq(usds.usdsThatShouldBeBurned(), usdsToBurn);

            // USDS contract initially starts with zero USDS
            assertEq(usds.balanceOf(address(usds)), 0);

    		// Set up the BTC/USDS pools
            vm.prank(address(collateral));
            usds.mintTo(address(DEPLOYER), 1234567 ether);

            vm.startPrank(DEPLOYER);
    		usds.approve( address(pools), type(uint256).max );
    		wbtc.approve( address(pools), type(uint256).max );
    		weth.approve( address(pools), type(uint256).max );

    		pools.addLiquidity( wbtc, usds, 10 *10**8, 10 * btcPrice, 0, block.timestamp );
    		pools.addLiquidity( weth, usds, 100 ether, 100 * ethPrice, 0, block.timestamp );

            // Deposit WBTC and WETH into this contract (to simulate WBTC/WETH transfer here from liquidated collateral)
            wbtc.transfer(address(usds), wbtcDeposit);
            weth.transfer(address(usds), wethDeposit);

    		vm.stopPrank();

            // Ensure that the USDS balance is less than the amount that should be burned
            assert(usds.balanceOf(address(this)) < usdsToBurn);

            // Perform upkeep
            uint256 initialTotalSupply = usds.totalSupply();
            usds.performUpkeep();

            assertEq( initialTotalSupply, usds.totalSupply(), "USDS should not have been burned on performUpkeep()" );


            // Align the prices to reduce slippage below 1%
    		btcPrice = btcPrice0 - btcPrice0 * 7 / 1000;
            ethPrice = ethPrice0 - ethPrice0 * 7 / 1000;

			vm.startPrank(DEPLOYER);
            forcedPriceFeed.setBTCPrice( btcPrice );
            forcedPriceFeed.setETHPrice( ethPrice );
			priceAggregator.performUpkeep();
            vm.stopPrank();

            usds.performUpkeep();
            assertTrue( initialTotalSupply != usds.totalSupply(), "USDS should have been burned" );
        }


   	// A unit test that checks USDS balance less than usdsThatShouldBeBurned and WBTC and WETH insufficient to cover usdsThatShouldBeBurned when performUpkeep called
	function testPerformUpkeepWithInsufficientUSDSAndInsufficientWBTCandNoWETH() public {
        uint256 usdsToBurn = 50000 ether;
        uint256 wbtcDeposit = 1 *10**8; // WBTC has 8 decimals
        uint256 wethDeposit = 0 ether;  // WETH has 18 decimals

		// PriceAggregator returns prices with 18 decimals
		uint256 btcPrice = priceAggregator.getPriceBTC();
        uint256 ethPrice = priceAggregator.getPriceETH();

        // Set up USDS.usdsToBurn
        vm.prank(address(collateral));
        usds.shouldBurnMoreUSDS(usdsToBurn);
        assertEq(usds.usdsThatShouldBeBurned(), usdsToBurn);

        // USDS contract initially starts with zero USDS
        assertEq(usds.balanceOf(address(usds)), 0);

		// Set up the BTC/USDS pools
        vm.prank(address(collateral));
        usds.mintTo(address(DEPLOYER), 100000000 ether);

        vm.startPrank(DEPLOYER);
		usds.approve( address(pools), type(uint256).max );
		wbtc.approve( address(pools), type(uint256).max );
		weth.approve( address(pools), type(uint256).max );

		pools.addLiquidity( wbtc, usds, 100 *10**8, 100 * btcPrice, 0, block.timestamp );
		pools.addLiquidity( weth, usds, 1000 ether, 1000 * ethPrice, 0, block.timestamp );

        // Deposit WBTC and WETH into this contract (to simulate WBTC/WETH transfer here from liquidated collateral)
        wbtc.transfer(address(usds), wbtcDeposit);
//        weth.transfer(address(usds), wethDeposit);

		vm.stopPrank();

        // Ensure that the USDS balance is less than the amount that should be burned
        assert(usds.balanceOf(address(this)) < usdsToBurn);

        // Perform upkeep
        uint256 initialTotalSupply = usds.totalSupply();
        usds.performUpkeep();

		// Check that 5% (percentSwapToUSDS) of the WBTC and WETH in the contract was converted to USDS
        uint256 usdsBurned = initialTotalSupply - usds.totalSupply();

        // Convert to 18 decimals (wbtcDeposit has 8 decimals and wethDeposit has 18 decimals)
		uint256 shouldHaveBurned = ( wbtcDeposit * 5 / 100 ) * btcPrice / 10**8 + ( wethDeposit * 5 / 100 ) * ethPrice / 10**18;

		// Check usdsBurned is correct within .10%
		assertTrue( usdsBurned >= shouldHaveBurned - shouldHaveBurned * 1 / 1000, "Incorrect amount of USDS burned" );
		assertTrue( usdsBurned <= shouldHaveBurned + shouldHaveBurned * 1 / 1000, "Incorrect amount of USDS burned" );
    }


	// A unit test that calls performUpkeep over multiple cycles to validate that the state transitions correctly across cycles. This test would involve multiple calls to performUpkeep() with a changing state (usdsToBurn) and checks the appropriate amount of burning in each cycle.
    function testPerformUpkeepCalledTwice() public {
        uint256 usdsToBurn = 50000 ether;
        uint256 wbtcDeposit = 1 *10**8; // WBTC has 8 decimals
        uint256 wethDeposit = 10 ether;  // WETH has 18 decimals

		// PriceAggregator returns prices with 18 decimals
		uint256 btcPrice = priceAggregator.getPriceBTC();
        uint256 ethPrice = priceAggregator.getPriceETH();

        // Set up USDS.usdsToBurn
        vm.prank(address(collateral));
        usds.shouldBurnMoreUSDS(usdsToBurn);
        assertEq(usds.usdsThatShouldBeBurned(), usdsToBurn);

        // USDS contract initially starts with zero USDS
        assertEq(usds.balanceOf(address(usds)), 0);

		// Set up the BTC/USDS pools
        vm.prank(address(collateral));
        usds.mintTo(address(DEPLOYER), 100000000 ether);

        vm.startPrank(DEPLOYER);
		usds.approve( address(pools), type(uint256).max );
		wbtc.approve( address(pools), type(uint256).max );
		weth.approve( address(pools), type(uint256).max );

		pools.addLiquidity( wbtc, usds, 100 *10**8, 100 * btcPrice, 0, block.timestamp );
		pools.addLiquidity( weth, usds, 1000 ether, 1000 * ethPrice, 0, block.timestamp );

        // Deposit WBTC and WETH into this contract (to simulate WBTC/WETH transfer here from liquidated collateral)
        wbtc.transfer(address(usds), wbtcDeposit);
        weth.transfer(address(usds), wethDeposit);

		vm.stopPrank();

        // Ensure that the USDS balance is less than the amount that should be burned
        assert(usds.balanceOf(address(this)) < usdsToBurn);

        // Call performUpkeep twice
        uint256 initialTotalSupply = usds.totalSupply();

        usds.performUpkeep();
        usds.performUpkeep();

		// Check that 5% of the WBTC and WETH in the contract was converted to USDS
        uint256 usdsBurned = initialTotalSupply - usds.totalSupply();
		uint256 shouldHaveBurned = ( wbtcDeposit * 975 / 10000 ) * btcPrice / 10**8 + ( wethDeposit * 975 / 10000 ) * ethPrice / 10**18;

		// Check usdsBurned is correct within .10%
		assertTrue( usdsBurned >= shouldHaveBurned - shouldHaveBurned * 1 / 1000, "Incorrect amount of USDS burned" );
		assertTrue( usdsBurned <= shouldHaveBurned + shouldHaveBurned * 1 / 1000, "Incorrect amount of USDS burned" );
    }


	// A unit test that mints USDS to multiple user accounts from the collateral contract. It should mint different amounts of USDS to multiple user accounts with validations after each minting operation.
	function testMintUSDSMultipleAccounts() public {
        // Define the user accounts and the amount of USDS to mint to each account
        address[] memory users = new address[](3);
        users[0] = address(0x1111); // alice
        users[1] = address(0x2222); // bob
        users[2] = address(0x3333); // charlie

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 3 ether;
        amounts[1] = 2 ether;
        amounts[2] = 1 ether;

        // Mint USDS to each user account from the collateral contract
        vm.startPrank(address(collateral));
        for(uint i = 0; i < users.length; i++)
        	{
            usds.mintTo(users[i], amounts[i]);
            assertEq(usds.balanceOf(users[i]), amounts[i]);
        	}
	    }


	// A unit test that checks setting usdsToBurn to very small and very large values to test edge cases.
    function testSetUsdsToBurnEdgeCases() public {
        uint256 smallAmount = 1;  // smallest non-zero value
        uint256 largeAmount = 10**30 * 1 ether;  // arbitrarily large value

        // Test with very small amount
        vm.prank(address(collateral));
        usds.shouldBurnMoreUSDS(smallAmount);
        assertEq(usds.usdsThatShouldBeBurned(), smallAmount);

        // Test with very large amount
        vm.prank(address(collateral));
        usds.shouldBurnMoreUSDS(largeAmount);
        assertEq(usds.usdsThatShouldBeBurned(), smallAmount + largeAmount);
    }

	//	A unit test that passes a random address to setCollateral. This test should validate that only the correct address can set the collateral.
	function testOnlyCorrectAddressCanSetCollateral() public {
        address correctAddress = address(0x5555);
        address randomAddress = address(0x6666);

        // New USDS in case Collateral was set in the deployed version already
        usds = new USDS(priceAggregator, stableConfig, wbtc, weth);

        // Set up the correct address as the collateral address
        vm.prank(DEPLOYER);
        usds.setCollateral(ICollateral(correctAddress));
        assertEq(address(usds.collateral()), address(correctAddress));

        // Try to set the collateral address from a random address
        vm.expectRevert("setCollateral can only be called once");
        vm.prank(randomAddress);
        usds.setCollateral(ICollateral(randomAddress));

        // Validate that the collateral address did not change
        assertEq(address(usds.collateral()), address(correctAddress));
    }


	//	A unit test that passes a random address to setPools. This test should validate that only the correct address can set the pools.
    function testSetPoolsOnlyOwner() public {
        address firstAddress = address(0x5555);
        address secondAddress = address(0x6666);

        // New USDS in case Pools was set in the deployed version already
        usds = new USDS(priceAggregator, stableConfig, wbtc, weth);

        // Initial set up
        assertEq(address(usds.pools()), address(0));

        // Try setting the pools address for the first time
        usds.setPools(IPools(firstAddress));
        assertEq(address(usds.pools()), address(firstAddress));

        // Attempt to set the pools address from a different address
        vm.expectRevert("setPools can only be called once");
        vm.prank(secondAddress);
        usds.setPools(IPools(secondAddress));

        // Validate that the pools address did not change
        assertEq(address(usds.pools()), address(firstAddress));
    }


	//	A unit test that burns 0 amount. Total supply should not change.
	function testBurnZeroAmount() public {
        uint256 initialSupply = usds.totalSupply();
        uint256 burnAmount = 0 ether;

        // Prank as the collateral contract to pass the sender check
        vm.prank(address(collateral));

        // Indicate that 0 USDS should be burned
        usds.shouldBurnMoreUSDS(burnAmount);

        // Perform upkeep which should burn the indicated amount
        usds.performUpkeep();

        // Check that the total supply did not change
        assertEq(usds.totalSupply(), initialSupply);
    }
	}
