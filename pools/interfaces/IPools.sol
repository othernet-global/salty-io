// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.12;

import "../../openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "../../interfaces/IExchangeConfig.sol";
import "./IPoolsConfig.sol";


interface IPools
	{
	function addLiquidity( IERC20 tokenA, IERC20 tokenB, uint256 maxAmountA, uint256 maxAmountB, uint256 minLiquidityReceived, uint256 deadline ) external returns (uint256 addedAmountA, uint256 addedAmountB, uint256 addedLiquidity);
	function removeLiquidity( IERC20 tokenA, IERC20 tokenB, uint256 liquidityToRemove, uint256 minReclaimedA, uint256 minReclaimedB, uint256 deadline ) external returns (uint256 reclaimedA, uint256 reclaimedB);
	function deposit( IERC20 token, uint256 amount ) external;
	function withdraw( IERC20 token, uint256 amount ) external;
	function swap( IERC20[] calldata tokens, uint256 amountIn, uint256 minAmountOut, uint256 deadline ) external returns (uint256 amountOut);
	function depositSwapWithdraw(IERC20 tokenIn, IERC20 tokenOut, uint256 amountIn, uint256 minAmountOut, uint256 deadline) external returns (uint256 amountOut);
	function dualZapInLiquidity(IERC20 tokenA, IERC20 tokenB, uint256 zapAmountA, uint256 zapAmountB, uint256 minLiquidityReceived, uint256 deadline, bool bypassSwap ) external returns (uint256 addedAmountA, uint256 addedAmountB, uint256 addedLiquidity);

	// Views
	function exchangeConfig() external view returns (IExchangeConfig);
	function poolInfo(bytes32 poolID) external view returns (uint256 reserve0, uint256 reserve1, uint256 lastSwapTimestamp);
	function totalLiquidity(bytes32 poolID) external view returns (uint256);

	function getPoolReserves(IERC20 tokenA, IERC20 tokenB) external view returns (uint256 reserveA, uint256 reserveB);
	function getUserDeposit(address user, IERC20 token) external view returns (uint256);
	function getUserLiquidity(address user, IERC20 tokenA, IERC20 tokenB) external view returns (uint256);

	function quoteAmountOut( IERC20[] calldata tokens, uint256 amountIn ) external view returns (uint256 amountOut);
	function quoteAmountIn( IERC20[] calldata tokens, uint256 amountOut ) external view returns (uint256 amountIn);
	}