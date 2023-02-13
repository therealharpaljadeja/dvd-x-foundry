//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import "../src/levels/Unstoppable/UnstoppableVault.sol";
import "../src/levels/Unstoppable/ReceiverUnstoppable.sol";
import "../src/DamnVulnerableToken.sol";

contract UnstoppableTest is DSTest {
    address deployer = address(uint160(uint256(keccak256("DEPLOYER"))));
    address player = address(uint160(uint256(keccak256("PLAYER"))));
    address someUser = address(uint160(uint256(keccak256("SOME_USER"))));

    DamnValuableToken token;
    UnstoppableVault vault;
    ReceiverUnstoppable receiver;

    function setUp() public {}
}
