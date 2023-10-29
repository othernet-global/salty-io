// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../dao/interfaces/IDAO.sol";
import "./IPoolStats.sol";
import "../../stable/interfaces/ICollateralAndLiquidity.sol";


interface IPools is IPoolStats
	{
	function startExchangeApproved() external;
	function setContracts( IDAO _dao, ICollateralAndLiquidity _collateralAndLiquidity ) external; // onlyOwner

	function addLiquidity( IERC20 tokenA, IERC20 tokenB, uint256 maxAmountA, uint256 maxAmountB, uint256 minLiquidityReceived, uint256 totalLiquidity ) external returns (uint256 addedAmountA, uint256 addedAmountB, uint256 addedLiquidity);
	function removeLiquidity( IERC20 tokenA, IERC20 tokenB, uint256 liquidityToRemove, uint256 minReclaimedA, uint256 minReclaimedB, uint256 totalLiquidity ) external returns (uint256 reclaimedA, uint256 reclaimedB);

	function deposit( IERC20 token, uint256 amount ) external;
	function withdraw( IERC20 token, uint256 amount ) external;
	function swap( IERC20 swapTokenIn, IERC20 swapTokenOut, uint256 swapAmountIn, uint256 minAmountOut, uint256 deadline, bool isWhitelistedPair ) external returns (uint256 swapAmountOut);
	function depositSwapWithdraw(IERC20 swapTokenIn, IERC20 swapTokenOut, uint256 swapAmountIn, uint256 minAmountOut, uint256 deadline, bool isWhitelistedPair) external returns (uint256 swapAmountOut);

	function depositTokenForCounterswap( address counterswapAddress, IERC20 tokenToDeposit, uint256 amountToDeposit ) external;
	function withdrawTokenFromCounterswap( address counterswapAddress, IERC20 tokenToWithdraw, uint256 amountToWithdraw ) external;

	// Views
	function lastSwapBlock( bytes32 poolID ) external returns (uint256 _lastSwapBlock);
	function getPoolReserves(IERC20 tokenA, IERC20 tokenB) external view returns (uint256 reserveA, uint256 reserveB);
	function depositedUserBalance(address user, IERC20 token) external view returns (uint256);
	}

