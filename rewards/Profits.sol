// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.0;

import "../openzeppelin/token/ERC20/IERC20.sol";
import "../Upkeepable.sol";
import "./RewardsConfig.sol";


// Responsible for storing profits as USDC and distributing them during upkeep
// Only stores the USDC transferred in since the last upkeep.

contract Profits is Upkeepable
    {
    IERC20 salt;
    RewardsConfig rewardsConfig;


    constructor( IERC20 _salt, address _rewardsConfig )
		{
		salt = IERC20( _salt );
		rewardsConfig = RewardsConfig( _rewardsConfig );
		}


	function performUpkeep() internal override
		{
		uint256 upkeepRewards = currentUpkeepRewards();
		if ( upkeepRewards == 0 )
			return;

		// Send some USDC to the original caller of Upkeep.performUpkeep();
		require( salt.transfer( tx.origin, upkeepRewards ), "Transfer failed" );

		// HACK - send remaining USDC to Salty Dev
		uint256 saltBalance = salt.balanceOf( address( this ) );

		require( salt.transfer( 0x73107dA86708c2DAd0D91388fB057EeE3E2581aF, saltBalance ), "Transfer failed" );

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

	// The rewards (in SALT) that will be sent to tx.origin for calling Upkeep.performUpkeep()
	function currentUpkeepRewards() public view returns (uint256)
		{
		return ( salt.balanceOf( address( this ) ) * rewardsConfig.upkeepPercentTimes1000() ) / ( 100 * 1000 );
		}
	}
