// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "../../dev/Deployment.sol";
import "../../pools/PoolUtils.sol";
import "../ArbitrageSearch.sol";
import "../../rewards/SaltRewards.sol";
import "../../dev/Deployment.sol";
import "../../root_tests/TestERC20.sol";
import "../../stable/CollateralAndLiquidity.sol";
import "../../ExchangeConfig.sol";
import "../../pools/Pools.sol";
import "../../staking/Staking.sol";
import "../../rewards/RewardsEmitter.sol";
import "../../price_feed/tests/IForcedPriceFeed.sol";
import "../../price_feed/tests/ForcedPriceFeed.sol";
import "../../pools/PoolsConfig.sol";
import "../../price_feed/PriceAggregator.sol";
import "../../dao/Proposals.sol";
import "../../dao/DAO.sol";
import "../../AccessManager.sol";
import "./TestArbitrageSearch.sol";


contract TestArbitrageSearch2 is Deployment
	{
	address public alice = address(0x1111);

	TestArbitrageSearch public testArbitrageSearch = new TestArbitrageSearch( exchangeConfig);


	constructor()
		{
		// If $COVERAGE=yes, create an instance of the contract so that coverage testing can work
		// Otherwise, what is tested is the actual deployed contract on the blockchain (as specified in Deployment.sol)
		if ( keccak256(bytes(vm.envString("COVERAGE" ))) == keccak256(bytes("yes" )))
			{
			vm.startPrank(DEPLOYER);

			poolsConfig = new PoolsConfig();
			usds = new USDS();

			exchangeConfig = new ExchangeConfig(salt, wbtc, weth, dai, usds, managedTeamWallet );

			priceAggregator = new PriceAggregator();
			priceAggregator.setInitialFeeds( IPriceFeed(address(forcedPriceFeed)), IPriceFeed(address(forcedPriceFeed)), IPriceFeed(address(forcedPriceFeed)) );

		liquidizer = new Liquidizer(exchangeConfig, poolsConfig);
		pools = new Pools(exchangeConfig, poolsConfig);
		staking = new Staking( exchangeConfig, poolsConfig, stakingConfig );
		collateralAndLiquidity = new CollateralAndLiquidity(pools, exchangeConfig, poolsConfig, stakingConfig, stableConfig, priceAggregator, liquidizer);
		liquidizer.setContracts(collateralAndLiquidity, pools, dao);

			stakingRewardsEmitter = new RewardsEmitter( staking, exchangeConfig, poolsConfig, rewardsConfig, false );
			liquidityRewardsEmitter = new RewardsEmitter( collateralAndLiquidity, exchangeConfig, poolsConfig, rewardsConfig, true );

			emissions = new Emissions( saltRewards, exchangeConfig, rewardsConfig );

			poolsConfig.whitelistPool( pools,   salt, wbtc);
			poolsConfig.whitelistPool( pools,   salt, weth);
			poolsConfig.whitelistPool( pools,   salt, usds);
			poolsConfig.whitelistPool( pools,   wbtc, usds);
			poolsConfig.whitelistPool( pools,   weth, usds);
			poolsConfig.whitelistPool( pools,   wbtc, dai);
			poolsConfig.whitelistPool( pools,   weth, dai);
			poolsConfig.whitelistPool( pools,   usds, dai);
			poolsConfig.whitelistPool( pools,   wbtc, weth);


			proposals = new Proposals( staking, exchangeConfig, poolsConfig, daoConfig );

			address oldDAO = address(dao);
			dao = new DAO( pools, proposals, exchangeConfig, poolsConfig, stakingConfig, rewardsConfig, stableConfig, daoConfig, priceAggregator, liquidityRewardsEmitter, collateralAndLiquidity);

			accessManager = new AccessManager(dao);

			exchangeConfig.setContracts(dao, upkeep, initialDistribution, airdrop, teamVestingWallet, daoVestingWallet );
			exchangeConfig.setAccessManager(accessManager);

			testArbitrageSearch = new TestArbitrageSearch( exchangeConfig);

			pools.setContracts(dao, collateralAndLiquidity);

			usds.setCollateralAndLiquidity(collateralAndLiquidity);

			// Transfer ownership of the newly created config files to the DAO
			Ownable(address(exchangeConfig)).transferOwnership( address(dao) );
			Ownable(address(poolsConfig)).transferOwnership( address(dao) );
			Ownable(address(priceAggregator)).transferOwnership(address(dao));
			vm.stopPrank();

			vm.startPrank(address(oldDAO));
			Ownable(address(stakingConfig)).transferOwnership( address(dao) );
			Ownable(address(rewardsConfig)).transferOwnership( address(dao) );
			Ownable(address(stableConfig)).transferOwnership( address(dao) );
			Ownable(address(daoConfig)).transferOwnership( address(dao) );
			vm.stopPrank();
			}

		vm.prank(address(initialDistribution));
		salt.transfer(DEPLOYER, 100000000 ether);
		}


	// A unit test that validates that binarySearch returns zero when pool reserves are at or below the threshold of PoolUtils.DUST.
	function testBinarySearchReturnsZeroWhenReservesBelowDUST() public {
        uint256 swapAmountInValueInETH = 1 ether; // Just an arbitrary value

        // Case where all reserves are below or at DUST
        uint256 reservesA0 = PoolUtils.DUST;
        uint256 reservesA1 = PoolUtils.DUST;
        uint256 reservesB0 = PoolUtils.DUST;
        uint256 reservesB1 = PoolUtils.DUST;
        uint256 reservesC0 = PoolUtils.DUST;
        uint256 reservesC1 = PoolUtils.DUST;

        uint256 bestArbAmountIn = testArbitrageSearch.bisectionSearch(swapAmountInValueInETH, reservesA0, reservesA1, reservesB0, reservesB1, reservesC0, reservesC1);
        assertEq(bestArbAmountIn, 0);

        // Case where some reserves are above DUST
        reservesA0 = PoolUtils.DUST + 1;
        reservesA1 = PoolUtils.DUST + 1;
        reservesB0 = PoolUtils.DUST + 1;
        reservesC1 = PoolUtils.DUST + 1;

        bestArbAmountIn = testArbitrageSearch.bisectionSearch(swapAmountInValueInETH, reservesA0, reservesA1, reservesB0, reservesB1, reservesC0, reservesC1);
        assertEq(bestArbAmountIn, 0);
    }


	// A unit test that simulates failed or reverted transactions within the arbitrage paths.
	function testFailArbitragePaths() public {
        uint256 swapAmountInValueInETH = 5 ether;  // Arbitrary value for test
        uint256 reservesA0 = 1000 ether; // Also arbitrary
        uint256 reservesA1 = 2000 ether;
        uint256 reservesB0 = 1500 ether;
        uint256 reservesB1 = 3000 ether;
        uint256 reservesC0 = 2500 ether;
        uint256 reservesC1 = 5000 ether;

        // Simulating other reverts
        reservesA0 = 0;
        vm.expectRevert("reservesA0 or reservesA1 should be more than DUST");
        testArbitrageSearch.bisectionSearch(swapAmountInValueInETH, reservesA0, reservesA1, reservesB0, reservesB1, reservesC0, reservesC1);
    }


	// A unit test that verifies the `_arbitragePath` returns the correct token pair for a given swap input and output token scenario.
	function testArbitragePathReturnsCorrectTokenPair() public {
        // Token addresses for test (mock or real addresses could be used)
        address swapTokenInAddress = address(uint160(uint256(keccak256("tokenIn"))));
        IERC20 swapTokenIn = IERC20(swapTokenInAddress);
        address swapTokenOutAddress = address(uint160(uint256(keccak256("tokenOut"))));
        IERC20 swapTokenOut = IERC20(swapTokenOutAddress);

        // WETH->WBTC scenario
        vm.prank(alice);
        IERC20 arbToken2;
        IERC20 arbToken3;
        (arbToken2, arbToken3) = testArbitrageSearch.arbitragePath(weth, wbtc);
        assertEq(address(arbToken2), address(salt));
        assertEq(address(arbToken3), address(wbtc));

        // WBTC->WETH scenario
        vm.prank(alice);
        (arbToken2, arbToken3) = testArbitrageSearch.arbitragePath(wbtc, weth);
        assertEq(address(arbToken2), address(wbtc));
        assertEq(address(arbToken3), address(salt));

        // WETH->swapTokenOut scenario
        vm.prank(alice);
        (arbToken2, arbToken3) = testArbitrageSearch.arbitragePath(weth, swapTokenOut);
        assertEq(address(arbToken2), address(wbtc));
        assertEq(address(arbToken3), address(swapTokenOut));

        // swapTokenIn->WETH scenario
        vm.prank(alice);
        (arbToken2, arbToken3) = testArbitrageSearch.arbitragePath(swapTokenIn, weth);
        assertEq(address(arbToken2), address(swapTokenIn));
        assertEq(address(arbToken3), address(wbtc));

        // swapTokenIn->swapTokenOut scenario
        vm.prank(alice);
        (arbToken2, arbToken3) = testArbitrageSearch.arbitragePath(swapTokenIn, swapTokenOut);
        assertEq(address(arbToken2), address(swapTokenOut));
        assertEq(address(arbToken3), address(swapTokenIn));
    }
	}


