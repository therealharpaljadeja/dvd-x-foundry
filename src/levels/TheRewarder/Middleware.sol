// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {TheRewarderPool} from "./TheRewarderPool.sol";
import {FlashLoanerPool} from "./FlashLoanerPool.sol";
import {AccountingToken} from "./AccountingToken.sol";
import {RewardToken} from "./RewardToken.sol";

contract MiddleWare {
    TheRewarderPool pool;
    FlashLoanerPool loanPool;
    AccountingToken liquidityToken;
    RewardToken rewardToken;
    address owner;

    constructor(
        address _pool,
        address _loanPool,
        address _liquidityToken,
        address _rewardToken
    ) {
        owner = msg.sender;
        pool = TheRewarderPool(_pool);
        loanPool = FlashLoanerPool(_loanPool);
        liquidityToken = AccountingToken(_liquidityToken);
        rewardToken = RewardToken(_rewardToken);
    }

    function borrow() external {
        uint256 poolBalance = liquidityToken.balanceOf(address(loanPool));
        loanPool.flashLoan(poolBalance);
    }

    function receiveFlashLoan(uint256 amount) external {
        require(
            msg.sender == address(loanPool),
            "Only FlashLoanerPool can call"
        );
        liquidityToken.approve(address(pool), amount);
        pool.deposit(amount);

        pool.withdraw(amount);

        liquidityToken.transfer(msg.sender, amount);

        uint256 rewardBalance = rewardToken.balanceOf(address(this));
        rewardToken.transfer(owner, rewardBalance);
    }
}
