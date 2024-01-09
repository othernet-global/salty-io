// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";


contract TestWETH is ERC20
    {
    uint8 private _decimals;

	uint256 public INITIAL_SUPPLY;



	constructor()
		ERC20( "TestWETH", "WETH" )
		{
		_decimals = uint8(18);

		// 1 quadrillion initial supply
		INITIAL_SUPPLY = 1000 * 1000 * 1000000000 * 10 ** _decimals;
		_mint( msg.sender, INITIAL_SUPPLY );
        }


    function decimals() public view override returns (uint8)
    	{
        return _decimals;
    	}


    // To mimic WETH
	function deposit() public payable
		{
		_mint( msg.sender, msg.value );
		}


	function withdraw(uint wad) public
		{
		require(balanceOf(msg.sender) >= wad);
		_burn( msg.sender, wad );

		payable(msg.sender).transfer(wad);
		}
	}

