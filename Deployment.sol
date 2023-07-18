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
import "./dao/interfaces/IDAOConfig.sol";
import "./dao/interfaces/IDAO.sol";
import "./dao/interfaces/IProposals.sol";
//import "./openzeppelin/token/ERC20/IERC20.sol";
//import "./stable/tests/IForcedPriceFeed.sol";
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

	IPools public pools = IPools(address(0x7195dD7efE20B08EBb570B067cF5186862d80c76));
	Emissions public emissions = Emissions(address(0xFb46A5c86be9FEef912cA28d55972B7f8c751E56));

	IExchangeConfig public exchangeConfig = IExchangeConfig(getContract(address(pools), "exchangeConfig()" ));

	ISalt public salt = exchangeConfig.salt();
    IERC20 public wbtc = exchangeConfig.wbtc();
    IERC20 public weth = exchangeConfig.weth();
    IERC20 public usdc = exchangeConfig.usdc();
    USDS public usds = USDS(address(exchangeConfig.usds()));

	IRewardsEmitter public stakingRewardsEmitter = IRewardsEmitter(getContract(address(exchangeConfig), "stakingRewardsEmitter()" ));
	IRewardsEmitter public liquidityRewardsEmitter = IRewardsEmitter(getContract(address(exchangeConfig), "liquidityRewardsEmitter()" ));
	IRewardsEmitter public collateralRewardsEmitter = IRewardsEmitter(getContract(address(exchangeConfig), "collateralRewardsEmitter()" ));

	IStaking public staking = IStaking(getContract(address(stakingRewardsEmitter), "stakingRewards()" ));
	ILiquidity public liquidity = ILiquidity(getContract(address(liquidityRewardsEmitter), "stakingRewards()" ));
	ICollateral public collateral = ICollateral(getContract(address(collateralRewardsEmitter), "stakingRewards()" ));

	IPoolsConfig public poolsConfig = IPoolsConfig(getContract(address(staking), "poolsConfig()" ));
	IStakingConfig public stakingConfig = IStakingConfig(getContract(address(staking), "stakingConfig()" ));
	IStableConfig public stableConfig = IStableConfig(getContract(address(usds), "stableConfig()" ));
	IRewardsConfig public rewardsConfig = IRewardsConfig(getContract(address(emissions), "rewardsConfig()" ));
	IDAOConfig public daoConfig = IDAOConfig(address(0x715767D39E1Ad1457f9156dd21fbB31195ef5Da0));

	IPriceFeed public priceFeed = stableConfig.priceFeed();
	IAccessManager public accessManager = exchangeConfig.accessManager();

	IDAO public dao = IDAO(getContract(address(exchangeConfig), "dao()" ));
	IProposals public proposals = IProposals(getContract(address(dao), "proposals()" ));

//	IDAO public dao = exchangeConfig.dao();
//	IAAA public aaa = exchangeConfig.aaa();
//	IPOL_Optimizer public optimizer = exchangeConfig.optimizer();

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




