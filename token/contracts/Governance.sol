pragma solidity 0.8.15;
// SPDX-License-Identifier: Unlicensed

import "./wizards.sol";
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
    Wizards wizardsNFT;

    // the value stored here is shifted over by one because 0 means no vote, 1 means voting for slot 0
    mapping (uint256 => mapping (uint256 => uint256)) public proposalToNFTVotes;

    // used to find active tasks
    struct TaskType {
        mapping (address => uint256) lastActiveTimestamp; // for recurring tasks -- todo -- add waitTime or ...
        string IPFSHash; // holds description
        bool paused;
        uint40 proposalID; // proposal ID or 0 if task
        uint8 numFieldsToHash;
        uint24 timeBonus;
        uint40 begTimestamp;
        uint40 endTimestamp;
        uint16 availableSlots;
    }

    // include parent???
    struct Task {
        string IPFSHash; // holds description
        uint40 NFTID; // wizard ID of who is assigned task
        bytes32 hash; // hashed input to be validated
        bytes32 refuterHash; // correct hash according to refuter
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

    // todo -- Adjustable
    uint256 verificationTime = 10*60; // 10 minutes
    uint256 taskVerificationTimeBonus = 1 days; // 1 day


    event VerificationAssigned(uint256 wizardId, uint256 taskId);
    event VerificationFailed(uint256 VerifierIdFirst, uint256 VerifierIdSecond, uint256 taskId);
    event VerificationSucceeded(uint256 taskDoer, uint256 Verifier, uint256 taskId, bytes32 hash, bool isHashCorrect);
    event HashTesting(bytes32 hash, bool isHashCorrect, bytes32 firstEncoded, bytes firstUnencoded);
    event NewTaskTypeCreated(string _IPFSHash,uint40 _proposalID, uint8 _numFieldsToHash, uint24 _timeBonus,
          uint40 _begTimestamp, uint40 _endTimestamp, uint16 _availableSlots);

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

/*
// todo -- delete this helper function
    function getTaskTypeFields(uint256 _id) external view returns (uint8 ) {
        return taskTypes[_id].numFieldsToHash;
    }
*/
    function getTaskById(uint256 _taskId) external view returns (Task memory) {
        return tasks[_taskId];
    }

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

    // todo -- see if we need to include IDs here -- may not need to
    function getMyAvailableTaskTypes() external view returns (string[] memory) {
        uint256 count;
        for(uint256 i=0; i< taskTypes.length;){
            if(taskTypes[i].lastActiveTimestamp[msg.sender] < block.timestamp
            && taskTypes[i].begTimestamp <= block.timestamp && taskTypes[i].endTimestamp > block.timestamp
            && taskTypes[i].availableSlots > 1
            ) {
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
            if(taskTypes[i].lastActiveTimestamp[msg.sender] < block.timestamp
            && taskTypes[i].begTimestamp <= block.timestamp && taskTypes[i].endTimestamp > block.timestamp
            && taskTypes[i].availableSlots > 1
            ) {
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
        wizardsNFT = Wizards(_addy);
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
        wizardsNFT = Wizards(_nft);

//        contractSettings = ContractSettings({
//        });

    }

    // Required to receive ETH
    receive() external payable {
    }

    function vote(uint256 proposalID, uint256 NFTID, uint256 _vote) external onlyMember {
        require(proposalID < totalProposals, "no such proposal");
        require(wizardsNFT.ownerOf(NFTID)==msg.sender, "not owner of NFT");
        require(proposalToNFTVotes[proposalID][NFTID]==0, "already voted");
        require(_vote!=0 && _vote <= proposals[proposalID].numberOfOptions);
        require(block.timestamp < proposals[proposalID].endTimestamp);
        proposalToNFTVotes[proposalID][NFTID] = _vote + 1; // vote reference shifted by one
        proposals[proposalID].votes[_vote] += 1; // increment votes
        proposals[proposalID].totalVotes += 1;
    }

    // votes won't need to be confirmed
    function createProposal(string calldata _IPFSHash, uint16 _numberOfOptions, uint24 _timeBonus, uint40 _begTimestamp, uint40 _endTimestamp, uint16 _availableSlots) external onlyBoard {
        require(_numberOfOptions > 1 && _numberOfOptions < 257, "invalid number of options");
        totalProposals += 1; // keep nothing at 0
        Proposal storage myProposal = proposals[totalProposals];
            myProposal.begTimestamp = _begTimestamp;
            myProposal.endTimestamp = _endTimestamp;
            myProposal.numberOfOptions = _numberOfOptions;
            myProposal.IPFSHash = _IPFSHash;

        _createTaskType(_IPFSHash, uint40(totalProposals), 0, _timeBonus, _begTimestamp, _endTimestamp, _availableSlots);
        // todo --  emit event
    }


    function createTaskType(string calldata _IPFSHash, uint8 _numFieldsToHash, uint24 _timeBonus, uint40 _begTimestamp,
                uint40 _endTimestamp, uint16 _availableSlots) external onlyBoard {
        _createTaskType(_IPFSHash, 0, _numFieldsToHash, _timeBonus, _begTimestamp, _endTimestamp, _availableSlots);
    }

    function _createTaskType(string calldata _IPFSHash, uint40 _proposalID, uint8 _numFieldsToHash, uint24 _timeBonus,
             uint40 _begTimestamp, uint40 _endTimestamp, uint16 _availableSlots) internal {
        uint256 taskTypesLength = taskTypes.length;
        taskTypes.push();
        TaskType storage newTaskType = taskTypes[taskTypesLength];
            newTaskType.IPFSHash =_IPFSHash;
            newTaskType.paused = false;
            newTaskType.proposalID = _proposalID;
            newTaskType.numFieldsToHash = _numFieldsToHash;
            newTaskType.timeBonus = _timeBonus;
            newTaskType.begTimestamp = _begTimestamp;
            newTaskType.endTimestamp = _endTimestamp;
            newTaskType.availableSlots = _availableSlots;
        // todo --  emit event
        emit NewTaskTypeCreated(_IPFSHash, _proposalID, _numFieldsToHash, _timeBonus, _begTimestamp, _endTimestamp, _availableSlots);
    }


    function claimRandomTaskForVerification(uint256 _wizID) external {
        uint256 totalTasksSubmitted = DoubleEndedQueue.length(tasksSubmitted);
        Task memory myTask;
        uint256 taskId;
        // todo --implement randomness
//        uint256[25] memory potentialTasks;
        for(uint256 i =0; i < totalTasksSubmitted; ){
            if( myTask.verificationReservedTimestamp < block.timestamp && myTask.NFTID != _wizID && myTask.refuterID!= _wizID){ // todo -- make sure to start IDs at 1
//                potentialTasks.push(uint256(DoubleEndedQueue.at(tasksSubmitted, i)));
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
        bytes32 refuterHash; // correct hash according to refuter
        uint8 numFieldsToHash; // input fields
        uint24 timeBonus; // increases Wizard's activation time, in seconds
        uint80 payment; //
        uint16 verifierID; // wizardId of Verifier
        uint16 refuterID; // wizardId of Verifier
        uint40 verificationReservedTimestamp; // time when verification period ends

*/
    function completeTask(string memory _IPFSHash, bytes32 _hash, uint40 _wizID) external {
        // IPFS, hash, wizardID

        // find the task type -- can't be too many
        for(uint256 i = 0; i<taskTypes.length; i++){
            if(keccak256(abi.encode(taskTypes[i].IPFSHash)) == keccak256(abi.encode(_IPFSHash))){ // hashed to compare
                // verify it is viable
                require(taskTypes[i].begTimestamp <= block.timestamp && block.timestamp <= taskTypes[i].endTimestamp, "Outside time period");
                // create new task
                Task memory myTask = Task(_IPFSHash,_wizID, _hash, 0, taskTypes[i].numFieldsToHash, taskTypes[i].timeBonus, 0, 0, 0, 0);
                DoubleEndedQueue.pushBack(tasksSubmitted, bytes32(tasksAttempted));
                tasks[tasksAttempted] = myTask;
                tasksAttempted+=1;
            }
        }
    }

    function testHashing(bytes32 _givenHash, bytes32[] memory _fields, bool _refuted) external {
        bytes memory unencoded = abi.encodePacked(_fields[0]);
        if(_refuted) {
            for(uint256 i = 0; i < _fields.length;){
                _fields[i] = keccak256(abi.encodePacked(_fields[i]));
                unchecked{++i;}
            }
        }
        bytes32 myHash = keccak256(abi.encodePacked(_fields));
        emit HashTesting(myHash, myHash==_givenHash, _fields[0], unencoded);
    }

// working for regular but not refuted.
//    function testHashing(bytes32 _givenHash, bytes32[] memory _fields, bool _refuted) external {
//        bytes memory unencoded = abi.encodePacked(_fields[0]);
//        if(_refuted) {
//            for(uint256 i = 0; i < _fields.length;){
//                _fields[i] = keccak256(abi.encodePacked(_fields[i]));
//                unchecked{++i;}
//            }
//        }
//        bytes32 myHash = keccak256(abi.encodePacked(_fields));
//        emit HashTesting(myHash, myHash==_givenHash, _fields[0], unencoded);
//    }



    // @dev -- hash structure: leaves of merkle tree are hashed. Unrefuted tasks must send in hashed leafs. Refuted, unhashed.
    function submitVerification(uint256 _wizId, uint256 _taskID, bytes32[] memory _fields) external {
    //todo -- uncomment out requirement (testing)
        require(wizardsNFT.ownerOf(_wizId) == msg.sender && tasks[_taskID].verifierID==_wizId, "Must be owner of assigned wizard");
        require(_fields.length > 0);

        Task storage myTask = tasks[_taskID];
        uint256 count = 0;

        // hash leaf if refuter exists
        // todo -- redo our hashes as we are hashing not same throughout

//        bytes32 myHash = myTask.refuterID > 0 ? keccak256(abi.encodePacked(_fields[0])) : _fields[0] ; // note -- not hashed
//        for(uint256 i = 0; i < _fields.length;){
//            myHash = keccak256(abi.encodePacked(myHash, myTask.refuterID > 0 ? keccak256(abi.encodePacked(_fields[i])) : _fields[i]));
//            unchecked{++i;}
//        }

        // hash leaves if there is a refuter
        if(myTask.refuterID > 0) {
            for(uint256 i = 0; i < _fields.length;){
                _fields[i] = keccak256(abi.encodePacked(_fields[i]));
                unchecked{++i;}
            }
        }
        bytes32 myHash = keccak256(abi.encodePacked(_fields));

        uint256 correctHash = myTask.hash == myHash ? 1 : 0;

        emit VerificationSucceeded(_wizId, myTask.NFTID, _taskID, myHash, correctHash==1);

        if (correctHash ==1){
            // if refuterId exists, then refuter gets no refund
            uint256 split = myTask.payment/2;
            address payable taskSubmitter = payable(wizardsNFT.ownerOf(myTask.verifierID));
//            address payable verifier = msg.sender;


            wizardsNFT.verifyDuty(myTask.NFTID, myTask.timeBonus);
            wizardsNFT.verifyDuty(myTask.verifierID, taskVerificationTimeBonus);

            myTask.payment=0; // thwart reentrancy attacks
            delete tasks[_taskID];

            // send to task submitter
            (bool sent, bytes memory data) = taskSubmitter.call{value: split}("");
            require(sent, "Failed to send Ether");

            // send to verifier
            (sent, data) = msg.sender.call{value: split}("");
            require(sent, "Failed to send Ether");

        }
        else { // if incorrect Hash
            // case 2 -- if no match, send to DAO

            // case 1 -- if matches hash of refuter, split
            if(myTask.refuterHash==myHash){
                uint256 split = myTask.payment/2;
                address payable taskRefuter = payable(wizardsNFT.ownerOf(myTask.refuterID));

                wizardsNFT.verifyDuty(myTask.refuterID, taskVerificationTimeBonus);
                wizardsNFT.verifyDuty(_wizId, taskVerificationTimeBonus);

                myTask.payment=0; // thwart reentrancy attacks
                delete tasks[_taskID];

                // send to task submitter
                (bool sent, bytes memory data) = taskRefuter.call{value: split}("");
                require(sent, "Failed to send Ether");

                // send to verifier
                (sent, data) = msg.sender.call{value: split}("");
                require(sent, "Failed to send Ether");

                // emit event
            }
            else{
                // no agreement in the 3 submissions
                // send ETH to DAO
                uint256 split = myTask.payment;
                delete tasks[_taskID];
                (bool sent, bytes memory data) = owner().call{value: split}(""); // todo -- decide on how to structure DAO address
                require(sent, "Failed to send Ether");

                // emit event
            }
        }
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