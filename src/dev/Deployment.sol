// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "forge-std/Test.sol";
import "../pools/interfaces/IPools.sol";
import "../pools/interfaces/IPoolsConfig.sol";
import "../interfaces/IExchangeConfig.sol";
import "../stable/USDS.sol";
import "../stable/interfaces/IStableConfig.sol";
import "../price_feed/interfaces/IPriceAggregator.sol";
import "../staking/interfaces/IStakingConfig.sol";
import "../staking/interfaces/IStaking.sol";
import "../staking/Staking.sol";
import "../rewards/interfaces/IRewardsEmitter.sol";
import "../rewards/Emissions.sol";
import "../dao/interfaces/IDAOConfig.sol";
import "../dao/interfaces/IDAO.sol";
import "../dao/interfaces/IProposals.sol";
import "../price_feed/tests/IForcedPriceFeed.sol";
import "../launch/interfaces/IBootstrapBallot.sol";
import "openzeppelin-contracts/contracts/finance/VestingWallet.sol";
import "../launch/interfaces/IAirdrop.sol";
import "../dao/Proposals.sol";
import "../dao/DAO.sol";
import "../AccessManager.sol";
import "../rewards/SaltRewards.sol";
import "../launch/InitialDistribution.sol";
import "../pools/PoolsConfig.sol";
import "../ExchangeConfig.sol";
import "../price_feed/PriceAggregator.sol";
import "../pools/Pools.sol";
import "../staking/Liquidity.sol";
import "../stable/CollateralAndLiquidity.sol";
import "../rewards/RewardsEmitter.sol";
import "../root_tests/TestERC20.sol";
import "../launch/Airdrop.sol";
import "../launch/BootstrapBallot.sol";
import "../stable/interfaces/ILiquidizer.sol";
import "../stable/Liquidizer.sol";
import "../stable/StableConfig.sol";
import "../Salt.sol";
import "../ManagedWallet.sol";
import "../dao/DAOConfig.sol";

// Stores the contract addresses for the various parts of the exchange and allows the unit tests to be run on them.

contract Deployment is Test
    {
    bool public DEBUG = true;
	address constant public DEPLOYER = 0x73107dA86708c2DAd0D91388fB057EeE3E2581aF;

	// Test addresses on Sepolia for the Price Feeds
	address public CHAINLINK_BTC_USD = 0x65EC417a4C95d6FE6FB11EBFa86FAFEaE2B3bE2F;
	address public CHAINLINK_ETH_USD = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
	address public UNISWAP_V3_BTC_ETH = 0xFb9785B2CA67AF31087945BCCd02D00768208e38;
	address public UNISWAP_V3_USDC_ETH = 0x3EcF4D43d1C7EC1A609d554BAb2565b223831349;
	IERC20 public _testBTC = IERC20(0xd4C3cc58E46C99fbA0c4e4d93C82AE32000cc4D4);
	IERC20 public _testETH = IERC20(0x14edfAb9FAE5fe2396565903763Cb29E0d7be7d9);
	IERC20 public _testUSDC = IERC20(0x9C65b1773A95d607f41fa205511cd3327cc39D9D);
	IForcedPriceFeed public forcedPriceFeed = IForcedPriceFeed(address(0x3B0Eb37f26b502bAe83df4eCc54afBDfb90B5d3a));

	// The DAO contract can provide us with all other contract addresses in the protocol
	IDAO public dao = IDAO(address(0x112223db8E32d056170da32FD3Dba90adCa50159));

	IExchangeConfig public exchangeConfig = IExchangeConfig(getContract(address(dao), "exchangeConfig()" ));
	IPoolsConfig public poolsConfig = IPoolsConfig(getContract(address(dao), "poolsConfig()" ));
	IStakingConfig public stakingConfig = IStakingConfig(getContract(address(dao), "stakingConfig()" ));
	IStableConfig public stableConfig = IStableConfig(getContract(address(dao), "stableConfig()" ));
	IRewardsConfig public rewardsConfig = IRewardsConfig(getContract(address(dao), "rewardsConfig()" ));
	IDAOConfig public daoConfig = IDAOConfig(getContract(address(dao), "daoConfig()" ));
	IPriceAggregator public priceAggregator = IPriceAggregator(getContract(address(dao), "priceAggregator()" ));

	IManagedWallet public managedTeamWallet = exchangeConfig.managedTeamWallet();
	address public teamWallet = managedTeamWallet.mainWallet();
	address public teamConfirmationWallet = managedTeamWallet.confirmationWallet();

	IUpkeep public upkeep = exchangeConfig.upkeep();
	IEmissions public emissions = IEmissions(getContract(address(upkeep), "emissions()" ));

	ISalt public salt = exchangeConfig.salt();
    IERC20 public wbtc = exchangeConfig.wbtc();
    IERC20 public weth = exchangeConfig.weth();
    IERC20 public dai = exchangeConfig.dai();
    USDS public usds = USDS(address(exchangeConfig.usds()));

	ISaltRewards public saltRewards = ISaltRewards(getContract(address(upkeep), "saltRewards()" ));
	IRewardsEmitter public stakingRewardsEmitter = IRewardsEmitter(getContract(address(saltRewards), "stakingRewardsEmitter()" ));
	IRewardsEmitter public liquidityRewardsEmitter = IRewardsEmitter(getContract(address(saltRewards), "liquidityRewardsEmitter()" ));

	IStaking public staking = IStaking(getContract(address(stakingRewardsEmitter), "stakingRewards()" ));
	ICollateralAndLiquidity public collateralAndLiquidity = ICollateralAndLiquidity(getContract(address(usds), "collateralAndLiquidity()" ));
	ILiquidizer  public liquidizer = ILiquidizer( getContract(address(collateralAndLiquidity), "liquidizer()" ));
	IPools public pools = IPools(getContract(address(collateralAndLiquidity), "pools()" ));

	IProposals public proposals = IProposals(getContract(address(dao), "proposals()" ));

	IAccessManager public accessManager = exchangeConfig.accessManager();

	VestingWallet public daoVestingWallet = VestingWallet(payable(exchangeConfig.daoVestingWallet()));
	VestingWallet public teamVestingWallet = VestingWallet(payable(exchangeConfig.teamVestingWallet()));

	IInitialDistribution public initialDistribution = exchangeConfig.initialDistribution();
	IAirdrop public airdrop = IAirdrop(getContract(address(initialDistribution), "airdrop()" ));
	IBootstrapBallot public bootstrapBallot = IBootstrapBallot(getContract(address(initialDistribution), "bootstrapBallot()" ));

	// Access signatures
	bytes aliceAccessSignature = hex"a34525874e8d962ca56353ee341719744ce31cb7558e2fbcfe25edb82924bf93460bf47d787dd6ca17382424919cdfa2a525f762ad8eac7292f56be6053c461d1b";
	bytes bobAccessSignature = hex"8df147d8434c21eec85c39a7372de1c49c4d9a031089d74034aa6baeed9c5b9e0d8234d966956bc92cba35e9e527f97ddd952e3125bf48da306fdc800349480f1b";
	bytes charlieAccessSignature = hex"8e2f4b7ee253a53ae9167de5182f612cd3b3b76566c34a448d6544d1bbeda6c574e5c98da44df387766a6c936e041d813ced8af26cff2ead588d13466d3217951c";
	bytes deployerAccessSignature = hex"94b8d45a45a9e6c48a1f110a1371c6f36e8638b8faaa0785af1254c52e51db656c4367ef191327b59334a228db8cbaaa892d4ee7c332fcd59378082a640190211c";
	bytes defaultAccessSignature = hex"c05e8d92e0cc66ddce0c88a1b49335866a2af521add73bbf904cd76db9a7934a0ee49f6f60f4ba90cf8fe44564b8fc3a1314625639518d3ba82317dc3d8363f11c";
	bytes teamAccessSignature = hex"a6980de89b6a0696affae222317f5317438b5c3823ce18cace5d9078bbf7b17c45a71cc823149a1c478d6503ed869dd4d6f6c33acd6d08a9518e12a7f82e781b1b";
	bytes oneTwoThreeFourAccessSignature = hex"1c4f137653c4d06e5e0230b4e741667037b44bc944d9165884f914163a0da6d6480705db5584bbbf28e42e783ec2cbfbb4e3602c4f7eb55cce68184b114818121c";

	bytes aliceAccessSignature1 = hex"4fbe3e8f1daba07f674f831ccfae103f2b172b547f51826e1b4673962d8ca2e14170e1fb2793ca5ef12a067db6a99ae1891cb8e1e7f7c70872bb442ce6df6b051c";
	bytes bobAccessSignature1 = hex"6cd08533c08306735cb435c8b3ef43f3307b8083f679e0b60728e3a8de243e7f3af8b5e81fd156a726702a5c9e232fb027420b2ccdb848a1d7fd0ede4ae1e47c1c";
	bytes charlieAccessSignature1 = hex"4c0901d584be8b570a8a03a2c4bdd60ac3339c4bef4b27d9bc292d1eaeaed02b30b65c69f42ec2404dd420c1bf9cb16bf44875258e385c004dd67eecc726e8811b";

	// Voting signatures
	bytes aliceVotingSignature = hex"291f777bcf554105b4067f14d2bb3da27f778af49fe2f008e718328a91cae2f81eceb0b4ed1d65c546bf0603c6c35567a69c8cb371cf4880a2964df8f6d1c0601c";
	bytes bobVotingSignature = hex"a08a0612b60d9c911d357664de578cd8e17c5f0ee10b82b829e35a999fa3f5e11a33e5f3d06c6b2b6f3ef3066cee3b47285a57cfc85f2c3e166f831a285aebcd1c";
	bytes charlieVotingSignature = hex"7fec06ab9da26790e4520b4476b7043ef8444178ec10cdf37942a229290ec70d01c7dced0a6e22080239df6fdc3983f515f52d06a32c03d5d6a0077f31fd9f841c";


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


	function initializeContracts() public
		{
//		console.log( "DEFAULT: ", address(this) );

		vm.startPrank(DEPLOYER);
		dai = new TestERC20("DAI", 18);
		weth = new TestERC20("WETH", 18);
		wbtc = new TestERC20("WBTC", 8);
		salt = new Salt();
		vm.stopPrank();

		vm.startPrank(DEPLOYER);

		daoConfig = new DAOConfig();
		poolsConfig = new PoolsConfig();
		usds = new USDS();

		managedTeamWallet = new ManagedWallet(teamWallet, teamConfirmationWallet);
		exchangeConfig = new ExchangeConfig(salt, wbtc, weth, dai, usds, managedTeamWallet );

		priceAggregator = new PriceAggregator();
		priceAggregator.setInitialFeeds( IPriceFeed(address(forcedPriceFeed)), IPriceFeed(address(forcedPriceFeed)), IPriceFeed(address(forcedPriceFeed)) );

		liquidizer = new Liquidizer(exchangeConfig, poolsConfig);

		pools = new Pools(exchangeConfig, poolsConfig);
		staking = new Staking( exchangeConfig, poolsConfig, stakingConfig );
		collateralAndLiquidity = new CollateralAndLiquidity(pools, exchangeConfig, poolsConfig, stakingConfig, stableConfig, priceAggregator, liquidizer);

		stakingRewardsEmitter = new RewardsEmitter( staking, exchangeConfig, poolsConfig, rewardsConfig, false );
		liquidityRewardsEmitter = new RewardsEmitter( collateralAndLiquidity, exchangeConfig, poolsConfig, rewardsConfig, true );

		saltRewards = new SaltRewards(stakingRewardsEmitter, liquidityRewardsEmitter, exchangeConfig, rewardsConfig);
		emissions = new Emissions( saltRewards, exchangeConfig, rewardsConfig );

		poolsConfig.whitelistPool( pools,  salt, wbtc);
		poolsConfig.whitelistPool( pools,  salt, weth);
		poolsConfig.whitelistPool( pools,  salt, usds);
		poolsConfig.whitelistPool( pools,  wbtc, usds);
		poolsConfig.whitelistPool( pools,  weth, usds);
		poolsConfig.whitelistPool( pools,  wbtc, dai);
		poolsConfig.whitelistPool( pools,  weth, dai);
		poolsConfig.whitelistPool( pools,  usds, dai);
		poolsConfig.whitelistPool( pools,  wbtc, weth);

		proposals = new Proposals( staking, exchangeConfig, poolsConfig, daoConfig );

		address oldDAO = address(dao);
		dao = new DAO( pools, proposals, exchangeConfig, poolsConfig, stakingConfig, rewardsConfig, stableConfig, daoConfig, priceAggregator, liquidityRewardsEmitter, collateralAndLiquidity);

		airdrop = new Airdrop(exchangeConfig, staking);

		accessManager = new AccessManager(dao);

		liquidizer.setContracts(collateralAndLiquidity, pools, dao);

		upkeep = new Upkeep(pools, exchangeConfig, poolsConfig, daoConfig, stableConfig, priceAggregator, saltRewards, collateralAndLiquidity, emissions, dao);

		daoVestingWallet = new VestingWallet( address(dao), uint64(block.timestamp), 60 * 60 * 24 * 365 * 10 );
		teamVestingWallet = new VestingWallet( address(upkeep), uint64(block.timestamp), 60 * 60 * 24 * 365 * 10 );

		bootstrapBallot = new BootstrapBallot(exchangeConfig, airdrop, 60 * 60 * 24 * 5 );
		initialDistribution = new InitialDistribution(salt, poolsConfig, emissions, bootstrapBallot, dao, daoVestingWallet, teamVestingWallet, airdrop, saltRewards, collateralAndLiquidity);

		pools.setContracts(dao, collateralAndLiquidity);
		usds.setCollateralAndLiquidity(collateralAndLiquidity);

		exchangeConfig.setContracts(dao, upkeep, initialDistribution, airdrop, teamVestingWallet, daoVestingWallet );
		exchangeConfig.setAccessManager(accessManager);

		// Transfer ownership of the newly created config files to the DAO
		Ownable(address(exchangeConfig)).transferOwnership( address(dao) );
		Ownable(address(poolsConfig)).transferOwnership( address(dao) );
		Ownable(address(priceAggregator)).transferOwnership(address(dao));
		Ownable(address(daoConfig)).transferOwnership( address(dao) );
		vm.stopPrank();

		vm.startPrank(address(oldDAO));
		Ownable(address(stakingConfig)).transferOwnership( address(dao) );
		Ownable(address(rewardsConfig)).transferOwnership( address(dao) );
		Ownable(address(stableConfig)).transferOwnership( address(dao) );
		vm.stopPrank();

		// Move the SALT to the new initialDistribution contract
		vm.prank(DEPLOYER);
		salt.transfer(address(initialDistribution), 100000000 ether);
		}


	function grantAccessAlice() public
		{
		bytes memory sig = abi.encodePacked(aliceAccessSignature);

		vm.prank( address(0x1111) );
		accessManager.grantAccess(sig);
		}


	function grantAccessBob() public
		{
		bytes memory sig = abi.encodePacked(bobAccessSignature);

		vm.prank( address(0x2222) );
		accessManager.grantAccess(sig);
		}


	function grantAccessCharlie() public
		{
		bytes memory sig = abi.encodePacked(charlieAccessSignature);

		vm.prank( address(0x3333) );
		accessManager.grantAccess(sig);
		}


	function grantAccessDeployer() public
		{
		bytes memory sig = abi.encodePacked(deployerAccessSignature);

		vm.prank( 0x73107dA86708c2DAd0D91388fB057EeE3E2581aF );
		accessManager.grantAccess(sig);
		}


	function grantAccessDefault() public
		{
		bytes memory sig = abi.encodePacked(defaultAccessSignature);

		vm.prank( 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496 );
		accessManager.grantAccess(sig);
		}


	function grantAccessTeam() public
		{
		bytes memory sig = abi.encodePacked(teamAccessSignature);

		vm.prank( address(0x123456789 ));
		accessManager.grantAccess(sig);
		}





	function whitelistAlice() public
		{
		vm.prank( address(bootstrapBallot) );
		airdrop.authorizeWallet(address(0x1111));
		}


	function whitelistBob() public
		{
		vm.prank( address(bootstrapBallot) );
		airdrop.authorizeWallet(address(0x2222));
		}


	function whitelistCharlie() public
		{
		vm.prank( address(bootstrapBallot) );
		airdrop.authorizeWallet(address(0x3333));
		}


	function whitelistTeam() public
		{
		vm.prank( address(bootstrapBallot) );
		airdrop.authorizeWallet(address(0x123456789));
		}


	function finalizeBootstrap() public
		{
		address alice = address(0x1111);
		address bob = address(0x2222);

		whitelistAlice();
		whitelistBob();

		bytes memory sig = abi.encodePacked(aliceVotingSignature);
		vm.startPrank(alice);
		bootstrapBallot.vote(true, sig);
		vm.stopPrank();

		sig = abi.encodePacked(bobVotingSignature);
		vm.startPrank(bob);
		bootstrapBallot.vote(true, sig);
		vm.stopPrank();

		// Increase current blocktime to be greater than completionTimestamp
		vm.warp( bootstrapBallot.completionTimestamp() + 1);

		// Call finalizeBallot()
		bootstrapBallot.finalizeBallot();
		}
	}