# Usage guidelines

This readme explains how the staking could be used from the frontend. 

## Admin perspective

The owner of the deployed `MoonStaking` contract can configure the possible lock periods for xMOON tokens being staked. A lock period can be registered through `MoonStaking.setLockMultiplier(uint256 lockDays, uint16 multiplier)`. 

Example: If you want to give users a staking bonus of 20% if they lock for 30 days, call it with `MoonStaking.setLockMultiplier(30, 120)`. 

## uToken creator perspective

First of all anyone can create a staking pool for any token through `MoonStaking.createPool`. A created pool doesn't hurt anyone.

There should be a screen where uToken creators can deposit their uTokens for xMOON stakers. That can be done through the method `MoonStakingRewardManager.addRewardPool(IERC20 rewardToken, uint256 startTime, uint256 endTime, uint256 amount)`. It accepts timestamps for the start and end time between which the rewards should be distributed to stakers. It will be a linear distribution from start to end. 

Currently the contract requires an external trigger. We could put the trigger into other contracts that are called anyways and where gas cost is not that relevant later on.

## xMOON stakers perspective

xMOON stakers can deposit through `MoonStaking.stake(uint256 amount, uint256 lockDays, address rewardToken)` where they can get a bonus depending on the lock days. An NFT will be returned that provides the access to the staked tokens. If the NFT is transferred, so are the staked tokens.

Stakers must choose a uToken they want to stake their xMOON for.

They can withdraw their stake if the lock days have expired through the `MoonStaking.withdraw(uint256 nftId)` function. 

They can harvest their rewards any time by calling the `MoonStaking.harvest(uint256 nftId)` method.
