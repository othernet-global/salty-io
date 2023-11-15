// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "../../staking/interfaces/ILiquidity.sol";
import "./ILiquidizer.sol";


interface ICollateralAndLiquidity is ILiquidity
	{
	function depositCollateralAndIncreaseShare( uint256 maxAmountWBTC, uint256 maxAmountWETH, uint256 minLiquidityReceived, uint256 deadline, bool useZapping ) external returns (uint256 addedAmountWBTC, uint256 addedAmountWETH, uint256 addedLiquidity);
	function withdrawCollateralAndClaim( uint256 collateralToWithdraw, uint256 minReclaimedWBTC, uint256 minReclaimedWETH, uint256 deadline ) external returns (uint256 reclaimedWBTC, uint256 reclaimedWETH);
	function borrowUSDS( uint256 amountBorrowed ) external;
	function repayUSDS( uint256 amountRepaid ) external;
	function liquidateUser( address wallet ) external;

	// Views
	function liquidizer() external view returns (ILiquidizer);
	function usdsBorrowedByUsers( address wallet ) external view returns (uint256);

	function maxWithdrawableCollateral( address wallet ) external view returns (uint256);
	function maxBorrowableUSDS( address wallet ) external view returns (uint256);
	function numberOfUsersWithBorrowedUSDS() external view returns (uint256);
	function canUserBeLiquidated( address wallet ) external view returns (bool);
	function findLiquidatableUsers( uint256 startIndex, uint256 endIndex ) external view returns (address[] calldata);
	function findLiquidatableUsers() external view returns (address[] calldata);

	function underlyingTokenValueInUSD( uint256 amountBTC, uint256 amountETH ) external view returns (uint256);
	function totalCollateralValueInUSD() external view returns (uint256);
	function userCollateralValueInUSD( address wallet ) external view returns (uint256);
	}
