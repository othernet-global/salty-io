// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.12;

import "../interfaces/ICalledContract.sol";


contract TestCallReceiver is ICalledContract
    {
    uint256 public value;


    function callFromDAO(uint256 n ) external
    	{
    	value = n;
    	}
	}