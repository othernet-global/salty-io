//// SPDX-License-Identifier: BSL 1.1
//pragma solidity =0.8.20;
//
//import "./interfaces/IAccessManager.sol";
//import "./dao/interfaces/IDAO.sol";
//
//
//// A simple AccessManager in which a user has access if their country is not only the DAO-controlled list of excluded countries.
//// Note that this could be replaced by alternate AccessManager such as Polygon ID (if the DAO decided that they wanted to do so).
//// Restricts users swaps, liquidity providing, staking and DAO voting - but always allows existing assets to be removed (in case a user is restricted after depositing assets).
//
//contract AccessManager is IAccessManager
//    {
//    IDAO immutable public dao;
//
//	mapping(address=>bool) public walletHasVerified;
//    mapping(address=>string) public walletCountries;
//
//
//	constructor( IDAO _dao )
//		{
//		require( address(_dao) != address(0), "_dao cannot be address(0)" );
//
//		dao = _dao;
//		}
//
//
//	// Relatively simple method in which a user sends a transaction with their country specified.
//	// The country can be derived from the user IP address (or other means)
//	function setCountry( string memory country ) public
//		{
//		require( keccak256(bytes(country)) != keccak256(bytes("")), "Specified country cannot be blank" );
//
//		walletHasVerified[msg.sender] = true;
//
//		walletCountries[msg.sender] = country;
//		}
//
//
//	function walletHasAccess( address wallet ) public view returns (bool)
//		{
//		if ( ! walletHasVerified[wallet] )
//			return false;
//
//		string memory country = walletCountries[wallet];
//
//		return ! dao.countryIsExcluded( country );
//		}
//	}
//
