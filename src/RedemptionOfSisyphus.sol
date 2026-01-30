// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import { IERC1155CreatorCore } from "@manifoldxyz/creator-core-solidity/contracts/core/IERC1155CreatorCore.sol";
import { ICreatorExtensionTokenURI } from
    "@manifoldxyz/creator-core-solidity/contracts/extensions/ICreatorExtensionTokenURI.sol";
import { IERC165, ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { RedemptionOfSisyphusRenderer } from "./RedemptionOfSisyphusRenderer.sol";

/**
 * @title Redemption of Sisyphus
 * @dev This contract serves as the extension that provides custom token URI functionality and minting capabilities.
 * It works in conjunction with the RedemptionOfSisyphusRenderer contract to handle metadata rendering.
 */
contract RedemptionOfSisyphus is ICreatorExtensionTokenURI, ERC165, Ownable {
    /// @dev Reference to the renderer contract that handles metadata generation
    RedemptionOfSisyphusRenderer public metadataRenderer;

    /// @dev Address of the Manifold Creator Core contract that will mint the tokens
    address public creatorContractAddress;

    /// @dev The token ID of the minted NFT (0 if not yet minted)
    uint256 public tokenId;

    /// @dev Error thrown when attempting to mint a second token (only one token allowed)
    error AlreadyMinted();

    /**
     * @dev Constructor initializes the contract with a metadata renderer and creator contract address.
     * @param _metadataRenderer Address of the RedemptionOfSisyphusRenderer contract that will handle metadata
     * @param _creatorContractAddress Address of the Manifold Creator Core contract for minting
     */
    constructor(address _metadataRenderer, address _creatorContractAddress) Ownable() {
        metadataRenderer = RedemptionOfSisyphusRenderer(_metadataRenderer);
        creatorContractAddress = _creatorContractAddress;
    }

    /**
     * @dev Allows the owner to set a new metadata renderer.
     * @param _metadataRenderer Address of the new RedemptionOfSisyphusRenderer contract
     * This allows upgrading the metadata rendering logic while keeping the same token
     */
    function setMetadataRenderer(address _metadataRenderer) public onlyOwner {
        metadataRenderer = RedemptionOfSisyphusRenderer(_metadataRenderer);
    }

    /**
     * @dev Allows the owner to set a new creator contract address.
     * @param _creatorContractAddress Address of the new Manifold Creator Core contract
     * This allows changing which creator contract is used for minting operations
     */
    function setCreatorContractAddress(address _creatorContractAddress) public onlyOwner {
        creatorContractAddress = _creatorContractAddress;
    }

    /**
     * @dev Returns the metadata for the given token.
     * @return string The metadata URI for the token
     * This function is called by the Manifold Creator Core contract when tokenURI is requested
     */
    function tokenURI(address, uint256) external view override returns (string memory) {
        // Delegate metadata generation to the renderer contract
        return metadataRenderer.renderMetadata();
    }

    /**
     * @dev Mints a new token to the contract owner. Can only be called once.
     * This function creates the single Redemption of Sisyphus token using the Manifold Creator Core.
     * The token is minted to the owner of this contract.
     *
     * Requirements:
     * - Can only be called by the contract owner
     * - Can only be called once (tokenId must be 0)
     */
    function mint() external onlyOwner {
        // Ensure this is the first (and only) mint
        require(tokenId == 0, AlreadyMinted());

        // Prepare arrays for the Manifold mint function
        // We're minting to a single address (the owner)
        address[] memory dest = new address[](1);
        uint256[] memory quantities = new uint256[](1);
        string[] memory uris = new string[](1);

        // Set the destination to the contract owner
        dest[0] = msg.sender;

        // Mint quantity of 1
        quantities[0] = 1;

        // URI is handled by this extension, so we pass empty string

        // Call the Manifold Creator Core to mint the token
        // This returns an array of token IDs, we take the first (and only) one
        tokenId = IERC1155CreatorCore(creatorContractAddress).mintExtensionNew(dest, quantities, uris)[0];
    }

    /**
     * @dev Checks if the contract supports a given interface.
     * @param interfaceId The interface identifier to check
     * @return bool True if the interface is supported, false otherwise
     * This is required for ERC165 compliance and to register as a Creator Extension
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC165) returns (bool) {
        // Support the ICreatorExtensionTokenURI interface (required for metadata extensions)
        // and any interfaces supported by the parent ERC165 contract
        return interfaceId == type(ICreatorExtensionTokenURI).interfaceId || super.supportsInterface(interfaceId);
    }
}
