// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";


contract ExcessiveSupplyToken is ERC20
    {
	constructor()
		ERC20( "TEST", "TEST" )
		{
		_mint( msg.sender, uint256(type(uint112).max) + 1 );
        }
	}

