// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

//import "./helpers/ERC721.sol";
import "./helpers/Ownable.sol";
import "./helpers/ERC721Enumerable.sol";
import "./libraries/Strings.sol";

//import "OpenZeppelin/openzeppelin-contracts@4.6.0/contracts/token/ERC721/ERC721.sol";
//import "estarriolvetch/ERC721Psi/contracts/ERC721Psi.sol";

contract Wizards is ERC721Enumerable, Ownable {
    // cull the herd and reduce to 1000?
//    uint256 public totalSupply = 0;
    mapping (uint256 => Stats) public tokenIdToStats;
    address public battler; /// contract address to update stats
    address public verifier; /// contract address to update stats

    enum ELEMENT {FIRE, WIND, WATER, EARTH}

    // todo -- add level (will affect dApp)
    struct Stats { // todo refine and move to bitencoding
        uint256 level;
        uint256 hp;
        uint256 mp;
        uint256 wins;
        uint256 losses;
        uint256 battles;
        uint256 tokensClaimed;
        uint256 goodness;
        uint256 badness;
        uint256 initiationTimestamp; // 0 if uninitiated
        uint256 protectedUntilTimestamp; // after this timestamp, NFT can be crushed
        ELEMENT element;
    }

    struct ContractSettings { // todo refine
        uint256 mintCost;
        uint256 initiationCost;
        uint256 maxSupply;
        uint256 protectionTimeExtension;
        address ecosystemTokenAddress;
    }

    ContractSettings public contractSettings;
    // 8 images

    // 8 phases, must initiate first

    event NewVerifier(address battler);
    event NewBattler(address verifier);
    event Initiated(address initiater, uint256 indexed wizardId, uint256 timestamp);


    ////////////////////
    ////    Get       //
    ////////////////////
    function isActive(uint256 _wizardId) public returns(bool) {
        return true; // todo isActive
    }


    ///////////////////////////
    ////// Core Functions /////
    ///////////////////////////
    constructor(string memory name_, string memory symbol_, address _address) ERC721(name_, symbol_) {
        contractSettings.maxSupply = 10000;
        contractSettings.initiationCost = 1;
        contractSettings.mintCost = 5; // todo -- do in less steps
        contractSettings.protectionTimeExtension = 1 days; // todo -- do in less steps
        contractSettings.ecosystemTokenAddress = _address; // todo -- do in less steps
    }

    function mint() external {
        require(totalSupply() < contractSettings.maxSupply, "at max supply.");
        // todo -- randomly create stats
        //
        // hp, base = 25
        // mp base = 25

        uint256 addOn = uint256(keccak256(abi.encodePacked(totalSupply(), msg.sender, block.timestamp))) % 26;
        uint256 hp = 25 + addOn;
        uint256 mp = 50 - addOn;

        ELEMENT element = ELEMENT(uint256(keccak256(abi.encodePacked(totalSupply(), msg.sender, block.timestamp+1, hp))) % 4);

        Stats memory myStats =  Stats(1, hp, mp, 0, 0, 0, 0, 0, 0, 0, 0, element);
        tokenIdToStats[totalSupply()] = myStats;
        _safeMint(msg.sender, totalSupply());
//        unchecked { totalSupply() += 1; }
    }


    /**
     * @dev Moves NFT from inactive to active
     */
    function initiate(uint256 _tokenId) external {
        require(ownerOf(_tokenId) == msg.sender, "must be owner");
        require(tokenIdToStats[_tokenId].initiationTimestamp == 0, "already initiated");
        // todo -- receive fee

        Stats storage myStats = tokenIdToStats[_tokenId];
        myStats.initiationTimestamp = block.timestamp;
        myStats.protectedUntilTimestamp = block.timestamp + contractSettings.protectionTimeExtension;

        emit Initiated(msg.sender, _tokenId, block.timestamp);
    }

    function reportBattle(uint256 _attackerId, uint256 _defenderId, uint256 _won, uint256 _tokensWon,
        uint256 _tokensWaged) external onlyBattler {
        tokenIdToStats[_attackerId].wins += _won;
        tokenIdToStats[_attackerId].losses += _won==0 ? 1 : 0;
        tokenIdToStats[_attackerId].tokensClaimed += _tokensWon;
        // todo -- tokens waged?
        tokenIdToStats[_defenderId].wins += _won==0 ? 1 : 0;
        tokenIdToStats[_defenderId].losses += _won;
        tokenIdToStats[_defenderId].tokensClaimed += _tokensWon;

        if(_won==0) {
            tokenIdToStats[_defenderId].tokensClaimed += _tokensWaged; // todo -- this ignores commission
        }
    }

    /**
     * @dev Gets phase of NFT
     */
    function getPhaseOf(uint256 _tokenId) public returns(uint256) {

    }

    /**
     * @dev check if NFT is deserted--negligent in duties.
     */
    function getIsDeserted(uint256 _tokenId) public returns(bool) {

    }

    /**
     * @dev Verify duties of NFT. Not duty specific
     */
    function verifyDuty(uint256 _tokenId) external onlyVerifier {
    }

    /**
     * @dev uninitiate an NFT that is negligent in duties. Reward crusher
     */
    function crush(uint256 _tokenId) onlyHolder external {
    }


    function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
        require(_exists(_tokenId), "ERC721Metadata: URI query for nonexistent token");
        // todo -- update image
        return formatTokenURI(_tokenId, "https://as2.ftcdn.net/v2/jpg/03/12/77/03/1000_F_312770349_4lkFN3e2UlO43kQlFemFNIpVkG5Zwytq.jpg");
    }

    function formatTokenURI(uint256 _tokenId, string memory imageURI) public view returns (string memory) {
//        Data memory _myData = unpackData(_tokenId);
        Stats memory myStats = tokenIdToStats[_tokenId];

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
            Strings.toString(myStats.hp),   ' }',
            ', {"display_type": "number", "trait_type": "mp", "value": ',
            Strings.toString(myStats.mp),   ' }',
                ', {"display_type": "number", "trait_type": "wins", "value": ',
            Strings.toString(myStats.wins),   ' }'
        ));

        // use this format to add extra properties
        json_str = string(abi.encodePacked(json_str,
            ', {"display_type": "number", "trait_type": "losses", "value": ',
            Strings.toString(myStats.losses),   ' }',
            ', {"display_type": "number", "trait_type": "battles", "value": ',
            Strings.toString(myStats.battles),   ' }',
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


    ///////////////////////////
    ////// Modifiers      /////
    ///////////////////////////

    modifier onlyVerifier() {
        require(msg.sender != address(this), 'only verifier'); // todo -- decide who will verify--one or many addresses
        _;
    }

    modifier onlyHolder() {
        require(msg.sender != address(this), 'only verifier'); // todo -- decide who will verify--one or many addresses
        _;
    }

    modifier onlyBattler() {
        require(
            msg.sender == battler,
            "Only battler can call this function."
        );
        _;
    }

    ///////////////////////////
    ////// Admin      /////
    ///////////////////////////

    function updateBattler(address _battler) external onlyOwner {
        require(_battler != address(0) && _battler != battler, "Invalid operator address");
        battler = _battler;
        emit NewBattler(_battler);
    }

    function updateVerifier(address _verifier) external onlyOwner {
        require(_verifier != address(0) && _verifier != verifier, "Invalid operator address");
        verifier = _verifier;
        emit NewVerifier(_verifier);
    }

}