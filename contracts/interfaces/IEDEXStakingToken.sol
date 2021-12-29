// SPDX-License-Identifier: MIT
pragma solidity >=0.4.24;

interface IEDEXStakingToken {
    // Views
    function endStakingTime(address account) external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function canWithdraw(address account) external view returns (bool);

    function canStake(address account) external view returns (bool);

    // Mutative

    function stake(uint256 amount) external;

    function withdraw() external;
    
    function emergencyWithdraw(address _token) external;

    function exit() external;
}
