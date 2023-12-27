// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "../interfaces/IExchangeConfig.sol";
import "./interfaces/IBootstrapBallot.sol";
import "./interfaces/IAirdrop.sol";
import "../SigningTools.sol";


// Allows airdrop participants to vote on whether or not to start up the exchange and which countries should be initially excluded from access.

contract BootstrapBallot is IBootstrapBallot, ReentrancyGuard
    {
	event BallotFinalized(bool startExchange);

    IExchangeConfig immutable public exchangeConfig;
    IAirdrop immutable public airdrop;
	uint256 immutable public completionTimestamp;

	bool public ballotFinalized;
	bool public startExchangeApproved;

	// Ensures that voters can only vote once
	mapping(address=>bool) public hasVoted;

	// === VOTE TALLIES ===
	// Yes/No tallies on whether or not to start the exchange and distribute SALT to the ecosystem contracts
	uint256 public startExchangeYes;
	uint256 public startExchangeNo;



	constructor( IExchangeConfig _exchangeConfig, IAirdrop _airdrop, uint256 ballotDuration )
		{
		require( ballotDuration > 0, "ballotDuration cannot be zero" );

		exchangeConfig = _exchangeConfig;
		airdrop = _airdrop;

		completionTimestamp = block.timestamp + ballotDuration;
		}


	// Cast a YES or NO vote to start up the exchange, distribute SALT and establish initial geo restrictions.
	// Votes cannot be changed once they are cast.
	// Requires a valid signature to signify that the msg.sender is authorized to vote (being whitelisted and the retweeting exchange launch posting - checked offchain)
	function vote( bool voteStartExchangeYes, bytes calldata signature ) external nonReentrant
		{
		require( ! hasVoted[msg.sender], "User already voted" );

		// Verify the signature to confirm the user is authorized to vote
		bytes32 messageHash = keccak256(abi.encodePacked(block.chainid, msg.sender));
		require(SigningTools._verifySignature(messageHash, signature), "Incorrect BootstrapBallot.vote signatory" );

		if ( voteStartExchangeYes )
			startExchangeYes++;
		else
			startExchangeNo++;

		hasVoted[msg.sender] = true;

		// As the whitelisted user has retweeted the launch message and voted, they are authorized to the receive the airdrop.
		airdrop.authorizeWallet(msg.sender);
		}


	// Ensures that the completionTimestamp has been reached and then calls InitialDistribution.distributionApproved and DAO.initialGeoExclusion if the voters have approved the ballot.
	function finalizeBallot() external nonReentrant
		{
		require( ! ballotFinalized, "Ballot has already been finalized" );
		require( block.timestamp >= completionTimestamp, "Ballot is not yet complete" );

		if ( startExchangeYes > startExchangeNo )
			{
			exchangeConfig.initialDistribution().distributionApproved();
			exchangeConfig.dao().pools().startExchangeApproved();

			startExchangeApproved = true;
			}

		emit BallotFinalized(startExchangeApproved);

		ballotFinalized = true;
		}
	}