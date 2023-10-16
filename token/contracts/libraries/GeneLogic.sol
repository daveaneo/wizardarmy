// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "./CommonDefinitions.sol";

/// @title GeneLogic
/// @notice A library for manipulating and interpreting the genes of Wizards.
library GeneLogic {

    /**
     * @notice Generates the magic genes for a given Wizard.
     * @dev Uses the keccak256 hash of the Wizard's ID and salt to generate genes.
     * @param _wizardId The ID of the Wizard.
     * @param wizardSalt The salt used for randomization.
     * @return result An array of four ELEMENT values representing the magic genes.
     */
    function getMagicGenes(uint256 _wizardId, uint256 wizardSalt) public pure returns(CommonDefinitions.ELEMENT) {
        return CommonDefinitions.ELEMENT(uint256(keccak256(abi.encodePacked(_wizardId, 'm', wizardSalt))) % 4);
    }


    // todo -- potentially add dimensions of happiness for facial expressions
    /**
     * @notice Generates the basic genes for a given Wizard.
     * @dev Uses the keccak256 hash of the Wizard's ID and salt to generate genes.
     * @param _wizardId The ID of the Wizard.
     * @param wizardSalt The salt used for randomization.
     * @return genes An array of thirteen uint8 values representing the basic genes.
     */
    function getBasicGenes(uint256 _wizardId, uint256 wizardSalt) public pure returns (uint8[13] memory) {
        uint256 pseudoRandNum = uint256(keccak256(abi.encodePacked(_wizardId, 'b', wizardSalt)));

        uint8[13] memory genes;

        for (uint i = 0; i < 13;) {
            unchecked {
                genes[i] = uint8((pseudoRandNum >> (i * 19)) % 4);
                ++i;
            }
        }

        return genes;
    }

    /**
     * @notice Gets the magic genes for a Wizard as a string.
     * @dev Transforms the magic genes into their corresponding string representations.
     * @param _wizardId The ID of the Wizard.
     * @param wizardSalt The salt used for randomization.
     * @return result A string representing the magic genes.
     */
    function getMagicGenesString(uint256 _wizardId, uint256 wizardSalt) public pure returns(string memory) {
        CommonDefinitions.ELEMENT magicGene = getMagicGenes(_wizardId, wizardSalt);

        string[4] memory elements = ["F", "W", "E", "A"];
        return string(elements[uint(magicGene)]);
    }


}
