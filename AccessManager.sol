// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "./interfaces/IAccessManager.sol";
import "./dao/interfaces/IDAO.sol";


// A simple AccessManager in which user IP is mapped offchain to a geolocation and then whitelisted user status is stored in the contract.
// If geographic regions are later excluded, users are required to reverify (allowing avoiding storing countries for specific wallets and potentially violating user privacy).
// The AccessManager restricts users from adding liquidity, adding collateral and borrowing USDS on the contract level - but always allows existing assets to be removed (in case a user's region is restricted after depositing assets).
//
// This contract can be replaced by the DAO with other mechanics such as decentralized ID services, KYC by region, or whatever else deemed necessary by the DAO to satisfy the changing regulatory landscape.
//
// Making proposals and voting is not access restricted - just in case there is ever AccessManager.sol is ever updated with a flaw in it that universally prevents access (which would effectively cripple the DAO if proposals and voting were then mistakingly resricted).
// Acquiring xSALT requires access though as the underlying staking mechanism requires access.
//
// Updateable using DAO.proposeSetContractAddress( "accessManager" )

contract AccessManager is IAccessManager
	{
	address constant public EXPECTED_SIGNER = 0x1234519DCA2ef23207E1CA7fd70b96f281893bAa;

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


	function _slice32(bytes memory array, uint index) internal pure returns (bytes32 result)
		{
		result = 0;

		for (uint i = 0; i < 32; i++)
			{
			uint8 temp = uint8(array[index+i]);
			result |= bytes32((uint(temp) & 0xFF) * 2**(8*(31-i)));
			}
		}


	// Verify that the whitelist was signed by the authoratative signer.
	// Note that this is only the default mechanism and can be changed by the DAO at any time (either aletering the regional restrictions themselves or replacing the access mechanism entirely).
    function verifyWhitelist(address wallet, bytes memory signature ) public view returns (bool)
    	{
		bytes32 r = _slice32(signature, 0);
		bytes32 s = _slice32(signature, 32);
		uint8 v = uint8(signature[64]);

		bytes32 messageHash = keccak256(abi.encodePacked(geoVersion, wallet));
		address recoveredAddress = ecrecover(messageHash, v, r, s);

        return (recoveredAddress == EXPECTED_SIGNER);
    	}


	// Grant access to the sender for the given geoVersion (which is incremented when new regions are restricted).
	// Requires the accompanying correct message signature from the offchain verifier.
    function grantAccess(bytes memory signature) public
    	{
    	require( verifyWhitelist(msg.sender, signature), "Incorrect grantAccess signer" );

        _walletsWithAccess[geoVersion][msg.sender] = true;
    	}


	// === VIEWS ===

	// Returns true if the wallet has access at the current geoVersion
    function walletHasAccess(address wallet) public view returns (bool)
    	{
        return _walletsWithAccess[geoVersion][wallet];
    	}
}

