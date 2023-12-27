// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "./interfaces/IAccessManager.sol";
import "./dao/interfaces/IDAO.sol";
import "./SigningTools.sol";


// A simple AccessManager in which user IP is mapped offchain to a geolocation and then whitelisted user status is stored in the contract.
// If geographic regions are later excluded, users are required to reverify (allowing avoiding storing countries for specific wallets and potentially violating user privacy).
// The AccessManager restricts users from adding liquidity, adding collateral and borrowing USDS on the contract level - but always allows existing assets to be removed (in case a user's region is restricted after depositing assets).
//
// This contract can be replaced by the DAO with other mechanics such as completely open access, decentralized ID services, KYC by region, or whatever else deemed the best option by the DAO.
//
// Making proposals and voting is not access restricted - just in case AccessManager.sol is ever updated with a flaw in it that universally blocks access (which would effectively cripple the DAO if proposals and voting were then mistakingly restricted).
//
// Updateable using DAO.proposeSetContractAddress( "accessManager" )

contract AccessManager is IAccessManager
	{
	event AccessGranted(address indexed wallet, uint256 geoVersion);

	IDAO immutable public dao;

	// Determines granted access for [geoVersion][wallet]
    mapping(uint256 => mapping(address => bool)) private _walletsWithAccess;

	// The current geoVersion for the AccessManager - which is incremented when new countries are excluded by the DAO.
    uint256 public geoVersion;


	constructor( IDAO _dao )
		{
		dao = _dao;
		}


	// Called whenever the DAO updates the list of excluded countries.
	// This effectively clears access for all users as the geoVersion is used to reference _walletsWithAccess.
	// If, in contrast, new countries are included, then updating the geoVersion isn't necessary as the existing _walletsWithAccess will still be valid.
    function excludedCountriesUpdated() external
    	{
    	require( msg.sender == address(dao), "AccessManager.excludedCountriedUpdated only callable by the DAO" );

        geoVersion += 1;
    	}


	// Verify that the access request was signed by the authoratative signer.
	// Note that this is only a simplistic default mechanism and can be changed by the DAO at any time (either altering the regional restrictions themselves or replacing the access mechanism entirely).
    function _verifyAccess(address wallet, bytes memory signature ) internal view returns (bool)
    	{
		bytes32 messageHash = keccak256(abi.encodePacked(block.chainid, geoVersion, wallet));

		return SigningTools._verifySignature(messageHash, signature);
    	}


	// Grant access to the sender for the given geoVersion.
	// Requires the accompanying correct message signature from the offchain verifier.
    function grantAccess(bytes calldata signature) external
    	{
    	require( _verifyAccess(msg.sender, signature), "Incorrect AccessManager.grantAccess signatory" );

        _walletsWithAccess[geoVersion][msg.sender] = true;

        emit AccessGranted( msg.sender, geoVersion );
    	}


	// === VIEWS ===

	// Returns true if the wallet has access at the current geoVersion
    function walletHasAccess(address wallet) external view returns (bool)
    	{
        return _walletsWithAccess[geoVersion][wallet];
    	}
}

