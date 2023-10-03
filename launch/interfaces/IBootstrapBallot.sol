// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;


interface IBootstrapBallot
	{
	function finalizeBallot() external;
	function vote( bool voteYes ) external;

	// Views
	function completionTimestamp() external returns (uint256);
	function yesVotes() external returns (uint256);
	function noVotes() external returns (uint256);
	function hasVoted(address user) external returns (bool);
	function ballotFinalized() external returns (bool);
	function ballotApproved() external returns (bool);
	}
