// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.20;

import "forge-std/Test.sol";
import "../Deployment.sol";


contract TestDeployment is Deployment, Test
	{
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
    function testDeployment() public
    	{
    	// Check token decimals
		assertTrue( ERC20(address(wbtc)).decimals() == 8, "WBTC should have 8 decimals" );
		assertTrue( ERC20(address(weth)).decimals() == 18, "WETH should have 18 decimals" );
		assertTrue( ERC20(address(usdc)).decimals() == 6, "USDC should have 6 decimals" );
		assertTrue( ERC20(address(salt)).decimals() == 18, "SALT should have 18 decimals" );
		assertTrue( ERC20(address(usds)).decimals() == 18, "USDS should have 18 decimals" );

        assertEq( getContract(address(exchangeConfig), "salt()"), address(salt), "Incorrect exchangeConfig.salt" );
        assertEq( getContract(address(exchangeConfig), "wbtc()"), address(wbtc), "Incorrect exchangeConfig.wbtc" );
        assertEq( getContract(address(exchangeConfig), "weth()"), address(weth), "Incorrect exchangeConfig.weth" );
        assertEq( getContract(address(exchangeConfig), "usdc()"), address(usdc), "Incorrect exchangeConfig.usdc" );
        assertEq( getContract(address(exchangeConfig), "usds()"), address(usds), "Incorrect exchangeConfig.usds" );
        assertEq( getContract(address(exchangeConfig), "accessManager()"), address(accessManager), "Incorrect exchangeConfig.accessManager" );
        assertEq( getContract(address(exchangeConfig), "dao()"), address(dao), "Incorrect exchangeConfig.dao" );

        assertEq( getContract(address(pools), "exchangeConfig()"), address(exchangeConfig), "Incorrect pools.exchangeConfig" );
        assertEq( getContract(address(pools), "dao()"), address(dao), "Incorrect pools.dao" );

        assertEq( getContract(address(staking), "exchangeConfig()"), address(exchangeConfig), "Incorrect staking.exchangeConfig" );
        assertEq( getContract(address(staking), "poolsConfig()"), address(poolsConfig), "Incorrect staking.poolsConfig" );
        assertEq( getContract(address(staking), "stakingConfig()"), address(stakingConfig), "Incorrect staking.stakingConfig" );

        assertEq( getContract(address(liquidity), "pools()"), address(pools), "Incorrect liquidity.pools" );
        assertEq( getContract(address(liquidity), "exchangeConfig()"), address(exchangeConfig), "Incorrect liquidity.exchangeConfig" );
        assertEq( getContract(address(liquidity), "poolsConfig()"), address(poolsConfig), "Incorrect liquidity.poolsConfig" );
        assertEq( getContract(address(liquidity), "stakingConfig()"), address(stakingConfig), "Incorrect liquidity.stakingConfig" );

    	assertEq( getContract(address(collateral), "wbtc()"), address(wbtc), "Incorrect collateral.wbtc" );
        assertEq( getContract(address(collateral), "weth()"), address(weth), "Incorrect collateral.weth" );
        assertEq( getContract(address(collateral), "usds()"), address(usds), "Incorrect collateral.usds" );
        assertEq( getContract(address(collateral), "stableConfig()"), address(stableConfig), "Incorrect collateral.stableConfig" );
        assertEq( getContract(address(collateral), "pools()"), address(pools), "Incorrect collateral.pools" );
        assertEq( getContract(address(collateral), "exchangeConfig()"), address(exchangeConfig), "Incorrect collateral.exchangeConfig" );
        assertEq( getContract(address(collateral), "poolsConfig()"), address(poolsConfig), "Incorrect collateral.poolsConfig" );
        assertEq( getContract(address(collateral), "stakingConfig()"), address(stakingConfig), "Incorrect collateral.stakingConfig" );

		assertEq( getContract(address(stakingRewardsEmitter), "stakingRewards()"), address(staking), "Incorrect stakingRewardsEmitter.stakingRewards" );
        assertEq( getContract(address(stakingRewardsEmitter), "poolsConfig()"), address(poolsConfig), "Incorrect stakingRewardsEmitter.poolsConfig" );
        assertEq( getContract(address(stakingRewardsEmitter), "stakingConfig()"), address(stakingConfig), "Incorrect stakingRewardsEmitter.stakingConfig" );
		assertEq( getContract(address(stakingRewardsEmitter), "rewardsConfig()"), address(rewardsConfig), "Incorrect stakingRewardsEmitter.rewardsConfig" );

		assertEq( getContract(address(liquidityRewardsEmitter), "stakingRewards()"), address(liquidity), "Incorrect liquidityRewardsEmitter.stakingRewards" );
        assertEq( getContract(address(liquidityRewardsEmitter), "poolsConfig()"), address(poolsConfig), "Incorrect liquidityRewardsEmitter.poolsConfig" );
        assertEq( getContract(address(liquidityRewardsEmitter), "stakingConfig()"), address(stakingConfig), "Incorrect liquidityRewardsEmitter.stakingConfig" );
		assertEq( getContract(address(liquidityRewardsEmitter), "rewardsConfig()"), address(rewardsConfig), "Incorrect liquidityRewardsEmitter.rewardsConfig" );

		assertEq( getContract(address(collateralRewardsEmitter), "stakingRewards()"), address(collateral), "Incorrect collateralRewardsEmitter.stakingRewards" );
        assertEq( getContract(address(collateralRewardsEmitter), "poolsConfig()"), address(poolsConfig), "Incorrect collateralRewardsEmitter.poolsConfig" );
        assertEq( getContract(address(collateralRewardsEmitter), "stakingConfig()"), address(stakingConfig), "Incorrect collateralRewardsEmitter.stakingConfig" );
		assertEq( getContract(address(collateralRewardsEmitter), "rewardsConfig()"), address(rewardsConfig), "Incorrect collateralRewardsEmitter.rewardsConfig" );

        assertEq( getContract(address(emissions), "staking()"), address(staking), "Incorrect emissions.staking" );
        assertEq( getContract(address(emissions), "exchangeConfig()"), address(exchangeConfig), "Incorrect emissions.exchangeConfig" );
		assertEq( getContract(address(emissions), "stakingConfig()"), address(stakingConfig), "Incorrect emissions.stakingConfig" );
		assertEq( getContract(address(emissions), "poolsConfig()"), address(poolsConfig), "Incorrect emissions.poolsConfig" );
        assertEq( getContract(address(emissions), "rewardsConfig()"), address(rewardsConfig), "Incorrect emissions.rewardsConfig" );

		assertEq( getContract(address(dao), "proposals()"), address(proposals), "Incorrect dao.proposals" );
        assertEq( getContract(address(dao), "exchangeConfig()"), address(exchangeConfig), "Incorrect dao.exchangeConfig" );
        assertEq( getContract(address(dao), "poolsConfig()"), address(poolsConfig), "Incorrect dao.poolsConfig" );
		assertEq( getContract(address(dao), "stakingConfig()"), address(stakingConfig), "Incorrect dao.stakingConfig" );
        assertEq( getContract(address(dao), "rewardsConfig()"), address(rewardsConfig), "Incorrect dao.rewardsConfig" );
        assertEq( getContract(address(dao), "stableConfig()"), address(stableConfig), "Incorrect dao.stableConfig" );
		assertEq( getContract(address(dao), "daoConfig()"), address(daoConfig), "Incorrect dao.daoConfig" );
        assertEq( getContract(address(dao), "liquidity()"), address(liquidity), "Incorrect dao.liquidity" );
        assertEq( getContract(address(dao), "liquidityRewardsEmitter()"), address(liquidityRewardsEmitter), "Incorrect dao.liquidityRewardsEmitter" );

		assertEq( getContract(address(proposals), "staking()"), address(staking), "Incorrect proposals.staking" );
        assertEq( getContract(address(proposals), "exchangeConfig()"), address(exchangeConfig), "Incorrect proposals.exchangeConfig" );
        assertEq( getContract(address(proposals), "poolsConfig()"), address(poolsConfig), "Incorrect proposals.poolsConfig" );
        assertEq( getContract(address(proposals), "stakingConfig()"), address(stakingConfig), "Incorrect proposals.stakingConfig" );
        assertEq( getContract(address(proposals), "daoConfig()"), address(daoConfig), "Incorrect proposals.daoConfig" );

		assertEq( getContract( address(exchangeConfig), "owner()" ), address(dao), "exchangeConfig owner is not dao" );
		assertEq( getContract( address(poolsConfig), "owner()" ), address(dao), "poolsConfig owner is not dao" );
		assertEq( getContract( address(stakingConfig), "owner()" ), address(dao), "stakingConfig owner is not dao" );
		assertEq( getContract( address(rewardsConfig), "owner()" ), address(dao), "rewardsConfig owner is not dao" );
		assertEq( getContract( address(stableConfig), "owner()" ), address(dao), "stableConfig owner is not dao" );
		assertEq( getContract( address(daoConfig), "owner()" ), address(dao), "daoConfig owner is not dao" );

        assertEq( getContract(address(poolsConfig), "arbitrageSearch()"), address(arbitrageSearch), "Incorrect poolsConfig.arbitrageSearch" );

        if ( DEBUG )
        	assertTrue( functionExists( address(priceFeed), "forcedPriceBTCWith18Decimals()" ), "For DEBUG: The PriceFeed should be a ForcedPriceFeed" );
        else
        	{
        	assertFalse( functionExists( address(priceFeed), "forcedPriceBTCWith18Decimals()" ), "For DEBUG: The PriceFeed should not be a ForcedPriceFeed" );

        	assertEq( getContract( address(priceFeed), "CHAINLINK_BTC_USD()" ), address(0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c), "Incorrect BTC/USD Chainlink price feed" );
        	assertEq( getContract( address(priceFeed), "CHAINLINK_ETH_USD()" ), address(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419), "Incorrect ETH/USD Chainlink price feed" );
        	assertEq( getContract( address(priceFeed), "UNISWAP_V3_BTC_ETH()" ), address(0xCBCdF9626bC03E24f779434178A73a0B4bad62eD), "Incorrect BTC/ETH Uniswap v3 Pool" );
        	assertEq( getContract( address(priceFeed), "UNISWAP_V3_USDC_ETH()" ), address(0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640), "Incorrect ETH/USDC Uniswap v3 Pool" );

			assertEq( address(wbtc), 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599, "Invalid WBTC" );
			assertEq( address(weth), 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, "Invalid WETH" );
			assertEq( address(usdc), 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, "Invalid USDC" );
        	}

        assertEq( getContract(address(stableConfig), "priceFeed()"), address(priceFeed), "Incorrect stableConfig.priceFeed" );

        assertEq( getContract(address(usds), "stableConfig()"), address(stableConfig), "Incorrect usds.stableConfig" );
        assertEq( getContract(address(usds), "wbtc()"), address(wbtc), "Incorrect usds.wbtc" );
        assertEq( getContract(address(usds), "weth()"), address(weth), "Incorrect usds.weth" );
        assertEq( getContract(address(usds), "collateral()"), address(collateral), "Incorrect usds.collateral" );
        assertEq( getContract(address(usds), "pools()"), address(pools), "Incorrect usds.pools" );

        assertEq( getContract(address(arbitrageSearch), "pools()"), address(pools), "Incorrect arbitrageSearch.pools" );
        assertEq( getContract(address(arbitrageSearch), "exchangeConfig()"), address(exchangeConfig), "Incorrect arbitrageSearch.exchangeConfig" );
//
//        if ( DEBUG )
//        	assertTrue( functionExists( address(accessManager), "isTest()" ), "For DEBUG: The AccessManager should be a TestAccessManager" );
//        else
//        	assertFalse( functionExists( address(accessManager), "isTest()" ), "For DEBUG: The AccessManager should not be a TestAccessManager" );
//
//        assertEq( getContract(address(optimizer), "weth()"), address(weth), "Incorrect optimizer.weth" );
//        assertEq( getContract(address(optimizer), "stakingConfig()"), address(stakingConfig), "Incorrect optimizer.stakingConfig" );
//        assertEq( getContract(address(optimizer), "exchangeConfig()"), address(exchangeConfig), "Incorrect optimizer.exchangeConfig" );
//        assertEq( getContract(address(optimizer), "liquidityRewardsEmitter()"), address(liquidityRewardsEmitter), "Incorrect optimizer.liquidityRewardsEmitter" );
//        assertEq( getContract(address(optimizer), "factory()"), address(factory), "Incorrect optimizer.factory" );
//        assertEq( getContract(address(optimizer), "router()"), address(router), "Incorrect optimizer.router" );
    	}


   	function testPrint() public view
   		{
   		console.log( "wbtc: ", address(wbtc) );
   		console.log( "weth: ", address(weth) );
   		console.log( "usdc: ", address(usdc) );
   		console.log( "accessManager: ", address(accessManager) );
		console.log( "" );
   		console.log( "salt: ", address(salt) );
   		console.log( "priceFeed: ", address(priceFeed) );
//   		console.log( "util: ", address(util) );
		console.log( "" );
   		console.log( "stableConfig: ", address(stableConfig) );
   		console.log( "usds: ", address(usds) );
		console.log( "" );
   		console.log( "exchangeConfig: ", address(exchangeConfig) );
   		console.log( "poolsConfig: ", address(poolsConfig) );
   		console.log( "stakingConfig: ", address(stakingConfig) );
   		console.log( "rewardsConfig: ", address(rewardsConfig) );
   		console.log( "daoConfig: ", address(daoConfig) );
		console.log( "" );
   		console.log( "pools: ", address(pools) );
		console.log( "" );
   		console.log( "staking: ", address(staking) );
   		console.log( "liquidity: ", address(liquidity) );
   		console.log( "collateral: ", address(collateral) );
		console.log( "" );
   		console.log( "stakingRewardsEmitter: ", address(stakingRewardsEmitter) );
   		console.log( "liquidityRewardsEmitter: ", address(liquidityRewardsEmitter) );
   		console.log( "collateralRewardsEmitter: ", address(collateralRewardsEmitter) );
		console.log( "" );
//   		console.log( "optimizer: ", address(optimizer) );
   		console.log( "arbitrageSearch: ", address(arbitrageSearch) );
////   		console.log( "emissions: ", address(emissions) );
//   		console.log( "dao: ", address(dao) );
		console.log( "" );
//   		console.log( "initialSale: ", address(initialSale) );
   		}
    }

