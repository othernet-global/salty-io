// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.12;


struct CollateralPosition
	{
	uint256 positionID;
	address wallet;
	uint256 lpCollateralAmount;
	uint256 usdsBorrowedAmount;
	bool liquidated;
	}


interface ICollateral
	{
	event eDepositCollateral(
		address indexed wallet,
		uint256 amount );

	event eWithdrawCollateral(
		address indexed wallet,
		uint256 amount );

	 event eBorrow(
		address indexed wallet,
		uint256 amount );

	event eRepay(
		address indexed wallet,
		uint256 amount );

	event eLiquidatePosition(
		uint256 indexed positionID,
		address indexed wallet,
		address indexed liquidator,
		uint256 collateralAmount );


	function depositCollateral( uint256 amountDeposited ) external;
	function withdrawCollateralAndClaim( uint256 amountWithdrawn ) external;
	function borrowUSDS( uint256 amountBorrowed ) external;
	function repayUSDS( uint256 amountRepaid ) external;
	function liquidatePosition( uint256 positionID ) external;

	function userHasPosition( address wallet ) external view returns (bool);
	function userPosition( address wallet ) external view returns (CollateralPosition calldata);
	function maxWithdrawableLP( address wallet ) external view returns (uint256);
	function maxBorrowableUSDS( address wallet ) external view returns (uint256);
	function positionIsOpen( uint256 positionID ) external view returns (bool);
	function numberOfOpenPositions() external view returns (uint256);
	function findLiquidatablePositions( uint256 startIndex, uint256 endIndex ) external view returns (uint256[] calldata);
	function findLiquidatablePositions() external view returns (uint256[] calldata);

	function underlyingTokenValueInUSD( uint256 amountBTC, uint256 amountETH ) external view returns (uint256);
	function collateralValue( uint256 collateralAmount ) external view returns (uint256);
	function userCollateralValueInUSD( address wallet ) external view returns (uint256);
	function totalCollateralValueInUSD() external view returns (uint256);
	}
