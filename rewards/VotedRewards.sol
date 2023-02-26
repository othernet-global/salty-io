// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.17;

import "../openzeppelin/security/ReentrancyGuard.sol";
import "../Upkeepable.sol";
import "./RewardsEmitter.sol";
import "./RewardsConfig.sol";


// Stores SALT and distributes it at upkeep to RewardsEmitter.sol for all [poolIDs][isLP=true]
// based on the votes that each pool has received at the moment of upkeep.
// Only stores the SALT rewards transferred in since the last upkeep.

contract VotedRewards is ReentrancyGuard, Upkeepable
    {
	RewardsConfig rewardsConfig;


    constructor( address _rewardsConfig )
		{
		rewardsConfig = RewardsConfig( _rewardsConfig );
		}


	function performUpkeep() internal override
		{
		}
	}
