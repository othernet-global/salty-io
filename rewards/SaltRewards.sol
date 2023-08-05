// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.21;

import "../openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "../pools/interfaces/IPoolsConfig.sol";
import "../rewards/interfaces/IRewardsEmitter.sol";
import "../rewards/interfaces/IRewardsConfig.sol";
import "../interfaces/ISalt.sol";
import "../interfaces/IExchangeConfig.sol";
import "./interfaces/ISaltRewards.sol";
import "../arbitrage/interfaces/IArbitrageProfits.sol";

// Temporarily holds SALT rewards from emissions and arbitrage profits during performUpkeep().
// Sends them to the stakingRewardsEmitter and liquidityRewardsEmitter (with proportions for the latter based on pool share in generating recent arbitrage profits).

contract SaltRewards is ISaltRewards
    {
	using SafeERC20 for ISalt;

	IPools immutable public pools;
	IExchangeConfig immutable public exchangeConfig;
	IRewardsConfig immutable public rewardsConfig;

	ISalt immutable public salt;

	// A special pool that represents staked SALT that is not associated with any particular pool.
	bytes32 public constant STAKED_SALT = bytes32(uint256(0));

    uint256 public pendingStakingRewards;
	uint256 public pendingLiquidityRewards;


    constructor( IPools _pools, IExchangeConfig _exchangeConfig, IRewardsConfig _rewardsConfig )
		{
		require( address(_pools) != address(0), "_pools cannot be address(0)" );
		require( address(_exchangeConfig) != address(0), "_exchangeConfig cannot be address(0)" );
		require( address(_rewardsConfig) != address(0), "_rewardsConfig cannot be address(0)" );

		pools = _pools;
		exchangeConfig = _exchangeConfig;
		rewardsConfig = _rewardsConfig;

		// Cached for efficiency
		salt = _exchangeConfig.salt();
		}


	// Add SALT rewards and indicate they will be split between staking and liquidity rewards.
	function addSALTRewards(uint256 amount) public
		{
		if ( amount == 0 )
			return;

		uint256 stakingAmount = ( amount * rewardsConfig.stakingRewardsPercent() ) / 100;
		uint256 liquidityAmount = amount - stakingAmount;

		pendingStakingRewards += stakingAmount;
		pendingLiquidityRewards += liquidityAmount;

		salt.safeTransferFrom( msg.sender, address(this), amount );
		}


	// Transfer SALT rewards to the liquidityRewardsEmitter proportional to pool share in generating recent arb profits.
	function _sendLiquidityRewards( bytes32[] memory poolIDs ) internal
		{
		// Pool share will be based on ArbitrageProfits.profitsFromPools
		uint256[] memory profitsForPools = IArbitrageProfits(address(pools)).profitsForPools( poolIDs );

		// Determine the total profits so we can calculate proportional share
		uint256 totalProfits = 0;
		for( uint256 i = 0; i < profitsForPools.length; i++ )
			totalProfits += profitsForPools[i];

		// No profits means nothing to send
		if ( totalProfits == 0 )
			return;

		// Send the specified amountToSend SALT proportional to the profits generated by each pool
		AddedReward[] memory addedRewards = new AddedReward[]( profitsForPools.length );
		for( uint256 i = 0; i < addedRewards.length; i++ )
			{
			uint256 rewardsForPool = ( pendingLiquidityRewards * profitsForPools[i] ) / totalProfits;

			addedRewards[i] = AddedReward( poolIDs[i], rewardsForPool );
			}

		// Send the SALT rewards to the LiquidityRewardsEmitter
		IRewardsEmitter liquidityRewardsEmitter = exchangeConfig.liquidityRewardsEmitter();
		salt.approve( address(liquidityRewardsEmitter), pendingLiquidityRewards );

		liquidityRewardsEmitter.addSALTRewards( addedRewards );
		}


	function performUpkeep( bytes32[] memory poolIDs ) public
		{
		require( msg.sender == address(exchangeConfig.dao()), "SaltRewards.performUpkeep only callable from the DAO contract" );

		if ( (pendingStakingRewards == 0) || (pendingLiquidityRewards == 0) )
			return;

		// Send SALT rewards to the stakingRewardsEmitter
		AddedReward[] memory addedRewards = new AddedReward[](1);
		addedRewards[0] = AddedReward( STAKED_SALT, pendingStakingRewards );

		IRewardsEmitter stakingRewardsEmitter = exchangeConfig.stakingRewardsEmitter();
		salt.approve( address(stakingRewardsEmitter), pendingStakingRewards );
		stakingRewardsEmitter.addSALTRewards( addedRewards );

		// Send the liquidity rewards to the liquidityRewardsEmitter
		_sendLiquidityRewards(poolIDs);

		// Clear the profits for pools that was used to distribute the above rewards
		IArbitrageProfits(address(pools)).clearProfitsForPools(poolIDs);

		pendingStakingRewards = 0;
		pendingLiquidityRewards = 0;
		}
	}
