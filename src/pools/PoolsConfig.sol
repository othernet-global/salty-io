// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import "./interfaces/IPoolsConfig.sol";
import "./PoolUtils.sol";


// Contract owned by the DAO and only modifiable by the DAO
contract PoolsConfig is IPoolsConfig, Ownable
    {
	struct TokenPair
		{
		// Note that these will be ordered in underlyingPoolTokens as specified in whitelistPool() - rather than ordered such that address(tokenA) < address(tokenB) as with the reserves in Pools.sol
		IERC20 tokenA;
		IERC20 tokenB;
		}

    using EnumerableSet for EnumerableSet.Bytes32Set;


	// Keeps track of what pools have been whitelisted
	EnumerableSet.Bytes32Set private _whitelist;

	// A mapping from poolIDs to the underlying TokenPair
	mapping(bytes32=>TokenPair) public underlyingPoolTokens;

	// The maximum number of pools that can be whitelisted at any one time.
	// If the maximum number of pools is reached, some tokens will need to be delisted before new ones can be whitelisted
	// Range: 20 to 100 with an adjustment of 10
	uint256 public maximumWhitelistedPools = 50;


	// Whitelist a given pair of tokens
	function whitelistPool( IERC20 tokenA, IERC20 tokenB ) public onlyOwner
		{
		require( _whitelist.length() < maximumWhitelistedPools, "Maximum number of whitelisted pools already reached" );
		require(tokenA != tokenB, "tokenA and tokenB cannot be the same token");

		bytes32 poolID = PoolUtils._poolIDOnly(tokenA, tokenB);

		// If this whitelist is new then remember the underlying tokens for the poolID
		if ( _whitelist.add(poolID) )
			underlyingPoolTokens[poolID] = TokenPair(tokenA, tokenB);
		}


	function unwhitelistPool( IERC20 tokenA, IERC20 tokenB ) public onlyOwner
		{
		bytes32 poolID = PoolUtils._poolIDOnly(tokenA,tokenB);

		_whitelist.remove(poolID);

		// underlyingPoolTokens still maps the poolID to the underlying tokens - but that is not authoratative for whitelisting
		}


	function changeMaximumWhitelistedPools(bool increase) public onlyOwner
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
        }


	// === VIEWS ===

	function numberOfWhitelistedPools() public view returns (uint256)
		{
		return _whitelist.length();
		}


	function isWhitelisted( bytes32 poolID ) public view returns (bool)
		{
		// The staked SALT pool is always considered whitelisted
		if ( poolID == PoolUtils.STAKED_SALT )
			return true;

		return _whitelist.contains( poolID );
		}


	// Return an array of the currently whitelisted poolIDs
	function whitelistedPools() public view returns (bytes32[] memory)
		{
		return _whitelist.values();
		}


	function underlyingTokenPair( bytes32 poolID ) public view returns (IERC20 tokenA, IERC20 tokenB)
		{
		TokenPair memory pair = underlyingPoolTokens[poolID];
		require(address(pair.tokenA) != address(0) && address(pair.tokenB) != address(0), "This poolID does not exist");

		return (pair.tokenA, pair.tokenB);
		}


	// Returns true if the token has been whitelisted (meaning it has been pooled with either WBTC and WETH)
	function tokenHasBeenWhitelisted( IERC20 token, IERC20 wbtc, IERC20 weth ) public view returns (bool)
		{
		// See if the token has been whitelisted with either WBTC or WETH, as all whitelisted tokens are pooled with both WBTC and WETH
		bytes32 poolID1 = PoolUtils._poolIDOnly( token, wbtc );
		bytes32 poolID2 = PoolUtils._poolIDOnly( token, weth );

		// || is used conservatively here: && should really work as all whitelisted tokens are paired with both WBTC and WETH.
		return isWhitelisted(poolID1) || isWhitelisted(poolID2);
		}
	}