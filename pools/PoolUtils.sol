pragma solidity ^0.8.12;

import "../openzeppelin/token/ERC20/IERC20.sol";
import "../openzeppelin/token/ERC20/utils/SafeERC20.sol";


library PoolUtils
	{
	using SafeERC20 for IERC20;

    // Return the unique poolID for the given two tokens.
    // Tokens are sorted before being hashed to make reversed pairs equivalent.
    // flipped = address(tokenB) < address(tokenA)
    function poolID( IERC20 tokenA, IERC20 tokenB ) internal pure returns (bytes32 _poolID, bool _flipped)
    	{
        // See if the token orders are flipped
        if ( uint160(address(tokenB)) < uint160(address(tokenA)) )
            return (keccak256(abi.encodePacked(address(tokenB), address(tokenA))), true);

        return (keccak256(abi.encodePacked(address(tokenA), address(tokenB))), false);
    	}


    // Returns true if the percentage difference between A/B and C/D is less than or equal to maxPercentDifferenceTimes1000
    function checkRatiosAreSimilar(uint256 A, uint256 B, uint256 C, uint256 D, uint256 maxPercentDifferenceTimes1000 ) internal pure returns (bool)
    	{
    	// Zero denominators aren't meaningful
    	if ( ( B==0 ) || ( D==0 ) )
    		return false;

		uint256 ratio1 = A * D;
		uint256 ratio2 = B * C;

		// Make sure the larger of the ratios isn't outside the specified limit
		if ( ratio1 > ratio2 )
			return ( ratio1 <= ratio2 * (100000 + maxPercentDifferenceTimes1000) / 100000);

		return ( ratio2 <= ratio1 * (100000 + maxPercentDifferenceTimes1000) / 100000);
        }
	}
