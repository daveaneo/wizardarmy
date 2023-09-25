pragma solidity 0.8.15;
// SPDX-License-Identifier: Unlicensed

import "./Wizards.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IERC165.sol";
import "./interfaces/IERC721.sol";
import "./interfaces/IERC721Enumerable.sol";
import './helpers/ERC721A.sol';
import './helpers/ERC721.sol';
import './helpers/ERC165.sol';
import './helpers/Ownable.sol';
import './helpers/Context.sol';
import './helpers/ReentrancyGuard.sol';
import './helpers/ERC2981Collection.sol';
import './libraries/Strings.sol';
import './libraries/Address.sol';
import './WizardTower.sol';
import {DoubleEndedQueue} from "@openzeppelin/contracts/utils/structs/DoubleEndedQueue.sol";

// todo -- make adjustable for for task verification
// todo -- make payments for regular tasks
// todo -- make tasks verifiable again
// todo -- restore timeBonus and waitTime


interface IAppointer {
    function canRoleCreateTasks(uint256 _roleId) external view returns(bool);
}

contract Governance is ReentrancyGuard, Ownable {

//    IERC20  ecosystemTokens;
    Wizards wizardsNFT;
    WizardTower wizardTower;
    IAppointer appointerContract;

    enum TASKTYPE {BASIC, RECURRING, SINGLE_WINNER, EQUAL_SPLIT, SHARED_SPLIT}
    enum TASKSTATE { ACTIVE, PAUSED, ENDED }

    // Only accepting 11 parameters
    struct Task {
        string IPFSHash; // holds description
        TASKSTATE state;
        uint8 numFieldsToHash;
//        uint24 timeBonus;
//        uint24 waitTime; // time between repeting tasks
        uint40 begTimestamp;
        uint40 endTimestamp;
        uint16 availableSlots;
        uint16 creatorRole;
        TASKTYPE taskType;
        uint16[8] restrictedTo; // roles that can do this task. 0 means no restriction
        uint16[8] restrictedFrom; // roles that can't do this task. 0 means no restriction
    }

    struct Report {
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
    }

    DoubleEndedQueue.Bytes32Deque public reportsWaitingConfirmation;

    // This mapping holds the next active time thresholds for each task.
    // The outer mapping uses the task ID as the key.
    // The inner mapping uses a uint40 (presumably a timestamp or similar) as the key,
    // mapping to a uint256 value that represents the threshold.
    // task -> wizard -> timestamp
    mapping (uint256 => mapping(uint256 => uint256)) internal nextActiveTimeThresholds; // todo -- compare performance if change mapping uint256 to less
    mapping(uint256 => Task) public tasks;
    mapping (uint256 => Report) public reports;

    uint256 public tasksCount;
    uint256 public totalTasksAttempted; // todo what does this do?

    // todo -- Adjustable
    uint256 verificationTime = 10*60; // 10 minutes
    uint40 taskVerificationTimeBonus = 1 days; // 1 day

    event VerificationAssigned(uint256 wizardId, uint256 taskId, Report myReport);
    event VerificationFailed(uint256 VerifierIdFirst, uint256 VerifierIdSecond, uint256 taskId);
    event VerificationSucceeded(uint256 taskDoer, uint256 Verifier, uint256 taskId, bytes32 hash, bool isHashCorrect);
    event HashTesting(bytes32 hash, bool isHashCorrect, bytes32 firstEncoded, bytes firstUnencoded);
//    event NewTaskCreated(string _IPFSHash, bool paused, uint8 _numFieldsToHash, uint24 _timeBonus,
//          uint40 _begTimestamp, uint40 _endTimestamp, uint16 _availableSlots, uint16 creatorRole,
//          uint16[8] restrictedTo, uint16[8] restrictedFrom);
    event NewTaskCreated(Task task);
    event TaskAccepted(uint256 wizardId, uint256 taskId, string IPFSHash, uint256 data);
    event TaskCompleted(uint256 wizardId, uint256 taskId, string IPFSHash, uint256 data);


    /////////////////////////////
    //////  TEMP Functions ///////
    /////////////////////////////
//
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


    /////////////////////////////
    //////  Get Functions ///////
    /////////////////////////////

    /**
     * @notice Determines if a wizard is allowed to create tasks.
     * @param _wizId The ID of the wizard in question.
     * @return True if the wizard is active and has the role to create tasks, otherwise false.
     */
    function canCreateTasks(uint256 _wizId) public view returns (bool) {
        uint256 roleId = wizardsNFT.getRole(_wizId);
        return wizardsNFT.isActive(_wizId) && appointerContract.canRoleCreateTasks(roleId);
    }

    /**
     * @notice Retrieves details of a specific task.
     * @param _taskId The ID of the task to retrieve.
     * @return The details of the specified task.
     */
    function getTaskById(uint256 _taskId) external view returns (Task memory) {
        return tasks[_taskId];
    }

    /**
     * @notice Retrieves details of a specific report.
     * @param _reportId The ID of the report to retrieve.
     * @return The details of the specified report.
     */
    function getReportById(uint256 _reportId) external view returns (Report memory) {
        return reports[_reportId];
    }

    /**
     * @notice Gets the next active time threshold for a wizard on a specific task.
     * @param _taskId The ID of the task in question.
     * @param _wizId The ID of the wizard in question.
     * @return The next active time threshold for the wizard on the specified task.
     */
    function getNextActiveTimeThreshold(uint256 _taskId, uint256 _wizId) external view returns (uint256) {
        return nextActiveTimeThresholds[_taskId][_wizId];
    }


    //////////////////////////////////////
    // handled externally by events //////
    //////////////////////////////////////

//    function getTasksAssignedToWiz(uint40 _wizId) external view returns (Report[] memory, uint256[] memory) {
//    function getMyAvailableTasks(uint40 _wizId) external view returns (string[] memory) {
//    function deleteTaskByIPFSHash(string memory _IPFSHash) external
//    function areTasksAvailableToConfirm(uint256 _wizId) external view onlyEOA returns (bool) // potentially have a uint256 handling this


    /////////////////////////////
    //////  Set Functions ///////
    /////////////////////////////

    /**
     * @notice Sets the address of the Wizards NFT contract.
     * @dev Can only be called by the contract owner.
     * @param _addy The address of the Wizards NFT contract.
     */
    function setNFTAddress(address _addy) external onlyOwner {
        wizardsNFT = Wizards(_addy);
    }

    /**
     * @notice Sets the address of the Appointer contract.
     * @dev Can only be called by the contract owner.
     * @param _addy The address of the Appointer contract.
     */
    function setAppointerAddress(address _addy) external onlyOwner {
        appointerContract = IAppointer(_addy);
    }

    /**
     * @notice Updates the state of a specific task.
     * @dev Can only be called by the contract owner or a wizard with the appropriate role.
     * @param _taskId The ID of the task to update.
     * @param _wizId The ID of the wizard being used for authentication (if not the contract owner).
     * @param desiredState The desired new state for the task.
     */
    function setTaskState(uint256 _taskId, uint256 _wizId, TASKSTATE desiredState) external {
        // Ensure that the task is not in the ENDED state or already in the desired state
        require(tasks[_taskId].state != TASKSTATE.ENDED && tasks[_taskId].state != desiredState, "Task is ended and cannot change state or already in desired state.");

        // Check if the caller is either the contract owner or has the appropriate role
        if (msg.sender != owner()) {
            require(wizardsNFT.ownerOf(_wizId) == msg.sender, "Not the wizard owner");
            uint256 role = wizardsNFT.getRole(_wizId);
            require(tasks[_taskId].creatorRole == role, "Must have role of task creator.");
        }

        // Set the task's state based on the desired state
        tasks[_taskId].state = desiredState;

        // If the task is being ended, perform cleanup
        if (desiredState == TASKSTATE.ENDED) {
            // todo
    //        endTaskCleanup(_taskId);
        }
    }





    //////////////////////////////
    //////  Main Functions ///////
    //////////////////////////////

    /** @dev Constructor for HOADAO
        @param _nft -- contract address for NFTs
      */
    constructor(address _nft, address _wizardTower){
//        ecosystemTokens = IERC20(_erc20);
        wizardsNFT = Wizards(_nft);
        wizardTower = WizardTower(_wizardTower);

//        contractSettings = ContractSettings({
//        });

    }

    // Required to receive ETH
    receive() external payable {
    }

    /// @notice Creates a new task type.
    /// @dev Only the owner, or a wizard with the appropriate role can create a task type.
    /// @param _wizardId The ID of the wizard being used for authentication.
    /// @param _IPFSHash The IPFS hash of the task details.
    /// @param _numFieldsToHash Number of fields to hash.
    /// @param _begTimestamp Beginning timestamp for the task.
    /// @param _endTimestamp Ending timestamp for the task.
    /// @param _availableSlots Number of available slots for the task.
    function createTask(
        uint256 _wizardId,
        string calldata _IPFSHash,
        bool _paused,
        uint8 _numFieldsToHash,
//        uint24 _timeBonus,
//        uint24 _waitTime,
        uint40 _begTimestamp,
        uint40 _endTimestamp,
        uint16 _availableSlots,
        TASKTYPE _taskType,
        uint16[8] memory _restrictedTo,
        uint16[8] memory _restrictedFrom
    ) external onlyTaskCreators(_wizardId) {
        tasksCount++;

        tasks[tasksCount] = Task({
            IPFSHash: _IPFSHash,
            state: _paused ? TASKSTATE.PAUSED : TASKSTATE.ACTIVE, // Set the state based on the _paused value
            numFieldsToHash: _numFieldsToHash,
//            timeBonus: _timeBonus,
//            waitTime: _waitTime,
            begTimestamp: _begTimestamp,
            endTimestamp: _endTimestamp,
            availableSlots: _availableSlots,
            creatorRole:  uint16(wizardsNFT.getRole(_wizardId)),
            taskType: _taskType,
            restrictedTo: _restrictedTo,
            restrictedFrom: _restrictedFrom
        });

        emit NewTaskCreated(tasks[tasksCount]);
    }



    function claimRandomTaskForVerification(uint256 _wizId) onlyWizardOwner(_wizId) external {
        uint256 totalTasksSubmitted = DoubleEndedQueue.length(reportsWaitingConfirmation);
        Report memory myReport;
        uint256 taskId;

        // todo --implement randomness
        for(uint256 i =0; i < totalTasksSubmitted; ){
            taskId = uint256(DoubleEndedQueue.at(reportsWaitingConfirmation, i));
            myReport = reports[taskId];
            if( myReport.verificationReservedTimestamp < block.timestamp && myReport.NFTID != _wizId && myReport.refuterID!= _wizId){

                // update task
                myReport.verifierID = uint16(_wizId);
                myReport.verificationReservedTimestamp = uint40(block.timestamp + verificationTime);
                reports[taskId] = myReport;
                emit VerificationAssigned(_wizId, taskId, reports[taskId]);
            }
            unchecked{++i;}
        }
//        emit VerificationAssigned(_wizId, taskId);
    }

//    todo -- complete task using task ID
    // todo --
    function completeTask(string memory _IPFSHash, bytes32 _hash, uint40 _wizId) onlyWizardOwner(_wizId) external {
//        // IPFS, hash, wizardID
//
//        // find the task type -- can't be too many
//        for(uint256 i = 0; i<tasks.length;){
//            if(keccak256(abi.encode(tasks[i].IPFSHash)) == keccak256(abi.encode(_IPFSHash))){ // hashed to compare
//                // verify it is viable
//                require(tasks[i].begTimestamp <= block.timestamp && block.timestamp <= tasks[i].endTimestamp, "Outside time period");
//                // create new task
//                Report memory myReport = Report(_IPFSHash,_wizId, _hash, 0, tasks[i].numFieldsToHash, tasks[i].timeBonus, 0, 0, 0, 0);
//                DoubleEndedQueue.pushBack(reportsWaitingConfirmation, bytes32(totalTasksAttempted));
//                reports[totalTasksAttempted] = myReport;
//                totalTasksAttempted+=1;
//
//                // update Tasks
//                tasks[i].nextActiveTimeThreshold[_wizId] = block.timestamp + 1 days;
//                tasks[i].availableSlots = tasks[i].availableSlots - 1;
//
//                emit TaskCompleted(_wizId,totalTasksAttempted -1, _IPFSHash, block.timestamp);
//                break;
//            }
//            unchecked{++i;}
//        }
//        // failed
//

    }

    // @dev -- hash structure: leaves of merkle tree are hashed. Unrefuted reports must send in hashed leafs. Refuted, unhashed.
    function submitVerification(uint256 _wizId, uint256 _taskID, bytes32[] memory _fields) onlyWizardOwner(_wizId) external {
    //todo -- uncomment out requirement (testing)
        require(wizardsNFT.ownerOf(_wizId) == msg.sender && reports[_taskID].verifierID==_wizId, "Must be owner of assigned wizard");
        require(_fields.length > 0);

        Report memory myReport = reports[_taskID];
//        uint256 count = 0;
        bool deleteTaskFlag = true;

        // hash leaves if there is a refuter
        if(myReport.refuterID > 0) {
            for(uint256 i = 0; i < _fields.length;){
                _fields[i] = keccak256(abi.encodePacked(_fields[i]));
                unchecked{++i;}
            }
        }
        bytes32 myHash = keccak256(abi.encodePacked(_fields));

        uint256 correctHash = myReport.hash == myHash ? 1 : 0;

        emit VerificationSucceeded(_wizId, myReport.NFTID, _taskID, myHash, correctHash==1);

        if (correctHash ==1){
            // if refuterId exists, then refuter gets no refund
            uint256 split = myReport.payment/2;
            address payable taskSubmitter = payable(wizardsNFT.ownerOf(myReport.verifierID));
//            address payable verifier = msg.sender;

            wizardsNFT.increaseProtectedUntilTimestamp(myReport.NFTID, myReport.timeBonus);
            wizardsNFT.increaseProtectedUntilTimestamp(myReport.verifierID, taskVerificationTimeBonus);

            // myReport.payment=0; // thwart reentrancy attacks
            delete reports[_taskID];

            // send to task submitter
            (bool sent, bytes memory data) = taskSubmitter.call{value: split}("");
            require(sent, "Failed to send Ether");

            // send to verifier
            (sent, data) = msg.sender.call{value: split}("");
            require(sent, "Failed to send Ether");

        }
        else { // if incorrect Hash
            // case 2 -- if no match, send to DAO


            if(myReport.refuterID==0){
                myReport.refuterID=uint16(_wizId);
                myReport.refuterHash=myHash;
                reports[_taskID] = myReport;
                deleteTaskFlag = false;
            }

            // case 1 -- if matches hash of refuter, split
            if(myReport.refuterHash==myHash){
                uint256 split = myReport.payment/2;
                address payable taskRefuter = payable(wizardsNFT.ownerOf(myReport.refuterID));

                wizardsNFT.increaseProtectedUntilTimestamp(myReport.refuterID, taskVerificationTimeBonus);
                wizardsNFT.increaseProtectedUntilTimestamp(_wizId, taskVerificationTimeBonus);

                // myReport.payment=0; // thwart reentrancy attacks
                delete reports[_taskID];

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
                uint256 split = myReport.payment;
                delete reports[_taskID];
                (bool sent, bytes memory data) = owner().call{value: split}(""); // todo -- decide on how to structure DAO address
                require(sent, "Failed to send Ether");

                // emit event
            }
        }

            // delete task from double ended queue
        if(deleteTaskFlag){
            uint256 totalTasksSubmitted = DoubleEndedQueue.length(reportsWaitingConfirmation);
//            Report memory myReport;

            // delete task from doubleEndedQueue
            for(uint256 i =0; i < totalTasksSubmitted; ){
                if( uint256(DoubleEndedQueue.at(reportsWaitingConfirmation, i))==_taskID){
                    bytes32 prevFront = DoubleEndedQueue.popFront(reportsWaitingConfirmation);
                    if(i!=0){ // add back on if we weren't meant to remove front
                        reportsWaitingConfirmation._data[int128(reportsWaitingConfirmation._begin + int(i))] = prevFront;
                    }
                }
                unchecked{++i;}
            }
        }

    }

    //////////////////////
    ////// Modifiers /////
    //////////////////////

    /// @notice Checks if the message sender is the owner of the token.
    /// @param tokenId ID of the token to check ownership of.
    modifier onlyWizardOwner(uint256 tokenId) {
        require(wizardsNFT.ownerOf(tokenId) == msg.sender); // dev: "Caller is not the owner of this NFT"
        _;
    }

    /**
     * @dev Modifier to ensure the caller is not another smart contract.
     */
    modifier onlyEOA() {
        require(tx.origin == msg.sender, "Cannot be called by a contract");
        _;
    }

    /// @dev Modifier to check if the caller is authorized to create a task -- owns and has right permissions.
    /// @param _wizardId The ID of the wizard being used for authentication.
    modifier onlyTaskCreators(uint256 _wizardId) {
        require(
            msg.sender == owner() || // Owner of the contract has unrestricted access.
            (msg.sender == wizardsNFT.ownerOf(_wizardId) && canCreateTasks(_wizardId)), // Check if the caller owns the specified wizard and if the wizard has the right to create task types.
            "Must own a qualified wizard or be the contract owner"
        );
        _;
    }





}