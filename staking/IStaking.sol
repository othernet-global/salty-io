// SPDX-License-Identifier: BSL 1.1

pragma solidity =0.8.17;


interface IStaking
	{
    struct Unstake
        {
        uint256 status;

        address wallet;
        uint256 unstakedXSALT;
        uint256 claimableSALT;
        uint256 completionTime;

        uint256 unstakeID;
        }

    event eStake(
        address wallet,
        uint256 amount );

    event eUnstake(
        address wallet,
        uint256 amount,
        uint256 numWeeks );

    event eRecover(
        address wallet,
        uint256 unstakeID,
        uint256 amount );

    event eCancelUnstake(
        address wallet,
        uint256 unstakeID );

    event eTransfer(
        address wallet,
        address dest,
        uint256 amount );


    event eDeposit(
        address wallet,
        address poolID,
        bool isLP,
		uint256 amount );

    event eWithdrawAndClaim(
        address wallet,
        address poolID,
        bool isLP,
		uint256 amount );

    event eClaimRewards(
        address wallet,
        address poolID,
        bool isLP,
		uint256 amount );

    event eClaimAllRewards(
        address wallet,
		uint256 amount );
	}