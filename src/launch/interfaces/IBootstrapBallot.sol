// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;


interface IBootstrapBallot
	{
	function vote( bool voteStartExchangeYes, uint256 saltAmount, bytes calldata signature ) external;
	function finalizeBallot() external;

	function authorizeAirdrop2( uint256 saltAmount, bytes calldata signature ) external;
	function finalizeAirdrop2() external;

	// Views
	function claimableTimestamp1() external view returns (uint256);
	function claimableTimestamp2() external view returns (uint256);

	function hasVoted(address user) external view returns (bool);
	function ballotFinalized() external view returns (bool);

	function startExchangeYes() external view returns (uint256);
	function startExchangeNo() external view returns (uint256);
	}
