pragma solidity 0.8.15;

import "./CommonDefinitions.sol";

library GeneLogic {

//    enum ELEMENT {FIRE, WIND, WATER, EARTH}

    function getMagicGenes(uint256 _wizardId, uint256 wizardSalt) external pure returns(CommonDefinitions.ELEMENT[4] memory) {
        uint256 myRandNum = uint256(keccak256(abi.encodePacked(_wizardId, 'm', wizardSalt)));

        CommonDefinitions.ELEMENT[4] memory result;

        for (uint i = 0; i < 4; i++) {
            uint256 value = (myRandNum >> (i * 64)) % 4; // Shift by 64 bits for each number
            result[i] = CommonDefinitions.ELEMENT(value);
        }

        return result;
    }

    function getBasicGenes(uint256 _wizardId, uint256 wizardSalt) external pure returns (uint8[13] memory) {
        uint256 pseudoRandNum = uint256(keccak256(abi.encodePacked(_wizardId, 'b', wizardSalt)));

        uint8[13] memory genes;

        for (uint i = 0; i < 13;) {
            unchecked {
                genes[i] = uint8((pseudoRandNum >> (i * 19)) % 9);
                ++i;
            }
        }

        return genes;
    }
}
