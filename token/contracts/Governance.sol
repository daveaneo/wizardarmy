pragma solidity 0.8.15;
// SPDX-License-Identifier: Unlicensed


import "./interfaces/IERC20.sol";
import "./interfaces/IERC165.sol";
import "./interfaces/IERC721.sol";
import "./interfaces/IERC721Enumerable.sol";
//import "./helpers/base64.sol";
import './helpers/ERC721A.sol';
import './helpers/ERC721.sol';
import './helpers/ERC165.sol';
import './helpers/Ownable.sol';
import './helpers/Context.sol';
import './helpers/ReentrancyGuard.sol';
import './helpers/ERC2981Collection.sol';
import './libraries/Strings.sol';
import './libraries/Address.sol';


//contract BMMultipass is ERC721Enumerable, ReentrancyGuard, Ownable {
contract Governance is ReentrancyGuard, Ownable {

//    IERC20  ecosystemTokens;
    IERC721 ecosystemNFTs;

    // the value stored here is shifted over by one because 0 means no vote, 1 means voting for slot 0
    mapping (uint256 => mapping (uint256 => uint256)) public proposalToNFTVotes;

    // used to find active tasks
    struct TaskType {
        mapping (address => uint256) lastActiveTimestamp; // for recurring tasks -- todo -- add waitTime or ...
        string IPFSHash; // holds description
        bool paused;
        uint40 proposalID; // proposal ID or 0 if task
        uint40 begTimestamp;
        uint40 endTimestamp;
        // max activity; current activity
    }

    struct Task {
        string IPFSHash; // holds description
        uint40 NFTID;
        bytes32 hash; // hashed input to be validated
        uint8 numFieldsToHash;
        uint24 timeBonus; // in seconds
        uint8 strikes;
        uint80 payment;
        address verifier;
        uint40 verificationReservedTimestamp;
    }

    struct Proposal {
        string IPFSHash;
        uint16 numberOfOptions;
        uint16[8] votes;
        uint40 totalVotes;
        uint40 begTimestamp;
        uint40 endTimestamp;
    }


    TaskType[] public taskTypes;
    Task[] public tasks;
    Task[] public tasksVerifying;

    mapping (uint256 => Proposal) public proposals;
    uint256 totalProposals;


    /////////////////////////////
    //////  Get Functions ///////
    /////////////////////////////

    function getVotes(uint256 proposalID) external view returns (uint16[] memory) {
        require(proposalID < totalProposals, "no such proposal");
        uint16[] memory voteArray = new uint16[](proposals[proposalID].numberOfOptions);
        for(uint256 i = 0; i< voteArray.length; i++){
            voteArray[i] = proposals[proposalID].votes[i];
        }
        return voteArray;
    }

    function getWinningVote(uint256 proposalID) external view returns (uint256 ) {
        require(proposalID < totalProposals, "no such proposal");
        require( block.timestamp > proposals[proposalID].endTimestamp, "voting still active"); // todo -- end voting only on time? Or, what?
        // todo -- is there a need to win by a certain percent?
        uint256 winningVote;
        uint256 winningVoteAmount;
        uint256 tie=0;
        for(uint256 i=0; i< proposals[proposalID].numberOfOptions; i++){ // start at 1 as 0 means no vote???
            if(proposals[proposalID].votes[i] > winningVoteAmount) {
                winningVoteAmount = proposals[proposalID].votes[i];
                winningVote = i;
                if (tie==1) { tie = 0;}
            }
            else if(proposals[proposalID].votes[i] == winningVoteAmount){
                tie=1;
            }
        }
        require(tie==0, "there was a tie.");
        return winningVote;
    }


    function getMyAvailableTaskTypes() external view returns (string[] memory) {
        uint256 count;
        for(uint256 i=0; i< taskTypes.length;){
            if(taskTypes[i].lastActiveTimestamp[msg.sender] < block.timestamp){ // && taskTypes[i].begTimestamp <= block.timestamp && taskTypes[i].endTimestamp > block.timestamp) {
                unchecked{++count;}
            }
            else {
                string[] memory myReturn= new string[](1);
                myReturn[0] = "No luck.";
                return myReturn;
            }
            unchecked{++i;}
        }

        string[] memory myTasks = new string[](count);
        uint256 counter = 0;
        for(uint256 i=0; i< taskTypes.length;){
            if(taskTypes[i].lastActiveTimestamp[msg.sender] < block.timestamp && taskTypes[i].begTimestamp < block.timestamp && taskTypes[i].endTimestamp > block.timestamp) {
                myTasks[i] = taskTypes[i].IPFSHash;
                unchecked{++counter;}
                if(counter >= count) {
                    break;
                }
            }
            unchecked{++i;}
        }
        return myTasks;
    }


    /////////////////////////////
    //////  Set Functions ///////
    /////////////////////////////

    function setNFTAddress(address _addy) external onlyOwner {
        ecosystemNFTs = IERC721(_addy);
    }

//    function setERC20Address(address _addy) external onlyOwner {
//        ecosystemTokens = IERC20(_addy);
//    }



    //////////////////////////////
    //////  Main Functions ///////
    //////////////////////////////

    /** @dev Constructor for HOADAO
        @param _nft -- contract address for NFTs
      */
    constructor(address _nft){
//        ecosystemTokens = IERC20(_erc20);
        ecosystemNFTs = IERC721(_nft);

//        contractSettings = ContractSettings({
//        });

    }

    // Required to receive ETH
    receive() external payable {
    }

    function vote(uint256 proposalID, uint256 NFTID, uint256 _vote) external onlyMember {
        require(proposalID < totalProposals, "no such proposal");
        require(ecosystemNFTs.ownerOf(NFTID)==msg.sender, "not owner of NFT");
        require(proposalToNFTVotes[proposalID][NFTID]==0, "already voted");
        require(_vote!=0 && _vote <= proposals[proposalID].numberOfOptions);
        require(block.timestamp < proposals[proposalID].endTimestamp);
        proposalToNFTVotes[proposalID][NFTID] = _vote + 1; // vote reference shifted by one
        proposals[proposalID].votes[_vote] += 1; // increment votes
        proposals[proposalID].totalVotes += 1;
    }

    // votes won't need to be confirmed
    function createProposal(string calldata _IPFSHash, uint16 _numberOfOptions, uint40 _begTimestamp, uint40 _endTimestamp) external onlyBoard {
        require(_numberOfOptions > 1 && _numberOfOptions < 257, "invalid number of options");
        totalProposals += 1; // keep nothing at 0
        Proposal storage myProposal = proposals[totalProposals];
            myProposal.begTimestamp = _begTimestamp;
            myProposal.endTimestamp = _endTimestamp;
            myProposal.numberOfOptions = _numberOfOptions;
            myProposal.IPFSHash = _IPFSHash;

        _createTaskType(_IPFSHash, uint40(totalProposals), _begTimestamp, _endTimestamp);
        // todo --  emit event
    }

    function createTaskType(string calldata _IPFSHash, uint40 _begTimestamp, uint40 _endTimestamp) external onlyBoard {
        _createTaskType(_IPFSHash, 0, _begTimestamp, _endTimestamp);
    }

    function _createTaskType(string calldata _IPFSHash, uint40 _proposalID, uint40 _begTimestamp, uint40 _endTimestamp) internal {
        uint256 taskTypesLength = taskTypes.length;
        taskTypes.push();
        TaskType storage newTaskType = taskTypes[taskTypesLength];
            newTaskType.IPFSHash =_IPFSHash;
            newTaskType.paused = false;
            newTaskType.proposalID = _proposalID;
            newTaskType.begTimestamp = _begTimestamp;
            newTaskType.endTimestamp = _endTimestamp;

        // todo --  emit event
    }

//        struct Task {
//        string IPFSHash; // holds description
//        uint40 NFTID;
//        bytes32 hash; // hashed input to be validated
//        uint8 numFieldsToHash;
//        uint24 timeBonus; // in seconds
//        uint8 strikes;
//        uint80 payment;
//        address verifier;
//        uint40 verificationReservedTimestamp;
//    }

    function claimRandomTaskForVerification() external {
        // issues --
        for(uint256 i = 0; i < tasks.length; i++){

        }
    }

    // todo -- we need to claim a random task
    // todo -- we need IPFS info, lock the task, task ID
    function verifyTask(uint256 _taskID, string memory _IPFSHash, bytes32[] calldata _fields) external {
        require(_fields.length > 0);
        uint256 count = 0;
        bytes32 myHash = _fields[0]; // note -- not hashed
        for(uint256 i = 1; i < _fields.length;){
            myHash = keccak256(abi.encodePacked(myHash, _fields[i]));
            unchecked{++i;}
        }
        // get task ID
        for(uint256 i =0; i < tasks.length; ){
            if(keccak256(bytes(tasks[i].IPFSHash)) == keccak256(bytes(_IPFSHash))){ // couldn't compare storage vs memory
                // check if hash is correct
                if(tasks[i].hash == myHash){
                    // todo -- approve and release funds
                    // if strikes == 1, we will split the funds
                }
                else {
                    // if it doesn't match the first, we want to compare it with the other
                }
                // check strikes

            }
            unchecked{++i;}
        }
        // verify hashes are equal
        // emit event
    }

    //////////////////////
    ////// Modifiers /////
    //////////////////////

    modifier onlyAdmin() {
        require(false,'Must be admin');
        _;
    }

    modifier onlyNFTOwner() {
        require(false,'Must be admin');
        _;
    }

    modifier onlyLessee() {
        require(false,'Must be lessee');
        _;
    }

    modifier onlyMember() { // todo -- onlyMember
        require(false,'Must be member');
        _;
    }

    modifier onlyBoard() {
        require(true,'Must be on the board'); // todo -- onlyBoard
        _;
    }





}