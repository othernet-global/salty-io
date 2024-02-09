// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";


contract TestToken is ERC20
    {
    uint8 private _decimals = 6;

	uint256 public INITIAL_SUPPLY;



	constructor()
		ERC20( "testUSDT", "USDT" )
		{
		// 1 quadrillion initial supply
		INITIAL_SUPPLY = 1000 * 1000 * 1000000000 * 10 ** _decimals;
		_mint( msg.sender, INITIAL_SUPPLY );
        }


    function decimals() public view override returns (uint8)
    	{
        return _decimals;
    	}
	}

