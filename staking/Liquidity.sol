// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.12;

import "../openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IStakingConfig.sol";
import "./StakingRewards.sol";
import "../interfaces/IExchangeConfig.sol";
import "./interfaces/ILiquidity.sol";
import "../pools/interfaces/IPools.sol";
import "../pools/interfaces/IPoolsConfig.sol";
import "../pools/PoolUtils.sol";


// Allows users to deposit and stake liquidity to receive a share of the rewards for that pool
contract Liquidity is ILiquidity, StakingRewards
    {
	using SafeERC20 for IERC20;

	IPools public pools;


	constructor( IPools _pools, IExchangeConfig _exchangeConfig, IPoolsConfig _poolsConfig, IStakingConfig _stakingConfig )
		StakingRewards( _exchangeConfig, _poolsConfig, _stakingConfig )
		{
		require( address(_pools) != address(0), "_pools cannot be address(0)" );

		pools = _pools;
		}


	// Add a certain amount of liquidity to the specified pool and stake the added liquidity within this contract for future rewards.
	// Requires that the sending wallet has exchange access and that the pool is whitelisted
	function addAndDepositLiquidity( IERC20 tokenA, IERC20 tokenB, uint256 maxAmountA, uint256 maxAmountB, uint256 minLiquidityReceived, uint256 deadline, bool bypassZapSwap ) public nonReentrant returns (uint256 addedAmountA, uint256 addedAmountB, uint256 addedLiquidity)
		{
		// Rememebr the initial underlying token balances so we can determine if any of the tokens remain after the liquidity is added
		uint256 startingBalanceA = tokenA.balanceOf( address(this) );
		uint256 startingBalanceB = tokenB.balanceOf( address(this) );

		// Transfer the maximum amount of tokens from the user
		// Any extra underlying tokens after the liquidity is added will be sent back to the user
		tokenA.safeTransferFrom(msg.sender, address(this), maxAmountA );
		tokenB.safeTransferFrom(msg.sender, address(this), maxAmountB );

		// Zap in the specified liquidity (with the optional bypassZapSwap which will then just be a strict addLiquidity call)
		tokenA.approve( address(pools), maxAmountA );
		tokenB.approve( address(pools), maxAmountB );
		(addedAmountA, addedAmountB, addedLiquidity) = pools.dualZapInLiquidity( tokenA, tokenB, maxAmountA, maxAmountB, minLiquidityReceived, deadline, bypassZapSwap );

		(bytes32 poolID,) = PoolUtils.poolID( tokenA, tokenB );

		// Update the user's share of the rewards for the pool (where the pool will be confirmed as whitelisted)
		// Cooldown is specified to prevent reward hunting (quickly depositing and withdrawing liquidity to earn rewards)
   		_increaseUserShare( msg.sender, poolID, addedLiquidity, true );

		// Send any extra of the underlying tokens back to the user
		uint256 extraBalanceA = startingBalanceA - tokenA.balanceOf( address(this) );
		uint256 extraBalanceB = startingBalanceB - tokenB.balanceOf( address(this) );

		if ( extraBalanceA > 0 )
			tokenA.transfer( msg.sender, extraBalanceA );
		if ( extraBalanceB > 0 )
			tokenB.transfer( msg.sender, extraBalanceB );
		}


	// Withdraw liquidity and claim any pending rewards.
	// The DAO itself is not allowed to unstake liquidity
     function withdrawLiquidityAndClaim( IERC20 tokenA, IERC20 tokenB, uint256 liquidityToWithdraw, uint256 minReclaimedA, uint256 minReclaimedB, uint256 deadline ) public nonReentrant returns (uint256 reclaimedA, uint256 reclaimedB)
		{
		// Make sure that the DAO isn't trying to remove liquidity
		require( msg.sender != address(exchangeConfig.dao()), "DAO is not allowed to unstake LP tokens" );

		(bytes32 poolID,) = PoolUtils.poolID( tokenA, tokenB );

		// Update the user's share of the rewards for the specified pool
		// Note: _decreaseUserShare checks to make sure the user has the specified share
		_decreaseUserShare( msg.sender, poolID, liquidityToWithdraw, true );

		// Remove the amount of liquidity specified by the user
		(reclaimedA, reclaimedB) = pools.removeLiquidity( tokenA, tokenB, liquidityToWithdraw, minReclaimedA, minReclaimedB, deadline );
		}
	}