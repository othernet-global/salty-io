// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "./interfaces/IAirdrop.sol";
import "../openzeppelin/access/Ownable.sol";
import "../openzeppelin/utils/structs/EnumerableSet.sol";
import "../interfaces/IExchangeConfig.sol";
import "../staking/interfaces/IStaking.sol";
import "../openzeppelin/security/ReentrancyGuard.sol";


// The Airdrop contract keeps track of users who qualify for the Salty.IO Airdrop (participants of prominent DeFi protocols who perform a basic social media task).
// The airdrop participants are able to claim staked SALT after the airdrop whitelisting period has ending (after the BootingstappingBallot has concluded).
contract Airdrop is IAirdrop, Ownable, ReentrancyGuard
    {
    using EnumerableSet for EnumerableSet.AddressSet;

	IExchangeConfig public exchangeConfig;
    IStaking public staking;
    ISalt public salt;

	EnumerableSet.AddressSet private _whitelist;

	bool public claimingAllowed;
	mapping(address=>bool) public claimed;

	uint256 public saltAmountForEachUser;


	constructor( IExchangeConfig _exchangeConfig, IStaking _staking )
		{
		require( address(_exchangeConfig) != address(0), "_exchangeConfig cannot be address(0)" );
		require( address(_staking) != address(0), "_staking cannot be address(0)" );

		exchangeConfig = _exchangeConfig;
		staking = _staking;

		salt = _exchangeConfig.salt();
		}


	// Whitelist a wallet as being able to claim the airdrop and vote in the BootstappingBallot
    function whitelistWallet( address wallet ) public onlyOwner
    	{
    	require( ! claimingAllowed, "Cannot whitelist after claiming is allowed" );

		_whitelist.add(wallet);
    	}


	// Whitelist multiple wallets as being able to claim the airdrop and vote in the BootstappingBallot
    function whitelistWallets( address[] memory wallets ) public onlyOwner
    	{
    	require( ! claimingAllowed, "Cannot whitelist after claiming is allowed" );

    	for ( uint256 i = 0; i < wallets.length; i++ )
			_whitelist.add(wallets[i]);
    	}


	// Unwhitelist a specified wallet
    function unwhitelistWallet( address wallet ) public onlyOwner
    	{
		_whitelist.remove(wallet);
    	}


	// Called by the InitialDistribution contract during its distributionApproved() function - which is called on successful conclusion of the BootstrappingBallot
    function allowClaiming() public
    	{
    	require( ! claimingAllowed, "Claiming is already allowed" );
		require(numberWhitelisted() > 0, "No addresses whitelisted to claim airdrop.");
    	require( msg.sender == address(exchangeConfig.initialDistribution()), "Airdrop.allowClaiming can only be called by the InitialDistribution contract" );

    	// All users receive an equal share of the airdrop
		saltAmountForEachUser = salt.balanceOf(address(this)) / numberWhitelisted();

		// Have the Airdrop contract stake all of the SALT that it holds so that that xSALT (staked SALT) can later be transferred to airdrop recipients
		salt.approve( address(staking), type(uint256).max );

    	claimingAllowed = true;
    	}


	// Sends a fixed amount of xSALT (staked SALT) to a qualifying user
    function claimAirdrop() public nonReentrant
    	{
    	require( claimingAllowed, "Claiming is not allowed yet" );
    	require( whitelisted(msg.sender), "Wallet is not whitelisted for airdrop" );
    	require( ! claimed[msg.sender], "Wallet already claimed the airdrop" );
		require( exchangeConfig.walletHasAccess(msg.sender), "Sender does not have exchange access" );

		// Have the Airdrop contract stake a specified amount of SALT and then
		staking.stakeSALT( saltAmountForEachUser );
		staking.transferXSaltFromAirdrop( msg.sender, saltAmountForEachUser );

    	claimed[msg.sender] = true;
    	}


    // === VIEWS ===
    // Returns true if the specified wallet has been whitelisted
    function whitelisted(address wallet) public view returns (bool)
    	{
    	return _whitelist.contains(wallet);
    	}


	// The current number of whitelisted wallets
    function numberWhitelisted() public view returns (uint256)
    	{
    	return _whitelist.length();
    	}


	// Returns an array of the currently whitelisted wallets
	function whitelistedWallets() public view returns (address[] memory)
		{
		return _whitelist.values();
		}
	}