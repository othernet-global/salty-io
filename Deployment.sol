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

	IPools public pools = IPools(address(0xAf30553D3aBd9A33094797C11D5E901a9F06a81E));
	IStaking public staking = IStaking(address(0xF8d347B2f0a27FDB73486c1298fFe17C3f631301));
	ILiquidity public liquidity = ILiquidity(address(0x5012e7E85073dFE447D846C7Cd856c7d219086F4));
	ICollateral public collateral = ICollateral(address(0x0));

	IExchangeConfig public exchangeConfig = IExchangeConfig(getContract(address(staking), "exchangeConfig()" ));
	IPoolsConfig public poolsConfig = IPoolsConfig(getContract(address(staking), "poolsConfig()" ));
	IStakingConfig public stakingConfig = IStakingConfig(getContract(address(staking), "stakingConfig()" ));
//	IStableConfig public stableConfig = collateral.stableConfig();
	IRewardsConfig public rewardsConfig = IRewardsConfig(address(0x52C689c75D561ec7eFAcD3D374900289A06A4c79));

	IRewardsEmitter public stakingRewardsEmitter = IRewardsEmitter(address(0x5b166406a043516CD741F6D017968AD47Fc13145));
	IRewardsEmitter public liquidityRewardsEmitter = IRewardsEmitter(address(0x495C4FfF0Aa5C1e927923d038c9eec8E8299C39d));
//	IRewardsEmitter public collateralRewardsEmitter = IRewardsEmitter(aaa.collateralRewardsEmitterAddress());

	Emissions public emissions = Emissions(address(0x73a3F7266a1C763Fa2B40f06C9c6B260C239d733));
//	IPriceFeed public priceFeed = stableConfig.priceFeed();

	ISalt public salt = exchangeConfig.salt();
    IERC20 public wbtc = exchangeConfig.wbtc();
    IERC20 public weth = exchangeConfig.weth();
    IERC20 public usdc = exchangeConfig.usdc();
    USDS public usds = USDS(address(exchangeConfig.usds()));


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




