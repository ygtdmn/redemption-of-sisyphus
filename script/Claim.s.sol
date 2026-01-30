// SPDX-License-Identifier: MIT
pragma solidity >=0.8.27 <0.9.0;

import { BaseScript } from "./Base.s.sol";
import { RedemptionOfSisyphusRenderer } from "../src/RedemptionOfSisyphusRenderer.sol";

contract Claim is BaseScript {
    function run() public broadcast {
        RedemptionOfSisyphusRenderer render = RedemptionOfSisyphusRenderer(0x6144C169c92D5fC9999d47CfD6ea6740F0F5c40a);
        bytes memory image = vm.readFileBinary("test/test_image.png");
        render.claimArtwork(image);
    }
}
