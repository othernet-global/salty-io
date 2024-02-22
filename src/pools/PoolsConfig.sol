// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "./interfaces/IPoolsConfig.sol";
import "./PoolUtils.sol";


// Contract owned by the DAO and only modifiable by the DAO
contract PoolsConfig is IPoolsConfig, Ownable
    {
	event PoolWhitelisted(address indexed tokenA, address indexed tokenB);
	event PoolUnwhitelisted(address indexed tokenA, address indexed tokenB);
	event MaximumWhitelistedPoolsChanged(uint256 newMaxPools);

	struct TokenPair
		{
		// Note that these will be ordered in underlyingPoolTokens as specified in whitelistPool() - rather than ordered such that address(tokenA) < address(tokenB) as with the reserves in Pools.sol
		IERC20 tokenA;
		IERC20 tokenB;
		}

    using EnumerableSet for EnumerableSet.Bytes32Set;


	// Keeps track of what poolIDs have been whitelisted
	EnumerableSet.Bytes32Set private _whitelist;

	// A mapping from poolIDs to the underlying TokenPair
	mapping(bytes32=>TokenPair) public underlyingPoolTokens;

	// The maximum number of pools that can be whitelisted at any one time.
	// If the maximum number of pools is reached, some tokens will need to be delisted before new ones can be whitelisted
	// Range: 20 to 100 with an adjustment of 10
	uint256 public maximumWhitelistedPools = 50;


	// Whitelist a given pair of tokens
	function whitelistPool( IPools pools, IERC20 tokenA, IERC20 tokenB ) external onlyOwner
		{
		require( _whitelist.length() < maximumWhitelistedPools, "Maximum number of whitelisted pools already reached" );
		require(tokenA != tokenB, "tokenA and tokenB cannot be the same token");

		bytes32 poolID = PoolUtils._poolID(tokenA, tokenB);

		// Add to the whitelist and remember the underlying tokens for the pool
		_whitelist.add(poolID);
		underlyingPoolTokens[poolID] = TokenPair(tokenA, tokenB);

 		emit PoolWhitelisted(address(tokenA), address(tokenB));
		}


	function unwhitelistPool( IPools pools, IERC20 tokenA, IERC20 tokenB ) external onlyOwner
		{
		bytes32 poolID = PoolUtils._poolID(tokenA,tokenB);

		_whitelist.remove(poolID);
		delete underlyingPoolTokens[poolID];

		emit PoolUnwhitelisted(address(tokenA), address(tokenB));
		}


	function changeMaximumWhitelistedPools(bool increase) external onlyOwner
        {
        if (increase)
            {
            if (maximumWhitelistedPools < 100)
                maximumWhitelistedPools += 10;
            }
        else
            {
            if (maximumWhitelistedPools > 20)
                maximumWhitelistedPools -= 10;
            }

		emit MaximumWhitelistedPoolsChanged(maximumWhitelistedPools);
        }


	// === VIEWS ===

	function numberOfWhitelistedPools() external view returns (uint256)
		{
		return _whitelist.length();
		}


	function isWhitelisted( bytes32 poolID ) public view returns (bool)
		{
		// The staked SALT pool is always considered whitelisted
		return ( poolID == PoolUtils.STAKED_SALT ) || _whitelist.contains( poolID );
		}


	// Return an array of the currently whitelisted poolIDs
	function whitelistedPools() external view returns (bytes32[] memory)
		{
		return _whitelist.values();
		}


	function underlyingTokenPair( bytes32 poolID ) external view returns (IERC20 tokenA, IERC20 tokenB)
		{
		TokenPair memory pair = underlyingPoolTokens[poolID];
		require(address(pair.tokenA) != address(0) && address(pair.tokenB) != address(0), "This poolID does not exist");

		return (pair.tokenA, pair.tokenB);
		}


	// Returns true if the token has been whitelisted (meaning it has been pooled with either WBTC and WETH)
	function tokenHasBeenWhitelisted( IERC20 token, IERC20 salt, IERC20 weth ) external view returns (bool)
		{
		// See if the token has been whitelisted with either SALT or WETH, as all whitelisted tokens are pooled with both WBTC and WETH
		bytes32 poolID1 = PoolUtils._poolID( token, salt );
		if ( isWhitelisted(poolID1) )
			return true;

		bytes32 poolID2 = PoolUtils._poolID( token, weth );
		if ( isWhitelisted(poolID2) )
			return true;

		return false;
		}
	}