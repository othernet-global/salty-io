// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "../interfaces/IExchangeConfig.sol";
import "../staking/interfaces/IStaking.sol";
import "./interfaces/IAirdrop.sol";


// The Airdrop contract keeps track of users who qualify for the Salty.IO Airdrop (participants of prominent DeFi protocols who retweet the launch announcement and vote).
// The airdrop participants are able to claim staked SALT after the BootingstapBallot has concluded.

contract Airdrop is IAirdrop, ReentrancyGuard
    {
    using EnumerableSet for EnumerableSet.AddressSet;

	IExchangeConfig immutable public exchangeConfig;
    IStaking immutable public staking;
    ISalt immutable public salt;

	// These are users who have retweeted the launch announcement and voted
	EnumerableSet.AddressSet private _authorizedUsers;

	// Set to true when airdrop claiming is allowed
	bool public claimingAllowed;

	// Those users who have already claimed
	mapping(address=>bool) public claimed;

	// How much SALT each user receives for the airdrop
	uint256 public saltAmountForEachUser;


	constructor( IExchangeConfig _exchangeConfig, IStaking _staking )
		{
		exchangeConfig = _exchangeConfig;
		staking = _staking;

		salt = _exchangeConfig.salt();
		}


	// Authorize the wallet as being able to claim the airdrop.
	// The BootstrapBallot would have already confirmed the user retweeted and voted.
    function authorizeWallet( address wallet ) external
    	{
    	require( msg.sender == address(exchangeConfig.initialDistribution().bootstrapBallot()), "Only the BootstrapBallot can call Airdrop.authorizeWallet" );
    	require( ! claimingAllowed, "Cannot authorize after claiming is allowed" );

		_authorizedUsers.add(wallet);
    	}


	// Called by the InitialDistribution contract during its distributionApproved() function - which is called on successful conclusion of the BootstrappingBallot
    function allowClaiming() external
    	{
    	require( msg.sender == address(exchangeConfig.initialDistribution()), "Airdrop.allowClaiming can only be called by the InitialDistribution contract" );
    	require( ! claimingAllowed, "Claiming is already allowed" );
		require(numberAuthorized() > 0, "No addresses authorized to claim airdrop.");

    	// All users receive an equal share of the airdrop.
    	uint256 saltBalance = salt.balanceOf(address(this));
		saltAmountForEachUser = saltBalance / numberAuthorized();

		// Have the Airdrop approve max so that that xSALT (staked SALT) can later be transferred to airdrop recipients.
		salt.approve( address(staking), saltBalance );

    	claimingAllowed = true;
    	}


	// Sends a fixed amount of xSALT (staked SALT) to a qualifying user
    function claimAirdrop() external nonReentrant
    	{
    	require( claimingAllowed, "Claiming is not allowed yet" );
    	require( isAuthorized(msg.sender), "Wallet is not authorized for airdrop" );
    	require( ! claimed[msg.sender], "Wallet already claimed the airdrop" );

		// Have the Airdrop contract stake a specified amount of SALT and then transfer it to the user
		staking.stakeSALT( saltAmountForEachUser );
		staking.transferStakedSaltFromAirdropToUser( msg.sender, saltAmountForEachUser );

    	claimed[msg.sender] = true;
    	}


    // === VIEWS ===
    // Returns true if the specified wallet has been authorized
    function isAuthorized(address wallet) public view returns (bool)
    	{
    	return _authorizedUsers.contains(wallet);
    	}


	// The current number of authorized wallets
    function numberAuthorized() public view returns (uint256)
    	{
    	return _authorizedUsers.length();
    	}
	}