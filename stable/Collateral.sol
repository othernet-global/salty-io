//// SPDX-License-Identifier: BSL 1.1
//pragma solidity ^0.8.12;
//
//import "../openzeppelin/token/ERC20/ERC20.sol";
//import "../openzeppelin/token/ERC20/IERC20.sol";
//import "../openzeppelin/token/ERC20/utils/SafeERC20.sol";
//import "../openzeppelin/utils/structs/EnumerableSet.sol";
//import "../staking/interfaces/IStakingConfig.sol";
//import "../staking/StakingRewards.sol";
//import "./interfaces/IPriceFeed.sol";
//import "./interfaces/IStableConfig.sol";
//import "./interfaces/ILiquidator.sol";
//import "../interfaces/IPOL_Optimizer.sol";
//import "../ExchangeConfig.sol";
//import "./USDS.sol";
//import "./interfaces/ICollateral.sol";
//
//
//// @title Collateral
//// @notice Allows users to stake BTC/ETH LP tokens as collateral and the USDS stablecoin.
//
//// The initial collateralization ratio of collateral / borrowed USDS is 200%.
//// The minimum default collateral ratio is 110%, below which positions can be liquidated by any user.
//
//// The liquidator receives a default 5% of liquidated colalteral
//// Liquidated collateral is sold on the market for USDS, the original borrowed amount of which is then burned while any excess goes to Protocol Owned Liquidity.
//// When liquidated, the borrower keeps the borrowed USDS and loses the collateral.
//contract Collateral is ICollateral, SharedRewards
//    {
//	using SafeERC20 for IERC20;
//    using EnumerableSet for EnumerableSet.UintSet;
//
//    IUniswapV2Pair public collateralLP;
//    USDS public usds;
//    IStableConfig public stableConfig;
//	IExchangeConfig public exchangeConfig;
//
//   	// Keeps track of open positions that need to be checked for collateral ratios
//   	EnumerableSet.UintSet private _openPositionIDs;
//
//	// Map from positionID to CollateralPosition
//	mapping(uint256=>CollateralPosition) public _positionsByID;
//
//	// Variable to hold the ID of the next position
//   	uint256 public _nextPositionID = 1;
//
//	// The positionID by wallet
//    mapping(address=>uint256) public userPositionIDs;
//
//	// Set to true if the collateralLP pair is WETH/WBTC instead of the default WBTC/WETH
//	bool public collateralIsFlipped = false;
//	uint256 public btcDecimals;
//    uint256 public wethDecimals;
//
//
//    constructor( IUniswapV2Pair _collateralLP, IStableConfig _stableConfig, IStakingConfig _stakingConfig, IExchangeConfig _exchangeConfig )
//		SharedRewards( _stakingConfig )
//    	{
//        collateralLP = _collateralLP;
//        usds = USDS(_exchangeConfig.usds());
//        stableConfig = _stableConfig;
//		exchangeConfig = _exchangeConfig;
//
//        string memory symbol0 = ERC20(collateralLP.token0()).symbol();
//		string memory symbol1 = ERC20(collateralLP.token1()).symbol();
//
//		// Make sure specified collateralLP is WBTC/WETH
//		// Only WBTC/WETH LP will be usable as collateral
//		bool valid = false;
//
//		if ( keccak256(bytes(symbol0)) == keccak256(bytes("WBTC")) && keccak256(bytes(symbol1)) == keccak256(bytes("WETH")) )
//           	{
//			valid = true;
//
//			btcDecimals = ERC20(collateralLP.token0()).decimals();
//			wethDecimals = ERC20(collateralLP.token1()).decimals();
//           	 }
//
//		if ( keccak256(bytes(symbol0)) == keccak256(bytes("WETH")) && keccak256(bytes(symbol1)) == keccak256(bytes("WBTC")) )
//			{
//			valid = true;
//			collateralIsFlipped = true;
//
//			wethDecimals = ERC20(collateralLP.token0()).decimals();
//			btcDecimals = ERC20(collateralLP.token1()).decimals();
//			}
//
//    	require( valid, "Collateral must be BTC/ETH LP" );
//    	}
//
//
//	function _closeUserCollateralPosition( CollateralPosition memory position ) internal
//		{
//		delete userPositionIDs[position.wallet];
//
//		// Remove the position from _openPositionIDs and delete it from the mapping
//		_openPositionIDs.remove(position.positionID);
//		delete _positionsByID[position.positionID];
//		}
//
//
//
//	// @dev Function for depositing BTC/ETH LP tokens as collateral
//	// @param amountDeposited Amount of tokens to be deposited
//    function depositCollateral( uint256 amountDeposited ) external nonReentrant
//		{
//		require( amountDeposited > 0, "Cannot deposit zero collateral" );
//
//		// Update or create the user's position
//		if ( userHasPosition( msg.sender ) )
//			{
//			// User already has an existing position
//			CollateralPosition storage position = _positionsByID[ userPositionIDs[msg.sender] ];
//
//			// Increase the collateral for the user
//			position.lpCollateralAmount += amountDeposited;
//			}
//		else
//			{
//			// Create a new position as the user doesn't yet have one
//			_positionsByID[_nextPositionID] = CollateralPosition( _nextPositionID, msg.sender, amountDeposited, 0, false );
//			userPositionIDs[msg.sender] = _nextPositionID;
//
//			_nextPositionID++;
//			}
//
//		// Update the user's share of the rewards for the pool
//   		_increaseUserShare( msg.sender, collateralLP, amountDeposited, true );
//
//		// Make sure there is no fee while transferring the token to this contract
//		uint256 beforeBalance = collateralLP.balanceOf( address(this) );
//
//		IERC20 erc20 = IERC20( address(collateralLP) );
//		require( erc20.allowance(msg.sender, address(this)) >= amountDeposited, "Insufficient allowance to deposit collateral" );
//		require( erc20.balanceOf(msg.sender) >= amountDeposited, "Insufficient balance to deposit collateral" );
//		erc20.safeTransferFrom(msg.sender, address(this), amountDeposited );
//
//		uint256 afterBalance = collateralLP.balanceOf( address(this) );
//		require( afterBalance == ( beforeBalance + amountDeposited ), "Cannot deposit tokens with a fee on transfer" );
//
//		emit eDepositCollateral( msg.sender, amountDeposited );
//		}
//
//
//	// @dev Function for withdrawing LP collateral and claiming any pending rewards.
//	// @param amountWithdrawn the amount of tokens to being withdrawn.
//	// @notice Makes sure the the amount being withdrawn does not exceed maxWithdrawable.
//    function withdrawCollateralAndClaim( uint256 amountWithdrawn ) external nonReentrant
//		{
//		require( userHasPosition( msg.sender ), "User does not have an existing position" );
//		require( amountWithdrawn <= maxWithdrawableLP(msg.sender), "Excessive amountWithdrawn" );
//
//		// Update the user's share of the rewards for the pool
//		// Balance checks and claiming pending rewards happens are done in _decreaseUserShare
//		_decreaseUserShare( msg.sender, collateralLP, amountWithdrawn, true );
//
//		// Decrease the collateral for the user
//		CollateralPosition storage position = _positionsByID[ userPositionIDs[msg.sender] ];
//		position.lpCollateralAmount -= amountWithdrawn;
//
//		// Transfer the withdrawn collateralLP back to the user
//		IERC20 erc20 = IERC20( address(collateralLP) );
//
//		// This error should never happen
//		require( erc20.balanceOf(address(this)) >= amountWithdrawn, "Insufficient collateral balance in contract for withdrawal" );
//		erc20.safeTransfer( msg.sender, amountWithdrawn );
//
//		emit eWithdrawCollateral( msg.sender, amountWithdrawn );
//		}
//
//
//	// @dev Function for borrowing USDS using existing collateral
//	// @param amountBorrowed the amount of tokens to being borrowed
//	// @notice Makes sure the the amount being borrowed does not exceed maxBorrowable
//    function borrowUSDS( uint256 amountBorrowed ) external nonReentrant
//		{
//		require( userHasPosition( msg.sender ), "User does not have an existing position" );
//		require( amountBorrowed <= maxBorrowableUSDS(msg.sender), "Excessive amountBorrowed" );
//
//		// Increase the borrowed amount for the user
//		CollateralPosition storage position = _positionsByID[ userPositionIDs[msg.sender] ];
//		position.usdsBorrowedAmount += amountBorrowed;
//
//		// Remember that the position is _openPositionIDs (EnumberableSet for doesn't allow duplicates)
//		_openPositionIDs.add( position.positionID );
//
//		// Mint USDS and send it to the user
//		usds.mintTo( msg.sender, amountBorrowed );
//
//		emit eBorrow( msg.sender, amountBorrowed );
//		}
//
//
//     // @dev Function for repaying borrowed USDS
//     // @param amountRepaid the amount of tokens being repaid
//     function repayUSDS( uint256 amountRepaid ) external nonReentrant
//		{
//		require( userHasPosition( msg.sender ), "User does not have an existing position" );
//
//		CollateralPosition storage position = _positionsByID[ userPositionIDs[msg.sender] ];
//		require( amountRepaid <= position.usdsBorrowedAmount, "Cannot repay more than the borrowed amount" );
//
//		// Decrease the borrowed amount for the user
//		position.usdsBorrowedAmount -= amountRepaid;
//
//		// Burn USDS from the user's wallet
//		require( usds.allowance(msg.sender, address(this)) >= amountRepaid, "Insufficient allowance to repay USDS" );
//		require( usds.balanceOf(msg.sender) >= amountRepaid, "Insufficient balance to repay USDS" );
//		(IERC20(address(usds))).safeTransferFrom(msg.sender, address(usds), amountRepaid);
//		usds.burnTokensInContract();
//
//		// If the position has no more borrowed USDS, then close it
//		if ( position.usdsBorrowedAmount == 0 )
//			_closeUserCollateralPosition( position );
//
//		emit eRepay( msg.sender, amountRepaid );
//		}
//
//
//	function liquidatePosition( uint256 positionID ) external nonReentrant
//		{
//		// Make sure the CollateralPosition exists and hasn't already been liquidated
//		CollateralPosition storage position = _positionsByID[positionID];
//		uint256 usdsBorrowedAmount = position.usdsBorrowedAmount;
//		uint256 lpCollateralAmount = position.lpCollateralAmount;
//
//		require( position.wallet != address(0), "Invalid position" );
//		require( !position.liquidated, "Position has already been liquidated" );
//		require( position.wallet != msg.sender, "Cannot liquidate self" );
//
//		// Check collateral ratio for the user
//		require( usdsBorrowedAmount > 0, "Borrowed amount must be greater than zero");
//		uint256 userCollateralValue = userCollateralValueInUSD( position.wallet );
//		uint256 currentCollateralRatioPercent = ( userCollateralValue * 100 ) / position.usdsBorrowedAmount;
//		require( currentCollateralRatioPercent < stableConfig.minimumCollateralRatioPercent(), "Collateral ratio is too high to liquidate" );
//
//		// Decrease the user's share of collateral within SharedRewards as they no longer have it.
//		// Any pending rewards will be issued to them within _decreaseUserShare as well.
//		_decreaseUserShare( position.wallet, collateralLP, position.lpCollateralAmount, true );
//
//		emit eLiquidatePosition( position.positionID, position.wallet, msg.sender, position.lpCollateralAmount );
//
//		// Mark the position as liquidated and reset the user's position
//		// This is likely redundant as the position will be deleted and there are checks for that - but it is there just in case
//		position.liquidated = true;
//		_closeUserCollateralPosition(position);
//
//		// Send a default 5% of the liquidated collateralLP to the user calling the liquidate function
//		uint256 rewardAmount = lpCollateralAmount * stableConfig.rewardPercentForCallingLiquidation() / 100;
//
//		// Make sure the value of the rewardAmount is not excessive
//		uint256 rewardValue = collateralValue( rewardAmount );
//		if ( rewardValue > stableConfig.maxRewardValueForCallingLiquidation() )
//			rewardAmount = rewardAmount * stableConfig.maxRewardValueForCallingLiquidation() / rewardValue;
//
//		// Reward the caller
//		require( collateralLP.balanceOf(address(this)) >= rewardAmount, "Insufficient balance to reward caller" );
//		(IERC20(address(collateralLP)) ).safeTransfer( msg.sender, rewardAmount );
//
//		// Send the remaining collateralLP to the Liquidator so that it can later be liquidated on its performUpkeep
//		ILiquidator liquidator = exchangeConfig.liquidator();
//		require( collateralLP.balanceOf(address(this)) >= (lpCollateralAmount - rewardAmount), "Insufficient balance to send remaining collateral to liquidator" );
//		(IERC20(address(collateralLP)) ).safeTransfer( address(liquidator), lpCollateralAmount - rewardAmount );
//
//		// Have the liquidator remember the amount of originally borrowed USDS so that it can be burned later on its performUpkeep
//		liquidator.increaseUSDSToBurn( usdsBorrowedAmount );
//		}
//
//
//	// ===== VIEWS =====
//
//	function userHasPosition( address wallet ) public view returns (bool)
//		{
//		return userPositionIDs[wallet] != 0;
//		}
//
//
//
//	// Requires the user to have a position
//	function userPosition( address wallet ) public view returns (CollateralPosition memory)
//		{
//		uint256 positionID = userPositionIDs[wallet];
//		require( positionID != 0, "User does not have a collateral position" );
//
//		return _positionsByID[positionID];
//		}
//
//
//	// The maximum amount of LP collateral that can be withdrawn while keeping
//	// the collateral ratio above a default of 200%
//	// Returns value with 18 decimals
//	function maxWithdrawableLP( address wallet ) public view returns (uint256)
//		{
//		if ( ! userHasPosition( wallet ) )
//			return 0;
//
//		CollateralPosition memory position = userPosition(wallet);
//
//		// When withdrawing require that the user keep at least the inital collateral ratio of default 200%
//		uint256 requiredCollateralValueAfterWithdrawal = ( position.usdsBorrowedAmount * stableConfig.initialCollateralRatioPercent() ) / 100;
//		uint256 value = userCollateralValueInUSD( wallet );
//
//		// If the user doesn't even have the minimum amount of required collateral then return 0
//		if ( value <= requiredCollateralValueAfterWithdrawal )
//			return 0;
//
//		// The maximum withdrawable value in USD
//		uint256 maxWithdrawableValue = value - requiredCollateralValueAfterWithdrawal;
//
//		// Cache totalSupply in a local variable
//		uint256 totalSupply = collateralLP.totalSupply();
//
//		// Determine the USD value of all LP
//		uint256 totalLPValue = value * totalSupply / (position.lpCollateralAmount);
//
//		// Return the number of LP tokens that can be withdrawn
//		return maxWithdrawableValue * totalSupply / totalLPValue;
//   		}
//
//
//	// The maximum amount of USDS that can still be borrowed given the user's current collateral.
//	// Max USDS defaults to 50% of collateral value.
//	// Returns value with 18 decimals.
//	function maxBorrowableUSDS( address wallet ) public view returns (uint256)
//		{
//		if ( ! userHasPosition( wallet ) )
//			return 0;
//
//		// The user's current collateral value will determine the maximum amount that can be borrowed
//		uint256 value  = userCollateralValueInUSD( wallet );
//
//		if ( value < stableConfig.minimumCollateralValueForBorrowing() )
//			return 0;
//
//		uint256 maxBorrowableAmount = ( value * 100 ) / stableConfig.initialCollateralRatioPercent();
//
//		CollateralPosition memory position = userPosition(wallet);
//
//		if ( position.usdsBorrowedAmount >= maxBorrowableAmount )
//			return 0;
//
//		return maxBorrowableAmount - position.usdsBorrowedAmount;
//   		}
//
//
//	function positionIsOpen( uint256 positionID ) public view returns (bool)
//		{
//		return _openPositionIDs.contains( positionID );
//		}
//
//
//	function numberOfOpenPositions() public view returns (uint256)
//		{
//		return _openPositionIDs.length();
//		}
//
//
//	function findLiquidatablePositions( uint256 startIndex, uint256 endIndex ) public view returns (uint256[] memory)
//		{
//		uint256[] memory liquidatablePositions = new uint256[](endIndex - startIndex + 1);
//		uint256 count = 0;
//
//		// Cache these values outside the loop
//		uint256 totalSupply = collateralLP.totalSupply();
//		uint256 totalCollateralValue = totalCollateralValueInUSD();
//
//		for ( uint256 i = startIndex; i <= endIndex; i++ )
//			{
//			uint256 positionID = _openPositionIDs.at(i);
//			CollateralPosition storage position = _positionsByID[positionID];
//
//			// Determine the minCollateralValue a user needs to have based on borrowedUSDS
//			uint256 minCollateralValue = (position.usdsBorrowedAmount * stableConfig.minimumCollateralRatioPercent()) / 100;
//
//			// Determine minCollateralValue in terms of collateral LP
//			uint256 minCollateralLP = (minCollateralValue * totalSupply) / totalCollateralValue;
//
//			// Make sure the user has at least minCollateralLP
//			if ( position.lpCollateralAmount < minCollateralLP )
//				{
//				liquidatablePositions[count] = positionID;
//				count++;
//				}
//			}
//
//		// Resize the array to match the actual number of liquidatable positions found
//		uint256[] memory resizedLiquidatablePositions = new uint256[](count);
//		for ( uint256 i = 0; i < count; i++ )
//			resizedLiquidatablePositions[i] = liquidatablePositions[i];
//
//		return resizedLiquidatablePositions;
//		}
//
//
//	function findLiquidatablePositions() public view returns (uint256[] memory)
//		{
//		if ( numberOfOpenPositions() == 0 )
//			return new uint256[](0);
//
//		return findLiquidatablePositions( 0, numberOfOpenPositions() - 1 );
//		}
//
//
//	// The market value in USD for a given amount of BTC and ETH using the StableConfig.priceFeed
//	// Returns the value with 18 decimals
//	function underlyingTokenValueInUSD( uint256 amountBTC, uint256 amountETH ) public view returns (uint256)
//		{
//		// Prices from the price feed have 18 decimals
//		IPriceFeed priceFeed = stableConfig.priceFeed();
//		uint256 btcPrice = priceFeed.getPriceBTC();
//        uint256 ethPrice = priceFeed.getPriceETH();
//
//		// Keep the 18 decimals from the price and remove the decimals from the token balance
//		uint256 btcValue = ( amountBTC * btcPrice ) / (10 ** btcDecimals );
//		uint256 ethValue = ( amountETH * ethPrice ) / (10 ** wethDecimals );
//
//		return btcValue + ethValue;
//		}
//
//
//	// Returns the current USD value of the specified amount of BTC/ETH collateral using the PriceFeed
//	function collateralValue( uint256 collateralAmount ) public view returns (uint256)
//		{
//		(uint112 reserve0, uint112 reserve1,) = collateralLP.getReserves();
//		uint256 totalLP = collateralLP.totalSupply();
//
//		uint256 userBTC = ( reserve0 * collateralAmount ) / totalLP;
//		uint256 userETH = ( reserve1 * collateralAmount ) / totalLP;
//
//		if ( collateralIsFlipped )
//			(userETH,userBTC) = (userBTC,userETH);
//
//		return underlyingTokenValueInUSD( userBTC, userETH );
//		}
//
//
//	// The current market value of the user's collateral in USD
//	// Returns the value with 18 decimals
//	function userCollateralValueInUSD( address wallet ) public view returns (uint256)
//		{
//		if ( ! userHasPosition(wallet) )
//			return 0;
//
//		// Determine how much LP the user currently has deposited as collateral
//		uint256 collateralAmount = _positionsByID[userPositionIDs[wallet]].lpCollateralAmount;
//
//		return collateralValue( collateralAmount );
//		}
//
//
//	// The current market value of all collateralLP in USD
//	// This is the BTC/ETH LP whether or not it has actually been staked.
//	// Returns the value with 18 decimals
//	function totalCollateralValueInUSD() public view returns (uint256)
//		{
//		(uint112 btcReserves, uint112 ethReserves,) = collateralLP.getReserves();
//
//		if ( collateralIsFlipped )
//			(ethReserves,btcReserves) = (btcReserves,ethReserves);
//
//		return underlyingTokenValueInUSD( btcReserves, ethReserves );
//		}
//	}