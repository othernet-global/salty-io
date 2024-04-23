// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "../pools/interfaces/IPoolsConfig.sol";
import "../interfaces/IExchangeConfig.sol";
import "./interfaces/IStakingConfig.sol";
import "../pools/interfaces/IPools.sol";
import "./interfaces/ILiquidity.sol";
import "./StakingRewards.sol";
import "../pools/PoolMath.sol";
import "../pools/PoolUtils.sol";


// Allows users to add liquidity and increase their liquidity share in the StakingRewards pool so that they can receive proportional future rewards.
// Keeps track of the liquidity held by each user via StakingRewards.userShare.

contract Liquidity is ILiquidity, StakingRewards
    {
	using SafeERC20 for IERC20;

	IPools immutable public pools;


	constructor( IPools _pools, IExchangeConfig _exchangeConfig, IPoolsConfig _poolsConfig, IStakingConfig _stakingConfig )
		StakingRewards( _exchangeConfig, _poolsConfig, _stakingConfig )
		{
		pools = _pools;
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
		(uint256 swapAmountA, uint256 swapAmountB ) = PoolMath._determineZapSwapAmount( reserveA, reserveB, zapAmountA, zapAmountB );

		// tokenA is in excess so swap some of it to tokenB?
		if ( swapAmountA > 0)
			{
			// https://github.com/code-423n4/2024-01-salty/blob/main/bot-report.md#l-02
			if ( tokenA.allowance(address(this), address(pools) ) > 0 )
				tokenA.safeApprove( address(pools), 0 );

			tokenA.safeApprove( address(pools), swapAmountA );

			// Swap from tokenA to tokenB and adjust the zapAmounts
			zapAmountA -= swapAmountA;
			zapAmountB += pools.depositZapSwapWithdraw( tokenA, tokenB, swapAmountA );
			}

		// tokenB is in excess so swap some of it to tokenA?
		else if ( swapAmountB > 0)
			{
			// https://github.com/code-423n4/2024-01-salty/blob/main/bot-report.md#l-02
			if ( tokenB.allowance(address(this), address(pools) ) > 0 )
				tokenB.safeApprove( address(pools), 0 );

			tokenB.safeApprove( address(pools), swapAmountB );

			// Swap from tokenB to tokenA and adjust the zapAmounts
			zapAmountB -= swapAmountB;
			zapAmountA += pools.depositZapSwapWithdraw( tokenB, tokenA, swapAmountB );
			}

		return (zapAmountA, zapAmountB);
		}


	// Add a certain amount of liquidity to the specified pool and increase the user's liquidity share for that pool so that they can receive future rewards.
	// With zapping, all the tokens specified by the user are added to the liquidity pool regardless of their ratio.
	// If one of the tokens has excess in regards to the reserves token ratio, then some of it is first swapped for the other before the liquidity is added. (See PoolMath.sol for details)
	// Requires exchange access for the user.
	function depositLiquidityAndIncreaseShare( IERC20 tokenA, IERC20 tokenB, uint256 maxAmountA, uint256 maxAmountB, uint256 minAddedAmountA, uint256 minAddedAmountB, uint256 minAddedLiquidity, uint256 deadline, bool useZapping ) external nonReentrant ensureNotExpired(deadline) returns (uint256 addedLiquidity)
		{
		require( exchangeConfig.walletHasAccess(msg.sender), "Sender does not have exchange access" );

		// Transfer the specified maximum amount of tokens from the user
		tokenA.safeTransferFrom(msg.sender, address(this), maxAmountA );
		tokenB.safeTransferFrom(msg.sender, address(this), maxAmountB );

		// Balance the token amounts by swapping one to the other before adding the liquidity?
		if ( useZapping )
			(maxAmountA, maxAmountB) = _dualZapInLiquidity(tokenA, tokenB, maxAmountA, maxAmountB );

		// Approve the liquidity to add

		// https://github.com/code-423n4/2024-01-salty/blob/main/bot-report.md#l-02
		if ( tokenA.allowance(address(this), address(pools) ) > 0 )
			tokenA.safeApprove(address(pools), 0 );

		if ( tokenB.allowance(address(this), address(pools) ) > 0 )
			tokenB.safeApprove(address(pools), 0 );

		tokenA.safeApprove( address(pools), maxAmountA );
		tokenB.safeApprove( address(pools), maxAmountB );

		uint256 addedAmountA;
		uint256 addedAmountB;

			{
			// Deposit the specified liquidity into the Pools contract
			// The added liquidity will be owned by this contract. (external call to Pools contract)
			bytes32 poolID = PoolUtils._poolID( tokenA, tokenB );

			(addedAmountA, addedAmountB, addedLiquidity) = pools.addLiquidity( tokenA, tokenB, maxAmountA, maxAmountB, minAddedAmountA, minAddedAmountB, totalShares[poolID]);

			// Make sure the user receives a sufficient share of liquidity
			require( addedLiquidity >= minAddedLiquidity, "Insufficient liquidity added" );

			// Increase the user's liquidity share by the amount of addedLiquidity.
			// Cooldown is specified to prevent reward hunting (ie - quickly depositing and withdrawing large amounts of liquidity to snipe rewards as they arrive)
			// _increaseUserShare confirms the pool as whitelisted as well.
			_increaseUserShare( msg.sender, poolID, addedLiquidity, true );
			}

		// If any of the user's tokens were not used, then send them back
		if ( addedAmountA < maxAmountA )
			tokenA.safeTransfer( msg.sender, maxAmountA - addedAmountA );

		if ( addedAmountB < maxAmountB )
			tokenB.safeTransfer( msg.sender, maxAmountB - addedAmountB );
		}


	// Withdraw specified liquidity, decrease the user's liquidity share and claim any pending rewards.
    function withdrawLiquidityAndClaim( IERC20 tokenA, IERC20 tokenB, uint256 liquidityToWithdraw, uint256 minReclaimedA, uint256 minReclaimedB, uint256 deadline ) external nonReentrant ensureNotExpired(deadline) returns (uint256 reclaimedA, uint256 reclaimedB)
		{
		bytes32 poolID = PoolUtils._poolID( tokenA, tokenB );
		require( userShareForPool(msg.sender, poolID) >= liquidityToWithdraw, "Cannot withdraw more than existing user share" );

		// Remove the amount of liquidity specified by the user.
		// The liquidity in the pool is currently owned by this contract. (external call)
		(reclaimedA, reclaimedB) = pools.removeLiquidity( tokenA, tokenB, liquidityToWithdraw, minReclaimedA, minReclaimedB, totalShares[poolID] );

		// Transfer the reclaimed tokens to the user
		tokenA.safeTransfer( msg.sender, reclaimedA );
		tokenB.safeTransfer( msg.sender, reclaimedB );

		// Reduce the user's liquidity share for the specified pool so that they receive less rewards.
		// Cooldown is specified to prevent reward hunting (ie - quickly depositing and withdrawing large amounts of liquidity to snipe rewards)
		// This call will send any pending SALT rewards to msg.sender as well.
		_decreaseUserShare( msg.sender, poolID, liquidityToWithdraw, true );
		}
	}