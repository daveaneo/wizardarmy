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
import {DoubleEndedQueue} from "@openzeppelin/contracts/utils/structs/DoubleEndedQueue.sol";

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

    // include parent???
    struct Task {
        string IPFSHash; // holds description
        uint40 NFTID; // wizard ID of who is assigned task
        bytes32 hash; // hashed input to be validated
        uint8 numFieldsToHash; // input fields
        uint24 timeBonus; // increases Wizard's activation time, in seconds
//        uint8 strikes; // number of times confirmation has failed, use existence of refuterID
        uint80 payment; //
        uint16 verifierID; // wizardId of Verifier
        uint16 refuterID; // wizardId of Verifier
        uint40 verificationReservedTimestamp; // time when verification period ends
    }

    struct Proposal {
        string IPFSHash;
        uint16 numberOfOptions;
        uint16[8] votes;
        uint40 totalVotes;
        uint40 begTimestamp;
        uint40 endTimestamp;
    }



    TaskType[] public taskTypes; // we must keep task types low in quantity to avoid gas issues

    // todo -- these should be dequeues
    DoubleEndedQueue.Bytes32Deque public tasksSubmitted;
//    uint256[] public tasksVerifying; // reduce size?

//    DoubleEndedQueue.Bytes32Deque  public myQueue;

    mapping (uint256 => Proposal) public proposals;
    uint256 totalProposals;

    mapping (uint256 => Task) public tasks;
    uint256 tasksAttempted;


    uint256 verificationTime = 10*60; // 10 minutes

    event VerificationAssigned(uint256 wizardId, uint256 taskId);
    event VerificationFailed(uint256 VerifierIdFirst, uint256 VerifierIdSecond, uint256 taskId);

    /////////////////////////////
    //////  TEMP Functions ///////
    /////////////////////////////

    /*
    function getFront() view external returns ( uint256) {
        require(DoubleEndedQueue.length(myQueue)!=0, "Empty Dequeue");
        return uint256(DoubleEndedQueue.front(myQueue));
    }

    function pushFront(bytes32 _data) external {
    //  Task memory myTask = Task("0 - MYIPFSHASH", 1, keccak256(4), 3, 4, 5, 6, 7);
        DoubleEndedQueue.pushFront(myQueue,bytes32(_data));
    }
    */

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


    function claimRandomTaskForVerification(uint256 _wizID) external {
        uint256 totalTasksSubmitted = DoubleEndedQueue.length(tasksSubmitted);
        Task memory myTask;
        uint256 taskId;
        for(uint256 i =0; i < totalTasksSubmitted; ){
            if( myTask.verificationReservedTimestamp < block.timestamp && myTask.NFTID != _wizID && myTask.refuterID!= _wizID){ // todo -- make sure to start IDs at 1
                taskId = uint256(DoubleEndedQueue.at(tasksSubmitted, i));
                myTask = tasks[taskId];

                /*
                // adjust dequeue
                tasksSubmitted[0], tasksSubmitted[uint128(i)] = bytes32(0), tasksSubmitted[uint128(i)];
                tasksVerifying.push(uint256(tasksSubmitted[uint128(i)]));
                // shift head of dequeue to maintain structure (slight penalty for head)
                if (i != 0) {
                    tasksSubmitted._data[uint128(i)] = tasksSubmitted._data[tasksSubmitted.begin];
                }
                DoubleEndedQueue.pop(tasksSubmitted);
                */

                // update task
                // assign task to home boy
                myTask.verifierID = uint16(_wizID);
                myTask.verificationReservedTimestamp = uint40(block.timestamp + verificationTime);
                tasks[uint256(DoubleEndedQueue.at(tasksSubmitted, i))] = myTask;
            }
        }
        // emit event with task
        emit VerificationAssigned(_wizID, taskId);
    }

/*
        string IPFSHash; // holds description
        uint40 NFTID; // wizard ID of who is assigned task
        bytes32 hash; // hashed input to be validated
        uint8 numFieldsToHash; // input fields
        uint24 timeBonus; // increases Wizard's activation time, in seconds
        uint8 strikes; // number of times confirmation has failed
        uint80 payment; //
        uint16 verifierID; // wizardId of Verifier
        uint40 verificationReservedTimestamp; // time when verification period ends

*/

    // todo --
    function completeTask() external {
        Task memory myTask = Task("0",1, keccak256("hi"), 3, 4, 5, 6, 7, 8);
        DoubleEndedQueue.pushBack(tasksSubmitted, bytes32(tasksAttempted)); // todo -- change to dequeue
        tasks[tasksAttempted] = myTask;
        tasksAttempted+=1;
    }

    // todo -- we need to claim a random task
    // todo -- we need IPFS info, lock the task, task ID
    // todo -- troubles
    // if first verification fails, we want to avoid gaming the system where anyone can submit any code
    // arguments are apparent in blockchain and can be used to easily win reward
    function submitVerification(uint256 _wizId, uint256 _taskID, string memory _IPFSHash, bytes32[] calldata _fields) external {
        require(ecosystemNFTs.ownerOf(_wizId) == msg.sender && tasks[_taskID].verifierID==_wizId, "Must be owner of assigned wizard");

        require(_fields.length > 0);
        uint256 count = 0;
        bytes32 myHash = _fields[0]; // note -- not hashed
        for(uint256 i = 1; i < _fields.length;){
            myHash = keccak256(abi.encodePacked(myHash, _fields[i]));
            unchecked{++i;}
        }

        //
        Task storage myTask = tasks[_taskID];
        // confirm hash is correct
            // yes, no
        // yes -> remove task, release rewards
        // no  -> increase strikes, create new task

        uint256 correctHash = myTask.hash == myHash ? 1 : 0;

        if (correctHash ==1){
            // if refuterId exists, then this person gets no refund

            // release funds



            delete tasks[_taskID];
        }
        else { // if incorrect Hash


        }

        // get task ID
//        uint256 totalTasksSubmitted = DoubleEndedQueue.length(tasksSubmitted);
//        for(uint256 i =0; i < totalTasksSubmitted; ){
//            if(keccak256(bytes(tasks[uint256(DoubleEndedQueue.at(tasksSubmitted, i))].IPFSHash)) == keccak256(bytes(_IPFSHash))){ // couldn't compare storage vs memory
//                // check if hash is correct
//                if(tasks[uint256(DoubleEndedQueue.at(tasksSubmitted, i))].hash == myHash){
//                    // todo -- approve and release funds
//                    // if strikes == 1, we will split the funds
//                }
//                else {
//                    // if it doesn't match the first, we want to compare it with the other
//                }
//                // check strikes
//
//            }
//            unchecked{++i;}
//        }
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

    // top x in tower?
    modifier onlyBoard() {
        require(true,'Must be on the board'); // todo -- onlyBoard
        _;
    }





}