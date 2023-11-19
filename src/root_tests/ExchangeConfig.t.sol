// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "forge-std/Test.sol";
import "../dev/Deployment.sol";


contract TestExchangeConfig is Deployment
	{
    address public constant alice = address(0x1111);


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
		}


    // A unit test to check the ExchangeConfig constructor when it is supplied with an invalid null address for one or more parameters. Verify that the function reverts with the correct error message.
    function testConstructorWithInvalidNullAddresses() public
    		{
    		IERC20 fakeIERC20 = IERC20(address(12345));
    		IUSDS fakeUSDS = IUSDS(address(23456));

    		// Test with _salt as zero address
    		vm.expectRevert("_salt cannot be address(0)");
    		new ExchangeConfig(ISalt(address(0)), fakeIERC20, fakeIERC20, fakeIERC20, fakeUSDS, managedTeamWallet);

    		// Test with _wbtc as zero address
    		vm.expectRevert("_wbtc cannot be address(0)");
    		new ExchangeConfig(salt, IERC20(address(0)), fakeIERC20, fakeIERC20, fakeUSDS, managedTeamWallet);

    		// Test with _weth as zero address
    		vm.expectRevert("_weth cannot be address(0)");
    		new ExchangeConfig(salt, fakeIERC20, IERC20(address(0)), fakeIERC20, fakeUSDS, managedTeamWallet);

    		// Test with _dai as zero address
    		vm.expectRevert("_dai cannot be address(0)");
    		new ExchangeConfig(salt, fakeIERC20, fakeIERC20, IERC20(address(0)), fakeUSDS, managedTeamWallet);

    		// Test with _usds as zero address
    		vm.expectRevert("_usds cannot be address(0)");
    		new ExchangeConfig(salt, fakeIERC20, fakeIERC20, fakeIERC20, IUSDS(address(0)), managedTeamWallet);

    		// Test with _teamWallet as zero address
    		vm.expectRevert("_managedTeamWallet cannot be address(0)");
    		new ExchangeConfig(salt, fakeIERC20, fakeIERC20, fakeIERC20, fakeUSDS, IManagedWallet(address(0)));
    		}


    // A unit test to check the setAccessManager function when it is called by an address other than the owner. Verify that the function reverts with the correct error message.
	function testSetAccessManagerAsNonOwner() public
        {
        vm.prank(DEPLOYER);
        exchangeConfig = new ExchangeConfig(salt, wbtc, weth, dai, usds, managedTeamWallet);

		vm.expectRevert("Ownable: caller is not the owner" );
		exchangeConfig.setAccessManager(IAccessManager(address(0x2222)));
        }


    // A unit test to check the setAccessManager function when called by the owner and the accessManager state variable has not been set yet. Ensure that the accessManager state variable is correctly set.
    function testSetAccessManager() public
    {
        exchangeConfig = new ExchangeConfig(salt, wbtc, weth, dai, usds, managedTeamWallet);

        // Initialize an instance of the AccessManager
        IAccessManager _accessManager = IAccessManager(address(0x1111));

        // Call `setAccessManager` function with the initialized _accessManager instance
        exchangeConfig.setAccessManager(_accessManager);

        // Assert that the `accessManager` state variable is now equal to the _accessManager instance
        assertEq(address(exchangeConfig.accessManager()), address(_accessManager));
    }


    // A unit test to check the walletHasAccess function when the given wallet address is the DAO address. Verify that the function returns true.
    function testWalletHasAccessDAOWallet() public {
    	// Call `walletHasAccess` function with DAO address
        assertTrue(exchangeConfig.walletHasAccess(address(dao)));
    }



    // A unit test to check the walletHasAccess function when the given wallet address is not the DAO address and the accessManager contract allows access for this wallet. Verify that the function returns true.
    function testWalletHasAccessNonDAOWalletAllowedByAccessManager() public {

    	// Give access to the user
		bytes memory sig = abi.encodePacked(oneTwoThreeFourAccessSignature);
		vm.prank( address(0x1234) );
		accessManager.grantAccess(sig);


    	// Call `walletHasAccess` function with a non-DAO address which is allowed by accessManager
    	assertTrue(exchangeConfig.walletHasAccess(address(0x1234)));
    }


    // A unit test to check the walletHasAccess function when the given wallet address is not the DAO address and the accessManager contract does not allow access for this wallet. Verify that the function returns false.
    function testWalletHasAccessNonDAOWalletNotAllowedByAccessManager() public {
    	// Call `walletHasAccess` function with a non-DAO address which is not allowed by accessManager
    	assertFalse(exchangeConfig.walletHasAccess(address(0x1234)));
    }



	// A unit test that verifies `setContracts` reverts if called more than once.
    // A unit test that checks if `setAccessManager` correctly reverts when supplied with the zero address as parameter.
    // A unit test that checks `walletHasAccess` function when the given wallet address is the Airdrop address, should return true.
	}
