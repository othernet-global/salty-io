// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.12;

import "./openzeppelin/security/ReentrancyGuard.sol";


// Keep track of how long it's been since the last performUpkeep0 call and calls performUpkeep
abstract contract Upkeepable is ReentrancyGuard
    {
	uint256 public lastUpkeepTime;


    constructor()
		{
		lastUpkeepTime = block.timestamp;
		}


	function timeSinceLastUpkeep() public view returns (uint256)
		{
		return block.timestamp - lastUpkeepTime;
		}


	function _performUpkeep() internal virtual
		{
		require( false, "performUpkeep() needs to be overridden" );
		}


	function performUpkeep() public nonReentrant
		{
		_performUpkeep();

		lastUpkeepTime = block.timestamp;
		}
	}
