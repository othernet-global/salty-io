// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.0;

import "../uniswap/core/interfaces/IUniswapV2Pair.sol";


struct AddedReward
	{
	IUniswapV2Pair poolID;
	bool isLP;
	uint256 amountToAdd;
	}

interface IStaking
	{
	// Staking / Unstaking
    event eStake(
        address indexed wallet,
        uint256 amount );

    event eUnstake(
        address indexed wallet,
        uint256 amount,
        uint256 numWeeks );

    event eRecover(
        address indexed wallet,
        uint256 indexed unstakeID,
        uint256 amount );

    event eCancelUnstake(
        address indexed wallet,
        uint256 indexed unstakeID );

    event eTransfer(
        address indexed wallet,
        address indexed dest,
        uint256 amount );


	// Deposit / Withdrawal
    event eDeposit(
        address indexed wallet,
        IUniswapV2Pair indexed poolID,
        bool isLP,
		uint256 amount );

    event eWithdrawAndClaim(
        address indexed wallet,
        IUniswapV2Pair indexed poolID,
        bool isLP,
		uint256 amount );

    event eClaimRewards(
        address indexed wallet,
        IUniswapV2Pair indexed poolID,
        bool isLP,
		uint256 amount );

    event eClaimAllRewards(
        address indexed wallet,
		uint256 amount );


	// Staking Config
    event eSetEarlyUnstake(
        address earlyUnstake );

    event eWhitelist(
        IUniswapV2Pair indexed poolID );

    event eUnwhitelist(
        IUniswapV2Pair indexed poolID );

    event eSetUnstakeParams(
        uint256 minUnstakeWeeks,
        uint256 maxUnstakeWeeks,
        uint256 minUnstakePercent );

    event eSetCooldown(
        uint256 cooldown );
	}