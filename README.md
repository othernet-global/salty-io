# Technical Overview
\
The Salty.IO codebase is divided up into the following folders:

**/arbitrage** - handles searching for arbitrage opportunities at user swap time -  with the actual arbitrage swaps being done within Pools.sol itself.

**/dao** - handles creating governance proposals, voting, acting on successful proposals and managing POL (Protocol Owned Liquidity). DAO adjustable parameters are stored in ~Config.sol contracts and are stored on a per folder basis.

**/launch** - handles the initial airdrop, initial distribution, and bootstrapping ballot (a decentralized vote by the airdrop recipients to start up the DEX and distribute SALT).

**/pools** - a core part of the exchange which handles liquidity pools, swaps, arbitrage, and user token deposits (which reduces gas costs for multiple trades) and which pools have contributed to recent arbitrage trades (for proportional rewards distribution).

**/price_feed** - implements a redundant price aggregator (initially using Chainlink, Uniswap v3 TWAP and Salty.IO reserves) to provide the WBTC and WETH prices used by the overcollateralized stablecoin framework.

**/rewards** - handles global SALT emissions, SALT rewards (which are sent to liquidity providers and stakers), and includes a rewards emitter mechanism (which emits a percentage of rewards over time to reduce rewards volatility).

**/stable** - includes the USDS contract and collateral functionality which allows users to deposit WBTC/WETH LP as collateral, borrow USDS (which mints it), repay USDS and allow users to liquidate undercollateralized positions.

**/staking** - implements a staking rewards mechanism which handles users receiving rewards proportional to some "userShare".  What the userShare actually represents is dependent on the contract that derives from StakingRewards.sol (namely Staking.sol which handles users staking SALT, and CollateralAndLiquidity.sol which handles users depositing collateral and liquidity).

**/** - includes the SALT token, the default AccessManager (which allows for DAO controlled geo-restriction) and the Upkeep contract (which contains a user callable performUpkeep() function that ensures proper functionality of ecosystem rewards, emissions, POL formation, etc).

\
**Dependencies**

*openzeppelin/openzeppelin-contracts@v4.9.3*

*Uniswap/v3-core@0.8* (for price feed)

*smartcontractkit/chainlink@v2.5.0*

\
**Build Instructions**

forge build

\
**Additional Resources**

Documentation: https://docs.salty.io \
In-depth Gitbook Technical Overview: https://tech.salty.io \
45 minute informal Technical Overview with Daniel Cota (originally for auditors): https://www.youtube.com/watch?v=bmAjm8J3q3Y
