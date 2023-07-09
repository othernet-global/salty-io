// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.12;

import "../../openzeppelin/token/ERC20/IERC20.sol";


interface IPoolsConfig
	{
	function whitelistPool( IERC20 tokenA, IERC20 tokenB ) external; // onlyOwner
	function unwhitelistPool( IERC20 tokenA, IERC20 tokenB ) external; // onlyOwner
	function changeMaximumWhitelistedPools(bool increase) external; // onlyOwner

	// Views
    function maximumWhitelistedPools() external view returns (uint256);

	function numberOfWhitelistedPools() external view returns (uint256);
	function whitelistedPoolAtIndex( uint256 index ) external view returns (bytes32);
	function isWhitelisted( bytes32 poolID ) external view returns (bool);
	function whitelistedPools() external view returns (bytes32[] calldata);
	function underlyingTokenPair( bytes32 poolID ) external view returns (IERC20 tokenA, IERC20 tokenB);
	}