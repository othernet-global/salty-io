// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.21;

import "../../openzeppelin/token/ERC20/IERC20.sol";
import "../../arbitrage/interfaces/IArbitrageSearch.sol";


interface IPoolsConfig
	{
	function whitelistPool( IERC20 tokenA, IERC20 tokenB ) external; // onlyOwner
	function unwhitelistPool( IERC20 tokenA, IERC20 tokenB ) external; // onlyOwner
	function setArbitrageSearch( IArbitrageSearch _arbitrageSearch ) external; // onlyOwner
	function changeMaximumWhitelistedPools(bool increase) external; // onlyOwner
	function changeDaoPercentShareArbitrage(bool increase) external; // onlyOwner

	// Views
	function arbitrageSearch() external view returns (IArbitrageSearch);

    function maximumWhitelistedPools() external view returns (uint256);
	function daoPercentShareArbitrage() external view returns (uint256);

	function numberOfWhitelistedPools() external view returns (uint256);
	function whitelistedPoolAtIndex( uint256 index ) external view returns (bytes32);
	function isWhitelisted( bytes32 poolID ) external view returns (bool);
	function whitelistedPools() external view returns (bytes32[] calldata);
	function underlyingTokenPair( bytes32 poolID ) external view returns (IERC20 tokenA, IERC20 tokenB);
	function tokenHasBeenWhitelisted( IERC20 token, IERC20 wbtc, IERC20 weth ) external view returns (bool);
	}