Staking and rewards mechanism that allows the following:

1) Staking SALT for xSALT - which happens without delay

2) Unstaking xSALT to SALT - which requires 2-26 weeks, with less SALT being returned with less unstake time (50% at minimum 2 weeks, 100% at 26 weeks).

3) Accounts for the total xSALT on the platform and each wallet's current xSALT balance

4) Depositing xSALT or LP into pools - which will receive a share of rewards specific to that pool (proportional to share of pool deposit - either xSALT or LP)

5) Depositing generic non-pool specific SALT rewards - which will be shared by those who have staked SALT for xSALT (whether or not the xSALT has been deposited for voting)

6) Depositing pool specific SALT rewards - which will be shared by those who have deposited xSALT or LP for the specifc pool receiving rewards


The accounting mechanism for SALT rewards and xSALT or LP deposits is similar to how liquidity tokens function.

At the time of deposit, the overall rewards/deposit ratio is kept constant by noting the ratio and depositing the correct amount rewards for the given deposit.  As the user has no rewards to deposit, the deposited rewards are "borrowed" and will have to be paid back later.

At the time of withdrawal, the overall rewards/deposit ratio is examined to determine the claimable rewards for the given withdrawal size.  Borrowed rewards are deducted before the rewards are sent to the user.

A claim (without deposit withdrawal) determines claimable rewards for the users deposit balance, sends the rewards to the users, and then consider those rewards to be borrowed.  
