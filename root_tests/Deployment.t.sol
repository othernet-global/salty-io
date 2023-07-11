// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.12;

import "forge-std/Test.sol";
import "../Deployment.sol";


contract TestDeployment is Deployment
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


	function getContract( address _contract, string memory _functionName ) public returns (address result) {
		bytes4 FUNC_SELECTOR = bytes4(keccak256( bytes(_functionName) ));

		bytes memory data = abi.encodeWithSelector(FUNC_SELECTOR );

		uint256 remainingGas = gasleft();

		bool success;
		bytes memory output = new bytes(32);  // Initialize an output buffer

		assembly {
			success := call(
				remainingGas,            // gas remaining
				_contract,               // destination address
				0,                       // no ether
				add(data, 32),           // input buffer (starts after the first 32 bytes in the `data` array)
				mload(data),             // input length (loaded from the first 32 bytes in the `data` array)
				add(output, 32),         // output buffer
				32                       // output length is 32 bytes because address is 20 bytes
			)
		}

		require(success, "External call failed");

		// Cast bytes to address
		result = abi.decode(output, (address));
	}


	// Tests that the contract address variables within the various contracts are correct
    function testDeployment() public
    	{
        assertEq( getContract(address(exchangeConfig), "salt()"), address(salt), "Incorrect exchangeConfig.salt" );
        assertEq( getContract(address(exchangeConfig), "wbtc()"), address(wbtc), "Incorrect exchangeConfig.wbtc" );
        assertEq( getContract(address(exchangeConfig), "weth()"), address(weth), "Incorrect exchangeConfig.weth" );
        assertEq( getContract(address(exchangeConfig), "usdc()"), address(usdc), "Incorrect exchangeConfig.usdc" );
        assertEq( getContract(address(exchangeConfig), "usds()"), address(usds), "Incorrect exchangeConfig.usds" );
        assertEq( getContract(address(exchangeConfig), "accessManager()"), address(accessManager), "Incorrect exchangeConfig.accessManager" );
//        assertEq( getContract(address(exchangeConfig), "aaa()"), address(aaa), "Incorrect exchangeConfig.aaa" );
//        assertEq( getContract(address(exchangeConfig), "dao()"), address(dao), "Incorrect exchangeConfig.dao" );
//        assertEq( getContract(address(exchangeConfig), "optimizer()"), address(optimizer), "Incorrect exchangeConfig.optimizer" );
//        assertEq( getContract(address(exchangeConfig), "liquidator()"), address(liquidator), "Incorrect exchangeConfig.liquidator" );

        assertEq( getContract(address(pools), "exchangeConfig()"), address(exchangeConfig), "Incorrect pools.exchangeConfig" );

        assertEq( getContract(address(staking), "exchangeConfig()"), address(exchangeConfig), "Incorrect staking.exchangeConfig" );
        assertEq( getContract(address(staking), "poolsConfig()"), address(poolsConfig), "Incorrect staking.poolsConfig" );
        assertEq( getContract(address(staking), "stakingConfig()"), address(stakingConfig), "Incorrect staking.stakingConfig" );

        assertEq( getContract(address(liquidity), "pools()"), address(pools), "Incorrect liquidity.pools" );
        assertEq( getContract(address(liquidity), "exchangeConfig()"), address(exchangeConfig), "Incorrect liquidity.exchangeConfig" );
        assertEq( getContract(address(liquidity), "poolsConfig()"), address(poolsConfig), "Incorrect liquidity.poolsConfig" );
        assertEq( getContract(address(liquidity), "stakingConfig()"), address(stakingConfig), "Incorrect liquidity.stakingConfig" );

//		assertEq( getContract(address(dao), "stakingConfig()"), address(stakingConfig), "Incorrect dao.stakingConfig" );
//		assertEq( getContract(address(dao), "daoConfig()"), address(daoConfig), "Incorrect dao.daoConfig" );
//        assertEq( getContract(address(dao), "exchangeConfig()"), address(exchangeConfig), "Incorrect dao.exchangeConfig" );
//        assertEq( getContract(address(dao), "staking()"), address(staking), "Incorrect dao.staking" );
//        assertEq( getContract(address(dao), "rewardsConfig()"), address(rewardsConfig), "Incorrect dao.rewardsConfig" );
//        assertEq( getContract(address(dao), "stableConfig()"), address(stableConfig), "Incorrect dao.stableConfig" );
//        assertEq( getContract(address(dao), "liquidity()"), address(liquidity), "Incorrect dao.liquidity" );
//        assertEq( getContract(address(dao), "stableConfig()"), address(stableConfig), "Incorrect dao.stableConfig" );
//        assertEq( getContract(address(dao), "liquidityRewardsEmitter()"), address(liquidityRewardsEmitter), "Incorrect dao.liquidityRewardsEmitter" );
//        assertEq( getContract(address(dao), "factory()"), address(factory), "Incorrect dao.factory" );
//

		assertEq( getContract(address(stakingRewardsEmitter), "stakingRewards()"), address(staking), "Incorrect stakingRewardsEmitter.stakingRewards" );
        assertEq( getContract(address(stakingRewardsEmitter), "poolsConfig()"), address(poolsConfig), "Incorrect stakingRewardsEmitter.poolsConfig" );
        assertEq( getContract(address(stakingRewardsEmitter), "stakingConfig()"), address(stakingConfig), "Incorrect stakingRewardsEmitter.stakingConfig" );
		assertEq( getContract(address(stakingRewardsEmitter), "rewardsConfig()"), address(rewardsConfig), "Incorrect stakingRewardsEmitter.rewardsConfig" );

		assertEq( getContract(address(liquidityRewardsEmitter), "stakingRewards()"), address(liquidity), "Incorrect liquidityRewardsEmitter.stakingRewards" );
        assertEq( getContract(address(liquidityRewardsEmitter), "poolsConfig()"), address(poolsConfig), "Incorrect liquidityRewardsEmitter.poolsConfig" );
        assertEq( getContract(address(liquidityRewardsEmitter), "stakingConfig()"), address(stakingConfig), "Incorrect liquidityRewardsEmitter.stakingConfig" );
		assertEq( getContract(address(liquidityRewardsEmitter), "rewardsConfig()"), address(rewardsConfig), "Incorrect liquidityRewardsEmitter.rewardsConfig" );
//
//        assertEq( getContract(address(collateralRewardsEmitter), "rewardsConfig()"), address(rewardsConfig), "Incorrect collateralRewardsEmitter.rewardsConfig" );
//        assertEq( getContract(address(collateralRewardsEmitter), "stakingConfig()"), address(stakingConfig), "Incorrect collateralRewardsEmitter.stakingConfig" );
//        assertEq( getContract(address(collateralRewardsEmitter), "sharedRewards()"), address(collateral), "Incorrect collateralRewardsEmitter.sharedRewards" );

        assertEq( getContract(address(emissions), "staking()"), address(staking), "Incorrect emissions.staking" );
        assertEq( getContract(address(emissions), "stakingRewardsEmitter()"), address(stakingRewardsEmitter), "Incorrect emissions.stakingRewardsEmitter" );
        assertEq( getContract(address(emissions), "liquidityRewardsEmitter()"), address(liquidityRewardsEmitter), "Incorrect emissions.liquidityRewardsEmitter" );
		assertEq( getContract(address(emissions), "stakingConfig()"), address(stakingConfig), "Incorrect emissions.stakingConfig" );
		assertEq( getContract(address(emissions), "poolsConfig()"), address(poolsConfig), "Incorrect emissions.poolsConfig" );
        assertEq( getContract(address(emissions), "rewardsConfig()"), address(rewardsConfig), "Incorrect emissions.rewardsConfig" );

//        if ( DEBUG )
//        	assertTrue( functionExists( address(priceFeed), "forcedPriceBTCWith18Decimals()" ), "For DEBUG: The PriceFeed should be a ForcedPriceFeed" );
//        else
//        	{
//        	assertFalse( functionExists( address(priceFeed), "forcedPriceBTCWith18Decimals()" ), "For DEBUG: The PriceFeed should not be a ForcedPriceFeed" );
//
//        	assertEq( getContract( address(priceFeed), "CHAINLINK_BTC_USD()" ), address(0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c), "Incorrect BTC/USD Chainlink price feed" );
//        	assertEq( getContract( address(priceFeed), "CHAINLINK_ETH_USD()" ), address(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419), "Incorrect ETH/USD Chainlink price feed" );
//        	assertEq( getContract( address(priceFeed), "UNISWAP_V3_BTC_ETH()" ), address(0x4585FE77225b41b697C938B018E2Ac67Ac5a20c0), "Incorrect BTC/ETH Uniswap v3 Pool" );
//        	assertEq( getContract( address(priceFeed), "UNISWAP_V3_USDC_ETH()" ), address(0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640), "Incorrect ETH/USDC Uniswap v3 Pool" );
//        	}

//
//		assertEq( getContract(address(collateral), "collateralLP()"), address(collateralLP), "Incorrect collateral.collateralLP" );
//        assertEq( getContract(address(collateral), "stableConfig()"), address(stableConfig), "Incorrect collateral.stableConfig" );
//        assertEq( getContract(address(collateral), "stakingConfig()"), address(stakingConfig), "Incorrect collateral.stakingConfig" );
//        assertEq( getContract(address(collateral), "exchangeConfig()"), address(exchangeConfig), "Incorrect collateral.exchangeConfig" );
//
//		assertEq( getContract(address(liquidator), "collateralLP()"), address(collateralLP), "Incorrect liquidator.collateralLP" );
//        assertEq( getContract(address(liquidator), "router()"), address(router), "Incorrect liquidator.router" );
//        assertEq( getContract(address(liquidator), "collateral()"), address(collateral), "Incorrect liquidator.collateral" );
//        assertEq( getContract(address(liquidator), "stableConfig()"), address(stableConfig), "Incorrect liquidator.stableConfig" );
//        assertEq( getContract(address(liquidator), "exchangeConfig()"), address(exchangeConfig), "Incorrect liquidator.exchangeConfig" );
//
//        assertEq( getContract(address(stableConfig), "priceFeed()"), address(priceFeed), "Incorrect stableConfig.priceFeed" );
//
//        assertEq( getContract(address(usds), "collateral()"), address(collateral), "Incorrect usds.collateral" );
//
//
//        assertEq( getContract(address(aaa), "liquidityRewardsEmitter()"), address(liquidityRewardsEmitter), "Incorrect aaa.liquidityRewardsEmitter" );
//        assertEq( getContract(address(aaa), "stakingRewardsEmitter()"), address(stakingRewardsEmitter), "Incorrect aaa.stakingRewardsEmitter" );
//        assertEq( getContract(address(aaa), "collateralRewardsEmitter()"), address(collateralRewardsEmitter), "Incorrect aaa.collateralRewardsEmitter" );
//        assertEq( getContract(address(aaa), "optimizer()"), address(optimizer), "Incorrect aaa.optimizer" );
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
   		console.log( "deployed pools: ", address(pools) );
   		console.log( "deployed exchangeConfig: ", address(exchangeConfig) );
   		console.log( "deployed poolsConfig: ", address(poolsConfig) );
//   		console.log( "deployed stakingConfig: ", address(stakingConfig) );
   		console.log( "deployed accessManager: ", address(accessManager) );
   		console.log( "deployed salt: ", address(salt) );
   		console.log( "deployed wbtc: ", address(wbtc) );
   		console.log( "deployed weth: ", address(weth) );
   		console.log( "deployed usdc: ", address(usdc) );
   		console.log( "deployed usds: ", address(usds) );

//   		console.log( "deployed emissions: ", address(emissions) );
//   		console.log( "deployed dao: ", address(dao) );
//   		console.log( "deployed aaa: ", address(aaa) );
//   		console.log( "deployed liquidator: ", address(liquidator) );
//   		console.log( "deployed optimizer: ", address(optimizer) );
//   		console.log( "deployed daoConfig: ", address(daoConfig) );
//   		console.log( "deployed rewardsConfig: ", address(rewardsConfig) );
//   		console.log( "deployed stableConfig: ", address(stableConfig) );
//   		console.log( "deployed stakingConfig: ", address(stakingConfig) );
//   		console.log( "deployed staking: ", address(staking) );
//   		console.log( "deployed liquidity: ", address(liquidity) );
//   		console.log( "deployed liquidityRewardsEmitter: ", address(liquidityRewardsEmitter) );
//   		console.log( "deployed stakingRewardsEmitter: ", address(stakingRewardsEmitter) );
//   		console.log( "deployed collateralRewardsEmitter: ", address(collateralRewardsEmitter) );
//   		console.log( "deployed collateral: ", address(collateral) );
//   		console.log( "deployed priceFeed: ", address(priceFeed) );
//   		console.log( "deployed collateralLP: ", address(collateralLP) );
   		}
    }

