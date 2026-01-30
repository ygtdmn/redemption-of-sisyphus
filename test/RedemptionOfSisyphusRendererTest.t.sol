// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import { Test } from "forge-std/src/Test.sol";
import { RedemptionOfSisyphusRenderer } from "../src/RedemptionOfSisyphusRenderer.sol";
import { RedemptionOfSisyphus } from "../src/RedemptionOfSisyphus.sol";
import { ERC1155Mock } from "./mocks/ERC1155Mock.sol";
import { ERC1155CreatorCoreMock } from "./mocks/ERC1155CreatorCoreMock.sol";
import { console2 } from "forge-std/src/console2.sol";

contract RedemptionOfSisyphusRendererTest is Test {
    RedemptionOfSisyphus public redemptionContract;
    RedemptionOfSisyphusRenderer public renderer;
    ERC1155CreatorCoreMock public ephemeraMock;

    address public owner = address(0x1);
    address public user = address(0x2);
    address public unauthorized = address(0x3);

    string public constant BASE_METADATA =
        "\"name\": \"Redemption of Sisyphus\", \"description\": \"An AI artwork claimable by compute power.\"";
    bytes32 public imageHash;
    string public preRevealSVG;
    string public preRevealHTML;
    bytes public correctImage;

    function setUp() public {
        // Read files
        preRevealSVG = vm.readFile("display/thumbnail.svg");
        preRevealHTML = vm.readFile("display/content.html");
        correctImage = vm.readFileBinary("test/test_image.png");
        imageHash = keccak256(correctImage);

        // Deploy contracts with owner
        vm.startPrank(owner);
        ephemeraMock = new ERC1155CreatorCoreMock();
        renderer = new RedemptionOfSisyphusRenderer(BASE_METADATA, address(ephemeraMock), imageHash);
        redemptionContract = new RedemptionOfSisyphus(address(renderer), address(ephemeraMock));

        // Set up references
        renderer.setRedemptionOfSisyphus(address(redemptionContract));
        renderer.setPrerevealSVG(preRevealSVG);
        renderer.setPrerevealHTML(preRevealHTML);

        // Register extension
        ephemeraMock.registerExtension(address(redemptionContract), "");
        // Mint token to owner
        redemptionContract.mint();
        // Transfer token to renderer
        ephemeraMock.safeTransferFrom(owner, address(renderer), 1, 1, "");

        vm.stopPrank();
    }

    // ERC1155 Receiving and Rescuing Tests
    function testERC1155Receives() public returns (ERC1155Mock) {
        ERC1155Mock erc1155mock = new ERC1155Mock("");
        vm.startPrank(user);
        erc1155mock.mint(user, 1, 1, "");
        assertEq(erc1155mock.balanceOf(user, 1), 1);
        erc1155mock.safeTransferFrom(user, address(renderer), 1, 1, "");
        assertEq(erc1155mock.balanceOf(address(renderer), 1), 1);
        assertEq(erc1155mock.balanceOf(user, 1), 0);
        return erc1155mock;
    }

    function testERC1155Rescues() public {
        ERC1155Mock erc1155mock = testERC1155Receives();
        vm.startPrank(owner);
        renderer.rescueErc1155(address(erc1155mock), user, 1, 1, "");
        assertEq(erc1155mock.balanceOf(user, 1), 1);
        assertEq(erc1155mock.balanceOf(address(renderer), 1), 0);
    }

    // Claiming Tests
    function testClaimArtwork() public {
        vm.startPrank(user);
        assertEq(renderer.claimed(), false);
        vm.expectRevert(RedemptionOfSisyphusRenderer.NotRevealed.selector);
        renderer.renderRevealedMetadata();
        assertEq(ephemeraMock.balanceOf(address(renderer), 1), 1);
        assertEq(ephemeraMock.balanceOf(user, 1), 0);
        assertEq(ephemeraMock.uri(1), renderer.renderPrerevealMetadata());
        renderer.claimArtwork(correctImage);
        assertEq(renderer.claimed(), true);
        assertEq(renderer.revealedImage(), correctImage);
        assertEq(ephemeraMock.balanceOf(address(renderer), 1), 0);
        assertEq(ephemeraMock.balanceOf(user, 1), 1);
        assertEq(ephemeraMock.uri(1), renderer.renderRevealedMetadata());
        console2.log(renderer.renderRevealedImage());
    }

    function testClaimArtwork_AlreadyClaimed() public {
        testClaimArtwork();
        vm.expectRevert(RedemptionOfSisyphusRenderer.AlreadyClaimed.selector);
        renderer.claimArtwork(correctImage);
    }

    function testClaimArtwork_InvalidImageHash() public {
        vm.startPrank(user);
        assertEq(renderer.claimed(), false);
        vm.expectRevert(RedemptionOfSisyphusRenderer.NotRevealed.selector);
        renderer.renderRevealedMetadata();
        assertEq(ephemeraMock.balanceOf(address(renderer), 1), 1);
        assertEq(ephemeraMock.balanceOf(user, 1), 0);
        assertEq(ephemeraMock.uri(1), renderer.renderPrerevealMetadata());
        vm.expectRevert(RedemptionOfSisyphusRenderer.InvalidImageHash.selector);
        renderer.claimArtwork("");
    }
}
