pragma solidity =0.8.22;

import "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";


library SigningTools
	{
	// The public address of the signer for verfication of BootstrapBallot voting and default AccessManager
	address constant public EXPECTED_SIGNER = 0x1234519DCA2ef23207E1CA7fd70b96f281893bAa;


	// Verify that the messageHash was signed by the authoratative signer.
    function _verifySignature(bytes32 messageHash, bytes memory signature ) internal pure returns (bool)
    	{
		bytes32 r;
		bytes32 s;
		uint8 v;

		assembly
			{
			r := mload (add (signature, 0x20))
			s := mload (add (signature, 0x40))
			v := mload (add (signature, 0x41))
			}

		address recoveredAddress = ECDSA.recover(messageHash, v, r, s);

        return (recoveredAddress == EXPECTED_SIGNER);
    	}
	}
