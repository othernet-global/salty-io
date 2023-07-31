// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.21;


// Performs upkeep on the exchange, handling various housekeeping functions such as:
// Emissions - distributing SALT rewards to the stakingRewardsEmitter and liquidityRewardsEmitter
// ArbitrageSearch - converting previous arbitrage profits from WETH to SALT and sending them to the releveant RewardsEmitters
// RewardsEmitters - for staking, liquidity and collateral SALT rewards distribution.
// Liquidator - liquidating any LP that is currently being held in the Liquidator contract, burning the required amount of USDS and sending extra WETH to the POL_Optimizer.
// POL_Optimizer - forming optimized Protocol Owned Liquidity with the WETH it has been sent.
// DAO - staking any LP that was sent to it by the POL_Optimizer.

// The caller of performUpkeep receives a share of the DAO Protocol Owned Liquidity profits that are claimed during the upkeep and also
// receives any WETH (swapped to SALT) that was sent by the ArbitrageSearch on its performUpkeep.

contract UpkeepPerformer
    {
	uint256 public lastUpkeepTime;


    constructor()
		{
		lastUpkeepTime = block.timestamp;
		}


	function _performUpkeep() internal
		{
		uint256 timeSinceLastUpkeep = block.timestamp - lastUpkeepTime;

		// Send a portion of the current WETH balance to the msg.sender

		lastUpkeepTime = block.timestamp;
		}
	}
