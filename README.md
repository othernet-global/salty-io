# Technical Overview
\
The Salty.IO codebase is divided up into the following folders:


**/arbitrage** - handles creating governance proposals, voting, and acting on successful proposals. DAO adjustable parameters are stored in ~Config.sol contracts and are stored on a per folder basis.

**/dao** - handles creating governance proposals, voting, acting on successful proposals and managing POL (Protocol Owned Liquidity). DAO adjustable parameters are stored in ~Config.sol contracts and are stored on a per folder basis.

**/launch** - handles the initial airdrop, initial distribution, and bootstrapping ballot (a decentralized vote by the airdrop recipients to start up the DEX and distribute SALT).

**/pools** - a core part of the exchange which handles liquidity pools, swaps, arbitrage, and user token deposits (which reduces gas costs for multiple trades) and pools contribution to recent arbitrage trades (for proportional rewards distribution).

**/price_feed** - implements a redundant price aggregator (initially using Chainlink, Uniswap v3 TWAP and Salty.IO reserves) to provide the WBTC and WETH prices used by the overcollateralized stablecoin framework.

**/rewards** - handles global SALT emissions, SALT rewards (which are sent to liquidity providers and stakers), and includes a rewards emitter mechanism (which emits a percentage of rewards over time to reduce rewards volatility).

**/stable** - includes the USDS contract and collateral functionality which allows users to deposit WBTC/WETH LP as collateral, borrow USDS (which mints it), repay USDS and allow users to liquidate undercollateralized positions.

**/staking** - implements a staking rewards mechanism which handles users receiving rewards proportional to some "userShare".  What the userShare actually represents is dependent on the contract that derives from StakingRewards.sol (namely Staking.sol which handles users staking SALT, and Liquidity.sol which handles users depositing liquidity).

**/** - includes the SALT token, the default AccessManager (which allows for DAO controlled geo-restriction) and the Upkeep contract (which contains a user callable performUpkeep() function that ensures proper functionality of ecosystem rewards, emissions, etc).

\
**Dependencies**

*openzeppelin/openzeppelin-contracts@v4.9.3*

\
**Build Instructions**

forge build\
\
**To run unit tests**\
Note - the RPC URL needs to be a Sepolia RPC (e.g. https://rpc.sepolia.org) \
COVERAGE="yes" NETWORK="sep" forge test -vv --rpc-url https://x.x.x.x:yyy

\
**Additional Resources**

[Documentation](https://docs.salty.io) \
[In-depth Gitbook Technical Overview](https://tech.salty.io) \

\
**Audits**

[ABDK](https://github.com/abdk-consulting/audits/blob/main/othernet_global_pte_ltd/ABDK_OthernetGlobalPTELTD_SaltyIO_v_2_0.pdf) \
[Trail of Bits](https://github.com/trailofbits/publications/blob/master/reviews/2023-10-saltyio-securityreview.pdf) \
Code4rena: In progress
