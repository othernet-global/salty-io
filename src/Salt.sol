// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "./interfaces/ISalt.sol";


contract Salt is ISalt, ERC20
    {
    event SALTBurned(uint256 amount);

	uint256 public constant MILLION_ETHER = 1000000 ether;
	uint256 public constant INITIAL_SUPPLY = 100 * MILLION_ETHER ;


	constructor()
		ERC20( "Salt", "SALT" )
		{
		_mint( msg.sender, INITIAL_SUPPLY );
        }


	// SALT tokens will need to be sent here before they are burned.
	// There should otherwise be no SALT balance in this contract.
    function burnTokensInContract() external
    	{
    	uint256 balance = balanceOf( address(this) );
    	_burn( address(this), balance );

    	emit SALTBurned(balance);
    	}


    // === VIEWS ===
    function totalBurned() external view returns (uint256)
    	{
    	return INITIAL_SUPPLY - totalSupply();
    	}
	}

