//// SPDX-License-Identifier: BSL 1.1
//pragma solidity ^0.8.12;
//
//import "forge-std/Test.sol";
//import "../../uniswap/core/interfaces/IUniswapV2Factory.sol";
//import "../../interfaces/IAAA.sol";
//import "../../Salt.sol";
//import "../../stable/USDS.sol";
//import "../../stable/tests/IForcedPriceFeed.sol";
//import "../../stable/StableConfig.sol";
//import "../../staking/interfaces/IStakingConfig.sol";
//import "../../staking/StakingConfig.sol";
//import "../../interfaces/IPOL_Optimizer.sol";
//import "../../ExchangeConfig.sol";
//import "../../interfaces/IExchangeConfig.sol";
//import "../Collateral.sol";
//import "../Liquidator.sol";
//import "../../interfaces/IAccessManager.sol";
//import "../../tests/TestAccessManager.sol";
//
//contract TestLiquidator is Test, Liquidator
//	{
//	// Deployed resources
//	IUniswapV2Router02 public constant _saltyRouter = IUniswapV2Router02(address(0xcCAA839192E6087F51B95Bf593498C72113D9f65));
//	IUniswapV2Factory public _factory = IUniswapV2Factory(_saltyRouter.factory());
//	IExchangeConfig public _exchangeConfig = _factory.exchangeConfig();
//    IERC20 public _wbtc = IERC20(_exchangeConfig.wbtc());
//    IERC20 public _weth = IERC20(_exchangeConfig.weth());
//    IERC20 public _usdc = IERC20(_exchangeConfig.usdc());
//    USDS public _usds = USDS(_exchangeConfig.usds());
//
//	address constant public DEV_WALLET = 0x73107dA86708c2DAd0D91388fB057EeE3E2581aF;
//
//	IForcedPriceFeed public _forcedPriceFeed = IForcedPriceFeed(address(0xDEE776893503EFB20e6fC7173E9c03911F28233E));
//
//    IUniswapV2Pair public _collateralLP = IUniswapV2Pair( _factory.getPair( address(_wbtc), address(_weth) ));
//
//	IStableConfig public _stableConfig = IStableConfig(address(new StableConfig(IPriceFeed(address(_forcedPriceFeed))) ) );
//	IStakingConfig public _stakingConfig = IStakingConfig(address(new StakingConfig(IERC20(address(new Salt())))));
//
//	IAccessManager public accessManager = IAccessManager(new TestAccessManager());
//
//	Collateral public _collateral = new Collateral( _collateralLP, _usds, _stableConfig, _stakingConfig, _exchangeConfig );
//	IPOL_Optimizer public constant polOptimizer = IPOL_Optimizer(address(0x8888));
//    IAAA public constant aaa = IAAA(address(0xc5753E05803832413084aE2dd1565878250A185A));
//
//	// User wallets for testing
//    address public constant alice = address(0x1111);
//    address public constant bob = address(0x2222);
//    address public constant charlie = address(0x3333);
//
//
//	constructor()
//		Liquidator( _collateralLP, _saltyRouter, _collateral, _stableConfig, _exchangeConfig )
//		{
//		vm.startPrank( DEV_WALLET );
//		_exchangeConfig.setOptimizer( polOptimizer );
//		_exchangeConfig.setLiquidator( this );
//		_exchangeConfig.setAccessManager(accessManager);
//
//		// setCollateral can only be called on USDS one time
//		// call it with this address as the Collateral so that usds.mintTo() can be called
//		_usds.setCollateral( _collateral );
//		vm.stopPrank();
//
//		// Mint some USDS to the DEV_WALLET from Collateral
//		vm.prank( address(_collateral) );
//		_usds.mintTo( DEV_WALLET, 10000000000 ether );
//		}
//
//
//    function setUp() public
//    	{
//		assertEq( address(collateralLP), address(0x8a47e16a804E6d7531e0a8f6031f9Fee12EaeE57), "Unexpected collateralLP" );
//
//    	// The fake tokens are held by DEV_WALLET
//		vm.startPrank( DEV_WALLET );
//
//		// Dev Approvals
//		wbtc.approve( address(_saltyRouter), type(uint256).max );
//        weth.approve( address(_saltyRouter), type(uint256).max );
//		usds.approve( address(_saltyRouter), type(uint256).max );
//
////		console.log( "WBTC DECIMALS: ", this.wbtcDecimals() );
////		console.log( "WETH DECIMALS: ", this.wethDecimals() );
////		console.log( "WBTC BALANCE: ", _wbtc.balanceOf(address(DEV_WALLET)) / 10 ** 8 );
////		console.log( "WETH BALANCE: ", _weth.balanceOf(address(DEV_WALLET)) / 10 ** 18 );
//
//		// Have DEV_WALLET create some BTC/ETH LP collateral on Salty.IO
//		(,,uint256 initialCollateral) = _saltyRouter.addLiquidity( address(wbtc), address(weth), 100 * 10 ** 8, 100 ether * stableConfig.priceFeed().getPriceBTC() / stableConfig.priceFeed().getPriceETH(), 0, 0, DEV_WALLET, block.timestamp );
//		_saltyRouter.addLiquidity( address(wbtc), address(usds), 100 * 10 ** wbtcDecimals, 100 * stableConfig.priceFeed().getPriceBTC(), 0, 0, DEV_WALLET, block.timestamp );
//		_saltyRouter.addLiquidity( address(weth), address(usds), 10000 ether, 10000 * stableConfig.priceFeed().getPriceETH(), 0, 0, DEV_WALLET, block.timestamp );
//
//
//    	// Transfer some collateral to alice, bob and charlie for later testing
//    	// DEV_WALLET will maintain 1/4 of the initialCollateral as well
//		collateralLP.transfer( alice, initialCollateral / 100 );
//		collateralLP.transfer( bob, initialCollateral / 100 );
//		collateralLP.transfer( charlie, initialCollateral / 100 );
//
//		// Have DEV_WALLET create some initial USDS/USDC liquidity on Salty.IO
//		vm.stopPrank();
//
//		// More approvals
//		vm.startPrank( alice );
//		collateralLP.approve( address(this), type(uint256).max );
//		vm.stopPrank();
//
//		vm.startPrank( bob );
//		collateralLP.approve( address(this), type(uint256).max );
//		vm.stopPrank();
//
//		vm.startPrank( charlie );
//		collateralLP.approve( address(this), type(uint256).max );
//		vm.stopPrank();
//    	}
//
//
//
//
//	// A unit test that checks the correct behavior of the liquidate function when it is called by a single user.
//	function testLiquidate() public {
//
//	// Make sure alice starts with zero USDS
//	assertEq(usds.balanceOf(alice), 0);
//
//    // Transfer collateralLP tokens to this contract for liquidation
//    vm.startPrank(alice);
//    uint256 amountToLiquidate = collateralLP.balanceOf(alice) / 4;
//    collateralLP.transfer(address(this), amountToLiquidate);
//    vm.stopPrank();
//
//	uint256 collateralValue = _collateral.collateralValue( amountToLiquidate );
//
//	// Assume the collateral / usds ratio is at 109% (and available for liquidation)
//	uint256 expectedBurnedUSDS = collateralValue * 100 / 109;
////	console.log( "amountToLiquidate: ", amountToLiquidate / 10 ** 18 );
//
//	vm.prank( address(collateral) );
//	this.increaseUSDSToBurn( expectedBurnedUSDS );
//
//    // Call the liquidate function
//    uint256 startingSupplyUSDS = usds.totalSupply();
//    uint256 startingSupplyCollateral = collateralLP.totalSupply();
//
//	assertTrue( weth.balanceOf( address(_exchangeConfig.optimizer())) == 0, "Starting balance of optimizer should be zero" );
//	this.performUpkeep();
//
//	// Slippage
//	uint256 collateralBurned = startingSupplyCollateral - collateralLP.totalSupply();
//	uint256 usdsBurned = startingSupplyUSDS - usds.totalSupply();
//
//	assertEq( amountToLiquidate, collateralBurned, "Unexpected amount of collateral burned" );
//
//	uint256 expectedBurnedUSDSWithSlippage = expectedBurnedUSDS * 98 / 100;
////	console.log( "expectedBurnedUSDSWithSlippage: ", expectedBurnedUSDSWithSlippage / 10 ** 18 );
//
////	console.log( "usdsBurned: ", usdsBurned / 10 ** 18 );
//	assertTrue( usdsBurned >= expectedBurnedUSDSWithSlippage, "Insufficient USDS burned on liquidation" );
//
//	// Make sure extra WETH has been sent to the optimizer
//	uint256 extraUSDS = collateralValue - usdsBurned;
//
//	// Include slippage
//	uint256 expectedOptimizerETH = extraUSDS * 1 ether / stableConfig.priceFeed().getPriceETH();
//	expectedOptimizerETH = expectedOptimizerETH * 98 / 100;
//
//	uint256 optimizerBalanceETH = weth.balanceOf( address(polOptimizer));
////	console.log( "optimizerBalanceETH: ", optimizerBalanceETH );
////	console.log( "expectedOptimizerETH: ", expectedOptimizerETH );
//
//	assertTrue( optimizerBalanceETH > expectedOptimizerETH, "Unexpected amount of WETH sent to Optimizer on liquidation" );
//	}
//
//
//	// A unit test that checks the correct behavior of the liquidate function when it is called by a single user.
//	function testLiquidateUnderwater() public {
//
//	// Make sure alice starts with zero USDS
//	assertEq(usds.balanceOf(alice), 0);
//
//    // Transfer collateralLP tokens to this contract for liquidation
//    vm.startPrank(alice);
//    uint256 amountToLiquidate = collateralLP.balanceOf(alice) / 4;
//    collateralLP.transfer(address(this), amountToLiquidate);
//    vm.stopPrank();
//
//	uint256 collateralValue = _collateral.collateralValue( amountToLiquidate );
//
//	// Assume the collateral / usds ratio is at 98% (and available for liquidation)
//	uint256 expectedBurnedUSDS = collateralValue * 100 / 98;
//
//	vm.prank( address(collateral) );
//	this.increaseUSDSToBurn( expectedBurnedUSDS );
//
//    // Call the liquidate function
//    uint256 startingSupplyUSDS = usds.totalSupply();
//    uint256 startingSupplyCollateral = collateralLP.totalSupply();
//
//	assertTrue( weth.balanceOf( address(_exchangeConfig.optimizer())) == 0, "Starting balance of optimizer should be zero" );
//	this.performUpkeep();
//
//	// Slippage
//	uint256 collateralBurned = startingSupplyCollateral - collateralLP.totalSupply();
//	uint256 usdsBurned = startingSupplyUSDS - usds.totalSupply();
//
//	assertEq( amountToLiquidate, collateralBurned, "Unexpected amount of collateral burned" );
//
//	uint256 expectedBurnedUSDSWithSlippage = expectedBurnedUSDS * 95 / 100;
////	console.log( "expectedBurnedUSDSWithSlippage: ", expectedBurnedUSDSWithSlippage / 10 ** 18 );
//
////	console.log( "usdsBurned: ", usdsBurned / 10 ** 18 );
//	assertTrue( usdsBurned >= expectedBurnedUSDSWithSlippage, "Insufficient USDS burned on liquidation" );
//
//	// Make sure extra WETH has been sent to the optimizer
//	uint256 optimizerBalanceETH = weth.balanceOf( address(polOptimizer));
//
//	assertEq( optimizerBalanceETH, 0,  "No ETH should be sent to optimizer on underwater liquidation" );
//	}
//
//
//	// Can be used to test liquidation by reducing BTC and ETH price.
//	// Original collateral ratio is 200% with a minimum collateral ratio of 110%.
//	// So dropping the prices by 46% should allow positions to be liquidated and still
//	// ensure that the collateral is above water and able to be liquidated successfully.
//	function _crashCollateralPrice() internal
//		{
//		vm.startPrank( DEV_WALLET );
//
//		address[] memory path3 = new address[](2);
//		path3[0] = address(wbtc);
//		path3[1] = address(usds);
//
//		saltyRouter.swapExactTokensForTokens( 100 * 10 ** wbtcDecimals, 0, path3, DEV_WALLET, block.timestamp);
//
//		vm.stopPrank();
//		}
//
//
//	// A unit test that checks the correct behavior of the liquidate function when it is called by a single user.
//	function testLiquidateInCrash() public {
//
//	// Make sure alice starts with zero USDS
//	assertEq(usds.balanceOf(alice), 0);
//
//    // Transfer collateralLP tokens to this contract for liquidation
//    vm.startPrank(alice);
//    uint256 amountToLiquidate = collateralLP.balanceOf(alice) / 4;
//    collateralLP.transfer(address(this), amountToLiquidate);
//    vm.stopPrank();
//
//	// Colalteral value in normal conditions
//	uint256 collateralValue = _collateral.collateralValue( amountToLiquidate );
//
//	// Assume the collateral / usds ratio is at 109% (and available for liquidation)
//	uint256 expectedBurnedUSDS = collateralValue * 100 / 109;
//
//
//	_crashCollateralPrice();
////	console.log( "amountToLiquidate: ", amountToLiquidate / 10 ** 18 );
//
//	vm.prank( address(collateral) );
//	this.increaseUSDSToBurn( expectedBurnedUSDS );
//
//    // Call the liquidate function
//    uint256 startingSupplyUSDS = usds.totalSupply();
//    uint256 startingSupplyCollateral = collateralLP.totalSupply();
//
//	assertTrue( weth.balanceOf( address(_exchangeConfig.optimizer())) == 0, "Starting balance of optimizer should be zero" );
//	this.performUpkeep();
//
//	// Slippage
//	uint256 collateralBurned = startingSupplyCollateral - collateralLP.totalSupply();
//	uint256 usdsBurned = startingSupplyUSDS - usds.totalSupply();
//
//	assertEq( amountToLiquidate, collateralBurned, "Unexpected amount of collateral burned" );
//
//	uint256 expectedBurnedUSDSWithSlippage = expectedBurnedUSDS * 98 / 100;
//
//	console.log( "expectedBurnedUSDSWithSlippage: ", expectedBurnedUSDSWithSlippage / 10 ** 18 );
//	console.log( "usdsBurned: ", usdsBurned / 10 ** 18 );
//
//	assertFalse( usdsBurned >= expectedBurnedUSDSWithSlippage, "Expecting insufficient USDS burned on liquidation" );
//	}
//
//
//	// A stress test that sends many requests to the liquidate function in a short period. This will test the contract's robustness and ability to handle high traffic.
//	function testLiquidate_stress() public {
//        uint256 numIterations = 100;
//        uint256 collateralLPBalance = collateralLP.balanceOf(alice);
//
//        // send collateralLP to liquidator contract from alice, bob and charlie
//        vm.startPrank(alice);
//
//        for(uint256 i = 0; i < numIterations; i++) {
//	        collateralLP.transfer(address(this), collateralLPBalance / numIterations);
////            this.liquidate(1);
//        }
//    }
//
//	// A unit test that checks the correct gas estimation for each function call. This test will help ensure that the contract doesn't require an unusually high amount of gas to execute its functions.
//	function testGasEstimations() public
//    {
//        // Set initial gas tracker
//        uint256 startGas = gasleft();
//
//        // Call increaseUserShare function and measure gas
//        vm.startPrank( alice );
//        collateralLP.transfer(address(this), collateralLP.balanceOf( alice ));
////        this.liquidate(minimumUSDS);
//
//        uint256 gasUsed = startGas - gasleft();
////        console.log( "GAS USED: ", gasUsed );
//
//        // Verify gas used is within acceptable bounds
//        assertTrue(gasUsed <= 750000, "Gas used by liquidate is too high");
//    }
//
//
//
//	// A unit test verifying that the constructor correctly initializes all contract variables. Test that all variables are initialized with the expected values.
//	function testConstructor() public {
//        // Verify that constructor correctly initializes all contract variables
//        assertEq(address(this.wbtc()), address(_wbtc));
//        assertEq(address(this.weth()), address(_weth));
//        assertEq(address(this.usds()), address(_usds));
//        assertEq(address(this.collateralLP()), address(_collateralLP));
//        assertEq(address(this.saltyRouter()), address(_saltyRouter));
//
//        // Check that initial contract balances are as expected
//        assertEq(this.wbtc().balanceOf(address(this)), 0 ether);
//        assertEq(this.weth().balanceOf(address(this)), 0 ether);
//        assertEq(this.usds().balanceOf(address(this)), 0 ether);
//        assertEq(this.collateralLP().balanceOf(address(this)), 0 ether);
//
//        // Check that the correct approvals have been given
//        assertEq(this.wbtc().allowance(address(this), address(_saltyRouter)), type(uint256).max);
//        assertEq(this.weth().allowance(address(this), address(_saltyRouter)), type(uint256).max);
//        assertEq(this.usds().allowance(address(this), address(_saltyRouter)), type(uint256).max);
//    }
//
//
//	// A unit test that ensures the liquidate function reverts when there are no collateralLP tokens available for liquidation. The balance of collateralLP tokens should be checked before the call to ensure it's zero.
//	function testLiquidateRevertNoCollateral() public {
//        vm.startPrank(bob);
//
//        assertEq(_collateralLP.balanceOf(address(this)), 0);
//        this.performUpkeep();
//       assertEq(_collateralLP.balanceOf(address(this)), 0);
//
//        vm.stopPrank();
//    }
//	}
//
