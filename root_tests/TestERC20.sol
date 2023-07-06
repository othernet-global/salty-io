// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.12;

import "../openzeppelin/token/ERC20/ERC20.sol";


contract TestERC20 is ERC20
    {
    uint8 private _decimals = 18;

	uint256 public INITIAL_SUPPLY;



	constructor( uint8 __decimals )
		ERC20( "Test", "TEST" )
		{
		_decimals = __decimals;

		// 1 trillion initial supply
		INITIAL_SUPPLY = 1000 * 1000000000 * 10 ** _decimals;
		_mint( msg.sender, INITIAL_SUPPLY );
        }


	// So the token can pass the whitelisting validation
    function kLast() public pure returns (uint)
    	{
    	return 0;
    	}


    function getReserves() public pure returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast)
		{
		return (0, 0, 0 );
		}


    function decimals() public view override returns (uint8)
    	{
        return _decimals;
    	}
	}

