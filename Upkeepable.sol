// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.17;

import "./openzeppelin/access/Ownable.sol";
import "./openzeppelin/security/ReentrancyGuard.sol";


// Keep track of how long it's been since the last performUpkeep0 call and calls performUpkeep
abstract contract Upkeepable is ReentrancyGuard
    {
	uint256 lastUpkeepTime;


    constructor()
		{
		lastUpkeepTime = block.timestamp;
		}


	function timeSinceLastUpkeep() public view returns (uint256)
		{
		return block.timestamp - lastUpkeepTime;
		}


	function performUpkeep() internal virtual
		{
		require( false, "performUpkeep() needs to be overriden" );
		}


	// Called by Upkeep.sol directly
	function performUpkeep0() public nonReentrant
		{
		performUpkeep();

		lastUpkeepTime = block.timestamp;
		}
	}
