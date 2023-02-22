// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/vm.sol";
import "ds-test/test.sol";
import "../src/levels/TheRewarder/TheRewarderPool.sol";
import "../src/levels/TheRewarder/AccountingToken.sol";
import "../src/levels/TheRewarder/RewardToken.sol";
import {FlashLoanerPool} from "../src/levels/TheRewarder/FlashLoanerPool.sol";
import {DamnValuableToken} from "../src/DamnValuableToken.sol";
import {MiddleWare} from "../src/levels/TheRewarder/Middleware.sol";

contract TheRewarderTest is DSTest {
    Vm private constant vm = Vm(HEVM_ADDRESS);
    uint256 public constant TOKENS_IN_POOL = 1_000_000 ether;

    address deployer = address(uint160(uint256(keccak256("DEPLOYER"))));
    address player = address(uint160(uint256(keccak256("PLAYER"))));
    address alice = address(uint160(uint256(keccak256("ALICE"))));
    address bob = address(uint160(uint256(keccak256("BOB"))));
    address charlie = address(uint160(uint256(keccak256("CHARLIE"))));
    address david = address(uint160(uint256(keccak256("DAVID"))));

    address[4] users = [alice, bob, charlie, david];

    FlashLoanerPool loanPool;
    DamnValuableToken liquidityToken;
    TheRewarderPool rewarderPool;
    AccountingToken accountingToken;
    RewardToken rewardToken;

    function setUp() public {
        vm.startPrank(deployer);
        liquidityToken = new DamnValuableToken();
        loanPool = new FlashLoanerPool(address(liquidityToken));
        liquidityToken.transfer(address(loanPool), TOKENS_IN_POOL);

        rewarderPool = new TheRewarderPool(address(liquidityToken));
        rewardToken = RewardToken(rewarderPool.rewardToken());
        accountingToken = AccountingToken(rewarderPool.accountingToken());
        vm.stopPrank();
        assertEq(accountingToken.owner(), address(rewarderPool));

        uint256 minterRole = accountingToken.MINTER_ROLE();
        uint256 snapshotRole = accountingToken.SNAPSHOT_ROLE();
        uint256 burnerRole = accountingToken.BURNER_ROLE();

        assertTrue(
            accountingToken.hasAllRoles(
                address(rewarderPool),
                minterRole | snapshotRole | burnerRole
            )
        );

        uint256 depositAmount = 100 ether;

        for (uint256 i = 0; i < users.length; i++) {
            vm.startPrank(deployer);
            liquidityToken.transfer(users[i], depositAmount);
            vm.stopPrank();

            vm.startPrank(users[i]);
            liquidityToken.approve(address(rewarderPool), depositAmount);
            rewarderPool.deposit(depositAmount);
            vm.stopPrank();

            assertEq(accountingToken.balanceOf(users[i]), depositAmount);
        }

        assertEq(accountingToken.totalSupply(), depositAmount * users.length);
        assertEq(rewardToken.totalSupply(), 0);

        vm.warp(block.timestamp + 5 days);

        uint256 rewardsInRound = rewarderPool.REWARDS();
        for (uint256 i = 0; i < users.length; i++) {
            vm.startPrank(users[i]);

            rewarderPool.distributeRewards();
            assertEq(
                rewardToken.balanceOf(users[i]),
                rewardsInRound / users.length
            );

            vm.stopPrank();
        }

        assertEq(rewardToken.totalSupply(), rewardsInRound);
        assertEq(liquidityToken.balanceOf(player), 0);
        assertEq(rewarderPool.roundNumber(), 2);
    }

    function testIsTheRewarderCleared() public {
        vm.warp(block.timestamp + 5 days);
        vm.startPrank(player);

        MiddleWare mid = new MiddleWare(
            address(rewarderPool),
            address(loanPool),
            address(liquidityToken),
            address(rewardToken)
        );

        mid.borrow();

        vm.stopPrank();

        assertEq(rewarderPool.roundNumber(), 3);

        for (uint256 i = 0; i < users.length; i++) {
            vm.startPrank(users[i]);
            rewarderPool.distributeRewards();
            uint256 userReward = rewardToken.balanceOf(users[i]);
            uint256 delta = userReward -
                (rewarderPool.REWARDS() / users.length);
            assertLt(delta, 0.01 ether);
            vm.stopPrank();
        }

        assertGt(rewardToken.totalSupply(), rewarderPool.REWARDS());
        uint256 playerRewardBalance = rewardToken.balanceOf(player);
        assertGt(playerRewardBalance, 0);

        assertLt(rewarderPool.REWARDS() - playerRewardBalance, 0.1 ether);
        assertEq(liquidityToken.balanceOf(player), 0);
        assertEq(liquidityToken.balanceOf(address(loanPool)), TOKENS_IN_POOL);
    }
}
