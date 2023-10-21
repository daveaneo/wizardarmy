// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "./libraries/CommonDefinitions.sol";

/// @title Reputation for Wizards.
/// @dev Computes the reputation of a wizard based on initiation and protection timestamps from the Wizards contract.
interface IWizards {
    /// @notice Fetches the stats of a given wizard.
    /// @param _wizardId The ID of the wizard whose initiation timestamp is to be fetched.
    /// @return The stats of the specified wizard.
    function getStatsGivenId(uint256 _wizardId) external view returns(CommonDefinitions.WizardStats memory);
}

contract Reputation {
    IWizards public wizardsContract;

    /// @notice Constructs the Reputation contract with a reference to the Wizards contract.
    /// @param _wizardsContractAddress The address of the deployed Wizards contract.
    constructor(address _wizardsContractAddress) {
        wizardsContract = IWizards(_wizardsContractAddress);
    }

    /// @notice Fetches the reputation of a given wizard.
    /// @dev The reputation is computed based on initiation and protection timestamps.
    /// @param wizardId The ID of the wizard whose reputation needs to be fetched.
    /// @return The reputation value of the specified wizard.
    function getReputation(uint256 wizardId) external view returns (uint256) {
        CommonDefinitions.WizardStats memory stats = wizardsContract.getStatsGivenId(wizardId);
        if (stats.initiationTimestamp == 0) {
            return 0;
        }

        // todo -- review this. I think we can just return stats.protectedUntilTimestamp - stats.initiationTimestamp;
        // we can also make it more advanced in that it always goes up. Give some for present time to initiated + half of the other:

        uint256 reputation = block.timestamp - stats.initiationTimestamp;
        if (stats.protectedUntilTimestamp > block.timestamp){
            reputation += (stats.protectedUntilTimestamp - block.timestamp)/2;
        }

        return reputation;
    }
}
