// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.20;

import "../interfaces/IAccessManager.sol";
import "../dao/interfaces/IDAO.sol";


// An AccessManager for testing that always returns that a wallet has access
contract TestAccessManager is IAccessManager
    {
    IDAO public dao;


	constructor( IDAO _dao )
		{
		require( address(_dao) != address(0), "_dao cannot be address(0)" );

		dao = _dao;
		}


	function isTest() external
		{
		}


	function setCountry( string calldata country ) external
		{
		}


	function walletHasAccess( address wallet ) public pure returns (bool)
		{
		// These are the addresses for the test users
		if ( wallet == address(0x73107dA86708c2DAd0D91388fB057EeE3E2581aF) ) // DEV_WALLET
			return true;
		if ( wallet == address(0x1111) ) // alice
			return true;
		if ( wallet == address(0x2222) ) // bob
			return true;
		if ( wallet == address(0x3333) ) // charlie
			return true;

		return false;
		}
	}

