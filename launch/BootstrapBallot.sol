// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "./interfaces/IBootstrapBallot.sol";
import "../openzeppelin/security/ReentrancyGuard.sol";
import "./interfaces/IAirdrop.sol";
import "../interfaces/IExchangeConfig.sol";


// Allows airdrop participants to vote on whether or not to start up the exchange by distributing SALT to the various exchange contracts.
// The actual distribution is handled by the InitialDistribution.distributionApproved() function.

contract BootstrapBallot is IBootstrapBallot, ReentrancyGuard
    {
    IExchangeConfig public exchangeConfig;
    IAirdrop public airdrop;

	uint256 public completionTimestamp;
	bool public ballotFinalized;
	bool private _ballotApproved;

	// Ensures that voters can only vote once
	mapping(address=>bool) public hasVoted;

	// The tally of YES and NO votes
	uint256 public yesVotes;
	uint256 public noVotes;


	constructor( IExchangeConfig _exchangeConfig, IAirdrop _airdrop, uint256 ballotDuration )
		{
		require( address(_exchangeConfig) != address(0), "_exchangeConfig cannot be address(0)" );
		require( address(_airdrop) != address(0), "_airdrop cannot be address(0)" );
		require( ballotDuration > 0, "ballotDuration cannot be zero" );

		exchangeConfig = _exchangeConfig;
		airdrop = _airdrop;

		completionTimestamp = block.timestamp + ballotDuration;
		}


	// Ensures that the completionTimestamp has been reached and then calls InitialDistribution.distributionApproved if the voters have approved the ballot
	function finalizeBallot() public nonReentrant
		{
		require( ! ballotFinalized, "Ballot has already been finalized" );
		require( block.timestamp >= completionTimestamp, "Ballot duration is not yet complete" );

		if ( yesVotes > noVotes )
			{
			exchangeConfig.initialDistribution().distributionApproved();
			_ballotApproved = true;
			}

		ballotFinalized = true;
		}


	// Cast a YES or NO vote to start up the exchange (airdropped users only).
	// Votes cannot be changed once they are cast.
	function vote( bool voteYes ) public nonReentrant
		{
		require( airdrop.whitelisted(msg.sender), "User is not an Airdrop recipient" );
		require( exchangeConfig.walletHasAccess(msg.sender), "User does not have exchange access" );
		require( ! hasVoted[msg.sender], "User already voted" );

		if ( voteYes )
			yesVotes++;
		else
			noVotes++;

		hasVoted[msg.sender] = true;
		}


	function ballotApproved() public virtual returns (bool)
		{
		return _ballotApproved;
		}	}