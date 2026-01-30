// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Base64 } from "solady/utils/Base64.sol";
import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import { ERC1155Receiver } from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Receiver.sol";
import { RedemptionOfSisyphus } from "./RedemptionOfSisyphus.sol";

/**
 * @title RedemptionOfSisyphusRenderer
 * @dev Contract for rendering metadata and SVG image.
 */
contract RedemptionOfSisyphusRenderer is Ownable, ERC1155Receiver {
    /// @dev Reference to the main RedemptionOfSisyphus contract
    RedemptionOfSisyphus public redemptionOfSisyphus;

    /// @dev Base metadata string that will be included in the final metadata JSON
    string public metadata;

    /// @dev Main Ephemera contract
    IERC1155 public ephemera;

    /// @dev Hash of the correct image that must be provided to claim the artwork
    bytes32 public imageHash;

    /// @dev SVG data used for the pre-reveal token image
    string public prerevealSVG;

    /// @dev HTML data used for the pre-reveal animation_url
    string public prerevealHTML;

    /// @dev Flag indicating whether the artwork has been claimed
    bool public claimed;

    /// @dev The revealed image data stored after successful claim
    bytes public revealedImage;

    /// @dev Error thrown when attempting to claim after artwork has already been claimed
    error AlreadyClaimed();

    /// @dev Error thrown when the provided image hash doesn't match the expected hash
    error InvalidImageHash();

    /// @dev Error thrown when attempting to render the revealed image before claiming
    error NotRevealed();

    /// @dev Event emitted when the token is successfully claimed
    /// @param claimer Address of the account that claimed the token
    event TokenClaimed(address indexed claimer);

    /**
     * @dev Constructor to initialize the contract with various parameters
     * @param _metadata Base metadata for the token (JSON format without wrapping braces)
     * @param _ephemera Main Ephemera contract
     * @param _imageHash Keccak256 hash of the correct image required for claiming
     */
    constructor(string memory _metadata, address _ephemera, bytes32 _imageHash) Ownable() {
        metadata = _metadata;
        ephemera = IERC1155(_ephemera);
        imageHash = _imageHash;
    }

    /**
     * @dev Allows a user to claim the artwork by providing the correct image
     * @param image The image data that must hash to the stored imageHash
     * Requirements:
     * - The artwork must not have been claimed already
     * - The provided image must hash to the stored imageHash
     * - The contract must hold the Ephemera token to transfer
     */
    function claimArtwork(bytes calldata image) external {
        // Check if the artwork has already been claimed
        if (claimed) revert AlreadyClaimed();

        // Verify that the provided image matches the expected hash
        if (keccak256(image) != imageHash) revert InvalidImageHash();

        // Transfer the token from this contract to the claimer
        // Uses the tokenId from the main RedemptionOfSisyphus contract
        ephemera.safeTransferFrom(address(this), msg.sender, redemptionOfSisyphus.tokenId(), 1, "");

        // Store the revealed image data for future metadata rendering
        revealedImage = image;

        // Mark the artwork as claimed to prevent future claims
        claimed = true;

        // Emit event to log the successful claim
        emit TokenClaimed(msg.sender);
    }

    /**
     * @dev Renders the pre-reveal SVG image as a data URI
     * @return string Base64 encoded data URI for the SVG image
     */
    function renderPrerevealSVG() public view returns (string memory) {
        return string(abi.encodePacked("data:image/svg+xml;base64,", Base64.encode(bytes(prerevealSVG))));
    }

    /**
     * @dev Renders the pre-reveal HTML animation as a data URI
     * @return string Base64 encoded data URI for the HTML animation
     */
    function renderPrerevealHTML() public view returns (string memory) {
        return string(abi.encodePacked("data:text/html;base64,", Base64.encode(bytes(prerevealHTML))));
    }

    /**
     * @dev Renders the revealed image as an upscaled SVG data URI
     * @return string Base64 encoded data URI for the SVG image that upscales the 32x32 PNG to 1024x1024
     * Note: Only returns valid data after the artwork has been claimed
     */
    function renderRevealedImage() public view returns (string memory) {
        if (!claimed) revert NotRevealed();

        // Create SVG that embeds the PNG with crisp pixel scaling
        string memory pngDataUri = string(abi.encodePacked("data:image/png;base64,", Base64.encode(revealedImage)));

        string memory svg = string(
            abi.encodePacked(
                "<svg width=\"1024\" height=\"1024\" xmlns=\"http://www.w3.org/2000/svg\">",
                "<image href=\"",
                pngDataUri,
                "\" width=\"1024\" height=\"1024\" image-rendering=\"pixelated\"/>",
                "</svg>"
            )
        );

        return string(abi.encodePacked("data:image/svg+xml;base64,", Base64.encode(bytes(svg))));
    }

    /**
     * @dev Renders the complete metadata JSON for the token
     * @return string The base64 encoded metadata JSON as a data URI
     * Returns different metadata depending on whether the artwork has been claimed
     */
    function renderMetadata() public view returns (string memory) {
        if (claimed) {
            return renderRevealedMetadata();
        } else {
            return renderPrerevealMetadata();
        }
    }

    /**
     * @dev Renders metadata for the revealed state (after claiming)
     * @return string Base64 encoded JSON metadata with revealed image
     */
    function renderRevealedMetadata() public view returns (string memory) {
        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                // Encode JSON object with base metadata and revealed image
                Base64.encode(abi.encodePacked("{", metadata, ", \"image\": \"", renderRevealedImage(), "\"}"))
            )
        );
    }

    /**
     * @dev Renders metadata for the pre-reveal state (before claiming)
     * @return string Base64 encoded JSON metadata with pre-reveal content
     */
    function renderPrerevealMetadata() public view returns (string memory) {
        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                // Encode JSON object with base metadata, pre-reveal image, and animation
                Base64.encode(
                    abi.encodePacked(
                        "{",
                        metadata,
                        ", \"image\": \"",
                        renderPrerevealSVG(),
                        "\", \"animation_url\": \"",
                        renderPrerevealHTML(),
                        "\"}"
                    )
                )
            )
        );
    }

    // Setter functions (onlyOwner)

    /**
     * @dev Sets the reference to the main RedemptionOfSisyphus contract
     * @param _redemptionOfSisyphus Address of the RedemptionOfSisyphus contract
     * Only callable by the contract owner
     */
    function setRedemptionOfSisyphus(address _redemptionOfSisyphus) external onlyOwner {
        redemptionOfSisyphus = RedemptionOfSisyphus(_redemptionOfSisyphus);
    }

    /**
     * @dev Sets the ERC1155 ephemera contract address
     * @param _ephemera Address of the new ERC1155 contract
     * Only callable by the contract owner
     */
    function setEphemera(address _ephemera) external onlyOwner {
        ephemera = IERC1155(_ephemera);
    }

    /**
     * @dev Updates the base metadata string
     * @param _metadata New metadata string (JSON format without wrapping braces)
     * Only callable by the contract owner
     */
    function setMetadata(string memory _metadata) external onlyOwner {
        metadata = _metadata;
    }

    /**
     * @dev Sets the pre-reveal SVG image data
     * @param _svg Raw SVG data to be used for pre-reveal image
     * Only callable by the contract owner
     */
    function setPrerevealSVG(string memory _svg) external onlyOwner {
        prerevealSVG = _svg;
    }

    /**
     * @dev Sets the pre-reveal HTML animation data
     * @param _html Raw HTML data to be used for pre-reveal animation
     * Only callable by the contract owner
     */
    function setPrerevealHTML(string memory _html) external onlyOwner {
        prerevealHTML = _html;
    }

    /**
     * @dev Updates the image hash that must be matched for claiming
     * @param _imageHash New keccak256 hash of the correct image
     * Only callable by the contract owner
     */
    function setImageHash(bytes32 _imageHash) external onlyOwner {
        imageHash = _imageHash;
    }

    // ERC1155Receiver functions

    /**
     * @dev Handles the receipt of a single ERC1155 token type
     * @return bytes4 The function selector to confirm token transfer
     * This function is called when this contract receives an ERC1155 token
     */
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    )
        external
        pure
        override
        returns (bytes4)
    {
        return bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
    }

    /**
     * @dev Handles the receipt of multiple ERC1155 token types
     * @return bytes4 The function selector to confirm token transfer
     * This function is called when this contract receives multiple ERC1155 tokens in a batch
     */
    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    )
        external
        pure
        override
        returns (bytes4)
    {
        return bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"));
    }

    /**
     * @dev Emergency function to rescue ERC1155 tokens sent to this contract
     * @param _token Address of the ERC1155 token contract
     * @param _to Address to send the rescued tokens to
     * @param _tokenId ID of the token to rescue
     * @param _amount Amount of tokens to rescue
     * @param _data Additional data for the transfer
     * Only callable by the contract owner
     */
    function rescueErc1155(
        address _token,
        address _to,
        uint256 _tokenId,
        uint256 _amount,
        bytes calldata _data
    )
        external
        onlyOwner
    {
        // Transfer the specified tokens from this contract to the specified address
        IERC1155(_token).safeTransferFrom(address(this), _to, _tokenId, _amount, _data);
    }
}
