// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IStakingConfig.sol";
import "./StakingRewards.sol";
import "../interfaces/IExchangeConfig.sol";
import "./interfaces/ILiquidity.sol";
import "../pools/interfaces/IPools.sol";
import "../pools/interfaces/IPoolsConfig.sol";
import "../pools/PoolUtils.sol";
import "../pools/PoolMath.sol";


// Allows users to add liquidity and increase their liquidity share in the StakingRewards pool so that they can receive proportional future rewards.
// Keeps track of the liquidity held by each user via StakingRewards.userShare

contract Liquidity is ILiquidity, StakingRewards
    {
	using SafeERC20 for IERC20;

	IPools immutable public pools;

	// The poolID of WBTC/WETH collateral - which should not be withdrawable from this contract directly
    bytes32 immutable public collateralPoolID;


	constructor( IPools _pools, IExchangeConfig _exchangeConfig, IPoolsConfig _poolsConfig, IStakingConfig _stakingConfig )
		StakingRewards( _exchangeConfig, _poolsConfig, _stakingConfig )
		{
		require( address(_pools) != address(0), "_pools cannot be address(0)" );

		pools = _pools;

		collateralPoolID = PoolUtils._poolIDOnly( exchangeConfig.wbtc(), exchangeConfig.weth() );
		}


	modifier ensureNotExpired(uint deadline)
		{
		require(block.timestamp <= deadline, "TX EXPIRED");
		_;
		}


	// Deposit an arbitrary amount of one or both tokens into the pool and receive liquidity corresponding the the value of both of them.
	// As the ratio of tokens added to the pool has to be the same as the existing ratio of reserves, some of the excess token will be swapped to the other.
	// Due to precision reduction during zapping calculation, the minimum possible reserves and quantity possible to zap is .000101,
	function _dualZapInLiquidity(IERC20 tokenA, IERC20 tokenB, uint256 zapAmountA, uint256 zapAmountB ) internal returns (uint256 amountForLiquidityA, uint256 amountForLiquidityB  )
		{
		(uint256 reserveA, uint256 reserveB) = pools.getPoolReserves(tokenA, tokenB);
		(uint256 swapAmountA, uint256 swapAmountB ) = PoolMath._determineZapSwapAmount( reserveA, reserveB, tokenA, tokenB, zapAmountA, zapAmountB );

		bytes32 poolID = PoolUtils._poolIDOnly( tokenA, tokenB );

		// tokenA is in excess so swap some of it to tokenB?
		if ( swapAmountA > 0)
			{
			tokenA.approve( address(pools), swapAmountA );

			// Swap from tokenA to tokenB and adjust the zapAmounts
			zapAmountA -= swapAmountA;
			zapAmountB += pools.depositSwapWithdraw( tokenA, tokenB, swapAmountA, 0, block.timestamp, poolsConfig.isWhitelisted(poolID) );
			}

		// tokenB is in excess so swap some of it to tokenA?
		if ( swapAmountB > 0)
			{
			tokenB.approve( address(pools), swapAmountB );

			// Swap from tokenB to tokenA and adjust the zapAmounts
			zapAmountB -= swapAmountB;
			zapAmountA += pools.depositSwapWithdraw( tokenB, tokenA, swapAmountB, 0, block.timestamp, poolsConfig.isWhitelisted(poolID) );
			}

		return (zapAmountA, zapAmountB);
		}


	// Add a certain amount of liquidity to the specified pool and increase the user's liqudiity share for that pool so that they can receive future rewards.
	// With zapping, all the tokens specified by the user are added to the liqudiity pool regardless of their ratio.
	// If one of the tokens has excess in regards to the reserves token ratio, then some of it is first swapped for the other before the liquidity is added. (See PoolMath.sol for details)
	// bypassZapping allows this zapping to be avoided - which results in a simple addLiquidity call.
	function _depositLiquidityAndIncreaseShare( IERC20 tokenA, IERC20 tokenB, uint256 maxAmountA, uint256 maxAmountB, uint256 minLiquidityReceived, bool useZapping ) internal returns (uint256 addedAmountA, uint256 addedAmountB, uint256 addedLiquidity)
		{
		require( exchangeConfig.walletHasAccess(msg.sender), "Sender does not have exchange access" );

		// Remember the initial underlying token balances of this contract so we can later determine if any of the user's tokens are later unused after adding liquidity and should be sent back.
		uint256 startingBalanceA = tokenA.balanceOf( address(this) );
		uint256 startingBalanceB = tokenB.balanceOf( address(this) );

		// Transfer the specified maximum amount of tokens from the user
		tokenA.safeTransferFrom(msg.sender, address(this), maxAmountA );
		tokenB.safeTransferFrom(msg.sender, address(this), maxAmountB );

		// Balance the token token amounts by swapping one to the other before adding the liquidity?
		if ( useZapping )
			(maxAmountA, maxAmountB) = _dualZapInLiquidity(tokenA, tokenB, maxAmountA, maxAmountB );

		// Deposit the specified liquidity into the Pools contract
		// The added liquidity will be owned by this contract. (external call to Pools contract)
		tokenA.approve( address(pools), maxAmountA );
		tokenB.approve( address(pools), maxAmountB );

		// Avoid stack too deep
		bytes32 poolID = PoolUtils._poolIDOnly( tokenA, tokenB );
		(addedAmountA, addedAmountB, addedLiquidity) = pools.addLiquidity( tokenA, tokenB, maxAmountA, maxAmountB, minLiquidityReceived, totalSharesForPool(poolID));

		// Increase the user's liquidity share by the amount of addedLiquidity.
		// Cooldown is specified to prevent reward hunting (ie - quickly depositing and withdrawing large amounts of liquidity to snipe rewards as they arrive)
		// Here the pool will be confirmed as whitelisted as well.
		_increaseUserShare( msg.sender, poolID, addedLiquidity, true );

		// If any of the user's tokens were not used, then send them back
		if ( tokenA.balanceOf( address(this) ) > startingBalanceA )
			tokenA.safeTransfer( msg.sender, tokenA.balanceOf( address(this) ) - startingBalanceA );

		if ( tokenB.balanceOf( address(this) ) > startingBalanceB )
			tokenB.safeTransfer( msg.sender, tokenB.balanceOf( address(this) ) - startingBalanceB );
		}


	// Public wrapper for adding liquidity which prevents the direct deposit to the collateral pool.
	// CollateralAndLiquidity.sol.depositCollateralAndIncreaseShare bypasses this and calls _depositLiquidityAndIncreaseShare directly.
	// Requires exchange access for the sending wallet
	function depositLiquidityAndIncreaseShare( IERC20 tokenA, IERC20 tokenB, uint256 maxAmountA, uint256 maxAmountB, uint256 minLiquidityReceived, uint256 deadline, bool useZapping ) public ensureNotExpired(deadline)  nonReentrant returns (uint256 addedAmountA, uint256 addedAmountB, uint256 addedLiquidity)
		{
		require( PoolUtils._poolIDOnly( tokenA, tokenB ) != collateralPoolID, "Stablecoin collateral cannot be deposited via Liquidity.depositLiquidityAndIncreaseShare" );

    	return _depositLiquidityAndIncreaseShare(tokenA, tokenB, maxAmountA, maxAmountB, minLiquidityReceived, useZapping);
		}


	// Withdraw specified liquidity, decrease the user's liquidity share and claim any pending rewards.
	// The DAO itself is not allowed to withdraw collateralAndLiquidity.
    function _withdrawLiquidityAndClaim( IERC20 tokenA, IERC20 tokenB, uint256 liquidityToWithdraw, uint256 minReclaimedA, uint256 minReclaimedB ) internal returns (uint256 reclaimedA, uint256 reclaimedB)
		{
		// Make sure that the DAO isn't trying to remove liquidity
		require( msg.sender != address(exchangeConfig.dao()), "DAO is not allowed to withdraw liquidity" );

		bytes32 poolID = PoolUtils._poolIDOnly( tokenA, tokenB );
		require( userShareForPool(msg.sender, poolID) >= liquidityToWithdraw, "Cannot withdraw more than existing user share" );

		// Reduce the user's liqudiity share for the specified pool so that they receive less rewards.
		// Cooldown is specified to prevent reward hunting (ie - quickly depositing and withdrawing large amounts of liquidity to snipe rewards)
		// This call will send any pending SALT rewards to msg.sender as well.

		// Remove the amount of liquidity specified by the user.
		// The liquidity in the pool is currently owned by this contract. (external call)
		(reclaimedA, reclaimedB) = pools.removeLiquidity( tokenA, tokenB, liquidityToWithdraw, minReclaimedA, minReclaimedB, totalSharesForPool(poolID) );

		// Transfer the reclaimed tokens to the user
		tokenA.safeTransfer( msg.sender, reclaimedA );
		tokenB.safeTransfer( msg.sender, reclaimedB );

		// Note: _decreaseUserShare checks to make sure that the user has the specified liquidity share.
		_decreaseUserShare( msg.sender, poolID, liquidityToWithdraw, true );
		}


	// Public wrapper for withdrawing liquidity which prevents the direct withdrawal from the collateral pool.
	// CollateralAndLiquidity.sol.withdrawCollateralAndClaim bypasses this and calls _withdrawLiquidityAndClaim directly.
    function withdrawLiquidityAndClaim( IERC20 tokenA, IERC20 tokenB, uint256 liquidityToWithdraw, uint256 minReclaimedA, uint256 minReclaimedB, uint256 deadline ) public ensureNotExpired(deadline)  nonReentrant returns (uint256 reclaimedA, uint256 reclaimedB)
    	{
		require( PoolUtils._poolIDOnly( tokenA, tokenB ) != collateralPoolID, "Stablecoin collateral cannot be withdrawn via Liquidity.withdrawLiquidityAndClaim" );

    	return _withdrawLiquidityAndClaim(tokenA, tokenB, liquidityToWithdraw, minReclaimedA, minReclaimedB);
    	}
	}