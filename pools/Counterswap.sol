// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "../openzeppelin/token/ERC20/IERC20.sol";


// Counterswaps allow the protocol to swap one given token for another in a way that doesn't impact the market directly.
// It is done by waiting for users to swap in the opposiite direction and then swapping in the desired direction - essentially restoring the reserves to where they were before the user swap.
// This is done to gradually swap WETH to Protocol Owned Liquidity and liquidated WBTC/WETH colalteral to USDS so that it can be burned.
// Counterswap deposits to the Pools contract are owned by the constant addresses below.

library Counterswap
	{
	// Counterswap addresses which own deposited tokens in the Pools contract
	address constant public WETH_TO_WBTC = address(bytes20(uint160(uint256(keccak256('counterswap weth to wbtc')))));
	address constant public WETH_TO_SALT = address(bytes20(uint160(uint256(keccak256('counterswap weth to salt')))));
	address constant public WETH_TO_USDS = address(bytes20(uint160(uint256(keccak256('counterswap weth to usds')))));
	address constant public WBTC_TO_USDS = address(bytes20(uint160(uint256(keccak256('counterswap wbtc to usds')))));


	// Determine the counterswap address for swapping tokenToCounterswap->desiredToken
	// Determine the counterswap address for swapping tokenToCounterswap->desiredToken
	function _determineCounterswapAddress( IERC20 tokenToCounterswap, IERC20 desiredToken, IERC20 wbtc, IERC20 weth, IERC20 salt, IERC20 usds ) internal view returns (address counterswapAddress)
		{
		if ( address(tokenToCounterswap) == address(weth) )
			{
			if ( address(desiredToken) == address(wbtc) )
				return WETH_TO_WBTC;
			if ( address(desiredToken) == address(salt) )
				return WETH_TO_SALT;
			if ( address(desiredToken) == address(usds) )
				return WETH_TO_USDS;
			}

		if ( (address(tokenToCounterswap) == address(wbtc)) && (address(desiredToken) == address(usds)) )
			return WBTC_TO_USDS;

		return address(0);
		}
	}