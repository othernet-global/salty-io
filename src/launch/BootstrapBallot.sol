// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "../interfaces/IExchangeConfig.sol";
import "./interfaces/IBootstrapBallot.sol";
import "./interfaces/IAirdrop.sol";
import "../SigningTools.sol";


// Allows airdrop participants to vote on whether or not to start up the exchange

contract BootstrapBallot is IBootstrapBallot, ReentrancyGuard
    {
	event BallotFinalized(bool startExchange);

    IExchangeConfig immutable public exchangeConfig;
    IAirdrop immutable public airdrop1;
    IAirdrop immutable public airdrop2;

	// Completion timestamps for Airdrop I and 2
	uint256 immutable public claimableTimestamp1;
	uint256 immutable public claimableTimestamp2;

	bool public ballotFinalized;
	bool public startExchangeApproved;

	// Ensures that voters can only vote once
	mapping(address=>bool) public hasVoted;

	// === VOTE TALLIES ===
	// Yes/No tallies on whether or not to start the exchange and distribute SALT to the ecosystem contracts
	uint256 public startExchangeYes;
	uint256 public startExchangeNo;



	constructor( IExchangeConfig _exchangeConfig, IAirdrop _airdrop1, IAirdrop _airdrop2, uint256 ballotDuration, uint256 airdrop2DelayTillDistribution )
		{
		require( ballotDuration > 0, "ballotDuration cannot be zero" );

		exchangeConfig = _exchangeConfig;
		airdrop1 = _airdrop1;
		airdrop2 = _airdrop2;

		// Airdrop I is claimable when the BootstrapBallot is completed
		claimableTimestamp1 = block.timestamp + ballotDuration;

		// Airdrop 2 is claimable a certain number of days after Airdrop 1 completes
		claimableTimestamp2 = claimableTimestamp1 + airdrop2DelayTillDistribution;
		}


	function bytes32ToHexString(bytes32 input) internal pure returns (string memory) {
			bytes memory lookup = "0123456789abcdef";
			bytes memory result = new bytes(64);
			for (uint i = 0; i < 32; i++) {
				uint8 currentByte = uint8(input[i]);
				uint8 hi = uint8(currentByte / 16);
				uint8 lo = currentByte - 16 * hi;
				result[i*2] = lookup[hi];
				result[i*2+1] = lookup[lo];
			}
			return string(result);
		}


	// Cast a YES or NO vote to start up the exchange, distribute SALT and establish initial geo restrictions.
	// Votes cannot be changed once they are cast.
	// Requires a valid signature to signify that the msg.sender is authorized to vote and entitled to receive the specified saltAmount (checked offchain)
	function vote( bool voteStartExchangeYes, uint256 saltAmount, bytes calldata signature ) external nonReentrant
		{
		require( ! hasVoted[msg.sender], "User already voted" );
		require( ! ballotFinalized, "Ballot has already been finalized" );
		require( saltAmount != 0, "saltAmount cannot be zero" );

		// Verify the signature to confirm the user is authorized to vote
		bytes32 messageHash = keccak256(abi.encodePacked( uint256(1), block.chainid, saltAmount, msg.sender));
		require(SigningTools._verifySignature(messageHash, signature), "Incorrect BootstrapBallot.vote signatory" );

		if ( voteStartExchangeYes )
			startExchangeYes++;
		else
			startExchangeNo++;

		hasVoted[msg.sender] = true;

		// Authorize the user to receive Airdrop 1
		airdrop1.authorizeWallet(msg.sender, saltAmount);
		}


	// Ensures that the completionTimestamp has been reached and then calls InitialDistribution.distributionApproved if the voters have approved the ballot.
	function finalizeBallot() external nonReentrant
		{
		require( ! ballotFinalized, "Ballot has already been finalized" );
		require( block.timestamp >= claimableTimestamp1, "Ballot is not yet complete" );

		if ( startExchangeYes > startExchangeNo )
			{
			// First call performUpkeep() to reset the emissions timers so the first liquidity rewards claimers don't claim a full days worth of the bootstrap rewards
			exchangeConfig.upkeep().performUpkeep();

			exchangeConfig.initialDistribution().distributionApproved( airdrop1, airdrop2 );
			airdrop1.allowClaiming();

			exchangeConfig.dao().pools().startExchangeApproved();

			startExchangeApproved = true;
			}

		emit BallotFinalized(startExchangeApproved);

		ballotFinalized = true;
		}


	// Requires a valid signature to signify that the msg.sender is entitled to receive the specified saltAmount for Airdrop 2 (checked offchain)
	function authorizeAirdrop2( uint256 saltAmount, bytes calldata signature ) external nonReentrant
		{
		require( saltAmount != 0, "saltAmount cannot be zero" );

		// Verify the signature to confirm the user is authorized to receive Airdrop 2
		bytes32 messageHash = keccak256(abi.encodePacked(uint256(2), block.chainid, saltAmount, msg.sender));
		require(SigningTools._verifySignature(messageHash, signature), "Incorrect authorizeAirdrop2 signatory" );

		// Authorize the user to receive Airdrop 2
		airdrop2.authorizeWallet(msg.sender, saltAmount);
		}


	// Called to signify that Airdrop 2 is ready to allow claiming
	function finalizeAirdrop2() external nonReentrant
		{
		require( block.timestamp >= claimableTimestamp2, "Airdrop 2 cannot be finalized yet" );

		airdrop2.allowClaiming();
		}
	}