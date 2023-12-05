// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "../../dev/Deployment.sol";
import "../interfaces/IStaking.sol";


contract StakingTest is Deployment
	{
    address public constant alice = address(0x1111);
    address public constant bob = address(0x2222);


	constructor()
		{
		initializeContracts();

		grantAccessAlice();
		grantAccessBob();
		}


	function testLiveBalanceCheck() public
    	{
    	address wallet1 = alice;
    	address wallet2 = bob;

		// Create a new Staking contract for testing
		staking = new Staking( exchangeConfig, poolsConfig, stakingConfig );

		// Initial approvals
		vm.prank(wallet1);
		salt.approve(address(staking), type(uint256).max);
		vm.prank(wallet2);
		salt.approve(address(staking), type(uint256).max);


		// Transfer SALT to the two test wallets
		vm.startPrank(address(initialDistribution));
		salt.transfer(wallet1, 1401054000000000000000000 );
		salt.transfer(wallet1, 54000000000000000000 );
		salt.transfer(wallet2, 2401234000000000000000000 );
		vm.stopPrank();

		// wallet1 stakes 1401054 SALT
		vm.prank(wallet1);
		staking.stakeSALT(1401054000000000000000000);

		// wallet2 stakes 2401234 SALT
		vm.prank(wallet2);
		staking.stakeSALT(2401234000000000000000000);

		// Add 30000 rewards
    	bytes32[] memory poolIDs = new bytes32[](1);
    	poolIDs[0] = PoolUtils.STAKED_SALT;

		AddedReward[] memory addedRewards = new AddedReward[](1);
		addedRewards[0] = AddedReward( PoolUtils.STAKED_SALT, 30000 ether );

		vm.startPrank(address(initialDistribution));
		salt.approve( address(staking), type(uint256).max );
		staking.addSALTRewards(addedRewards);
		vm.stopPrank();

		uint256 totalRewards = staking.totalRewardsForPools(poolIDs)[0];
		uint256 userShare = staking.userShareForPool(wallet1, PoolUtils.STAKED_SALT);
		uint256 totalShares = staking.totalShares(PoolUtils.STAKED_SALT);
		uint256 rewardsShare = ( totalRewards * userShare ) / totalShares;
//		console.log( "REWARDS SHARE0: ", rewardsShare );
//		console.log( "VIRTUAL REWARDS0: ", staking.userVirtualRewardsForPool(wallet1, PoolUtils.STAKED_SALT));

		console.log( "" );
		// wallet1 claims all
		vm.prank(wallet1);
//		uint256 amountClaimed = staking.claimAllRewards(poolIDs);
//		console.log( "AMOUNT CLAIMED: ", amountClaimed );

		totalRewards = staking.totalRewardsForPools(poolIDs)[0];
		userShare = staking.userShareForPool(wallet1, PoolUtils.STAKED_SALT);
		totalShares = staking.totalShares(PoolUtils.STAKED_SALT);
		rewardsShare = ( totalRewards * userShare ) / totalShares;
//		console.log( "REWARDS SHARE1: ", rewardsShare );
//		console.log( "VIRTUAL REWARDS1: ", staking.userVirtualRewardsForPool(wallet1, PoolUtils.STAKED_SALT));

		vm.prank(wallet1);
		staking.stakeSALT(54000000000000000000);

		totalRewards = staking.totalRewardsForPools(poolIDs)[0];
		userShare = staking.userShareForPool(wallet1, PoolUtils.STAKED_SALT);
		totalShares = staking.totalShares(PoolUtils.STAKED_SALT);
		rewardsShare = ( totalRewards * userShare ) / totalShares;
//		console.log( "REWARDS SHARE2: ", rewardsShare );
//		console.log( "VIRTUAL REWARDS2: ", staking.userVirtualRewardsForPool(wallet1, PoolUtils.STAKED_SALT));


//		uint256 reward = staking.userRewardForPool( wallet1, PoolUtils.STAKED_SALT );
//		console.log( "REWARD: ", reward );

    	}
	}
