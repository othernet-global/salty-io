pragma solidity ^0.8.12;

import "../openzeppelin/token/ERC20/IERC20.sol";


contract ArbManager
	{
	address public ARB_MANAGER;


	constructor()
		{
		ARB_MANAGER = address(this);
		}


	function _updateArbitrageStats( bytes32[] memory arbPathPoolIDs, uint256 arbProfit ) internal
		{
		}
	}
