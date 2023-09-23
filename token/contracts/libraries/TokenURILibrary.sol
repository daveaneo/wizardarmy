pragma solidity 0.8.15;
import "./SVGGenerator.sol";
import "./Strings.sol";
import "./CommonDefinitions.sol";

library TokenURILibrary {



    function getImageURI(
        uint256 _wizardId, 
        uint256 wizardSalt,
        uint256 _myPhase,
        uint256 _totalPhases,
        uint256 _maturityThreshold,
        string memory _imageBaseURI,
        bool uninitiated,
//        bool _exists,
        bool _isExiled,
        bool _isActive
    ) external view returns (string memory imageURI) {
//        require(_exists(_wizardId));

        string memory linkExtension="";

        if (wizardSalt == 0) { // todo -- confirm we don't need wizardSaltSet
            linkExtension = "placeholder";
        } 
        else if (uninitiated) {
            linkExtension = "uninitiated";
        } 
        else if (_isExiled) {
            linkExtension = "exiled";
        } 
        else if (_isActive) {
            linkExtension = "inactive";
        } 
        else if (_myPhase < 4) {
            linkExtension = Strings.toString(_myPhase);
        } 
        else {
            imageURI = SVGGenerator.getAdultWizardImage(_wizardId, wizardSalt, _myPhase, _totalPhases,
                _maturityThreshold, _imageBaseURI);
        }
        
        if (keccak256(abi.encodePacked(imageURI)) != 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470) {
            imageURI = string(abi.encodePacked(_imageBaseURI, linkExtension, '.jpg'));
        }
        else {
            imageURI = "NO SALT"; // todo -- have mystery image for when no salt is there
        }
        
//        return imageURI;
        return imageURI;
    }


    function formatTokenURI(uint256 _wizardId, string memory imageURI, CommonDefinitions.WizardStats memory attributes) external pure returns (string memory) {
        string memory json_str = string(abi.encodePacked(
            '{"description": "WizardArmy"',
            ', "external_url": "https://www.wizards.club"',
            ', "image": "', imageURI, '"',
            ', "name": "Wizard"',
            ', "attributes": [',
            '{"display_type": "number", "trait_type": "role", "value": ', Strings.toString(attributes.role), '},',
            '{"display_type": "number", "trait_type": "upline id", "value": ', Strings.toString(attributes.uplineId), '},',
            '{"display_type": "number", "trait_type": "initiation timestamp", "value": ', Strings.toString(attributes.initiationTimestamp), '},',
            '{"display_type": "number", "trait_type": "protected until timestamp", "value": ', Strings.toString(attributes.protectedUntilTimestamp), '},',
            ']}'
        ));

        return json_str;
    }
}