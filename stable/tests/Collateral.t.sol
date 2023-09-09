// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "../../dev/Deployment.sol";
import "../../price_feed/tests/ForcedPriceFeed.sol";


contract TestCollateral is Deployment
	{
	// User wallets for testing
    address public constant alice = address(0x1111);
    address public constant bob = address(0x2222);
    address public constant charlie = address(0x3333);

	bytes32 public collateralPoolID;


	constructor()
		{
		vm.prank(address(initialDistribution));
		salt.transfer(DEPLOYER, 100000000 ether);

		// If $COVERAGE=yes, create an instance of the contract so that coverage testing can work
		// Otherwise, what is tested is the actual deployed contract on the blockchain (as specified in Deployment.sol)
		if ( keccak256(bytes(vm.envString("COVERAGE" ))) == keccak256(bytes("yes" )))
			initializeContracts();

		priceAggregator.performUpkeep();

		(collateralPoolID,) = PoolUtils.poolID( wbtc, weth );

		// Mint some USDS to the DEPLOYER
		vm.prank( address(collateral) );
		usds.mintTo( DEPLOYER, 2000000 ether );

		vm.prank(alice);
		accessManager.grantAccess();
		vm.prank(bob);
		accessManager.grantAccess();
		vm.prank(charlie);
		accessManager.grantAccess();
		}


	function _userHasCollateral( address user ) internal view returns (bool)
		{
		return collateral.userShareForPool( user, collateralPoolID ) > 0;
		}


	function _readyUser( address user ) internal
		{
		uint256 addedWBTC = 1000 * 10 ** 8 / 4;
		uint256 addedWETH = 1000000 ether / 4;

        // Deployer holds all the test tokens
		vm.startPrank( DEPLOYER );
		wbtc.transfer( user, addedWBTC );
		weth.transfer( user, addedWETH );
		vm.stopPrank();

//		console.log( "WBTC0: ", wbtc.balanceOf( user ) );

		vm.startPrank( user );
		wbtc.approve( address(collateral), type(uint256).max );
        weth.approve( address(collateral), type(uint256).max );
		usds.approve( address(collateral), type(uint256).max );
		salt.approve( address(collateral), type(uint256).max );
		usds.approve( address(collateral), type(uint256).max );
		vm.stopPrank();
		}


    function setUp() public
    	{
    	_readyUser( DEPLOYER );
		_readyUser( alice );
		_readyUser( bob );
		_readyUser( charlie );
    	}


	// This will set the collateral / borrowed ratio at the default of 200%
	function _depositCollateralAndBorrowMax( address user ) internal
		{
		vm.startPrank( user );
		collateral.depositCollateralAndIncreaseShare(wbtc.balanceOf(user), weth.balanceOf(user), 0, block.timestamp, false );

		uint256 maxUSDS = collateral.maxBorrowableUSDS(user);
		collateral.borrowUSDS( maxUSDS );
		vm.stopPrank();
		}


	// This will set the collateral / borrowed ratio at the default of 200%
	function _depositHalfCollateralAndBorrowMax( address user ) internal
		{
		vm.startPrank( user );
		collateral.depositCollateralAndIncreaseShare(wbtc.balanceOf(user) / 2, weth.balanceOf(user) / 2, 0, block.timestamp, false );

		uint256 maxUSDS = collateral.maxBorrowableUSDS(user);
		collateral.borrowUSDS( maxUSDS );
		vm.stopPrank();
		}


	// Can be used to test liquidation by reducing BTC and ETH price.
	// Original collateral ratio is 200% with a minimum collateral ratio of 110%.
	// So dropping the prices by 46% should allow positions to be liquidated and still
	// ensure that the collateral is above water and able to be liquidated successfully.
	function _crashCollateralPrice() internal
		{
		vm.startPrank( DEPLOYER );
		forcedPriceFeed.setBTCPrice( forcedPriceFeed.getPriceBTC() * 54 / 100);
		forcedPriceFeed.setETHPrice( forcedPriceFeed.getPriceETH() * 54 / 100 );
		priceAggregator.performUpkeep();
		vm.stopPrank();
		}


	// A unit test that verifies the liquidateUser function correctly transfers WETH to the liquidator and WBTC/WETH to the USDS contract
	function testLiquidatePosition() public {
		assertEq(wbtc.balanceOf(address(usds)), 0, "USDS contract should start with zero WBTC");
		assertEq(weth.balanceOf(address(usds)), 0, "USDS contract should start with zero WETH");
		assertEq(usds.balanceOf(alice), 0, "Alice should start with zero USDS");

		// Total needs to be at least 2500
		priceAggregator.performUpkeep();
		uint256 depositedWBTC = ( 1000 ether *10**8) / priceAggregator.getPriceBTC();
		uint256 depositedWETH = ( 1000 ether *10**18) / priceAggregator.getPriceETH();

		// Alice will deposit collateral and borrow max USDS
		vm.startPrank(alice);
		collateral.depositCollateralAndIncreaseShare( depositedWBTC, depositedWETH, 0, block.timestamp, false );
		uint256 maxUSDS = collateral.maxBorrowableUSDS(alice);
		assertEq( maxUSDS, 0, "Alice doesn't have enough collateral to borrow USDS" );

		vm.warp( block.timestamp + 1 hours );
		collateral.depositCollateralAndIncreaseShare( depositedWBTC, depositedWETH, 0, block.timestamp, false );
		maxUSDS = collateral.maxBorrowableUSDS(alice);

		depositedWBTC = depositedWBTC * 2;
		depositedWETH = depositedWETH * 2;

		collateral.borrowUSDS( maxUSDS );
		vm.stopPrank();

		uint256 maxWithdrawable = collateral.maxWithdrawableCollateral(alice);
		assertEq( maxWithdrawable, 0, "Alice shouldn't be able to withdraw any collateral" );


		uint256 aliceCollateralShare = collateral.userShareForPool( alice, collateralPoolID );
		uint256 aliceCollateralValue = collateral.collateralValueInUSD( aliceCollateralShare );


		uint256 aliceBorrowedUSDS = usds.balanceOf(alice);
		assertEq( collateral.usdsBorrowedByUsers(alice), aliceBorrowedUSDS, "Alice amount USDS borrowed not what she has" );

		// Borrowed USDS should be about 50% of the aliceCollateralValue
		assertTrue( aliceBorrowedUSDS > ( aliceCollateralValue * 499 / 1000 ), "Alice did not borrow sufficient USDS" );
		assertTrue( aliceBorrowedUSDS < ( aliceCollateralValue * 501 / 1000 ), "Alice did not borrow sufficient USDS" );

		// Try and fail to liquidate alice
		vm.expectRevert( "User cannot be liquidated" );
		vm.prank(bob);
        collateral.liquidateUser(alice);

		// Artificially crash the collateral price
		_crashCollateralPrice();

		// Delay before the liquidation
		vm.warp( block.timestamp + 1 days );

		uint256 bobStartingWETH = weth.balanceOf(bob);

		// Liquidate Alice's position
		vm.prank(bob);
		collateral.liquidateUser(alice);

		uint256 bobRewardWETH = weth.balanceOf(bob) - bobStartingWETH;

		// Verify that Alice's position has been liquidated
		assertEq( collateral.userShareForPool(alice, collateralPoolID), 0 );
        assertEq( collateral.usdsBorrowedByUsers(alice), 0 );

		// Verify that Bob has received WETH for the liquidation
		uint256 bobExpectedReward = depositedWETH * 10 / 100;

		assertEq(bobExpectedReward, bobRewardWETH , "Bob should have received WETH for liquidating Alice");

		// Verify that USDS received the WBTC and WETH form Alice's liquidated collateral
		assertEq(wbtc.balanceOf(address(usds)), depositedWBTC, "The USDS contract should have received Alice's WBTC");
		assertEq(weth.balanceOf(address(usds)), depositedWETH - bobRewardWETH, "The USDS contract should have received Alice's WETH - Bob's WETH reward");
		}


	// A unit test that verifies liquidateUser behavior where the borrowed amount is zero.
	function testLiquidatePositionWithZeroBorrowedAmount() public {
		assertEq(wbtc.balanceOf(address(usds)), 0, "USDS contract should start with zero WBTC");
		assertEq(weth.balanceOf(address(usds)), 0, "USDS contract should start with zero WETH");
		assertEq(usds.balanceOf(alice), 0, "Alice should start with zero USDS");

		// Alice will deposit all her collateral but not borrow any
		vm.startPrank( alice );
		collateral.depositCollateralAndIncreaseShare(wbtc.balanceOf(alice), weth.balanceOf(alice), 0, block.timestamp, false );

		// Artificially crash the collateral price
		_crashCollateralPrice();

		// Delay before the liquidation
		vm.warp( block.timestamp + 1 days );

		// Try and fail to liquidate alice
		vm.expectRevert( "User cannot be liquidated" );
		vm.prank(bob);
		collateral.liquidateUser(alice);
		}


   	// A unit test that verifies the liquidateUser function's handling of position liquidation, including both valid and invalid position IDs, cases where the position has already been liquidated.
   	function testLiquidatePositionFailure() public {
		assertEq(wbtc.balanceOf(address(usds)), 0, "USDS contract should start with zero WBTC");
		assertEq(weth.balanceOf(address(usds)), 0, "USDS contract should start with zero WETH");
		assertEq(usds.balanceOf(alice), 0, "Alice should start with zero USDS");

		// Alice will deposit all her collateral and borrow max
    	_depositCollateralAndBorrowMax(alice);

		// Artificially crash the collateral price
		_crashCollateralPrice();

		// Delay before the liquidation
		vm.warp( block.timestamp + 1 days );

		// Now Alice's position should be liquidatable
    	collateral.liquidateUser(alice);

    	// Shouldn't be able to liquidate twice
    	vm.expectRevert("User cannot be liquidated");
    	collateral.liquidateUser(alice);

    	// Trying to liquidate an invalid user should fail
    	vm.expectRevert("User cannot be liquidated");
    	collateral.liquidateUser(address(0xDEAD));
    }


   	// A unit test that checks the liquidateUser function for proper calculation, and when the caller tries to liquidate their own position.
	function testLiquidateSelf() public {
		uint256 initialSupplyUSDS = IERC20(address(usds)).totalSupply();
        _depositCollateralAndBorrowMax(alice);
		assertTrue( _userHasCollateral(alice) );

		assertTrue( initialSupplyUSDS < IERC20(address(usds)).totalSupply(), "Supply after borrow should be higher" );

        _crashCollateralPrice();

		// Warp past the sharedRewards cooldown
		vm.warp( block.timestamp + 1 days );

        // Attempting to liquidate own position should revert
        vm.prank(alice);
        vm.expectRevert( "Cannot liquidate self" );
        collateral.liquidateUser(alice);
		assertTrue( _userHasCollateral(alice) );

        // Proper liquidation by another account
        vm.prank(bob);
        collateral.liquidateUser(alice);

		assertFalse( _userHasCollateral(alice) );
    }


	// A unit test where a user is liquidated and then adds another position which is then liquidated as well
	function testUserLiquidationTwice() public {
        // Deposit and borrow for Alice
        _depositHalfCollateralAndBorrowMax(alice);

        // Check if Alice has a position
        assertTrue(_userHasCollateral(alice));

        // Crash the collateral price
        _crashCollateralPrice();
        vm.warp( block.timestamp + 1 days );

        // Liquidate Alice's position
        collateral.liquidateUser(alice);

        // Check if Alice's position was liquidated
        assertFalse(_userHasCollateral(alice));

        vm.warp( block.timestamp + 1 days );

        // Deposit and borrow again for Alice
        _depositHalfCollateralAndBorrowMax(alice);

        // Check if Alice has a new position
        assertTrue(_userHasCollateral(alice));

        // Crash the collateral price again
        _crashCollateralPrice();
        vm.warp( block.timestamp + 1 days );

        // Liquidate Alice's position again
        collateral.liquidateUser(alice);

        // Check if Alice's position was liquidated again
        assertFalse(_userHasCollateral(alice));
    }



	// A unit test where a user deposits, borrows, deposits and is then liquidated
	function testUserDepositBorrowDepositAndLiquidate() public {
		vm.startPrank( alice );
		uint256 wbtcDeposit = wbtc.balanceOf(alice) / 4;
		uint256 wethDeposit = weth.balanceOf(alice) / 4;

		collateral.depositCollateralAndIncreaseShare(wbtcDeposit, wethDeposit, 0, block.timestamp, false );

        // Alice borrows USDS
        uint256 maxBorrowable = collateral.maxBorrowableUSDS(alice);
        collateral.borrowUSDS( maxBorrowable );

        // Alice deposits more collateral - but fails due to the cooldown
        vm.expectRevert( "Must wait for the cooldown to expire" );
		collateral.depositCollateralAndIncreaseShare(wbtcDeposit, wethDeposit, 0, block.timestamp, false );

		vm.warp( block.timestamp + 1 days );

		// Try depositing again
		collateral.depositCollateralAndIncreaseShare(wbtcDeposit, wethDeposit, 0, block.timestamp, false );
		vm.stopPrank();

//		console.log( "ALICE COLLATERAL VALUE: ", collateral.userCollateralValueInUSD( alice ) / 10**18 );
//		console.log( "ALICE BORROWED USDS: ", collateral.usdsBorrowedByUser(alice) / 10**18 );

        // Crash the collateral price so Alice's position can be liquidated
        _crashCollateralPrice();
        _crashCollateralPrice();
        _crashCollateralPrice();
		vm.warp( block.timestamp + 1 days );

		assertTrue(_userHasCollateral(alice));

        // Liquidate Alice's position
        collateral.liquidateUser(alice);

		assertFalse(_userHasCollateral(alice));
    }


	// A unit test that verifies the userCollateralValueInUSD and underlyingTokenValueInUSD function with different collateral amounts and different token prices, including when the user does not have a position.
	function testUserCollateralValueInUSD() public
    	{
    	// Determine how many BTC and ETH alice has in colalteral
    	_depositCollateralAndBorrowMax(alice);

		(uint256 reserveWBTC, uint256 reserveWETH) = pools.getPoolReserves(wbtc, weth);
		uint256 totalLP = pools.totalLiquidity( collateralPoolID );

		uint256 aliceCollateral = collateral.userShareForPool( alice, collateralPoolID );

		uint256 aliceBTC = ( reserveWBTC * aliceCollateral ) / totalLP; // 8 decimals
		uint256 aliceETH = ( reserveWETH * aliceCollateral ) / totalLP; // 18 decimals

		vm.startPrank( DEPLOYER );
		forcedPriceFeed.setBTCPrice( 20000 ether );
		forcedPriceFeed.setETHPrice( 2000 ether );
		priceAggregator.performUpkeep();
		vm.stopPrank();

        uint256 aliceCollateralValue0 = collateral.userCollateralValueInUSD(alice);

        // Make sure resulting calculation has 18 decimals
        uint256 aliceCollateralValue = aliceBTC * 20000 ether / 10**8 + aliceETH * 2000;
		assertEq( aliceCollateralValue0, aliceCollateralValue, "Collateral value different than expected" );


		vm.startPrank( DEPLOYER );
		forcedPriceFeed.setBTCPrice( 15000 ether );
		forcedPriceFeed.setETHPrice( 1777 ether );
		priceAggregator.performUpkeep();
		vm.stopPrank();

        aliceCollateralValue0 = collateral.userCollateralValueInUSD(alice);

        // Make sure resulting calculation has 18 decimals
        aliceCollateralValue = aliceBTC * 15000 ether / 10**8 + aliceETH * 1777;
		assertEq( aliceCollateralValue0, aliceCollateralValue, "Collateral value different than expected" );


		vm.startPrank( DEPLOYER );
		forcedPriceFeed.setBTCPrice( 45000 ether );
		forcedPriceFeed.setETHPrice( 11777 ether );
		priceAggregator.performUpkeep();
		vm.stopPrank();

        aliceCollateralValue0 = collateral.userCollateralValueInUSD(alice);

        // Make sure resulting calculation has 18 decimals
        aliceCollateralValue = aliceBTC * 45000 ether / 10**8 + aliceETH * 11777;
		assertEq( aliceCollateralValue0, aliceCollateralValue, "Collateral value different than expected" );

		assertEq( collateral.userCollateralValueInUSD(bob), 0, "Non-existent collateral value should be zero" );
    	}


	// A unit test that verifies the findLiquidatableUsers function returns an empty array when there are no liquidatable positions and checks it for a range of indices.
	function testFindLiquidatablePositions_noLiquidatablePositions() public {
		// Alice, Bob, and Charlie deposit collateral and borrow within the limit
		_depositHalfCollateralAndBorrowMax(alice);
		_depositHalfCollateralAndBorrowMax(bob);
		_depositHalfCollateralAndBorrowMax(charlie);

		address[] memory liquidatableUsers = collateral.findLiquidatableUsers();
        assertEq(liquidatableUsers.length, 0, "No liquidatable users should be found");
    }


	// A unit test to ensure that the borrowUSDS function updates the _walletsWithBorrowedUSDS mapping correctly, and that the _walletsWithBorrowedUSDS mapping is also updated properly after liquidation.
	function testBorrowUSDSAndLiquidation() public {
        // Deposit collateral
        vm.startPrank(alice);
		collateral.depositCollateralAndIncreaseShare(wbtc.balanceOf(alice), weth.balanceOf(alice), 0, block.timestamp, false );
		assertTrue(_userHasCollateral(alice));
		assertEq( collateral.numberOfUsersWithBorrowedUSDS(), 0);

        // Borrow USDS
        uint256 borrowedAmount = collateral.maxBorrowableUSDS(alice);
        collateral.borrowUSDS(borrowedAmount);
		assertEq( collateral.numberOfUsersWithBorrowedUSDS(), 1);

        // Check that Alice's borrowed amount increased
        assertEq(collateral.usdsBorrowedByUsers(alice), borrowedAmount);

        // Crash collateral price to enable liquidation
        _crashCollateralPrice();
		vm.warp( block.timestamp + 1 days );

        // Liquidate alice
        collateral.liquidateUser(alice);

        // Confirm that position is removed from _walletsWithBorrowedUSDS
		assertFalse(_userHasCollateral(alice));
        assertEq(collateral.usdsBorrowedByUsers(alice), 0);
		assertEq( collateral.numberOfUsersWithBorrowedUSDS(), 0);
    }


	// A unit test for collateral.numberOfUsersWithBorrowedUSDS to verify that it returns the correct number of open positions.
	function testNumberOfOpenPositions() public {
        // Alice, Bob and Charlie each deposit and borrow
        _depositCollateralAndBorrowMax(alice);
        _depositCollateralAndBorrowMax(bob);
        _depositCollateralAndBorrowMax(charlie);

    	vm.warp( block.timestamp + 1 days );

        // Check collateral.numberOfUsersWithBorrowedUSDS returns correct number of open positions
        assertEq( collateral.numberOfUsersWithBorrowedUSDS(), 3);

        // Alice repays loan, reducing number of open positions
        uint256 aliceBorrowedAmount = usds.balanceOf(alice);

		vm.prank(address(collateral));
        usds.mintTo(alice, aliceBorrowedAmount);
        vm.startPrank(alice);
        collateral.repayUSDS(aliceBorrowedAmount / 2 );
        vm.stopPrank();

        // Check collateral.numberOfUsersWithBorrowedUSDS returns correct number of open positions
        assertEq( collateral.numberOfUsersWithBorrowedUSDS() , 3);

		vm.prank(alice);
		collateral.repayUSDS(aliceBorrowedAmount - aliceBorrowedAmount / 2);

        assertEq( collateral.numberOfUsersWithBorrowedUSDS() , 2);

        // _crashCollateralPrice to force liquidation of a position
        _crashCollateralPrice();

        // Check liquidation of Bob's position
        collateral.liquidateUser(bob);

        // Check collateral.numberOfUsersWithBorrowedUSDS returns correct number of open positions
        assertEq( collateral.numberOfUsersWithBorrowedUSDS(), 1);
    }


	// A unit test for totalCollateralValueInUSD to verify that it correctly calculates the total value of all collateral.
	    // Here's a unit test for the `totalCollateralValueInUSD` function
        function testTotalCollateralValueInUSD() public {

            // Initial deposit for Alice, Bob and Charlie
            _depositCollateralAndBorrowMax(alice);
            _depositCollateralAndBorrowMax(bob);
            _depositCollateralAndBorrowMax(charlie);

            // Get total collateral value before crash
            uint256 totalCollateral = collateral.totalCollateralValueInUSD();
			uint256 aliceCollateralValue = collateral.userCollateralValueInUSD(alice);

//			console.log( "totalCollateral: ", totalCollateral );
//			console.log( "aliceCollateralValue: ", aliceCollateralValue );

			// All three users have the same amount of collateral
			// Allow slight variation in quoted price
			assertTrue( totalCollateral > (aliceCollateralValue * 3 * 99 / 100), "Total collateral does not reflect the correct value" );
			assertTrue( totalCollateral < (aliceCollateralValue * 3 * 101 / 100), "Total collateral does not reflect the correct value" );
        }


	// A unit test that verifies that collateralValue correctly calculates the collateral value for given collateral amounts.
	function testUserCollateralValueInUSD2() public {

		_depositCollateralAndBorrowMax(alice);

		(uint256 reserveWBTC, uint256 reserveWETH) = pools.getPoolReserves( wbtc, weth );
		uint256 totalCollateral = pools.totalLiquidity( collateralPoolID );

		uint256 aliceCollateral = collateral.userShareForPool( alice, collateralPoolID );
		uint256 aliceBTC = ( reserveWBTC * aliceCollateral ) / totalCollateral;
		uint256 aliceETH = ( reserveWETH * aliceCollateral ) / totalCollateral;

		// Prices from the price feed have 18 decimals
		uint256 btcPrice = priceAggregator.getPriceBTC();
        uint256 ethPrice = priceAggregator.getPriceETH();

		// Keep the 18 decimals from the price and remove the decimals from the amount held by the user
		uint256 btcValue = ( aliceBTC * btcPrice ) / (10 ** 8 );
		uint256 ethValue = ( aliceETH * ethPrice ) / (10 ** 18 );

		uint256 manualCollateralValue = btcValue + ethValue;
    	uint256 actualCollateralValue = collateral.userCollateralValueInUSD(alice);

		assertEq( manualCollateralValue, actualCollateralValue, "Calculated and actual collateral values are not the same" );
    }


	// A unit test that checks the deposit and withdrawal of collateral with various amounts, ensuring that an account cannot withdraw collateral that they do not possess.
	function testDepositAndWithdrawCollateral() public
    {
    	// Setup
    	vm.startPrank(alice);

		uint256 wbtcToDeposit = wbtc.balanceOf(alice) / 2 + 1;
		uint256 wethToDeposit = weth.balanceOf(alice) / 2  + 1;
		collateral.depositCollateralAndIncreaseShare(wbtcToDeposit, wethToDeposit, 0, block.timestamp, false );

    	// Verify the result
    	uint256 depositAmount = collateral.userShareForPool(alice, collateralPoolID);
    	assertEq(depositAmount, Math.sqrt( wbtcToDeposit * wethToDeposit ) );

		vm.warp( block.timestamp + 1 days );

    	// Alice tries to withdraw more collateral than she has in the contract
    	vm.expectRevert( "Excessive collateralToWithdraw" );
    	collateral.withdrawCollateralAndClaim( depositAmount + 1, 0, 0, block.timestamp );

		vm.warp( block.timestamp + 1 days );

//		console.log( "COLLATERAL: ", collateral.userShareForPool(alice, collateralPoolID) );
    	// Alice withdraws half the collateral
    	collateral.withdrawCollateralAndClaim( depositAmount / 2, 0, 0, block.timestamp );
//		console.log( "COLLATERAL: ", collateral.userShareForPool(alice, collateralPoolID) );

		vm.warp( block.timestamp + 1 days );

		// Withdraw too much
    	vm.expectRevert( "Excessive collateralToWithdraw" );
    	collateral.withdrawCollateralAndClaim( depositAmount / 2 + 2, 0, 0, block.timestamp );
//		console.log( "COLLATERAL: ", collateral.userShareForPool(alice, collateralPoolID) );

		// Withdraw the rest
    	collateral.withdrawCollateralAndClaim( depositAmount / 2, 0, 0, block.timestamp );

		vm.warp( block.timestamp + 1 days );

    	// Verify the result
    	assertEq(collateral.userShareForPool(alice, collateralPoolID), 0);
    }


	// A unit test to verify that an account cannot borrow USDS more than their max borrowable limit
	function testCannotBorrowMoreThanMaxBorrowableLimit() public {
        vm.startPrank(alice);

		uint256 wbtcToDeposit = wbtc.balanceOf(alice);
		uint256 wethToDeposit = weth.balanceOf(alice);
		collateral.depositCollateralAndIncreaseShare(wbtcToDeposit, wethToDeposit, 0, block.timestamp, false );

        uint256 maxBorrowableAmount = collateral.maxBorrowableUSDS(alice);
        vm.expectRevert( "Excessive amountBorrowed" );
        collateral.borrowUSDS(maxBorrowableAmount + 1 ether);

        vm.stopPrank();
	    }


	// A unit test to verify that an account cannot repay USDS if they don't have a position.
    function testCannotRepayUSDSWithoutPosition() public {
        vm.startPrank(bob);
        vm.expectRevert( "User does not have any collateral" );
        collateral.repayUSDS(1 ether);
        vm.stopPrank();
    }

    // A unit test to validate borrowUSDS function for an account that has not deposited any collateral but tries to borrow USDS
    function testCannotBorrowUSDSWithoutPosition() public {
        vm.startPrank(bob);
        vm.expectRevert( "User does not have any collateral" );
        collateral.borrowUSDS(1 ether);
        vm.stopPrank();
    }



	// A unit test that verifies the _userHasCollateral function for accounts with and without positions.
	function testUserPositionFunctions() public {
        // Initially, Alice, Bob and Charlie should not have positions
        assertFalse(_userHasCollateral(alice));
        assertFalse(_userHasCollateral(bob));
        assertFalse(_userHasCollateral(charlie));

        // After Alice deposits collateral and borrows max, she should have a position
        _depositCollateralAndBorrowMax(alice);
        assertTrue(_userHasCollateral(alice));

        // Still, Bob and Charlie should not have positions
        assertFalse(_userHasCollateral(bob));
        assertFalse(_userHasCollateral(charlie));

        // After Bob deposits collateral and borrows max, he should have a position
        _depositCollateralAndBorrowMax(bob);
        assertTrue(_userHasCollateral(bob));

        // Finally, Charlie still should not have a position
        assertFalse(_userHasCollateral(charlie));
    }


	// A unit test that validates maxWithdrawableCollateral and maxBorrowableUSDS functions with scenarios including accounts without positions and accounts with positions whose collateral value is less than the minimum required to borrow USDS.
	function testMaxWithdrawableLP_and_maxBorrowableUSDS() public {
        vm.startPrank(alice);

		collateral.depositCollateralAndIncreaseShare(10000, 10000, 0, block.timestamp, false );

        uint256 maxWithdrawableLPForAlice = collateral.maxWithdrawableCollateral(alice);
        uint256 maxBorrowableUSDSForAlice = collateral.maxBorrowableUSDS(alice);

        assertTrue(maxWithdrawableLPForAlice == 10000, "maxWithdrawableCollateral should be 10000");
        assertTrue(maxBorrowableUSDSForAlice == 0, "Max borrowable USDS should be zero");
		vm.stopPrank();

        // Scenario where account does not have a position
		vm.startPrank(bob);
        uint256 maxWithdrawableLPForNonPositionUser = collateral.maxWithdrawableCollateral(bob);
        uint256 maxBorrowableUSDSForNonPositionUser = collateral.maxBorrowableUSDS(bob);

        assertTrue(maxWithdrawableLPForNonPositionUser == 0, "maxWithdrawableCollateral for user without position should be zero");
        assertTrue(maxBorrowableUSDSForNonPositionUser == 0, "Max borrowable USDS for user without position should be zero");
		vm.stopPrank();

        // Scenario where a random user tries to borrow and withdraw
        address randomUser = address(0xDEAD);
		_readyUser( randomUser );

		vm.startPrank( randomUser );
        try collateral.depositCollateralAndIncreaseShare(10000, 10000, 0, block.timestamp, false ) {
            fail("depositCollateral should have failed for random user");
        } catch {
            assertEq(collateral.userCollateralValueInUSD(randomUser), 0);
        }

        try collateral.borrowUSDS(100 ether) {
            fail("borrowUSDS should have failed for random user");
        } catch {
            assertEq(collateral.userCollateralValueInUSD(randomUser), 0);
        }
        vm.stopPrank();
    }


	// A unit test that verifies the accuracy of the findLiquidatableUsers function in more complex scenarios. This could include scenarios where multiple positions should be liquidated at once, or where no positions should be liquidated despite several being close to the threshold.
	function testFindLiquidatablePositions() public {
        _depositCollateralAndBorrowMax(alice);
        _depositCollateralAndBorrowMax(bob);
        _depositCollateralAndBorrowMax(charlie);

		_crashCollateralPrice();

		vm.warp( block.timestamp + 1 days );

        // All three positions should be liquidatable.
        assertEq(collateral.findLiquidatableUsers().length, 3);

		vm.startPrank(alice);
		collateral.repayUSDS( collateral.usdsBorrowedByUsers(alice) );
		vm.stopPrank();

        // Now only two positions should be liquidatable.
        assertEq(collateral.findLiquidatableUsers().length, 2);

        // Let's liquidate one of the positions.
        collateral.liquidateUser(bob);

        // Now only one position should be liquidatable.
        assertEq(collateral.findLiquidatableUsers().length, 1);

        // Charlie also repays all his debt.
		vm.startPrank(charlie);
		collateral.repayUSDS( collateral.usdsBorrowedByUsers(charlie) );
		vm.stopPrank();

        // Now no positions should be liquidatable.
        assertEq(collateral.findLiquidatableUsers().length, 0);
    }


	// A unit test to verify the accuracy of userCollateralValueInUSD when there are multiple positions opened by a single user.
	function testUserCollateralValueInUSD_multiplePositions() public {

    	// Setup
    	vm.startPrank(alice);

		uint256 wbtcToDeposit = wbtc.balanceOf(alice) / 10;
		uint256 wethToDeposit = weth.balanceOf(alice) / 10;

		uint256 initialTokenValue = collateral.underlyingTokenValueInUSD( wbtcToDeposit * 6, wethToDeposit * 6 );

		collateral.depositCollateralAndIncreaseShare(wbtcToDeposit, wethToDeposit, 0, block.timestamp, false );
        vm.warp( block.timestamp + 1 days );

		collateral.depositCollateralAndIncreaseShare(wbtcToDeposit * 2, wethToDeposit * 2, 0, block.timestamp, false );
        vm.warp( block.timestamp + 1 days );

		collateral.depositCollateralAndIncreaseShare(wbtcToDeposit * 3, wethToDeposit * 3, 0, block.timestamp, false );
        vm.warp( block.timestamp + 1 days );

        // check the collateral value
        uint256 aliceCollateralValue = collateral.userCollateralValueInUSD(alice);
        assertEq(aliceCollateralValue, initialTokenValue, "The final collateral value is incorrect");
    }


	// A unit test that ensures correct behavior when BTC/ETH prices drop by more than 50% and the collateral positions are underwater.
	function testUnderwaterPosition() public
    {
        // Setup
        _depositCollateralAndBorrowMax(alice);
        _depositCollateralAndBorrowMax(bob);
        _depositCollateralAndBorrowMax(charlie);

        // Simulate a 50% price drop for both BTC and ETH
        _crashCollateralPrice();

        // Simulate another 50% price drop for both BTC and ETH
        _crashCollateralPrice();

        vm.warp( block.timestamp + 1 days );

        // Alice, Bob and Charlie's positions should now be underwater
        uint256 aliceCollateralValue = collateral.userCollateralValueInUSD(alice);
        uint256 aliceCollateralRatio = (aliceCollateralValue * 100) / collateral.usdsBorrowedByUsers(alice);
        assertTrue(aliceCollateralRatio < stableConfig.minimumCollateralRatioPercent());

        uint256 bobCollateralValue = collateral.userCollateralValueInUSD(bob);
        uint256 bobCollateralRatio = (bobCollateralValue * 100) / collateral.usdsBorrowedByUsers(bob);
        assertTrue(bobCollateralRatio < stableConfig.minimumCollateralRatioPercent());

        uint256 charlieCollateralValue = collateral.userCollateralValueInUSD(charlie);
        uint256 charlieCollateralRatio = (charlieCollateralValue * 100) / collateral.usdsBorrowedByUsers(charlie);
        assertTrue(charlieCollateralRatio < stableConfig.minimumCollateralRatioPercent());

        // Liquidate the positions
        vm.startPrank( DEPLOYER );
        collateral.liquidateUser(alice);
        collateral.liquidateUser(bob);
        collateral.liquidateUser(charlie);
		vm.stopPrank();

        // Verify that liquidation was successful
        assertEq(collateral.userShareForPool(alice, collateralPoolID), 0);
        assertEq(collateral.userShareForPool(bob, collateralPoolID), 0);
        assertEq(collateral.userShareForPool(charlie, collateralPoolID), 0);
    }


	// A unit test that makes sure that borrowing max USDS and then borrowing 1 USDS more fails
	function testBorrowMaxPlusOneUSDS() public {
        _depositCollateralAndBorrowMax(alice);

        // Now we try to borrow 1 USDS more which should fail
        vm.startPrank(alice);
        vm.expectRevert("Excessive amountBorrowed" );
        collateral.borrowUSDS(1);
        vm.stopPrank();
    }


	// A unit test that checks that partial repayment of borrowed USDS adjust accounting correctly as does full repayment.
	function testRepaymentAdjustsAccountingCorrectly() public {

		_depositCollateralAndBorrowMax(alice);

		uint256 aliceBorrowedUSDS = collateral.usdsBorrowedByUsers(alice);

        // Alice repays half of her borrowed amount
        vm.startPrank(alice);

        // Make sure cannot repay too much
        vm.expectRevert( "Cannot repay more than the borrowed amount" );
        collateral.repayUSDS(aliceBorrowedUSDS * 2);

        // Repay half
        collateral.repayUSDS(aliceBorrowedUSDS / 2);
        vm.stopPrank();
		assertEq( collateral.usdsBorrowedByUsers(alice), usds.balanceOf(alice), "Alice amount USDS borrowed not what she has" );

        // Check position after partial repayment
        assertEq(collateral.usdsBorrowedByUsers(alice), aliceBorrowedUSDS / 2 );
		assertEq( collateral.usdsBorrowedByUsers(alice), usds.balanceOf(alice), "Alice amount USDS borrowed not what she has" );

        // Alice repays the rest of her borrowed amount
        vm.startPrank(alice);
        collateral.repayUSDS(collateral.usdsBorrowedByUsers(alice));
        vm.stopPrank();
		assertEq( collateral.usdsBorrowedByUsers(alice), usds.balanceOf(alice), "Alice amount USDS borrowed not what she has" );

        // Check position after full repayment
        assertEq( collateral.usdsBorrowedByUsers(alice), 0 );
		assertEq( collateral.numberOfUsersWithBorrowedUSDS(), 0 );
    }


	function check( uint256 shareA, uint256 shareB, uint256 shareC, uint256 rA, uint256 rB, uint256 rC, uint256 sA, uint256 sB, uint256 sC ) public
		{
		assertEq( collateral.userShareForPool(alice, collateralPoolID), shareA, "Share A incorrect" );
		assertEq( collateral.userShareForPool(bob, collateralPoolID), shareB, "Share B incorrect" );
		assertEq( collateral.userShareForPool(charlie, collateralPoolID), shareC, "Share C incorrect" );

		assertEq( collateral.userPendingReward( alice, collateralPoolID ), rA, "Incorrect pending rewards A" );
        assertEq( collateral.userPendingReward( bob, collateralPoolID ), rB, "Incorrect pending rewards B" );
        assertEq( collateral.userPendingReward( charlie, collateralPoolID ), rC, "Incorrect pending rewards C" );

		assertEq( salt.balanceOf(alice), sA, "SALT A incorrect" );
		assertEq( salt.balanceOf(bob), sB, "SALT B incorrect" );
		assertEq( salt.balanceOf(charlie), sC, "SALT C incorrect" );
		}


	// A unit test which allows users to deposit collateral and receive varying amounts of rewards
    // Test staking and claiming with multiple users, with Alice, Bob and Charlie each stacking, claiming and unstaking, with rewards being interleaved between each user action.  addSALTRewards should be used to add the rewards with some amount of rewards (between 10 and 100 SALT) being added after each user interaction.
	function testMultipleUserStakingClaiming() public {

		uint256 startingSaltA = salt.balanceOf(alice);
		uint256 startingSaltB = salt.balanceOf(bob);
        uint256 startingSaltC = salt.balanceOf(charlie);

		assertEq( startingSaltA, 0, "Starting SALT A not zero" );
		assertEq( startingSaltB, 0, "Starting SALT B not zero" );
        assertEq( startingSaltC, 0, "Starting SALT C not zero" );

        // Alice deposits 50
        vm.prank(alice);
		collateral.depositCollateralAndIncreaseShare(50*10**8, 50*10**8, 0, block.timestamp, false );
		check( 50*10**8, 0, 0, 0, 0, 0, 0, 0, 0 );
        AddedReward[] memory rewards = new AddedReward[](1);
        rewards[0] = AddedReward({poolID: collateralPoolID, amountToAdd: 50*10**8});

        vm.prank(DEPLOYER);
        collateral.addSALTRewards(rewards);
        vm.warp( block.timestamp + 1 hours );
		check( 50*10**8, 0, 0, 50*10**8, 0, 0, 0, 0, 0 );

        // Bob stakes 10
        vm.prank(bob);
		collateral.depositCollateralAndIncreaseShare(10*10**8, 10*10**8, 0, block.timestamp, false );
		check( 50*10**8, 10*10**8, 0, 50*10**8, 0, 0, 0, 0, 0 );
        rewards[0] = AddedReward({poolID: collateralPoolID, amountToAdd: 30*10**8});

        vm.prank(DEPLOYER);
        collateral.addSALTRewards(rewards);
        vm.warp( block.timestamp + 1 hours );
		check( 50*10**8, 10*10**8, 0, 75*10**8, 5*10**8, 0, 0, 0, 0 );

		// Alice claims
		bytes32[] memory pools = new bytes32[](1);
		pools[0] = collateralPoolID;

        vm.prank(alice);
        collateral.claimAllRewards(pools);
		check( 50*10**8, 10*10**8, 0, 0, 5*10**8, 0, 75*10**8, 0, 0 );
        rewards[0] = AddedReward({poolID: collateralPoolID, amountToAdd: 30*10**8});

        vm.prank(DEPLOYER);
        collateral.addSALTRewards(rewards);
        vm.warp( block.timestamp + 1 hours );
		check( 50*10**8, 10*10**8, 0, 25*10**8, 10*10**8, 0, 75*10**8, 0, 0 );

        // Charlie stakes 40
        vm.prank(charlie);
		collateral.depositCollateralAndIncreaseShare(40 *10**8, 40 *10**8, 0, block.timestamp, false );
		check( 50*10**8, 10*10**8, 40*10**8, 25*10**8, 10*10**8, 0, 75*10**8, 0, 0 );
        rewards[0] = AddedReward({poolID: collateralPoolID, amountToAdd: 100*10**8});

        vm.prank(DEPLOYER);
        collateral.addSALTRewards(rewards);
        vm.warp( block.timestamp + 1 hours );
		check( 50*10**8, 10*10**8, 40*10**8, 75*10**8, 20*10**8, 40*10**8, 75*10**8, 0, 0 );

		// Alice unstakes 10
        vm.prank(alice);
        collateral.withdrawCollateralAndClaim(10*10**8, 0, 0, block.timestamp);
		check( 40*10**8, 10*10**8, 40*10**8, 60*10**8, 20*10**8, 40*10**8, 90*10**8, 0, 0 );
        rewards[0] = AddedReward({poolID: collateralPoolID, amountToAdd: 90*10**8});

        vm.prank(DEPLOYER);
        collateral.addSALTRewards(rewards);
        vm.warp( block.timestamp + 1 hours );
		check( 40*10**8, 10*10**8, 40*10**8, 100*10**8, 30*10**8, 80*10**8, 90*10**8, 0, 0 );

		// Bob claims
        vm.prank(bob);
        collateral.claimAllRewards(pools);
		check( 40*10**8, 10*10**8, 40*10**8, 100*10**8, 0, 80*10**8, 90*10**8, 30*10**8, 0 );
        rewards[0] = AddedReward({poolID: collateralPoolID, amountToAdd: 90*10**8});

        vm.prank(DEPLOYER);
        collateral.addSALTRewards(rewards);
        vm.warp( block.timestamp + 1 hours );
		check( 40*10**8, 10*10**8, 40*10**8, 140*10**8, 10*10**8, 120*10**8, 90*10**8, 30*10**8, 0 );

		// Charlie claims
        vm.prank(charlie);
        collateral.claimAllRewards(pools);
		check( 40*10**8, 10*10**8, 40*10**8, 140*10**8, 10*10**8, 0, 90*10**8, 30*10**8, 120*10**8 );
        rewards[0] = AddedReward({poolID: collateralPoolID, amountToAdd: 180*10**8});

        vm.prank(DEPLOYER);
        collateral.addSALTRewards(rewards);
        vm.warp( block.timestamp + 1 hours );
		check( 40*10**8, 10*10**8, 40*10**8, 220*10**8, 30*10**8, 80*10**8, 90*10**8, 30*10**8, 120*10**8 );

		// Alice adds 100
        vm.prank(alice);
		collateral.depositCollateralAndIncreaseShare(100 *10**8, 100 *10**8, 0, block.timestamp, false );
		check( 140*10**8, 10*10**8, 40*10**8, 220*10**8, 30*10**8, 80*10**8, 90*10**8, 30*10**8, 120*10**8 );
        rewards[0] = AddedReward({poolID: collateralPoolID, amountToAdd: 190*10**8});

        vm.prank(DEPLOYER);
        collateral.addSALTRewards(rewards);
        vm.warp( block.timestamp + 1 hours );
		check( 140*10**8, 10*10**8, 40*10**8, 360*10**8, 40*10**8, 120*10**8, 90*10**8, 30*10**8, 120*10**8 );

		// Charlie unstakes all
        vm.prank(charlie);
        collateral.withdrawCollateralAndClaim(40*10**8, 0, 0, block.timestamp);
		check( 140*10**8, 10*10**8, 0, 360*10**8, 40*10**8, 0, 90*10**8, 30*10**8, 240*10**8 );
        rewards[0] = AddedReward({poolID: collateralPoolID, amountToAdd: 75*10**8});

        vm.prank(DEPLOYER);
        collateral.addSALTRewards(rewards);
        vm.warp( block.timestamp + 1 hours );
		check( 140*10**8, 10*10**8, 0, 430*10**8, 45*10**8, 0, 90*10**8, 30*10**8, 240*10**8 );

		// Bob unstakes 5
        vm.prank(bob);
        collateral.withdrawCollateralAndClaim(2*10**8, 0, 0, block.timestamp);
		check( 140*10**8, 8*10**8, 0, 430*10**8, 36*10**8, 0, 90*10**8, 39*10**8, 240*10**8 );
        rewards[0] = AddedReward({poolID: collateralPoolID, amountToAdd: 74*10**8});

        vm.prank(DEPLOYER);
        collateral.addSALTRewards(rewards);
        vm.warp( block.timestamp + 1 hours );
		check( 140*10**8, 8*10**8, 0, 500*10**8, 40*10**8, 0, 90*10**8, 39*10**8, 240*10**8 );

		// Bob adds 148
        vm.prank(bob);
		collateral.depositCollateralAndIncreaseShare(148 *10**8, 148 *10**8, 0, block.timestamp, false );
		check( 140*10**8, 156*10**8, 0, 500*10**8, 40*10**8, 0, 90*10**8, 39*10**8, 240*10**8 );
        rewards[0] = AddedReward({poolID: collateralPoolID, amountToAdd: 592*10**8});

        vm.prank(DEPLOYER);
        collateral.addSALTRewards(rewards);
        vm.warp( block.timestamp + 1 hours );
		check( 140*10**8, 156*10**8, 0, 780*10**8, 352*10**8, 0, 90*10**8, 39*10**8, 240*10**8 );
	}


	// A unit test that tests maxRewardValueForCallingLiquidation
	function testMaxRewardValueForCallingLiquidation() public {
		vm.startPrank(alice);
		collateral.depositCollateralAndIncreaseShare(( 100000 ether *10**8) / priceAggregator.getPriceBTC(), ( 100000 ether *10**18) / priceAggregator.getPriceETH() , 0, block.timestamp, false );

		uint256 maxUSDS = collateral.maxBorrowableUSDS(alice);
		collateral.borrowUSDS( maxUSDS );
		vm.stopPrank();

        uint256 aliceCollateralShare = collateral.userShareForPool( alice, collateralPoolID );
        uint256 aliceCollateralValue = collateral.collateralValueInUSD( aliceCollateralShare );

        uint256 aliceBorrowedUSDS = usds.balanceOf(alice);
        assertEq( collateral.usdsBorrowedByUsers(alice), aliceBorrowedUSDS, "Alice amount USDS borrowed not what she has" );

        // Artificially crash the collateral price
        _crashCollateralPrice();

        // Delay before the liquidation
        vm.warp( block.timestamp + 1 days );

		uint256 startingWETH = weth.balanceOf(address(this));

        // Liquidate Alice's position
        collateral.liquidateUser(alice);

        // Verify that Alice's position has been liquidated
        assertEq( collateral.userShareForPool(alice, collateralPoolID), 0 );
        assertEq( collateral.usdsBorrowedByUsers(alice), 0 );

        // Verify that caller has received WETH for the liquidation
        uint256 expectedRewardValue = aliceCollateralValue * stableConfig.rewardPercentForCallingLiquidation() / 100;
        uint256 maxRewardValue = stableConfig.maxRewardValueForCallingLiquidation();
        if ( expectedRewardValue > maxRewardValue )
            expectedRewardValue = maxRewardValue;

		uint256 wethReward = weth.balanceOf(address(this)) - startingWETH;

        assertTrue( collateral.underlyingTokenValueInUSD(0, wethReward ) < expectedRewardValue + expectedRewardValue * 5 / 1000 , "Should have received WETH for liquidating Alice");
        assertTrue( collateral.underlyingTokenValueInUSD(0, wethReward ) > expectedRewardValue - expectedRewardValue * 5 / 1000 , "Should have received WETH for liquidating Alice");
    }


	// A unit test that tests rewardPercentForCallingLiquidation
	function testRewardValueForCallingLiquidation() public {
		vm.startPrank(alice);

		uint256 depositedWBTC = ( 1500 ether *10**8) / priceAggregator.getPriceBTC();
		uint256 depositedWETH = ( 1500 ether *10**18) / priceAggregator.getPriceETH();

		collateral.depositCollateralAndIncreaseShare( depositedWBTC, depositedWETH , 0, block.timestamp, false );

		uint256 maxUSDS = collateral.maxBorrowableUSDS(alice);
		collateral.borrowUSDS( maxUSDS );
		vm.stopPrank();

        uint256 aliceCollateralShare = collateral.userShareForPool( alice, collateralPoolID );
        uint256 aliceCollateralValue = collateral.collateralValueInUSD( aliceCollateralShare );

        uint256 aliceBorrowedUSDS = usds.balanceOf(alice);
        assertEq( collateral.usdsBorrowedByUsers(alice), aliceBorrowedUSDS, "Alice amount USDS borrowed not what she has" );

        // Artificially crash the collateral price
        _crashCollateralPrice();

        aliceCollateralValue = collateral.collateralValueInUSD( aliceCollateralShare );

        // Delay before the liquidation
        vm.warp( block.timestamp + 1 days );

		uint256 startingWETH = weth.balanceOf(address(this));

        // Liquidate Alice's position
        collateral.liquidateUser(alice);

        // Verify that Alice's position has been liquidated
        assertEq( collateral.userShareForPool(alice, collateralPoolID), 0 );
        assertEq( collateral.usdsBorrowedByUsers(alice), 0 );

        // Verify that caller has received WETH for the liquidation
        uint256 expectedRewardValue = aliceCollateralValue * stableConfig.rewardPercentForCallingLiquidation() / 100;

		uint256 wethReward = weth.balanceOf(address(this)) - startingWETH;

        assertTrue( collateral.underlyingTokenValueInUSD(0, wethReward ) < expectedRewardValue + expectedRewardValue * 5 / 1000 , "Should have received WETH for liquidating Alice");
        assertTrue( collateral.underlyingTokenValueInUSD(0, wethReward ) > expectedRewardValue - expectedRewardValue * 5 / 1000 , "Should have received WETH for liquidating Alice");
    }


	// A unit test to test minimumCollateralValueForBorrowing
	function testMinimumCollateralValueForBorrowing() public {
		vm.startPrank(alice);
		collateral.depositCollateralAndIncreaseShare(( 1000 ether *10**8) / priceAggregator.getPriceBTC(), ( 1000 ether *10**18) / priceAggregator.getPriceETH() , 0, block.timestamp, false );

		uint256 maxUSDS = collateral.maxBorrowableUSDS(alice);
		assertEq( maxUSDS, 0, "Should not be able to borrow USDS with only $2000 worth of collateral" );

		vm.expectRevert( "Excessive amountBorrowed" );
		collateral.borrowUSDS( 1 );

		vm.warp( block.timestamp + 1 hours );
		collateral.depositCollateralAndIncreaseShare(( 1000 ether *10**8) / priceAggregator.getPriceBTC(), ( 1000 ether *10**18) / priceAggregator.getPriceETH() , 0, block.timestamp, false );

		maxUSDS = collateral.maxBorrowableUSDS(alice);
        uint256 expectedMaxUSDS = 2000 ether;

        assertTrue( maxUSDS < expectedMaxUSDS + expectedMaxUSDS * 5 / 1000 , "Incorrect expectedMaxUSDS" );
        assertTrue( maxUSDS > expectedMaxUSDS - expectedMaxUSDS * 5 / 1000 , "Incorrect expectedMaxUSDS" );

		collateral.borrowUSDS( expectedMaxUSDS * 999 / 1000 );

		assertEq( usds.balanceOf(alice), expectedMaxUSDS * 999 / 1000, "Incorrect USDS balance for alice" );
        }


	// A user test to check that no liquidation is possible if the PriceFeed isn't returning a valid price
	function testUserLiquidationWithTwoFailedPriceFeeds() public {
        // Deposit and borrow for Alice
        _depositHalfCollateralAndBorrowMax(alice);

        // Check if Alice has a position
        assertTrue(_userHasCollateral(alice));

        // Crash the collateral price
        _crashCollateralPrice();
        vm.warp( block.timestamp + 1 days );

		IForcedPriceFeed forcedPriceFeed = new ForcedPriceFeed(0, 0 );

		vm.startPrank(address(dao));
		priceAggregator.setPriceFeed(1, IPriceFeed(address(forcedPriceFeed)));
		vm.warp( block.timestamp + 60 days);
		priceAggregator.setPriceFeed(2, IPriceFeed(address(forcedPriceFeed)));

		// Shouldn't return an error, but should actually set the price feed
		priceAggregator.setPriceFeed(2, IPriceFeed(address(0x123)));
		assertEq( address(priceAggregator.priceFeed2()), address(forcedPriceFeed), "Price feed should not have been set" );

		vm.stopPrank();

		priceAggregator.performUpkeep();

        // Liquidate Alice's position
        vm.expectRevert( "Invalid WBTC price" );
        collateral.liquidateUser(alice);

        assertFalse( collateral.userShareForPool(alice, collateralPoolID) == 0 );
    }



	// A user test to check that no liquidation is possible if the PriceFeed isn't returning a valid price
	function testUserLiquidationWithDivergentPrices() public {
        // Deposit and borrow for Alice
        _depositHalfCollateralAndBorrowMax(alice);

        // Check if Alice has a position
        assertTrue(_userHasCollateral(alice));

        // Crash the collateral price
        _crashCollateralPrice();
        vm.warp( block.timestamp + 1 days );

		IForcedPriceFeed forcedPriceFeed1 = new ForcedPriceFeed(0, 0 );
		IForcedPriceFeed forcedPriceFeed2 = new ForcedPriceFeed(30000, 3000 );
		IForcedPriceFeed forcedPriceFeed3 = new ForcedPriceFeed(33000, 3300 );

		vm.startPrank(address(dao));
		priceAggregator.setPriceFeed(1, IPriceFeed(address(forcedPriceFeed1)));
		vm.warp( block.timestamp + 60 days);
		priceAggregator.setPriceFeed(2, IPriceFeed(address(forcedPriceFeed2)));
		vm.warp( block.timestamp + 60 days);
		priceAggregator.setPriceFeed(3, IPriceFeed(address(forcedPriceFeed3)));
		vm.stopPrank();

		priceAggregator.performUpkeep();

        // Liquidate Alice's position
        vm.expectRevert( "Invalid WBTC price" );
        collateral.liquidateUser(alice);

        assertFalse( collateral.userShareForPool(alice, collateralPoolID) == 0 );
    }


	// A user test to check that liquidation is possible if the PriceFeed is returning two similar prices and one failure
	function testUserLiquidationWithTwoGoodFeeds() public {
        // Deposit and borrow for Alice
        _depositHalfCollateralAndBorrowMax(alice);

        // Check if Alice has a position
        assertTrue(_userHasCollateral(alice));

        // Crash the collateral price
        _crashCollateralPrice();
        vm.warp( block.timestamp + 1 days );

		// Makimum error for a valid PriceAggregator price is 3%
		IForcedPriceFeed forcedPriceFeed1 = new ForcedPriceFeed(0, 0 );
		IForcedPriceFeed forcedPriceFeed2 = new ForcedPriceFeed(30000, 3000 );
		IForcedPriceFeed forcedPriceFeed3 = new ForcedPriceFeed(30899, 3089 );

		vm.startPrank(address(dao));
		priceAggregator.setPriceFeed(1, IPriceFeed(address(forcedPriceFeed1)));
		vm.warp( block.timestamp + 60 days);
		priceAggregator.setPriceFeed(2, IPriceFeed(address(forcedPriceFeed2)));
		vm.warp( block.timestamp + 60 days);
		priceAggregator.setPriceFeed(3, IPriceFeed(address(forcedPriceFeed3)));
		vm.stopPrank();

		priceAggregator.performUpkeep();

        // Liquidate Alice's position
        collateral.liquidateUser(alice);

        assertTrue( collateral.userShareForPool(alice, collateralPoolID) == 0 );
    }


	// A user test to check that no borrowing is possible if the PriceFeed is returning an invalid price
	function testUserBorrowingWithBadPriceFeed() public {

		IForcedPriceFeed forcedPriceFeed = new ForcedPriceFeed(0, 0 );

		vm.startPrank(address(dao));
		priceAggregator.setPriceFeed(1, IPriceFeed(address(forcedPriceFeed)));
		vm.warp( block.timestamp + 60 days);
		priceAggregator.setPriceFeed(2, IPriceFeed(address(forcedPriceFeed)));
		vm.stopPrank();

		priceAggregator.performUpkeep();


        // Deposit and borrow for Alice
		vm.startPrank( alice );
		collateral.depositCollateralAndIncreaseShare(wbtc.balanceOf(alice) / 2, weth.balanceOf(alice) / 2, 0, block.timestamp, false );

        vm.expectRevert( "Invalid WBTC price" );
		uint256 maxUSDS = collateral.maxBorrowableUSDS(alice);

        vm.expectRevert( "Invalid WBTC price" );
		collateral.borrowUSDS( maxUSDS );
		vm.stopPrank();
        }


	// A unit test to verify the case scenario where a user tries to deposit zero collateral amount in the depositCollateralAndIncreaseShare function.
	function testDepositZeroCollateral() public {
        // Alice attempts to deposit zero collateral which should not be allowed.
        vm.prank(alice);
        vm.expectRevert("The amount of tokenA to add is too small");
        collateral.depositCollateralAndIncreaseShare(0, 0, 0, block.timestamp, false);
    }


	// A unit test that validates the behaviour of borrowUSDS function when the user has not yet deposited any collateral.
	// A unit test that validates the borrowUSDS function behavior when a user has not deposited any collateral.
    function testBorrowUSDSWithoutCollateral() public {

    	address userX = address(0xDEAD);

        assertEq(wbtc.balanceOf(userX), 0, "userX should start with zero WBTC");
        assertEq(weth.balanceOf(userX), 0, "userX should start with zero WETH");
        assertEq(usds.balanceOf(userX), 0, "userX should start with zero USDS");

        // Alice tries to borrow USDS without having deposited any collateral
        vm.startPrank(userX);
        vm.expectRevert("User does not have any collateral");
        collateral.borrowUSDS(1 ether);
        vm.stopPrank();

        // Verify Alice's collateral and USDS balance remain unchanged
        assertEq(_userHasCollateral(userX), false, "userX should have no collateral");
        assertEq(usds.balanceOf(userX), 0, "userX should have zero USDS");
    }


	// A unit test to verify that the canUserBeLiquidated function returns false when the borrowed amount is less than the collateral ratio threshold.
	function testCanUserBeLiquidatedUnderThreshold() public {
        // Verify that Alice can't be liquidated yet (collateral ratio is 200%)
        assertFalse(collateral.canUserBeLiquidated(alice));

//        _depositCollateralAndBorrowMax(alice);
//
//        // Verify that Alice can't be liquidated yet (collateral ratio is 200%)
//        assertFalse(collateral.canUserBeLiquidated(alice));

//        // Alice repays half of her borrowed USDS
//        uint256 bobBorrowedUSDS = collateral.usdsBorrowedByUsers(alice);
//        vm.prank(alice);
//        collateral.repayUSDS(bobBorrowedUSDS / 2);
//        vm.stopPrank();
//
//        // Verify that Alice can't be liquidated (collateral ratio is now 400%)
//        assertFalse(collateral.canUserBeLiquidated(alice));
    }


    // A unit test to ensure the correct working of the usds.shouldBurnMoreUSDS function for various inputs.
    // A unit test for totalSharesForPool function, ensuring it returns zero when the total collateral amount becomes zero.
    // A unit test to validate the maxBorrowableUSDS function for multiple users with different levels of collateral values notably those above, at, and below the minimumCollateralValueForBorrowing.
    // A unit test validating the behavior of liquidateUser function in the scenario where the user is just above the liquidation threshold.
  	// A unit test for accuracy of maxWithdrawableCollateral function for scenarios where all borrowed USDS have been repaid.
	// A unit test that validates the _walletsWithBorrowedUSDS set does not add duplicate wallets, even when multiple borrowUSDS operations are executed from the same user
	// A unit test that verifies the accurate calculation, behavior, and exception handling for cases with various amounts of borrowed USDS in the repayUSDS function.
	// A unit test to verify the behavior of collateralValueInUSD function when the user does not have any collateral in the collateral pool.
    // A unit test which verifies that the liquidateUser function correctly updates the number of users with borrowed USDS.
    // A unit test that checks accurate exception handling for invalid inputs to the constructor.
    // A unit test that validates wbtc and weth balances in the contract should be zero when there are no depositors or borrowers
	// A unit test to validate userCollateralValueInUSD for wallets which have not deposited any collateral.
    // A unit test that ensures collateralValueInUSD returns zero when the provided collateralAmount value is zero.
    // A unit test to validate behaviors of liquidateUser function when the wallet to be liquidated has no borrowed USDS.
    // A unit test that checks after every successful liquidity withdrawal the totalSharesForPool function returns updated share
    // A unit test that checks if repayUSDS function correctly reverts when the amount to repay is more than the borrowed amount
    // A unit test to check if borrowUSDS function throws error when called by a wallet which doesn't have exchange access.
    // A unit test to check if depositCollateralAndIncreaseShare function throws error when called by a wallet which doesn't have exchange access.
	// A unit test which verifies the behavior of userShareForPool function for wallets without any collateral share in the pool.
	// A unit test that validates the behavior of underlyingTokenValueInUSD function with a range of token prices.
    // A unit test that validates the behavior of _increaseUserShare function with a range of addedLiquidity values.
    // A unit test that verifies the userShareForPool for accounts with multiple collateral positions.
    // A unit test that checks the borrower's position before and after the liquidity is added and verifies the increase in shares after the addition of liquidity.
    // A unit test that checks the borrower's position before and after the liquidity is removed and verifies the decrease in shares after the removal of liquidity.


}
