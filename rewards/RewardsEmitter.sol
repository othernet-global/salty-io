// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.17;

import "../openzeppelin/security/ReentrancyGuard.sol";
import "../staking/Staking.sol";
import "../Upkeepable.sol";


// Stores SALT rewards by pool/isLP and distributes them at a default rate of 10% per day to Staking.sol
// Only the SALT since the last upkeep will be stored in the contract
contract RewardsEmitter is ReentrancyGuard, Upkeepable
    {
    // The stored SALT rewards by pool/isLP that need to be distributed to Staking.sol
   	mapping(address=>mapping(bool=>uint256)) totalRewards;					// [poolID][isLP]


	Staking staking;


    constructor( address _staking )
		{
		staking = Staking( _staking );
		}


	function performUpkeep() internal override
		{
		}
	}
