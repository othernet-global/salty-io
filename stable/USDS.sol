// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.12;

import "../openzeppelin/token/ERC20/ERC20.sol";
import "../stable/interfaces/ICollateral.sol";


contract USDS is ERC20
    {
    ICollateral public collateral;


	constructor()
		ERC20( "testUSDS", "USDS" )
		{
        }


	// The collateral contract will be set at deployment time and after that is immutable
	function setCollateral( ICollateral _collateral ) public
		{
		require( address(collateral) == address(0), "setCollateral can only be called once" );
		require( address(_collateral) != address(0), "_collateral cannot be address(0)" );

		collateral = _collateral;
		}


	function mintTo( address wallet, uint256 amount ) public
		{
		require( msg.sender == address(collateral), "Can only mint from the Collateral contract" );
		require( address(wallet) != address(0), "cannot mint to address(0)" );

		_mint( wallet, amount );
		}


	// Burn all of the tokens that have been sent to this contract
	function burnTokensInContract() public
		{
		uint256 balance = balanceOf( address(this) );

		_burn( address(this), balance );
		}
	}

