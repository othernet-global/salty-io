// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "./interfaces/IAccessManager.sol";
import "./dao/interfaces/IDAO.sol";


// A simple AccessManager in which a user is confirmed to have access offchain in the browser and then verified user status is stored in the contract.
// When geographic regions are later excluded, users are required to reverify (allowing avoiding storing countries for specific wallets and potentially violating user privacy).
//
// Note that using ExchangeConfig.setAccessManager() this contract can be replaced by the DAO with orther mechanics such as decentralized ID services, KYC by region, or whatever else deemed necessary by the DAO to satisfy the changing regulatory landscape.
// The AccessManager restricts users from swapping, making DAO proposals, voting, adding liquidity, adding collateral and borrowing USDS on the contract level - but always allows existing assets to be removed (in case a user's region is restricted after depositing assets).
// DAO interaction is not restricted on the contract level - in the case that the AccessManager mistakingly denies everyone access which woudl prevent it from being replaced by the DAO.
//
// Updateable using DAO.proposeSetContractAddress( "accessManager" )
contract AccessManager is IAccessManager
	{
    uint256 public geoVersion;
    mapping(uint256 => mapping(address => bool)) private _walletsWithAccess;

	IDAO immutable public dao;


	constructor( IDAO _dao )
		{
		require( address(_dao) != address(0), "_dao cannot be address(0)" );

		dao = _dao;
		}


	// Called whenever the DAO updates the list of excluded countries.
	// If, in contrast, new countries are included, then updating the geoVersion isn't necessary as the existing _walletsWithAccess will still be valid.
    function excludedCountriesUpdated() public
    	{
    	require( msg.sender == address(dao), "AccessManager.excludedCountriedUpdated only callable by the DAO" );

        geoVersion += 1;
    	}


	// Grant access to the sender - region and access checking being done in the browser.
    function grantAccess() public
    	{
        _walletsWithAccess[geoVersion][msg.sender] = true;
    	}


	// === VIEWS ===

    function walletHasAccess(address wallet) public view returns (bool)
    	{
        return _walletsWithAccess[geoVersion][wallet];
    	}
}

