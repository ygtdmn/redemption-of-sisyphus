// SPDX-License-Identifier: MIT

pragma solidity >=0.8.25;

import { ERC1155Creator } from "@manifoldxyz/creator-core-solidity/contracts/ERC1155Creator.sol";

contract ERC1155CreatorCoreMock is ERC1155Creator {
    constructor() ERC1155Creator("a", "b") { }
}
