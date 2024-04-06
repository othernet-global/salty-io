// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "./IBootstrapBallot.sol";
import "./IAirdrop.sol";


interface IInitialDistribution
	{
	function distributionApproved( IAirdrop airdrop1, IAirdrop airdrop2 ) external;

	// Views
	function bootstrapBallot() external view returns (IBootstrapBallot);
	}
