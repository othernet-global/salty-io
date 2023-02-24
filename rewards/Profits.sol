// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.17;

import "../openzeppelin/security/ReentrancyGuard.sol";
import "../openzeppelin/token/ERC20/ERC20.sol";
import "../staking/Staking.sol";
import "../Config.sol";
import "../Upkeepable.sol";


// Responsible for storing profits as USDC and distributing them during upkeep
// Only the USDC since the last upkeep will be stored in the contract
contract Profits is Upkeepable
    {
    Config config;

	// The share of the stored USDC that is sent to the caller of Upkeep.performUpkeep()
	uint256 public upkeepPercentTimes1000 = 1 * 1000; // x1000 for precision


	ERC20 public usdc;


    constructor( address _config, address _usdc )
		{
		config = Config( _config );
		usdc = ERC20( _usdc );
		}


	// The rewards (in USDC) that will be sent to tx.origin for calling Upkeep.performUpkeep()
	function currentUpkeepRewards() public view returns (uint256)
		{
		return ( config.usdc().balanceOf( address( this ) ) * config.upkeepPercentTimes1000() ) / ( 100 * 1000 );
		}


	function performUpkeep() internal override
		{
		ERC20 usdc = config.usdc();

		uint256 usdcBalance = usdc.balanceOf( address( this ) );

		if ( usdcBalance == 0 )
			return;

		uint256 upkeepRewards = currentUpkeepRewards();

		// Send some USDC to the caller of Upkeep.performUpkeep();
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
	}
