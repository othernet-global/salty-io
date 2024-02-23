// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "../../staking/interfaces/ILiquidity.sol";
import "../../dao/interfaces/IDAO.sol";
import "./IPoolStats.sol";


interface IPools is IPoolStats
	{
	function startExchangeApproved() external;
	function setContracts( IDAO _dao, ILiquidity _liquidity ) external; // onlyOwner

	function addLiquidity( IERC20 tokenA, IERC20 tokenB, uint256 maxAmountA, uint256 maxAmountB, uint256 minAddedAmountA, uint256 minAddedAmountB, uint256 totalLiquidity ) external returns (uint256 addedAmountA, uint256 addedAmountB, uint256 addedLiquidity);
	function removeLiquidity( IERC20 tokenA, IERC20 tokenB, uint256 liquidityToRemove, uint256 minReclaimedA, uint256 minReclaimedB, uint256 totalLiquidity ) external returns (uint256 reclaimedA, uint256 reclaimedB);

	function deposit( IERC20 token, uint256 amount ) external;
	function withdraw( IERC20 token, uint256 amount ) external;
	function swap( IERC20 swapTokenIn, IERC20 swapTokenOut, uint256 swapAmountIn, uint256 minAmountOut, uint256 deadline ) external returns (uint256 swapAmountOut);
	function depositSwapWithdraw(IERC20 swapTokenIn, IERC20 swapTokenOut, uint256 swapAmountIn, uint256 minAmountOut, uint256 deadline ) external returns (uint256 swapAmountOut);
	function depositDoubleSwapWithdraw( IERC20 swapTokenIn, IERC20 swapTokenMiddle, IERC20 swapTokenOut, uint256 swapAmountIn, uint256 minAmountOut, uint256 deadline ) external returns (uint256 swapAmountOut);

	// Views
	function exchangeIsLive() external view returns (bool);
	function getPoolReserves(IERC20 tokenA, IERC20 tokenB) external view returns (uint256 reserveA, uint256 reserveB);
	function depositedUserBalance(address user, IERC20 token) external view returns (uint256);
	}

