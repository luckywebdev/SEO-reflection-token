// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

interface ISEOCoin {
    function balanceOf(address account) external view returns (uint256);
    
    function approve(address spender, uint256 amount) external returns (bool);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    function timeLockReleaseForPresale(address _lockAddress) external returns (bool);

    function timeLockFromPresale(address _lockAddress, uint256 _lockTime) external returns (bool);
}