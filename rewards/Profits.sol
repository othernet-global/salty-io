// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.17;

import "../openzeppelin/security/ReentrancyGuard.sol";
import "../openzeppelin/token/ERC20/ERC20.sol";
import "../staking/Staking.sol";
import "../Config.sol";
import "../Upkeepable.sol";
import "../Exchange.sol";
import "./RewardsEmitter.sol";


// Responsible for storing profits as USDC and distributing them during upkeep
// Only the USDC since the last upkeep will be stored in the contract
contract Profits is Upkeepable
    {
    Config config;
    Staking staking;
    RewardsEmitter rewardsEmitter;


    constructor( address _config, address _staking, address _rewardsEmitter )
		{
		config = Config( _config );
		staking = Staking( _staking );
		rewardsEmitter = RewardsEmitter( _rewardsEmitter );
		}


	// The rewards (in USDC) that will be sent to tx.origin for calling Upkeep.performUpkeep()
	function currentUpkeepRewards() public view returns (uint256)
		{
		return ( usdc.balanceOf( address( this ) ) * config.upkeepPercent() ) / ( 100 * 1000 );
		}


	function performUpkeep() internal override
		{
		uint256 usdcBalance = usdc.balanceOf( address( this ) );

		if ( usdcBalance == 0 )
			return;

		uint256 upkeepRewards = currentUpkeepRewards();

		// Send some USDC to the caller of Upkeep.performUpkeep();
		usdc.transfer( tx.origin, upkeepRewards );

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
	}
