// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

/// @title CommonDefinitions
/// @dev A library that provides shared definitions for the Wizard ecosystem.
library CommonDefinitions {

    /// @dev Represents the four primary magical elements of the wizards.
    enum ELEMENT {
        FIRE,   ///< Represents the fire element.
        WATER,  ///< Represents the water element.
        EARTH,  ///< Represents the earth element.
        AIR     ///< Represents the air element.
    }

    /// @dev Describes various stats and attributes related to a wizard.
    struct WizardStats {
        uint16 role; ///< Numeric representation of the wizard's role. Wizards are currently limited to one role.
        uint16 uplineId;  ///< Referral or upline ID for the wizard. Default is 0, supporting up to 65,535 wizards.
        uint40 initiationTimestamp; ///< Timestamp of wizard's initiation. A value of 0 indicates the wizard is uninitiated.
        uint40 protectedUntilTimestamp; ///< End of the wizard's protection period. Post this timestamp, the NFT can be vulnerable.
    }

}
