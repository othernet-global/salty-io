// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.12;

import "./openzeppelin/token/ERC20/ERC20.sol";
import "./openzeppelin/token/ERC20/IERC20.sol";
import "./pools/interfaces/IPools.sol";
import "./pools/interfaces/IPoolsConfig.sol";


contract Util
    {
	function functionExists( address _contract, string memory _functionName ) public returns (bool)
		{
		bytes4 FUNC_SELECTOR = bytes4(keccak256( bytes(_functionName) ));

		bool success;
		bytes memory data = abi.encodeWithSelector(FUNC_SELECTOR );

		uint256 remainingGas = gasleft();

		assembly {
			success := call(
				remainingGas,            // gas remaining
				_contract,         // destination address
				0,              // no ether
				add(data, 32),  // input buffer (starts after the first 32 bytes in the `data` array)
				mload(data),    // input length (loaded from the first 32 bytes in the `data` array)
				0,              // output buffer
				0               // output length
			)
		}

		return success;
	}


	function tokenNames( address[] memory tokens ) public view returns (string[] memory)
		{
		string[] memory names = new string[]( tokens.length );

		for( uint256 i = 0; i < tokens.length; i++ )
			{
			ERC20 token = ERC20( tokens[i] );

			names[i] = token.symbol();
			}

		return names;
		}


	function tokenDecimals( address[] memory tokens ) public view returns (uint256[] memory)
		{
		uint256[] memory decimals = new uint256[]( tokens.length );

		uint256 index;
		for( uint256 i = 0; i < tokens.length; i++ )
			{
			ERC20 token = ERC20( tokens[i] );

			decimals[ index++ ] = token.decimals();
			}

		return decimals;
		}


	function tokenSupplies( address[] memory tokens ) public view returns (uint256[] memory)
		{
		uint256[] memory supplies = new uint256[]( tokens.length );

		uint256 index;
		for( uint256 i = 0; i < tokens.length; i++ )
			{
			IERC20 pair = IERC20( tokens[i] );

			supplies[ index++ ] = pair.totalSupply();
			}

		return supplies;
		}


	function underlyingTokens( IPoolsConfig poolsConfig, bytes32[] memory poolIDs ) public view returns (address[] memory)
		{
		address[] memory tokens = new address[]( poolIDs.length * 2 );

		uint256 index;
		for( uint256 i = 0; i < poolIDs.length; i++ )
			{
			(IERC20 token0, IERC20 token1) = poolsConfig.underlyingTokenPair( poolIDs[i] );

			tokens[ index++ ] = address(token0);
			tokens[ index++ ] = address(token1);
			}

		return tokens;
		}


	function poolReserves( IPools pools, IPoolsConfig poolsConfig, bytes32[] memory poolIDs ) public view returns (uint256[] memory)
		{
		uint256[] memory reserves = new uint256[]( poolIDs.length * 2 );

		uint256 index;
		for( uint256 i = 0; i < poolIDs.length; i++ )
			{
			(IERC20 token0, IERC20 token1) = poolsConfig.underlyingTokenPair( poolIDs[i] );
			(uint256 reserve0, uint256 reserve1) = pools.getPoolReserves( token0, token1 );

			reserves[ index++ ] = reserve0;
			reserves[ index++ ] = reserve1;
			}

		return reserves;
		}



	function userBalances( address wallet, address[] memory tokenIDs ) public view  returns (uint256[] memory)
		{
		uint256[] memory balances = new uint256[]( tokenIDs.length );

		for( uint256 i = 0; i < tokenIDs.length; i++ )
			{
			IERC20 token = IERC20( tokenIDs[i] );

			balances[i] = token.balanceOf( wallet );
			}

		return balances;
		}
	}

