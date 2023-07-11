// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.12;

import "../openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "../openzeppelin/utils/structs/EnumerableSet.sol";
import "./interfaces/IPriceFeed.sol";
import "./USDS.sol";
import "../pools/PoolUtils.sol";
import "../staking/Liquidity.sol";
import "./interfaces/ICollateral.sol";


// Allows users to add and deposit WBTC/WETH liquidity as collateral for borrowing USDS stablecoin.
// Deposited WBTC/WETH liquidity is owned by this contract (as it makes external calls to Pools.sol to add and remove liquidity) and the user making the deposit is given increased collateral share.
// This contract needs to maintain control over the liquidity collateral in case a user's collateral ratio falls below required minimums and their collateral needs to be liquidated.
// When users withdraw liquidity: their collateral share is reduced, this contract pulls liquidity from Pools.sol and the reclaimed tokens are sent back to the user.
// The functionality to add and remove liquidity is inherited from Liquidity.sol

// The default initial collateralization ratio of collateral / borrowed USDS is 200%.
// The minimum default collateral ratio is 110%, below which positions can be liquidated by any user.
// Users who call the liquidation function on undercollateralized positions receive a default 5% of the liquidated collateral (up to a default max of $500).
// Liquidated users lose their deposited WBTC/WETH collateral and keep the USDS that they borrowed.

// Liquidated WBTC/WETH collateral is sent to the USDS contract where it is swapped to USDS and the original amount of USDS borrowed from the liquidated position is burned (essentially "undoing" the user's original collateral deposit and USDS borrow).
// As the minimum collateral ratio defaults to 110% any excess WBTC/WETH that is not swapped to burned USDS will be stored in the USDS contract - in the case
// that future liquidated positions are undercollateralized during times of high market volatility and the WBTC/WETH is needed to purchase USDS to burn.

contract Collateral is Liquidity, ICollateral
    {
	using SafeERC20 for IERC20;
	using SafeERC20 for IUSDS;
    using EnumerableSet for EnumerableSet.AddressSet;

	IERC20 public wbtc;
	IERC20 public weth;
    IUSDS public usds;

    IStableConfig public stableConfig;

   	// Keeps track of wallets that have borrowed USDS (so that they can be checked easily for sufficient colalteral ratios)
   	EnumerableSet.AddressSet private _walletsWithBorrowedUSDS;

	// The amount of USDS that has been borrowed by each user
    mapping(address=>uint256) public usersBorrowedUSDS;

	// Cached for efficiency
	uint256 public wbtcDecimals;
    uint256 public wethDecimals;
    bytes32 public collateralPoolID;


    constructor( IPools _pools, IERC20 _wbtc, IERC20 _weth, IExchangeConfig _exchangeConfig, IPoolsConfig _poolsConfig, IStakingConfig _stakingConfig, IStableConfig _stableConfig )
		Liquidity( _pools, _exchangeConfig, _poolsConfig, _stakingConfig )
    	{
		require( address(_wbtc) != address(0), "_wbtc cannot be address(0)" );
		require( address(_weth) != address(0), "_weth cannot be address(0)" );
		require( address(_stableConfig) != address(0), "_stableConfig cannot be address(0)" );

		wbtc = _wbtc;
		weth = _weth;
        stableConfig = _stableConfig;

		usds = exchangeConfig.usds();

		wbtcDecimals = ERC20(address(wbtc)).decimals();
		wethDecimals = ERC20(address(weth)).decimals();
        (collateralPoolID,) = PoolUtils.poolID( wbtc, weth );
    	}


	// Deposit WBTC/WETH liqudity as collateral and increase the caller's collateral share for future rewards.
    function depositCollateralAndIncreaseShare( uint256 maxAmountWBTC, uint256 maxAmountWETH, uint256 minLiquidityReceived, uint256 deadline, bool bypassZapping ) public nonReentrant returns (uint256 addedAmountWBTC, uint256 addedAmountWETH, uint256 addedLiquidity)
		{
		// Have the user deposit the specified WBTC/WETH liquidity and increase their collateral share
		(addedAmountWBTC, addedAmountWETH, addedLiquidity) = addLiquidityAndIncreaseShare( wbtc, weth, maxAmountWBTC, maxAmountWETH, minLiquidityReceived, deadline, bypassZapping );

		emit eDepositCollateral( msg.sender, addedAmountWBTC, addedAmountWETH, addedLiquidity );
		}


	// Withdraw WBTC/WETH collateral and claim any pending rewards.
     function withdrawCollateralAndClaim( uint256 collateralToWithdraw, uint256 minReclaimedWBTC, uint256 minReclaimedWETH, uint256 deadline ) public nonReentrant returns (uint256 reclaimedWBTC, uint256 reclaimedWETH)
		{
		// Make sure that the user has collateral and if they have borrowed USDS that collateralToWithdraw doesn't bring their collateralRatio below allowable levels.
		require( userShareInfoForPool( msg.sender, collateralPoolID ).userShare > 0, "User does not have any collateral" );
		require( collateralToWithdraw <= maxWithdrawableCollateral(msg.sender), "Excessive collateralToWithdraw" );

		// Withdraw the WBTC/WETH liquidity from the liquidity pool (sending the reclaimed tokens back to the user)
		(reclaimedWBTC, reclaimedWETH) = withdrawLiquidityAndClaim( wbtc, weth, collateralToWithdraw, minReclaimedWBTC, minReclaimedWETH, deadline );

		emit eWithdrawCollateral( msg.sender, collateralToWithdraw, reclaimedWBTC, reclaimedWETH );
		}


	// Borrow USDS using existing collateral, making sure that the amount being borrowed does not exceed maxBorrowable
    function borrowUSDS( uint256 amountBorrowed ) public nonReentrant
		{
		require( userShareInfoForPool( msg.sender, collateralPoolID ).userShare > 0, "User does not have any collateral" );
		require( amountBorrowed <= maxBorrowableUSDS(msg.sender), "Excessive amountBorrowed" );

		// Increase the borrowed amount for the user
		usersBorrowedUSDS[msg.sender] += amountBorrowed;

		// Remember that the user has borrowed USDS (so they can later be checked for sufficient collateralization ratios and liquidated if necessary)
		_walletsWithBorrowedUSDS.add(msg.sender);

		// Mint USDS and send it to the user
		usds.mintTo( msg.sender, amountBorrowed );

		emit eBorrow( msg.sender, amountBorrowed );
		}


     // Repay borrowed USDS and adjust the user's usersBorrowedUSDS
     function repayUSDS( uint256 amountRepaid ) public nonReentrant
		{
		require( userShareInfoForPool( msg.sender, collateralPoolID ).userShare > 0, "User does not have any collateral" );
		require( amountRepaid <= usersBorrowedUSDS[msg.sender], "Cannot repay more than the borrowed amount" );

		// Decrease the borrowed amount for the user
		usersBorrowedUSDS[msg.sender] -= amountRepaid;

		// Have the user send the USDS to the USDS contract so that it can later be burned (on USDS.performUpkeep)
		usds.safeTransferFrom(msg.sender, address(usds), amountRepaid);

		// Have USDS remember that the USDS should be burned
		usds.shouldBurnMoreUSDS( amountRepaid );

		// Check if the user no longer has any borrowed USDS
		if ( usersBorrowedUSDS[msg.sender] == 0 )
			_walletsWithBorrowedUSDS.remove(msg.sender);

		emit eRepay( msg.sender, amountRepaid );
		}


	// Withdraw the liquidated collateral from the liquidity pool.
	// The liquidity is owned by this contract so when it is withdrawn it will be reclaimed by this contract.
	function _withdrawLiquidatedCollateral( uint256 collateralAmount ) internal returns (uint256 reclaimedWBTC, uint256 reclaimedWETH)
		{
		// Withdraw the liquidity that was used as collateral by the user.
		// No minimums are used as the amounts returned will be dictated by the current WTBC/WETH reserves
		// The liquidity withdrawn is held by this contract (as the removeLiquidity call is external)
		(reclaimedWBTC, reclaimedWETH) = pools.removeLiquidity(wbtc, weth, collateralAmount, 0, 0, block.timestamp );
		}


	// Liquidate a position which has fallen under the minimum collateral ratio.
	// A default 5% of the value of the collateral is sent to the caller, with the rest being sent to the Liquidator for later conversion to USDS which is then burned.
	function liquidateUser( address wallet ) public nonReentrant
		{
		require( wallet != msg.sender, "Cannot liquidate self" );

		// First, make sure that the user's colalteral ratio is below the required level
		require( canUserCanBeLiquidated(wallet), "User cannot be liquidated" );

		uint256 userCollateralAmount = userShareInfoForPool( wallet, collateralPoolID ).userShare;

		// Withdraw the liquidated collateral from the liquidity pool.
		// The liquidity is owned by this contract so when it is withdrawn it will be reclaimed by this contract.
		(, uint256 reclaimedWETH) = _withdrawLiquidatedCollateral( userCollateralAmount );

		// Decrease the user's share of collateral as it has been liquidated and they no longer have it.
		_decreaseUserShare( wallet, collateralPoolID, userCollateralAmount, true );

		// The caller receives a default 5% of the value of the liquidated collateral so we can just send them default 10% of the reclaimedWETH (as WBTC/WETH is a 50/50 pool).
		uint256 rewardedWETH = 2 * reclaimedWETH * stableConfig.rewardPercentForCallingLiquidation() / 100;

		// Make sure the value of the rewardAmount is not excessive
		uint256 rewardValue = underlyingTokenValueInUSD( 0, rewardedWETH ); // in 18 decimals
		uint256 maxRewardValue = stableConfig.maxRewardValueForCallingLiquidation() * 10**18; // convert to 18 decimals
		if ( rewardValue > maxRewardValue )
			rewardedWETH = ( rewardedWETH * maxRewardValue / rewardValue );

		// Reward the caller
		weth.safeTransfer( msg.sender, rewardedWETH );

		// Send the remaining WBTC and WETH to the USDS contract so that the tokens can later be converted to USDS and burned (on USDS.performUpkeep)
		wbtc.safeTransfer( address(usds), wbtc.balanceOf(address(this)) );
		weth.safeTransfer( address(usds), weth.balanceOf(address(this)) );

		// Have USDS remember the amount of originally borrowed USDS so that it can be burned later
		usds.shouldBurnMoreUSDS( usersBorrowedUSDS[wallet] );

		// Clear the borrowedUSDS for the user who was liquidated so that they can simply keep the USDS they borrowed
		usersBorrowedUSDS[wallet] = 0;
		_walletsWithBorrowedUSDS.remove(msg.sender);

		emit eLiquidatePosition( wallet, msg.sender, userCollateralAmount );
		}


	// ===== VIEWS =====

	// The maximum amount of collateral that can be withdrawn while keeping the collateral ratio above a default of 200%
	// Returns value with 18 decimals
	function maxWithdrawableCollateral( address wallet ) public view returns (uint256)
		{
		uint256 userCollateralAmount = userShareInfoForPool( wallet, collateralPoolID ).userShare;

		// If the user has no collateral then they can't withdraw any collateral
		if ( userCollateralAmount == 0 )
			return 0;

		// When withdrawing, require that the user keep at least the inital collateral ratio (default 200%)
		uint256 requiredCollateralValueAfterWithdrawal = ( usersBorrowedUSDS[wallet] * stableConfig.initialCollateralRatioPercent() ) / 100;
		uint256 value = userCollateralValueInUSD( wallet );

		// If the user doesn't even have the minimum amount of required collateral then return zero
		if ( value <= requiredCollateralValueAfterWithdrawal )
			return 0;

		// The maximum withdrawable value in USD
		uint256 maxWithdrawableValue = value - requiredCollateralValueAfterWithdrawal;

		// Return the collateralAmount that can be withdrawn
		return userCollateralAmount * maxWithdrawableValue / value;
   		}


	// The maximum amount of USDS that can be borrowed given the user's current collateral and existing balance of borrowedUSDS.
	// Max borrowable USDS defaults to 50% of collateral value.
	// Returns value with 18 decimals.
	function maxBorrowableUSDS( address wallet ) public view returns (uint256)
		{
		// If the user doesn't have any collateral, then they can't borrow any USDS
		if ( userShareInfoForPool( wallet, collateralPoolID ).userShare == 0 )
			return 0;

		// The user's current collateral value will determine the maximum amount that can be borrowed
		uint256 value  = userCollateralValueInUSD( wallet );

		if ( value < stableConfig.minimumCollateralValueForBorrowing() )
			return 0;

		uint256 maxBorrowableAmount = ( value * 100 ) / stableConfig.initialCollateralRatioPercent();

		// Already borrowing more than the max?
		if ( usersBorrowedUSDS[wallet] >= maxBorrowableAmount )
			return 0;

		return maxBorrowableAmount - usersBorrowedUSDS[wallet];
   		}


	function numberOfUsersWithBorrowedUSDS() public view returns (uint256)
		{
		return _walletsWithBorrowedUSDS.length();
		}


	// Confirm that a user can be liquidated - that they have borrowed USDS and that their collateral value / borrowedUSDS ratio is less than the minimum required
	function canUserCanBeLiquidated( address wallet ) public view returns (bool)
		{
		// Check the current collateral ratio for the user
		uint256 usdsBorrowedAmount = usersBorrowedUSDS[wallet];
		if ( usdsBorrowedAmount == 0 )
			return false;

		uint256 userCollateralValue = userCollateralValueInUSD(wallet);

		// Make sure the user's position is under collateralized
		return ( userCollateralValue * 100 ) / usdsBorrowedAmount < stableConfig.minimumCollateralRatioPercent();
		}


	function findLiquidatableUsers( uint256 startIndex, uint256 endIndex ) public view returns (address[] memory)
		{
		address[] memory liquidatableUsers = new address[](endIndex - startIndex + 1);
		uint256 count = 0;

		// Cache these values outside the loop
		uint256 totalCollateralShares = totalSharesForPool( collateralPoolID );

		(uint256 reservesWBTC, uint256 reservesWETH) = pools.getPoolReserves(wbtc, weth);
		uint256 totalCollateralValue = underlyingTokenValueInUSD( reservesWBTC, reservesWETH );

		for ( uint256 i = startIndex; i <= endIndex; i++ )
			{
			address wallet = _walletsWithBorrowedUSDS.at(i);

			// Determine the minCollateralValue a user needs to have based on their borrowedUSDS
			uint256 minCollateralValue = (usersBorrowedUSDS[wallet] * stableConfig.minimumCollateralRatioPercent()) / 100;

			// Determine minCollateral in terms of minCollateralValue
			uint256 minCollateral = (minCollateralValue * totalCollateralShares) / totalCollateralValue;

			// Make sure the user has at least minCollateral
			if ( userShareInfoForPool( wallet, collateralPoolID ).userShare < minCollateral )
				liquidatableUsers[count++] = wallet;
			}

		// Resize the array to match the actual number of liquidatable positions found
		address[] memory resizedLiquidatableUsers = new address[](count);
		for ( uint256 i = 0; i < count; i++ )
			resizedLiquidatableUsers[i] = liquidatableUsers[i];

		return resizedLiquidatableUsers;
		}


	function findLiquidatablePositions() public view returns (address[] memory)
		{
		if ( numberOfUsersWithBorrowedUSDS() == 0 )
			return new address[](0);

		return findLiquidatableUsers( 0, numberOfUsersWithBorrowedUSDS() - 1 );
		}


	// The current market value in USD for a given amount of BTC and ETH using the StableConfig.priceFeed
	// Returns the value with 18 decimals
	function underlyingTokenValueInUSD( uint256 amountBTC, uint256 amountETH ) public view returns (uint256)
		{
		// Prices from the price feed have 18 decimals
		IPriceFeed priceFeed = stableConfig.priceFeed();
		uint256 btcPrice = priceFeed.getPriceBTC();
        uint256 ethPrice = priceFeed.getPriceETH();

		// Keep the 18 decimals from the price and remove the decimals from the token balance
		uint256 btcValue = ( amountBTC * btcPrice ) / (10 ** wbtcDecimals );
		uint256 ethValue = ( amountETH * ethPrice ) / (10 ** wethDecimals );

		return btcValue + ethValue;
		}


	// The current market value of the user's collateral in USD
	// Returns the value with 18 decimals
	function userCollateralValueInUSD( address wallet ) public view returns (uint256)
		{
		// Determine how much collateral share the user currently has
		uint256 userCollateralAmount = userShareInfoForPool( wallet, collateralPoolID ).userShare;

		// If the user doesn't have any collateral then the value of their collateral is zero
		if ( userCollateralAmount == 0 )
			return 0;

		uint256 totalCollateralShares = totalSharesForPool( collateralPoolID );

		(uint256 reservesWBTC, uint256 reservesWETH) = pools.getPoolReserves(wbtc, weth);
		uint256 totalCollateralValue = underlyingTokenValueInUSD( reservesWBTC, reservesWETH );

		return userCollateralAmount * totalCollateralValue / totalCollateralShares;
		}
	}