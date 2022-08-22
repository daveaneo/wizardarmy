// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

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
    enum OUTCOME {LOSS, WIN, TIE, CAPTURE}

    // note -- stack gets too deep if add more
    struct Stats { // todo -- reduce uint amount
        uint256 level;
        uint256 hp;
        uint256 magicalPower;
        uint256 magicalDefense;
        uint256 speed;
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
        uint256 phaseDuration;
        string imageBaseURI;
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
    function isActive(uint256 _wizardId) public view returns(bool) {
        return tokenIdToStats[_wizardId].protectedUntilTimestamp > block.timestamp;
    }

    function getStatsGivenId(uint256 _wizardId) external view returns(Stats memory) {
        return tokenIdToStats[_wizardId];
    }


    ///////////////////////////
    ////// Core Functions /////
    ///////////////////////////
    constructor(string memory name_, string memory symbol_, address _address, string memory _imageBaseURI) ERC721(name_, symbol_) {
        contractSettings.maxSupply = 10000;
        contractSettings.initiationCost = 1;
        contractSettings.mintCost = 5; // todo -- do in less steps
        contractSettings.protectionTimeExtension = 1 days; // todo -- do in less steps
        contractSettings.ecosystemTokenAddress = _address; // todo -- do in less steps
        contractSettings.phaseDuration = 60*60;// todo --
        contractSettings.imageBaseURI = _imageBaseURI;// todo --
    }

    function mint() external {
        require(totalSupply() < contractSettings.maxSupply, "at max supply.");
        // todo -- randomly create stats
        //
        // hp, base = 25
        // mp base = 25

        uint256 pseudoRandNum = uint256(keccak256(abi.encodePacked(totalSupply(), msg.sender, block.timestamp)));
//        uint256 addOn = uint256(keccak256(abi.encodePacked(totalSupply(), msg.sender, block.timestamp))) % 26;
        uint256 hp = 25 + pseudoRandNum % 26;
        uint256 magicalPower = 25 + (pseudoRandNum/100) % 26;
        uint256 magicalDefense = 10 + (pseudoRandNum/10*4) % 10;
        uint256 speed = 10 + (pseudoRandNum/10*5) % 10;
        ELEMENT element = ELEMENT((pseudoRandNum/10*6) % 4);

        Stats memory myStats =  Stats(1, hp, magicalPower, magicalDefense, speed, 0, 0, 0, 0, 0, 0, 0, 0, element);
        tokenIdToStats[totalSupply()+1] = myStats;
        _safeMint(msg.sender, totalSupply()+1 ); // with with 1 as id
    }


    /**
     * @dev Moves NFT from inactive to active
     */
    function initiate(uint256 _tokenId) external {
        require(ownerOf(_tokenId) == msg.sender, "must be owner");
        require(tokenIdToStats[_tokenId].initiationTimestamp == 0, "already initiated");
        // todo -- must be beyond time limitation
        // todo -- receive fee

        Stats storage myStats = tokenIdToStats[_tokenId];
        myStats.initiationTimestamp = block.timestamp;
        myStats.protectedUntilTimestamp = block.timestamp + contractSettings.protectionTimeExtension;

        emit Initiated(msg.sender, _tokenId, block.timestamp);
    }

    function reportBattle(uint256 _attackerId, uint256 _defenderId, OUTCOME outcome, uint256 _tokensWon,
        uint256 _tokensWaged) external onlyBattler {
        if(outcome == OUTCOME.WIN){
            tokenIdToStats[_attackerId].wins += 1;
            tokenIdToStats[_defenderId].losses += 1;

        }
        else if(outcome == OUTCOME.LOSS){
            tokenIdToStats[_attackerId].losses += 1;
            tokenIdToStats[_defenderId].wins += 1;
        }

        tokenIdToStats[_attackerId].tokensClaimed += _tokensWon;

        // todo -- tokens waged?
//        tokenIdToStats[_defenderId].tokensClaimed += _tokensWon;
        // todo -- add stat for last time attacked to limit attack frequency?

        // we switched to ETH
//        if(_won==OUTCOME.LOSS) {
//            tokenIdToStats[_defenderId].tokensClaimed += _tokensWaged; // todo -- this ignores commission
//        }
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
    function verifyDuty(uint256 _tokenId, uint256 _timeReward) external onlyVerifier {
        // add time entension to NFT
        tokenIdToStats[_tokenId].protectedUntilTimestamp = _timeReward + (tokenIdToStats[_tokenId].protectedUntilTimestamp < block.timestamp
                 ? block.timestamp : tokenIdToStats[_tokenId].protectedUntilTimestamp);

        // increase stats of NFT
//        tokenIdToStats[_tokenId].tasksCompleted +=1;
    }



    /**
     * @dev uninitiate an NFT that is negligent in duties. Reward crusher
     */
    function crush(uint256 _tokenId) onlyHolder external {
    }


    function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
        require(_exists(_tokenId), "ERC721Metadata: URI query for nonexistent token");
        // todo -- update image
        string memory linkExtension;
        if(tokenIdToStats[_tokenId].initiationTimestamp==0){ // uninitiated
            linkExtension = "0"; // todo -- shameful uninitiated picture
        }
        else{
            linkExtension =
                      Strings.toString(
                      (block.timestamp - tokenIdToStats[_tokenId].initiationTimestamp) / contractSettings.phaseDuration
                      > 7 ? 7 : (block.timestamp - tokenIdToStats[_tokenId].initiationTimestamp) / contractSettings.phaseDuration
                      );
        }
        string memory imageURI = string(abi.encodePacked(contractSettings.imageBaseURI, linkExtension, '.jpg'));
        return formatTokenURI(_tokenId, imageURI);
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
            ', {"display_type": "number", "trait_type": "magical power", "value": ',
            Strings.toString(myStats.magicalPower),   ' }',
                ', {"display_type": "number", "trait_type": "magical defense", "value": ',
            Strings.toString(myStats.magicalDefense),   ' }'
        ));

        // use this format to add extra properties
        json_str = string(abi.encodePacked(json_str,
            ', {"display_type": "number", "trait_type": "speed", "value": ',
            Strings.toString(myStats.speed),   ' }',
            ', {"display_type": "number", "trait_type": "mp", "value": ',
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


    /////////////////////////////////
    ////// Admin Functions      /////
    /////////////////////////////////


    function modifyContractSettings(string memory _imageBaseURI, uint256 _phaseDuration, uint256 _protectionTimeExtension, uint256 _mintCost,
                    uint256 _initiationCost) external onlyOwner {
        contractSettings.imageBaseURI;
        contractSettings.phaseDuration;
        contractSettings.protectionTimeExtension;
        contractSettings.mintCost;
        contractSettings.initiationCost;
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