pragma solidity 0.8.15;

import "./GeneLogic.sol";
import "./CommonDefinitions.sol";
import "./Strings.sol";

library SVGGenerator {

    function getAdultWizardImage(uint256 _wizardId, uint256 wizardSalt, uint256 phase, uint256 totalPhases, uint256 maturityThreshold, string memory imageBaseURI) external pure returns (string memory) {
//        uint256 phase = GeneLogic.getPhaseOf(_wizardId, totalPhases);
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

        return svg;
    }
}
