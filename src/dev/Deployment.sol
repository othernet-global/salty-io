// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "forge-std/Test.sol";
import "../pools/interfaces/IPools.sol";
import "../pools/interfaces/IPoolsConfig.sol";
import "../interfaces/IExchangeConfig.sol";
import "../staking/interfaces/IStakingConfig.sol";
import "../staking/interfaces/IStaking.sol";
import "../staking/Staking.sol";
import "../rewards/interfaces/IRewardsEmitter.sol";
import "../rewards/Emissions.sol";
import "../dao/interfaces/IDAOConfig.sol";
import "../dao/interfaces/IDAO.sol";
import "../dao/interfaces/IProposals.sol";
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
import "../pools/Pools.sol";
import "../staking/Liquidity.sol";
import "../rewards/RewardsEmitter.sol";
import "../root_tests/TestERC20.sol";
import "../launch/Airdrop.sol";
import "../launch/BootstrapBallot.sol";
import "../Salt.sol";
import "../dao/DAOConfig.sol";
import "../rewards/RewardsConfig.sol";
import "../staking/StakingConfig.sol";


// Stores the contract addresses for the various parts of the exchange and allows the unit tests to be run on them.

contract Deployment is Test
    {
    // Default to running on mainnet
    bool public DEBUG = false;

	address constant public DEPLOYER = 0x73107dA86708c2DAd0D91388fB057EeE3E2581aF;

	// Test addresses on Sepolia for the Price Feeds
	address public CHAINLINK_BTC_USD = 0x65EC417a4C95d6FE6FB11EBFa86FAFEaE2B3bE2F;
	address public CHAINLINK_ETH_USD = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
	address public UNISWAP_V3_BTC_ETH = 0xFb9785B2CA67AF31087945BCCd02D00768208e38;
	address public UNISWAP_V3_USDC_ETH = 0x3EcF4D43d1C7EC1A609d554BAb2565b223831349;
	IERC20 public _testBTC = IERC20(0xd4C3cc58E46C99fbA0c4e4d93C82AE32000cc4D4);
	IERC20 public _testETH = IERC20(0x12e2cA2Cc70f1742EDA01C2980aC43Ca5F12CbFd);
	IERC20 public _testUSDC = IERC20(0x9C65b1773A95d607f41fa205511cd3327cc39D9D);
	IERC20 public _testUSDT = IERC20(0xCd58586cC5F0c6c425b99BB94Dc5662cf2A18B84);

	// The DAO contract can provide us with all other contract addresses in the protocol
	IDAO public dao = IDAO(address(0xE92d34C646665252DF703A17Cc19CE8CC13D95b2));

	IExchangeConfig public exchangeConfig = IExchangeConfig(getContract(address(dao), "exchangeConfig()" ));
	IPoolsConfig public poolsConfig = IPoolsConfig(getContract(address(dao), "poolsConfig()" ));
	IStakingConfig public stakingConfig = IStakingConfig(getContract(address(dao), "stakingConfig()" ));
	IRewardsConfig public rewardsConfig = IRewardsConfig(getContract(address(dao), "rewardsConfig()" ));
	IDAOConfig public daoConfig = IDAOConfig(getContract(address(dao), "daoConfig()" ));

	address public teamWallet = exchangeConfig.teamWallet();

	IUpkeep public upkeep = exchangeConfig.upkeep();
	IEmissions public emissions = IEmissions(getContract(address(upkeep), "emissions()" ));

	ISalt public salt = exchangeConfig.salt();
    IERC20 public wbtc = exchangeConfig.wbtc();
    IERC20 public weth = exchangeConfig.weth();
    IERC20 public usdc = exchangeConfig.usdc();
    IERC20 public usdt = exchangeConfig.usdt();

	ISaltRewards public saltRewards = ISaltRewards(getContract(address(upkeep), "saltRewards()" ));
	IRewardsEmitter public stakingRewardsEmitter = IRewardsEmitter(getContract(address(saltRewards), "stakingRewardsEmitter()" ));
	IRewardsEmitter public liquidityRewardsEmitter = IRewardsEmitter(getContract(address(saltRewards), "liquidityRewardsEmitter()" ));

	IStaking public staking = IStaking(getContract(address(stakingRewardsEmitter), "stakingRewards()" ));
	ILiquidity public liquidity = ILiquidity(getContract(address(liquidityRewardsEmitter), "stakingRewards()" ));
	IPools public pools = IPools(getContract(address(liquidity), "pools()" ));

	IProposals public proposals = IProposals(getContract(address(dao), "proposals()" ));

	IAccessManager public accessManager = exchangeConfig.accessManager();

	VestingWallet public daoVestingWallet = VestingWallet(payable(exchangeConfig.daoVestingWallet()));
	VestingWallet public teamVestingWallet = VestingWallet(payable(exchangeConfig.teamVestingWallet()));

	IInitialDistribution public initialDistribution = exchangeConfig.initialDistribution();
	IBootstrapBallot public bootstrapBallot = IBootstrapBallot(getContract(address(initialDistribution), "bootstrapBallot()" ));
	IAirdrop public airdrop1 = IAirdrop(getContract(address(bootstrapBallot), "airdrop1()" ));
	IAirdrop public airdrop2 = IAirdrop(getContract(address(bootstrapBallot), "airdrop2()" ));

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
	bytes aliceVotingSignature = hex"b84ebb8dc4e7f727393bf355c9777630a2e1201dbdd72bb1c5d7fe87a6eaeae43a775465059058034b59c8d63e8d278a1978ab59b1514101b4049f6221f9e76d1b";
	bytes bobVotingSignature = hex"f9d61eebbd848bb12bbfd1b39da385f6a7e90d31ccd78647ac20e5ce68cb35ff3af380354e34c4f1897fa977e91024a74b91f1f8643cab704ce5be57f76737b61b";
	bytes charlieVotingSignature = hex"6b371ed02c1f3aa1b26d8d084a595e064515da24908ffd1dd31413ad05d41e0d23882f58d65e700c88da41d3c95f92049edf8b63bddbcef92398dd12970451a91b";

	uint256 startingBlock;
	uint256 rollCount;


	constructor()
		{
		if ( block.chainid == 11155111 )
			DEBUG = true;

		startingBlock = block.number;
		}


	// Overcomes an issue with Yul via-ir inlining block.number
	function rollToNextBlock() public
		{
		rollCount++;

		vm.roll(startingBlock + rollCount);
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


	function initializeContracts() public
		{
//		console.log( "DEFAULT: ", address(this) );

		vm.startPrank(DEPLOYER);
		usdc = new TestERC20("USDC", 6);
		weth = new TestERC20("WETH", 18);
		wbtc = new TestERC20("WBTC", 8);
		salt = new Salt();
		vm.stopPrank();

		vm.startPrank(DEPLOYER);

		daoConfig = new DAOConfig();
		poolsConfig = new PoolsConfig();
		rewardsConfig = new RewardsConfig();
		stakingConfig = new StakingConfig();
		exchangeConfig = new ExchangeConfig(salt, wbtc, weth, usdc, usdt, teamWallet );

		pools = new Pools(exchangeConfig, poolsConfig);
		staking = new Staking( exchangeConfig, poolsConfig, stakingConfig );
		liquidity = new Liquidity(pools, exchangeConfig, poolsConfig, stakingConfig);

		stakingRewardsEmitter = new RewardsEmitter( staking, exchangeConfig, poolsConfig, rewardsConfig, false );
		liquidityRewardsEmitter = new RewardsEmitter( liquidity, exchangeConfig, poolsConfig, rewardsConfig, true );

		saltRewards = new SaltRewards(stakingRewardsEmitter, liquidityRewardsEmitter, exchangeConfig, rewardsConfig);
		emissions = new Emissions( saltRewards, exchangeConfig, rewardsConfig );

		// Whitelist the pools
		poolsConfig.whitelistPool(salt, usdc);
		poolsConfig.whitelistPool(salt, weth);
		poolsConfig.whitelistPool(weth, usdc);
		poolsConfig.whitelistPool(weth, usdt);
		poolsConfig.whitelistPool(wbtc, usdc);
		poolsConfig.whitelistPool(wbtc, weth);
		poolsConfig.whitelistPool(usdc, usdt);

		proposals = new Proposals( staking, exchangeConfig, poolsConfig, daoConfig );

		dao = new DAO( pools, proposals, exchangeConfig, poolsConfig, stakingConfig, rewardsConfig, daoConfig, liquidityRewardsEmitter);

		airdrop1 = new Airdrop(exchangeConfig);
		airdrop2 = new Airdrop(exchangeConfig);

		accessManager = new AccessManager(dao);

		upkeep = new Upkeep(pools, exchangeConfig, poolsConfig, daoConfig, saltRewards, emissions, dao);


		bootstrapBallot = new BootstrapBallot(exchangeConfig, airdrop1, airdrop2, 60 * 60 * 24 * 3, 60 * 60 * 24 * 45 );

		// Vesting wallets start emitting at the same time that the bootstrapBallot ends
		daoVestingWallet = new VestingWallet( address(dao), uint64(bootstrapBallot.claimableTimestamp1()), 60 * 60 * 24 * 365 * 10 );
		teamVestingWallet = new VestingWallet( teamWallet, uint64(bootstrapBallot.claimableTimestamp1()), 60 * 60 * 24 * 365 * 10 );

		initialDistribution = new InitialDistribution(salt, poolsConfig, emissions, bootstrapBallot, dao, daoVestingWallet, teamVestingWallet, saltRewards);

		pools.setContracts(dao, liquidity);

		exchangeConfig.setContracts(dao, upkeep, initialDistribution, teamVestingWallet, daoVestingWallet );
		exchangeConfig.setAccessManager(accessManager);

		// Transfer ownership of the newly created config files to the DAO
		Ownable(address(exchangeConfig)).transferOwnership( address(dao) );
		Ownable(address(poolsConfig)).transferOwnership( address(dao) );
		Ownable(address(daoConfig)).transferOwnership( address(dao) );
		Ownable(address(rewardsConfig)).transferOwnership( address(dao) );
		Ownable(address(stakingConfig)).transferOwnership( address(dao) );
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
		vm.startPrank( address(bootstrapBallot) );
		airdrop1.authorizeWallet(address(0x1111), 1000 ether);
		airdrop2.authorizeWallet(address(0x1111), 1000 ether);
		vm.stopPrank();
		}


	function whitelistBob() public
		{
		vm.startPrank( address(bootstrapBallot) );
		airdrop1.authorizeWallet(address(0x2222), 1000 ether);
		airdrop2.authorizeWallet(address(0x2222), 1000 ether);
		vm.stopPrank();
		}


	function whitelistCharlie() public
		{
		vm.startPrank( address(bootstrapBallot) );
		airdrop1.authorizeWallet(address(0x3333), 1000 ether);
		airdrop2.authorizeWallet(address(0x3333), 1000 ether);
		vm.stopPrank();
		}


	function whitelistTeam() public
		{
		vm.startPrank( address(bootstrapBallot) );
		airdrop1.authorizeWallet(address(0x123456789), 1000 ether);
		airdrop2.authorizeWallet(address(0x123456789), 1000 ether);
		vm.stopPrank();
		}


	function finalizeBootstrap() public
		{
		address alice = address(0x1111);
		address bob = address(0x2222);

//		whitelistAlice();
//		whitelistBob();

		bytes memory sig = abi.encodePacked(aliceVotingSignature);
		vm.startPrank(alice);
		bootstrapBallot.vote(true, 1000 ether, sig);
		vm.stopPrank();

		sig = abi.encodePacked(bobVotingSignature);
		vm.startPrank(bob);
		bootstrapBallot.vote(true, 1000 ether, sig);
		vm.stopPrank();

		// Increase current blocktime to be greater than completionTimestamp
		vm.warp( bootstrapBallot.claimableTimestamp1() + 1);

		// Call finalizeBallot()
		bootstrapBallot.finalizeBallot();
		}
	}