// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.20;

import "./openzeppelin/token/ERC20/ERC20.sol";
import "./interfaces/ISalt.sol";


contract Salt is ISalt, ERC20
    {
	uint256 public constant MILLION_ETHER = 1000000 ether;
	uint256 public constant INITIAL_SUPPLY = 100 * MILLION_ETHER ;

	uint256 public totalBurned = 0;


	constructor()
		ERC20( "testSALT", "SALT" )
		{
		_mint( msg.sender, INITIAL_SUPPLY );
        }


	// SALT tokens will need to be sent here before they are burned.
	// Normally there will be no SALT balance on this contract - only SALT to burn will be sent here.
    function burnTokensInContract() public returns (uint256)
    	{
    	uint256 balance = balanceOf( address(this) );
    	_burn( address(this), balance );

		totalBurned = totalBurned + balance;

    	return balance;
    	}
	}

