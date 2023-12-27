// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "../stable/interfaces/ICollateralAndLiquidity.sol";
import "./interfaces/IUSDS.sol";


// USDS can be borrowed by users who have deposited WBTC/WETH liquidity as collateral via CollateralAndLiquidity.sol.
// The default initial collateralization ratio of collateral / borrowed USDS is 200%.
// The minimum default collateral ratio is 110% - below which positions can be liquidated by any user.

contract USDS is ERC20, IUSDS, Ownable
    {
	event USDSMinted(address indexed to, uint256 amount);
	event USDSTokensBurned(uint256 amount);

    ICollateralAndLiquidity public collateralAndLiquidity;


	constructor()
	ERC20( "USDS", "USDS" )
		{
        }


	// This will be called only once - at deployment time
	function setCollateralAndLiquidity( ICollateralAndLiquidity _collateralAndLiquidity ) external onlyOwner
		{
		collateralAndLiquidity = _collateralAndLiquidity;

		// setCollateralAndLiquidity can only be called once
		renounceOwnership();
		}


	// Mint USDS for users to borrow after they deposit adequate WBTC/WETH liquidity as collateral.
	// Only callable by the CollateralAndLiquidity contract.
	function mintTo( address wallet, uint256 amount ) external
		{
		require( msg.sender == address(collateralAndLiquidity), "USDS.mintTo is only callable from the Collateral contract" );
		require( amount > 0, "Cannot mint zero USDS" );

		_mint( wallet, amount );

		emit USDSMinted(wallet, amount);
		}


	// USDS tokens will need to be sent here before they are burned (on a repayment or liquidation).
	// There should otherwise be no USDS balance in this contract.
    function burnTokensInContract() external
    	{
    	uint256 balance = balanceOf( address(this) );
    	_burn( address(this), balance );

    	emit USDSTokensBurned(balance);
    	}
    }

