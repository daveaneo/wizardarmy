// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "OpenZeppelin/openzeppelin-contracts@4.6.0/contracts/token/ERC721/ERC721.sol";
//import "estarriolvetch/ERC721Psi/contracts/ERC721Psi.sol";

contract Wizards is ERC721 {
    // cull the herd and reduce to 1000?
    uint256 public totalSupply = 0;
    mapping (uint256 => Stats) public tokenIdToStats;

    enum ELEMENT {FIRE, WIND, WATER, EARTH}

    struct Stats { // todo refine and move to bitencoding
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
        require(totalSupply < contractSettings.maxSupply, "at max supply.");
        Stats memory myStats =  Stats(1, 2, 0, 0, 0, 0, 0, 0, 0, 0, ELEMENT.FIRE); // todo -- add randomness
        tokenIdToStats[totalSupply] = myStats;
        _safeMint(msg.sender, totalSupply);
        unchecked { totalSupply += 1; }
    }

    /**
     * @dev Moves NFT from inactive to active
     */
    function initiate(uint256 _tokenId) external {
        require(ownerOf(_tokenId) == msg.sender, "must be owner");
        // todo -- receive fee

        Stats storage myStats = tokenIdToStats[_tokenId];
        myStats.initiationTimestamp = block.timestamp;
        myStats.protectedUntilTimestamp = block.timestamp + contractSettings.protectionTimeExtension;
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
        return formatTokenURI(_tokenId, "https://static01.nyt.com/images/2019/02/05/world/05egg/15xp-egg-promo-superJumbo-v2.jpg");
    }

    function formatTokenURI(uint256 _tokenId, string memory imageURI) public view returns (string memory) {
//        Data memory _myData = unpackData(_tokenId);
        string memory json_str = string(abi.encodePacked(
            '{"description": "The NFT limit order that earns money!"',
            ', "external_url": "https://webuythedip.com"',
            ', "image": "',
             imageURI, '"',
            ', "name": "BuyTheDip"',
            // attributes
            ', "attributes": [{"display_type": "number", "trait_type": "Dip Level", "value": ',
            uint2str(uint256(9)),   ' }'
        ));
        json_str = string(abi.encodePacked(json_str,
            ', {"display_type": "number", "trait_type": "Strike Price", "value": ',
            uint2str(uint256(333)),   ' }',
            ', {"display_type": "number", "trait_type": "USDC Balance", "value": ',
            uint2str(uint256(111)),   ' }',
                ', {"display_type": "number", "trait_type": "Energy", "value": ',
            uint2str(uint256(222)),   ' }',
            ']', // End Attributes
            '}'
        ));
    }

    function uint2str(uint _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len - 1;
        while (_i != 0) {
            bstr[k--] = bytes1(uint8(48 + _i % 10));
            _i /= 10;
        }
        return string(bstr);
    }


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

}