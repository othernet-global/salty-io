// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.20;


interface IAccessManager
	{
	function setCountry( string calldata country ) external;
	function walletHasAccess( address wallet ) external view returns (bool);
	}
