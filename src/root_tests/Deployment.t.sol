// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "../dev/Deployment.sol";


contract TestDeployment is Deployment
	{
	address constant public TEAM_WALLET = address(0xBB1A8d7927CFA75E3cA2eD99DB7A9Cbafb62Cd50);


	function functionExists( address _contract, string memory _functionName ) public returns (bool)
		{
		bytes4 FUNC_SELECTOR = bytes4(keccak256( bytes(_functionName) ));

		bool success;
		bytes memory data = abi.encodeWithSelector(FUNC_SELECTOR );

		uint256 remainingGas = gasleft();

		assembly {
			success := call(
				remainingGas,            // gas remaining
				_contract,         // destination address
				0,              // no ether
				add(data, 32),  // input buffer (starts after the first 32 bytes in the `data` array)
				mload(data),    // input length (loaded from the first 32 bytes in the `data` array)
				0,              // output buffer
				0               // output length
			)
		}

		return success;
	}


	// Tests that the contract address variables within the various contracts are correct
    function testProperDeployment() public
    	{
    	// For sanity, check that the vesting wallet starts are within one month of now
    	uint256 daoVestingWalletStart = daoVestingWallet.start();
    	uint256 teamVestingWalletStart = teamVestingWallet.start();

		uint256 daoWithin;
		uint256 teamWithin;

		if ( daoVestingWalletStart > block.timestamp )
			daoWithin = daoVestingWalletStart - block.timestamp;
		else
			daoWithin = block.timestamp - daoVestingWalletStart;

		if ( teamVestingWalletStart > block.timestamp )
			teamWithin = teamVestingWalletStart - block.timestamp;
		else
			teamWithin = block.timestamp - teamVestingWalletStart;

		assertTrue( daoWithin < 60 * 60 * 24 * 30, "daoVestingWallet start() is too far away!" );
		assertTrue( teamWithin < 60 * 60 * 24 * 30, "teamVestingWallet start() is too far away!" );

		assertEq( daoVestingWalletStart, uint64(bootstrapBallot.completionTimestamp()), "daoVestingWallet start() doesn't match bootstrapBallot completionTimestamp" );
		assertEq( teamVestingWalletStart, uint64(bootstrapBallot.completionTimestamp()), "teamVestingWallet start() doesn't match bootstrapBallot completionTimestamp" );

    	// Check token decimals
		assertTrue( ERC20(address(wbtc)).decimals() == 8, "WBTC should have 8 decimals" );
		assertTrue( ERC20(address(weth)).decimals() == 18, "WETH should have 18 decimals" );
		assertTrue( ERC20(address(usdc)).decimals() == 6, "USDC should have 6 decimals" );
		assertTrue( ERC20(address(usdt)).decimals() == 6, "USDT should have 6 decimals" );
		assertTrue( ERC20(address(salt)).decimals() == 18, "SALT should have 18 decimals" );

        assertEq( getContract(address(exchangeConfig), "salt()"), address(salt), "Incorrect exchangeConfig.salt" );
        assertEq( getContract(address(exchangeConfig), "wbtc()"), address(wbtc), "Incorrect exchangeConfig.wbtc" );
        assertEq( getContract(address(exchangeConfig), "weth()"), address(weth), "Incorrect exchangeConfig.weth" );
        assertEq( getContract(address(exchangeConfig), "usdc()"), address(usdc), "Incorrect exchangeConfig.usdc" );
        assertEq( getContract(address(exchangeConfig), "usdt()"), address(usdt), "Incorrect exchangeConfig.usdt" );

        assertEq( getContract(address(exchangeConfig), "dao()"), address(dao), "Incorrect exchangeConfig.dao" );
        assertEq( getContract(address(exchangeConfig), "upkeep()"), address(upkeep), "Incorrect exchangeConfig.upkeep" );
        assertEq( getContract(address(exchangeConfig), "accessManager()"), address(accessManager), "Incorrect exchangeConfig.accessManager" );
        assertEq( getContract(address(exchangeConfig), "initialDistribution()"), address(initialDistribution), "Incorrect exchangeConfig.initialDistribution" );
		assertEq( getContract(address(exchangeConfig), "airdrop()"), address(airdrop), "Incorrect exchangeConfig.airdrop" );
        assertEq( getContract(address(exchangeConfig), "teamVestingWallet()"), address(teamVestingWallet), "Incorrect exchangeConfig.teamVestingWallet" );
        assertEq( getContract(address(exchangeConfig), "daoVestingWallet()"), address(daoVestingWallet), "Incorrect exchangeConfig.daoVestingWallet" );
        assertEq( getContract(address(exchangeConfig), "teamWallet()"), address(teamWallet), "Incorrect exchangeConfig.teamWallet" );
        assertEq( getContract(address(exchangeConfig), "accessManager()"), address(accessManager), "Incorrect exchangeConfig.accessManager" );

		assertTrue( functionExists( address(teamVestingWallet), "beneficiary()" ), "For DEBUG: Incorrect exchangeConfig.teamVestingWallet" );
		assertTrue( functionExists( address(daoVestingWallet), "beneficiary()" ), "For DEBUG: Incorrect exchangeConfig.daoVestingWallet" );
        assertEq( getContract(address(teamVestingWallet), "beneficiary()"), address(teamWallet), "Incorrect teamVestingWallet.beneficiary" );
        assertEq( getContract(address(daoVestingWallet), "beneficiary()"), address(dao), "Incorrect daoVestingWallet.beneficiary" );

        assertEq( getContract(address(airdrop), "exchangeConfig()"), address(exchangeConfig), "Incorrect airdrop.exchangeConfig" );
        assertEq( getContract(address(airdrop), "staking()"), address(staking), "Incorrect airdrop.staking" );
        assertEq( getContract(address(airdrop), "salt()"), address(salt), "Incorrect airdrop.salt" );

        assertEq( getContract(address(pools), "exchangeConfig()"), address(exchangeConfig), "Incorrect pools.exchangeConfig" );
        assertEq( getContract(address(pools), "poolsConfig()"), address(poolsConfig), "Incorrect pools.poolsConfig" );
        assertEq( getContract(address(pools), "dao()"), address(dao), "Incorrect pools.dao" );
        assertEq( getContract(address(pools), "liquidity()"), address(liquidity), "Incorrect pools.liquidity" );

        assertEq( getContract(address(staking), "exchangeConfig()"), address(exchangeConfig), "Incorrect staking.exchangeConfig" );
        assertEq( getContract(address(staking), "poolsConfig()"), address(poolsConfig), "Incorrect staking.poolsConfig" );
        assertEq( getContract(address(staking), "stakingConfig()"), address(stakingConfig), "Incorrect staking.stakingConfig" );

        assertEq( getContract(address(liquidity), "pools()"), address(pools), "Incorrect liquidity.pools" );
        assertEq( getContract(address(liquidity), "exchangeConfig()"), address(exchangeConfig), "Incorrect liquidity.exchangeConfig" );
        assertEq( getContract(address(liquidity), "poolsConfig()"), address(poolsConfig), "Incorrect liquidity.poolsConfig" );
        assertEq( getContract(address(liquidity), "stakingConfig()"), address(stakingConfig), "Incorrect liquidity.stakingConfig" );
        assertEq( getContract(address(liquidity), "pools()"), address(pools), "Incorrect liquidity.pools" );
        assertEq( getContract(address(liquidity), "exchangeConfig()"), address(exchangeConfig), "Incorrect liquidity.exchangeConfig" );
        assertEq( getContract(address(liquidity), "stakingConfig()"), address(stakingConfig), "Incorrect liquidity.stakingConfig" );

		assertEq( getContract(address(stakingRewardsEmitter), "stakingRewards()"), address(staking), "Incorrect stakingRewardsEmitter.stakingRewards" );
        assertEq( getContract(address(stakingRewardsEmitter), "exchangeConfig()"), address(exchangeConfig), "Incorrect stakingRewardsEmitter.exchangeConfig" );
        assertEq( getContract(address(stakingRewardsEmitter), "poolsConfig()"), address(poolsConfig), "Incorrect stakingRewardsEmitter.poolsConfig" );
		assertEq( getContract(address(stakingRewardsEmitter), "rewardsConfig()"), address(rewardsConfig), "Incorrect stakingRewardsEmitter.rewardsConfig" );
		assertEq( getContract(address(stakingRewardsEmitter), "salt()"), address(salt), "Incorrect stakingRewardsEmitter.salt" );

		assertEq( getContract(address(liquidityRewardsEmitter), "stakingRewards()"), address(liquidity), "Incorrect liquidityRewardsEmitter.stakingRewards" );
		assertEq( getContract(address(liquidityRewardsEmitter), "exchangeConfig()"), address(exchangeConfig), "Incorrect liquidityRewardsEmitter.exchangeConfig" );
        assertEq( getContract(address(liquidityRewardsEmitter), "poolsConfig()"), address(poolsConfig), "Incorrect liquidityRewardsEmitter.poolsConfig" );
		assertEq( getContract(address(liquidityRewardsEmitter), "rewardsConfig()"), address(rewardsConfig), "Incorrect liquidityRewardsEmitter.rewardsConfig" );
		assertEq( getContract(address(liquidityRewardsEmitter), "salt()"), address(salt), "Incorrect liquidityRewardsEmitter.salt" );

        assertEq( getContract(address(emissions), "saltRewards()"), address(saltRewards), "Incorrect emissions.saltRewards" );
        assertEq( getContract(address(emissions), "exchangeConfig()"), address(exchangeConfig), "Incorrect emissions.exchangeConfig" );
        assertEq( getContract(address(emissions), "rewardsConfig()"), address(rewardsConfig), "Incorrect emissions.rewardsConfig" );
        assertEq( getContract(address(emissions), "salt()"), address(salt), "Incorrect emissions.salt" );

		assertEq( getContract(address(dao), "pools()"), address(pools), "Incorrect dao.pools" );
		assertEq( getContract(address(dao), "proposals()"), address(proposals), "Incorrect dao.proposals" );
        assertEq( getContract(address(dao), "exchangeConfig()"), address(exchangeConfig), "Incorrect dao.exchangeConfig" );
        assertEq( getContract(address(dao), "poolsConfig()"), address(poolsConfig), "Incorrect dao.poolsConfig" );
		assertEq( getContract(address(dao), "stakingConfig()"), address(stakingConfig), "Incorrect dao.stakingConfig" );
        assertEq( getContract(address(dao), "rewardsConfig()"), address(rewardsConfig), "Incorrect dao.rewardsConfig" );
		assertEq( getContract(address(dao), "daoConfig()"), address(daoConfig), "Incorrect dao.daoConfig" );
        assertEq( getContract(address(dao), "liquidityRewardsEmitter()"), address(liquidityRewardsEmitter), "Incorrect dao.liquidityRewardsEmitter" );

        assertEq( getContract(address(upkeep), "pools()"), address(pools), "Incorrect upkeep.pools" );
        assertEq( getContract(address(upkeep), "exchangeConfig()"), address(exchangeConfig), "Incorrect upkeep.exchangeConfig" );
        assertEq( getContract(address(upkeep), "poolsConfig()"), address(poolsConfig), "Incorrect upkeep.poolsConfig" );
        assertEq( getContract(address(upkeep), "daoConfig()"), address(daoConfig), "Incorrect upkeep.daoConfig" );
        assertEq( getContract(address(upkeep), "saltRewards()"), address(saltRewards), "Incorrect upkeep.saltRewards" );
        assertEq( getContract(address(upkeep), "emissions()"), address(emissions), "Incorrect upkeep.emissions" );
        assertEq( getContract(address(upkeep), "dao()"), address(dao), "Incorrect upkeep.dao" );

        assertEq( getContract(address(upkeep), "salt()"), address(salt), "Incorrect upkeep.salt" );

		assertEq( getContract(address(proposals), "staking()"), address(staking), "Incorrect proposals.staking" );
        assertEq( getContract(address(proposals), "exchangeConfig()"), address(exchangeConfig), "Incorrect proposals.exchangeConfig" );
        assertEq( getContract(address(proposals), "poolsConfig()"), address(poolsConfig), "Incorrect proposals.poolsConfig" );
        assertEq( getContract(address(proposals), "daoConfig()"), address(daoConfig), "Incorrect proposals.daoConfig" );

		assertEq( getContract(address(saltRewards), "exchangeConfig()"), address(exchangeConfig), "Incorrect saltRewards.exchangeConfig" );
        assertEq( getContract(address(saltRewards), "rewardsConfig()"), address(rewardsConfig), "Incorrect saltRewards.rewardsConfig" );
        assertEq( getContract(address(saltRewards), "salt()"), address(salt), "Incorrect saltRewards.salt" );
        assertEq( getContract(address(saltRewards), "stakingRewardsEmitter()"), address(stakingRewardsEmitter), "Incorrect saltRewards.stakingRewardsEmitter" );
        assertEq( getContract(address(saltRewards), "liquidityRewardsEmitter()"), address(liquidityRewardsEmitter), "Incorrect saltRewards.liquidityRewardsEmitter" );

		// Check ownership has been transferred to the DAO
		assertEq( getContract( address(exchangeConfig), "owner()" ), address(dao), "exchangeConfig owner is not dao" );
		assertEq( getContract( address(poolsConfig), "owner()" ), address(dao), "poolsConfig owner is not dao" );
		assertEq( getContract( address(stakingConfig), "owner()" ), address(dao), "stakingConfig owner is not dao" );
		assertEq( getContract( address(rewardsConfig), "owner()" ), address(dao), "rewardsConfig owner is not dao" );
		assertEq( getContract( address(daoConfig), "owner()" ), address(dao), "daoConfig owner is not dao" );

		assertEq( getContract(address(bootstrapBallot), "exchangeConfig()"), address(exchangeConfig), "Incorrect bootstrapBallot.exchangeConfig" );
		assertEq( getContract(address(bootstrapBallot), "airdrop()"), address(airdrop), "Incorrect bootstrapBallot.airdrop" );

		assertEq( getContract(address(initialDistribution), "salt()"), address(salt), "Incorrect initialDistribution.salt" );
		assertEq( getContract(address(initialDistribution), "poolsConfig()"), address(poolsConfig), "Incorrect initialDistribution.poolsConfig" );
		assertEq( getContract(address(initialDistribution), "emissions()"), address(emissions), "Incorrect initialDistribution.emissions" );
		assertEq( getContract(address(initialDistribution), "bootstrapBallot()"), address(bootstrapBallot), "Incorrect initialDistribution.bootstrapBallot" );
		assertEq( getContract(address(initialDistribution), "dao()"), address(dao), "Incorrect initialDistribution.dao" );
		assertEq( getContract(address(initialDistribution), "daoVestingWallet()"), address(daoVestingWallet), "Incorrect initialDistribution.daoVestingWallet" );
		assertEq( getContract(address(initialDistribution), "teamVestingWallet()"), address(teamVestingWallet), "Incorrect initialDistribution.teamVestingWallet" );
		assertEq( getContract(address(initialDistribution), "airdrop()"), address(airdrop), "Incorrect initialDistribution.airdrop" );
		assertEq( getContract(address(initialDistribution), "saltRewards()"), address(saltRewards), "Incorrect initialDistribution.saltRewards" );

		assertEq( salt.balanceOf(address(initialDistribution)), 100000000 ether, "The InitialDistribution contract should start with a SALT balance of 100 million SALT" );

        if ( ! DEBUG )
        	{
			assertEq( address(wbtc), 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599, "Invalid WBTC" );
			assertEq( address(weth), 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, "Invalid WETH" );
			assertEq( address(usdc), 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, "Invalid USDC" );
        	}

        assertEq( exchangeConfig.teamWallet(), teamWallet, "Incorrect teamWallet" );

        // Check the initial country exclusion
		// Excluded by default: United States, Canada, United Kingdom, China, India, Pakistan, Russian, Afghanistan, Cuba, Iran, North Korea, Syria, Venezuela
        assertTrue( dao.countryIsExcluded("US"), "US should be initially excluded" );
        assertTrue( dao.countryIsExcluded("CA"), "CA should be initially excluded" );
        assertTrue( dao.countryIsExcluded("GB"), "GB should be initially excluded" );

        assertTrue( dao.countryIsExcluded("CN"), "CN should be initially excluded" );
        assertTrue( dao.countryIsExcluded("IN"), "IN should be initially excluded" );
        assertTrue( dao.countryIsExcluded("PK"), "PK should be initially excluded" );
        assertTrue( dao.countryIsExcluded("RU"), "RU should be initially excluded" );

        assertTrue( dao.countryIsExcluded("AF"), "AF should be initially excluded" );
        assertTrue( dao.countryIsExcluded("CU"), "CU should be initially excluded" );
        assertTrue( dao.countryIsExcluded("IR"), "IR should be initially excluded" );
        assertTrue( dao.countryIsExcluded("KP"), "KP should be initially excluded" );
        assertTrue( dao.countryIsExcluded("SY"), "SY should be initially excluded" );
        assertTrue( dao.countryIsExcluded("VE"), "VE should be initially excluded" );
    	}


   	function testPrint() public view
   		{
   		console.log( "wbtc: ", address(wbtc) );
   		console.log( "weth: ", address(weth) );
   		console.log( "usdc: ", address(usdc) );
   		console.log( "accessManager: ", address(accessManager) );
		console.log( "" );
	   	console.log( "airdrop: ", address(airdrop) );
   		console.log( "bootstrapBallot: ", address(bootstrapBallot) );
	   	console.log( "dao: ", address(dao) );
   		console.log( "daoConfig: ", address(daoConfig) );
   		console.log( "emissions: ", address(emissions) );
		console.log( "exchangeConfig: ", address(exchangeConfig) );
   		console.log( "initialDistribution: ", address(initialDistribution) );
   		console.log( "liquidity: ", address(liquidity) );
   		console.log( "liquidityRewardsEmitter: ", address(liquidityRewardsEmitter) );
   		console.log( "teamWallet: ", address(teamWallet) );
   		console.log( "pools: ", address(pools) );
   		console.log( "poolsConfig: ", address(poolsConfig) );
   		console.log( "proposals: ", address(proposals) );
   		console.log( "rewardsConfig: ", address(rewardsConfig) );
   		console.log( "salt: ", address(salt) );
   		console.log( "saltRewards: ", address(saltRewards) );
   		console.log( "staking: ", address(staking) );
		console.log( "stakingConfig: ", address(stakingConfig) );
   		console.log( "stakingRewardsEmitter: ", address(stakingRewardsEmitter) );
		console.log( "teamVestingWallet: ", address(teamVestingWallet) );
   		console.log( "upkeep: ", address(upkeep) );
		console.log( "" );
   		}
    }

