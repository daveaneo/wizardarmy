// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "./GeneLogic.sol";
import "./CommonDefinitions.sol";
import "./Strings.sol";
import "./Base64.sol";


/// @title SVGGenerator
/// @notice A library for generating SVG images for Wizards based on their genes.
library SVGGenerator {

    /**
     * @notice Generates the SVG image for an adult Wizard.
     * @dev Generates an SVG based on the wizard's genes and the given phase.
     * @param _wizardId The ID of the Wizard.
     * @param wizardSalt The salt used for randomization.
     * @param phase The current phase of the Wizard.
     * @param totalPhases The total number of phases.
     * @param maturityThreshold The phase at which a Wizard is considered mature.
     * @param imageBaseURI The base URI for image assets.
     * @param dataURI Whether the result should be a data URI.
     * @return The SVG image as a string.
     */
    function getAdultWizardImage(uint256 _wizardId, uint256 wizardSalt, uint256 phase, uint256 totalPhases, uint256 maturityThreshold, string memory imageBaseURI, bool dataURI) external pure returns (string memory) {
        require(phase < totalPhases && phase >= maturityThreshold); // dev: "Invalid phase"

        // Start with the SVG header
        string memory svg = '<svg width="500" height="500" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">';

        CommonDefinitions.ELEMENT[4] memory magicGenes  = GeneLogic.getMagicGenes(_wizardId, wizardSalt);
        uint8[13] memory basicGenes  = GeneLogic.getBasicGenes(_wizardId, wizardSalt);

        // Map the magicGenes (ELEMENT enums) to their corresponding letters
        string[4] memory magicLetters = ["f", "w", "a", "e"];

        // todo -- update mapping to correct map
        string[13] memory basicPrefixes = [
            "",
            "",
            magicLetters[uint8(magicGenes[0])],
            magicLetters[uint8(magicGenes[0])],
            magicLetters[uint8(magicGenes[1])],
            magicLetters[uint8(magicGenes[1])],
            "",
            magicLetters[uint8(magicGenes[2])],
            "",
            "",
            "",
            "",
            magicLetters[uint8(magicGenes[3])]
        ];

        // Add the 13 base layers
        for (uint i = 0; i < 13; i++) {
            svg = string(abi.encodePacked(svg, '<image x="0" y="0" width="500" height="500" xlink:href="data:image/png;base64,', imageBaseURI, basicPrefixes[i], Strings.toString(basicGenes[i]), '.png" />'));
        }

        // Bonus layer if fully one element
        if ((magicGenes[0] == magicGenes[1]) && (magicGenes[1] == magicGenes[2]) && (magicGenes[2] == magicGenes[3])) {
            svg = string(abi.encodePacked(svg, '<image x="0" y="0" width="500" height="500" xlink:href="data:image/png;base64,', imageBaseURI, 'complete_element', '.png" />'));
        }

        // Close the SVG
        svg = string(abi.encodePacked(svg, '</svg>'));

        if (dataURI){
            return svgToImageURI(svg);
        }
        else{
            return svg;
        }
    }


    /**
     * @notice Converts an SVG string to a data URI format.
     * @dev Encodes the SVG to base64 if the ENCODE flag is set.
     * @param svg The SVG string to convert.
     * @return The SVG in data URI format.
     */
    function svgToImageURI(string memory svg) internal pure returns (string memory) {
        bool ENCODE = false;
        string memory baseURL = "data:image/svg+xml;base64,";

        if (!ENCODE) {
            baseURL = "data:image/svg+xml,";
            return string(abi.encodePacked(baseURL,svg));
        }

        string memory svgBase64Encoded = Base64.encode(bytes(svg));
        return string(abi.encodePacked(baseURL,svgBase64Encoded));
    }
}
