// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

//import "./helpers/ERC721.sol";
import "./helpers/Ownable.sol";
import "./helpers/ERC721Enumerable.sol";
import "./libraries/Strings.sol";

//import "OpenZeppelin/openzeppelin-contracts@4.6.0/contracts/token/ERC721/ERC721.sol";
//import "estarriolvetch/ERC721Psi/contracts/ERC721Psi.sol";

contract Wizards is ERC721Enumerable, Ownable {
    mapping (uint256 => Stats) public tokenIdToStats;
    address public verifier; /// contract address to update stats
    address public culler; /// contract address to exile any wizard
    address public appointer; /// contract address to assign roles

    enum ELEMENT {FIRE, WIND, WATER, EARTH}

    // note -- stack gets too deep if add more
    struct Stats { // todo -- reduce uint amount
        uint128 level;
        uint128 tokensClaimed; // maybe
        uint128 contributionKarma; // maybe
        uint16 role; // limit wizards to 1 role, which is a number
        uint16 uplineId;  // 0 is default, 65k max?
        uint40 initiationTimestamp; // 0 if uninitiated
        uint40 protectedUntilTimestamp; // after this timestamp, NFT can be crushed
        ELEMENT element;
    }

    struct ContractSettings { // todo refine, update setter
        uint256 mintCost;
        uint256 initiationCost;
        // cull the herd and reduce to 1000... 400, and so forth? total or per role?
        uint256 maxSupply;
        uint256 protectionTimeExtension;
        uint256 exileTimePenalty;
        address ecosystemTokenAddress;
        uint256 phaseDuration;
        uint256 totalPhases;
        uint256 maturityThreshold; // phase in which wizard can enter Wizard Tower
        string imageBaseURI;
    }

    ContractSettings public contractSettings;
    // 8 images????

    // 8 phases, must initiate first

    event NewVerifier(address verifier);
    event NewCuller(address culler);
    event NewAppointer(address appointer);
    event Initiated(address initiater, uint256 indexed wizardId, uint256 timestamp);
    event Exiled(address exilee, uint256 indexed wizardId, uint256 timestamp);


    ///////

    ////////////////////
    ////    Get       //
    ////////////////////

    /** @dev Check if wizard is active
      * @param _wizardId id of wizard.
      * @return true if active, false if inactive
      */
    function isActive(uint256 _wizardId) public view returns(bool) {
        require(_wizardId!=0 && _wizardId <= totalSupply(), "invalid wizard");
        return tokenIdToStats[_wizardId].protectedUntilTimestamp > block.timestamp;
    }


    /** @dev check if wizard has been exiled (temporarily banished)
      * @param _wizardId id of wizard.
      * @return true -> exiled; false -> not exiled
      */
    function isExiled(uint256 _wizardId) public view returns(bool) {
        require(_wizardId!=0 && _wizardId <= totalSupply(), "invalid wizard");
        return tokenIdToStats[_wizardId].protectedUntilTimestamp != 0 && tokenIdToStats[_wizardId].initiationTimestamp ==0;
    }

    /** @dev check if wizard has deserted and thus can be exiled
      * @param _wizardId id of wizard.
      * @return true -> deserted; false -> has not deserted
      */
    function hasDeserted(uint256 _wizardId) public view returns(bool) {
        require(_wizardId!=0 && _wizardId <= totalSupply(), "invalid wizard");
        return tokenIdToStats[_wizardId].protectedUntilTimestamp < block.timestamp && tokenIdToStats[_wizardId].initiationTimestamp ==0;
    }


    /** @dev Check if wizard is active
      * @param _wizardId id of wizard.
      * @return true if active, false if inactive
      */
    function isMature(uint256 _wizardId) public view returns(bool) {
        require(_wizardId!=0 && _wizardId <= totalSupply(), "invalid wizard");
        return getPhaseOf(_wizardId) >= contractSettings.maturityThreshold;
    }


    /** @dev Check if wizard is active
      * @param _wizardId id of wizard.
      * @return wizardId of upline
      */
    function getUplineId(uint256 _wizardId) public view returns(uint256) {
        require(_wizardId!=0 && _wizardId <= totalSupply(), "invalid wizard");
        return tokenIdToStats[_wizardId].uplineId;
    }

    function getRole(uint256 _wizardId) public view returns(uint256) {
        require(_wizardId!=0 && _wizardId <= totalSupply(), "invalid wizard");
        return tokenIdToStats[_wizardId].role;
    }


    /** @dev returns stats of wizard, potentially amplified by level or phase
      * @param _wizardId id of wizard.
      * @return stats
      */
    function getStatsGivenId(uint256 _wizardId) external view returns(Stats memory) {
        require(_wizardId!=0 && _wizardId <= totalSupply(), "invalid wizard");
        return tokenIdToStats[_wizardId];
    }


    /** @dev Returns phase of wizard
      * @param _wizardId id of wizard.
      * @return number representing phase
      */
    function getPhaseOf(uint256 _wizardId) public view returns(uint256) {
        require(_wizardId!=0 && _wizardId <= totalSupply(), "invalid wizard");
        uint256 phase =
          (block.timestamp - tokenIdToStats[_wizardId].initiationTimestamp) / contractSettings.phaseDuration
          > (contractSettings.totalPhases - 1) ? (contractSettings.totalPhases - 1) : (block.timestamp - tokenIdToStats[_wizardId].initiationTimestamp) / contractSettings.phaseDuration
          ;
        return phase;
    }


    ///////////////////////////
    ////// Core Functions /////
    ///////////////////////////
    /** @dev initiate Wizards NFT
      * @param _name name of NFT
      * @param _symbol symbol for NFT
      * @param _ERC20Address address for ecosystem token (currency)
      * @param _imageBaseURI base URI used for images
      */
    constructor(string memory _name, string memory _symbol, address _ERC20Address, string memory _imageBaseURI) ERC721(_name, _symbol) {
        contractSettings.maxSupply = 10000;
        contractSettings.initiationCost = 1;
        contractSettings.mintCost = 5; // todo -- do in less steps
        contractSettings.protectionTimeExtension = 1 days; // todo -- do in less steps
        contractSettings.ecosystemTokenAddress = _ERC20Address; // todo -- do in less steps
        contractSettings.phaseDuration = 60*60;// todo --
        contractSettings.imageBaseURI = _imageBaseURI;// todo --
        contractSettings.totalPhases = 8;
        contractSettings.maturityThreshold = 0; // todo make it 5?

        verifier = msg.sender;
        culler = msg.sender;
        appointer = msg.sender;

    }


    /** @dev check if wizard has deserted and thus can be exiled
      * @param _uplineId id of referring wizard. use 0 if no referral
      */
    function mint(uint16 _uplineId) external {
        require(totalSupply() < contractSettings.maxSupply, "at max supply.");
        require(_uplineId <= totalSupply(), "invalid upline--must be less than total supply");

        uint256 pseudoRandNum = uint256(keccak256(abi.encodePacked(totalSupply(), msg.sender, block.timestamp)));
        ELEMENT element = ELEMENT((pseudoRandNum/10*6) % 4);

        Stats memory myStats =  Stats(1, 0, 0, 0, _uplineId, 0, 0, element);
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
        // todo -- receive fee

        require(msg.value == contractSettings.initiationCost, "incorrect initiaton fee");

        Stats storage myStats = tokenIdToStats[_wizardId];
        myStats.initiationTimestamp = uint40(block.timestamp);
        myStats.protectedUntilTimestamp = uint40(block.timestamp + contractSettings.protectionTimeExtension);

        emit Initiated(msg.sender, _wizardId, block.timestamp);
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
        require(_wizardId!=0 && _wizardId <= totalSupply(), "invalid id"); // todo -- potentially restrict this further
        tokenIdToStats[_wizardId].protectedUntilTimestamp = uint40(block.timestamp); // this saves the time of exile started
        tokenIdToStats[_wizardId].initiationTimestamp = 0;
    }



//    • Uninitiated
//    • Exiled
//      Inactive
//    • "Egg"
//    • Wizard -> Can join wizard tower

    // todo -- consider adding elements to all images
    /** @dev get token URI
      * @param _wizardId id of wizard.
      * @return returns inline URI as string
      */
    function tokenURI(uint256 _wizardId) public view virtual override returns (string memory) {
        require(_exists(_wizardId), "ERC721Metadata: URI query for nonexistent token");
        // todo -- update image
        string memory linkExtension;
        if(tokenIdToStats[_wizardId].initiationTimestamp==0){ // uninitiated
            linkExtension = "uninitiated"; // todo -- shameful uninitiated picture
        }
        else if(isExiled(_wizardId)){ // exiled
            linkExtension = "exiled"; // todo -- shameful banished/exiled picture
        }
        else if(!isActive(_wizardId)){ // not protected
            linkExtension = "inactive"; // todo -- shameful, sleeping picture
        }
        else{ // todo -- this didn't use getPhaseOf
            linkExtension = Strings.toString(getPhaseOf(_wizardId));
        }
        string memory imageURI = string(abi.encodePacked(contractSettings.imageBaseURI, linkExtension, '.jpg'));
        return formatTokenURI(_wizardId, imageURI);
    }

    /** @dev format URI based on image and _wizardId
      * @param _wizardId id of wizard.
      * @param imageURI inline SVG string.
      * @return returns inline URI as string
      */
    function formatTokenURI(uint256 _wizardId, string memory imageURI) public view returns (string memory) {
        Stats memory myStats = tokenIdToStats[_wizardId];

        string memory json_str = string(abi.encodePacked(
            '{"description": "WizardArmy"',
            ', "external_url": "https://wizardarmyNFT.com (or something like this)"',
            ', "image": "',
             imageURI, '"',
            ', "name": "Wizard"',
            // attributes
            ', "attributes": [{"display_type": "number", "trait_type": "level", "value": ',
            Strings.toString(myStats.level), ' }'
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


        // use this format to add extra properties
        json_str = string(abi.encodePacked(json_str,
            ', {"display_type": "number", "trait_type": "losses", "value": ',
            Strings.toString(999),   ' }',
            ', {"display_type": "number", "trait_type": "battles", "value": ',
            Strings.toString(999),   ' }',
                ', {"display_type": "number", "trait_type": "tokensClaimed", "value": ',
            Strings.toString(myStats.tokensClaimed),   ' }'
        ));

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
        require(_wizardId!=0 && _wizardId <= totalSupply(), "invalid wizard");
        tokenIdToStats[_wizardId].role = _role;
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


}
