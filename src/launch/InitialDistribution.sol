// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/contracts/finance/VestingWallet.sol";
import "../rewards/interfaces/ISaltRewards.sol";
import "../rewards/interfaces/IEmissions.sol";
import "../pools/interfaces/IPoolsConfig.sol";
import "./interfaces/IInitialDistribution.sol";
import "./interfaces/IBootstrapBallot.sol";
import "./interfaces/IAirdrop.sol";
import "../interfaces/ISalt.sol";


contract InitialDistribution is IInitialDistribution
    {
	using SafeERC20 for ISalt;

	uint256 constant public MILLION_ETHER = 1000000 ether;

   	ISalt immutable public salt;
	IPoolsConfig immutable public poolsConfig;
   	IEmissions immutable public emissions;
   	IBootstrapBallot immutable public bootstrapBallot;
	IDAO immutable public dao;
	VestingWallet immutable public daoVestingWallet;
	VestingWallet immutable public teamVestingWallet;
	ISaltRewards immutable public saltRewards;


	constructor( ISalt _salt, IPoolsConfig _poolsConfig, IEmissions _emissions, IBootstrapBallot _bootstrapBallot, IDAO _dao, VestingWallet _daoVestingWallet, VestingWallet _teamVestingWallet, ISaltRewards _saltRewards  )
		{
		salt = _salt;
		poolsConfig = _poolsConfig;
		emissions = _emissions;
		bootstrapBallot = _bootstrapBallot;
		dao = _dao;
		daoVestingWallet = _daoVestingWallet;
		teamVestingWallet = _teamVestingWallet;
		saltRewards = _saltRewards;
        }


    // Called when the BootstrapBallot is approved by the initial airdrop recipients.
    function distributionApproved( IAirdrop airdrop1, IAirdrop airdrop2 ) external
    	{
    	require( msg.sender == address(bootstrapBallot), "InitialDistribution.distributionApproved can only be called from the BootstrapBallot contract" );
		require( salt.balanceOf(address(this)) == 100 * MILLION_ETHER, "SALT has already been sent from the contract" );

    	// 51 million		Emissions
		salt.safeTransfer( address(emissions), 51 * MILLION_ETHER );

	    // 25 million		DAO Reserve Vesting Wallet
		salt.safeTransfer( address(daoVestingWallet), 25 * MILLION_ETHER );

	    // 10 million		Initial Development Team Vesting Wallet
		salt.safeTransfer( address(teamVestingWallet), 10 * MILLION_ETHER );

	    // 3 million		Airdrop Phase I
		salt.safeTransfer( address(airdrop1), 3 * MILLION_ETHER );

	    // 3 million		Airdrop Phase II
		salt.safeTransfer( address(airdrop2), 3 * MILLION_ETHER );

		bytes32[] memory poolIDs = poolsConfig.whitelistedPools();

	    // 5 million		Liquidity Bootstrapping
	    // 3 million		Staking Bootstrapping
		salt.safeTransfer( address(saltRewards), 8 * MILLION_ETHER );
		saltRewards.sendInitialSaltRewards(5 * MILLION_ETHER, poolIDs );
    	}
	}