// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "./IBootstrapBallot.sol";


interface IInitialDistribution
	{
	function distributionApproved() external;

	// Views
	function bootstrapBallot() external view returns (IBootstrapBallot);
	}
