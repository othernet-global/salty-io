// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "../../dev/Deployment.sol";


contract LiquidizerTest is Deployment
	{
	constructor()
		{
		// If $COVERAGE=yes, create an instance of the contract so that coverage testing can work
		// Otherwise, what is tested is the actual deployed contract on the blockchain (as specified in Deployment.sol)
		if ( keccak256(bytes(vm.envString("COVERAGE" ))) == keccak256(bytes("yes" )))
			initializeContracts();

		grantAccessAlice();
		grantAccessBob();
		grantAccessCharlie();
		grantAccessDeployer();
		grantAccessDefault();

		finalizeBootstrap();
		}


	// // A unit test in which the collateral address is set for the first time. This test should validate that the collateral address is correctly updated and can only be set once.
	function testSetContractsOnlyOnce() public
		{
		address _collateral = address(0x5555);
		address _pools = address(0x6666);
		address _dao = address(0x7777);

		// New USDS in case CollateralAndLiquidity.sol was set in the deployed version already
		liquidizer = new Liquidizer(exchangeConfig, poolsConfig);

		liquidizer.setContracts( ICollateralAndLiquidity(_collateral), IPools(_pools), IDAO(_dao) );

		address invalid = address(0xdead);

		vm.expectRevert("Ownable: caller is not the owner");
		liquidizer.setContracts( ICollateralAndLiquidity(invalid), IPools(invalid), IDAO(invalid) );
	}


	// A unit test where an attempt is made to burn more USD than is available in the contract.
	function testBurnMoreThanAvailable() public {
        uint256 usdsToBurn = 2 ether; // Amount greater than current balance

        assertEq(liquidizer.usdsThatShouldBeBurned(), 0 ether);

        // Try burning more than available
        vm.prank(address(collateralAndLiquidity));
        liquidizer.incrementBurnableUSDS(usdsToBurn);

        // Validate that the amount that should be burnt is set correctly
        assertEq(liquidizer.usdsThatShouldBeBurned(), usdsToBurn);
}

	// A unit test to confirm that calling `performUpkeep` with no WBTC, WETH, DAI, or SALT in the contract's balance does not revert and does nothing.
	function testPerformUpkeepWithNoTokens() public {
        // Ensure that the contract has no WBTC, WETH, DAI, or SALT before calling performUpkeep
        assertEq(wbtc.balanceOf(address(liquidizer)), 0, "WBTC balance should be 0");
        assertEq(weth.balanceOf(address(liquidizer)), 0, "WETH balance should be 0");
        assertEq(dai.balanceOf(address(liquidizer)), 0, "DAI balance should be 0");
        assertEq(salt.balanceOf(address(liquidizer)), 0, "SALT balance should be 0");

        // Perform upkeep with no balances
        vm.prank(address(upkeep));
        liquidizer.performUpkeep();

        // Check if balances and state remain unchanged
        assertEq(wbtc.balanceOf(address(liquidizer)), 0, "WBTC balance should remain 0");
        assertEq(weth.balanceOf(address(liquidizer)), 0, "WETH balance should remain 0");
        assertEq(dai.balanceOf(address(liquidizer)), 0, "DAI balance should remain 0");
        assertEq(salt.balanceOf(address(liquidizer)), 0, "SALT balance should remain 0");
        assertEq(usds.balanceOf(address(liquidizer)), 0, "USDS balance should remain 0");
        assertEq(liquidizer.usdsThatShouldBeBurned(), 0, "usdsThatShouldBeBurned should remain unchanged");
    }


    // A unit test to confirm that `incrementBurnableUSDS` correctly aggregates multiple calls to increase `usdsThatShouldBeBurned`.
function testAggregatesMultipleCallsToincrementBurnableUSDS() public {
    uint256 firstUsdsToBurn = 1 ether;
    uint256 secondUsdsToBurn = 2 ether;
    uint256 thirdUsdsToBurn = 3 ether;

    // Initially the usdsThatShouldBeBurned should be 0
    assertEq(liquidizer.usdsThatShouldBeBurned(), 0 ether);

    // Call incrementBurnableUSDS multiple times and check if the USDS amount to be burned aggregates
    vm.prank(address(collateralAndLiquidity));
    liquidizer.incrementBurnableUSDS(firstUsdsToBurn);
    assertEq(liquidizer.usdsThatShouldBeBurned(), firstUsdsToBurn);

    vm.prank(address(collateralAndLiquidity));
    liquidizer.incrementBurnableUSDS(secondUsdsToBurn);
    assertEq(liquidizer.usdsThatShouldBeBurned(), firstUsdsToBurn + secondUsdsToBurn);

    vm.prank(address(collateralAndLiquidity));
    liquidizer.incrementBurnableUSDS(thirdUsdsToBurn);
    assertEq(liquidizer.usdsThatShouldBeBurned(), firstUsdsToBurn + secondUsdsToBurn + thirdUsdsToBurn);
        }


    // A unit test to verify the successful increase in USDS balance after `performUpkeep` swaps WBTC, WETH, or DAI when USDS balance is initially zero.
    function testSuccessfulBalanceIncreaseAfterPerformUpkeep() public {

		vm.prank(address(collateralAndLiquidity));
		usds.mintTo(DEPLOYER, 100000000 ether );

		vm.startPrank(DEPLOYER);
		wbtc.approve(address(collateralAndLiquidity), type(uint256).max);
		weth.approve(address(collateralAndLiquidity), type(uint256).max);
		dai.approve(address(collateralAndLiquidity), type(uint256).max);
		usds.approve(address(collateralAndLiquidity), type(uint256).max);

		collateralAndLiquidity.depositLiquidityAndIncreaseShare(wbtc, usds, 1000 * 10**8, 30000 * 1000 ether, 0, block.timestamp, false );
		collateralAndLiquidity.depositLiquidityAndIncreaseShare(weth, usds, 1000 ether, 3000 * 1000 ether, 0, block.timestamp, false );
		collateralAndLiquidity.depositLiquidityAndIncreaseShare(dai, usds, 100000 ether, 100000 ether, 0, block.timestamp, false );

        uint256 initialBalance = usds.balanceOf(address(liquidizer));
        assertEq(initialBalance, 0, "Initial USDS balance should be 0");

        // Simulate external conditions - deposit WBTC/WETH/DAI into the Liquidizer contract
        uint256 wbtcAmount = 1 * 10**8;
        uint256 wethAmount = 1 ether;
        uint256 daiAmount = 1000 ether;

        // Transfer tokens to Liquidizer for swapping
        wbtc.transfer(address(liquidizer), wbtcAmount);
        weth.transfer(address(liquidizer), wethAmount);
        dai.transfer(address(liquidizer), daiAmount);

        // Check that the Liquidizer received the tokens
        assertEq(wbtc.balanceOf(address(liquidizer)), wbtcAmount, "Liquidizer should hold WBTC");
        assertEq(weth.balanceOf(address(liquidizer)), wethAmount, "Liquidizer should hold WETH");
        assertEq(dai.balanceOf(address(liquidizer)), daiAmount, "Liquidizer should hold DAI");

        // Perform the upkeep call to swap tokens to USDS
        vm.startPrank(address(exchangeConfig.upkeep()));
        liquidizer.performUpkeep();
        vm.stopPrank();

        // Check that all WBTC/WETH/DAI has been swapped to USDS (balances are zero and USDS balance increased)
        assertEq(wbtc.balanceOf(address(liquidizer)), 0, "WBTC balance after upkeep should be 0");
        assertEq(weth.balanceOf(address(liquidizer)), 0, "WETH balance after upkeep should be 0");
        assertEq(dai.balanceOf(address(liquidizer)), 0, "DAI balance after upkeep should be 0");

        uint256 newUsdsBalance = usds.balanceOf(address(liquidizer));
        assertEq(newUsdsBalance, 33957131976933957131976, "USDS balance should have increased");
    }


    // A unit test to ensure that the withdrawal of Protocol Owned Liquidity updates the DAO's POL balance appropriately.
	function testWithdrawalOfPOLUpdatesDAOsPOLBalance() public {

		// Originally no tokens in the liquidizer
		assertEq( salt.balanceOf(address(liquidizer)), 0 );
		assertEq( usds.balanceOf(address(liquidizer)), 0 );
		assertEq( dai.balanceOf(address(liquidizer)), 0 );


		vm.prank(address(collateralAndLiquidity));
		usds.mintTo(address(dao), 1000000 ether);

		vm.prank(address(teamVestingWallet));
		salt.transfer(address(dao), 100000 ether);

		vm.prank(DEPLOYER);
		dai.transfer(address(dao), 100000 ether);

        vm.startPrank(address(dao));
		collateralAndLiquidity.depositLiquidityAndIncreaseShare(salt, usds, 100000 ether, 100000 ether, 0, block.timestamp, false );
		collateralAndLiquidity.depositLiquidityAndIncreaseShare(dai, usds, 100000 ether, 100000 ether, 0, block.timestamp, false );
		vm.stopPrank();

		bytes32 poolIDA = PoolUtils._poolID(salt, usds);
		bytes32 poolIDB = PoolUtils._poolID(dai, usds);

		assertEq( collateralAndLiquidity.userShareForPool(address(dao), poolIDA), 200000 ether);
		assertEq( collateralAndLiquidity.userShareForPool(address(dao), poolIDB), 200000 ether);

        // Simulate shortfall in burning USDS
        uint256 shortfallAmount = 10 ether;
		vm.prank(address(collateralAndLiquidity));
        liquidizer.incrementBurnableUSDS(shortfallAmount);  // Assuming a setter for easy testing

        // The test is setup to cause a withdrawal of POL
		vm.prank(address(upkeep));
        liquidizer.performUpkeep();

		// Check that 1% of the POL has been withdrawn
		assertEq( collateralAndLiquidity.userShareForPool(address(dao), poolIDA), 198000 ether);
		assertEq( collateralAndLiquidity.userShareForPool(address(dao), poolIDB), 198000 ether);

		// Check that the withdrawn POL is now in the Liquidizer
		assertEq( salt.balanceOf(address(liquidizer)), 1000 ether );
		assertEq( usds.balanceOf(address(liquidizer)), 2000 ether );
		assertEq( dai.balanceOf(address(liquidizer)), 1000 ether );
    }


  	// A unit test to verify that calling `performUpkeep` with various balances of WBTC, WETH, and DAI results in no more than the specified percentage being swapped as per `maximumInternalSwapPercentTimes1000`.
    function testSuccessfulBalanceIncreaseAfterPerformUpkeepWithLimit() public {

		vm.prank(address(collateralAndLiquidity));
		usds.mintTo(DEPLOYER, 100000000 ether );

		vm.startPrank(DEPLOYER);
		wbtc.approve(address(collateralAndLiquidity), type(uint256).max);
		weth.approve(address(collateralAndLiquidity), type(uint256).max);
		dai.approve(address(collateralAndLiquidity), type(uint256).max);
		usds.approve(address(collateralAndLiquidity), type(uint256).max);

		collateralAndLiquidity.depositLiquidityAndIncreaseShare(wbtc, usds, 1000 * 10**8, 30000 * 1000 ether, 0, block.timestamp, false );
		collateralAndLiquidity.depositLiquidityAndIncreaseShare(weth, usds, 1000 ether, 3000 * 1000 ether, 0, block.timestamp, false );
		collateralAndLiquidity.depositLiquidityAndIncreaseShare(dai, usds, 100000 ether, 100000 ether, 0, block.timestamp, false );

        uint256 initialBalance = usds.balanceOf(address(liquidizer));
        assertEq(initialBalance, 0, "Initial USDS balance should be 0");

        // Simulate external conditions - deposit WBTC/WETH/DAI into the Liquidizer contract
        uint256 wbtcAmount = 100 * 10**8;
        uint256 wethAmount = 100 ether;
        uint256 daiAmount = 100000 ether;

        // Transfer tokens to Liquidizer for swapping
        wbtc.transfer(address(liquidizer), wbtcAmount);
        weth.transfer(address(liquidizer), wethAmount);
        dai.transfer(address(liquidizer), daiAmount);

        // Check that the Liquidizer received the tokens
        assertEq(wbtc.balanceOf(address(liquidizer)), wbtcAmount, "Liquidizer should hold WBTC");
        assertEq(weth.balanceOf(address(liquidizer)), wethAmount, "Liquidizer should hold WETH");
        assertEq(dai.balanceOf(address(liquidizer)), daiAmount, "Liquidizer should hold DAI");

        // Perform the upkeep call to swap tokens to USDS
        vm.startPrank(address(exchangeConfig.upkeep()));
        liquidizer.performUpkeep();
        vm.stopPrank();

        // Check that all WBTC/WETH/DAI has been swapped to USDS (balances are zero and USDS balance increased)
        assertEq(wbtc.balanceOf(address(liquidizer)), 9000000000, "WBTC balance after upkeep should exist");
        assertEq(weth.balanceOf(address(liquidizer)), 90000000000000000000, "WETH balance after upkeep should exist");
        assertEq(dai.balanceOf(address(liquidizer)), 99000000000000000000000, "DAI balance after upkeep should exist");

        uint256 newUsdsBalance = usds.balanceOf(address(liquidizer));
        assertEq(newUsdsBalance, 327722772277227722772276, "USDS balance should have increased after selling 1% of the sent tokens");
    }


    // A unit test to confirm that no USDS burning occurs during performUpkeep if `usdsThatShouldBeBurned` is zero.
    function testNoUsdsBurnWhenShouldBeZero() public {
        // Ensure that usdsThatShouldBeBurned is zero
        assertEq(liquidizer.usdsThatShouldBeBurned(), 0, "usdsThatShouldBeBurned should be zero");

		uint256 supply = usds.totalSupply();

        // Perform upkeep
        vm.prank(address(upkeep));
        liquidizer.performUpkeep();

		assertEq( usds.totalSupply(), supply );
    }


    // A unit test to check the functionality of `_possiblyBurnUSDS` when there is enough USDS balance to partially burn `usdsThatShouldBeBurned`.
    function testPossiblyBurnUSDSPartial() public {
        uint256 initialUSDSBalance = 5 ether; // Assuming that the contract starts with this balance
        uint256 usdsRequiredToBurn = 7 ether; // We want to burn more than the initial balance
        uint256 expectedUSDSLeftToBurn = usdsRequiredToBurn - initialUSDSBalance;

        // Mint USDS to the liquidizer contract to set an initial balance
        vm.prank(address(collateralAndLiquidity));
        usds.mintTo(address(liquidizer), initialUSDSBalance);

        assertEq(usds.balanceOf(address(liquidizer)), initialUSDSBalance, "Initial USDS balance incorrect");

        // Set the USDS that should be burned to a higher number than the balance
        vm.prank(address(collateralAndLiquidity));
        liquidizer.incrementBurnableUSDS(usdsRequiredToBurn);

        assertEq(liquidizer.usdsThatShouldBeBurned(), usdsRequiredToBurn, "usdsThatShouldBeBurned should be set");

        // Perform the action to partially burn USDS
        vm.prank(address(upkeep));
        liquidizer.performUpkeep();

        // All USDS will be burned
        assertEq(usds.balanceOf(address(liquidizer)), 0, "Not all available USDS burned");

        // The usdsThatShouldBeBurned should be reduced by the amount that was available to burn
        assertEq(liquidizer.usdsThatShouldBeBurned(), expectedUSDSLeftToBurn, "Not all available USDS was counted as burned");
    }


    // A unit test to ensure that calling `incrementBurnableUSDS` with zero value does not affect `usdsThatShouldBeBurned`.
    function testCallingincrementBurnableUSDSWithZeroDoesNotAffectUsdsThatShouldBeBurned() public {
        // Initially `usdsThatShouldBeBurned` should be 0
        assertEq(liquidizer.usdsThatShouldBeBurned(), 0 ether);

        // Call `incrementBurnableUSDS` with 0 ether
        vm.prank(address(collateralAndLiquidity));
        liquidizer.incrementBurnableUSDS(0 ether);  // This call is expected to be safe and not revert because it's called by `collateralAndLiquidity`

        // Validate that `usdsThatShouldBeBurned` is still 0
        assertEq(liquidizer.usdsThatShouldBeBurned(), 0 ether, "Calling incrementBurnableUSDS with zero should not affect usdsThatShouldBeBurned");
    }


    // A unit test to verify that `_possiblyBurnUSDS` can correctly handle a scenario where there is excessive USDS compared to usdsThatShouldBeBurned
    function testPossiblyBurnWithExtraUSDS() public {
        uint256 initialUSDSBalance = 7 ether; // Assuming that the contract starts with this balance
        uint256 usdsRequiredToBurn = 2 ether; // We want to burn more than the initial balance
        uint256 expectedUSDSLeft = initialUSDSBalance - usdsRequiredToBurn;

        // Mint USDS to the liquidizer contract to set an initial balance
        vm.prank(address(collateralAndLiquidity));
        usds.mintTo(address(liquidizer), initialUSDSBalance);

        assertEq(usds.balanceOf(address(liquidizer)), initialUSDSBalance, "Initial USDS balance incorrect");

        // Set the USDS that should be burned to a higher number than the balance
        vm.prank(address(collateralAndLiquidity));
        liquidizer.incrementBurnableUSDS(usdsRequiredToBurn);

        assertEq(liquidizer.usdsThatShouldBeBurned(), usdsRequiredToBurn, "usdsThatShouldBeBurned should be set");

        // Perform the action to partially burn USDS
        vm.prank(address(upkeep));
        liquidizer.performUpkeep();

        // All USDS will be burned
        assertEq(usds.balanceOf(address(liquidizer)), expectedUSDSLeft, "Not all available USDS burned");

        assertEq(liquidizer.usdsThatShouldBeBurned(), 0, "Shouldn't be any USDS left to burn");
    }


    // A unit test for validating that SALT tokens are not swapped for USDS but are burned directly, regardless of SALT pricing or pools configuration during `performUpkeep`.
	function testSALTNotSwappedButBurnedDuringUpkeep() public {
        // Preparing the test environment: Mint and send SALT to the contract
        uint256 saltAmount = 10 ether; // Replacing the SALT amount to test
        vm.prank(address(teamVestingWallet));
        salt.transfer(address(liquidizer), saltAmount);
        assertEq(salt.balanceOf(address(liquidizer)), saltAmount, "SALT balance should be set for test");

        // Perform the upkeep call
        vm.prank(address(upkeep));
        liquidizer.performUpkeep();

		assertEq( salt.totalBurned(), saltAmount );
        assertEq(salt.balanceOf(address(liquidizer)), 0);
    }


    // A unit test to confirm that the `setContracts` function fails when called by an address other than the owner
    function testSetContractsNotOwnerReverts() public {
        // Deploy a new Liquidizer contract so we can call setContracts
        Liquidizer newLiquidizer = new Liquidizer(exchangeConfig, poolsConfig);

        // Prepare the contract addresses that would be passed to setContracts
        ICollateralAndLiquidity _collateralAndLiquidity = ICollateralAndLiquidity(address(0x12345));
        IPools _pools = IPools(address(0x54321));
        IDAO _dao = IDAO(address(0xABCDEF));

        // Expect the transaction to revert due to the caller not being the owner of the new Liquidizer contract
        vm.expectRevert("Ownable: caller is not the owner");
        address nonOwner = address(0xBEEF);
        vm.prank(nonOwner);
        newLiquidizer.setContracts(_collateralAndLiquidity, _pools, _dao);
    }


    // A unit test to confirm that the `incrementBurnableUSDS` function fails when called by an address other than the CollateralAndLiquidity contract
    function testincrementBurnableUSDSRevertWhenNotCollateralAndLiquidity() public {
        uint256 usdsToBurn = 1 ether;

        vm.startPrank( address(0x1234));
        vm.expectRevert("Liquidizer.incrementBurnableUSDS is only callable from the CollateralAndLiquidity contract");
        liquidizer.incrementBurnableUSDS(usdsToBurn);
        vm.stopPrank();
    }


    // A unit test that ensures `performUpkeep` fails when called by an address other than the Upkeep contract
    function testPerformUpkeepNotByUpkeepContractShouldFail() public {
        address nonUpkeepAddress = address(0x1234); // an arbitrary address that is not the upkeep contract

        // We expect the transaction to revert with the specific error message
        vm.expectRevert("Liquidizer.performUpkeep is only callable from the Upkeep contract");
        vm.prank(nonUpkeepAddress);
        liquidizer.performUpkeep();
    }


    // A unit test that checks if `performUpkeep` correctly handles the burning of excess USDS in the contract
	function testPerformUpkeepBurnsExcessUSDS() public {
    		uint256 initialBalance = 10 ether; // Assuming initial USDS balance is 10 ether
    		uint256 usdsToBurn = 5 ether;  // USDS that should be burned is 5 ether

    		// Mint USDS to the contract
    		vm.prank(address(collateralAndLiquidity));
    		usds.mintTo(address(liquidizer), initialBalance);

    		// Set the USDS that should be burned to 5 ether
    		vm.prank(address(collateralAndLiquidity));
    		liquidizer.incrementBurnableUSDS(usdsToBurn);

    		// Perform upkeep
    		vm.prank(address(upkeep));
    		liquidizer.performUpkeep();

    		// Check that the excess USDS (5 ether) remains after burning 5 ether that should be burned
    		uint256 remainingBalance = usds.balanceOf(address(liquidizer));
    		assertEq(remainingBalance, initialBalance - usdsToBurn, "Remaining USDS balance should be 5 ether");

    		// Check that usdsThatShouldBeBurned is now 0 after burning
    		uint256 remainingUsdsToBeBurned = liquidizer.usdsThatShouldBeBurned();
    		assertEq(remainingUsdsToBeBurned, 0, "usdsThatShouldBeBurned should be 0 after burning");
    	}


	function _createLiquidity() internal
		{
		vm.prank(address(collateralAndLiquidity));
		usds.mintTo(DEPLOYER, 100000000 ether);

		vm.startPrank(DEPLOYER);
		wbtc.approve(address(collateralAndLiquidity), type(uint256).max);
		weth.approve(address(collateralAndLiquidity), type(uint256).max);
		usds.approve(address(collateralAndLiquidity), type(uint256).max);
		dai.approve(address(collateralAndLiquidity), type(uint256).max);

        // 1 WBTC = 10000 USDS
        // 1 WETH = 1000 USDS
        // 1 DAI = 1 USDS
		collateralAndLiquidity.depositLiquidityAndIncreaseShare(wbtc, usds, 1000 * 10**8, 10000000 ether, 0, block.timestamp, false);
		collateralAndLiquidity.depositLiquidityAndIncreaseShare(weth, usds, 10000 ether, 10000000 ether, 0, block.timestamp, false);
		collateralAndLiquidity.depositLiquidityAndIncreaseShare(dai, usds, 1000000 ether, 1000000 ether, 0, block.timestamp, false);
		vm.stopPrank();
		}


    // A unit test to ensure that when `performUpkeep` is called, the correct amount of WBTC, WETH, and DAI is swapped to USDS
	function testPerformUpkeepSwapsCorrectTokenAmounts() public {
        // setup token balances in contract
        uint256 initialWbtcBalance = 5 * 10**8;
        uint256 initialWethBalance = 10 ether;
        uint256 initialDaiBalance = 1000 ether;

        // Transfer initial balances to the contract
        vm.startPrank(DEPLOYER);
        wbtc.transfer(address(liquidizer), initialWbtcBalance );
        weth.transfer(address(liquidizer), initialWethBalance );
        dai.transfer(address(liquidizer), initialDaiBalance );
        vm.stopPrank();

        _createLiquidity();

		vm.prank(address(upkeep));
		liquidizer.performUpkeep();

        // Assume specific amounts are swapped based on some hypothetical example ratios:
        // 1 WBTC = 10000 USDS
        // 1 WETH = 1000 USDS
        // 1 DAI = 1 USDS
//        uint256 expectedUsdsFromWbtc = 5 ether * 10000;
//        uint256 expectedUsdsFromWeth = initialWethBalance * 1000;
//        uint256 expectedUsdsFromDai = initialDaiBalance;
//        uint256 expectedTotalUsds = expectedUsdsFromWbtc + expectedUsdsFromWeth + expectedUsdsFromDai;

		uint256 expectedTotalUSDS = 60740254770105516374173;

        // Check balances after performUpkeep
        uint256 finalUsdsBalance = usds.balanceOf(address(liquidizer));
        // assert that all WBTC, WETH, and DAI are swapped to USDS
        assertEq(wbtc.balanceOf(address(liquidizer)), 0, "WBTC should be completely swapped to USDS");
        assertEq(weth.balanceOf(address(liquidizer)), 0, "WETH should be completely swapped to USDS");
        assertEq(dai.balanceOf(address(liquidizer)), 0, "DAI should be completely swapped to USDS");
        assertEq(finalUsdsBalance, expectedTotalUSDS, "Final USDS balance should reflect the swapped amounts from WBTC, WETH, and DAI");

        // assert that no additional tokens are present in the contract
        assertEq(salt.balanceOf(address(liquidizer)), 0, "No SALT tokens should be present in Liquidizer's balance after performUpkeep");
    }


    // A unit test that verifies the proper functioning of `_burnUSDS` method with various amounts of USDS to burn
	function testBurnUSDSCorrectlyHandlesVariousAmounts() public {
        uint256 smallAmountToBurn = 1 ether;
        uint256 largeAmountToBurn = 10 ether;
        uint256 balanceToSet = 5 ether;

        // Set-up the initial balance of USDS in the contract
        vm.startPrank(address(collateralAndLiquidity));
        usds.mintTo(address(liquidizer), balanceToSet);
		liquidizer.incrementBurnableUSDS(smallAmountToBurn);
		vm.stopPrank();

        // Ensure the contract has the correct initial balance
        assertEq(usds.balanceOf(address(liquidizer)), balanceToSet);

        // Should be able to burn an amount less than the balance without reverting
        vm.prank(address(upkeep));
        liquidizer.performUpkeep();

        // Confirm the correct amount was burned
        assertEq(usds.balanceOf(address(liquidizer)), balanceToSet - smallAmountToBurn);
        assertEq(liquidizer.usdsThatShouldBeBurned(), 0);


        // Specify burning more than the balance in the liquidizer
        vm.prank(address(collateralAndLiquidity));
		liquidizer.incrementBurnableUSDS(largeAmountToBurn);

        vm.prank(address(upkeep));
        liquidizer.performUpkeep();
        assertEq(usds.balanceOf(address(liquidizer)), 0);
        assertEq(liquidizer.usdsThatShouldBeBurned(), 6 ether);
    }


    // A unit test that confirms an increase in `usdsThatShouldBeBurned` only by the expected amount after a liquidation event
    function testIncreaseInUsdsThatShouldBeBurnedAfterLiquidation() public {
        uint256 initialUsdsToBurn = liquidizer.usdsThatShouldBeBurned();
        uint256 liquidationAmount = 1 ether; // amount that should increase after liquidation

        // Assuming the address of collateralAndLiquidity contract is allowed to call incrementBurnableUSDS
        vm.prank(address(collateralAndLiquidity));
        liquidizer.incrementBurnableUSDS(liquidationAmount);

        uint256 finalUsdsToBurn = liquidizer.usdsThatShouldBeBurned();

        // Check if `usdsThatShouldBeBurned` increased by the expected amount only
        assertEq(finalUsdsToBurn, initialUsdsToBurn + liquidationAmount, "usdsThatShouldBeBurned did not increase by the expected amount after liquidation");
    }


    // A unit test to ensure that the USDS balance of the DAO is increased by the expected amount after POL withdrawal
    function testUSDSBalanceDecreasedAfterPOLWithdrawal() public {
        // Deposit SALT/USDS to the DAO to simulate Protocol Owned Liquidity
        vm.prank(address(collateralAndLiquidity));
        usds.mintTo(address(dao), 100 ether);

        vm.prank(address(daoVestingWallet));
        salt.transfer(address(dao), 100 ether);

        vm.prank(address(upkeep));
        dao.formPOL(salt, usds, 100 ether, 100 ether);

		bytes32 poolID = PoolUtils._poolID( salt, usds );
		assertEq( collateralAndLiquidity.userShareForPool(address(dao),poolID ), 200 ether);


        // Set the USDS that should be burned to an amount greater than the balance
        vm.prank(address(collateralAndLiquidity));
        liquidizer.incrementBurnableUSDS(150 ether);

		// Start with 20 ether of USDS in the Liquidizer just to make sure it gets burned
        vm.prank(address(collateralAndLiquidity));
        usds.mintTo(address(liquidizer), 20 ether);

		// Initial stats
		uint256 usdsSupply = usds.totalSupply();

        // Call performUpkeep, which should trigger POL withdrawal and USDS burning
        vm.prank(address(exchangeConfig.upkeep()));
        liquidizer.performUpkeep();

		uint256 usdsBurned = usdsSupply - usds.totalSupply();
		assertEq( usdsBurned, 20 ether );

		// 1% of the SALT from the SALT/USDS POL should have been sent to the liquidizer
		assertEq( salt.balanceOf( address(liquidizer) ), 1 ether );
		assertEq( usds.balanceOf( address(liquidizer)), 1 ether );

		usdsSupply = usds.totalSupply();
		uint256 saltSupply = salt.totalSupply();

		// Call upkeep again to burn the SALT and USDS in the Liquidizer
        vm.prank(address(exchangeConfig.upkeep()));
        liquidizer.performUpkeep();

		usdsBurned = usdsSupply - usds.totalSupply();
		assertEq( usdsBurned, 1 ether );

		uint256 saltBurned = saltSupply - salt.totalSupply();
		assertEq( saltBurned, 1 ether );
    }


    // A unit test to check that no USDS burning occurs if non-USDS (WBTC, WETH, or DAI) balances are zero during `performUpkeep`
	function testNoUsdsBurningIfNonUSDSBalancesAreZero() public {
        // Initialize non-USDS balances to zero
        assertEq(wbtc.balanceOf(address(liquidizer)), 0, "WBTC balance should be 0");
        assertEq(weth.balanceOf(address(liquidizer)), 0, "WETH balance should be 0");
        assertEq(dai.balanceOf(address(liquidizer)), 0, "DAI balance should be 0");

        // Store current USDS balance and usdsThatShouldBeBurned before performUpkeep
        uint256 initialUsdsBalance = usds.balanceOf(address(liquidizer));
        uint256 initialUsdsShouldBeBurned = liquidizer.usdsThatShouldBeBurned();

        // Perform upkeep
        vm.prank(address(exchangeConfig.upkeep()));
        liquidizer.performUpkeep();

        // Assert USDS balance and usdsThatShouldBeBurned remain unchanged
        assertEq(usds.balanceOf(address(liquidizer)), initialUsdsBalance, "USDS balance should not change");
        assertEq(liquidizer.usdsThatShouldBeBurned(), initialUsdsShouldBeBurned, "usdsThatShouldBeBurned should not change");
    }


    // A unit test that confirms that SALT balance is burned and USDS balance is unaffected when SALT is present during `performUpkeep`
    function testPerformUpkeepBurnSaltBalanceOnly() public {
        // Given
        uint256 initialSaltBalance = 5 ether;
        uint256 initialUsdsBalance = 1 ether;
        vm.prank(address(teamVestingWallet));
        salt.transfer(address(liquidizer), initialSaltBalance); // Assume the existence of mintTo function for setup

        vm.prank(address(collateralAndLiquidity));
        usds.mintTo(address(liquidizer), initialUsdsBalance); // Assume the existence of mintTo function for setup

        // Verify initial conditions
        assertEq(salt.balanceOf(address(liquidizer)), initialSaltBalance, "Initial SALT balance should be set for test");
        assertEq(usds.balanceOf(address(liquidizer)), initialUsdsBalance, "Initial USDS balance should be unchanged");

        // When
        vm.prank(address(exchangeConfig.upkeep())); // Perform the upkeep as the authorized upkeep address
        liquidizer.performUpkeep();

        // Then
        assertEq(salt.balanceOf(address(liquidizer)), 0, "SALT should be burned (balance zero)");
        assertEq(salt.totalBurned(), initialSaltBalance, "SALT burned amount should match initial balance");
        assertEq(usds.balanceOf(address(liquidizer)), initialUsdsBalance, "USDS balance should remain unaffected");
    }
	}
