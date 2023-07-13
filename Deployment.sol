// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.12;

import "forge-std/Test.sol";
import "./pools/interfaces/IPools.sol";
import "./pools/interfaces/IPoolsConfig.sol";
import "./interfaces/IExchangeConfig.sol";
import "./stable/USDS.sol";
import "./staking/interfaces/IStakingConfig.sol";
import "./staking/interfaces/IStaking.sol";
import "./staking/interfaces/ILiquidity.sol";
import "./rewards/interfaces/IRewardsEmitter.sol";
import "./rewards/Emissions.sol";
//import "./openzeppelin/token/ERC20/IERC20.sol";
//import "./stable/tests/IForcedPriceFeed.sol";
//import "./dao/interfaces/IDAOConfig.sol";
//import "./rewards//RewardsEmitter.sol";
//import "./stable/interfaces/IStableConfig.sol";
//import "./staking/Staking.sol";
//import "./interfaces/IUpkeepable.sol";
//import "./Salt.sol";


// Stores the contract addresses for the various parts of the exchange and allows the unit tests to be run on them.

contract Deployment is Test
    {
    bool public DEBUG = true;
	address constant public DEPLOYER = 0x73107dA86708c2DAd0D91388fB057EeE3E2581aF;

	IPools public pools = IPools(address(0xb69148b4E8ca6e7AB7C6DD6BbC9246951e6ef17c));
	IExchangeConfig public exchangeConfig = IExchangeConfig(getContract(address(pools), "exchangeConfig()" ));

	ISalt public salt = exchangeConfig.salt();
    IERC20 public wbtc = exchangeConfig.wbtc();
    IERC20 public weth = exchangeConfig.weth();
    IERC20 public usdc = exchangeConfig.usdc();
    USDS public usds = USDS(address(exchangeConfig.usds()));

	IStaking public staking = IStaking(address(0x8f9E3bFde74aB5c38D72959C31E725713a550773));
	ILiquidity public liquidity = ILiquidity(address(0x2fA3c84e8929fFA330502F4922a586010E2c165C));
	ICollateral public collateral = ICollateral(getContract(address(usds), "collateral()" ));

	Emissions public emissions = Emissions(address(0x19033Bc67cEe1901D060B06bB63C22a02AA04470));



	IPoolsConfig public poolsConfig = IPoolsConfig(getContract(address(staking), "poolsConfig()" ));
	IStakingConfig public stakingConfig = IStakingConfig(getContract(address(staking), "stakingConfig()" ));
	IStableConfig public stableConfig = IStableConfig(getContract(address(usds), "stableConfig()" ));
	IRewardsConfig public rewardsConfig = IRewardsConfig(getContract(address(emissions), "rewardsConfig()" ));

	IRewardsEmitter public stakingRewardsEmitter = IRewardsEmitter(getContract(address(emissions), "stakingRewardsEmitter()" ));
	IRewardsEmitter public liquidityRewardsEmitter = IRewardsEmitter(getContract(address(emissions), "liquidityRewardsEmitter()" ));
//	IRewardsEmitter public collateralRewardsEmitter = IRewardsEmitter(aaa.collateralRewardsEmitterAddress());

	IPriceFeed public priceFeed = stableConfig.priceFeed();



	IAccessManager public accessManager = exchangeConfig.accessManager();


//
//
//	IDAO public dao = exchangeConfig.dao();
//	IAAA public aaa = exchangeConfig.aaa();
//	ILiquidator public liquidator = exchangeConfig.liquidator();
//	IPOL_Optimizer public optimizer = exchangeConfig.optimizer();
//
//	IDAOConfig public daoConfig = dao.daoConfig();
//
//
//
//    IUniswapV2Pair public collateralLP = IUniswapV2Pair( factory.getPair( address(wbtc), address(weth) ));

	// A special pool that represents staked SALT that is not associated with any particular pool.
	bytes32 public constant STAKED_SALT = bytes32(0);


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

	}




