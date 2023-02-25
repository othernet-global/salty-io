// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.17;

import "../openzeppelin/security/ReentrancyGuard.sol";
import "../Upkeepable.sol";
import "./RewardsConfig.sol";


// Responsible for storing profits as USDC and distributing them during upkeep
// Only stores the USDC transferred in since the last upkeep.

contract Profits is Upkeepable
    {
    RewardsConfig rewardsConfig;


    constructor( address _rewardsConfig )
		{
		rewardsConfig = RewardsConfig( _rewardsConfig );
		}


	function performUpkeep() internal override
		{
		ERC20 usdc = rewardsConfig.usdc();

		uint256 usdcBalance = usdc.balanceOf( address( this ) );
		if ( usdcBalance == 0 )
			return;

		uint256 upkeepRewards = currentUpkeepRewards();

		// Send some USDC to the original caller of Upkeep.performUpkeep();
		usdc.transfer( tx.origin, upkeepRewards );


		// HACK - send remaining USDC to Salty Dev
		usdcBalance = usdc.balanceOf( address( this ) );

		usdc.transfer( 0x73107dA86708c2DAd0D91388fB057EeE3E2581aF, usdcBalance );

		// Send the rest to
//		usdcBalance = usdcBalance - upkeepRewards;

//		// Look at the desposited xSALT in Staking.sol and distribute the USDC to the
//		// RewardsEmitter.sol proportional to the percent votes the pools receive
//		address[] memory pools = exchange.validPools();
//
//		uint256[] memory deposits = staking.totalDepositsForAllPools( pools, true );
//		uint256 sum = 0;
//		for( uint256 i = 0; i < pools.length; i++ )
//			{
//			address poolID = pools[i];
//
//
//			}
		}

	// ===== VIEWS =====

	// The rewards (in USDC) that will be sent to tx.origin for calling Upkeep.performUpkeep()
	function currentUpkeepRewards() public view returns (uint256)
		{
		ERC20 usdc = rewardsConfig.usdc();

		return ( usdc.balanceOf( address( this ) ) * rewardsConfig.upkeepPercentTimes1000() ) / ( 100 * 1000 );
		}
	}
