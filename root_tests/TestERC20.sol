// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.20;

import "../openzeppelin/token/ERC20/ERC20.sol";


contract TestERC20 is ERC20
    {
    uint8 private _decimals = 6;

	uint256 public INITIAL_SUPPLY;



	constructor( uint256 __decimals )
		ERC20( "TestUSDC", "USDC" )
		{
		_decimals = uint8(__decimals);

		// 1 trillion initial supply
		INITIAL_SUPPLY = 1000 * 1000000000 * 10 ** _decimals;
		_mint( msg.sender, INITIAL_SUPPLY );
        }


    function decimals() public view override returns (uint8)
    	{
        return _decimals;
    	}
	}

