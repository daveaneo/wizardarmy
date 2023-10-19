// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "../helpers/console.sol";


import "./SVGGenerator.sol";
import "./Strings.sol";
import "./CommonDefinitions.sol";
import "./Base64.sol";

/// @title TokenURILibrary
/// @dev This library provides utility functions related to token URI generation for NFTs.
library TokenURILibrary {

    /// @notice Generates the image URI for a wizard based on its characteristics.
    /// @param _wizardId The ID of the wizard.
    /// @param wizardSalt A salt value for generating the image.
    /// @param _myPhase The phase of the wizard.
    /// @param _totalPhases The total number of phases.
    /// @param _maturityThreshold The threshold for wizard maturity.
    /// @param _imageBaseURI The base URI for images.
    /// @param uninitiated A flag indicating if the wizard is uninitiated.
    /// @param _isExiled A flag indicating if the wizard is exiled.
    /// @param _isActive A flag indicating if the wizard is active.
    /// @return imageURI The URI of the wizard's image.
    function getImageURI(
        uint256 _wizardId, 
        uint256 wizardSalt,
        uint256 _myPhase,
        uint256 _totalPhases,
        uint256 _maturityThreshold,
        string memory _imageBaseURI,
        bool uninitiated,
        bool _isExiled,
        bool _isActive
    ) external pure returns (string memory imageURI) {
        string memory linkExtension="";
        // Non-SVG images
        if (wizardSalt==0 || uninitiated || _isExiled || !_isActive || _myPhase < _maturityThreshold){
            if (wizardSalt == 0) {
                linkExtension = "placeholder";
            }
            else if (_isExiled) {
                linkExtension = "exiled";
            }
            else if (uninitiated) {
                linkExtension = "uninitiated";
            }
            else if (!_isActive) {
                linkExtension = "inactive";
            }
//            else if (_myPhase < _maturityThreshold) {
            else {
                linkExtension = Strings.toString(_myPhase); // todo -- add complexity to this linkExtension?
            }

            imageURI = string(abi.encodePacked(_imageBaseURI, "/", linkExtension, '.jpg'));
        }
        else {
            imageURI = SVGGenerator.getAdultWizardImage(_wizardId, wizardSalt, _myPhase, _totalPhases,
                                                        _maturityThreshold, _imageBaseURI, true);
        }

        return imageURI;
    }

    /// @notice Formats the token URI with given attributes.
    /// @param _wizardId The ID of the wizard.
    /// @param imageURI The image URI of the wizard.
    /// @param attributes The attributes of the wizard.
    /// @param _wizardSalt A salt value for generating the image.
    /// @return A formatted token URI string.
    function formatTokenURI(uint256 _wizardId, string memory imageURI, CommonDefinitions.WizardStats memory attributes, uint256 _wizardSalt) external pure returns (string memory) {
        string memory geneString = GeneLogic.getMagicGenesString(_wizardId, _wizardSalt);
        string memory json_str = string(abi.encodePacked(
            '{"description": "WizardArmy"',
            ', "external_url": "https://www.wizards.club"',
            ', "image": "', imageURI, '"',
            ', "name": "Wizard"',
            ', "attributes": [',
            '{"display_type": "number", "trait_type": "magic genes", "value": "', geneString, '"},',
            '{"display_type": "number", "trait_type": "role", "value": ', Strings.toString(attributes.role), '},',
            '{"display_type": "number", "trait_type": "upline id", "value": ', Strings.toString(attributes.uplineId), '},',
            '{"display_type": "number", "trait_type": "initiation timestamp", "value": ', Strings.toString(attributes.initiationTimestamp), '},',
            '{"display_type": "number", "trait_type": "protected until timestamp", "value": ', Strings.toString(attributes.protectedUntilTimestamp), '}', // no comma

            ']}'
        ));

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(json_str))));
    }

    /// @notice Converts an SVG string into an image URI.
    /// @param svg The SVG string to convert.
    /// @return The SVG string in the form of an image URI.
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
