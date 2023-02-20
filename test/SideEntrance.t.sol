// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/vm.sol";
import "ds-test/test.sol";
import "../src/levels/SideEntrance/SideEntranceLenderPool.sol";
import "../src/levels/SideEntrance/FlashLoanEtherReceiver.sol";

contract SideEntranceTest is DSTest {
    Vm private constant vm = Vm(HEVM_ADDRESS);
    uint256 constant ETHER_IN_POOL = 1000 ether;
    uint256 constant PLAYER_INITIAL_ETH_BALANCE = 1 ether;

    address deployer = address(uint160(uint256(keccak256("DEPLOYER"))));
    address player = address(uint160(uint256(keccak256("PLAYER"))));

    SideEntranceLenderPool pool;

    function setUp() public {
        vm.startPrank(deployer);

        pool = new SideEntranceLenderPool();
        vm.deal(address(pool), ETHER_IN_POOL);
        assertEq(address(pool).balance, ETHER_IN_POOL);

        vm.deal(player, PLAYER_INITIAL_ETH_BALANCE);
        assertEq(player.balance, PLAYER_INITIAL_ETH_BALANCE);

        vm.stopPrank();
    }

    function testIsSideEntranceClear() public {
        vm.startPrank(player);

        FlashLoanEtherReceiver receiver = new FlashLoanEtherReceiver(
            address(pool)
        );

        receiver.attack(player);

        assertEq(address(pool).balance, 0);
        assertEq(
            address(player).balance,
            ETHER_IN_POOL + PLAYER_INITIAL_ETH_BALANCE
        );

        vm.stopPrank();
    }
}
