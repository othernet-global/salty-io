// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.12;

import "forge-std/Test.sol";
import "../../Deployment.sol";
import "../../root_tests/TestERC20.sol";
import "../Collateral.sol";
import "../../ExchangeConfig.sol";
import "../../pools/Pools.sol";
import "../../staking/Staking.sol";
import "../../rewards/RewardsEmitter.sol";
import "./IForcedPriceFeed.sol";


contract TestCollateral is Test, Deployment
	{
	// User wallets for testing
    address public constant alice = address(0x1111);
    address public constant bob = address(0x2222);
    address public constant charlie = address(0x3333);

	bytes32 public collateralPoolID;
	bool public collateralIsFlipped;


	constructor()
		{
		// If $COVERAGE=yes, create an instance of the contract so that coverage testing can work
		// Otherwise, what is tested is the actual deployed contract on the blockchain (as specified in Deployment.sol)
		if ( keccak256(bytes(vm.envString("COVERAGE" ))) == keccak256(bytes("yes" )))
			{
			vm.startPrank(DEPLOYER);

			// Because USDS already set the Collateral on deployment and it can only be done once, we have to recreate USDS as well
			// That cascades into recreating multiple other contracts as well.
			usds = new USDS( stableConfig, wbtc, weth );

			IDAO dao = IDAO(getContract( address(exchangeConfig), "dao()" ));

			exchangeConfig = new ExchangeConfig(salt, wbtc, weth, usdc, usds );
			pools = new Pools( exchangeConfig );

			staking = new Staking( exchangeConfig, poolsConfig, stakingConfig );
			liquidity = new Liquidity( pools, exchangeConfig, poolsConfig, stakingConfig );
			collateral = new Collateral(pools, wbtc, weth, exchangeConfig, poolsConfig, stakingConfig, stableConfig);

			stakingRewardsEmitter = new RewardsEmitter( staking, exchangeConfig, poolsConfig, stakingConfig, rewardsConfig );
			liquidityRewardsEmitter = new RewardsEmitter( liquidity, exchangeConfig, poolsConfig, stakingConfig, rewardsConfig );

			emissions = new Emissions( staking, stakingRewardsEmitter, liquidityRewardsEmitter, exchangeConfig, poolsConfig, stakingConfig, rewardsConfig );

			exchangeConfig.setDAO( dao );
			exchangeConfig.setAccessManager( accessManager );
			usds.setPools( pools );
			usds.setCollateral( collateral );

			vm.stopPrank();
			}

		(collateralPoolID,collateralIsFlipped) = PoolUtils.poolID( wbtc, weth );

		// Mint some USDS to the DEPLOYER
		vm.prank( address(collateral) );
		usds.mintTo( DEPLOYER, 2000000 ether );
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
		IForcedPriceFeed _forcedPriceFeed = IForcedPriceFeed(address(priceFeed));

		vm.startPrank( DEPLOYER );
		_forcedPriceFeed.setBTCPrice( _forcedPriceFeed.getPriceBTC() * 54 / 100);
		_forcedPriceFeed.setETHPrice( _forcedPriceFeed.getPriceETH() * 54 / 100 );
		vm.stopPrank();
		}


	// A unit test that verifies the liquidateUser function correctly transfers WETH to the liquidator and WBTC/WETH to the USDS contract
	function testLiquidatePosition() public {
		assertEq(wbtc.balanceOf(address(usds)), 0, "USDS contract should start with zero WBTC");
		assertEq(weth.balanceOf(address(usds)), 0, "USDS contract should start with zero WETH");
		assertEq(usds.balanceOf(alice), 0, "Alice should start with zero USDS");

		uint256 aliceStartingWBTC = wbtc.balanceOf( alice );
		uint256 aliceStartingWETH = weth.balanceOf( alice );

		// Alice will deposit all her collateral and borrowed max USDS
		_depositCollateralAndBorrowMax(alice);

		uint256 aliceCollateralShare = collateral.userShareInfoForPool( alice, collateralPoolID ).userShare;
		uint256 aliceCollateralValue = collateral.collateralValue( aliceCollateralShare );

		assertEq(wbtc.balanceOf(address(alice)), 0, "Collateral contract should have all of Alice's collateral");
		assertEq(weth.balanceOf(address(alice)), 0, "Collateral contract should have all of Alice's collateral");

		uint256 aliceBorrowedUSDS = usds.balanceOf(alice);
		assertEq( collateral.usersBorrowedUSDS(alice), aliceBorrowedUSDS, "Alice amount USDS borrowed not what she has" );

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

		// Verify that Alice's position has been liquidated
		assertEq( collateral.userShareInfoForPool(alice, collateralPoolID).userShare, 0 );
        assertEq( collateral.usersBorrowedUSDS(alice), 0 );

		// Verify that Bob has received WETH for the liquidation
		uint256 bobExpectedReward = aliceStartingWETH * 10 / 100;
		assertEq(weth.balanceOf(bob), bobStartingWETH + bobExpectedReward , "Bob should have received WETH for liquidating Alice");

		// Verify that USDS received the WBTC and WETH form Alice's liquidated collateral
		assertEq(wbtc.balanceOf(address(usds)), aliceStartingWBTC, "The USDS contract should have received Alice's WBTC");
		assertEq(weth.balanceOf(address(usds)), aliceStartingWETH - bobExpectedReward, "The USDS contract should have received Alice's WETH - Bob's WETH reward");
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


//   	// A unit test that checks the liquidateUser function for proper calculation and burning of the borrowed amount, and when the caller tries to liquidate their own position.
//	function testLiquidateSelf() public {
//
//		uint256 initialSupplyUSDS = IERC20(address(usds)).totalSupply();
//
//        _depositCollateralAndBorrowMax(alice);
//
//		assertTrue( initialSupplyUSDS < IERC20(address(usds)).totalSupply(), "Supply after borrow should be higher" );
//
//        CollateralPosition memory positionBefore = userPosition(alice);
//        assertEq(positionBefore.wallet, alice);
//        assertTrue(positionBefore.lpCollateralAmount > 0 ether);
//        assertTrue(positionBefore.usdsBorrowedAmount > 0 ether);
//        assert(!positionBefore.liquidated);
//
//        _crashCollateralPrice();
//
//		// Warp past the sharedRewards cooldown
//		vm.warp( block.timestamp + 1 days );
//
//        // Attempting to liquidate own position should revert
//        vm.prank(alice);
//        vm.expectRevert( "Cannot liquidate self" );
//        collateral.liquidateUser(userPositionIDs[alice]);
//
//        // Proper liquidation by another account
//        vm.prank(bob);
//        collateral.liquidateUser(userPositionIDs[alice]);
//
//		assertFalse( collateral.userHasPosition(alice) );
//    }
//
//
//	// A unit test where a user is liquidated and then adds another position which is then liquidated as well
//	function testUserLiquidationTwice() public {
//        // Deposit and borrow for Alice
//        _depositHalfCollateralAndBorrowMax(alice);
//
//        // Check if Alice has a position
//        assertTrue(userHasPosition(alice));
//
//        // Crash the collateral price
//        _crashCollateralPrice();
//        vm.warp( block.timestamp + 1 days );
//
//        // Alice's position should now be under-collateralized and ready for liquidation
//        // The id of alice's position should be 1 as she is the first one to open a position
//        uint256 alicePositionId = userPositionIDs[alice];
//
//        // Liquidate Alice's position
//        collateral.liquidateUser(alicePositionId);
//
//        // Check if Alice's position was liquidated
//        assertFalse(userHasPosition(alice));
//
//        vm.warp( block.timestamp + 1 days );
//
//        // Deposit and borrow again for Alice
//        _depositHalfCollateralAndBorrowMax(alice);
//
//        // Check if Alice has a new position
//        assertTrue(userHasPosition(alice));
//
//        // Crash the collateral price again
//        _crashCollateralPrice();
//        vm.warp( block.timestamp + 1 days );
//
//        // Alice's position should now be under-collateralized and ready for liquidation again
//        // The id of alice's position should now be 2 as she opened a new position
//        alicePositionId = userPositionIDs[alice];
//
//        // Liquidate Alice's position again
//        collateral.liquidateUser(alicePositionId);
//
//        // Check if Alice's position was liquidated again
//        assertFalse(userHasPosition(alice));
//    }
//
//
//
//	// A unit test where a user deposits, borrows, deposits and is then liquidated
//	function testUserDepositBorrowDepositAndLiquidate() public {
//        // User Alice deposits collateral
//        uint256 aliceCollateralBalance = collateralLP.balanceOf(alice) / 2;
//        vm.prank( alice );
//		collateral.depositCollateral( aliceCollateralBalance );
//
//        // Alice borrows USDS
//        uint256 maxBorrowable = collateral.maxBorrowableUSDS(alice);
//        vm.prank( alice );
//        collateral.borrowUSDS( maxBorrowable );
//
//        // Alice deposits more collateral - but fails due to the cooldown
//        aliceCollateralBalance = collateralLP.balanceOf(alice) / 2;
//
//        vm.expectRevert( "Must wait for the cooldown to expire" );
//        vm.prank( alice );
//		collateral.depositCollateral( aliceCollateralBalance );
//
//		vm.warp( block.timestamp + 1 days );
//
//		// Try depositing again
//        aliceCollateralBalance = collateralLP.balanceOf(alice) / 2;
//        vm.prank( alice );
//		collateral.depositCollateral( aliceCollateralBalance );
//
//        // Alice's position after second deposit
//        CollateralPosition memory position = collateral.userPosition(alice);
//
//        // Crash the collateral price so Alice's position can be liquidated
//        _crashCollateralPrice();
//        _crashCollateralPrice();
//		vm.warp( block.timestamp + 1 days );
//
//        // Liquidate Alice's position
//        collateral.liquidateUser(position.positionID);
//
//        // Alice's position should be liquidated
//        try collateral.userPosition(alice) {
//            fail("Alice's position should have been liquidated");
//        } catch Error(string memory reason) {
//            assertEq(reason, "User does not have a collateral position", "Error message mismatch");
//        }
//    }
//
//
//	// A unit test that verifies the userCollateralValueInUSD and underlyingTokenValueInUSD function with different collateral amounts and different token prices, including when the user does not have a position.
//	function testUserCollateralValueInUSD() public
//    	{
//    	// Determine how many BTC and ETH alice has in colalteral
//    	uint256 aliceCollateral = collateralLP.balanceOf(alice);
//
//    	_depositCollateralAndBorrowMax(alice);
//
//		(uint112 reserve0, uint112 reserve1,) = collateralLP.getReserves();
//		uint256 totalLP = collateralLP.totalSupply();
//
//		uint256 aliceBTC = ( reserve0 * aliceCollateral ) / totalLP;
//		uint256 aliceETH = ( reserve1 * aliceCollateral ) / totalLP;
//
//		if ( collateralIsFlipped )
//			(aliceETH,aliceBTC) = (aliceBTC,aliceETH);
//
//		vm.startPrank( DEPLOYER );
//		_forcedPriceFeed.setBTCPrice( 20000 ether );
//		_forcedPriceFeed.setETHPrice( 2000 ether );
//		vm.stopPrank();
//
//        uint256 aliceCollateralValue0 = collateral.userCollateralValueInUSD(alice);
//        uint256 aliceCollateralValue = aliceBTC * 20000 * 10 ** 18 / 10 ** 8 + aliceETH * 2000;
//		assertEq( aliceCollateralValue0, aliceCollateralValue, "Collateral value different than expected" );
//
////
////		vm.startPrank( DEPLOYER );
////		_forcedPriceFeed.setBTCPrice( 15000 ether );
////		_forcedPriceFeed.setETHPrice( 1777 ether );
////		vm.stopPrank();
////
////        aliceCollateralValue0 = collateral.userCollateralValueInUSD(alice);
////        aliceCollateralValue = aliceBTC * 15000 + aliceETH * 1777;
////		assertEq( aliceCollateralValue0, aliceCollateralValue, "Collateral value different than expected" );
////
////
////		vm.startPrank( DEPLOYER );
////		_forcedPriceFeed.setBTCPrice( 45000 ether );
////		_forcedPriceFeed.setETHPrice( 11777 ether );
////		vm.stopPrank();
////
////        aliceCollateralValue0 = collateral.userCollateralValueInUSD(alice);
////        aliceCollateralValue = aliceBTC * 45000 + aliceETH * 11777;
////		assertEq( aliceCollateralValue0, aliceCollateralValue, "Collateral value different than expected" );
////
////		assertEq( collateral.userCollateralValueInUSD(DEPLOYER), 0, "Non-existent collateral value should be zero" );
//    	}
//
//
//
//
//	// A unit test that verifies the findLiquidatablePositions function returns an empty array when there are no liquidatable positions and checks it for a range of indices.
//	function testFindLiquidatablePositions_noLiquidatablePositions() public {
//		// Alice, Bob, and Charlie deposit collateral and borrow within the limit
//		_depositHalfCollateralAndBorrowMax(alice);
//		_depositHalfCollateralAndBorrowMax(bob);
//		_depositHalfCollateralAndBorrowMax(charlie);
//
//		uint256[] memory liquidatablePositions = collateral.findLiquidatablePositions();
//        assertEq(liquidatablePositions.length, 0, "No liquidatable positions should be found");
//    }
//
//
//	// A unit test to ensure that the borrowUSDS function updates the _openPositionIDs mapping correctly, and that the _openPositionIDs mapping is also updated properly after liquidation.
//	function testBorrowUSDSAndLiquidation() public {
//        // Deposit collateral
//        vm.startPrank(alice);
//        collateral.depositCollateral( collateralLP.balanceOf(alice) / 2 );
//        vm.stopPrank();
//
//        // Check that position is opened for Alice
//        assertEq(userPositionIDs[alice], _nextPositionID - 1);
//
//        // Borrow USDS
//        uint256 borrowedAmount = collateral.maxBorrowableUSDS(alice); // Assuming collateral is within max borrowable
//        vm.startPrank(alice);
//        collateral.borrowUSDS(borrowedAmount);
//        vm.stopPrank();
//
//        // Check that Alice's borrowed amount increased
//        CollateralPosition memory position = userPosition(alice);
//        assertEq(position.usdsBorrowedAmount, borrowedAmount);
//
//        // Confirm that position is open
//        assertTrue( collateral.positionIsOpen(position.positionID));
//
//        // Crash collateral price to enable liquidation
//        _crashCollateralPrice();
//		vm.warp( block.timestamp + 1 days );
//
//        // Liquidate position
//        collateral.liquidateUser(position.positionID);
//
//        // Confirm that position is removed from _openPositionIDs
//        assertFalse( collateral.positionIsOpen(position.positionID));
//    }
//
//
//
//	// A unit test for numberOfOpenPositions to verify that it returns the correct number of open positions.
//	function testNumberOfOpenPositions() public {
//        // Alice, Bob and Charlie each deposit and borrow
//        _depositCollateralAndBorrowMax(alice);
//        _depositCollateralAndBorrowMax(bob);
//        _depositCollateralAndBorrowMax(charlie);
//
//    	vm.warp( block.timestamp + 1 days );
//
//        // Check numberOfOpenPositions returns correct number of open positions
//        assertEq( numberOfOpenPositions(), 3);
//
//        // Alice repays loan, reducing number of open positions
//        uint256 aliceBorrowedAmount = usds.balanceOf(alice);
//
//        usds.mintTo(alice, aliceBorrowedAmount);
//        vm.startPrank(alice);
//        collateral.repayUSDS(aliceBorrowedAmount / 2 );
//        vm.stopPrank();
//
//        // Check numberOfOpenPositions returns correct number of open positions
//        assertEq( numberOfOpenPositions() , 3);
//
//		vm.startPrank(alice);
//		collateral.repayUSDS(aliceBorrowedAmount - aliceBorrowedAmount / 2);
//		vm.stopPrank();
//
//        assertEq( numberOfOpenPositions() , 2);
//
//        // _crashCollateralPrice to force liquidation of a position
//        _crashCollateralPrice();
//
//        // Check liquidation of Bob's position
//        uint256 bobPositionID = userPositionIDs[bob];
//        collateral.liquidateUser(bobPositionID);
//
//        // Check numberOfOpenPositions returns correct number of open positions
//        assertEq( numberOfOpenPositions(), 1);
//    }
//
//
//	// A unit test for totalCollateralValueInUSD to verify that it correctly calculates the total value of all collateral.
//	    // Here's a unit test for the `totalCollateralValueInUSD` function
//        function testTotalCollateralValueInUSD() public {
//
//            // Initial deposit for Alice, Bob and Charlie
//            _depositCollateralAndBorrowMax(alice);
//            _depositCollateralAndBorrowMax(bob);
//            _depositCollateralAndBorrowMax(charlie);
//
//            // Get total collateral value before crash
//            uint256 totalCollateral = collateral.totalCollateralValueInUSD();
//			uint256 aliceCollateralValue = collateral.userCollateralValueInUSD(alice);
//
////			console.log( "totalCollateral: ", totalCollateral );
////			console.log( "aliceCollateralValue: ", aliceCollateralValue );
//
//			// The original collateralLP was divided amounts 4 wallets - one of which was alice
//			// ALlow slight variation in quoted price
//			bool isValid = totalCollateral > (aliceCollateralValue * 4 * 99 / 100);
//			isValid = isValid && (totalCollateral < (aliceCollateralValue * 4 * 101 / 100 ));
//
//			assertTrue( isValid, "Total collateral does not reflect the correct value" );
//        }
//
//
//
//	// A unit test that verifies that collateralValue correctly calculates the collateral value for given LP amounts.
//	function testUserCollateralValueInUSD2() public {
//
//		uint256 aliceCollateral = collateralLP.balanceOf(alice);
//
//		(uint112 reserve0, uint112 reserve1,) = collateralLP.getReserves();
//		uint256 totalLP = collateralLP.totalSupply();
//
//		uint256 aliceBTC = ( reserve0 * aliceCollateral ) / totalLP;
//		uint256 aliceETH = ( reserve1 * aliceCollateral ) / totalLP;
//
//		// Prices from the price feed have 18 decimals
//		IPriceFeed priceFeed = stableConfig.priceFeed();
//		uint256 btcPrice = priceFeed.getPriceBTC();
//        uint256 ethPrice = priceFeed.getPriceETH();
//
//		// Keep the 18 decimals from the price and remove the decimals from the amount held by the user
//		uint256 btcValue = ( aliceBTC * btcPrice ) / (10 ** btcDecimals );
//		uint256 ethValue = ( aliceETH * ethPrice ) / (10 ** wethDecimals );
//
//		uint256 manualColletaralValue = btcValue + ethValue;
//
//
//		_depositCollateralAndBorrowMax(alice);
//
//    	uint256 actualCollateralValue = collateral.userCollateralValueInUSD(alice);
//
//		assertEq( manualColletaralValue, actualCollateralValue, "Calculated and actual collateral values are not the same" );
//    }
//
//
//	// A unit test to verify that the collateralIsFlipped boolean value is correctly set in the constructor based on the LP tokens provided.
//	function testCollateralIsFlipped() public {
//       	// Create two LP tokens with different order of tokens
//        IUniswapV2Pair collateralLP1;
//        while( true )
//        	{
//        	// Keep creating BTC/ETH pairs until BTC is symbol0
//        	ERC20 a = new ERC20( "WBTC", "WBTC" );
//			ERC20 b = new ERC20( "WETH", "WETH" );
//
//			collateralLP1 = IUniswapV2Pair( _factory.createPair( address(a), address(b) ) );
//			if ( address(collateralLP1.token0()) == address(a) )
//	        	break;
//        	}
//
//        IUniswapV2Pair collateralLP2;
//		while( true )
//			{
//			// Keep creating BTC/ETH pairs until BTC is symbol0
//			ERC20 a = new ERC20( "WETH", "WETH" );
//			ERC20 b = new ERC20( "WBTC", "WBTC" );
//
//			collateralLP2 = IUniswapV2Pair( _factory.createPair( address(a), address(b) ) );
//			if ( address(collateralLP2.token0()) == address(a) )
//				break;
//			}
//
//		// Create two Collateral contracts with different LP tokens
//		Collateral collateral1 = new Collateral(collateralLP1, usds, _stableConfig, _stakingConfig, _exchangeConfig);
//		Collateral collateral2 = new Collateral(collateralLP2, usds, _stableConfig, _stakingConfig, _exchangeConfig);
//
//		// Collateral1 should have collateralIsFlipped as false since WBTC is token0 and WETH is token1
//		assertFalse(collateral1.collateralIsFlipped() );
//
//		// Collateral2 should have collateralIsFlipped as true since WETH is token0 and WBTC is token1
//		assertTrue(collateral2.collateralIsFlipped() );
//    }
//
//
//	// A unit test that checks the deposit and withdrawal of collateral with various amounts, ensuring that an account cannot withdraw collateral that they do not possess.
//	function testDepositAndWithdrawCollateral() public
//    {
//    	// Setup
//    	vm.startPrank(alice);
//
//    	uint256 aliceCollateralAmount = _collateralLP.balanceOf(alice);
//    	uint256 depositAmount = aliceCollateralAmount / 2;
//
//    	// Alice deposits half of her collateral
//    	collateral.depositCollateral(depositAmount);
//
//    	// Verify the result
//    	assertEq(_collateralLP.balanceOf(address(collateral)), depositAmount);
//    	assertEq(collateral.userPosition(alice).lpCollateralAmount, depositAmount);
//
//		vm.warp( block.timestamp + 1 days );
//
//    	// Alice tries to withdraw more collateral than she has in the contract
//    	vm.expectRevert( "Excessive amountWithdrawn" );
//    	collateral.withdrawCollateralAndClaim( depositAmount + 1 );
//
//		vm.warp( block.timestamp + 1 days );
//
//    	// Alice withdraws half the collateral
//    	collateral.withdrawCollateralAndClaim(depositAmount / 2);
//
//		vm.warp( block.timestamp + 1 days );
//
//		// Withdraw too much
//    	vm.expectRevert( "Excessive amountWithdrawn" );
//    	collateral.withdrawCollateralAndClaim(depositAmount / 2 + 1);
//
//		// Withdraw the rest
//    	collateral.withdrawCollateralAndClaim(depositAmount / 2);
//
//		vm.warp( block.timestamp + 1 days );
//
//    	// Verify the result
//    	assertEq(_collateralLP.balanceOf(address(collateral)), 0);
//    	assertEq(collateral.userPosition(alice).lpCollateralAmount, 0);
//    }
//
//
//	// A unit test to verify that an account cannot borrow USDS more than their max borrowable limit and cannot repay USDS if they don't have a position.
//	function testCannotBorrowMoreThanMaxBorrowableLimit() public {
//        vm.startPrank(alice);
//
//        uint256 initialAmount = collateralLP.balanceOf(alice);
//        collateral.depositCollateral(initialAmount);
//
//        uint256 maxBorrowableAmount = collateral.maxBorrowableUSDS(alice);
//        vm.expectRevert( "Excessive amountBorrowed" );
//        collateral.borrowUSDS(maxBorrowableAmount + 1 ether);
//
//        vm.stopPrank();
//	    }
//
//
//    function testCannotRepayUSDSWithoutPosition() public {
//        vm.startPrank(bob);
//        vm.expectRevert( "User does not have an existing position" );
//        collateral.repayUSDS(1 ether);
//        vm.stopPrank();
//    }
//
//
//
//	// A unit test that verifies the userPosition function and userHasPosition function for accounts with and without positions.
//	function testUserPositionFunctions() public {
//        // Initially, Alice, Bob and Charlie should not have positions
//        assertTrue(!collateral.userHasPosition(alice));
//        assertTrue(!collateral.userHasPosition(bob));
//        assertTrue(!collateral.userHasPosition(charlie));
//
//        // After Alice deposits collateral and borrows max, she should have a position
//        _depositCollateralAndBorrowMax(alice);
//        assertTrue(collateral.userHasPosition(alice));
//
//        CollateralPosition memory alicePosition = collateral.userPosition(alice);
//        assertEq(alicePosition.wallet, alice);
//        assertTrue(alicePosition.lpCollateralAmount > 0);
//        assertTrue(alicePosition.usdsBorrowedAmount > 0);
//        assertTrue(!alicePosition.liquidated);
//
//        // Still, Bob and Charlie should not have positions
//        assertTrue(!collateral.userHasPosition(bob));
//        assertTrue(!collateral.userHasPosition(charlie));
//
//        // After Bob deposits collateral and borrows max, he should have a position
//        _depositCollateralAndBorrowMax(bob);
//        assertTrue(collateral.userHasPosition(bob));
//
//        CollateralPosition memory bobPosition = collateral.userPosition(bob);
//        assertEq(bobPosition.wallet, bob);
//        assertTrue(bobPosition.lpCollateralAmount > 0);
//        assertTrue(bobPosition.usdsBorrowedAmount > 0);
//        assertTrue(!bobPosition.liquidated);
//
//        // Finally, Charlie still should not have a position
//        assertTrue(!collateral.userHasPosition(charlie));
//    }
//
//
//	// A unit test that validates maxWithdrawableLP and maxBorrowableUSDS functions with scenarios including accounts without positions and accounts with positions whose collateral value is less than the minimum required to borrow USDS.
//	function testMaxWithdrawableLP_and_maxBorrowableUSDS() public {
//        address randomUser = address(0x4444);
//        address nonPositionUser = address(0x5555);
//
//        // Scenario where account has a position but collateral value is less than the minimum required to borrow USDS
//        _depositCollateralAndBorrowMax(alice);
//
//        uint256 maxWithdrawableLPForAlice = collateral.maxWithdrawableLP(alice);
//        uint256 maxBorrowableUSDSForAlice = collateral.maxBorrowableUSDS(alice);
//
//        assertTrue(maxWithdrawableLPForAlice == 0, "Max withdrawable LP should be zero");
//        assertTrue(maxBorrowableUSDSForAlice == 0, "Max borrowable USDS should be zero");
//
//        // Scenario where account does not have a position
//        uint256 maxWithdrawableLPForNonPositionUser = collateral.maxWithdrawableLP(nonPositionUser);
//        uint256 maxBorrowableUSDSForNonPositionUser = collateral.maxBorrowableUSDS(nonPositionUser);
//
//        assertTrue(maxWithdrawableLPForNonPositionUser == 0, "Max withdrawable LP for user without position should be zero");
//        assertTrue(maxBorrowableUSDSForNonPositionUser == 0, "Max borrowable USDS for user without position should be zero");
//
//        // Scenario where a random user tries to borrow and withdraw
//        vm.startPrank(randomUser);
//        collateralLP.approve( address(collateral), type(uint256).max );
//
//        try collateral.depositCollateral(100 ether) {
//            fail("depositCollateral should have failed for random user");
//        } catch {
//            assertEq(collateral.userCollateralValueInUSD(randomUser), 0);
//        }
//        try collateral.borrowUSDS(100 ether) {
//            fail("borrowUSDS should have failed for random user");
//        } catch {
//            assertEq(collateral.userCollateralValueInUSD(randomUser), 0);
//        }
//        vm.stopPrank();
//    }
//
//
//	// A unit test that verifies the accuracy of the findLiquidatablePositions function in more complex scenarios. This could include scenarios where multiple positions should be liquidated at once, or where no positions should be liquidated despite several being close to the threshold.
//	function testFindLiquidatablePositions() public {
//        _depositCollateralAndBorrowMax(alice);
//        _depositCollateralAndBorrowMax(bob);
//        _depositCollateralAndBorrowMax(charlie);
//
//		_crashCollateralPrice();
//
//		vm.warp( block.timestamp + 1 days );
//
//        // All three positions should be liquidatable.
//        assertEq(collateral.findLiquidatablePositions().length, 3);
//
//		CollateralPosition memory position = userPosition(alice);
//		vm.prank(alice);
//		collateral.repayUSDS( position.usdsBorrowedAmount );
//
////        // Now only two positions should be liquidatable.
////        assertEq(collateral.findLiquidatablePositions().length, 2);
////
////        // Let's liquidate one of the positions.
////        collateral.liquidateUser(userPositionIDs[bob]);
////
////        // Now only one position should be liquidatable.
////        assertEq(collateral.findLiquidatablePositions().length, 1);
////
////        // Charlie also repays all his debt.
////		position = userPosition(charlie);
////		vm.prank(charlie);
////		collateral.repayUSDS( position.usdsBorrowedAmount );
////
////        // Now no positions should be liquidatable.
////        assertEq(collateral.findLiquidatablePositions().length, 0);
//    }
//
//
//	// A unit test to verify the accuracy of userCollateralValueInUSD when there are multiple positions opened by a single user.
//	function testUserCollateralValueInUSD_multiplePositions() public {
//
//		uint256 collateralAmount0 = collateralLP.balanceOf(alice);
//		uint256 collateralAmount = collateralAmount0 / 10;
//		uint256 collateralValue0 = collateral.collateralValue( collateralAmount0);
//
//        // User Alice opens the first position
//        vm.startPrank(alice);
//        collateral.depositCollateral(collateralAmount);
//        vm.warp( block.timestamp + 1 days );
//
//        collateral.depositCollateral(collateralAmount * 2);
//        vm.warp( block.timestamp + 1 days );
//
//        collateral.depositCollateral(collateralAmount0 - collateralAmount * 3);
//        vm.warp( block.timestamp + 1 days );
//
//		assertEq( collateralLP.balanceOf(alice), 0, "Alice should have zero collateral" );
//
//        // check the collateral value
//        uint256 aliceCollateralValue = collateral.userCollateralValueInUSD(alice);
//        assertEq(aliceCollateralValue, collateralValue0, "The total collateral value is incorrect");
//    }
//
//	// A unit test that ensures correct behavior when BTC/ETH prices drop by more than 50% and the collateral positions are underwater.
//	function testUnderwaterPosition() public
//    {
//        // Setup
//        _depositCollateralAndBorrowMax(alice);  // Assume the function correctly initializes a max leveraged position
//        _depositCollateralAndBorrowMax(bob);
//        _depositCollateralAndBorrowMax(charlie);
//
//        // Simulate a 50% price drop for both BTC and ETH
//        _crashCollateralPrice();
//
//        // Simulate another 50% price drop for both BTC and ETH
//        _crashCollateralPrice();
//
//        vm.warp( block.timestamp + 1 days );
//
//        // Alice, Bob and Charlie's positions should now be underwater
//        // Check if liquidation is possible
//        CollateralPosition memory alicePosition = collateral.userPosition(alice);
//        CollateralPosition memory bobPosition = collateral.userPosition(bob);
//        CollateralPosition memory charliePosition = collateral.userPosition(charlie);
//
//        uint256 aliceCollateralValue = collateral.userCollateralValueInUSD(alice);
//        uint256 aliceCollateralRatio = (aliceCollateralValue * 100) / alicePosition.usdsBorrowedAmount;
//        assertTrue(aliceCollateralRatio < stableConfig.minimumCollateralRatioPercent());
//
//        uint256 bobCollateralValue = collateral.userCollateralValueInUSD(bob);
//        uint256 bobCollateralRatio = (bobCollateralValue * 100) / bobPosition.usdsBorrowedAmount;
//        assertTrue(bobCollateralRatio < stableConfig.minimumCollateralRatioPercent());
//
//        uint256 charlieCollateralValue = collateral.userCollateralValueInUSD(charlie);
//        uint256 charlieCollateralRatio = (charlieCollateralValue * 100) / charliePosition.usdsBorrowedAmount;
//        assertTrue(charlieCollateralRatio < stableConfig.minimumCollateralRatioPercent());
//
//        // Attempt to liquidate the positions
//        vm.startPrank( DEPLOYER );
//        collateral.liquidateUser(alicePosition.positionID);
//        collateral.liquidateUser(bobPosition.positionID);
//        collateral.liquidateUser(charliePosition.positionID);
//		vm.stopPrank();
//
//        // Verify that liquidation was successful
//        assertFalse(collateral.userHasPosition(alice));
//        assertFalse(collateral.userHasPosition(bob));
//        assertFalse(collateral.userHasPosition(charlie));
//    }
//
//	// A unit test that makes sure that borrowing max USDS and then borrowing 1 USDS more fails
//	function testBorrowMaxPlusOneUSDS() public {
//        _depositCollateralAndBorrowMax(alice);
//
//        // Now we try to borrow 1 USDS more which should fail
//        vm.startPrank(alice);
//        vm.expectRevert("Excessive amountBorrowed" );
//        collateral.borrowUSDS(1);
//        vm.stopPrank();
//    }
//
//
//	// A unit test that checks that partial repayment of borrowed USDS adjust accounting correctly as does full repayment.
//	function testRepaymentAdjustsAccountingCorrectly() public {
//
//		_depositCollateralAndBorrowMax(alice);
//
//        // Save initial position
//        CollateralPosition memory initialPosition = collateral.userPosition(alice);
//
//        // Alice repays half of her borrowed amount
//        vm.startPrank(alice);
//
//        // Make sure cannot repay too much
//        vm.expectRevert( "Cannot repay more than the borrowed amount" );
//        collateral.repayUSDS(initialPosition.usdsBorrowedAmount * 2);
//
//        // Repay half
//        collateral.repayUSDS(initialPosition.usdsBorrowedAmount / 2);
//        vm.stopPrank();
//
//        // Check position after partial repayment
//        CollateralPosition memory partialRepaymentPosition = collateral.userPosition(alice);
//
//        // Renmove the least significant digit to remove rounding issues
//        assertEq(partialRepaymentPosition.usdsBorrowedAmount / 10, initialPosition.usdsBorrowedAmount / 2 / 10);
//
//        // Alice repays the rest of her borrowed amount
//        vm.startPrank(alice);
//        collateral.repayUSDS(partialRepaymentPosition.usdsBorrowedAmount);
//        vm.stopPrank();
//
//        // Check position after full repayment
//        // User no longer has a position
//        vm.expectRevert( "User does not have a collateral position" );
//        collateral.userPosition(alice);
//
//        assertFalse( collateral.userHasPosition(alice) );
//    }
//
//
//	function check( uint256 shareA, uint256 shareB, uint256 shareC, uint256 rA, uint256 rB, uint256 rC, uint256 vA, uint256 vB, uint256 vC, uint256 sA, uint256 sB, uint256 sC ) public
//		{
//		assertEq( collateral.userShareInfoForPool(alice, collateralLP).userShare, shareA, "Share A incorrect" );
//		assertEq( collateral.userShareInfoForPool(bob, collateralLP).userShare, shareB, "Share B incorrect" );
//		assertEq( collateral.userShareInfoForPool(charlie, collateralLP).userShare, shareC, "Share C incorrect" );
//
//		assertEq( collateral.userPendingReward( alice, collateralLP ), rA, "Incorrect pending rewards A" );
//        assertEq( collateral.userPendingReward( bob, collateralLP ), rB, "Incorrect pending rewards B" );
//        assertEq( collateral.userPendingReward( charlie, collateralLP ), rC, "Incorrect pending rewards C" );
//
//		assertEq( collateral.userShareInfoForPool(alice, collateralLP).virtualRewards, vA, "Virtual A incorrect" );
//		assertEq( collateral.userShareInfoForPool(bob, collateralLP).virtualRewards, vB, "Virtual B incorrect" );
//		assertEq( collateral.userShareInfoForPool(charlie, collateralLP).virtualRewards, vC, "Virtual C incorrect" );
//
//		assertEq( collateral.userShareInfoForPool(alice, collateralLP).userShare, shareA, "Share A incorrect" );
//		assertEq( collateral.userShareInfoForPool(bob, collateralLP).userShare, shareB, "Share B incorrect" );
//		assertEq( collateral.userShareInfoForPool(charlie, collateralLP).userShare, shareC, "Share C incorrect" );
//
//		assertEq( salt.balanceOf(alice), sA, "SALT A incorrect" );
//		assertEq( salt.balanceOf(bob), sB, "SALT B incorrect" );
//		assertEq( salt.balanceOf(charlie), sC, "SALT C incorrect" );
//		}
//
//
//
//
//	// A unit test which allows users to deposit collateral and receive varying amounts of rewards
//    // Test staking and claiming with multiple users, with Alice, Bob and Charlie each stacking, claiming and unstaking, with rewards being interleaved between each user action.  addSALTRewards should be used to add the rewards with some amount of rewards (between 10 and 100 SALT) being added after each user interaction.
//	function testMultipleUserStakingClaiming() public {
//
//		uint256 startingSaltA = salt.balanceOf(alice);
//		uint256 startingSaltB = salt.balanceOf(bob);
//        uint256 startingSaltC = salt.balanceOf(charlie);
//
//		assertEq( startingSaltA, 0, "Starting SALT A not zero" );
//		assertEq( startingSaltB, 0, "Starting SALT B not zero" );
//        assertEq( startingSaltC, 0, "Starting SALT C not zero" );
//
//        // Alice deposits 50
//        vm.prank(alice);
//        collateral.depositCollateral(50);
//		check( 50, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 );
//        AddedReward[] memory rewards = new AddedReward[](1);
//        rewards[0] = AddedReward({pool: collateralLP, amountToAdd: 50});
//
//        vm.prank(DEPLOYER);
//        collateral.addSALTRewards(rewards);
//        vm.warp( block.timestamp + 1 hours );
//		check( 50, 0, 0, 50, 0, 0, 0, 0, 0, 0, 0, 0 );
//
//        // Bob stakes 10
//        vm.prank(bob);
//        collateral.depositCollateral(10);
//		check( 50, 10, 0, 50, 0, 0, 0, 10, 0, 0, 0, 0 );
//        rewards[0] = AddedReward({pool: collateralLP, amountToAdd: 30});
//
//        vm.prank(DEPLOYER);
//        collateral.addSALTRewards(rewards);
//        vm.warp( block.timestamp + 1 hours );
//		check( 50, 10, 0, 75, 5, 0, 0, 10, 0, 0, 0, 0 );
//
//		// Alice claims
//		IUniswapV2Pair[] memory pools = new IUniswapV2Pair[](1);
//		pools[0] = collateralLP;
//
//        vm.prank(alice);
//        collateral.claimAllRewards(pools);
//		check( 50, 10, 0, 0, 5, 0, 75, 10, 0, 75, 0, 0 );
//        rewards[0] = AddedReward({pool: collateralLP, amountToAdd: 30});
//
//        vm.prank(DEPLOYER);
//        collateral.addSALTRewards(rewards);
//        vm.warp( block.timestamp + 1 hours );
//		check( 50, 10, 0, 25, 10, 0, 75, 10, 0, 75, 0, 0 );
//
//        // Charlie stakes 40
//        vm.prank(charlie);
//        collateral.depositCollateral(40);
//		check( 50, 10, 40, 25, 10, 0, 75, 10, 80, 75, 0, 0 );
//        rewards[0] = AddedReward({pool: collateralLP, amountToAdd: 100});
//
//        vm.prank(DEPLOYER);
//        collateral.addSALTRewards(rewards);
//        vm.warp( block.timestamp + 1 hours );
//		check( 50, 10, 40, 75, 20, 40, 75, 10, 80, 75, 0, 0 );
//
//		// Alice unstakes 10
//        vm.prank(alice);
//        collateral.withdrawCollateralAndClaim(10);
//		check( 40, 10, 40, 60, 20, 40, 60, 10, 80, 90, 0, 0 );
//        rewards[0] = AddedReward({pool: collateralLP, amountToAdd: 90});
//
//        vm.prank(DEPLOYER);
//        collateral.addSALTRewards(rewards);
//        vm.warp( block.timestamp + 1 hours );
//		check( 40, 10, 40, 100, 30, 80, 60, 10, 80, 90, 0, 0 );
//
//		// Bob claims
//        vm.prank(bob);
//        collateral.claimAllRewards(pools);
//		check( 40, 10, 40, 100, 0, 80, 60, 40, 80, 90, 30, 0 );
//        rewards[0] = AddedReward({pool: collateralLP, amountToAdd: 90});
//
//        vm.prank(DEPLOYER);
//        collateral.addSALTRewards(rewards);
//        vm.warp( block.timestamp + 1 hours );
//		check( 40, 10, 40, 140, 10, 120, 60, 40, 80, 90, 30, 0 );
//
//		// Charlie claims
//        vm.prank(charlie);
//        collateral.claimAllRewards(pools);
//		check( 40, 10, 40, 140, 10, 0, 60, 40, 200, 90, 30, 120 );
//        rewards[0] = AddedReward({pool: collateralLP, amountToAdd: 180});
//
//        vm.prank(DEPLOYER);
//        collateral.addSALTRewards(rewards);
//        vm.warp( block.timestamp + 1 hours );
//		check( 40, 10, 40, 220, 30, 80, 60, 40, 200, 90, 30, 120 );
//
//		// Alice adds 100
//        vm.prank(alice);
//        collateral.depositCollateral(100);
//		check( 140, 10, 40, 220, 30, 80, 760, 40, 200, 90, 30, 120 );
//        rewards[0] = AddedReward({pool: collateralLP, amountToAdd: 190});
//
//        vm.prank(DEPLOYER);
//        collateral.addSALTRewards(rewards);
//        vm.warp( block.timestamp + 1 hours );
//		check( 140, 10, 40, 360, 40, 120, 760, 40, 200, 90, 30, 120 );
//
//		// Charlie unstakes all
//        vm.prank(charlie);
//        collateral.withdrawCollateralAndClaim(40);
//		check( 140, 10, 0, 360, 40, 0, 760, 40, 0, 90, 30, 240 );
//        rewards[0] = AddedReward({pool: collateralLP, amountToAdd: 75});
//
//        vm.prank(DEPLOYER);
//        collateral.addSALTRewards(rewards);
//        vm.warp( block.timestamp + 1 hours );
//		check( 140, 10, 0, 430, 45, 0, 760, 40, 0, 90, 30, 240 );
//
//		// Bob unstakes 5
//        vm.prank(bob);
//        collateral.withdrawCollateralAndClaim( 2);
//		check( 140, 8, 0, 430, 36, 0, 760, 32, 0, 90, 39, 240 );
//        rewards[0] = AddedReward({pool: collateralLP, amountToAdd: 74});
//
//        vm.prank(DEPLOYER);
//        collateral.addSALTRewards(rewards);
//        vm.warp( block.timestamp + 1 hours );
//		check( 140, 8, 0, 500, 40, 0, 760, 32, 0, 90, 39, 240 );
//
//		// Bob adds 148
//        vm.prank(bob);
//        collateral.depositCollateral(148);
//		check( 140, 156, 0, 500, 40, 0, 760, 1364, 0, 90, 39, 240 );
//        rewards[0] = AddedReward({pool: collateralLP, amountToAdd: 592});
//
//        vm.prank(DEPLOYER);
//        collateral.addSALTRewards(rewards);
//        vm.warp( block.timestamp + 1 hours );
//		check( 140, 156, 0, 780, 352, 0, 760, 1364, 0, 90, 39, 240 );
//	}

// A unit test that tests maxRewardValueForCallingLiquidation
}
