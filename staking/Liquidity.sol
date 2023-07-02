//// SPDX-License-Identifier: BSL 1.1
//pragma solidity ^0.8.12;
//
//import "../openzeppelin/token/ERC20/utils/SafeERC20.sol";
//import "./interfaces/IStakingConfig.sol";
//import "./StakingRewards.sol";
//import "../interfaces/IExchangeConfig.sol";
//import "./interfaces/ILiquidity.sol";
//import "../../pools/interfaces/IPools.sol";
//
//// Allows users to stake  pool to receive a share of the rewards
//
//contract Liquidity is ILiquidity, StakingRewards
//    {
//	using SafeERC20 for IERC20;
//
//	IPools public pools;
//	IExchangeConfig public exchangeConfig;
//
//
//	constructor( IPools _pools, IStakingConfig _stakingConfig, IExchangeConfig _exchangeConfig )
//		StakingRewards( _stakingConfig )
//		{
//		require( address(_pools) != address(0), "_pools cannot be address(0)" );
//		require( address(_exchangeConfig) != address(0), "_exchangeConfig cannot be address(0)" );
//
//		pools = _pools;
//		exchangeConfig = _exchangeConfig;
//		}
//
//
//	// Add a certain amount of liquidity to the specified pool and stake the added liquidity within this contract for future rewards.
//	// Requires that the sending wallet has exchange access and that the pool is whitelisted
//	function addAndDepositLiquidity( IERC20 token0, IERC20 token1, uint256 maxAmount0, uint256 maxAmount1, uint256 minLiquidityReceived, uint256 deadline ) public nonReentrant returns (uint256 userLiquidity)
//		{
//		// Check allowances and transfer
//		require( erc20.allowance(msg.sender, address(this)) >= amountStaked, "Insufficient allowance to stake LP" );
//		require( erc20.balanceOf(msg.sender) >= amountStaked, "Insufficient balance to stake LP" );
//		erc20.safeTransferFrom(msg.sender, address(this), amountStaked );
//
//
//		// Don't allow unstaking the STAKED_SALT pool
//		require( poolID != STAKED_SALT, "Cannot stake on the STAKED_SALT pool" );
//
//		// Update the user's share of the rewards for the pool (must be whitelisted)
//   		_increaseUserShare( msg.sender, poolID, amountStaked, true );
//
//		// The Uniswap LP token address is the pool
//		IERC20 erc20 = IERC20( address(poolID) );
//
//		// Make sure there is no fee while transferring the token to this contract
//		uint256 beforeBalance = erc20.balanceOf( address(this) );
//
//
//		uint256 afterBalance = erc20.balanceOf( address(this) );
//		require( afterBalance == ( beforeBalance + amountStaked ), "Cannot stake tokens with a fee on transfer" );
//
//		emit eStakeLP( msg.sender, poolID, amountStaked );
//		}
//
//
//	// Unstake LP tokens and claim any pending rewards
//	// Does not check that the send has exchange access (in case they were excluded recently)
//	// The DAO itself is not allowed to unstake liquidity
//     function withdrawLiquidityAndClaim( IUniswapV2Pair pool, uint256 amountUnstaked ) public nonReentrant
//		{
//		// Don't allow unstaking the STAKED_SALT pool
//		require( pool != STAKED_SALT, "Cannot unstake on the STAKED_SALT pool" );
//
//		// Make sure that the DAO isn't trying to remove liquidity
//		require( msg.sender != address(exchangeConfig.dao()), "DAO is not allowed to unstake LP tokens" );
//
//		// Update the user's share of the rewards for the pool
//		// Balance checks are done here
//		_decreaseUserShare( msg.sender, pool, amountUnstaked, true );
//
//		// The pool is an ERC20 token
//		IERC20 erc20 = IERC20( address(pool) );
//
//		// Transfer the withdrawn token to the caller
//		// This error should never happen
//		require( erc20.balanceOf(address(this)) >= amountUnstaked, "Insufficient contract balance to withdraw" );
//		erc20.safeTransfer( msg.sender, amountUnstaked );
//
//		emit eUnstakeLP( msg.sender, pool, amountUnstaked );
//		}
//	}