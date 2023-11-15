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
        liquidizer.shouldBurnMoreUSDS(usdsToBurn);

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


    // A unit test to confirm that `shouldBurnMoreUSDS` correctly aggregates multiple calls to increase `usdsThatShouldBeBurned`.
function testAggregatesMultipleCallsToShouldBurnMoreUSDS() public {
    uint256 firstUsdsToBurn = 1 ether;
    uint256 secondUsdsToBurn = 2 ether;
    uint256 thirdUsdsToBurn = 3 ether;

    // Initially the usdsThatShouldBeBurned should be 0
    assertEq(liquidizer.usdsThatShouldBeBurned(), 0 ether);

    // Call shouldBurnMoreUSDS multiple times and check if the USDS amount to be burned aggregates
    vm.prank(address(collateralAndLiquidity));
    liquidizer.shouldBurnMoreUSDS(firstUsdsToBurn);
    assertEq(liquidizer.usdsThatShouldBeBurned(), firstUsdsToBurn);

    vm.prank(address(collateralAndLiquidity));
    liquidizer.shouldBurnMoreUSDS(secondUsdsToBurn);
    assertEq(liquidizer.usdsThatShouldBeBurned(), firstUsdsToBurn + secondUsdsToBurn);

    vm.prank(address(collateralAndLiquidity));
    liquidizer.shouldBurnMoreUSDS(thirdUsdsToBurn);
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

		bytes32 poolIDA = PoolUtils._poolIDOnly(salt, usds);
		bytes32 poolIDB = PoolUtils._poolIDOnly(dai, usds);

		assertEq( collateralAndLiquidity.userShareForPool(address(dao), poolIDA), 200000 ether);
		assertEq( collateralAndLiquidity.userShareForPool(address(dao), poolIDB), 200000 ether);

        // Simulate shortfall in burning USDS
        uint256 shortfallAmount = 10 ether;
		vm.prank(address(collateralAndLiquidity));
        liquidizer.shouldBurnMoreUSDS(shortfallAmount);  // Assuming a setter for easy testing

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
        liquidizer.shouldBurnMoreUSDS(usdsRequiredToBurn);

        assertEq(liquidizer.usdsThatShouldBeBurned(), usdsRequiredToBurn, "usdsThatShouldBeBurned should be set");

        // Perform the action to partially burn USDS
        vm.prank(address(upkeep));
        liquidizer.performUpkeep();

        // All USDS will be burned
        assertEq(usds.balanceOf(address(liquidizer)), 0, "Not all available USDS burned");

        // The usdsThatShouldBeBurned should be reduced by the amount that was available to burn
        assertEq(liquidizer.usdsThatShouldBeBurned(), expectedUSDSLeftToBurn, "Not all available USDS was counted as burned");
    }


    // A unit test to ensure that calling `shouldBurnMoreUSDS` with zero value does not affect `usdsThatShouldBeBurned`.
    function testCallingShouldBurnMoreUSDSWithZeroDoesNotAffectUsdsThatShouldBeBurned() public {
        // Initially `usdsThatShouldBeBurned` should be 0
        assertEq(liquidizer.usdsThatShouldBeBurned(), 0 ether);

        // Call `shouldBurnMoreUSDS` with 0 ether
        vm.prank(address(collateralAndLiquidity));
        liquidizer.shouldBurnMoreUSDS(0 ether);  // This call is expected to be safe and not revert because it's called by `collateralAndLiquidity`

        // Validate that `usdsThatShouldBeBurned` is still 0
        assertEq(liquidizer.usdsThatShouldBeBurned(), 0 ether, "Calling shouldBurnMoreUSDS with zero should not affect usdsThatShouldBeBurned");
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
        liquidizer.shouldBurnMoreUSDS(usdsRequiredToBurn);

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
	}
