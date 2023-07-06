// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.12;

import "forge-std/Test.sol";
import "./pools/interfaces/IPools.sol";
import "./pools/interfaces/IPoolsConfig.sol";
import "./interfaces/IExchangeConfig.sol";
import "./stable/USDS.sol";
import "./staking/interfaces/IStakingConfig.sol";
import "./staking/interfaces/IStaking.sol";
//import "./openzeppelin/token/ERC20/IERC20.sol";
//import "./stable/tests/IForcedPriceFeed.sol";
//import "./dao/interfaces/IDAOConfig.sol";
//import "./rewards/interfaces/IRewardsConfig.sol";
//import "./rewards/interfaces/IEmissions.sol";
//import "./rewards//RewardsEmitter.sol";
//import "./stable/interfaces/IStableConfig.sol";
//import "./staking/Staking.sol";
//import "./staking/Liquidity.sol";
//import "./interfaces/IUpkeepable.sol";
//import "./Salt.sol";


// Stores the contract addresses for the various parts of the exchange and allows the unit tests to be run on them.

contract Deployment is Test
    {
    bool public DEBUG = true;
	address constant public DEPLOYER = 0x73107dA86708c2DAd0D91388fB057EeE3E2581aF;

	IPools public pools = IPools(address(0xBbB5A43F51F951c477080578bB7f98CBcF88131b));
	IStaking public staking = IStaking(address(0xFff87D41195949f8c6c52CFd0d526D23FfA78175));

	IExchangeConfig public exchangeConfig = pools.exchangeConfig();
	IPoolsConfig public poolsConfig = IPoolsConfig(address(0x4DC9Bf826612fD778719BE892442cb0921608209));
	IStakingConfig public stakingConfig = staking.stakingConfig();

	ISalt public salt = exchangeConfig.salt();
    IERC20 public wbtc = exchangeConfig.wbtc();
    IERC20 public weth = exchangeConfig.weth();
    IERC20 public usdc = exchangeConfig.usdc();
    USDS public usds = USDS(address(exchangeConfig.usds()));


//	IPoolsConfig = IStakingConfig
//	IEmissions public emissions = IEmissions(address(0x72B5fDd1284B10Ff526a9Ebc6eF6904A0Ee097EC));
//
//
//	IDAO public dao = exchangeConfig.dao();
//	IAAA public aaa = exchangeConfig.aaa();
//	ILiquidator public liquidator = exchangeConfig.liquidator();
//	IPOL_Optimizer public optimizer = exchangeConfig.optimizer();
	IAccessManager public accessManager = exchangeConfig.accessManager();
//
//	IDAOConfig public daoConfig = dao.daoConfig();
//	IRewardsConfig public rewardsConfig = dao.rewardsConfig();
//	IStableConfig public stableConfig = dao.stableConfig();
//
//	ILiquidity public liquidity = ILiquidity(address(dao.liquidity()));
//	IRewardsEmitter public liquidityRewardsEmitter = dao.liquidityRewardsEmitter();
//	IRewardsEmitter public stakingRewardsEmitter = emissions.stakingRewardsEmitter();
//	IRewardsEmitter public collateralRewardsEmitter = IRewardsEmitter(aaa.collateralRewardsEmitterAddress());
//
//	ICollateral public collateral = liquidator.collateral();
//
//
//	IPriceFeed public priceFeed = stableConfig.priceFeed();
//    IUniswapV2Pair public collateralLP = IUniswapV2Pair( factory.getPair( address(wbtc), address(weth) ));

	// A special pool that represents staked SALT that is not associated with any particular pool.
	bytes32 public constant STAKED_SALT = bytes32(0);
	}




