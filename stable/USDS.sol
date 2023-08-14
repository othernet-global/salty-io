// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "../openzeppelin/token/ERC20/ERC20.sol";
import "../stable/interfaces/ICollateral.sol";
import "./interfaces/IUSDS.sol";
import "../pools/interfaces/IPools.sol";
import "../dao/interfaces/IDAO.sol";
import "../pools/Counterswap.sol";


// USDS can be borrowed by users who have deposited WBTC/WETH liquidity as collateral via Collateral.sol
// The default initial collateralization ratio of collateral / borrowed USDS is 200%.
// The minimum default collateral ratio is 110% - below which positions can be liquidated by any user.

// If WBTC/WETH collateral is liquidated the reclaimed WBTC and WETH tokens are sent to this contract and swapped for USDS (via counterswapping) which is then burned (essentially "undoing" the user's original collateral deposit and USDS borrow).
contract USDS is ERC20, IUSDS
    {
    IERC20 immutable public wbtc;
    IERC20 immutable public weth;

    ICollateral public collateral;
    IPools public pools;
    IDAO public dao;

	// This corresponds to USDS that was borrowed by users who had their collateral liquidated.
	// Because liquidated collateral no longer exists the borrowed USDS needs to be burned as well in order to
	// "undo" the collateralized position and return state back to where it was before the liquidated user deposited collateral and borrowed USDS.
	uint256 public usdsThatShouldBeBurned;


	constructor( IERC20 _wbtc, IERC20 _weth )
		ERC20( "testUSDS", "USDS" )
		{
		require( address(_wbtc) != address(0), "_wbtc cannot be address(0)" );
		require( address(_weth) != address(0), "_weth cannot be address(0)" );

		wbtc = _wbtc;
		weth = _weth;
        }


	// These contracts will be set at deployment time and after that become immutable
	function setContracts( ICollateral _collateral, IPools _pools, IDAO _dao ) public
		{
		require( address(_collateral) != address(0), "_collateral cannot be address(0)" );
		require( address(_pools) != address(0), "_pools cannot be address(0)" );
		require( address(_dao) != address(0), "_dao cannot be address(0)" );

		require( address(collateral) == address(0), "setContracts can only be called once" );

		collateral = _collateral;
		pools = _pools;
		dao = _dao;
		}


	// Mint from the Collateral contract to allow users to borrow USDS after depositing BTC/ETH liquidity as collateral.
	// Only callable by the Collateral contract.
	function mintTo( address wallet, uint256 amount ) public
		{
		require( msg.sender == address(collateral), "Can only call USDS.mintTo from the Collateral contract" );
		require( address(wallet) != address(0), "Cannot mint to address(0)" );
		require( amount > 0, "Cannot mint zero USDS" );

		_mint( wallet, amount );
		}


	// Called when a user's collateral position has been liquidated to indicate that the borrowed USDS from the position needs to be burned.
	// Only callable by the Collateral contract.
	function shouldBurnMoreUSDS( uint256 usdsToBurn ) public
		{
		require( msg.sender == address(collateral), "Can only call USDS.shouldBurnMoreUSDS from the Collateral contract" );

		usdsThatShouldBeBurned += usdsToBurn;
		}


	// Send the specified token to Counterswap contract so that it will be gradually converted to USDS (when users swap first in the opposite direction)
	function _sendTokenToCounterswap( IERC20 token, address counterswapAddress ) internal
		{
		uint256 tokenBalance = token.balanceOf( address(this) );
		if ( tokenBalance == 0 )
			return;

		token.approve( address(pools), tokenBalance );

		// Deposit the token in the Pools contract for the specified counterswapAddress so that the proper counterswap will be made as users swap in the opposite direction.
		pools.depositTokenForCounterswap( token, counterswapAddress, tokenBalance );
		}


	function _withdrawUSDSFromCounterswap( address counterswapAddress, uint256 amountRemainingUSDS ) internal returns (uint256)
		{
		// Determine how much USDS has previously been converted through counterswaps and should be withdrawn from the Pools contract.
		uint256 usdsToWithdraw = pools.depositedBalance( counterswapAddress, this );

		// Don't withdraw more USDS than amountRemainingUSDS
		if ( usdsToWithdraw > amountRemainingUSDS )
			usdsToWithdraw = amountRemainingUSDS;

		if ( usdsToWithdraw == 0 )
			return amountRemainingUSDS;

		// Withdraw USDS (this ERC20 contract) from Counterswap
		pools.withdrawTokenFromCounterswap( this, counterswapAddress, usdsToWithdraw );

		return amountRemainingUSDS - usdsToWithdraw;
		}


	// Send all WBTC and WETH in this contract to the Counterswap contract (same as the Pools contract as Pools derives from Counterswap) so that it can gradually be swapped to USDS (which can then be burned).
	// Also, withdraw and burn USDS which has already been obtained through previous counterswaps.
	function performUpkeep() public
		{
		require( msg.sender == address(dao), "USDS.performUpkeep is only callable from the DAO" );

		// Send any WBTC or WETH in this contract to the Counterswap contract for gradual conversion to USDS
		_sendTokenToCounterswap(wbtc, Counterswap.WBTC_TO_USDS);
		_sendTokenToCounterswap(weth, Counterswap.WETH_TO_USDS);

		if ( usdsThatShouldBeBurned == 0 )
			return;

		// Withdraw up to usdsThatShouldBeBurned from WBTC and WETH -> USDS counterswaps
		uint256 amountRemainingUSDS = _withdrawUSDSFromCounterswap( Counterswap.WBTC_TO_USDS, usdsThatShouldBeBurned );
		usdsThatShouldBeBurned = _withdrawUSDSFromCounterswap( Counterswap.WETH_TO_USDS, amountRemainingUSDS );

		// Burn all the USDS that was jsut withdraw (and any other USDS in the contract - although there shouldn't normally be any)
		_burn( address(this), balanceOf(address(this)) );
		}
	}

