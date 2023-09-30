// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "./interfaces/IBootstrapBallot.sol";
import "../openzeppelin/security/ReentrancyGuard.sol";
import "./interfaces/IAirdrop.sol";
import "./interfaces/IInitialDistribution.sol";


// Allows the airdrop participants to vote on wheter or not to distribute SALT to the exchange contracts and start up the exchange
contract BootstrapBallot is IBootstrapBallot, ReentrancyGuard
    {
    IInitialDistribution public initialDistribution;
    IAirdrop public airdrop;

	uint256 public completionTimestamp;
	bool public ballotFinalized;

	// Ensures that voters can only vote once
	mapping(address=>bool) public hasVoted;

	uint256 public yesVotes;
	uint256 public noVotes;


	constructor( IInitialDistribution _initialDistribution, IAirdrop _airdrop, uint256 ballotDuration )
		{
		require( address(_initialDistribution) != address(0), "_initialDistribution cannot be address(0)" );
		require( address(_airdrop) != address(0), "_airdrop cannot be address(0)" );

		initialDistribution = _initialDistribution;
		airdrop = _airdrop;

		completionTimestamp = block.timestamp + ballotDuration;
		}


	// Ensures that the completionTimestamp has been reached and then calls InitialDistribution.distributionApproved if the voters have approved it
	function finalizeBallot() public
		{
		require( ! ballotFinalized, "Ballot has already been finalized" );
		require( block.timestamp >= completionTimestamp, "Ballot duration is not yet complete" );

		if ( yesVotes > noVotes )
			initialDistribution.distributionApproved();

		ballotFinalized = true;
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