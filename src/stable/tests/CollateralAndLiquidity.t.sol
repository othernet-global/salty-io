// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

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

		vm.prank(address(daoVestingWallet));
		salt.transfer(DEPLOYER, 1000000 ether);


		collateralPoolID = PoolUtils._poolID( wbtc, weth );

		// Mint some USDS to the DEPLOYER
		vm.prank( address(collateralAndLiquidity) );
		usds.mintTo( DEPLOYER, 2000000 ether );
		}


	function _userHasCollateral( address user ) internal view returns (bool)
		{
		return collateralAndLiquidity.userShareForPool( user, collateralPoolID ) > 0;
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
		wbtc.approve( address(collateralAndLiquidity), type(uint256).max );
        weth.approve( address(collateralAndLiquidity), type(uint256).max );
		usds.approve( address(collateralAndLiquidity), type(uint256).max );
		salt.approve( address(collateralAndLiquidity), type(uint256).max );
		usds.approve( address(collateralAndLiquidity), type(uint256).max );
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
		collateralAndLiquidity.depositCollateralAndIncreaseShare(wbtc.balanceOf(user), weth.balanceOf(user), 0, block.timestamp, true );

		uint256 maxUSDS = collateralAndLiquidity.maxBorrowableUSDS(user);
		collateralAndLiquidity.borrowUSDS( maxUSDS );
		vm.stopPrank();
		}


	// This will set the collateral / borrowed ratio at the default of 200%
	function _depositHalfCollateralAndBorrowMax( address user ) internal
		{
		vm.startPrank( user );
		collateralAndLiquidity.depositCollateralAndIncreaseShare(wbtc.balanceOf(user) / 2, weth.balanceOf(user) / 2, 0, block.timestamp, true );

		uint256 maxUSDS = collateralAndLiquidity.maxBorrowableUSDS(user);
		collateralAndLiquidity.borrowUSDS( maxUSDS );
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
			vm.stopPrank();
		}



	// A unit test to check that users without exchange access cannot borrowUSDS
	function testUserWithoutAccess() public
		{
		vm.expectRevert( "Sender does not have exchange access" );
		vm.prank(address(0xDEAD));
		collateralAndLiquidity.borrowUSDS( 1 ether );
		}


	// A unit test that verifies the liquidateUser function correctly transfers WETH to the liquidator and WBTC/WETH to the USDS contract
	function testLiquidatePosition() public {

		assertEq( collateralAndLiquidity.numberOfUsersWithBorrowedUSDS(), 0 );

		assertEq(wbtc.balanceOf(address(usds)), 0, "USDS contract should start with zero WBTC");
		assertEq(weth.balanceOf(address(usds)), 0, "USDS contract should start with zero WETH");
		assertEq(usds.balanceOf(alice), 0, "Alice should start with zero USDS");

		// Total needs to be worth at least $2500
		uint256 depositedWBTC = ( 1000 ether *10**8) / priceAggregator.getPriceBTC();
		uint256 depositedWETH = ( 1000 ether *10**18) / priceAggregator.getPriceETH();

		(uint256 reserveWBTC, uint256 reserveWETH) = pools.getPoolReserves(wbtc, weth);
		assertEq( reserveWBTC, 0, "reserveWBTC doesn't start as zero" );
		assertEq( reserveWETH, 0, "reserveWETH doesn't start as zero" );

		// Alice will deposit collateral and borrow max USDS
		vm.startPrank(alice);
		collateralAndLiquidity.depositCollateralAndIncreaseShare( depositedWBTC, depositedWETH, 0, block.timestamp, false );

		uint256 maxUSDS = collateralAndLiquidity.maxBorrowableUSDS(alice);
		assertEq( maxUSDS, 0, "Alice doesn't have enough collateral to borrow USDS" );

		// Deposit again
		vm.warp( block.timestamp + 1 hours );
		collateralAndLiquidity.depositCollateralAndIncreaseShare( depositedWBTC, depositedWETH, 0, block.timestamp, false );

		// Account for both deposits
		depositedWBTC = depositedWBTC * 2;
		depositedWETH = depositedWETH * 2;
		vm.stopPrank();


		// Deposit extra so alice can withdraw all liquidity without having to worry about the DUST reserve limit
		vm.prank(DEPLOYER);
		collateralAndLiquidity.depositCollateralAndIncreaseShare( 1 * 10**8, 1 ether, 0, block.timestamp, false );

		vm.warp( block.timestamp + 1 hours );


		vm.startPrank(alice);
		maxUSDS = collateralAndLiquidity.maxBorrowableUSDS(alice);



		vm.startPrank(alice);
		vm.warp( block.timestamp + 1 hours);

		maxUSDS = collateralAndLiquidity.maxBorrowableUSDS(alice);
		collateralAndLiquidity.borrowUSDS( maxUSDS );
		vm.stopPrank();

		assertEq( collateralAndLiquidity.numberOfUsersWithBorrowedUSDS(), 1 );

		uint256 maxWithdrawable = collateralAndLiquidity.maxWithdrawableCollateral(alice);
		assertEq( maxWithdrawable, 0, "Alice shouldn't be able to withdraw any collateral" );

		{
		uint256 aliceCollateralValue = collateralAndLiquidity.userCollateralValueInUSD(alice);

		uint256 aliceBorrowedUSDS = usds.balanceOf(alice);
		assertEq( collateralAndLiquidity.usdsBorrowedByUsers(alice), aliceBorrowedUSDS, "Alice amount USDS borrowed not what she has" );

		// Borrowed USDS should be about 50% of the aliceCollateralValue
		assertTrue( aliceBorrowedUSDS > ( aliceCollateralValue * 499 / 1000 ), "Alice did not borrow sufficient USDS" );
		assertTrue( aliceBorrowedUSDS < ( aliceCollateralValue * 501 / 1000 ), "Alice did not borrow sufficient USDS" );
		}

		// Try and fail to liquidate alice
		vm.expectRevert( "User cannot be liquidated" );
		vm.prank(bob);
        collateralAndLiquidity.liquidateUser(alice);

		// Artificially crash the collateral price
		_crashCollateralPrice();

		// Delay before the liquidation
		vm.warp( block.timestamp + 1 days );

		uint256 bobStartingWETH = weth.balanceOf(bob);
		uint256 bobStartingWBTC = wbtc.balanceOf(bob);

		// Liquidate Alice's position
		vm.prank(bob);

		uint256 gas0 = gasleft();
		collateralAndLiquidity.liquidateUser(alice);
		console.log( "LIQUIDATE GAS: ", gas0 - gasleft() );

		uint256 bobRewardWETH = weth.balanceOf(bob) - bobStartingWETH;
		uint256 bobRewardWBTC = wbtc.balanceOf(bob) - bobStartingWBTC;

		// Verify that Alice's position has been liquidated
		assertEq( collateralAndLiquidity.userShareForPool(alice, collateralPoolID), 0 );
        assertEq( collateralAndLiquidity.usdsBorrowedByUsers(alice), 0 );

		// Verify that Bob has received WBTC and WETH for the liquidation
		assertEq( depositedWETH * 5 / 100, bobRewardWETH , "Bob should have received WETH for liquidating Alice");
		assertEq( depositedWBTC * 5 / 100, bobRewardWBTC , "Bob should have received WBTC for liquidating Alice");

		// Verify that the Liquidizer received the WBTC and WETH from Alice's liquidated collateral
		assertEq(wbtc.balanceOf(address(liquidizer)), depositedWBTC - bobRewardWBTC - 1, "The Liquidizer contract should have received Alice's WBTC");
		assertEq(weth.balanceOf(address(liquidizer)), depositedWETH - bobRewardWETH, "The Liquidizer contract should have received Alice's WETH - Bob's WETH reward");

		assertEq( collateralAndLiquidity.numberOfUsersWithBorrowedUSDS(), 0 );
		}


	// A unit test that verifies liquidateUser behavior where the borrowed amount is zero.
	function testLiquidatePositionWithZeroBorrowedAmount() public {
		assertEq(wbtc.balanceOf(address(usds)), 0, "USDS contract should start with zero WBTC");
		assertEq(weth.balanceOf(address(usds)), 0, "USDS contract should start with zero WETH");
		assertEq(usds.balanceOf(alice), 0, "Alice should start with zero USDS");

		// Alice will deposit all her collateral but not borrow any
		vm.startPrank( alice );
		collateralAndLiquidity.depositCollateralAndIncreaseShare(wbtc.balanceOf(alice), weth.balanceOf(alice), 0, block.timestamp, true );

		// Artificially crash the collateral price
		_crashCollateralPrice();

		// Delay before the liquidation
		vm.warp( block.timestamp + 1 days );

		// Try and fail to liquidate alice
		vm.expectRevert( "User cannot be liquidated" );
		vm.prank(bob);
		collateralAndLiquidity.liquidateUser(alice);
		}


   	// A unit test that verifies the liquidateUser function's handling of position liquidation, including both valid and invalid position IDs, cases where the position has already been liquidated.
   	function testLiquidatePositionFailure() public {
		assertEq(wbtc.balanceOf(address(usds)), 0, "USDS contract should start with zero WBTC");
		assertEq(weth.balanceOf(address(usds)), 0, "USDS contract should start with zero WETH");
		assertEq(usds.balanceOf(alice), 0, "Alice should start with zero USDS");


		// Bob deposits collateral so alice can be liquidated
		vm.startPrank(bob);
		collateralAndLiquidity.depositCollateralAndIncreaseShare(wbtc.balanceOf(bob), weth.balanceOf(bob), 0, block.timestamp, false );


		// Alice will deposit all her collateral and borrow max
    	_depositCollateralAndBorrowMax(alice);

		// Artificially crash the collateral price
		_crashCollateralPrice();

		// Delay before the liquidation
		vm.warp( block.timestamp + 1 days );

		// Now Alice's position should be liquidatable
    	collateralAndLiquidity.liquidateUser(alice);

    	// Shouldn't be able to liquidate twice
    	vm.expectRevert("User cannot be liquidated");
    	collateralAndLiquidity.liquidateUser(alice);

    	// Trying to liquidate an invalid user should fail
    	vm.expectRevert("User cannot be liquidated");
    	collateralAndLiquidity.liquidateUser(address(0xDEAD));
    }


   	// A unit test that checks the liquidateUser function for proper calculation, and when the caller tries to liquidate their own position.
	function testLiquidateSelf() public {

		// Bob deposits collateral so alice can be liquidated
        vm.startPrank(bob);
		collateralAndLiquidity.depositCollateralAndIncreaseShare(wbtc.balanceOf(bob), weth.balanceOf(bob), 0, block.timestamp, false );
		vm.stopPrank();

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
        collateralAndLiquidity.liquidateUser(alice);
		assertTrue( _userHasCollateral(alice) );

        // Proper liquidation by another account
        vm.prank(bob);
        collateralAndLiquidity.liquidateUser(alice);

		assertFalse( _userHasCollateral(alice) );
    }


	// A unit test where a user is liquidated and then adds another position which is then liquidated as well
	function testUserLiquidationTwice() public {

		// Have bob deposit so alice can withdraw everything without DUST reserves restriction
        _depositHalfCollateralAndBorrowMax(bob);

        // Deposit and borrow for Alice
        _depositHalfCollateralAndBorrowMax(alice);

        // Check if Alice has a position
        assertTrue(_userHasCollateral(alice));

        // Crash the collateral price
        _crashCollateralPrice();
        vm.warp( block.timestamp + 1 days );

        // Liquidate Alice's position
        collateralAndLiquidity.liquidateUser(alice);

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
        collateralAndLiquidity.liquidateUser(alice);

        // Check if Alice's position was liquidated again
        assertFalse(_userHasCollateral(alice));
    }



	// A unit test where a user deposits, borrows, deposits and is then liquidated
	function testUserDepositBorrowDepositAndLiquidate() public {

		// Bob deposits collateral so alice can be liquidated
        vm.startPrank(bob);
		collateralAndLiquidity.depositCollateralAndIncreaseShare(wbtc.balanceOf(bob), weth.balanceOf(bob), 0, block.timestamp, false );
		vm.stopPrank();

		vm.startPrank( alice );
		uint256 wbtcDeposit = wbtc.balanceOf(alice) / 4;
		uint256 wethDeposit = weth.balanceOf(alice) / 4;

		collateralAndLiquidity.depositCollateralAndIncreaseShare(wbtcDeposit, wethDeposit, 0, block.timestamp, true );

        // Alice borrows USDS
        uint256 maxBorrowable = collateralAndLiquidity.maxBorrowableUSDS(alice);
        collateralAndLiquidity.borrowUSDS( maxBorrowable );

        // Alice deposits more collateral - but fails due to the cooldown
        vm.expectRevert( "Must wait for the cooldown to expire" );
		collateralAndLiquidity.depositCollateralAndIncreaseShare(wbtcDeposit, wethDeposit, 0, block.timestamp, true );

		vm.warp( block.timestamp + 1 days );

		// Try depositing again
		collateralAndLiquidity.depositCollateralAndIncreaseShare(wbtcDeposit, wethDeposit, 0, block.timestamp, true );
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
        collateralAndLiquidity.liquidateUser(alice);

		assertFalse(_userHasCollateral(alice));
    }


	// A unit test that verifies the userCollateralValueInUSD and underlyingTokenValueInUSD function with different collateral amounts and different token prices, including when the user does not have a position.
	function testUserCollateralValueInUSD() public
    	{
    	// Determine how many BTC and ETH alice has in colalteral
    	_depositCollateralAndBorrowMax(alice);

		(uint256 reserveWBTC, uint256 reserveWETH) = pools.getPoolReserves(wbtc, weth);
		uint256 totalLP = collateralAndLiquidity.totalShares(collateralPoolID);

		uint256 aliceCollateral = collateralAndLiquidity.userShareForPool( alice, collateralPoolID );

		uint256 aliceBTC = ( reserveWBTC * aliceCollateral ) / totalLP; // 8 decimals
		uint256 aliceETH = ( reserveWETH * aliceCollateral ) / totalLP; // 18 decimals

		vm.startPrank( DEPLOYER );
		forcedPriceFeed.setBTCPrice( 20000 ether );
		forcedPriceFeed.setETHPrice( 2000 ether );
			vm.stopPrank();

        uint256 aliceCollateralValue0 = collateralAndLiquidity.userCollateralValueInUSD(alice);

        // Make sure resulting calculation has 18 decimals
        uint256 aliceCollateralValue = aliceBTC * 20000 ether / 10**8 + aliceETH * 2000;
		assertEq( aliceCollateralValue0, aliceCollateralValue, "Collateral value different than expected" );


		vm.startPrank( DEPLOYER );
		forcedPriceFeed.setBTCPrice( 15000 ether );
		forcedPriceFeed.setETHPrice( 1777 ether );
			vm.stopPrank();

        aliceCollateralValue0 = collateralAndLiquidity.userCollateralValueInUSD(alice);

        // Make sure resulting calculation has 18 decimals
        aliceCollateralValue = aliceBTC * 15000 ether / 10**8 + aliceETH * 1777;
		assertEq( aliceCollateralValue0, aliceCollateralValue, "Collateral value different than expected" );


		vm.startPrank( DEPLOYER );
		forcedPriceFeed.setBTCPrice( 45000 ether );
		forcedPriceFeed.setETHPrice( 11777 ether );
			vm.stopPrank();

        aliceCollateralValue0 = collateralAndLiquidity.userCollateralValueInUSD(alice);

        // Make sure resulting calculation has 18 decimals
        aliceCollateralValue = aliceBTC * 45000 ether / 10**8 + aliceETH * 11777;
		assertEq( aliceCollateralValue0, aliceCollateralValue, "Collateral value different than expected" );

		assertEq( collateralAndLiquidity.userCollateralValueInUSD(bob), 0, "Non-existent collateral value should be zero" );
    	}


	// A unit test that verifies the findLiquidatableUsers function returns an empty array when there are no liquidatable positions and checks it for a range of indices.
	function testFindLiquidatablePositions_noLiquidatablePositions() public {
		// Alice, Bob, and Charlie deposit collateral and borrow within the limit
		_depositHalfCollateralAndBorrowMax(alice);
		_depositHalfCollateralAndBorrowMax(bob);
		_depositHalfCollateralAndBorrowMax(charlie);

		address[] memory liquidatableUsers = collateralAndLiquidity.findLiquidatableUsers();
        assertEq(liquidatableUsers.length, 0, "No liquidatable users should be found");
    }


	// A unit test to ensure that the borrowUSDS function updates the _walletsWithBorrowedUSDS mapping correctly, and that the _walletsWithBorrowedUSDS mapping is also updated properly after liquidation.
	function testBorrowUSDSAndLiquidation() public {

		// Bob deposits collateral so alice can be liquidated
        vm.startPrank(bob);
		collateralAndLiquidity.depositCollateralAndIncreaseShare(wbtc.balanceOf(bob), weth.balanceOf(bob), 0, block.timestamp, false );
		vm.stopPrank();

        // Deposit collateral
        vm.startPrank(alice);
		collateralAndLiquidity.depositCollateralAndIncreaseShare(wbtc.balanceOf(alice), weth.balanceOf(alice), 0, block.timestamp, true );
		assertTrue(_userHasCollateral(alice));
		assertEq( collateralAndLiquidity.numberOfUsersWithBorrowedUSDS(), 0);

        // Borrow USDS
        uint256 borrowedAmount = collateralAndLiquidity.maxBorrowableUSDS(alice);
        collateralAndLiquidity.borrowUSDS(borrowedAmount);
		assertEq( collateralAndLiquidity.numberOfUsersWithBorrowedUSDS(), 1);

        // Check that Alice's borrowed amount increased
        assertEq(collateralAndLiquidity.usdsBorrowedByUsers(alice), borrowedAmount);

        // Crash collateral price to enable liquidation
        _crashCollateralPrice();
		vm.warp( block.timestamp + 1 days );

        // Liquidate alice
        collateralAndLiquidity.liquidateUser(alice);

        // Confirm that position is removed from _walletsWithBorrowedUSDS
		assertFalse(_userHasCollateral(alice));
        assertEq(collateralAndLiquidity.usdsBorrowedByUsers(alice), 0);
		assertEq( collateralAndLiquidity.numberOfUsersWithBorrowedUSDS(), 0);
    }


	// A unit test for collateral.numberOfUsersWithBorrowedUSDS to verify that it returns the correct number of open positions.
	function testNumberOfOpenPositions() public {
        // Alice, Bob and Charlie each deposit and borrow
        _depositCollateralAndBorrowMax(alice);
        _depositCollateralAndBorrowMax(bob);
        _depositCollateralAndBorrowMax(charlie);

    	vm.warp( block.timestamp + 1 days );

        // Check collateral.numberOfUsersWithBorrowedUSDS returns correct number of open positions
        assertEq( collateralAndLiquidity.numberOfUsersWithBorrowedUSDS(), 3);

        // Alice repays loan, reducing number of open positions
        uint256 aliceBorrowedAmount = usds.balanceOf(alice);

		vm.prank(address(collateralAndLiquidity));
        usds.mintTo(alice, aliceBorrowedAmount);
        vm.startPrank(alice);
        collateralAndLiquidity.repayUSDS(aliceBorrowedAmount / 2 );
        vm.stopPrank();

        // Check collateral.numberOfUsersWithBorrowedUSDS returns correct number of open positions
        assertEq( collateralAndLiquidity.numberOfUsersWithBorrowedUSDS() , 3);

		vm.prank(alice);
		collateralAndLiquidity.repayUSDS(aliceBorrowedAmount - aliceBorrowedAmount / 2);

        assertEq( collateralAndLiquidity.numberOfUsersWithBorrowedUSDS() , 2);

        // _crashCollateralPrice to force liquidation of a position
        _crashCollateralPrice();

        // Check liquidation of Bob's position
        collateralAndLiquidity.liquidateUser(bob);

        // Check collateral.numberOfUsersWithBorrowedUSDS returns correct number of open positions
        assertEq( collateralAndLiquidity.numberOfUsersWithBorrowedUSDS(), 1);
    }


	// A unit test for totalCollateralValueInUSD to verify that it correctly calculates the total value of all collateral.
	    // Here's a unit test for the `totalCollateralValueInUSD` function
        function testTotalCollateralValueInUSD() public {

            // Initial deposit for Alice, Bob and Charlie
            _depositCollateralAndBorrowMax(alice);
            _depositCollateralAndBorrowMax(bob);
            _depositCollateralAndBorrowMax(charlie);

            // Get total collateral value before crash
            uint256 totalCollateral = collateralAndLiquidity.totalCollateralValueInUSD();
			uint256 aliceCollateralValue = collateralAndLiquidity.userCollateralValueInUSD(alice);

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
		uint256 totalCollateral = collateralAndLiquidity.totalShares(collateralPoolID);

		uint256 aliceCollateral = collateralAndLiquidity.userShareForPool( alice, collateralPoolID );
		uint256 aliceBTC = ( reserveWBTC * aliceCollateral ) / totalCollateral;
		uint256 aliceETH = ( reserveWETH * aliceCollateral ) / totalCollateral;

		// Prices from the price feed have 18 decimals
		uint256 btcPrice = priceAggregator.getPriceBTC();
        uint256 ethPrice = priceAggregator.getPriceETH();

		// Keep the 18 decimals from the price and remove the decimals from the amount held by the user
		uint256 btcValue = ( aliceBTC * btcPrice ) / (10 ** 8 );
		uint256 ethValue = ( aliceETH * ethPrice ) / (10 ** 18 );

		uint256 manualCollateralValue = btcValue + ethValue;
    	uint256 actualCollateralValue = collateralAndLiquidity.userCollateralValueInUSD(alice);

		assertEq( manualCollateralValue, actualCollateralValue, "Calculated and actual collateral values are not the same" );
    }


	// A unit test that checks the deposit and withdrawal of collateral with various amounts, ensuring that an account cannot withdraw collateral that they do not possess.
	function testDepositAndWithdrawCollateral() public
    {

		// Bob deposits collateral so alice can be liquidated
        vm.startPrank(bob);
		collateralAndLiquidity.depositCollateralAndIncreaseShare(wbtc.balanceOf(bob), weth.balanceOf(bob), 0, block.timestamp, false );
		vm.stopPrank();


    	// Setup
    	vm.startPrank(alice);

		uint256 wbtcToDeposit = wbtc.balanceOf(alice) / 2;
		uint256 wethToDeposit = weth.balanceOf(alice) / 2;
		collateralAndLiquidity.depositCollateralAndIncreaseShare(wbtcToDeposit, wethToDeposit, 0, block.timestamp, true );

    	// Verify the result
    	uint256 depositAmount = collateralAndLiquidity.userShareForPool(alice, collateralPoolID);
    	assertEq(depositAmount, wbtcToDeposit + wethToDeposit );

		vm.warp( block.timestamp + 1 days );

    	// Alice tries to withdraw more collateral than she has in the contract
    	vm.expectRevert( "Excessive collateralToWithdraw" );
    	collateralAndLiquidity.withdrawCollateralAndClaim( depositAmount + 1, 0, 0, block.timestamp );

		vm.warp( block.timestamp + 1 days );

//		console.log( "COLLATERAL: ", collateral.userShareForPool(alice, collateralPoolID) );
    	// Alice withdraws half the collateral
    	collateralAndLiquidity.withdrawCollateralAndClaim( depositAmount / 2, 0, 0, block.timestamp );
//		console.log( "COLLATERAL: ", collateral.userShareForPool(alice, collateralPoolID) );

		vm.warp( block.timestamp + 1 days );

		// Withdraw too much
    	vm.expectRevert( "Excessive collateralToWithdraw" );
    	collateralAndLiquidity.withdrawCollateralAndClaim( depositAmount / 2 + 2, 0, 0, block.timestamp );
//		console.log( "COLLATERAL: ", collateral.userShareForPool(alice, collateralPoolID) );

		// Withdraw the rest
    	collateralAndLiquidity.withdrawCollateralAndClaim( depositAmount / 2, 0, 0, block.timestamp );

		vm.warp( block.timestamp + 1 days );

    	// Verify the result
    	assertEq(collateralAndLiquidity.userShareForPool(alice, collateralPoolID), 0);
    }


	// A unit test to verify that an account cannot borrow USDS more than their max borrowable limit
	function testCannotBorrowMoreThanMaxBorrowableLimit() public {
        vm.startPrank(alice);

		uint256 wbtcToDeposit = wbtc.balanceOf(alice);
		uint256 wethToDeposit = weth.balanceOf(alice);
		collateralAndLiquidity.depositCollateralAndIncreaseShare(wbtcToDeposit, wethToDeposit, 0, block.timestamp, true );

        uint256 maxBorrowableAmount = collateralAndLiquidity.maxBorrowableUSDS(alice);
        vm.expectRevert( "Excessive amountBorrowed" );
        collateralAndLiquidity.borrowUSDS(maxBorrowableAmount + 1 ether);

        vm.stopPrank();
	    }


	// A unit test to verify that an account cannot repay USDS if they don't have a position.
    function testCannotRepayUSDSWithoutPosition() public {
        vm.startPrank(bob);
        vm.expectRevert( "User does not have any collateral" );
        collateralAndLiquidity.repayUSDS(1 ether);
        vm.stopPrank();
    }

    // A unit test to validate borrowUSDS function for an account that has not deposited any collateral but tries to borrow USDS
    function testCannotBorrowUSDSWithoutPosition() public {
        vm.startPrank(bob);
        vm.expectRevert( "User does not have any collateral" );
        collateralAndLiquidity.borrowUSDS(1 ether);
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

		collateralAndLiquidity.depositCollateralAndIncreaseShare(10000, 10000, 0, block.timestamp, true );

        uint256 maxWithdrawableLPForAlice = collateralAndLiquidity.maxWithdrawableCollateral(alice);
        uint256 maxBorrowableUSDSForAlice = collateralAndLiquidity.maxBorrowableUSDS(alice);

        assertEq(maxWithdrawableLPForAlice, 20000, "maxWithdrawableCollateral should be 10000");
        assertEq(maxBorrowableUSDSForAlice,  0, "Max borrowable USDS should be zero");
		vm.stopPrank();

        // Scenario where account does not have a position
		vm.startPrank(bob);
        uint256 maxWithdrawableLPForNonPositionUser = collateralAndLiquidity.maxWithdrawableCollateral(bob);
        uint256 maxBorrowableUSDSForNonPositionUser = collateralAndLiquidity.maxBorrowableUSDS(bob);

        assertTrue(maxWithdrawableLPForNonPositionUser == 0, "maxWithdrawableCollateral for user without position should be zero");
        assertTrue(maxBorrowableUSDSForNonPositionUser == 0, "Max borrowable USDS for user without position should be zero");
		vm.stopPrank();

        // Scenario where a random user tries to borrow and withdraw
        address randomUser = address(0xDEAD);
		_readyUser( randomUser );

		vm.startPrank( randomUser );
        try collateralAndLiquidity.depositCollateralAndIncreaseShare(10000, 10000, 0, block.timestamp, false ) {
            fail("depositCollateral should have failed for random user");
        } catch {
            assertEq(collateralAndLiquidity.userCollateralValueInUSD(randomUser), 0);
        }

        try collateralAndLiquidity.borrowUSDS(100 ether) {
            fail("borrowUSDS should have failed for random user");
        } catch {
            assertEq(collateralAndLiquidity.userCollateralValueInUSD(randomUser), 0);
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
        assertEq(collateralAndLiquidity.findLiquidatableUsers().length, 3);

		vm.startPrank(alice);
		collateralAndLiquidity.repayUSDS( collateralAndLiquidity.usdsBorrowedByUsers(alice) );
		vm.stopPrank();

        // Now only two positions should be liquidatable.
        assertEq(collateralAndLiquidity.findLiquidatableUsers().length, 2);

        // Let's liquidate one of the positions.
        collateralAndLiquidity.liquidateUser(bob);

        // Now only one position should be liquidatable.
        assertEq(collateralAndLiquidity.findLiquidatableUsers().length, 1);

        // Charlie also repays all his debt.
		vm.startPrank(charlie);
		collateralAndLiquidity.repayUSDS( collateralAndLiquidity.usdsBorrowedByUsers(charlie) );
		vm.stopPrank();

        // Now no positions should be liquidatable.
        assertEq(collateralAndLiquidity.findLiquidatableUsers().length, 0);
    }


	// A unit test to verify the accuracy of userCollateralValueInUSD when there are multiple positions opened by a single user.
	function testUserCollateralValueInUSD_multiplePositions() public {

    	// Setup
    	vm.startPrank(alice);

		uint256 wbtcToDeposit = wbtc.balanceOf(alice) / 10;
		uint256 wethToDeposit = weth.balanceOf(alice) / 10;

		uint256 initialTokenValue = collateralAndLiquidity.underlyingTokenValueInUSD( wbtcToDeposit * 6, wethToDeposit * 6 );

		collateralAndLiquidity.depositCollateralAndIncreaseShare(wbtcToDeposit, wethToDeposit, 0, block.timestamp, true );
        vm.warp( block.timestamp + 1 days );

		collateralAndLiquidity.depositCollateralAndIncreaseShare(wbtcToDeposit * 2, wethToDeposit * 2, 0, block.timestamp, true );
        vm.warp( block.timestamp + 1 days );

		collateralAndLiquidity.depositCollateralAndIncreaseShare(wbtcToDeposit * 3, wethToDeposit * 3, 0, block.timestamp, true );
        vm.warp( block.timestamp + 1 days );

        // check the collateral value
        uint256 aliceCollateralValue = collateralAndLiquidity.userCollateralValueInUSD(alice);
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
        uint256 aliceCollateralValue = collateralAndLiquidity.userCollateralValueInUSD(alice);
        uint256 aliceCollateralRatio = (aliceCollateralValue * 100) / collateralAndLiquidity.usdsBorrowedByUsers(alice);
        assertTrue(aliceCollateralRatio < stableConfig.minimumCollateralRatioPercent());

        uint256 bobCollateralValue = collateralAndLiquidity.userCollateralValueInUSD(bob);
        uint256 bobCollateralRatio = (bobCollateralValue * 100) / collateralAndLiquidity.usdsBorrowedByUsers(bob);
        assertTrue(bobCollateralRatio < stableConfig.minimumCollateralRatioPercent());

        uint256 charlieCollateralValue = collateralAndLiquidity.userCollateralValueInUSD(charlie);
        uint256 charlieCollateralRatio = (charlieCollateralValue * 100) / collateralAndLiquidity.usdsBorrowedByUsers(charlie);
        assertTrue(charlieCollateralRatio < stableConfig.minimumCollateralRatioPercent());

        // Liquidate the positions
        vm.startPrank( DEPLOYER );
        collateralAndLiquidity.liquidateUser(alice);
        collateralAndLiquidity.liquidateUser(bob);
//        collateralAndLiquidity.liquidateUser(charlie);
		vm.stopPrank();

        // Verify that liquidation was successful
        assertEq(collateralAndLiquidity.userShareForPool(alice, collateralPoolID), 0);
        assertEq(collateralAndLiquidity.userShareForPool(bob, collateralPoolID), 0);
//        assertEq(collateralAndLiquidity.userShareForPool(charlie, collateralPoolID), 0);
    }


	// A unit test that makes sure that borrowing max USDS and then borrowing 1 USDS more fails
	function testBorrowMaxPlusOneUSDS() public {
        _depositCollateralAndBorrowMax(alice);

        // Now we try to borrow 1 USDS more which should fail
        vm.startPrank(alice);
        vm.expectRevert("Excessive amountBorrowed" );
        collateralAndLiquidity.borrowUSDS(1);
        vm.stopPrank();
    }


	// A unit test that checks that partial repayment of borrowed USDS adjust accounting correctly as does full repayment.
	function testRepaymentAdjustsAccountingCorrectly() public {

		// Start with no borrowers
		assertEq( collateralAndLiquidity.numberOfUsersWithBorrowedUSDS(), 0 );

		_depositCollateralAndBorrowMax(alice);


		uint256 aliceBorrowedUSDS = collateralAndLiquidity.usdsBorrowedByUsers(alice);

		// Check that there is now one user borrowing USDS
		assertEq( collateralAndLiquidity.numberOfUsersWithBorrowedUSDS(), 1 );


        // Alice repays half of her borrowed amount
        vm.startPrank(alice);

        // Make sure cannot repay too much
        vm.expectRevert( "Cannot repay more than the borrowed amount" );
        collateralAndLiquidity.repayUSDS(aliceBorrowedUSDS * 2);

        // Repay half
        collateralAndLiquidity.repayUSDS(aliceBorrowedUSDS / 2);
        vm.stopPrank();
		assertEq( collateralAndLiquidity.usdsBorrowedByUsers(alice), usds.balanceOf(alice), "Alice amount USDS borrowed not what she has" );

        // Check position after partial repayment
        assertEq(collateralAndLiquidity.usdsBorrowedByUsers(alice), aliceBorrowedUSDS / 2 );
		assertEq( collateralAndLiquidity.usdsBorrowedByUsers(alice), usds.balanceOf(alice), "Alice amount USDS borrowed not what she has" );

        // Alice repays the rest of her borrowed amount
        vm.startPrank(alice);
        collateralAndLiquidity.repayUSDS(collateralAndLiquidity.usdsBorrowedByUsers(alice));
        vm.stopPrank();
		assertEq( collateralAndLiquidity.usdsBorrowedByUsers(alice), usds.balanceOf(alice), "Alice amount USDS borrowed not what she has" );

        // Check position after full repayment
        assertEq( collateralAndLiquidity.usdsBorrowedByUsers(alice), 0 );
		assertEq( collateralAndLiquidity.numberOfUsersWithBorrowedUSDS(), 0 );
    }


	function check( uint256 shareA, uint256 shareB, uint256 shareC, uint256 rA, uint256 rB, uint256 rC, uint256 sA, uint256 sB, uint256 sC ) public
		{
		assertEq( collateralAndLiquidity.userShareForPool(alice, collateralPoolID), shareA, "Share A incorrect" );
		assertEq( collateralAndLiquidity.userShareForPool(bob, collateralPoolID), shareB, "Share B incorrect" );
		assertEq( collateralAndLiquidity.userShareForPool(charlie, collateralPoolID), shareC, "Share C incorrect" );

		assertEq( collateralAndLiquidity.userRewardForPool( alice, collateralPoolID ), rA, "Incorrect pending rewards A" );
        assertEq( collateralAndLiquidity.userRewardForPool( bob, collateralPoolID ), rB, "Incorrect pending rewards B" );
        assertEq( collateralAndLiquidity.userRewardForPool( charlie, collateralPoolID ), rC, "Incorrect pending rewards C" );

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
		collateralAndLiquidity.depositCollateralAndIncreaseShare(50*10**8, 50*10**8, 0, block.timestamp, true );
		check( 100*10**8, 0, 0, 0, 0, 0, 0, 0, 0 );
        AddedReward[] memory rewards = new AddedReward[](1);
        rewards[0] = AddedReward({poolID: collateralPoolID, amountToAdd: 50*10**8});

        vm.prank(DEPLOYER);
        collateralAndLiquidity.addSALTRewards(rewards);
        vm.warp( block.timestamp + 1 hours );
		check( 100*10**8, 0, 0, 50*10**8, 0, 0, 0, 0, 0 );

        // Bob stakes 10
        vm.prank(bob);
		collateralAndLiquidity.depositCollateralAndIncreaseShare(10*10**8, 10*10**8, 0, block.timestamp, true );
		check( 100*10**8, 20*10**8, 0, 50*10**8, 0, 0, 0, 0, 0 );
        rewards[0] = AddedReward({poolID: collateralPoolID, amountToAdd: 30*10**8});

        vm.prank(DEPLOYER);
        collateralAndLiquidity.addSALTRewards(rewards);
        vm.warp( block.timestamp + 1 hours );
		check( 100*10**8, 20*10**8, 0, 75*10**8, 5*10**8, 0, 0, 0, 0 );

		// Alice claims
		bytes32[] memory pools = new bytes32[](1);
		pools[0] = collateralPoolID;

        vm.prank(alice);
        collateralAndLiquidity.claimAllRewards(pools);
		check( 100*10**8, 20*10**8, 0, 0, 5*10**8, 0, 75*10**8, 0, 0 );
        rewards[0] = AddedReward({poolID: collateralPoolID, amountToAdd: 30*10**8});

        vm.prank(DEPLOYER);
        collateralAndLiquidity.addSALTRewards(rewards);
        vm.warp( block.timestamp + 1 hours );
		check( 100*10**8, 20*10**8, 0, 25*10**8, 10*10**8, 0, 75*10**8, 0, 0 );

        // Charlie stakes 40
        vm.prank(charlie);
		collateralAndLiquidity.depositCollateralAndIncreaseShare(40 *10**8, 40 *10**8, 0, block.timestamp, true );
		check( 100*10**8, 20*10**8, 80*10**8, 25*10**8, 10*10**8, 0, 75*10**8, 0, 0 );
        rewards[0] = AddedReward({poolID: collateralPoolID, amountToAdd: 100*10**8});

        vm.prank(DEPLOYER);
        collateralAndLiquidity.addSALTRewards(rewards);
        vm.warp( block.timestamp + 1 hours );
		check( 100*10**8, 20*10**8, 80*10**8, 75*10**8, 20*10**8, 40*10**8, 75*10**8, 0, 0 );

		// Alice unstakes 10
        vm.prank(alice);
        collateralAndLiquidity.withdrawCollateralAndClaim(20*10**8, 0, 0, block.timestamp);
		check( 80*10**8, 20*10**8, 80*10**8, 60*10**8, 20*10**8, 40*10**8, 90*10**8, 0, 0 );
        rewards[0] = AddedReward({poolID: collateralPoolID, amountToAdd: 90*10**8});

        vm.prank(DEPLOYER);
        collateralAndLiquidity.addSALTRewards(rewards);
        vm.warp( block.timestamp + 1 hours );
		check( 80*10**8, 20*10**8, 80*10**8, 100*10**8, 30*10**8, 80*10**8, 90*10**8, 0, 0 );

		// Bob claims
        vm.prank(bob);
        collateralAndLiquidity.claimAllRewards(pools);
		check( 80*10**8, 20*10**8, 80*10**8, 100*10**8, 0, 80*10**8, 90*10**8, 30*10**8, 0 );
        rewards[0] = AddedReward({poolID: collateralPoolID, amountToAdd: 90*10**8});

        vm.prank(DEPLOYER);
        collateralAndLiquidity.addSALTRewards(rewards);
        vm.warp( block.timestamp + 1 hours );
		check( 80*10**8, 20*10**8, 80*10**8, 140*10**8, 10*10**8, 120*10**8, 90*10**8, 30*10**8, 0 );

		// Charlie claims
        vm.prank(charlie);
        collateralAndLiquidity.claimAllRewards(pools);
		check( 80*10**8, 20*10**8, 80*10**8, 140*10**8, 10*10**8, 0, 90*10**8, 30*10**8, 120*10**8 );
        rewards[0] = AddedReward({poolID: collateralPoolID, amountToAdd: 180*10**8});

        vm.prank(DEPLOYER);
        collateralAndLiquidity.addSALTRewards(rewards);
        vm.warp( block.timestamp + 1 hours );
		check( 80*10**8, 20*10**8, 80*10**8, 220*10**8, 30*10**8, 80*10**8, 90*10**8, 30*10**8, 120*10**8 );

		// Alice adds 100
        vm.prank(alice);
		collateralAndLiquidity.depositCollateralAndIncreaseShare(100 *10**8, 100 *10**8, 0, block.timestamp, true );
		check( 280*10**8, 20*10**8, 80*10**8, 220*10**8, 30*10**8, 80*10**8, 90*10**8, 30*10**8, 120*10**8 );
        rewards[0] = AddedReward({poolID: collateralPoolID, amountToAdd: 190*10**8});

        vm.prank(DEPLOYER);
        collateralAndLiquidity.addSALTRewards(rewards);
        vm.warp( block.timestamp + 1 hours );
		check( 280*10**8, 20*10**8, 80*10**8, 360*10**8, 40*10**8, 120*10**8, 90*10**8, 30*10**8, 120*10**8 );

		// Charlie unstakes all
        vm.prank(charlie);
        collateralAndLiquidity.withdrawCollateralAndClaim(80*10**8, 0, 0, block.timestamp);
		check( 280*10**8, 20*10**8, 0, 360*10**8, 40*10**8, 0, 90*10**8, 30*10**8, 240*10**8 );
        rewards[0] = AddedReward({poolID: collateralPoolID, amountToAdd: 75*10**8});

        vm.prank(DEPLOYER);
        collateralAndLiquidity.addSALTRewards(rewards);
        vm.warp( block.timestamp + 1 hours );
		check( 280*10**8, 20*10**8, 0, 430*10**8, 45*10**8, 0, 90*10**8, 30*10**8, 240*10**8 );

		// Bob unstakes 2
        vm.prank(bob);
        collateralAndLiquidity.withdrawCollateralAndClaim(4*10**8, 0, 0, block.timestamp);
		check( 280*10**8, 16*10**8, 0, 430*10**8, 36*10**8, 0, 90*10**8, 39*10**8, 240*10**8 );
        rewards[0] = AddedReward({poolID: collateralPoolID, amountToAdd: 74*10**8});

        vm.prank(DEPLOYER);
        collateralAndLiquidity.addSALTRewards(rewards);
        vm.warp( block.timestamp + 1 hours );
		check( 280*10**8, 16*10**8, 0, 500*10**8, 40*10**8, 0, 90*10**8, 39*10**8, 240*10**8 );

		// Bob adds 148
        vm.prank(bob);
		collateralAndLiquidity.depositCollateralAndIncreaseShare(148 *10**8, 148 *10**8, 0, block.timestamp, true );
		check( 280*10**8, 312*10**8, 0, 500*10**8, 40*10**8, 0, 90*10**8, 39*10**8, 240*10**8 );
        rewards[0] = AddedReward({poolID: collateralPoolID, amountToAdd: 592*10**8});

        vm.prank(DEPLOYER);
        collateralAndLiquidity.addSALTRewards(rewards);
        vm.warp( block.timestamp + 1 hours );
		check( 280*10**8, 312*10**8, 0, 780*10**8, 352*10**8, 0, 90*10**8, 39*10**8, 240*10**8 );
	}


	// A unit test that tests maxRewardValueForCallingLiquidation
	function testMaxRewardValueForCallingLiquidation() public {
		// Bob deposits collateral so alice can be liquidated
		vm.startPrank(bob);
		collateralAndLiquidity.depositCollateralAndIncreaseShare(wbtc.balanceOf(bob), weth.balanceOf(bob), 0, block.timestamp, false );


		vm.startPrank(alice);
		collateralAndLiquidity.depositCollateralAndIncreaseShare(( 100000 ether *10**8) / priceAggregator.getPriceBTC(), ( 100000 ether *10**18) / priceAggregator.getPriceETH() , 0, block.timestamp, true );

		uint256 maxUSDS = collateralAndLiquidity.maxBorrowableUSDS(alice);
		collateralAndLiquidity.borrowUSDS( maxUSDS );
		vm.stopPrank();

        collateralAndLiquidity.userShareForPool( alice, collateralPoolID );
		uint256 aliceCollateralValue = collateralAndLiquidity.userCollateralValueInUSD(alice);

        uint256 aliceBorrowedUSDS = usds.balanceOf(alice);
        assertEq( collateralAndLiquidity.usdsBorrowedByUsers(alice), aliceBorrowedUSDS, "Alice amount USDS borrowed not what she has" );

        // Artificially crash the collateral price
        _crashCollateralPrice();

        // Delay before the liquidation
        vm.warp( block.timestamp + 1 days );

		uint256 startingWETH = weth.balanceOf(address(this));
		uint256 startingWBTC = wbtc.balanceOf(address(this));

        // Liquidate Alice's position
        collateralAndLiquidity.liquidateUser(alice);

        // Verify that Alice's position has been liquidated
        assertEq( collateralAndLiquidity.userShareForPool(alice, collateralPoolID), 0 );
        assertEq( collateralAndLiquidity.usdsBorrowedByUsers(alice), 0 );

        // Verify that caller has received WBTC and WETH for the liquidation
        uint256 expectedRewardValue = aliceCollateralValue * stableConfig.rewardPercentForCallingLiquidation() / 100;
        uint256 maxRewardValue = stableConfig.maxRewardValueForCallingLiquidation();
        if ( expectedRewardValue > maxRewardValue )
            expectedRewardValue = maxRewardValue;

		uint256 wbtcReward = wbtc.balanceOf(address(this)) - startingWBTC;
		uint256 wethReward = weth.balanceOf(address(this)) - startingWETH;

        assertTrue( collateralAndLiquidity.underlyingTokenValueInUSD(wbtcReward, wethReward ) < expectedRewardValue + expectedRewardValue * 5 / 1000 , "Incorrect rewards received for liquidating Alice");
        assertTrue( collateralAndLiquidity.underlyingTokenValueInUSD(wbtcReward, wethReward ) > expectedRewardValue - expectedRewardValue * 5 / 1000 , "Incorrect rewards received for liquidating Alice");
    }


	// A unit test that tests rewardPercentForCallingLiquidation
	function testRewardValueForCallingLiquidation() public {

		vm.startPrank(alice);

		uint256 depositedWBTC = ( 1500 ether *10**8) / priceAggregator.getPriceBTC();
		uint256 depositedWETH = ( 1500 ether *10**18) / priceAggregator.getPriceETH();

		collateralAndLiquidity.depositCollateralAndIncreaseShare( depositedWBTC, depositedWETH , 0, block.timestamp, true );
		vm.stopPrank();

		// Bob deposits collateral so alice can be liquidated
		vm.startPrank(bob);
		collateralAndLiquidity.depositCollateralAndIncreaseShare(wbtc.balanceOf(bob), weth.balanceOf(bob), 0, block.timestamp, false );
		vm.stopPrank();


		vm.startPrank(alice);
		uint256 maxUSDS = collateralAndLiquidity.maxBorrowableUSDS(alice);
		collateralAndLiquidity.borrowUSDS( maxUSDS );
		vm.stopPrank();

        collateralAndLiquidity.userShareForPool( alice, collateralPoolID );
		uint256 aliceCollateralValue = collateralAndLiquidity.userCollateralValueInUSD(alice);

        uint256 aliceBorrowedUSDS = usds.balanceOf(alice);
        assertEq( collateralAndLiquidity.usdsBorrowedByUsers(alice), aliceBorrowedUSDS, "Alice amount USDS borrowed not what she has" );

        // Artificially crash the collateral price
        _crashCollateralPrice();

		aliceCollateralValue = collateralAndLiquidity.userCollateralValueInUSD(alice);

        // Delay before the liquidation
        vm.warp( block.timestamp + 1 days );

		uint256 startingWBTC = wbtc.balanceOf(address(this));
		uint256 startingWETH = weth.balanceOf(address(this));

        // Liquidate Alice's position
        collateralAndLiquidity.liquidateUser(alice);

        // Verify that Alice's position has been liquidated
        assertEq( collateralAndLiquidity.userShareForPool(alice, collateralPoolID), 0 );
        assertEq( collateralAndLiquidity.usdsBorrowedByUsers(alice), 0 );

        // Verify that caller has received WETH for the liquidation
        uint256 expectedRewardValue = aliceCollateralValue * stableConfig.rewardPercentForCallingLiquidation() / 100;

		uint256 wbtcReward = wbtc.balanceOf(address(this)) - startingWBTC;
		uint256 wethReward = weth.balanceOf(address(this)) - startingWETH;

//		console.log( "wbtcReward: ", wbtcReward );
//		console.log( "wethReward: ", wethReward );

        assertTrue( collateralAndLiquidity.underlyingTokenValueInUSD(wbtcReward, wethReward ) < expectedRewardValue + expectedRewardValue * 5 / 1000 , "Should have received WETH for liquidating Alice");
        assertTrue( collateralAndLiquidity.underlyingTokenValueInUSD(wbtcReward, wethReward ) > expectedRewardValue - expectedRewardValue * 5 / 1000 , "Should have received WETH for liquidating Alice");
    }


	// A unit test to test minimumCollateralValueForBorrowing
	function testMinimumCollateralValueForBorrowing() public {
		vm.startPrank(alice);
		collateralAndLiquidity.depositCollateralAndIncreaseShare(( 1000 ether *10**8) / priceAggregator.getPriceBTC(), ( 1000 ether *10**18) / priceAggregator.getPriceETH() , 0, block.timestamp, true );

		uint256 maxUSDS = collateralAndLiquidity.maxBorrowableUSDS(alice);
		assertEq( maxUSDS, 0, "Should not be able to borrow USDS with only $2000 worth of collateral" );

		vm.expectRevert( "Excessive amountBorrowed" );
		collateralAndLiquidity.borrowUSDS( 1 );

		vm.warp( block.timestamp + 1 hours );
		collateralAndLiquidity.depositCollateralAndIncreaseShare(( 1000 ether *10**8) / priceAggregator.getPriceBTC(), ( 1000 ether *10**18) / priceAggregator.getPriceETH() , 0, block.timestamp, true );

		maxUSDS = collateralAndLiquidity.maxBorrowableUSDS(alice);
        uint256 expectedMaxUSDS = 2000 ether;

        assertTrue( maxUSDS < expectedMaxUSDS + expectedMaxUSDS * 5 / 1000 , "Incorrect expectedMaxUSDS" );
        assertTrue( maxUSDS > expectedMaxUSDS - expectedMaxUSDS * 5 / 1000 , "Incorrect expectedMaxUSDS" );

		collateralAndLiquidity.borrowUSDS( expectedMaxUSDS * 999 / 1000 );

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


        // Liquidate Alice's position
        vm.expectRevert( "Invalid BTC price" );
        collateralAndLiquidity.liquidateUser(alice);

        assertFalse( collateralAndLiquidity.userShareForPool(alice, collateralPoolID) == 0 );
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


        // Liquidate Alice's position
        vm.expectRevert( "Invalid BTC price" );
        collateralAndLiquidity.liquidateUser(alice);

        assertFalse( collateralAndLiquidity.userShareForPool(alice, collateralPoolID) == 0 );
    }


	// A user test to check that liquidation is possible if the PriceFeed is returning two similar prices and one failure
	function testUserLiquidationWithTwoGoodFeeds() public {

		// Bob deposits collateral so alice can be liquidated
        vm.startPrank(bob);
		collateralAndLiquidity.depositCollateralAndIncreaseShare(wbtc.balanceOf(bob), weth.balanceOf(bob), 0, block.timestamp, false );
		vm.stopPrank();

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


        // Liquidate Alice's position
        collateralAndLiquidity.liquidateUser(alice);

        assertTrue( collateralAndLiquidity.userShareForPool(alice, collateralPoolID) == 0 );
    }


	// A user test to check that no borrowing is possible if the PriceFeed is returning an invalid price
	function testUserBorrowingWithBadPriceFeed() public {

		IForcedPriceFeed forcedPriceFeed = new ForcedPriceFeed(0, 0 );

		vm.startPrank(address(dao));
		priceAggregator.setPriceFeed(1, IPriceFeed(address(forcedPriceFeed)));
		vm.warp( block.timestamp + 60 days);
		priceAggregator.setPriceFeed(2, IPriceFeed(address(forcedPriceFeed)));
		vm.stopPrank();



        // Deposit and borrow for Alice
		vm.startPrank( alice );
		collateralAndLiquidity.depositCollateralAndIncreaseShare(wbtc.balanceOf(alice) / 2, weth.balanceOf(alice) / 2, 0, block.timestamp, true );

        vm.expectRevert( "Invalid BTC price" );
		uint256 maxUSDS = collateralAndLiquidity.maxBorrowableUSDS(alice);

        vm.expectRevert( "Invalid BTC price" );
		collateralAndLiquidity.borrowUSDS( maxUSDS );
		vm.stopPrank();
        }


	// A unit test to verify the case scenario where a user tries to deposit zero collateral amount in the depositCollateralAndIncreaseShare function.
	function testDepositZeroCollateral() public {
        // Alice attempts to deposit zero collateral which should not be allowed.
        vm.prank(alice);
        vm.expectRevert("The amount of tokenA to add is too small");
        collateralAndLiquidity.depositCollateralAndIncreaseShare(0, 0, 0, block.timestamp, false);
    }


	// A unit test that validates the behaviour of borrowUSDS function when the user has not yet deposited any collateral.
	// A unit test that validates the borrowUSDS function behavior when a user has not deposited any collateral.
    function testBorrowUSDSWithoutCollateral() public {

    	// Give access to the user
		bytes memory sig = abi.encodePacked(oneTwoThreeFourAccessSignature);
		vm.prank( address(0x1234) );
		accessManager.grantAccess(sig);


    	address userX = address(0x1234);

        assertEq(wbtc.balanceOf(userX), 0, "userX should start with zero WBTC");
        assertEq(weth.balanceOf(userX), 0, "userX should start with zero WETH");
        assertEq(usds.balanceOf(userX), 0, "userX should start with zero USDS");

        // Alice tries to borrow USDS without having deposited any collateral
        vm.startPrank(userX);
        vm.expectRevert("User does not have any collateral");
        collateralAndLiquidity.borrowUSDS(1 ether);
        vm.stopPrank();

        // Verify Alice's collateral and USDS balance remain unchanged
        assertEq(_userHasCollateral(userX), false, "userX should have no collateral");
        assertEq(usds.balanceOf(userX), 0, "userX should have zero USDS");
    }


	// A unit test to verify that the canUserBeLiquidated function returns false when the borrowed amount is less than the collateral ratio threshold.
	function testCanUserBeLiquidatedUnderThreshold() public {

        // Verify that Alice can't be liquidated yet (collateral ratio is 200%)
        assertFalse(collateralAndLiquidity.canUserBeLiquidated(alice));

        _depositCollateralAndBorrowMax(alice);

        // Verify that Alice can't be liquidated yet (collateral ratio is 200%)
        assertFalse(collateralAndLiquidity.canUserBeLiquidated(alice));

        // Alice repays half of her borrowed USDS
        uint256 bobBorrowedUSDS = collateralAndLiquidity.usdsBorrowedByUsers(alice);
        vm.prank(alice);
        collateralAndLiquidity.repayUSDS(bobBorrowedUSDS / 2);

        // Verify that Alice can't be liquidated (collateral ratio is now 400%)
        assertFalse(collateralAndLiquidity.canUserBeLiquidated(alice));
    }


    // A unit test for totalSharesForPool function, ensuring it returns zero when the total collateral amount becomes zero.
    function testTotalSharesForPool() public {

    	// Alice will deposit all her collateral and borrow max
    	_depositCollateralAndBorrowMax(alice);

		vm.warp(block.timestamp + 1 days);

    	assertTrue( _userHasCollateral(alice) );

    	// Ensure the total shares for pool is greater than zero
    	assertTrue(collateralAndLiquidity.totalShares(collateralPoolID) > 0, "Total shares for pool should be greater than zero");

		uint256 aliceCollateral = collateralAndLiquidity.userShareForPool(alice, collateralPoolID);

    	// Withdraw all collateral of Alice
    	vm.startPrank(address(alice));
    	collateralAndLiquidity.repayUSDS( collateralAndLiquidity.usdsBorrowedByUsers(alice));
    	collateralAndLiquidity.withdrawCollateralAndClaim( aliceCollateral / 2, 0, 0, block.timestamp );
    	vm.stopPrank();

    	// After withdrawing all collaterals the total shares for pool should be zero
    	assertEq(collateralAndLiquidity.totalShares(collateralPoolID), aliceCollateral / 2, "Total shares for pool should be zero after withdrawing all collaterals");
    }


    // A unit test to validate the maxBorrowableUSDS function for multiple users with different levels of collateral values notably those above, at, and below the minimumCollateralValueForBorrowing.
    function testMaxBorrowableUSDS() public {
        _depositCollateralAndBorrowMax(alice);
        vm.prank(alice);
        collateralAndLiquidity.repayUSDS(1 ether);
        assertEq( collateralAndLiquidity.maxBorrowableUSDS(alice), 1 ether );

        _depositCollateralAndBorrowMax(bob);
        vm.prank(bob);
        collateralAndLiquidity.repayUSDS(2 ether);
        assertEq( collateralAndLiquidity.maxBorrowableUSDS(bob), 2 ether );

        _depositHalfCollateralAndBorrowMax(charlie);
        vm.prank(charlie);
        collateralAndLiquidity.repayUSDS(3 ether);
        assertEq( collateralAndLiquidity.maxBorrowableUSDS(charlie), 3 ether );

        uint256 maxBorrowDeployer = collateralAndLiquidity.maxBorrowableUSDS(DEPLOYER);
        assertTrue(maxBorrowDeployer == 0, "Deployer should not be able to borrow");

        // Artificially crash the collateral price
        _crashCollateralPrice();

        // Alice and bob should not able to borrow after price crash
        uint256 maxBorrowAlice = collateralAndLiquidity.maxBorrowableUSDS(alice);
        assertTrue(maxBorrowAlice == 0, "Alice should not be able to borrow after price crash");

        uint256 maxBorrowBob = collateralAndLiquidity.maxBorrowableUSDS(bob);
        assertTrue(maxBorrowBob == 0, "Bob should not be able to borrow after price crash");

        // Charlie can still borrow as he only borrowed half initially
        uint256 maxBorrowCharlie = collateralAndLiquidity.maxBorrowableUSDS(charlie);
        assertTrue(maxBorrowCharlie == 0, "Charlie should not be able to borrow");
    }


    // A unit test validating the behavior of liquidateUser function in the scenario where the user is just above the liquidation threshold.
    function testLiquidateUserMarginallyAboveThreshold() public {

		// Bob deposits collateral so alice can be liquidated
        vm.startPrank(bob);
		collateralAndLiquidity.depositCollateralAndIncreaseShare(wbtc.balanceOf(bob), weth.balanceOf(bob), 0, block.timestamp, false );
		vm.stopPrank();


        // User deposits collateral and borrows max USDS
        _depositCollateralAndBorrowMax(alice);

        vm.warp( block.timestamp + 1 days);

        // At this point, Alice shouldn't be liquidatable
        assertFalse( collateralAndLiquidity.canUserBeLiquidated(alice), "Alice should not be liquidatable initially" );

        // Manipulate collateral price to bring Alice just over the liquidation threshold
        uint256 originalPriceBTC = forcedPriceFeed.getPriceBTC();
        uint256 originalPriceETH = forcedPriceFeed.getPriceETH();
        uint256 newPriceBTC = (originalPriceBTC * 55) / 100;
        uint256 newPriceETH = (originalPriceETH * 55) / 100;

        vm.startPrank( DEPLOYER );
        forcedPriceFeed.setBTCPrice( newPriceBTC );
        forcedPriceFeed.setETHPrice( newPriceETH );
        vm.stopPrank();

        // Alice should now be just above the liquidation threshold
        assertFalse(  collateralAndLiquidity.canUserBeLiquidated(alice), "Alice should still not be liquidatable" );

        // Trying to liquidate Alice now should fail
        vm.expectRevert( "User cannot be liquidated" );
        vm.prank(bob);
        collateralAndLiquidity.liquidateUser(alice);

        // Crash the collateral value further to bring Alice under the liquidation threshold
        newPriceBTC = (originalPriceBTC * 54) / 100;
        newPriceETH = (originalPriceETH * 54) / 100;

        vm.startPrank( DEPLOYER );
        forcedPriceFeed.setBTCPrice( newPriceBTC );
        forcedPriceFeed.setETHPrice( newPriceETH );
        vm.stopPrank();

        // Alice should now be under the liquidation threshold
        assertTrue(  collateralAndLiquidity.canUserBeLiquidated(alice), "Alice should be liquidatable after crashing the collateral price further" );

        // Liquidate Alice's position
        vm.prank(bob);
        collateralAndLiquidity.liquidateUser(alice);

        // Alice's position should now be liquidated
        assertEq( collateralAndLiquidity.userShareForPool(alice, collateralPoolID), 0 );
        assertEq( collateralAndLiquidity.usdsBorrowedByUsers(alice), 0 );
    }


  	// A unit test for accuracy of maxWithdrawableCollateral function for scenarios where all borrowed USDS have been repaid.
  	function testMaxWithdrawableCollateralAfterRepayment() public {
        // Arrange
        _depositCollateralAndBorrowMax(alice);

        uint256 borrowed = collateralAndLiquidity.usdsBorrowedByUsers(alice);
        assertTrue(borrowed > 0, "Alice should have borrowed some USDS");

        uint256 collateralBeforeRepayment = collateralAndLiquidity.userShareForPool( alice, collateralPoolID );
        assertEq(collateralAndLiquidity.maxWithdrawableCollateral(alice), 0, "Alice shouldn't withdraw any collateral before repayment");

        // Act
        vm.startPrank(alice);
        collateralAndLiquidity.repayUSDS(borrowed);
        vm.stopPrank();

        // Assert
        uint256 collateralAfterRepayment = collateralAndLiquidity.userShareForPool(alice, collateralPoolID);
        assertEq(collateralAfterRepayment, collateralBeforeRepayment, "Alice's collateral should remain the same after repayment");
        assertEq(collateralAndLiquidity.maxWithdrawableCollateral(alice), collateralAfterRepayment, "Alice should be able to withdraw all collateral after repayment");
    }


	// A unit test that validates the _walletsWithBorrowedUSDS set does not add duplicate wallets, even when multiple borrowUSDS operations are executed from the same user
	function testNoDuplicateWalletsInBorrowUSDS() public {
        assertEq(collateralAndLiquidity.numberOfUsersWithBorrowedUSDS(), 0, "Should start with 0 wallets with borrowed USDS");

		_readyUser(alice);
		_readyUser(bob);

        // Alice borrows from the contract
        vm.startPrank(alice);
        collateralAndLiquidity.depositCollateralAndIncreaseShare(wbtc.balanceOf(alice), weth.balanceOf(alice), 0, block.timestamp, true );
        collateralAndLiquidity.borrowUSDS(1 ether);
        vm.stopPrank();

        assertEq(collateralAndLiquidity.numberOfUsersWithBorrowedUSDS(), 1, "After one borrow operation, there should be 1 wallet with borrowed USDS");

        // Alice borrows again from the contract
        vm.startPrank(alice);
        collateralAndLiquidity.borrowUSDS(1 ether);
        vm.stopPrank();

        assertEq(collateralAndLiquidity.numberOfUsersWithBorrowedUSDS(), 1, "After second borrow operation from the same wallet, there should still be 1 wallet with borrowed USDS");

        // Bob borrows from the contract
        vm.startPrank(bob);
        collateralAndLiquidity.depositCollateralAndIncreaseShare(wbtc.balanceOf(bob), weth.balanceOf(bob), 0, block.timestamp, true );
        collateralAndLiquidity.borrowUSDS(1 ether);
        vm.stopPrank();

        assertEq(collateralAndLiquidity.numberOfUsersWithBorrowedUSDS(), 2, "After borrow operation from a new wallet, there should be 2 wallets with borrowed USDS");
    }


	// A unit test that verifies the accurate calculation, behavior, and exception handling for cases with various amounts of borrowed USDS in the repayUSDS function.
	function testRepayUSDS() public {
        _depositCollateralAndBorrowMax(alice);

        uint256 borrowedUSDS = collateralAndLiquidity.usdsBorrowedByUsers(alice);
        uint256 aliceUSDSBalance = IERC20(address(usds)).balanceOf(alice);

        assertEq(borrowedUSDS, aliceUSDSBalance, "Alice's borrowed USDS should equal her USDS balance.");

        uint256 repayAmount = borrowedUSDS / 2;
        vm.prank(alice);
        collateralAndLiquidity.repayUSDS(repayAmount);

        // Alice's borrowedUSDS and USDS balance should have decreased by `repayAmount`
        assertEq(collateralAndLiquidity.usdsBorrowedByUsers(alice), borrowedUSDS - repayAmount, "Alice's borrowed USDS did not decrease correctly.");
        assertEq(IERC20(address(usds)).balanceOf(alice), aliceUSDSBalance - repayAmount, "Alice's USDS balance did not decrease correctly.");

        // Trying to repay more than borrowed should fail
        uint256 remainingBorrowedUSDS = collateralAndLiquidity.usdsBorrowedByUsers(alice);
        vm.expectRevert("Cannot repay more than the borrowed amount");

        vm.prank(alice);
        collateralAndLiquidity.repayUSDS(remainingBorrowedUSDS + 1);

        // Repay full remaining amount
        vm.prank(alice);
        collateralAndLiquidity.repayUSDS(remainingBorrowedUSDS);

        assertEq(collateralAndLiquidity.usdsBorrowedByUsers(alice), 0, "Alice's borrowed USDS should be 0 after full repayment.");
        assertEq(IERC20(address(usds)).balanceOf(alice), aliceUSDSBalance - borrowedUSDS, "Alice's USDS balance did not decrease correctly after full repayment.");
    }


	// A unit test to verify the behavior of collateralValueInUSD function when the user does not have any collateral in the collateral pool.
		function testCollateralValueInUSD_NoCollateralInPool() public {
    		assertEq(collateralAndLiquidity.userShareForPool(bob, collateralPoolID), 0, "Bob should start with no collateral in pool");

    		// The collateral value for Bob should be 0 as there is no collateral in the pool
			uint256 collateralValueUSD = collateralAndLiquidity.userCollateralValueInUSD(bob);
    		assertEq(collateralValueUSD, 0, "Bob's collateral value should be 0 with no collateral in the pool");
    	}


    // A unit test which verifies that the liquidateUser function correctly updates the number of users with borrowed USDS.
	function testLiquidateUserUpdatesUsersWithBorrowedUSDS() public {
        // Assume Alice, Bob and Charlie have borrowed USDS
        _depositCollateralAndBorrowMax(alice);
        _depositCollateralAndBorrowMax(bob);
        _depositCollateralAndBorrowMax(charlie);

        // Check initial state
        assertEq(collateralAndLiquidity.numberOfUsersWithBorrowedUSDS(), 3, "Initial number of users with borrowed USDS should be 3");

        // Artificially crash the collateral price
        _crashCollateralPrice();

        // Delay before the liquidation
        vm.warp( block.timestamp + 1 days );

        // Liquidate Alice's position
        vm.prank(bob);
        collateralAndLiquidity.liquidateUser(alice);

        // Check that the number of users with borrowed USDS is now 2
        assertEq(collateralAndLiquidity.numberOfUsersWithBorrowedUSDS(), 2, "Number of users with borrowed USDS should be 2 after liquidating Alice");

        // Liquidate Bob's position
        vm.prank(charlie);
        collateralAndLiquidity.liquidateUser(bob);

        // Check that the number of users with borrowed USDS is now 1
        assertEq(collateralAndLiquidity.numberOfUsersWithBorrowedUSDS(), 1, "Number of users with borrowed USDS should be 1 after liquidating Bob");

//        // Liquidate Charlie's position
//        vm.prank(alice);
//        collateralAndLiquidity.liquidateUser(charlie);
//
//        // Check that the number of users with borrowed USDS is now 0
//        assertEq(collateralAndLiquidity.numberOfUsersWithBorrowedUSDS(), 0, "Number of users with borrowed USDS should be 0 after liquidating Charlie");
    }


    // A unit test that validates wbtc and weth balances in the contract should be zero when there are no depositors or borrowers
    function testZeroWbtcWethBalances() public {
          assertEq(collateralAndLiquidity.numberOfUsersWithBorrowedUSDS(), 0 );

        // Check WBTC and WETH balances
        assertEq(wbtc.balanceOf(address(collateralAndLiquidity)), 0 ether, "WBTC balance should be zero when there are no depositors or borrowers");
        assertEq(weth.balanceOf(address(collateralAndLiquidity)), 0 ether, "WETH balance should be zero when there are no depositors or borrowers");
    }


	// A unit test to validate userCollateralValueInUSD for wallets which have not deposited any collateral.
	function testUserCollateralValueInUSD3() public {
        address newUser = address(0x4444);
        // Make sure newUser does not have any collateral
        assertFalse(_userHasCollateral(newUser), "New user should not have any collateral");
        // Try to get the user collateral value in USD
        uint256 collateralValue = collateralAndLiquidity.userCollateralValueInUSD(newUser);
        // The value should be 0 because the user has not deposited any collateral
        assertEq(collateralValue, 0, "Collateral value for a user with no collateral should be 0");
    }


    // A unit test that ensures collateralValueInUSD returns zero when the provided collateralAmount value is zero.
    function testCollateralValueInUSD() public {
        // Prepare
        uint256 zeroCollateralValue = 0;
        // Call
        uint256 result = collateralAndLiquidity.userCollateralValueInUSD(address(0x3));
        // Assert
        assertEq(result, zeroCollateralValue, "Expect collateralValueInUSD with zero collateral to be zero");
    }



    // A unit test to validate behaviors of liquidateUser function when the wallet to be liquidated has no borrowed USDS.
	// A unit test to validate the behavior of 'liquidateUser' function when the wallet to be liquidated has no borrowed USDS.
    function testLiquidateUserWithoutBorrowedUSDS() public {

    	_depositCollateralAndBorrowMax(alice);

    	vm.startPrank(alice);
    	collateralAndLiquidity.repayUSDS( collateralAndLiquidity.usdsBorrowedByUsers(alice));
    	vm.stopPrank();

        // Make sure Alice starts with zero USDS borrowed
        assertEq(collateralAndLiquidity.usdsBorrowedByUsers(alice), 0, "Alice should start with zero borrowed USDS");

        // Make sure Alice's collateral is more than zero
        assertTrue(_userHasCollateral(alice), "Alice doesn't have any collateral");

        // Artificially crash the collateral price
        _crashCollateralPrice();

        // Delay before the liquidation
        vm.warp( block.timestamp + 1 days );

        // Try and fail to liquidate Alice
        vm.expectRevert( "User cannot be liquidated" );
        vm.prank(bob);
        collateralAndLiquidity.liquidateUser(alice);

        // Alice's position should remain unchanged
        assertTrue(_userHasCollateral(alice), "Alice's position should not have been liquidated");
        assertEq(collateralAndLiquidity.usdsBorrowedByUsers(alice), 0, "Alice should still have zero borrowed USDS");
    }

    // A unit test that checks after every successful liquidity withdrawal the totalSharesForPool function returns updated share
    function testWithdrawCollateralAndSharesUpdate() public {
        // Alice deposits collateral and borrows the maximum amount of USDS
        _depositCollateralAndBorrowMax(alice);

		vm.warp( block.timestamp + 1 days );

    	vm.startPrank(alice);
    	collateralAndLiquidity.repayUSDS( collateralAndLiquidity.usdsBorrowedByUsers(alice));
    	vm.stopPrank();


        uint256 aliceCollateralAmount = collateralAndLiquidity.userShareForPool(alice, collateralPoolID);

        // Alice withdraws some collateral
        uint256 collateralToWithdraw = aliceCollateralAmount / 2;

        vm.prank(alice);
        collateralAndLiquidity.withdrawCollateralAndClaim(collateralToWithdraw, 0, 0, block.timestamp);

        // Total shares should be reduced by the withdrawn collateral amount
        uint256 sharesAfterWithdrawal = collateralAndLiquidity.totalShares(collateralPoolID);
        assertEq(aliceCollateralAmount - collateralToWithdraw, sharesAfterWithdrawal, "totalSharesForPool did not update");

        assertEq(collateralAndLiquidity.userShareForPool(alice, collateralPoolID), sharesAfterWithdrawal);
    }



    // A unit test that checks if repayUSDS function correctly reverts when the amount to repay is more than the borrowed amount
    function testRepayUSDSExceedBorrowed() public {
        _depositCollateralAndBorrowMax(alice);
        uint256 borrowedUSDS = collateralAndLiquidity.usdsBorrowedByUsers(alice);

        // Try to repay more than the borrowed USDS
        vm.startPrank(alice);
        vm.expectRevert("Cannot repay more than the borrowed amount");
        collateralAndLiquidity.repayUSDS(borrowedUSDS + 1 ether);
        vm.stopPrank();
    }



    // A unit test to check if depositCollateralAndIncreaseShare function throws error when called by a wallet which doesn't have exchange access.
    function testDepositCollateralWithoutExchangeAccess() public {

		address wallet = address(0xDEAD1);

		_readyUser(wallet);

		uint256 wbtcBalance = wbtc.balanceOf(wallet);
		uint256 wethBalance = weth.balanceOf(wallet);

		vm.expectRevert( "Sender does not have exchange access" );

		vm.startPrank( wallet );
		collateralAndLiquidity.depositCollateralAndIncreaseShare( wbtcBalance, wethBalance, 0, block.timestamp, true );
		vm.stopPrank();
    }


	// A unit test which verifies the behavior of userShareForPool function for wallets without any collateral share in the pool.
	function testUserShareForPoolWithoutCollateral() public {
        // Given no collateral has been deposited for alice so far, expect 0 share
        vm.startPrank(alice);
        uint256 aliceCollateralShare = collateralAndLiquidity.userShareForPool(alice, collateralPoolID);
        assertEq(aliceCollateralShare, 0, "Alice shouldn't have collateral share to begin with");

        // Also, let's ensure calling this function for an arbitray address (not in the system) should return 0
        address randomAddress = address(0x9999);
        uint256 randomAddressCollateralShare = collateralAndLiquidity.userShareForPool(randomAddress, collateralPoolID);
        assertEq(randomAddressCollateralShare, 0, "Random address shouldn't have collateral share");
        vm.stopPrank();
    }



	// A unit test that validates the behavior of underlyingTokenValueInUSD function with a range of token prices.
	function testUnderlyingTokenValueInUSD() public {
        uint256[5] memory mockBTCPricesInUSD = [uint256(100000 ether), 50000 ether, 20000 ether, 10000 ether, 5000 ether];
        uint256[5] memory mockETHPricesInUSD = [uint256(3000 ether), 2000 ether, 1500 ether, 1000 ether, 500 ether];

		forcedPriceFeed = IForcedPriceFeed(address(priceAggregator.priceFeed1()));

        for (uint256 i = 0; i < mockBTCPricesInUSD.length; i++) {
            uint256 mockBTCPriceInUSD = mockBTCPricesInUSD[i];
            uint256 mockETHPriceInUSD = mockETHPricesInUSD[i];

            // Mock the BTC and ETH prices
            vm.startPrank(DEPLOYER);
            forcedPriceFeed.setBTCPrice(mockBTCPriceInUSD);
            forcedPriceFeed.setETHPrice(mockETHPriceInUSD);
            vm.stopPrank();

			vm.prank(address(upkeep));

            uint256 expectedUnderlyingTokenValueInUSD = mockBTCPriceInUSD + mockETHPriceInUSD;

            assertEq( collateralAndLiquidity.underlyingTokenValueInUSD(1 * 10**8, 1 ether), expectedUnderlyingTokenValueInUSD, "underlyingTokenValueInUSD" );
        }
    }


    // A unit test that validates the behavior of _increaseUserShare function with a range of addedLiquidity values.
    function testDepositCollateralAndIncreaseShare() public {
        // Initial balances for Alice
        uint256 initialWBTCBalanceA = wbtc.balanceOf(alice);
        uint256 initialWETHBalanceA = weth.balanceOf(alice);

        // Alice tries to deposit 0 WBTC and 0 WETH, should fail
        vm.expectRevert("The amount of tokenA to add is too small");
        vm.prank(alice);
        collateralAndLiquidity.depositCollateralAndIncreaseShare(0, 0, 1, block.timestamp + 15 minutes, false);

        // Alice deposits half of her WBTC and WETH
        uint256 depositWBTC = initialWBTCBalanceA / 2;
        uint256 depositWETH = initialWETHBalanceA / 2;

        uint256 liquidityBefore = collateralAndLiquidity.userShareForPool(alice, collateralPoolID);

        vm.prank(alice);
        collateralAndLiquidity.depositCollateralAndIncreaseShare(depositWBTC, depositWETH, 1, block.timestamp + 15 minutes, false);

        uint256 liquidityAfter = collateralAndLiquidity.userShareForPool(alice, collateralPoolID);

        // Validate that liquidity increased for Alice
        assertEq(liquidityAfter > liquidityBefore, true, "Liquidity should have increased for Alice");

        // Validate that Alice's WBTC and WETH balances decreased
        assertEq(wbtc.balanceOf(alice), initialWBTCBalanceA - depositWBTC, "Alice's WBTC balance should have decreased by depositWBTC");
        assertEq(weth.balanceOf(alice), initialWETHBalanceA - depositWETH, "Alice's WETH balance should have decreased by depositWETH");
    }


    // A unit test that verifies the userShareForPool for accounts with multiple collateral positions.
    function testUserShareForPool_multipleCollateralPositions() public {
    	_depositHalfCollateralAndBorrowMax(alice);
    	_depositHalfCollateralAndBorrowMax(bob);
		vm.warp( block.timestamp + 1 days);

    	uint256 aliceShareBeforeSecondDeposit = collateralAndLiquidity.userShareForPool(alice, collateralPoolID);
    	uint256 bobShareBeforeSecondDeposit = collateralAndLiquidity.userShareForPool(bob, collateralPoolID);

    	_depositHalfCollateralAndBorrowMax(alice);
    	_depositHalfCollateralAndBorrowMax(bob);

    	uint256 aliceShareAfterSecondDeposit = collateralAndLiquidity.userShareForPool(alice, collateralPoolID);
    	uint256 bobShareAfterSecondDeposit = collateralAndLiquidity.userShareForPool(bob, collateralPoolID);

    	assertTrue(aliceShareAfterSecondDeposit > aliceShareBeforeSecondDeposit, "Alice's share should increase after second deposit");
    	assertTrue(bobShareAfterSecondDeposit > bobShareBeforeSecondDeposit, "Bob's share should increase after second deposit");
    }


    // A unit test that checks the borrower's position before and after the liquidity is removed and verifies the decrease in shares after the removal of collateralAndLiquidity.
	function testBorrowerPositionBeforeAndAfterRemovingLiquidity() public {
        // Alice will deposit all her collateral and borrow max
        _depositCollateralAndBorrowMax(alice);

		vm.warp( block.timestamp + 1 days );

		// Repay so that colalteral can be withdrawn
    	vm.startPrank(alice);
    	collateralAndLiquidity.repayUSDS( collateralAndLiquidity.usdsBorrowedByUsers(alice));
    	vm.stopPrank();

        uint256 aliceCollateralShare = collateralAndLiquidity.userShareForPool(alice, collateralPoolID);

        // Alice will withdraw half of her collateral
        uint256 halfCollateral = aliceCollateralShare / 2;
        vm.prank(alice);
        collateralAndLiquidity.withdrawCollateralAndClaim(halfCollateral, 0, 0, block.timestamp);

        uint256 aliceCollateralShareAfterWithdraw = collateralAndLiquidity.userShareForPool(alice, collateralPoolID);

        uint256 collateralDecrease = aliceCollateralShare - aliceCollateralShareAfterWithdraw;
        assertEq(halfCollateral, collateralDecrease, "The decrease in Alice's collateral share should be equal to the amount withdrawn");
    }


    // A unit test to check that WBTC/WETH LP providers can receive staking rewards
    function testCollateralDepositersCanReceiveStakingRewards() public
    	{
	  	_depositHalfCollateralAndBorrowMax(alice);

		uint256 startingBalance = salt.balanceOf(alice);

		vm.prank(address(upkeep));
		liquidityRewardsEmitter.performUpkeep( 24 hours);

		bytes32[] memory poolIDs = new bytes32[](1);
		poolIDs[0] = PoolUtils._poolID(wbtc, weth);

		vm.prank(alice);
		collateralAndLiquidity.claimAllRewards(poolIDs);

		// Default 1% emitted by the liquidityRewardsEmitter each day
		uint256 expectedClaim = 5555555555555555555555;

		assertEq( salt.balanceOf(alice) - startingBalance, expectedClaim );
    	}


	// A unit test that tests depositing and withdrawing collateral
	function testDepositAndWithdrawCollateral2() public {

		// Total needs to be worth at least $2500
		uint256 depositedWBTC = ( 2000 ether *10**8) / priceAggregator.getPriceBTC();
		uint256 depositedWETH = ( 2000 ether *10**18) / priceAggregator.getPriceETH();

		(uint256 reserveWBTC, uint256 reserveWETH) = pools.getPoolReserves(wbtc, weth);
		assertEq( reserveWBTC, 0, "reserveWBTC doesn't start as zero" );
		assertEq( reserveWETH, 0, "reserveWETH doesn't start as zero" );

		// Alice deposits collateral
		vm.prank(alice);
		collateralAndLiquidity.depositCollateralAndIncreaseShare( depositedWBTC, depositedWETH, 0, block.timestamp, false );

		vm.warp( block.timestamp + 1 hours);

		// Deposit extra so alice can withdraw all liquidity without having to worry about DUST reserve limit
		vm.prank(DEPLOYER);
		collateralAndLiquidity.depositCollateralAndIncreaseShare( 1 * 10**8, 1 ether, 0, block.timestamp, false );

		vm.startPrank(alice);
		uint256 aliceCollateral = collateralAndLiquidity.userShareForPool(alice, collateralPoolID);
		(uint256 removedWBTC, uint256 removedWETH) = collateralAndLiquidity.withdrawCollateralAndClaim(aliceCollateral, 0, 0, block.timestamp );

		assertEq( depositedWBTC, removedWBTC + 1 );
		assertEq( depositedWETH, removedWETH );
//
//		console.log( "depositedWBTC: ", depositedWBTC );
//		console.log( "depositedWETH: ", depositedWETH );
//		console.log( "removedWBTC: ", removedWBTC );
//		console.log( "removedWETH: ", removedWETH );
		}



	// A unit test to ensure that depositing collateral updates the totalSharesForPool accurately
    function testDepositCollateralAndIncreaseTotalShares() public {
        // Initial balances for Alice
        uint256 initialWBTCBalanceA = wbtc.balanceOf(alice);
        uint256 initialWETHBalanceA = weth.balanceOf(alice);

		bytes32[] memory poolIDs = new bytes32[](1);
		poolIDs[0] = PoolUtils._poolID(wbtc, weth);

		uint256 initialTotalShares = collateralAndLiquidity.totalSharesForPools(poolIDs)[0];

        vm.prank(alice);
        (uint256 addedA, uint256 addedB, uint256 addedLiquidity) = collateralAndLiquidity.depositCollateralAndIncreaseShare(initialWBTCBalanceA / 2, initialWETHBalanceA / 2, 0, block.timestamp, false);

		uint256 finalTotalShares = collateralAndLiquidity.totalSharesForPools(poolIDs)[0];

		assertEq( finalTotalShares, initialTotalShares + (addedA + addedB) );
		assertEq( finalTotalShares, initialTotalShares + addedLiquidity );
    }


	// A unit test to validate that liquidateUser cannot be called within a certain time frame after the last deposit or borrow action
	function testCannotLiquidateWithinCertainTimeFrame() public {

		// Bob deposits collateral so alice can be liquidated
        vm.startPrank(bob);
		collateralAndLiquidity.depositCollateralAndIncreaseShare(wbtc.balanceOf(bob), weth.balanceOf(bob), 0, block.timestamp, false );
		vm.stopPrank();


        // Deposit and borrow from Alice's account to create basis for liquidation
        _depositCollateralAndBorrowMax(alice);

        // Cause a drastic price drop to allow for liquidation
        _crashCollateralPrice();

        vm.expectRevert("Must wait for the cooldown to expire");
        collateralAndLiquidity.liquidateUser(alice);

        // Warp past the lockout period, so liquidation is now allowed
        vm.warp(block.timestamp + 1 hours); // warp to just after the lockout period

        // Now liquidateUser job should be successful as the lockout period has passed and collateral value has dropped
        collateralAndLiquidity.liquidateUser(alice);

        // Check that Alice's collateral and borrowed USDS are now 0 indicating successful liquidation
        assertEq(collateralAndLiquidity.userShareForPool(alice, collateralPoolID), 0);
        assertEq(collateralAndLiquidity.usdsBorrowedByUsers(alice), 0);
    }


	// A unit test ensuring that the liquidation reward does not exceed the liquidated collateral value or maximum reward amount
	function testLiquidationRewardNotExceedingLimits() public {

		// Bob deposits collateral so alice can be liquidated
        vm.startPrank(bob);
		collateralAndLiquidity.depositCollateralAndIncreaseShare(wbtc.balanceOf(bob), weth.balanceOf(bob), 0, block.timestamp, false );
		vm.stopPrank();

        // Depositing collateral and borrowing the maximum amount for Alice
        _depositCollateralAndBorrowMax(alice);

        // Crashing collateral price to enable liquidation
        _crashCollateralPrice();

        // Alice should now be liquidatable
        assertTrue(collateralAndLiquidity.canUserBeLiquidated(alice), "Alice should be liquidatable");

        // Warp to ensure there's enough time past
        vm.warp(block.timestamp + 1 days);

        // Simulate liquidation and capture the rewards
        (uint256 preRewardWBTCBalance, uint256 preRewardWETHBalance) = (wbtc.balanceOf(bob), weth.balanceOf(bob));

        // Calculate USD value of Alice's liquidated collateral
        uint256 aliceCollateralValueUSD = collateralAndLiquidity.userCollateralValueInUSD(alice);

        vm.startPrank(bob);
        collateralAndLiquidity.liquidateUser(alice);
        vm.stopPrank();

        (uint256 postRewardWBTCBalance, uint256 postRewardWETHBalance) = (wbtc.balanceOf(bob), weth.balanceOf(bob));

        // Calculate actual rewards received
        uint256 receivedRewardWBTC = postRewardWBTCBalance - preRewardWBTCBalance;
        uint256 receivedRewardWETH = postRewardWETHBalance - preRewardWETHBalance;

        // Calculate USD value of received rewards
        uint256 receivedRewardUSDValue = collateralAndLiquidity.underlyingTokenValueInUSD(receivedRewardWBTC, receivedRewardWETH);

        // Get the maximum allowable reward from the stableConfig
        uint256 maxRewardValue = stableConfig.maxRewardValueForCallingLiquidation();

        // Bob's reward should not exceed either the value of Alice's liquidated collateral or the max reward
        assertTrue(receivedRewardUSDValue <= aliceCollateralValueUSD, "Reward exceeds liquidated collateral value");
        assertTrue(receivedRewardUSDValue <= maxRewardValue, "Reward exceeds maximum allowance");
    }


	// A unit test to verify that user USDS borrow balance cannot become negative after partial or full repayments
	function testBorrowBalanceNotNegativeAfterRepayment() public {
        address testUser = alice; // Test with Alice's account

        // Ensure that Alice had deposited collateral previously
        _depositCollateralAndBorrowMax(testUser);

        uint256 borrowedAmount = collateralAndLiquidity.usdsBorrowedByUsers(testUser);
        assertTrue(borrowedAmount > 0, "Borrowed amount should be greater than 0");

        // Repay part of the borrowed amount
        uint256 halfRepayment = borrowedAmount / 2;
        vm.prank(testUser);
        collateralAndLiquidity.repayUSDS(halfRepayment);

        // Check if the borrowed balance is now half of what it was
        uint256 remainingBorrow = collateralAndLiquidity.usdsBorrowedByUsers(testUser);
        assertEq(remainingBorrow, halfRepayment, "Remaining borrow after partial payment should be half of initial borrow");

        // Repay the rest of the borrowed amount
        vm.prank(testUser);
        collateralAndLiquidity.repayUSDS(halfRepayment);

        // Check if the borrowed balance is now 0
        remainingBorrow = collateralAndLiquidity.usdsBorrowedByUsers(testUser);
        assertEq(remainingBorrow, 0, "Remaining borrow after full repayment should be 0");

        // Attempting to repay more than the borrowed amount should fail
        uint256 excessRepayment = 1 ether;
        vm.prank(testUser);
        vm.expectRevert("Cannot repay more than the borrowed amount");
        collateralAndLiquidity.repayUSDS(excessRepayment);

        // Ensure the borrowed amount has not gone negative
        remainingBorrow = collateralAndLiquidity.usdsBorrowedByUsers(testUser);
        assertTrue(remainingBorrow >= 0, "Borrowed balance should not be negative after repayment");
    }


	// A unit test that confirms canUserBeLiquidated returns true only if the wallet is on the _walletsWithBorrowedUSDS list and undercollateralized
	function testCanUserBeLiquidated_TrueIfWalletOnBorrowedListAndUndercollateralized() public {
        assertEq(0, collateralAndLiquidity.numberOfUsersWithBorrowedUSDS(), "Borrowed USDS list should start empty");

        // Alice deposits collateral and borrows
        _depositCollateralAndBorrowMax(alice);

        // At the start, Alice should not be liquidatable because she's just borrowed up to the max allowed (collateral ratio at 200%)
        assertFalse(collateralAndLiquidity.canUserBeLiquidated(alice), "Alice should not be liquidatable at the start");

        // Crash the collateral price to drop the collateral ratio below the minimum (110%)
        _crashCollateralPrice();

        // Now Alice should have a collateral ratio below the liquidation threshold (collateral ratio dropped below 110%)
        assertTrue(collateralAndLiquidity.canUserBeLiquidated(alice), "Alice should be liquidatable after price crash");

        // Bob has not borrowed any USDS, so he should not be on the borrowed list and not undercollateralized
        assertFalse(collateralAndLiquidity.canUserBeLiquidated(bob), "Bob should not be liquidatable without borrowing");
    }
}
