// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.21;


interface IEmissions
	{
	function performUpkeep( uint256 timeSinceLastUpkeep ) external;
    }