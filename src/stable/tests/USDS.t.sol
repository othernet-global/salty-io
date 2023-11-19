// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "../../dev/Deployment.sol";


contract USDSTest is Deployment
	{
	constructor()
		{
		// If $COVERAGE=yes, create an instance of the contract so that coverage testing can work
		// Otherwise, what is tested is the actual deployed contract on the blockchain (as specified in Deployment.sol)
		if ( keccak256(bytes(vm.envString("COVERAGE" ))) == keccak256(bytes("yes" )))
			initializeContracts();

		grantAccessAlice();
		grantAccessBob();
		grantAccessCharlie();
		grantAccessDeployer();
		grantAccessDefault();

		finalizeBootstrap();
		}


	// // A unit test in which the collateral address is set for the first time. This test should validate that the collateral address is correctly updated and can only be set once.
	function testSetCollateralAndLiquidityOnlyOnce() public
		{
		address _collateral = address(0x5555);

		// New USDS in case CollateralAndLiquidity.sol was set in the deployed version already
		usds = new USDS();

		// Initial set up
		assertEq(address(usds.collateralAndLiquidity()), address(0));

		usds.setCollateralAndLiquidity( ICollateralAndLiquidity(_collateral));

		assertEq(address(usds.collateralAndLiquidity()), address(_collateral));

		address invalid = address(0xdead);

		vm.expectRevert("Ownable: caller is not the owner");
		usds.setCollateralAndLiquidity( ICollateralAndLiquidity(invalid) );

		// Validate that the addresses did not change
		assertEq(address(usds.collateralAndLiquidity()), address(_collateral));
	}


	// A unit test where a different address attempts to call the mintTo function. This test should validate that only the collateral address is allowed to mint tokens.
	function testOnlyCollateralCanMint() public {
        address otherAddress = address(0x6666);
        address wallet = address(0x7777);
        uint256 mintAmount = 1 ether;

        // Try minting from the collateral address
        vm.prank(address(collateralAndLiquidity));
        usds.mintTo(wallet, mintAmount);
        assertEq(usds.balanceOf(wallet), mintAmount);

        // Try minting from a different address
        vm.expectRevert("USDS.mintTo is only callable from the Collateral contract");
        vm.prank(otherAddress);
        usds.mintTo(wallet, mintAmount);

        // Validate that the balance did not increase
        assertEq(usds.balanceOf(wallet), mintAmount);
    }


	// A unit test where a different address attempts to call the mintTo function. This test should validate that only the collateral address is allowed to mint tokens.
	function testOnlyCollateralCanMint2() public {
        address otherAddress = address(0x6666);
        address wallet = address(0x7777);
        uint256 mintAmount = 1 ether;

        // Set up a new instance of USDS and set collateral
        // Mint from the collateral address
        vm.prank(address(collateralAndLiquidity));
        usds.mintTo(wallet, mintAmount);
        assertEq(usds.balanceOf(wallet), mintAmount);

        // Attempt to mint from a different address
        vm.expectRevert("USDS.mintTo is only callable from the Collateral contract");
        vm.prank(otherAddress);
        usds.mintTo(wallet, mintAmount);

        // Validate that the balance did not increase
        assertEq(usds.balanceOf(wallet), mintAmount);
    }



	// A unit test where a call is made to mintTo function without calling the setCollateral function first. This test will validate that before the mint operation can be made, the CollateralAndLiquidity.sol.sol contract has to be set.
    function testMintWithoutSettingCollateral() public {
        address wallet = address(0x7777);
        uint256 mintAmount = 1 ether;

        // Try minting without setting the collateral address first
        vm.expectRevert("USDS.mintTo is only callable from the Collateral contract");
        usds.mintTo(wallet, mintAmount);

        // Validate that the balance did not increase
        assertEq(usds.balanceOf(wallet), 0);
    }


	// A unit test which tries to mint a zero amount of USDS. The test should not increase the total supply of the USDS.
    function testMintZeroUSDS() public {
        address wallet = address(0x7777);
        uint256 zeroAmount = 0 ether;

        // Store the total supply before minting
        uint256 totalSupplyBeforeMint = usds.totalSupply();

        // Try minting zero USDS from the collateral address
        vm.prank(address(collateralAndLiquidity));
        vm.expectRevert( "Cannot mint zero USDS" );
        usds.mintTo(wallet, zeroAmount);

        // The balance of the wallet should not increase
        assertEq(usds.balanceOf(wallet), 0 ether);

        // The total supply of USDS should not increase
        assertEq(usds.totalSupply(), totalSupplyBeforeMint);
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
        vm.startPrank(address(collateralAndLiquidity));
        for(uint i = 0; i < users.length; i++)
        	{
            usds.mintTo(users[i], amounts[i]);
            assertEq(usds.balanceOf(users[i]), amounts[i]);
        	}
	    }


	// A unit test that makes sure the constructor initializes the token with correct name and symbol.
	function testConstructorInitializesTokenWithCorrectNameAndSymbol() public {
        // Create a new instance of USDS to test constructor initialization.
        USDS usdsToken = new USDS();

        // Check that the token name is set correctly.
        assertEq(usdsToken.name(), "USDS");

        // Check that the token symbol is set correctly.
        assertEq(usdsToken.symbol(), "USDS");
    }


    // A unit test ensuring the burnTokensInContract function does not allow burning when the contract's balance is zero.
	function testDisallowBurningWhenBalanceIsZero() public {
        // Contract's initial USDS balance is expected to be zero
        assertEq(usds.balanceOf(address(usds)), 0);

        // Expect revert with the correct error message
        uint256 supply0 = usds.totalSupply();
        usds.burnTokensInContract();

        assertEq( supply0, usds.totalSupply() );
    }


    // A unit test confirming the burnTokensInContract function only works when there are USDS tokens in the contract.
	function testBurnTokensInContract() public {
        uint256 burnAmount = 5 ether;

		// If there are USDS tokens in the contract, we simulate sending USDS to the contract
		vm.startPrank(address(collateralAndLiquidity));
		usds.mintTo(address(usds), burnAmount);
		vm.stopPrank();
		assertEq(usds.balanceOf(address(usds)), burnAmount);

		// Then we call the burnTokensInContract function and expect it to succeed
		usds.burnTokensInContract();

		// After burning, the balance of USDS in the contract should be 0
		assertEq(usds.balanceOf(address(usds)), 0);
	    }


    // A unit test that ensures after burning tokens with the burnTokensInContract function, the total supply is reduced accordingly.
    function testBurnTokensReducesTotalSupply() public {
        assertEq(usds.totalSupply(), 0, "Initial supply should be zero");

        uint256 burnAmount = 5 ether;

        // Mint some tokens to the contract itself to simulate users repaying loans
        vm.prank(address(collateralAndLiquidity));
        usds.mintTo(address(usds), burnAmount);

        assertEq(usds.balanceOf(address(usds)), burnAmount);

        // Burn the tokens and verify the total supply is reduced accordingly
        usds.burnTokensInContract();
        assertEq(usds.totalSupply(), 0, "Total supply did not reduce after burning tokens in contract");
    }


    // A unit test validating an attempt to mint USDS to an invalid address (address(0)) fails.
    function testMintToInvalidAddressFails() public {
        uint256 mintAmount = 1 ether;

        // Attempt to mint to the invalid address (address(0))
        vm.expectRevert("ERC20: mint to the zero address");
        vm.prank(address(collateralAndLiquidity));
        usds.mintTo(address(0), mintAmount);

        // Validate that the total supply did not increase
        assertEq(usds.totalSupply(), 0);
    }


    // A unit test to ensure the totalSupply of USDS increases correctly after minting operations.
    function testTotalSupplyIncreasesAfterMint() public {
        address wallet = address(0x7777);
        uint256 mintAmount = 5 ether;
        uint256 initialTotalSupply = usds.totalSupply();

        // Mint to the wallet from the collateral address
        vm.prank(address(collateralAndLiquidity));
        usds.mintTo(wallet, mintAmount);

        uint256 newTotalSupply = usds.totalSupply();

        // The total supply should have increased by the mint amount
        assertEq(newTotalSupply, initialTotalSupply + mintAmount);
    }


    // A unit test that consistently sends varying amounts of USDS to the contract and ensures burnTokensInContract accurately burns only the tokens within the contract.
    function testBurnOnlyContractTokens(uint256 amount1, uint256 amount2, uint256 amount3) public {

		amount1 = amount1 % type(uint64).max;
		amount2 = amount2 % type(uint64).max;
		amount3 = amount3 % type(uint64).max;

		vm.startPrank(address(collateralAndLiquidity));
		usds.mintTo(address(usds), amount1 + 1);
		usds.mintTo(address(usds), amount2 + 1);
		vm.stopPrank();

		assertEq(usds.balanceOf(address(usds)), amount1 + amount2 + 2, "Incorrect minted balance" );
		assertEq( usds.totalSupply(), amount1 + amount2 + 2, "Incorrect total supply" );

		usds.burnTokensInContract();
		assertEq(usds.balanceOf(address(usds)), 0);

		vm.prank(address(collateralAndLiquidity));
		usds.mintTo(address(usds), amount3 + 1);

		assertEq(usds.balanceOf(address(usds)), amount3 + 1);

		usds.burnTokensInContract();
		assertEq(usds.balanceOf(address(usds)), 0);
    }
	}
