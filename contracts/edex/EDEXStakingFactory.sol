// SPDX-License-Identifier: MIT
pragma solidity ^0.6.2;
import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/IBEP20.sol";
import '@pancakeswap/pancake-swap-lib/contracts/access/Ownable.sol';

import './EDEXStakingToken.sol';

contract EDEXStakingFactory is Ownable {
    // info about rewards for a particular staking token
    struct StakingInfo {
        address stakingTokenContract;
        uint256 duration;
        uint256 baseApy;
    }

    // the staking tokens for which the contract has been deployed
    StakingInfo[] public stakingTokens;

    constructor() Ownable() public {}

    ///// permissioned functions

    // deploy a staking contract for the staking token, and store the reward duration
    function deploy(
        address stakingToken,
        uint256 duration,
        uint256 baseApy
    ) public onlyOwner {
        require(duration > 0, 'duration=0');
        address deployedContract = address(new EDEXStakingToken(stakingToken, duration, baseApy, address(this)));
        stakingTokens.push(StakingInfo(deployedContract, duration, baseApy));
    }

    function emergencyWithdraw(address _token) external onlyOwner {
        for (uint256 index = 0; index < stakingTokens.length; index++) {
            StakingInfo memory info = stakingTokens[index];
            IEDEXStakingToken(info.stakingTokenContract).emergencyWithdraw(_token);
        }
        IBEP20(_token).transfer(msg.sender, IBEP20(_token).balanceOf(address(this)));
    }
}
