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
	}
