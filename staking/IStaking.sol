// SPDX-License-Identifier: BSL 1.1

pragma solidity =0.8.17;


interface IStaking
	{
    struct Unstake
        {
        uint8 status;

        address wallet;
        uint256 unstakedXSALT;
        uint256 claimableSALT;
        uint256 completionTime;

        uint256 unstakeID;
        }

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
        uint256 unstakeID,
        uint256 amount );

    event eCancelUnstake(
        address indexed wallet,
        uint256 unstakeID );

    event eTransfer(
        address indexed wallet,
        address indexed dest,
        uint256 amount );


	// Deposit / Withdrawal
    event eDeposit(
        address indexed wallet,
        address indexed poolID,
        bool isLP,
		uint256 amount );

    event eWithdrawAndClaim(
        address indexed wallet,
        address indexed poolID,
        bool isLP,
		uint256 amount );

    event eClaimRewards(
        address indexed wallet,
        address indexed poolID,
        bool isLP,
		uint256 amount );

    event eClaimAllRewards(
        address indexed wallet,
		uint256 amount );


	// Staking Config

    event eSetTransferable(
        bool transferable );

    event eChangePOL(
        address pol );

    event eConfirmPOL();

    event eSetEarlyUnstake(
        address earlyUnstake );

    event eWhitelist(
        address poolID );

    event eBlacklist(
        address poolID );

    event eSetUnstakeParams(
        uint256 minUnstakeWeeks,
        uint256 maxUnstakeWeeks,
        uint256 minUnstakePercent );

    event eSetCooldown(
        uint256 cooldown );
	}