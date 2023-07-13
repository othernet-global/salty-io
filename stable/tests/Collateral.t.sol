//// SPDX-License-Identifier: BSL 1.1
//pragma solidity ^0.8.12;
//
//import "forge-std/Test.sol";
//import "../../Deployment.sol";
//import "../../root_tests/TestERC20.sol";
//
//
//contract TestCollateral is Test, Deployment
//	{
//	// User wallets for testing
//    address public constant alice = address(0x1111);
//    address public constant bob = address(0x2222);
//    address public constant charlie = address(0x3333);
//
//
////	constructor()
////		Collateral( _collateralLP, _usds, _stableConfig, _stakingConfig, _exchangeConfig )
////		{
////		_liquidator = new Liquidator( _collateralLP, _saltyRouter, this, stableConfig, exchangeConfig );
////
////		vm.startPrank( DEV_WALLET );
////		_exchangeConfig.setOptimizer( polOptimizer );
////		_exchangeConfig.setLiquidator( _liquidator );
////		_exchangeConfig.setAccessManager(accessManager);
////
////		// setCollateral can only be called on USDS one time
////		// call it with this address as the Collateral so that usds.mintTo() can be called
////		usds.setCollateral( this );
////		vm.stopPrank();
////
////		// Mint some USDS to the DEV_WALLET
////		vm.prank( address(this) );
////		usds.mintTo( DEV_WALLET, 2000000 ether );
////
////		_stakingConfig.whitelist( collateralLP );
////		}
////
////
////    function setUp() public
////    	{
////		assertEq( address(collateralLP), address(0x8a47e16a804E6d7531e0a8f6031f9Fee12EaeE57), "Unexpected collateralLP" );
////
////    	// The test WBTC, WETH, and USDC tokens are held by DEV_WALLET
////		vm.startPrank( DEV_WALLET );
////
////		// Dev Approvals
////		_wbtc.approve( address(_saltyRouter), type(uint256).max );
////        _weth.approve( address(_saltyRouter), type(uint256).max );
////		_usds.approve( address(_saltyRouter), type(uint256).max );
////		salt.approve( address(this), type(uint256).max );
////
//////		console.log( "WBTC DECIMALS: ", _liquidator.wbtcDecimals() );
//////		console.log( "WETH DECIMALS: ", _liquidator.wethDecimals() );
//////		console.log( "WBTC BALANCE: ", _wbtc.balanceOf(address(DEV_WALLET)) / 10 ** 8 );
//////		console.log( "WETH BALANCE: ", _weth.balanceOf(address(DEV_WALLET)) / 10 ** 18 );
////
////
////		// Have DEV_WALLET create some BTC/ETH LP collateral on Salty.IO
////		(,,uint256 initialCollateral) = _saltyRouter.addLiquidity( address(_wbtc), address(_weth), 1000 * 10 ** 8, 1000000 ether, 0, 0, DEV_WALLET, block.timestamp );
////
////    	// Transfer some collateral to alice, bob and charlie for later testing
////    	// DEV_WALLET will maintain 1/4 of the initialCollateral as well
////		collateralLP.transfer( alice, initialCollateral / 4 );
////		collateralLP.transfer( bob, initialCollateral / 4 );
////		collateralLP.transfer( charlie, initialCollateral / 4 );
////		vm.stopPrank();
////
////
////		// More approvals
////		vm.startPrank( alice );
////		usds.approve( address(this), type(uint256).max );
////		collateralLP.approve( address(this), type(uint256).max );
////		vm.stopPrank();
////
////		vm.startPrank( bob );
////		usds.approve( address(this), type(uint256).max );
////		collateralLP.approve( address(this), type(uint256).max );
////		vm.stopPrank();
////
////		vm.startPrank( charlie );
////		usds.approve( address(this), type(uint256).max );
////		collateralLP.approve( address(this), type(uint256).max );
////		vm.stopPrank();
////    	}
////
////
////	// This will set the collateral / borrowed ratio at the default of 200%
////	function _depositCollateralAndBorrowMax( address user ) internal
////		{
////		vm.startPrank( user );
////		this.depositCollateral( collateralLP.balanceOf(user) );
////
////		uint256 maxUSDS = this.maxBorrowableUSDS(user);
////		this.borrowUSDS( maxUSDS );
////		vm.stopPrank();
////		}
////
////
////	// This will set the collateral / borrowed ratio at the default of 200%
////	function _depositHalfCollateralAndBorrowMax( address user ) internal
////		{
////		vm.startPrank( user );
////		this.depositCollateral( collateralLP.balanceOf(user) / 2 );
////
////		uint256 maxUSDS = this.maxBorrowableUSDS(user);
////		this.borrowUSDS( maxUSDS );
////		vm.stopPrank();
////		}
////
////
////	// Can be used to test liquidation by reducing BTC and ETH price.
////	// Original collateral ratio is 200% with a minimum collateral ratio of 110%.
////	// So dropping the prices by 46% should allow positions to be liquidated and still
////	// ensure that the collateral is above water and able to be liquidated successfully.
////	function _crashCollateralPrice() internal
////		{
////		vm.startPrank( DEV_WALLET );
////		_forcedPriceFeed.setBTCPrice( _forcedPriceFeed.getPriceBTC() * 54 / 100);
////		_forcedPriceFeed.setETHPrice( _forcedPriceFeed.getPriceETH() * 54 / 100 );
////		vm.stopPrank();
////		}
////
////
////	// A unit test that verifies the order of adding new positions.
////	function testOrderOfAddingNewPositions() public {
////		uint256 collateralAmount = collateralLP.balanceOf(alice) / 2;
////
////        // Alice, Bob and Charlie deposit collateral
////        vm.prank(alice);
////        this.depositCollateral(collateralAmount);
////
////        vm.prank(bob);
////        this.depositCollateral(collateralAmount);
////
////        vm.prank(charlie);
////        this.depositCollateral(collateralAmount);
////
////		uint256 maxBorrowable = this.maxBorrowableUSDS(alice);
////
////        // Alice, Bob and Charlie borrow USDS
////        vm.prank(alice);
////        this.borrowUSDS(maxBorrowable);
////        assertEq(this.userPosition(alice).usdsBorrowedAmount, maxBorrowable);
////
////        vm.prank(bob);
////        this.borrowUSDS(maxBorrowable);
////        assertEq(this.userPosition(bob).usdsBorrowedAmount, maxBorrowable);
////
////        vm.prank(charlie);
////        this.borrowUSDS(maxBorrowable);
////        assertEq(this.userPosition(charlie).usdsBorrowedAmount, maxBorrowable);
////
////        // The order of positions should be Alice, Bob, Charlie based on the deposits and borrows above
////        assertEq(this.userPositionIDs(alice), 1);
////        assertEq(this.userPositionIDs(bob), 2);
////        assertEq(this.userPositionIDs(charlie), 3);
////    }
////
////
////	// A unit test that verifies the liquidatePosition function correctly transfers LP tokens to the liquidator
////	function testLiquidatePosition() public {
////		assertEq(collateralLP.balanceOf(address(this)), 0, "Collateral contract should start with zero collateralLP");
////
////		assertEq(usds.balanceOf(address(this)), 0, "Collateral contract should start with zero USDS");
////		assertEq(usds.balanceOf(alice), 0, "Alice should start with zero USDS");
////		assertEq(usds.balanceOf(bob), 0, "Bob should start with zero USDS");
////
////		uint256 aliceCollateralBalance = collateralLP.balanceOf( alice );
////		uint256 aliceCollateralValue = this.collateralValue( aliceCollateralBalance );
////
////		// Alice will deposit all her collateral and borrowed max USDS
////		_depositCollateralAndBorrowMax(alice);
////
////		assertEq(collateralLP.balanceOf(address(this)), aliceCollateralBalance, "Collateral contract should have all of Alice's collateral");
////
////		// Get position details for Alice
////		uint256 alicePositionId = userPositionIDs[alice];
////		CollateralPosition memory alicePosition = userPosition(alice);
////
////		uint256 aliceBorrowedUSDS = usds.balanceOf(alice);
////		assertEq( alicePosition.usdsBorrowedAmount, aliceBorrowedUSDS, "Alice amount USDS borrowed not what she has" );
////
////		// Borrowed USDS should be able 50% of the aliceCollateralValue
//////		console.log( "aliceCollateralValue: ", aliceCollateralValue / 10 ** 18 );
//////		console.log( "aliceBorrowedUSDS: ", aliceBorrowedUSDS / 10 ** 18 );
////
////		assertTrue( aliceBorrowedUSDS > ( aliceCollateralValue * 49 / 100 ), "Alice did not borrow sufficient USDS" );
////		assertTrue( collateralLP.balanceOf(alice) == 0, "Alice should have deposited all her LP" );
////
////		// Try and fail to liquidate alice
////		vm.expectRevert( "Collateral ratio is too high to liquidate" );
////		vm.prank(bob);
////        this.liquidatePosition(alicePositionId);
////
////		// Artificially crash the collateral price
////		_crashCollateralPrice();
////
////		// Delay before the liquidation
////		vm.warp( block.timestamp + 1 days );
////
////		uint256 bobStartingCollateralLP = collateralLP.balanceOf(bob);
////		uint256 liquidatorStartingCollateralLP = collateralLP.balanceOf(address(_liquidator));
////
////		// Liquidate Alice's position
////		vm.prank(bob);
////		this.liquidatePosition(alicePositionId);
////
////		// Verify that Alice's position has been liquidated
////		assertEq(userPositionIDs[alice], 0);
////		assertFalse(this.userHasPosition(alice));
////
////		// Verify that Bob has received collateralLP for the liquidation
////		assertTrue(collateralLP.balanceOf(bob) > bobStartingCollateralLP, "Bob should have received collateralLP for liquidating");
////
////		// Verify that the liquidator received collateralLP for later liquidation
////		assertTrue(collateralLP.balanceOf(address(_liquidator)) > liquidatorStartingCollateralLP, "_liquidator should have received collateralLP for liquidation");
////		}
////
////
////	// A unit test that verifies liquidatePosition behavior where the borrowed amount is zero.
////		function testLiquidatePositionWithZeroBorrowedAmount() public {
////			uint256 aliceCollateralBalance = collateralLP.balanceOf( alice );
////
////    		// Alice will deposit all her collateral, but doesn't borrow any
////			vm.prank( alice );
////			this.depositCollateral( aliceCollateralBalance );
////
////    		assertEq(collateralLP.balanceOf(address(this)), aliceCollateralBalance, "Collateral contract should have all of Alice's collateral");
////
////    		// Get position details for Alice
////    		uint256 alicePositionId = userPositionIDs[alice];
////
////    		uint256 aliceBorrowedUSDS = usds.balanceOf(alice);
////    		assertEq( aliceBorrowedUSDS, 0, "Alice should have zero borrowed USDS" );
////
////    		// Artificially crash the collateral price
////    		_crashCollateralPrice();
////
////    		// Delay before the liquidation
////    		vm.warp( block.timestamp + 1 days );
////
////    		// Try and fail to liquidate alice
////    		vm.expectRevert( "Borrowed amount must be greater than zero" );
////    		vm.prank(bob);
////            this.liquidatePosition(alicePositionId);
////    		}
////
////   	// A unit test that verifies the liquidatePosition function's handling of position liquidation, including both valid and invalid position IDs, cases where the position has already been liquidated.
////   	function testLiquidatePositionFailure() public {
////    	// Assume Alice, Bob and Charlie already have positions in setUp()
////    	_depositCollateralAndBorrowMax(alice);
////
////    	uint256 alicePositionID = userPositionIDs[alice];
////
////    	assertTrue(alicePositionID > 0);
////
////    	// Let's make the prices crash
////    	_crashCollateralPrice();
////
////		// Warp past the sharedRewards cooldown
////		vm.warp( block.timestamp + 1 days );
////
////    	// Now Alice's position should be liquidatable
////    	this.liquidatePosition(alicePositionID);
////
////    	// Shouldn't be able to liquidate twice
////    	vm.expectRevert("Invalid position");
////    	this.liquidatePosition(alicePositionID);
////
////    	// Trying to liquidate an invalid position id should fail
////    	vm.expectRevert("Invalid position");
////    	this.liquidatePosition(9999999);
////    }
////
////
////   	// A unit test that checks the liquidatePosition function for proper calculation and burning of the borrowed amount, and when the caller tries to liquidate their own position.
////	function testLiquidateSelf() public {
////
////		uint256 initialSupplyUSDS = IERC20(address(usds)).totalSupply();
////
////        _depositCollateralAndBorrowMax(alice);
////
////		assertTrue( initialSupplyUSDS < IERC20(address(usds)).totalSupply(), "Supply after borrow should be higher" );
////
////        CollateralPosition memory positionBefore = userPosition(alice);
////        assertEq(positionBefore.wallet, alice);
////        assertTrue(positionBefore.lpCollateralAmount > 0 ether);
////        assertTrue(positionBefore.usdsBorrowedAmount > 0 ether);
////        assert(!positionBefore.liquidated);
////
////        _crashCollateralPrice();
////
////		// Warp past the sharedRewards cooldown
////		vm.warp( block.timestamp + 1 days );
////
////        // Attempting to liquidate own position should revert
////        vm.prank(alice);
////        vm.expectRevert( "Cannot liquidate self" );
////        this.liquidatePosition(userPositionIDs[alice]);
////
////        // Proper liquidation by another account
////        vm.prank(bob);
////        this.liquidatePosition(userPositionIDs[alice]);
////
////		assertFalse( this.userHasPosition(alice) );
////    }
////
////
////	// A unit test where a user is liquidated and then adds another position which is then liquidated as well
////	function testUserLiquidationTwice() public {
////        // Deposit and borrow for Alice
////        _depositHalfCollateralAndBorrowMax(alice);
////
////        // Check if Alice has a position
////        assertTrue(userHasPosition(alice));
////
////        // Crash the collateral price
////        _crashCollateralPrice();
////        vm.warp( block.timestamp + 1 days );
////
////        // Alice's position should now be under-collateralized and ready for liquidation
////        // The id of alice's position should be 1 as she is the first one to open a position
////        uint256 alicePositionId = userPositionIDs[alice];
////
////        // Liquidate Alice's position
////        this.liquidatePosition(alicePositionId);
////
////        // Check if Alice's position was liquidated
////        assertFalse(userHasPosition(alice));
////
////        vm.warp( block.timestamp + 1 days );
////
////        // Deposit and borrow again for Alice
////        _depositHalfCollateralAndBorrowMax(alice);
////
////        // Check if Alice has a new position
////        assertTrue(userHasPosition(alice));
////
////        // Crash the collateral price again
////        _crashCollateralPrice();
////        vm.warp( block.timestamp + 1 days );
////
////        // Alice's position should now be under-collateralized and ready for liquidation again
////        // The id of alice's position should now be 2 as she opened a new position
////        alicePositionId = userPositionIDs[alice];
////
////        // Liquidate Alice's position again
////        this.liquidatePosition(alicePositionId);
////
////        // Check if Alice's position was liquidated again
////        assertFalse(userHasPosition(alice));
////    }
////
////
////
////	// A unit test where a user deposits, borrows, deposits and is then liquidated
////	function testUserDepositBorrowDepositAndLiquidate() public {
////        // User Alice deposits collateral
////        uint256 aliceCollateralBalance = collateralLP.balanceOf(alice) / 2;
////        vm.prank( alice );
////		this.depositCollateral( aliceCollateralBalance );
////
////        // Alice borrows USDS
////        uint256 maxBorrowable = this.maxBorrowableUSDS(alice);
////        vm.prank( alice );
////        this.borrowUSDS( maxBorrowable );
////
////        // Alice deposits more collateral - but fails due to the cooldown
////        aliceCollateralBalance = collateralLP.balanceOf(alice) / 2;
////
////        vm.expectRevert( "Must wait for the cooldown to expire" );
////        vm.prank( alice );
////		this.depositCollateral( aliceCollateralBalance );
////
////		vm.warp( block.timestamp + 1 days );
////
////		// Try depositing again
////        aliceCollateralBalance = collateralLP.balanceOf(alice) / 2;
////        vm.prank( alice );
////		this.depositCollateral( aliceCollateralBalance );
////
////        // Alice's position after second deposit
////        CollateralPosition memory position = this.userPosition(alice);
////
////        // Crash the collateral price so Alice's position can be liquidated
////        _crashCollateralPrice();
////        _crashCollateralPrice();
////		vm.warp( block.timestamp + 1 days );
////
////        // Liquidate Alice's position
////        this.liquidatePosition(position.positionID);
////
////        // Alice's position should be liquidated
////        try this.userPosition(alice) {
////            fail("Alice's position should have been liquidated");
////        } catch Error(string memory reason) {
////            assertEq(reason, "User does not have a collateral position", "Error message mismatch");
////        }
////    }
////
////
////	// A unit test that verifies the userCollateralValueInUSD and underlyingTokenValueInUSD function with different collateral amounts and different token prices, including when the user does not have a position.
////	function testUserCollateralValueInUSD() public
////    	{
////    	// Determine how many BTC and ETH alice has in colalteral
////    	uint256 aliceCollateral = collateralLP.balanceOf(alice);
////
////    	_depositCollateralAndBorrowMax(alice);
////
////		(uint112 reserve0, uint112 reserve1,) = collateralLP.getReserves();
////		uint256 totalLP = collateralLP.totalSupply();
////
////		uint256 aliceBTC = ( reserve0 * aliceCollateral ) / totalLP;
////		uint256 aliceETH = ( reserve1 * aliceCollateral ) / totalLP;
////
////		if ( collateralIsFlipped )
////			(aliceETH,aliceBTC) = (aliceBTC,aliceETH);
////
////		vm.startPrank( DEV_WALLET );
////		_forcedPriceFeed.setBTCPrice( 20000 ether );
////		_forcedPriceFeed.setETHPrice( 2000 ether );
////		vm.stopPrank();
////
////        uint256 aliceCollateralValue0 = this.userCollateralValueInUSD(alice);
////        uint256 aliceCollateralValue = aliceBTC * 20000 * 10 ** 18 / 10 ** 8 + aliceETH * 2000;
////		assertEq( aliceCollateralValue0, aliceCollateralValue, "Collateral value different than expected" );
////
//////
//////		vm.startPrank( DEV_WALLET );
//////		_forcedPriceFeed.setBTCPrice( 15000 ether );
//////		_forcedPriceFeed.setETHPrice( 1777 ether );
//////		vm.stopPrank();
//////
//////        aliceCollateralValue0 = this.userCollateralValueInUSD(alice);
//////        aliceCollateralValue = aliceBTC * 15000 + aliceETH * 1777;
//////		assertEq( aliceCollateralValue0, aliceCollateralValue, "Collateral value different than expected" );
//////
//////
//////		vm.startPrank( DEV_WALLET );
//////		_forcedPriceFeed.setBTCPrice( 45000 ether );
//////		_forcedPriceFeed.setETHPrice( 11777 ether );
//////		vm.stopPrank();
//////
//////        aliceCollateralValue0 = this.userCollateralValueInUSD(alice);
//////        aliceCollateralValue = aliceBTC * 45000 + aliceETH * 11777;
//////		assertEq( aliceCollateralValue0, aliceCollateralValue, "Collateral value different than expected" );
//////
//////		assertEq( this.userCollateralValueInUSD(DEV_WALLET), 0, "Non-existent collateral value should be zero" );
////    	}
////
////
////
////
////	// A unit test that verifies the findLiquidatablePositions function returns an empty array when there are no liquidatable positions and checks it for a range of indices.
////	function testFindLiquidatablePositions_noLiquidatablePositions() public {
////		// Alice, Bob, and Charlie deposit collateral and borrow within the limit
////		_depositHalfCollateralAndBorrowMax(alice);
////		_depositHalfCollateralAndBorrowMax(bob);
////		_depositHalfCollateralAndBorrowMax(charlie);
////
////		uint256[] memory liquidatablePositions = this.findLiquidatablePositions();
////        assertEq(liquidatablePositions.length, 0, "No liquidatable positions should be found");
////    }
////
////
////	// A unit test to ensure that the borrowUSDS function updates the _openPositionIDs mapping correctly, and that the _openPositionIDs mapping is also updated properly after liquidation.
////	function testBorrowUSDSAndLiquidation() public {
////        // Deposit collateral
////        vm.startPrank(alice);
////        this.depositCollateral( collateralLP.balanceOf(alice) / 2 );
////        vm.stopPrank();
////
////        // Check that position is opened for Alice
////        assertEq(userPositionIDs[alice], _nextPositionID - 1);
////
////        // Borrow USDS
////        uint256 borrowedAmount = this.maxBorrowableUSDS(alice); // Assuming this is within max borrowable
////        vm.startPrank(alice);
////        this.borrowUSDS(borrowedAmount);
////        vm.stopPrank();
////
////        // Check that Alice's borrowed amount increased
////        CollateralPosition memory position = userPosition(alice);
////        assertEq(position.usdsBorrowedAmount, borrowedAmount);
////
////        // Confirm that position is open
////        assertTrue( this.positionIsOpen(position.positionID));
////
////        // Crash collateral price to enable liquidation
////        _crashCollateralPrice();
////		vm.warp( block.timestamp + 1 days );
////
////        // Liquidate position
////        this.liquidatePosition(position.positionID);
////
////        // Confirm that position is removed from _openPositionIDs
////        assertFalse( this.positionIsOpen(position.positionID));
////    }
////
////
////
////	// A unit test for numberOfOpenPositions to verify that it returns the correct number of open positions.
////	function testNumberOfOpenPositions() public {
////        // Alice, Bob and Charlie each deposit and borrow
////        _depositCollateralAndBorrowMax(alice);
////        _depositCollateralAndBorrowMax(bob);
////        _depositCollateralAndBorrowMax(charlie);
////
////    	vm.warp( block.timestamp + 1 days );
////
////        // Check numberOfOpenPositions returns correct number of open positions
////        assertEq( numberOfOpenPositions(), 3);
////
////        // Alice repays loan, reducing number of open positions
////        uint256 aliceBorrowedAmount = usds.balanceOf(alice);
////
////        usds.mintTo(alice, aliceBorrowedAmount);
////        vm.startPrank(alice);
////        this.repayUSDS(aliceBorrowedAmount / 2 );
////        vm.stopPrank();
////
////        // Check numberOfOpenPositions returns correct number of open positions
////        assertEq( numberOfOpenPositions() , 3);
////
////		vm.startPrank(alice);
////		this.repayUSDS(aliceBorrowedAmount - aliceBorrowedAmount / 2);
////		vm.stopPrank();
////
////        assertEq( numberOfOpenPositions() , 2);
////
////        // _crashCollateralPrice to force liquidation of a position
////        _crashCollateralPrice();
////
////        // Check liquidation of Bob's position
////        uint256 bobPositionID = userPositionIDs[bob];
////        this.liquidatePosition(bobPositionID);
////
////        // Check numberOfOpenPositions returns correct number of open positions
////        assertEq( numberOfOpenPositions(), 1);
////    }
////
////
////	// A unit test for totalCollateralValueInUSD to verify that it correctly calculates the total value of all collateral.
////	    // Here's a unit test for the `totalCollateralValueInUSD` function
////        function testTotalCollateralValueInUSD() public {
////
////            // Initial deposit for Alice, Bob and Charlie
////            _depositCollateralAndBorrowMax(alice);
////            _depositCollateralAndBorrowMax(bob);
////            _depositCollateralAndBorrowMax(charlie);
////
////            // Get total collateral value before crash
////            uint256 totalCollateral = this.totalCollateralValueInUSD();
////			uint256 aliceCollateralValue = this.userCollateralValueInUSD(alice);
////
//////			console.log( "totalCollateral: ", totalCollateral );
//////			console.log( "aliceCollateralValue: ", aliceCollateralValue );
////
////			// The original collateralLP was divided amounts 4 wallets - one of which was alice
////			// ALlow slight variation in quoted price
////			bool isValid = totalCollateral > (aliceCollateralValue * 4 * 99 / 100);
////			isValid = isValid && (totalCollateral < (aliceCollateralValue * 4 * 101 / 100 ));
////
////			assertTrue( isValid, "Total collateral does not reflect the correct value" );
////        }
////
////
////
////	// A unit test that verifies that collateralValue correctly calculates the collateral value for given LP amounts.
////	function testUserCollateralValueInUSD2() public {
////
////		uint256 aliceCollateral = collateralLP.balanceOf(alice);
////
////		(uint112 reserve0, uint112 reserve1,) = collateralLP.getReserves();
////		uint256 totalLP = collateralLP.totalSupply();
////
////		uint256 aliceBTC = ( reserve0 * aliceCollateral ) / totalLP;
////		uint256 aliceETH = ( reserve1 * aliceCollateral ) / totalLP;
////
////		// Prices from the price feed have 18 decimals
////		IPriceFeed priceFeed = stableConfig.priceFeed();
////		uint256 btcPrice = priceFeed.getPriceBTC();
////        uint256 ethPrice = priceFeed.getPriceETH();
////
////		// Keep the 18 decimals from the price and remove the decimals from the amount held by the user
////		uint256 btcValue = ( aliceBTC * btcPrice ) / (10 ** btcDecimals );
////		uint256 ethValue = ( aliceETH * ethPrice ) / (10 ** wethDecimals );
////
////		uint256 manualColletaralValue = btcValue + ethValue;
////
////
////		_depositCollateralAndBorrowMax(alice);
////
////    	uint256 actualCollateralValue = this.userCollateralValueInUSD(alice);
////
////		assertEq( manualColletaralValue, actualCollateralValue, "Calculated and actual collateral values are not the same" );
////    }
////
////
////	// A unit test to verify that the collateralIsFlipped boolean value is correctly set in the constructor based on the LP tokens provided.
////	function testCollateralIsFlipped() public {
////       	// Create two LP tokens with different order of tokens
////        IUniswapV2Pair collateralLP1;
////        while( true )
////        	{
////        	// Keep creating BTC/ETH pairs until BTC is symbol0
////        	ERC20 a = new ERC20( "WBTC", "WBTC" );
////			ERC20 b = new ERC20( "WETH", "WETH" );
////
////			collateralLP1 = IUniswapV2Pair( _factory.createPair( address(a), address(b) ) );
////			if ( address(collateralLP1.token0()) == address(a) )
////	        	break;
////        	}
////
////        IUniswapV2Pair collateralLP2;
////		while( true )
////			{
////			// Keep creating BTC/ETH pairs until BTC is symbol0
////			ERC20 a = new ERC20( "WETH", "WETH" );
////			ERC20 b = new ERC20( "WBTC", "WBTC" );
////
////			collateralLP2 = IUniswapV2Pair( _factory.createPair( address(a), address(b) ) );
////			if ( address(collateralLP2.token0()) == address(a) )
////				break;
////			}
////
////		// Create two Collateral contracts with different LP tokens
////		Collateral collateral1 = new Collateral(collateralLP1, _usds, _stableConfig, _stakingConfig, _exchangeConfig);
////		Collateral collateral2 = new Collateral(collateralLP2, _usds, _stableConfig, _stakingConfig, _exchangeConfig);
////
////		// Collateral1 should have collateralIsFlipped as false since WBTC is token0 and WETH is token1
////		assertFalse(collateral1.collateralIsFlipped() );
////
////		// Collateral2 should have collateralIsFlipped as true since WETH is token0 and WBTC is token1
////		assertTrue(collateral2.collateralIsFlipped() );
////    }
////
////
////	// A unit test that checks the deposit and withdrawal of collateral with various amounts, ensuring that an account cannot withdraw collateral that they do not possess.
////	function testDepositAndWithdrawCollateral() public
////    {
////    	// Setup
////    	vm.startPrank(alice);
////
////    	uint256 aliceCollateralAmount = _collateralLP.balanceOf(alice);
////    	uint256 depositAmount = aliceCollateralAmount / 2;
////
////    	// Alice deposits half of her collateral
////    	this.depositCollateral(depositAmount);
////
////    	// Verify the result
////    	assertEq(_collateralLP.balanceOf(address(this)), depositAmount);
////    	assertEq(this.userPosition(alice).lpCollateralAmount, depositAmount);
////
////		vm.warp( block.timestamp + 1 days );
////
////    	// Alice tries to withdraw more collateral than she has in the contract
////    	vm.expectRevert( "Excessive amountWithdrawn" );
////    	this.withdrawCollateralAndClaim( depositAmount + 1 );
////
////		vm.warp( block.timestamp + 1 days );
////
////    	// Alice withdraws half the collateral
////    	this.withdrawCollateralAndClaim(depositAmount / 2);
////
////		vm.warp( block.timestamp + 1 days );
////
////		// Withdraw too much
////    	vm.expectRevert( "Excessive amountWithdrawn" );
////    	this.withdrawCollateralAndClaim(depositAmount / 2 + 1);
////
////		// Withdraw the rest
////    	this.withdrawCollateralAndClaim(depositAmount / 2);
////
////		vm.warp( block.timestamp + 1 days );
////
////    	// Verify the result
////    	assertEq(_collateralLP.balanceOf(address(this)), 0);
////    	assertEq(this.userPosition(alice).lpCollateralAmount, 0);
////    }
////
////
////	// A unit test to verify that an account cannot borrow USDS more than their max borrowable limit and cannot repay USDS if they don't have a position.
////	function testCannotBorrowMoreThanMaxBorrowableLimit() public {
////        vm.startPrank(alice);
////
////        uint256 initialAmount = collateralLP.balanceOf(alice);
////        this.depositCollateral(initialAmount);
////
////        uint256 maxBorrowableAmount = this.maxBorrowableUSDS(alice);
////        vm.expectRevert( "Excessive amountBorrowed" );
////        this.borrowUSDS(maxBorrowableAmount + 1 ether);
////
////        vm.stopPrank();
////	    }
////
////
////    function testCannotRepayUSDSWithoutPosition() public {
////        vm.startPrank(bob);
////        vm.expectRevert( "User does not have an existing position" );
////        this.repayUSDS(1 ether);
////        vm.stopPrank();
////    }
////
////
////
////	// A unit test that verifies the userPosition function and userHasPosition function for accounts with and without positions.
////	function testUserPositionFunctions() public {
////        // Initially, Alice, Bob and Charlie should not have positions
////        assertTrue(!this.userHasPosition(alice));
////        assertTrue(!this.userHasPosition(bob));
////        assertTrue(!this.userHasPosition(charlie));
////
////        // After Alice deposits collateral and borrows max, she should have a position
////        _depositCollateralAndBorrowMax(alice);
////        assertTrue(this.userHasPosition(alice));
////
////        CollateralPosition memory alicePosition = this.userPosition(alice);
////        assertEq(alicePosition.wallet, alice);
////        assertTrue(alicePosition.lpCollateralAmount > 0);
////        assertTrue(alicePosition.usdsBorrowedAmount > 0);
////        assertTrue(!alicePosition.liquidated);
////
////        // Still, Bob and Charlie should not have positions
////        assertTrue(!this.userHasPosition(bob));
////        assertTrue(!this.userHasPosition(charlie));
////
////        // After Bob deposits collateral and borrows max, he should have a position
////        _depositCollateralAndBorrowMax(bob);
////        assertTrue(this.userHasPosition(bob));
////
////        CollateralPosition memory bobPosition = this.userPosition(bob);
////        assertEq(bobPosition.wallet, bob);
////        assertTrue(bobPosition.lpCollateralAmount > 0);
////        assertTrue(bobPosition.usdsBorrowedAmount > 0);
////        assertTrue(!bobPosition.liquidated);
////
////        // Finally, Charlie still should not have a position
////        assertTrue(!this.userHasPosition(charlie));
////    }
////
////
////	// A unit test that validates maxWithdrawableLP and maxBorrowableUSDS functions with scenarios including accounts without positions and accounts with positions whose collateral value is less than the minimum required to borrow USDS.
////	function testMaxWithdrawableLP_and_maxBorrowableUSDS() public {
////        address randomUser = address(0x4444);
////        address nonPositionUser = address(0x5555);
////
////        // Scenario where account has a position but collateral value is less than the minimum required to borrow USDS
////        _depositCollateralAndBorrowMax(alice);
////
////        uint256 maxWithdrawableLPForAlice = this.maxWithdrawableLP(alice);
////        uint256 maxBorrowableUSDSForAlice = this.maxBorrowableUSDS(alice);
////
////        assertTrue(maxWithdrawableLPForAlice == 0, "Max withdrawable LP should be zero");
////        assertTrue(maxBorrowableUSDSForAlice == 0, "Max borrowable USDS should be zero");
////
////        // Scenario where account does not have a position
////        uint256 maxWithdrawableLPForNonPositionUser = this.maxWithdrawableLP(nonPositionUser);
////        uint256 maxBorrowableUSDSForNonPositionUser = this.maxBorrowableUSDS(nonPositionUser);
////
////        assertTrue(maxWithdrawableLPForNonPositionUser == 0, "Max withdrawable LP for user without position should be zero");
////        assertTrue(maxBorrowableUSDSForNonPositionUser == 0, "Max borrowable USDS for user without position should be zero");
////
////        // Scenario where a random user tries to borrow and withdraw
////        vm.startPrank(randomUser);
////        collateralLP.approve( address(this), type(uint256).max );
////
////        try this.depositCollateral(100 ether) {
////            fail("depositCollateral should have failed for random user");
////        } catch {
////            assertEq(this.userCollateralValueInUSD(randomUser), 0);
////        }
////        try this.borrowUSDS(100 ether) {
////            fail("borrowUSDS should have failed for random user");
////        } catch {
////            assertEq(this.userCollateralValueInUSD(randomUser), 0);
////        }
////        vm.stopPrank();
////    }
////
////
////	// A unit test that verifies the accuracy of the findLiquidatablePositions function in more complex scenarios. This could include scenarios where multiple positions should be liquidated at once, or where no positions should be liquidated despite several being close to the threshold.
////	function testFindLiquidatablePositions() public {
////        _depositCollateralAndBorrowMax(alice);
////        _depositCollateralAndBorrowMax(bob);
////        _depositCollateralAndBorrowMax(charlie);
////
////		_crashCollateralPrice();
////
////		vm.warp( block.timestamp + 1 days );
////
////        // All three positions should be liquidatable.
////        assertEq(this.findLiquidatablePositions().length, 3);
////
////		CollateralPosition memory position = userPosition(alice);
////		vm.prank(alice);
////		this.repayUSDS( position.usdsBorrowedAmount );
////
//////        // Now only two positions should be liquidatable.
//////        assertEq(this.findLiquidatablePositions().length, 2);
//////
//////        // Let's liquidate one of the positions.
//////        this.liquidatePosition(userPositionIDs[bob]);
//////
//////        // Now only one position should be liquidatable.
//////        assertEq(this.findLiquidatablePositions().length, 1);
//////
//////        // Charlie also repays all his debt.
//////		position = userPosition(charlie);
//////		vm.prank(charlie);
//////		this.repayUSDS( position.usdsBorrowedAmount );
//////
//////        // Now no positions should be liquidatable.
//////        assertEq(this.findLiquidatablePositions().length, 0);
////    }
////
////
////	// A unit test to verify the accuracy of userCollateralValueInUSD when there are multiple positions opened by a single user.
////	function testUserCollateralValueInUSD_multiplePositions() public {
////
////		uint256 collateralAmount0 = collateralLP.balanceOf(alice);
////		uint256 collateralAmount = collateralAmount0 / 10;
////		uint256 collateralValue0 = this.collateralValue( collateralAmount0);
////
////        // User Alice opens the first position
////        vm.startPrank(alice);
////        this.depositCollateral(collateralAmount);
////        vm.warp( block.timestamp + 1 days );
////
////        this.depositCollateral(collateralAmount * 2);
////        vm.warp( block.timestamp + 1 days );
////
////        this.depositCollateral(collateralAmount0 - collateralAmount * 3);
////        vm.warp( block.timestamp + 1 days );
////
////		assertEq( collateralLP.balanceOf(alice), 0, "Alice should have zero collateral" );
////
////        // check the collateral value
////        uint256 aliceCollateralValue = this.userCollateralValueInUSD(alice);
////        assertEq(aliceCollateralValue, collateralValue0, "The total collateral value is incorrect");
////    }
////
////	// A unit test that ensures correct behavior when BTC/ETH prices drop by more than 50% and the collateral positions are underwater.
////	function testUnderwaterPosition() public
////    {
////        // Setup
////        _depositCollateralAndBorrowMax(alice);  // Assume the function correctly initializes a max leveraged position
////        _depositCollateralAndBorrowMax(bob);
////        _depositCollateralAndBorrowMax(charlie);
////
////        // Simulate a 50% price drop for both BTC and ETH
////        _crashCollateralPrice();
////
////        // Simulate another 50% price drop for both BTC and ETH
////        _crashCollateralPrice();
////
////        vm.warp( block.timestamp + 1 days );
////
////        // Alice, Bob and Charlie's positions should now be underwater
////        // Check if liquidation is possible
////        CollateralPosition memory alicePosition = this.userPosition(alice);
////        CollateralPosition memory bobPosition = this.userPosition(bob);
////        CollateralPosition memory charliePosition = this.userPosition(charlie);
////
////        uint256 aliceCollateralValue = this.userCollateralValueInUSD(alice);
////        uint256 aliceCollateralRatio = (aliceCollateralValue * 100) / alicePosition.usdsBorrowedAmount;
////        assertTrue(aliceCollateralRatio < stableConfig.minimumCollateralRatioPercent());
////
////        uint256 bobCollateralValue = this.userCollateralValueInUSD(bob);
////        uint256 bobCollateralRatio = (bobCollateralValue * 100) / bobPosition.usdsBorrowedAmount;
////        assertTrue(bobCollateralRatio < stableConfig.minimumCollateralRatioPercent());
////
////        uint256 charlieCollateralValue = this.userCollateralValueInUSD(charlie);
////        uint256 charlieCollateralRatio = (charlieCollateralValue * 100) / charliePosition.usdsBorrowedAmount;
////        assertTrue(charlieCollateralRatio < stableConfig.minimumCollateralRatioPercent());
////
////        // Attempt to liquidate the positions
////        vm.startPrank( DEV_WALLET );
////        this.liquidatePosition(alicePosition.positionID);
////        this.liquidatePosition(bobPosition.positionID);
////        this.liquidatePosition(charliePosition.positionID);
////		vm.stopPrank();
////
////        // Verify that liquidation was successful
////        assertFalse(this.userHasPosition(alice));
////        assertFalse(this.userHasPosition(bob));
////        assertFalse(this.userHasPosition(charlie));
////    }
////
////	// A unit test that makes sure that borrowing max USDS and then borrowing 1 USDS more fails
////	function testBorrowMaxPlusOneUSDS() public {
////        _depositCollateralAndBorrowMax(alice);
////
////        // Now we try to borrow 1 USDS more which should fail
////        vm.startPrank(alice);
////        vm.expectRevert("Excessive amountBorrowed" );
////        this.borrowUSDS(1);
////        vm.stopPrank();
////    }
////
////
////	// A unit test that checks that partial repayment of borrowed USDS adjust accounting correctly as does full repayment.
////	function testRepaymentAdjustsAccountingCorrectly() public {
////
////		_depositCollateralAndBorrowMax(alice);
////
////        // Save initial position
////        CollateralPosition memory initialPosition = this.userPosition(alice);
////
////        // Alice repays half of her borrowed amount
////        vm.startPrank(alice);
////
////        // Make sure cannot repay too much
////        vm.expectRevert( "Cannot repay more than the borrowed amount" );
////        this.repayUSDS(initialPosition.usdsBorrowedAmount * 2);
////
////        // Repay half
////        this.repayUSDS(initialPosition.usdsBorrowedAmount / 2);
////        vm.stopPrank();
////
////        // Check position after partial repayment
////        CollateralPosition memory partialRepaymentPosition = this.userPosition(alice);
////
////        // Renmove the least significant digit to remove rounding issues
////        assertEq(partialRepaymentPosition.usdsBorrowedAmount / 10, initialPosition.usdsBorrowedAmount / 2 / 10);
////
////        // Alice repays the rest of her borrowed amount
////        vm.startPrank(alice);
////        this.repayUSDS(partialRepaymentPosition.usdsBorrowedAmount);
////        vm.stopPrank();
////
////        // Check position after full repayment
////        // User no longer has a position
////        vm.expectRevert( "User does not have a collateral position" );
////        this.userPosition(alice);
////
////        assertFalse( this.userHasPosition(alice) );
////    }
////
////
////	function check( uint256 shareA, uint256 shareB, uint256 shareC, uint256 rA, uint256 rB, uint256 rC, uint256 vA, uint256 vB, uint256 vC, uint256 sA, uint256 sB, uint256 sC ) public
////		{
////		assertEq( this.userShareInfoForPool(alice, collateralLP).userShare, shareA, "Share A incorrect" );
////		assertEq( this.userShareInfoForPool(bob, collateralLP).userShare, shareB, "Share B incorrect" );
////		assertEq( this.userShareInfoForPool(charlie, collateralLP).userShare, shareC, "Share C incorrect" );
////
////		assertEq( this.userPendingReward( alice, collateralLP ), rA, "Incorrect pending rewards A" );
////        assertEq( this.userPendingReward( bob, collateralLP ), rB, "Incorrect pending rewards B" );
////        assertEq( this.userPendingReward( charlie, collateralLP ), rC, "Incorrect pending rewards C" );
////
////		assertEq( this.userShareInfoForPool(alice, collateralLP).virtualRewards, vA, "Virtual A incorrect" );
////		assertEq( this.userShareInfoForPool(bob, collateralLP).virtualRewards, vB, "Virtual B incorrect" );
////		assertEq( this.userShareInfoForPool(charlie, collateralLP).virtualRewards, vC, "Virtual C incorrect" );
////
////		assertEq( this.userShareInfoForPool(alice, collateralLP).userShare, shareA, "Share A incorrect" );
////		assertEq( this.userShareInfoForPool(bob, collateralLP).userShare, shareB, "Share B incorrect" );
////		assertEq( this.userShareInfoForPool(charlie, collateralLP).userShare, shareC, "Share C incorrect" );
////
////		assertEq( salt.balanceOf(alice), sA, "SALT A incorrect" );
////		assertEq( salt.balanceOf(bob), sB, "SALT B incorrect" );
////		assertEq( salt.balanceOf(charlie), sC, "SALT C incorrect" );
////		}
////
////
////
////
////	// A unit test which allows users to deposit collateral and receive varying amounts of rewards
////    // Test staking and claiming with multiple users, with Alice, Bob and Charlie each stacking, claiming and unstaking, with rewards being interleaved between each user action.  addSALTRewards should be used to add the rewards with some amount of rewards (between 10 and 100 SALT) being added after each user interaction.
////	function testMultipleUserStakingClaiming() public {
////
////		uint256 startingSaltA = salt.balanceOf(alice);
////		uint256 startingSaltB = salt.balanceOf(bob);
////        uint256 startingSaltC = salt.balanceOf(charlie);
////
////		assertEq( startingSaltA, 0, "Starting SALT A not zero" );
////		assertEq( startingSaltB, 0, "Starting SALT B not zero" );
////        assertEq( startingSaltC, 0, "Starting SALT C not zero" );
////
////        // Alice deposits 50
////        vm.prank(alice);
////        this.depositCollateral(50);
////		check( 50, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 );
////        AddedReward[] memory rewards = new AddedReward[](1);
////        rewards[0] = AddedReward({pool: collateralLP, amountToAdd: 50});
////
////        vm.prank(DEV_WALLET);
////        this.addSALTRewards(rewards);
////        vm.warp( block.timestamp + 1 hours );
////		check( 50, 0, 0, 50, 0, 0, 0, 0, 0, 0, 0, 0 );
////
////        // Bob stakes 10
////        vm.prank(bob);
////        this.depositCollateral(10);
////		check( 50, 10, 0, 50, 0, 0, 0, 10, 0, 0, 0, 0 );
////        rewards[0] = AddedReward({pool: collateralLP, amountToAdd: 30});
////
////        vm.prank(DEV_WALLET);
////        this.addSALTRewards(rewards);
////        vm.warp( block.timestamp + 1 hours );
////		check( 50, 10, 0, 75, 5, 0, 0, 10, 0, 0, 0, 0 );
////
////		// Alice claims
////		IUniswapV2Pair[] memory pools = new IUniswapV2Pair[](1);
////		pools[0] = collateralLP;
////
////        vm.prank(alice);
////        this.claimAllRewards(pools);
////		check( 50, 10, 0, 0, 5, 0, 75, 10, 0, 75, 0, 0 );
////        rewards[0] = AddedReward({pool: collateralLP, amountToAdd: 30});
////
////        vm.prank(DEV_WALLET);
////        this.addSALTRewards(rewards);
////        vm.warp( block.timestamp + 1 hours );
////		check( 50, 10, 0, 25, 10, 0, 75, 10, 0, 75, 0, 0 );
////
////        // Charlie stakes 40
////        vm.prank(charlie);
////        this.depositCollateral(40);
////		check( 50, 10, 40, 25, 10, 0, 75, 10, 80, 75, 0, 0 );
////        rewards[0] = AddedReward({pool: collateralLP, amountToAdd: 100});
////
////        vm.prank(DEV_WALLET);
////        this.addSALTRewards(rewards);
////        vm.warp( block.timestamp + 1 hours );
////		check( 50, 10, 40, 75, 20, 40, 75, 10, 80, 75, 0, 0 );
////
////		// Alice unstakes 10
////        vm.prank(alice);
////        this.withdrawCollateralAndClaim(10);
////		check( 40, 10, 40, 60, 20, 40, 60, 10, 80, 90, 0, 0 );
////        rewards[0] = AddedReward({pool: collateralLP, amountToAdd: 90});
////
////        vm.prank(DEV_WALLET);
////        this.addSALTRewards(rewards);
////        vm.warp( block.timestamp + 1 hours );
////		check( 40, 10, 40, 100, 30, 80, 60, 10, 80, 90, 0, 0 );
////
////		// Bob claims
////        vm.prank(bob);
////        this.claimAllRewards(pools);
////		check( 40, 10, 40, 100, 0, 80, 60, 40, 80, 90, 30, 0 );
////        rewards[0] = AddedReward({pool: collateralLP, amountToAdd: 90});
////
////        vm.prank(DEV_WALLET);
////        this.addSALTRewards(rewards);
////        vm.warp( block.timestamp + 1 hours );
////		check( 40, 10, 40, 140, 10, 120, 60, 40, 80, 90, 30, 0 );
////
////		// Charlie claims
////        vm.prank(charlie);
////        this.claimAllRewards(pools);
////		check( 40, 10, 40, 140, 10, 0, 60, 40, 200, 90, 30, 120 );
////        rewards[0] = AddedReward({pool: collateralLP, amountToAdd: 180});
////
////        vm.prank(DEV_WALLET);
////        this.addSALTRewards(rewards);
////        vm.warp( block.timestamp + 1 hours );
////		check( 40, 10, 40, 220, 30, 80, 60, 40, 200, 90, 30, 120 );
////
////		// Alice adds 100
////        vm.prank(alice);
////        this.depositCollateral(100);
////		check( 140, 10, 40, 220, 30, 80, 760, 40, 200, 90, 30, 120 );
////        rewards[0] = AddedReward({pool: collateralLP, amountToAdd: 190});
////
////        vm.prank(DEV_WALLET);
////        this.addSALTRewards(rewards);
////        vm.warp( block.timestamp + 1 hours );
////		check( 140, 10, 40, 360, 40, 120, 760, 40, 200, 90, 30, 120 );
////
////		// Charlie unstakes all
////        vm.prank(charlie);
////        this.withdrawCollateralAndClaim(40);
////		check( 140, 10, 0, 360, 40, 0, 760, 40, 0, 90, 30, 240 );
////        rewards[0] = AddedReward({pool: collateralLP, amountToAdd: 75});
////
////        vm.prank(DEV_WALLET);
////        this.addSALTRewards(rewards);
////        vm.warp( block.timestamp + 1 hours );
////		check( 140, 10, 0, 430, 45, 0, 760, 40, 0, 90, 30, 240 );
////
////		// Bob unstakes 5
////        vm.prank(bob);
////        this.withdrawCollateralAndClaim( 2);
////		check( 140, 8, 0, 430, 36, 0, 760, 32, 0, 90, 39, 240 );
////        rewards[0] = AddedReward({pool: collateralLP, amountToAdd: 74});
////
////        vm.prank(DEV_WALLET);
////        this.addSALTRewards(rewards);
////        vm.warp( block.timestamp + 1 hours );
////		check( 140, 8, 0, 500, 40, 0, 760, 32, 0, 90, 39, 240 );
////
////		// Bob adds 148
////        vm.prank(bob);
////        this.depositCollateral(148);
////		check( 140, 156, 0, 500, 40, 0, 760, 1364, 0, 90, 39, 240 );
////        rewards[0] = AddedReward({pool: collateralLP, amountToAdd: 592});
////
////        vm.prank(DEV_WALLET);
////        this.addSALTRewards(rewards);
////        vm.warp( block.timestamp + 1 hours );
////		check( 140, 156, 0, 780, 352, 0, 760, 1364, 0, 90, 39, 240 );
////	}
//}
