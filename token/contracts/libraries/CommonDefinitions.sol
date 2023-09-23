// CommonDefinitions.sol

pragma solidity 0.8.15;

library CommonDefinitions {

    enum ELEMENT {
        FIRE,
        WATER,
        EARTH,
        AIR
    }

    struct WizardStats {
        uint16 role; // limit wizards to 1 role, which is a number --         // todo -- have role smart contract and be able to get role from here
        uint16 uplineId;  // 0 is default, 65k max?
        uint40 initiationTimestamp; // 0 if uninitiated
        uint40 protectedUntilTimestamp; // after this timestamp, NFT can be crushed
    }

    // Add any other shared enums, structs, or even constants here...

}
