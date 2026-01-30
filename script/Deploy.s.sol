// SPDX-License-Identifier: MIT
pragma solidity >=0.8.27 <0.9.0;

import { BaseScript } from "./Base.s.sol";
import { RedemptionOfSisyphusRenderer } from "../src/RedemptionOfSisyphusRenderer.sol";
import { RedemptionOfSisyphus } from "../src/RedemptionOfSisyphus.sol";
import { console2 } from "forge-std/src/console2.sol";
import { ERC1155CreatorImplementation } from
    "@manifoldxyz/creator-core-solidity/contracts/ERC1155CreatorImplementation.sol";

contract Deploy is BaseScript {
    function run() public broadcast returns (RedemptionOfSisyphusRenderer renderer, RedemptionOfSisyphus artwork) {
        address ephemera = address(0xCb337152b6181683010D07e3f00e7508cd348BC7); // mainnet
        // address ephemera = address(0xBF6b69aF9a0f707A9004E85D2ce371Ceb665237B); // sepolia
        string memory metadata =
            unicode"\"name\": \"Redemption of Sisyphus\",\"description\": \"Redemption of Sisyphus, a fully on-chain, instruction-based AI artwork.\"";
        bytes memory correctImage = vm.readFileBinary("display/image_downscaled.png");
        bytes32 imageHash = keccak256(correctImage);
        console2.logBytes32(imageHash);
        renderer = new RedemptionOfSisyphusRenderer(metadata, ephemera, imageHash);
        artwork = new RedemptionOfSisyphus(address(renderer), address(ephemera));
        renderer.setRedemptionOfSisyphus(address(artwork));
        string memory preRevealSVG = vm.readFile("display/thumbnail.svg");
        string memory preRevealHTML = vm.readFile("display/content.html");
        renderer.setPrerevealSVG(preRevealSVG);
        renderer.setPrerevealHTML(preRevealHTML);
        ERC1155CreatorImplementation ephemeraImpl = ERC1155CreatorImplementation(ephemera);
        ephemeraImpl.registerExtension(address(artwork), " ");
        artwork.mint();
        ephemeraImpl.safeTransferFrom(
            address(0x28996f7DECe7E058EBfC56dFa9371825fBfa515A), address(renderer), artwork.tokenId(), 1, ""
        );
    }
}
