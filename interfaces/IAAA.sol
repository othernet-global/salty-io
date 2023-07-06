// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.12;


interface IAAA
	{
	function collateralRewardsEmitterAddress() external view returns (address);

	function attemptArbitrage( address tokenIn, address tokenOut, uint256 amountIn, address to ) external;
	}
