//// SPDX-License-Identifier: BSL 1.1
//pragma solidity ^0.8.12;
//
//import "forge-std/Test.sol";
//import "../USDS.sol";
//
//contract USDSTest is Test, USDS
//	{
//	constructor()
//		{
//		}
//
//
//	// A unit test in which the collateral address is set for the first time. This test should validate that the collateral address is correctly updated.
//	function testSetCollateralAddressOnlyOnce() public {
//		address firstAddress = address(0x5555);
//		address secondAddress = address(0x6666);
//
//		// Initial set up
//		assertEq(address(this.collateral()), address(0));
//
//		// Try setting the collateral address for the first time
//		this.setCollateral(ICollateral(firstAddress));
//		assertEq(address(this.collateral()), address(firstAddress));
//
//		// Try setting the collateral address for the second time
//		vm.expectRevert("setCollateral can only be called once");
//		this.setCollateral(ICollateral(secondAddress));
//
//		// Validate that the collateral address did not change
//		assertEq(address(this.collateral()), address(firstAddress));
//	}
//
//
//
//	// A unit test where a different address attempts to call the mintTo function. This test should validate that only the collateral address is allowed to mint tokens.
//	function testOnlyCollateralCanMint() public {
//        ICollateral collateralAddress = ICollateral(address(0x5555));
//        address otherAddress = address(0x6666);
//        address wallet = address(0x7777);
//        uint256 mintAmount = 1 ether;
//
//        // Set the collateral address
//        this.setCollateral(collateralAddress);
//        assertEq(address(this.collateral()), address(collateralAddress));
//
//        // Try minting from the collateral address
//        vm.prank(address(collateralAddress));
//        this.mintTo(wallet, mintAmount);
//        assertEq(this.balanceOf(wallet), mintAmount);
//
//        // Try minting from a different address
//        vm.expectRevert("Can only mint from the Collateral contract");
//        vm.prank(otherAddress);
//        this.mintTo(wallet, mintAmount);
//
//        // Validate that the balance did not increase
//        assertEq(this.balanceOf(wallet), mintAmount);
//    }
//
//
//	// A unit test where a random address attempts to burn tokens
//	function testBurn() public {
//        address collateralAddress = address(0x5555);
//        address wallet = address(0x7777);
//        uint256 mintAmount = 1 ether;
//        uint256 burnAmount = 0.5 ether;
//
//        // Set the collateral address
//        this.setCollateral(ICollateral(collateralAddress));
//        assertEq(address(this.collateral()), collateralAddress);
//
//        // Mint some tokens to the wallet
//        vm.prank(collateralAddress);
//        this.mintTo(wallet, mintAmount);
//        assertEq(this.balanceOf(wallet), mintAmount);
//
//		uint256 startingSupply = ERC20(this).totalSupply();
//
//        // Have a wallet burn tokens
//        vm.prank(wallet);
//        this.transfer( address(this), burnAmount );
//        this.burnTokensInContract();
//        assertEq(this.balanceOf(wallet), mintAmount - burnAmount);
//
//		uint256 burned = startingSupply - ERC20(this).totalSupply();
//
//		assertEq( burned, burnAmount, "Unexpected amount of tokens burned" );
//    }
//
//
//	// A unit test where multiple mints and burns and that token balances are calculated correctly
//	function testMultipleMintsAndBurns() public {
//
//        address collateralAddress = address(0x5555);
//        address wallet = address(0x7777);
//        uint256 mintAmount1 = 5 ether;
//        uint256 burnAmount1 = 2 ether;
//        uint256 mintAmount2 = 3 ether;
//        uint256 burnAmount2 = 1 ether;
//
//        // Set the collateral address
//        this.setCollateral(ICollateral(collateralAddress));
//        assertEq(address(this.collateral()), collateralAddress);
//
//        // Mint some tokens to the wallet
//        vm.prank(collateralAddress);
//        this.mintTo(wallet, mintAmount1);
//        assertEq(this.balanceOf(wallet), mintAmount1);
//
//        // Burn some tokens from the wallet
//        vm.prank(wallet);
//        this.transfer( address(this), burnAmount1 );
//        this.burnTokensInContract(); // called by this
//        assertEq(this.balanceOf(wallet), mintAmount1 - burnAmount1);
//
//        // Mint some more tokens to the wallet
//        vm.prank(collateralAddress);
//        this.mintTo(wallet, mintAmount2);
//        assertEq(this.balanceOf(wallet), mintAmount1 - burnAmount1 + mintAmount2);
//
//        // Burn some more tokens from the wallet
//        vm.prank(wallet);
//        this.transfer( address(this), burnAmount2 );
//        this.burnTokensInContract(); // called by this
//        assertEq(this.balanceOf(wallet), mintAmount1 - burnAmount1 + mintAmount2 - burnAmount2);
//    }
//	}
