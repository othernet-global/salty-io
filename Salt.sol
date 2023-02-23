// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.17;

import "./openzeppelin/token/ERC20/ERC20.sol";
import "./openzeppelin/access/Ownable.sol";


contract Salt is ERC20, Ownable
    {
	uint256 constant MILLION_ETHER = 1000000 ether;
	uint256 constant INITIAL_SUPPLY = 100 * MILLION_ETHER ;


	constructor()
		ERC20( "Salt", "SALT" )
		{
		_mint( msg.sender, INITIAL_SUPPLY );

		// Send initial supply to managing contracts
        }
	}

