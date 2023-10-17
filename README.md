# Technical Overview
\
The Salty.IO codebase is divided up into the following folders:

**/arbitrage** - handles searching for arbitrage opportunities at user swap time - with the actual arbitrage swaps being done within Pools.sol itself.

**/dao** - handles creating governance proposals, voting, acting on successful proposals and DAO functionality related to Upkeep (such as forming POL). DAO adjustable parameters are stored in ~Config.sol contracts and are stored on a per folder basis.

**/launch** - handles the initial airdrop, initial distribution, and bootstrapping ballot (a decentralized vote by the airdrop recipients to start up the DEX and establish the initial geo restrictions).

**/pools** - a core part of the exchange which handles liquidity pools, swaps, arbitrage, counterswaps*, and user token deposits (which reduces gas costs for subsequent trades) and keeps track of pool ratio averages and which pools have contributed to recent arbitrage trades (for proportional rewards distribution).

**/price_feed** - implements a redundant price aggregator (using Chainlink, Uniswap v3 TWAP and Salty.IO reserves) to update the WBTC and WETH prices used by the overcollateralized stablecoin logic.

**/rewards** - handles global SALT emissions, salt rewards (which are sent to liquidity providers and stakers), and includes a rewards emitter mechanism (which emits a percentage of rewards over time to reduce rewards volatility).

**/stable** - includes the USDS contract and collateral functionality which allows users to deposit WBTC/WETH LP as collateral, borrow USDS (which mints it), repay USDS and allow users to liquidate undercollateralized positions.

**/staking** - implements a staking rewards mechanism which handles users receiving rewards proportional to some "userShare". What the userShare actually represents is dependent on the contract that derives from StakingRewards.sol (namely Staking.sol which handles users staking and unstaking SALT, Liquidity.sol which handles users depositing and removing liquidity, and Collateral.sol which handles users depositing and removing WBTC/WETH LP collateral).

**/** - includes the SALT token, the default AccessManager (which allows for DAO controlled geo-restriction) and the Upkeep contract (which contains a user callable performUpkeep() function that ensures proper functionality of ecosystem rewards, emissions, POL formation, etc).

*counterswaps allow the protocol itself to swap one given token for another in a way that doesn't impact the market directly (by waiting for users to swap in the opposite direction and then swapping in the desired direction within the same transaction). Used internally for forming POL and liquidating WBTC/WETH LP rather than being accessible to users.

\
**Dependencies**

*openzeppelin/openzeppelin-contracts@v4.9.3*

*abdk-consulting/abdk-libraries-solidity@v3.2*

*Uniswap/v3-core@0.8*

*smartcontractkit/chainlink@v2.5.0*

\
**Build Instructions**

forge build
