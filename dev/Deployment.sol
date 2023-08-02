// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.21;

import "../pools/interfaces/IPools.sol";
import "../pools/interfaces/IPoolsConfig.sol";
import "../interfaces/IExchangeConfig.sol";
import "../stable/USDS.sol";
import "../staking/interfaces/IStakingConfig.sol";
import "../staking/interfaces/IStaking.sol";
import "../staking/interfaces/ILiquidity.sol";
import "../rewards/interfaces/IRewardsEmitter.sol";
import "../rewards/Emissions.sol";
import "../dao/interfaces/IDAOConfig.sol";
import "../dao/interfaces/IDAO.sol";
import "../dao/interfaces/IProposals.sol";
import "../price_feed/tests/IForcedPriceFeed.sol";


// Stores the contract addresses for the various parts of the exchange and allows the unit tests to be run on them.

contract Deployment
    {
    bool public DEBUG = true;
	address constant public DEPLOYER = 0x73107dA86708c2DAd0D91388fB057EeE3E2581aF;

	IForcedPriceFeed public forcedPriceFeed = IForcedPriceFeed(address(0x3B0Eb37f26b502bAe83df4eCc54afBDfb90B5d3a));

	IDAO public dao = IDAO(address(0xb66B49d7674dC52207a09dd902401b64Cd14C716));
	Emissions public emissions = Emissions(address(0x5bb846a251aa791308a9f4Ea21AF01EFF12CE633));

	IExchangeConfig public exchangeConfig = IExchangeConfig(getContract(address(dao), "exchangeConfig()" ));
	IPoolsConfig public poolsConfig = IPoolsConfig(getContract(address(dao), "poolsConfig()" ));
	IStakingConfig public stakingConfig = IStakingConfig(getContract(address(dao), "stakingConfig()" ));
	IStableConfig public stableConfig = IStableConfig(getContract(address(dao), "stableConfig()" ));
	IRewardsConfig public rewardsConfig = IRewardsConfig(getContract(address(dao), "rewardsConfig()" ));
	IDAOConfig public daoConfig = IDAOConfig(getContract(address(dao), "daoConfig()" ));
	IPriceAggregator public priceAggregator = IPriceAggregator(getContract(address(dao), "priceAggregator()" ));

	ISalt public salt = exchangeConfig.salt();
    IERC20 public wbtc = exchangeConfig.wbtc();
    IERC20 public weth = exchangeConfig.weth();
    IERC20 public usdc = exchangeConfig.usdc();
    USDS public usds = USDS(address(exchangeConfig.usds()));

	IRewardsEmitter public stakingRewardsEmitter = IRewardsEmitter(getContract(address(exchangeConfig), "stakingRewardsEmitter()" ));
	IRewardsEmitter public liquidityRewardsEmitter = IRewardsEmitter(getContract(address(exchangeConfig), "liquidityRewardsEmitter()" ));

	IStaking public staking = IStaking(getContract(address(stakingRewardsEmitter), "stakingRewards()" ));
	ILiquidity public liquidity = ILiquidity(getContract(address(liquidityRewardsEmitter), "stakingRewards()" ));
	ICollateral public collateral = ICollateral(getContract(address(usds), "collateral()" ));

	IPools public pools = IPools(getContract(address(collateral), "pools()" ));

	IProposals public proposals = IProposals(getContract(address(dao), "proposals()" ));

	IAccessManager public accessManager = exchangeConfig.accessManager();

	IArbitrageSearch public arbitrageSearch = IArbitrageSearch(getContract(address(poolsConfig), "arbitrageSearch()" ));

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




