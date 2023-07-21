// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.20;


interface ICalledContract
	{
    function callFromDAO(uint256) external;
	}