// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

//import "./helpers/ERC721.sol";
import "./helpers/Ownable.sol";
import "./helpers/ERC721Enumerable.sol";
import "./helpers/Base64.sol";
import "./libraries/Strings.sol";

//import "OpenZeppelin/openzeppelin-contracts@4.6.0/contracts/token/ERC721/ERC721.sol";
//import "estarriolvetch/ERC721Psi/contracts/ERC721Psi.sol";

/// @title Interface for Reputation Contract
/// @dev This interface describes the functions that the reputation contract should implement.
interface IReputationContract {
    function getReputation(uint256 wizardId) external view returns (uint256);
}


contract Wizards is ERC721Enumerable, Ownable {
    mapping (uint256 => Stats) public tokenIdToStats;
    address public verifier; /// contract address to update stats
    address public culler; /// contract address to exile any wizard
    address public appointer; /// contract address to assign roles

    IReputationContract public reputationSmartContract;
    //    address taskSmartContractAddress;


    enum ELEMENT {FIRE, WIND, WATER, EARTH}

//    todo -- we can have base stats and extended stats
//    base stats will be what is located on this contract
//    extended stats will draw from other contracts
    // note -- stack gets too deep if add more
    struct Stats { // todo -- reduce uint amount
//        uint128 level; // todo -- this can liekly be changed to phase or something that continues to grow
//        uint128 tokensClaimed; // maybe -- probably best to store elsewhere
//        uint128 contributionKarma; // todo -- have reputation smart contract and be able to get reputation from here
        // todo -- have reputation smart contract and be able to get reputation from here
        uint16 role; // limit wizards to 1 role, which is a number --         // todo -- have role smart contract and be able to get role from here
        uint16 uplineId;  // 0 is default, 65k max?
        uint40 initiationTimestamp; // 0 if uninitiated
        uint40 protectedUntilTimestamp; // after this timestamp, NFT can be crushed
//        ELEMENT[4] genes; # this will be determined by the wizards properties not stored separately
    }

    struct ContractSettings { // todo refine, update setter
        uint256 mintCost; // Cost in ETH to mint NFT
        uint256 initiationCost; // Cost in ETH to initiate NFT (after minting)
        // cull the herd and reduce to 1000... 400, and so forth? total or per role?
        uint256 maxSupply; // Max supply of NFTs
        uint256 maxActiveWizards; // Max supply of NFTs that can be active
        uint256 protectionTimeExtension; //
        uint256 exileTimePenalty; // time to wait before able to reactivate
        address ecosystemTokenAddress; // address of ecoystem token
        uint256 phaseDuration; // time in seconds for each phase of wizard life
        uint256 totalPhases; // total phases for wizards -- aiming for 8
        uint256 maturityThreshold; // phase in which wizard can enter Wizard Tower
        string imageBaseURI; // base URI where images are stored
    }

    ContractSettings public contractSettings;

    // Random number for creating wizard genes
    uint256 public wizardSalt;
    bool private wizardSaltSet = false;

    event NewVerifier(address verifier);
    event NewCuller(address culler);
    event NewAppointer(address appointer);
    event Initiated(address initiater, uint256 indexed wizardId, uint256 timestamp);
    event Exiled(address exilee, uint256 indexed wizardId, uint256 timestamp);


    ////////////////////
    ////    Get       //
    ////////////////////

    /** @dev Check if wizard is active
      * @param _wizardId id of wizard.
      * @return true if active, false if inactive
      */
    function isActive(uint256 _wizardId) public view returns(bool) {
        require(_isValidWizard(_wizardId), "invalid wizard");
        return tokenIdToStats[_wizardId].protectedUntilTimestamp > block.timestamp;
    }


    /** @dev check if wizard has been exiled (temporarily banished)
      * @param _wizardId id of wizard.
      * @return true -> exiled; false -> not exiled
      */
    function isExiled(uint256 _wizardId) public view returns(bool) {
        require(_isValidWizard(_wizardId), "invalid wizard");
        return tokenIdToStats[_wizardId].protectedUntilTimestamp != 0 && tokenIdToStats[_wizardId].initiationTimestamp ==0;
    }

    /** @dev check if wizard has deserted and thus can be exiled
      * @param _wizardId id of wizard.
      * @return true -> deserted; false -> has not deserted
      */
    function hasDeserted(uint256 _wizardId) public view returns(bool) {
        require(_isValidWizard(_wizardId), "invalid wizard");
        return tokenIdToStats[_wizardId].protectedUntilTimestamp < block.timestamp && tokenIdToStats[_wizardId].initiationTimestamp ==0;
    }


    /** @dev Check if wizard is mature -- can be in wizard tower
      * @param _wizardId id of wizard.
      * @return true if active, false if inactive
      */
    function isMature(uint256 _wizardId) public view returns(bool) {
        require(_isValidWizard(_wizardId), "invalid wizard");
        return getPhaseOf(_wizardId) >= contractSettings.maturityThreshold;
    }


    /** @dev Get upline of wizard
      * @param _wizardId id of wizard.
      * @return wizardId of upline
      */
    function getUplineId(uint256 _wizardId) public view returns(uint256) {
        require(_isValidWizard(_wizardId), "invalid wizard");
        return tokenIdToStats[_wizardId].uplineId;
    }

    /** @dev Get role of wizard
      * @param _wizardId id of wizard.
      * @return wizardId of upline
      */
    function getRole(uint256 _wizardId) public view returns(uint256) {
        require(_isValidWizard(_wizardId), "invalid wizard");
        return tokenIdToStats[_wizardId].role;
    }

    /// @notice A function in Wizards that uses the reputation contract.
    /// @param _wizardId The ID of the wizard whose reputation needs to be fetched.
    /// @return The reputation value of the specified wizard.
    function getReputation(uint256 _wizardId) public view returns (uint256) {
        /// @dev Fetching the reputation from the reputation contract.
        return reputationSmartContract.getReputation(_wizardId);
    }


    /** @dev returns stats of wizard, potentially amplified by level or phase
      * @param _wizardId id of wizard.
      * @return stats
      */
    function getStatsGivenId(uint256 _wizardId) external view returns(Stats memory) {
        require(_isValidWizard(_wizardId), "invalid wizard");
        return tokenIdToStats[_wizardId];
        //todo -- extended stats
    }


    /** @dev Returns phase of wizard
      * @param _wizardId id of wizard.
      * @return number representing phase
      */
    function getPhaseOf(uint256 _wizardId) public view returns(uint256) {
        require(_isValidWizard(_wizardId), "invalid wizard");
        uint256 phase =
          (block.timestamp - tokenIdToStats[_wizardId].initiationTimestamp) / contractSettings.phaseDuration
          > (contractSettings.totalPhases - 1) ? (contractSettings.totalPhases - 1) : (block.timestamp - tokenIdToStats[_wizardId].initiationTimestamp) / contractSettings.phaseDuration
          ;
        return phase;
    }

    /** @dev Returns phase of wizard
      * @param _wizardId id of wizard.
      * @return number representing phase
      */
    function getMagicGenes(uint256 _wizardId) public view afterSaltSet returns(ELEMENT[4] memory)  {
        require(_isValidWizard(_wizardId), "invalid wizard");
        uint256 myRandNum = uint256(keccak256(abi.encodePacked(_wizardId, 'm', wizardSalt)));

        ELEMENT[4] memory result;

        for (uint i = 0; i < 4; i++) {
            uint256 value = (myRandNum >> (i * 64)) % 4; // Shift by 64 bits for each number
            result[i] = ELEMENT(value);
        }

        return result;
    }


    /**
     * @dev Returns the basic genes of a wizard.
     *
     * This function generates a pseudo-random number based on the wizard ID, a constant salt for basic genes ('b'),
     * and a global salt (wizardSalt). It then derives genes for 13 different traits, where each trait can have a
     * value between 0 and 8 (inclusive).
     *
     * @param _wizardId The ID of the wizard.
     * @return An array of 13 integers, each representing the gene for one trait. Each gene will have a value
     * between 0 and 8 (inclusive).
     */
    function getBasicGenes(uint256 _wizardId) public view returns (uint8[13] memory) {
        require(_isValidWizard(_wizardId), "Invalid wizard");

        uint256 pseudoRandNum = uint256(keccak256(abi.encodePacked(_wizardId, 'b', wizardSalt)));

        uint8[13] memory genes;
        for (uint i = 0; i < 13; i++) {
            genes[i] = uint8((pseudoRandNum >> (i * 19)) % 9);
        }

        return genes;
    }



    /**
     * @dev Checks if the given wizard ID is valid.
     * A valid wizard ID is non-zero and less than or equal to the total supply of wizards.
     *
     * @param _wizardId The ID of the wizard to be checked.
     * @return True if the wizard ID is valid, otherwise false.
     */
    function _isValidWizard(uint256 _wizardId) internal view returns (bool) {
        return _wizardId != 0 && _wizardId <= totalSupply();
    }


    ///////////////////////////
    ////// Core Functions /////
    ///////////////////////////


//    struct ContractSettings { // todo refine, update setter
//        uint256 mintCost; // Cost in ETH to mint NFT
//        uint256 initiationCost; // Cost in ETH to initiate NFT (after minting)
//        // cull the herd and reduce to 1000... 400, and so forth? total or per role?
//        uint256 maxSupply; // Max supply of NFTs
//        uint256 maxActiveWizards; // Max supply of NFTs that can be active
//        uint256 protectionTimeExtension; //
//        uint256 exileTimePenalty; // time to wait before able to reactivate
//        address ecosystemTokenAddress; // address of ecoystem token
//        uint256 phaseDuration; // time in seconds for each phase of wizard life
//        uint256 totalPhases; // total phases for wizards -- aiming for 8
//        uint256 maturityThreshold; // phase in which wizard can enter Wizard Tower
//        string imageBaseURI; // base URI where images are stored
//    }


    /**
     * @dev initiate Wizards NFT
     * @param _name name of NFT
     * @param _symbol symbol for NFT
     * @param _ERC20Address address for ecosystem token (currency)
     * @param _imageBaseURI base URI used for images
     */
    constructor(string memory _name, string memory _symbol, address _ERC20Address, string memory _imageBaseURI)
        ERC721(_name, _symbol)
    {
        contractSettings = ContractSettings({
            mintCost: 5,
            initiationCost: 10,
            maxSupply: 8192,
            maxActiveWizards: 8192,
            protectionTimeExtension: 1 days,
            exileTimePenalty: 30 days,
            ecosystemTokenAddress: _ERC20Address,
            phaseDuration: 60*60,
            totalPhases: 8,
            maturityThreshold: 0,
            imageBaseURI: _imageBaseURI
        });

        verifier = msg.sender;
        culler = msg.sender;
        appointer = msg.sender;
    }


    /**
      * @dev check if wizard has deserted and thus can be exiled
      * @param _uplineId id of referring wizard. use 0 if no referral
      */
    function mint(uint16 _uplineId) external {
        require(totalSupply() < contractSettings.maxSupply, "at max supply.");
        require(_uplineId <= totalSupply(), "invalid upline--must be less than total supply");

        Stats memory myStats =  Stats(0, _uplineId, 0, 0);
        tokenIdToStats[totalSupply()+1] = myStats;
        _safeMint(msg.sender, totalSupply()+1 ); // with with 1 as id
    }


    /** @dev Changes NFT from uninitated or exiled to initiated
      * @param _wizardId id of wizard.
      */
    function initiate(uint256 _wizardId) external payable {
        require(ownerOf(_wizardId) == msg.sender, "must be owner");
        require(tokenIdToStats[_wizardId].initiationTimestamp == 0, "already initiated");
        require(tokenIdToStats[_wizardId].protectedUntilTimestamp + contractSettings.exileTimePenalty <  block.timestamp, "Exiled wizard not yet allowed to return.");
        require(msg.value == contractSettings.initiationCost, "incorrect initiation fee");

        Stats storage myStats = tokenIdToStats[_wizardId];
        myStats.initiationTimestamp = uint40(block.timestamp);
        myStats.protectedUntilTimestamp = uint40(block.timestamp + contractSettings.protectionTimeExtension);

        emit Initiated(msg.sender, _wizardId, block.timestamp);
    }

    /**
     * @dev Resets the statistics of a given wizard by its token ID.
     * The function sets the wizard's statistics back to default values while preserving the upline ID.
     *
     * @param tokenId The ID of the wizard whose statistics are to be reset.
     */
    function _resetWizard(uint256 tokenId) internal {
        // Reset the states
        Stats memory myStats = tokenIdToStats[tokenId];
        tokenIdToStats[tokenId] = Stats(0, myStats.uplineId, 0, 0);
    }


    /** @dev exile an NFT that is negligent in duties. Use only for culling.
      * @param _wizardId id of wizard.
      */
    function cull(uint256 _wizardId) external onlyCuller {
        _exile(_wizardId);
    }

    /** @dev exile an NFT that is negligent in duties. Any address can call this, but wizard must have deserted
      * @param _wizardId id of wizard.
      */
    function exile(uint256 _wizardId) external {
        require(hasDeserted(_wizardId), "wizard can not be exiled.");
        _exile(_wizardId);
    }

    /** @dev exile an NFT that is negligent in duties. Never called by address directly, only by cull or exile
      * @param _wizardId id of wizard.
      */
    function _exile(uint256 _wizardId) internal {
        require(_wizardId!=0 && _wizardId <= totalSupply(), "invalid id");
        require(!isExiled(_wizardId), "wiz already in exile");
        tokenIdToStats[_wizardId].protectedUntilTimestamp = uint40(block.timestamp); // this saves the time of exile started
        tokenIdToStats[_wizardId].initiationTimestamp = 0;
    }



//    • Uninitiated
//    • Exiled
//      Inactive
//    • "Egg"
//    • Wizard -> Can join wizard tower


    /**
     * @dev Generates an SVG representation of an adult wizard.
     *
     * The SVG is constructed based on the genes of the wizard, and each gene
     * corresponds to an image layer in the SVG. These layers are represented
     * as base64 PNG images. The genes determine the type and order of these
     * layers, with some genes resulting in prefixed image names.
     *
     * @param _wizardId The ID of the wizard for which the SVG is to be generated.
     * @return svg The resulting SVG string representation of the wizard.
     */
    function getAdultWizardImage(uint256 _wizardId) public view returns (string memory) {
        uint256 phase = getPhaseOf(_wizardId);
        require(phase < contractSettings.totalPhases && phase >= contractSettings.maturityThreshold, "Invalid phase");

        // Start with the SVG header
        string memory svg = '<svg width="500" height="500" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">';


        ELEMENT[4] memory magicGenes  = getMagicGenes(_wizardId);
        uint8[13] memory basicGenes  = getBasicGenes(_wizardId);
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
            svg = string(abi.encodePacked(svg, '<image x="0" y="0" width="500" height="500" xlink:href="data:image/png;base64,', contractSettings.imageBaseURI, basicPrefixes[i], Strings.toString(basicGenes[i]), '.png" />'));
        }

        //        Bonus layer if fully one element
        if ((magicGenes[0] == magicGenes[1]) && (magicGenes[1] == magicGenes[2]) && (magicGenes[2] == magicGenes[3])){
            svg = string(abi.encodePacked(svg, '<image x="0" y="0" width="500" height="500" xlink:href="data:image/png;base64,', contractSettings.imageBaseURI, 'complete_element', '.png" />'));

        }

        // Close the SVG
        svg = string(abi.encodePacked(svg, '</svg>'));


        // Convert the SVG to a data URI
        string memory base64EncodedSVG = Base64.encode(bytes(svg));
        string memory dataURI = string(abi.encodePacked("data:image/svg+xml;charset=UTF-8;base64,", base64EncodedSVG));

        return dataURI;
    }

    /** @dev get token URI
      * @param _wizardId id of wizard.
      * @return returns inline URI as string
      */
    function tokenURI(uint256 _wizardId) public view virtual override returns (string memory) {
        require(_exists(_wizardId), "ERC721Metadata: URI query for nonexistent token");
        // todo -- update image
        string memory linkExtension;
        uint256 myPhase = getPhaseOf(_wizardId);

        string memory imageURI = "";

        if(!wizardSaltSet){
            linkExtension = "placeholder"; // todo -- placeholder image before random number set
        }
        else if(tokenIdToStats[_wizardId].initiationTimestamp==0){ // uninitiated
            linkExtension = "uninitiated"; // todo -- shameful uninitiated picture
        }
        else if(isExiled(_wizardId)){ // exiled
            linkExtension = "exiled"; // todo -- shameful banished/exiled picture
        }
        else if(!isActive(_wizardId)){ // not protected
            linkExtension = "inactive"; // todo -- shameful, sleeping picture
        }
        else if(myPhase<4){
            linkExtension = Strings.toString(myPhase); // todo -- shameful, sleeping picture
        }
        else{
            imageURI = getAdultWizardImage(_wizardId);
        }

        //    bytes32 constant EMPTY_STRING_HASH = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470; // keccak256 hash of ""
        if (keccak256(abi.encodePacked(imageURI)) != 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470) {
            imageURI = string(abi.encodePacked(contractSettings.imageBaseURI, linkExtension, '.jpg'));
        }

        return formatTokenURI(_wizardId, imageURI);
    }

    /** @dev format URI based on image and _wizardId
      * @param _wizardId id of wizard.
      * @param imageURI inline SVG string.
      * @return returns inline URI as string
      */
    function formatTokenURI(uint256 _wizardId, string memory imageURI) public view returns (string memory) {
//        Stats memory myStats = tokenIdToStats[_wizardId];

        string memory json_str = string(abi.encodePacked(
            '{"description": "WizardArmy"',
            ', "external_url": "https://wizardarmyNFT.com (or something like this)"',
            ', "image": "',
             imageURI, '"',
            ', "name": "Wizard"',
            // attributes
//            ', "attributes": [{"display_type": "number", "trait_type": "level", "value": ',
//            Strings.toString(myStats.level),
            ' }'
        ));

        // use this format to add extra properties
        json_str = string(abi.encodePacked(json_str,
            ', {"display_type": "number", "trait_type": "hp", "value": ',
            Strings.toString(999),   ' }',
            ', {"display_type": "number", "trait_type": "magical power", "value": ',
            Strings.toString(999),   ' }',
                ', {"display_type": "number", "trait_type": "magical defense", "value": ',
            Strings.toString(9999),   ' }'
        ));

        // use this format to add extra properties
        json_str = string(abi.encodePacked(json_str,
            ', {"display_type": "number", "trait_type": "speed", "value": ',
            Strings.toString(999),   ' }',
            ', {"display_type": "number", "trait_type": "wins", "value": ',
            Strings.toString(999),   ' }'
        ));

//
//        // use this format to add extra properties
//        json_str = string(abi.encodePacked(json_str,
//            ', {"display_type": "number", "trait_type": "losses", "value": ',
//            Strings.toString(999),   ' }',
//            ', {"display_type": "number", "trait_type": "battles", "value": ',
//            Strings.toString(999),   ' }',
//                ', {"display_type": "number", "trait_type": "tokensClaimed", "value": ',
//            Strings.toString(myStats.tokensClaimed),   ' }'
//        ));

        // end string
        json_str = string(abi.encodePacked(json_str, ']','}'));

//        string memory json_str = string(abi.encodePacked(
//            '{"description": "WizardArmy"',
//            ', "external_url": "https://wizardarmyNFT.com (or something like this)"',
//            ', "image": "',
//             imageURI, '"',
//            ', "name": "Wizard"',
//            // attributes
//            ', "attributes": [{"display_type": "number", "trait_type": "level", "value": ',
//            '11111111',   ' }'
//        ));
//        json_str = string(abi.encodePacked(json_str,
//            ', {"display_type": "number", "trait_type": "hp", "value": ',
//            '2222222222',   ' }',
//            ', {"display_type": "number", "trait_type": "mp", "value": ',
//            '33333333333333333',   ' }',
//                ', {"display_type": "number", "trait_type": "wins", "value": ',
//            '4444444444',   ' }',
//            ']', // End Attributes
//            '}'
//        ));
        return json_str;
    }

//    function uint2str(uint _i) internal pure returns (string memory _uintAsString) {
//        if (_i == 0) {
//            return "0";
//        }
//        uint j = _i;
//        uint len;
//        while (j != 0) {
//            len++;
//            j /= 10;
//        }
//        bytes memory bstr = new bytes(len);
//        uint k = len - 1;
//        while (_i != 0) {
//            bstr[k--] = bytes1(uint8(48 + _i % 10));
//            _i /= 10;
//        }
//        return string(bstr);
//    }


    //    todo -- make an actual random number generator with chainlink
    function setRandomNumber(uint256 _wizardSalt) external afterSaltSet onlyOwner {
        wizardSalt = _wizardSalt;
        wizardSaltSet = true;
    }


    ///////////////////////////////////
    ////// Verifier Functions     /////
    ///////////////////////////////////

    /** @dev increase protectionTimestamp, called by verifier. Used to keep wizard from being exiled.
      * @param _wizardId id of wizard.
      * @param _timeReward amout of time in seconds to add to current protectedUntilTimestamp
      */
    function increaseProtectedUntilTimestamp(uint256 _wizardId, uint40 _timeReward) external onlyVerifier {
        require(_wizardId!=0 && _wizardId <= totalSupply(), "invalid id");
        require(tokenIdToStats[_wizardId].initiationTimestamp!=0, "is not initiated");
        tokenIdToStats[_wizardId].protectedUntilTimestamp += _timeReward;
    }


    ////////////////////////////////////
    ////// Appointer Functions     /////
    ////////////////////////////////////

    function appointRole(uint256 _wizardId, uint16 _role) external onlyAppointer {
        require(_isValidWizard(_wizardId), "invalid wizard");
        tokenIdToStats[_wizardId].role = _role;
    }



    ////////////////////////////////////
    ////// Override Functions     /////
    ////////////////////////////////////

    function transferFrom(address from, address to, uint256 tokenId) public override(ERC721, IERC721)  {
        // Call the parent contract's implementation of transferFrom
        super.transferFrom(from, to, tokenId);

        // Reset the states of the wizard after transfer
        _resetWizard(tokenId);
    }

    /////////////////////////////////
    ////// Admin Functions      /////
    /////////////////////////////////


    /** @dev modify contract settings. Only available to owner
      * @param _imageBaseURI baseURI for images
      * @param _phaseDuration period in seconds for phases
      * @param _protectionTimeExtension problby remove this // todo -- delete
      * @param _initiationCost cost in ETH to initiate
      */
    function modifyContractSettings(string memory _imageBaseURI, uint256 _phaseDuration, uint256 _protectionTimeExtension, uint256 _mintCost,
                    uint256 _initiationCost, uint256 _maturityThreshold) external onlyOwner {
        contractSettings.imageBaseURI = _imageBaseURI;
        contractSettings.phaseDuration = _phaseDuration;
        contractSettings.protectionTimeExtension = _protectionTimeExtension;
        contractSettings.mintCost = _mintCost;
        contractSettings.initiationCost = _initiationCost;
        contractSettings.maturityThreshold = _maturityThreshold;
    }


    /// @notice Sets the address of the reputation contract.
    /// @dev Can only be called by the owner of the Wizards contract.
    /// @param _reputationContractAddress The address of the reputation contract.
    function setReputationSmartContract(address _reputationContractAddress) external onlyOwner {
        reputationSmartContract = IReputationContract(_reputationContractAddress);
    }


    ///////////////////////////
    ////// Modifiers      /////
    ///////////////////////////

    modifier onlyVerifier() {
        require(msg.sender == verifier, 'only verifier'); // todo -- decide who will verify--one or many addresses
        _;
    }

    modifier onlyAppointer() {
        require(msg.sender == appointer, 'only appointer');
        _;
    }


    modifier onlyHolder() {
        require(msg.sender != address(this), 'only holder'); // todo -- decide who will verify--one or many addresses
        _;
    }

    modifier onlyCuller() {
        require(
            msg.sender == culler, // todo -- one or many addresses?
            "Only culler can call this function."
        );
        _;
    }


    modifier afterSaltSet() {
        require(!wizardSaltSet, "Number is already set");
        _;
    }


    ///////////////////////////
    ////// Admin      /////
    ///////////////////////////

    /** @dev increase protectionTimestamp, called by verifier. Used to keep wizard from being exiled.
      * @param _culler new address for culler, the wallet/contract which can exile wizards without contraint
      */
    function updateCuller(address _culler) external onlyOwner {
        require(_culler != address(0) && _culler != culler, "Invalid operator address");
        culler = _culler;
        emit NewCuller(_culler);
    }

    /** @dev increase protectionTimestamp, called by verifier. Used to keep wizard from being exiled.
      * @param _verifier the new address for verifier, the contract which can add protectedUntil time for wizards
      */
    function updateVerifier(address _verifier) external onlyOwner {
        require(_verifier != address(0) && _verifier != verifier, "Invalid operator address");
        verifier = _verifier;
        emit NewVerifier(_verifier);
    }

    /** @dev increase protectionTimestamp, called by verifier. Used to keep wizard from being exiled.
      * @param _appointer the new address for appointer, the contract which can appoint and create roles
      */
    function updateAppointer(address _appointer) external onlyOwner {
        require(_appointer != address(0) && _appointer != appointer, "Invalid operator address");
        appointer = _appointer;
        emit NewAppointer(_appointer);
    }

    // Allows the contract owner to withdraw the accumulated fees
    function withdraw() external onlyOwner {
        address payable recipient = payable(owner());
        recipient.transfer(address(this).balance);
    }

}
