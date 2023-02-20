// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import "forge-std/vm.sol";
import "../src/levels/NaiveReceiver/NaiveReceiverLenderPool.sol";
import "../src/levels/NaiveReceiver/FlashLoanReceiver.sol";

contract NaiveReceiverTest is DSTest {
    uint256 constant ETHER_IN_POOL = 1000 ether;
    uint256 constant ETHER_IN_RECEIVER = 10 ether;
    Vm private constant vm = Vm(HEVM_ADDRESS);

    NaiveReceiverLenderPool pool;
    FlashLoanReceiver receiver;
    address ETH;
    address player = address(uint160(uint256(keccak256("PLAYER"))));

    function setUp() public {
        pool = new NaiveReceiverLenderPool();
        ETH = pool.ETH();
        receiver = new FlashLoanReceiver(address(pool));
        vm.deal(address(pool), 1000 ether);
        vm.deal(address(receiver), 10 ether);

        assertEq(address(pool).balance, ETHER_IN_POOL);
        assertEq(address(receiver).balance, ETHER_IN_RECEIVER);

        vm.expectRevert(0x48f5c3ed);

        receiver.onFlashLoan(
            address(this),
            ETH,
            ETHER_IN_RECEIVER,
            1 ether,
            "0x"
        );

        assertEq(address(receiver).balance, ETHER_IN_RECEIVER);
    }

    function testIsNaiveReceiverPassed() public {
        vm.startPrank(player);

        for (uint8 i = 0; i < 10; i++) {
            pool.flashLoan(receiver, ETH, 1 ether, "");
        }

        vm.stopPrank();

        assertEq(address(receiver).balance, 0);
    }
}
