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
	function testSetContractsRevertsIfCalledMoreThanOnce() public {
        // Arrange: Deploy the contract and setup contracts for the first time
        vm.prank(address(this));
        ExchangeConfig exchangeConfig = new ExchangeConfig(salt, wbtc, weth, dai, usds, managedTeamWallet);

        IDAO mockDao = IDAO(address(0x1));
        IUpkeep mockUpkeep = IUpkeep(address(0x2));
        IInitialDistribution mockInitialDistribution = IInitialDistribution(address(0x3));
        IAirdrop mockAirdrop = IAirdrop(address(0x4));

        // Act: Call setContracts for the first time
        exchangeConfig.setContracts(mockDao, mockUpkeep, mockInitialDistribution, mockAirdrop, teamVestingWallet, daoVestingWallet);

        // Assert: Calling setContracts again should revert
        vm.expectRevert("setContracts can only be called once");
        exchangeConfig.setContracts(mockDao, mockUpkeep, mockInitialDistribution, mockAirdrop, teamVestingWallet, daoVestingWallet);
    }


    // A unit test that checks if `setAccessManager` correctly reverts when supplied with the zero address as parameter.
    function testSetAccessManagerRevertsWithZeroAddress() public
        {
        // Deploy the ExchangeConfig contract
        exchangeConfig = new ExchangeConfig(salt, wbtc, weth, dai, usds, managedTeamWallet);

        // Set the expected revert reason and call the function with the zero address
        vm.expectRevert("_accessManager cannot be address(0)");
        exchangeConfig.setAccessManager(IAccessManager(address(0)));
        }


    // A unit test that checks `walletHasAccess` function when the given wallet address is the Airdrop address, should return true.
    // A unit test that checks `walletHasAccess` function when the given wallet address is the Airdrop address, should return true.
    function testWalletHasAccessAirdropAddress() public {
        // Call `walletHasAccess` function with Airdrop address
        assertTrue(exchangeConfig.walletHasAccess(address(airdrop)));
    }
	}
