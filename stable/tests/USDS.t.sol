// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "forge-std/Test.sol";
import "../../root_tests/TestERC20.sol";
import "../../dev/Deployment.sol";
import "../../pools/PoolUtils.sol";
import "../../pools/Pools.sol";
import "../../arbitrage/ArbitrageSearch.sol";
import "../../pools/Counterswap.sol";
import "../../rewards/SaltRewards.sol";
import "../../stable/Collateral.sol";
import "../../ExchangeConfig.sol";
import "../../staking/Staking.sol";
import "../../rewards/RewardsEmitter.sol";
import "../../price_feed/tests/IForcedPriceFeed.sol";
import "../../price_feed/tests/ForcedPriceFeed.sol";
import "../../pools/PoolsConfig.sol";
import "../../price_feed/PriceAggregator.sol";
import "../../dao/Proposals.sol";
import "../../dao/DAO.sol";
import "../../AccessManager.sol";


contract USDSTest is Test, Deployment
	{
	constructor()
		{
		// If $COVERAGE=yes, create an instance of the contract so that coverage testing can work
		// Otherwise, what is tested is the actual deployed contract on the blockchain (as specified in Deployment.sol)
		if ( keccak256(bytes(vm.envString("COVERAGE" ))) == keccak256(bytes("yes" )))
			{
			vm.startPrank(DEPLOYER);

			poolsConfig = new PoolsConfig();
			usds = new USDS(wbtc, weth);

			exchangeConfig = new ExchangeConfig(salt, wbtc, weth, dai, usds, teamWallet );

			priceAggregator = new PriceAggregator();
			priceAggregator.setInitialFeeds( IPriceFeed(address(forcedPriceFeed)), IPriceFeed(address(forcedPriceFeed)), IPriceFeed(address(forcedPriceFeed)) );

			pools = new Pools(exchangeConfig, poolsConfig);
			staking = new Staking( exchangeConfig, poolsConfig, stakingConfig );
			liquidity = new Liquidity( pools, exchangeConfig, poolsConfig, stakingConfig );
			collateral = new Collateral(pools, exchangeConfig, poolsConfig, stakingConfig, stableConfig, priceAggregator);

			stakingRewardsEmitter = new RewardsEmitter( staking, exchangeConfig, poolsConfig, rewardsConfig );
			liquidityRewardsEmitter = new RewardsEmitter( liquidity, exchangeConfig, poolsConfig, rewardsConfig );

			emissions = new Emissions( saltRewards, exchangeConfig, rewardsConfig );

			poolsConfig.whitelistPool(pools, salt, wbtc);
			poolsConfig.whitelistPool(pools, salt, weth);
			poolsConfig.whitelistPool(pools, salt, usds);
			poolsConfig.whitelistPool(pools, wbtc, usds);
			poolsConfig.whitelistPool(pools, weth, usds);
			poolsConfig.whitelistPool(pools, wbtc, dai);
			poolsConfig.whitelistPool(pools, weth, dai);
			poolsConfig.whitelistPool(pools, usds, dai);
			poolsConfig.whitelistPool(pools, wbtc, weth);


			proposals = new Proposals( staking, exchangeConfig, poolsConfig, daoConfig );

			address oldDAO = address(dao);
			dao = new DAO( pools, proposals, exchangeConfig, poolsConfig, stakingConfig, rewardsConfig, stableConfig, daoConfig, priceAggregator, liquidityRewardsEmitter);

			accessManager = new AccessManager(dao);

			exchangeConfig.setAccessManager( accessManager );
			exchangeConfig.setStakingRewardsEmitter( stakingRewardsEmitter);
			exchangeConfig.setLiquidityRewardsEmitter( liquidityRewardsEmitter);
			exchangeConfig.setDAO( dao );

			pools.setDAO(dao);

			usds.setContracts(collateral, pools, exchangeConfig);

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

		priceAggregator.performUpkeep();
		}


	// // A unit test in which the collateral address is set for the first time. This test should validate that the collateral address is correctly updated and can only be set once.
	function testSetContractsOnlyOnce() public
		{
		address _collateral = address(0x5555);
		address _pools = address(0x6666);
		address _exchangeConfig = address(0x7777);

		// New USDS in case Collateral was set in the deployed version already
		usds = new USDS(wbtc, weth);

		// Initial set up
		assertEq(address(usds.collateral()), address(0));
		assertEq(address(usds.pools()), address(0));
		assertEq(address(usds.exchangeConfig()), address(0));

		usds.setContracts( ICollateral(_collateral), IPools(_pools), IExchangeConfig(_exchangeConfig) );

		assertEq(address(usds.collateral()), address(_collateral));
		assertEq(address(usds.pools()), address(_pools));
		assertEq(address(usds.exchangeConfig()), address(_exchangeConfig));

		address invalid = address(0xdead);

		vm.expectRevert("setContracts can only be called once");
		usds.setContracts( ICollateral(invalid), IPools(invalid), IExchangeConfig(invalid) );

		// Validate that the addresses did not change
		assertEq(address(usds.collateral()), address(_collateral));
		assertEq(address(usds.pools()), address(_pools));
		assertEq(address(usds.exchangeConfig()), address(_exchangeConfig));
	}


	// A unit test where a different address attempts to call the mintTo function. This test should validate that only the collateral address is allowed to mint tokens.
	function testOnlyCollateralCanMint() public {
        address otherAddress = address(0x6666);
        address wallet = address(0x7777);
        uint256 mintAmount = 1 ether;

        // Try minting from the collateral address
        vm.prank(address(collateral));
        usds.mintTo(wallet, mintAmount);
        assertEq(usds.balanceOf(wallet), mintAmount);

        // Try minting from a different address
        vm.expectRevert("Can only call USDS.mintTo from the Collateral contract");
        vm.prank(otherAddress);
        usds.mintTo(wallet, mintAmount);

        // Validate that the balance did not increase
        assertEq(usds.balanceOf(wallet), mintAmount);
    }


	// A unit test where an attempt is made to burn more USD than is available in the contract.
	function testBurnMoreThanAvailable() public {
        uint256 usdsToBurn = 2 ether; // Amount greater than current balance

        assertEq(usds.usdsThatShouldBeBurned(), 0 ether);

        // Try burning more than available
        vm.prank(address(collateral));
        usds.shouldBurnMoreUSDS(usdsToBurn);

        // Validate that the amount that should be burnt is set correctly
        assertEq(usds.usdsThatShouldBeBurned(), usdsToBurn);
}


   // A unit test where a different address attempts to call the shouldBurnMoreUSDS function. This test should validate that only the collateral address is allowed to signal the contract to burn tokens.
   function testOnlyCollateralCanSignalBurn2() public {
		   address otherAddress = address(0x6666);
		   uint256 amountToBurn = 1 ether;

		   vm.prank(address(collateral));
		   usds.shouldBurnMoreUSDS(amountToBurn);
		   assertEq(usds.usdsThatShouldBeBurned(), amountToBurn);

		   // Try signalling burn from a non-collateral address
		   vm.expectRevert("Can only call USDS.shouldBurnMoreUSDS from the Collateral contract");
		   vm.prank(otherAddress);
		   usds.shouldBurnMoreUSDS(amountToBurn);
   }


	// A unit test where a different address attempts to call the mintTo function. This test should validate that only the collateral address is allowed to mint tokens.
	function testOnlyCollateralCanMint2() public {
        address otherAddress = address(0x6666);
        address wallet = address(0x7777);
        uint256 mintAmount = 1 ether;

        // Set up a new instance of USDS and set collateral
        // Mint from the collateral address
        vm.prank(address(collateral));
        usds.mintTo(wallet, mintAmount);
        assertEq(usds.balanceOf(wallet), mintAmount);

        // Attempt to mint from a different address
        vm.expectRevert("Can only call USDS.mintTo from the Collateral contract");
        vm.prank(otherAddress);
        usds.mintTo(wallet, mintAmount);

        // Validate that the balance did not increase
        assertEq(usds.balanceOf(wallet), mintAmount);
    }


	// A unit test where a different address attempts to call the shouldBurnMoreUSDS function. This test should validate that only the collateral address is allowed to signal the contract to burn tokens.
	function testOnlyCollateralCanSignalBurn() public {
        address otherAddress = address(0x6666);
        uint256 burnAmount = 1 ether;

        // Set up a new instance of USDS and set collateral
        // Signal burn from the collateral address
        vm.prank(address(collateral));
        usds.shouldBurnMoreUSDS(burnAmount);
        assertEq(usds.usdsThatShouldBeBurned(), burnAmount);

        // Attempt to signal burn from a different address
        vm.expectRevert("Can only call USDS.shouldBurnMoreUSDS from the Collateral contract");
        vm.prank(otherAddress);
        usds.shouldBurnMoreUSDS(burnAmount);
    }


	// A unit test where a call is made to mintTo function without calling the setCollateral function first. This test will validate that before the mint operation can be made, the Collateral contract has to be set.
    function testMintWithoutSettingCollateral() public {
        address wallet = address(0x7777);
        uint256 mintAmount = 1 ether;

        // Try minting without setting the collateral address first
        vm.expectRevert("Can only call USDS.mintTo from the Collateral contract");
        usds.mintTo(wallet, mintAmount);

        // Validate that the balance did not increase
        assertEq(usds.balanceOf(wallet), 0);
    }


	// A unit test where a call is made to shouldBurnMoreUSDS function without calling the setCollateral function first. This test will validate that before the burn operation can be made, the Collateral contract has to be set.
    function testShouldBurnMoreUSDSWithoutCollateralSet() public {
        uint256 usdsToBurn = 1 ether;

        // New USDS instance in case Collateral was set in the deployed version already
    	USDS newUSDS = new USDS(wbtc, weth);

        // Expect revert as the Collateral contract is not set yet
        vm.expectRevert("Can only call USDS.shouldBurnMoreUSDS from the Collateral contract");
        newUSDS.shouldBurnMoreUSDS(usdsToBurn);
    }

	// A unit test to check if an incorrect or zero address is provided to the constructor of USDS. The test should fail since these addresses would be invalid.
    function testInvalidAddressInConstructor() public {
        address zeroAddress = address(0);
        address wbtcAddress = address(0x1111); // Suppose this is a valid wbtc address
        address wethAddress = address(0x2222); // Suppose this is a valid weth address

        // Test with zero address as wbtc
        vm.expectRevert("_wbtc cannot be address(0)");
        USDS newUSDS = new USDS( IERC20(zeroAddress), IERC20(wethAddress));

        // Test with zero address as weth
        vm.expectRevert("_weth cannot be address(0)");
        newUSDS = new USDS( IERC20(wbtcAddress), IERC20(zeroAddress));
    }


	// A unit test which tries to mint USDS to a zero address. The test should fail since minting to zero addresses should be prohibited.
    function testMintToZeroAddress() public {
        address zeroAddress = address(0);
        uint256 mintAmount = 1 ether;

        // Attempt to mint to a zero address
        vm.expectRevert("Cannot mint to address(0)");
        vm.prank(address(collateral));
        usds.mintTo(zeroAddress, mintAmount);
    }


	// A unit test which tries to mint a zero amount of USDS. The test should not increase the total supply of the USDS.
    function testMintZeroUSDS() public {
        address wallet = address(0x7777);
        uint256 zeroAmount = 0 ether;

        // Store the total supply before minting
        uint256 totalSupplyBeforeMint = usds.totalSupply();

        // Try minting zero USDS from the collateral address
        vm.prank(address(collateral));
        vm.expectRevert( "Cannot mint zero USDS" );
        usds.mintTo(wallet, zeroAmount);

        // The balance of the wallet should not increase
        assertEq(usds.balanceOf(wallet), 0 ether);

        // The total supply of USDS should not increase
        assertEq(usds.totalSupply(), totalSupplyBeforeMint);
    }


	// A unit test to check for integer overflow/underflow in burn, and mint functions.
	// A unit test to check for integer overflow/underflow in burn, mint, and swap functions.
    function testCheckForIntegerOverflowUnderflow() public {
        vm.startPrank(address(collateral));

        uint256 maxUint = type(uint256).max;
        address wallet = address(0x7777);

        // Test overflow in mintTo function
        usds.mintTo(wallet, maxUint);

        vm.expectRevert();
        usds.mintTo(wallet, 1);

        // Test underflow in shouldBurnMoreUSDS function
        vm.prank(address(collateral));
        usds.shouldBurnMoreUSDS(maxUint);

        vm.expectRevert();
        usds.shouldBurnMoreUSDS(1);
    }


	// A unit test that checks setting usdsToBurn to very small and very large values to test edge cases.
    function testSetUsdsToBurnEdgeCases() public {
        uint256 smallAmount = 1;  // smallest non-zero value
        uint256 largeAmount = 10**30 * 1 ether;  // arbitrarily large value

        // Test with very small amount
        vm.prank(address(collateral));
        usds.shouldBurnMoreUSDS(smallAmount);
        assertEq(usds.usdsThatShouldBeBurned(), smallAmount);

        // Test with very large amount
        vm.prank(address(collateral));
        usds.shouldBurnMoreUSDS(largeAmount);
        assertEq(usds.usdsThatShouldBeBurned(), smallAmount + largeAmount);
    }


	//	A unit test that burns 0 amount. Total supply should not change.
	function testBurnZeroAmount() public {
        uint256 initialSupply = usds.totalSupply();
        uint256 burnAmount = 0 ether;

        // Prank as the collateral contract to pass the sender check
        vm.prank(address(collateral));
        usds.shouldBurnMoreUSDS(burnAmount);

        // Perform upkeep which should burn the indicated amount
        vm.prank(address(upkeep));
        usds.performUpkeep();

        // Check that the total supply did not change
        assertEq(usds.totalSupply(), initialSupply);
    }


	// A unit test that mints USDS to multiple user accounts from the collateral contract. It should mint different amounts of USDS to multiple user accounts with validations after each minting operation.
	function testMintUSDSMultipleAccounts() public {
        // Define the user accounts and the amount of USDS to mint to each account
        address[] memory users = new address[](3);
        users[0] = address(0x1111); // alice
        users[1] = address(0x2222); // bob
        users[2] = address(0x3333); // charlie

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 3 ether;
        amounts[1] = 2 ether;
        amounts[2] = 1 ether;

        // Mint USDS to each user account from the collateral contract
        vm.startPrank(address(collateral));
        for(uint i = 0; i < users.length; i++)
        	{
            usds.mintTo(users[i], amounts[i]);
            assertEq(usds.balanceOf(users[i]), amounts[i]);
        	}
	    }


	// A unit test where a call is made to performUpkeep from an address that is not the DAO. This test should validate that only the DAO address can call this function.
	function testPerformUpkeepOnlyByDAO() public {
        // Trying to call performUpkeep from an address that is not the Upkeep contract
        vm.startPrank(address(0xdeadbeef));
        vm.expectRevert("USDS.performUpkeep is only callable from the Upkeep contract");
        usds.performUpkeep();
        vm.stopPrank();
    }


	// A unit test that mimics liquidation, and performs upkeep with the amount of usdsToBurn less that the amount of USDS deposited for counterswap
	function testPerformUpkeepWithSufficientUSDSToBurn() public {
        uint256 wbtcAmount = 5 ether;
        uint256 wethAmount = 3 ether;
        uint256 usdsToBurn = 2 ether;
        uint256 depositedUSDS = 3 ether;

        // Send WBTC and WETH to USDS to mimic WBTC/WETH liquidity colalteral that was liquidated
        vm.startPrank( DEPLOYER );
        wbtc.transfer(address(usds), wbtcAmount);
        weth.transfer(address(usds), wethAmount);
        vm.stopPrank();

		// Deposit USDS directly to act like USDS that was a result of counterswaps
		vm.startPrank( address(collateral) );
		usds.mintTo( Counterswap.WBTC_TO_USDS, depositedUSDS / 2 );
		usds.mintTo( Counterswap.WETH_TO_USDS, depositedUSDS / 2 );
		vm.stopPrank();

		vm.startPrank(Counterswap.WBTC_TO_USDS);
		usds.approve( address(pools), depositedUSDS / 2 );
		pools.deposit( usds, depositedUSDS / 2 );
		vm.stopPrank();

		vm.startPrank(Counterswap.WETH_TO_USDS);
		usds.approve( address(pools), depositedUSDS / 2 );
		pools.deposit( usds, depositedUSDS / 2 );
		vm.stopPrank();

		// Verify the USDS deposits
        assertEq(pools.depositedBalance(Counterswap.WBTC_TO_USDS, usds), depositedUSDS / 2);
        assertEq(pools.depositedBalance(Counterswap.WETH_TO_USDS, usds), depositedUSDS / 2);

		// Mimic liquidation calling shouldBurnMoreUSDS
        vm.prank( address(collateral) );
        usds.shouldBurnMoreUSDS(usdsToBurn);

        // Simulate the DAO address calling performUpkeep
        vm.prank(address(upkeep));
        usds.performUpkeep();

        // performUpkeep should have transfer all WBTC and WETH in the contract to the correct counterswap addresses
        assertEq(pools.depositedBalance(Counterswap.WBTC_TO_USDS, wbtc), wbtcAmount);
        assertEq(pools.depositedBalance(Counterswap.WETH_TO_USDS, weth), wethAmount);

        // Check that the USDS balances for the counterswap addresses has been reduced
        // USDS would have been removed from the WBTC_TO_USDS first and then from the WETH_TO_USDS address
        assertEq(pools.depositedBalance(Counterswap.WBTC_TO_USDS, usds), 0);
        assertEq(pools.depositedBalance(Counterswap.WETH_TO_USDS, usds), 1 ether);

        // Check that USDS was burned
        assertEq(usds.totalSupply(), depositedUSDS - usdsToBurn);
        assertEq(usds.usdsThatShouldBeBurned(), 0);
    }


	// A unit test that mimics liquidation, and performs upkeep with the amount of usdsToBurn greater that the amount of USDS deposited for counterswap
	function testPerformUpkeepWithInsufficientUSDSToBurn() public {
        uint256 wbtcAmount = 5 ether;
        uint256 wethAmount = 3 ether;
        uint256 usdsToBurn = 8 ether;
        uint256 depositedUSDS = 3 ether;

        // Send WBTC and WETH to USDS to mimic WBTC/WETH liquidity colalteral that was liquidated
        vm.startPrank( DEPLOYER );
        wbtc.transfer(address(usds), wbtcAmount);
        weth.transfer(address(usds), wethAmount);
        vm.stopPrank();

		// Deposit USDS directly to act like USDS that was a result of counterswaps
		vm.startPrank( address(collateral) );
		usds.mintTo( Counterswap.WBTC_TO_USDS, depositedUSDS / 2 );
		usds.mintTo( Counterswap.WETH_TO_USDS, depositedUSDS / 2 );
		vm.stopPrank();

		vm.startPrank(Counterswap.WBTC_TO_USDS);
		usds.approve( address(pools), depositedUSDS / 2 );
		pools.deposit( usds, depositedUSDS / 2 );
		vm.stopPrank();

		vm.startPrank(Counterswap.WETH_TO_USDS);
		usds.approve( address(pools), depositedUSDS / 2 );
		pools.deposit( usds, depositedUSDS / 2 );
		vm.stopPrank();

		// Verify the USDS deposits
        assertEq(pools.depositedBalance(Counterswap.WBTC_TO_USDS, usds), depositedUSDS / 2);
        assertEq(pools.depositedBalance(Counterswap.WETH_TO_USDS, usds), depositedUSDS / 2);

		// Mimic liquidation calling shouldBurnMoreUSDS
        vm.prank( address(collateral) );
        usds.shouldBurnMoreUSDS(usdsToBurn);

        // Simulate the DAO address calling performUpkeep
        vm.prank(address(upkeep));
        usds.performUpkeep();

        // performUpkeep should have transfer all WBTC and WETH in the contract to the correct counterswap addresses
        assertEq(pools.depositedBalance(Counterswap.WBTC_TO_USDS, wbtc), wbtcAmount);
        assertEq(pools.depositedBalance(Counterswap.WETH_TO_USDS, weth), wethAmount);

        // Check that the USDS balances for the counterswap addresses has been reduced
        // USDS would have been completely removed from both WBTC_TO_USDS and WETH_TO_USDS as the usdsToBurn is excessive
        assertEq(pools.depositedBalance(Counterswap.WBTC_TO_USDS, usds), 0);
        assertEq(pools.depositedBalance(Counterswap.WETH_TO_USDS, usds), 0);

        // Check that USDS was burned
        assertEq(usds.totalSupply(), 0);
        assertEq(usds.usdsThatShouldBeBurned(), usdsToBurn - depositedUSDS);
    }
	}
