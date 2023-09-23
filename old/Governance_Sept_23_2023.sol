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

interface IAppointer {
    function canRoleCreateTaskTypes(uint256 _roleId) external view returns(bool);
}

contract Governance is ReentrancyGuard, Ownable {

//    IERC20  ecosystemTokens;
    Wizards wizardsNFT;
    WizardTower wizardTower;
    IAppointer appointerContract;

    // used to find active tasks
    struct TaskType {
        mapping (uint40 => uint256) nextActiveTimeThreshold; // for recurring tasks -- todo -- add waitTime or ...
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

    TaskType[] public taskTypes; // we must keep task types low in quantity to avoid gas issues

    DoubleEndedQueue.Bytes32Deque public tasksWaitingConfirmation;

    mapping (uint256 => Task) public tasks;
    uint256 public totalTasksAttempted;

    // todo -- Adjustable
    uint256 verificationTime = 10*60; // 10 minutes
    uint40 taskVerificationTimeBonus = 1 days; // 1 day

    event VerificationAssigned(uint256 wizardId, uint256 taskId, Task myTask);
    event VerificationFailed(uint256 VerifierIdFirst, uint256 VerifierIdSecond, uint256 taskId);
    event VerificationSucceeded(uint256 taskDoer, uint256 Verifier, uint256 taskId, bytes32 hash, bool isHashCorrect);
    event HashTesting(bytes32 hash, bool isHashCorrect, bytes32 firstEncoded, bytes firstUnencoded);
    event NewTaskTypeCreated(string _IPFSHash,uint40 _proposalID, uint8 _numFieldsToHash, uint24 _timeBonus,
          uint40 _begTimestamp, uint40 _endTimestamp, uint16 _availableSlots);
    event TaskAccepted(uint256 wizardId, uint256 taskId, string IPFSHash, uint256 data);
    event TaskCompleted(uint256 wizardId, uint256 taskId, string IPFSHash, uint256 data);

    /////////////////////////////
    //////  TEMP Functions ///////
    /////////////////////////////


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



    /////////////////////////////
    //////  Get Functions ///////
    /////////////////////////////


    // todo -- update this function as we know long have board but have roles that can assign tasks to other roles
    function canCreateTaskTypes(uint256 _wizId) public view returns (bool) {
        uint256 roleId = wizardsNFT.getRole(_wizId);
        return wizardsNFT.isActive(_wizId) && appointerContract.canRoleCreateTaskTypes(roleId);
    }

//    todo -- we want to limit certain tasks to certain roles. How to do this in a department?
    function getTaskById(uint256 _taskId) external view returns (Task memory) {
        return tasks[_taskId];
    }

    /**
     * @notice Check if there are any tasks available for confirmation for a given wizard.
     * @param _wizId The ID of the wizard.
     * @return True if tasks are available for confirmation; otherwise, false.
     * @dev Ensures the caller is not another smart contract.
     */
    function areTasksAvailableToConfirm(uint256 _wizId) external view onlyEOA returns (bool) {
        uint256 totalTasksSubmitted = DoubleEndedQueue.length(tasksWaitingConfirmation);
        Task memory myTask;
        // todo --implement randomness

        for(uint256 i =0; i < totalTasksSubmitted; ){
            myTask = tasks[uint256(DoubleEndedQueue.at(tasksWaitingConfirmation,i))];
            if( myTask.verificationReservedTimestamp < block.timestamp && myTask.NFTID != _wizId && myTask.refuterID!= _wizId){
                return true;
            }
            unchecked{++i;}
        }
        return false;
    }


    // todo -- refactor. No for loops like this. We will have to use events.
    function getTasksAssignedToWiz(uint40 _wizId) external view returns (Task[] memory, uint256[] memory) {
        uint256 totalTasksAssigned = DoubleEndedQueue.length(tasksWaitingConfirmation);
        Task memory myTask;
        uint256 taskId;
        uint256 count=0;

        for(uint256 i =0; i < totalTasksAssigned; ){
            taskId = uint256(DoubleEndedQueue.at(tasksWaitingConfirmation, i));
            myTask = tasks[taskId];
            if( myTask.verificationReservedTimestamp > block.timestamp && myTask.verifierID== _wizId){
                unchecked{++count;}
            }
            unchecked{++i;}
        }

        // if no tasks, return empty array
        if (count==0) {
            Task[] memory myReturn= new Task[](1);
            uint256[] memory myReturnUint= new uint256[](1);
            return (myReturn, myReturnUint);
        }

        uint256 counter = 0;
        Task[] memory myTasks = new Task[](count);
        uint256[] memory myTaskIds = new uint256[](count);
        for(uint256 i =0; i < totalTasksAssigned; ){
            taskId = uint256(DoubleEndedQueue.at(tasksWaitingConfirmation, i));
            myTask = tasks[taskId];
            if( myTask.verificationReservedTimestamp > block.timestamp && myTask.verifierID== _wizId){
                myTasks[counter] = myTask;
                myTaskIds[counter] = taskId;
                unchecked{++counter;}
                if(counter>count){break;}
            }
            unchecked{++i;}
        }
        return (myTasks, myTaskIds);
    }

    // todo -- remove because of for loop
    // todo -- see if we need to include IDs here -- may not need to
    function getMyAvailableTaskTypes(uint40 _wizId) external view returns (string[] memory) {
        uint256 count;
        for(uint256 i=0; i< taskTypes.length;){
            if(taskTypes[i].nextActiveTimeThreshold[_wizId] < block.timestamp
            && taskTypes[i].begTimestamp <= block.timestamp && taskTypes[i].endTimestamp > block.timestamp
            && taskTypes[i].availableSlots > 1
            ) {
                unchecked{++count;}
            }
            unchecked{++i;}
        }

        // if no tasks, return empty array
        if (count==0) {
            string[] memory myReturn= new string[](1);
            myReturn[0] = "";
            return myReturn;
        }

        string[] memory myTasks = new string[](count);
        uint256 counter = 0;
        for(uint256 i=0; i< taskTypes.length;){
            if(taskTypes[i].nextActiveTimeThreshold[_wizId] < block.timestamp
            && taskTypes[i].begTimestamp <= block.timestamp && taskTypes[i].endTimestamp > block.timestamp
            && taskTypes[i].availableSlots > 1
            ) {
                myTasks[counter] = taskTypes[i].IPFSHash;
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

    function setAppointerAddress(address _addy) external onlyOwner {
        appointerContract = IAppointer(_addy);
    }

    // todo -- inefficient
    function deleteTaskTypeByIPFSHash(string memory _IPFSHash) external {
        for(uint256 i=0; i<taskTypes.length;){
            if(keccak256(abi.encodePacked(taskTypes[i].IPFSHash)) == keccak256(abi.encodePacked(_IPFSHash))){
                TaskType storage myTaskType = taskTypes[i];
                TaskType storage displacedTaskType = taskTypes[taskTypes.length-1];
                myTaskType = displacedTaskType;
                delete taskTypes[taskTypes.length-1];
                // todo see if this works at all
                delete taskTypes[taskTypes.length-1];
                break;
            }
            unchecked{++i;}
        }
    }


//    todo -- make another function where authorized users can delete the taskType
    function deleteTaskType(uint256 _taskId) external onlyOwner {
        delete taskTypes[_taskId];
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
    /// @param _timeBonus Time-based bonus for the task.
    /// @param _begTimestamp Beginning timestamp for the task.
    /// @param _endTimestamp Ending timestamp for the task.
    /// @param _availableSlots Number of available slots for the task.
    function createTaskType(
        uint256 _wizardId,
        string calldata _IPFSHash,
        uint8 _numFieldsToHash,
        uint24 _timeBonus,
        uint40 _begTimestamp,
        uint40 _endTimestamp,
        uint16 _availableSlots
    ) external onlyTaskCreators(_wizardId) {
        _createTaskType(_IPFSHash, 0, _numFieldsToHash, _timeBonus, _begTimestamp, _endTimestamp, _availableSlots);
    }

    /// @notice Creates a new task type.
    /// @dev Only the owner, or a wizard with the appropriate role can create a task type.
    /// @param _IPFSHash The IPFS hash of the task details.
    /// @param _numFieldsToHash Number of fields to hash.
    /// @param _timeBonus Time-based bonus for the task.
    /// @param _begTimestamp Beginning timestamp for the task.
    /// @param _endTimestamp Ending timestamp for the task.
    /// @param _availableSlots Number of available slots for the task.
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


    function claimRandomTaskForVerification(uint256 _wizId) external {
        uint256 totalTasksSubmitted = DoubleEndedQueue.length(tasksWaitingConfirmation);
        Task memory myTask;
        uint256 taskId;

        // todo --implement randomness
        // uint256[25] memory potentialTasks;

        for(uint256 i =0; i < totalTasksSubmitted; ){
            taskId = uint256(DoubleEndedQueue.at(tasksWaitingConfirmation, i));
            myTask = tasks[taskId];
            if( myTask.verificationReservedTimestamp < block.timestamp && myTask.NFTID != _wizId && myTask.refuterID!= _wizId){
//                taskId = uint256(DoubleEndedQueue.at(tasksWaitingConfirmation, i));
//                myTask = tasks[taskId];

                // update task
                myTask.verifierID = uint16(_wizId);
                myTask.verificationReservedTimestamp = uint40(block.timestamp + verificationTime);
                tasks[taskId] = myTask;
                emit VerificationAssigned(_wizId, taskId, tasks[taskId]);
            }
            unchecked{++i;}
        }
//        emit VerificationAssigned(_wizId, taskId);
    }

    function completeTask(string memory _IPFSHash, bytes32 _hash, uint40 _wizId) external {
        // IPFS, hash, wizardID

        // find the task type -- can't be too many
        for(uint256 i = 0; i<taskTypes.length;){
            if(keccak256(abi.encode(taskTypes[i].IPFSHash)) == keccak256(abi.encode(_IPFSHash))){ // hashed to compare
                // verify it is viable
                require(taskTypes[i].begTimestamp <= block.timestamp && block.timestamp <= taskTypes[i].endTimestamp, "Outside time period");
                // create new task
                Task memory myTask = Task(_IPFSHash,_wizId, _hash, 0, taskTypes[i].numFieldsToHash, taskTypes[i].timeBonus, 0, 0, 0, 0);
                DoubleEndedQueue.pushBack(tasksWaitingConfirmation, bytes32(totalTasksAttempted));
                tasks[totalTasksAttempted] = myTask;
                totalTasksAttempted+=1;

                // update TaskTypes
                taskTypes[i].nextActiveTimeThreshold[_wizId] = block.timestamp + 1 days;
                taskTypes[i].availableSlots = taskTypes[i].availableSlots - 1;

                emit TaskCompleted(_wizId,totalTasksAttempted -1, _IPFSHash, block.timestamp);
                break;
            }
            unchecked{++i;}
        }
        // failed


    }



    // @dev -- hash structure: leaves of merkle tree are hashed. Unrefuted tasks must send in hashed leafs. Refuted, unhashed.
    function submitVerification(uint256 _wizId, uint256 _taskID, bytes32[] memory _fields) external {
    //todo -- uncomment out requirement (testing)
        require(wizardsNFT.ownerOf(_wizId) == msg.sender && tasks[_taskID].verifierID==_wizId, "Must be owner of assigned wizard");
        require(_fields.length > 0);

        Task memory myTask = tasks[_taskID];
//        uint256 count = 0;
        bool deleteTaskFlag = true;

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

            wizardsNFT.increaseProtectedUntilTimestamp(myTask.NFTID, myTask.timeBonus);
            wizardsNFT.increaseProtectedUntilTimestamp(myTask.verifierID, taskVerificationTimeBonus);

            // myTask.payment=0; // thwart reentrancy attacks
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


            if(myTask.refuterID==0){
                myTask.refuterID=uint16(_wizId);
                myTask.refuterHash=myHash;
                tasks[_taskID] = myTask;
                deleteTaskFlag = false;
            }

            // case 1 -- if matches hash of refuter, split
            if(myTask.refuterHash==myHash){
                uint256 split = myTask.payment/2;
                address payable taskRefuter = payable(wizardsNFT.ownerOf(myTask.refuterID));

                wizardsNFT.increaseProtectedUntilTimestamp(myTask.refuterID, taskVerificationTimeBonus);
                wizardsNFT.increaseProtectedUntilTimestamp(_wizId, taskVerificationTimeBonus);

                // myTask.payment=0; // thwart reentrancy attacks
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

            // delete task from double ended queue
        if(deleteTaskFlag){
            uint256 totalTasksSubmitted = DoubleEndedQueue.length(tasksWaitingConfirmation);
//            Task memory myTask;

            // delete task from doubleEndedQueue
            for(uint256 i =0; i < totalTasksSubmitted; ){
                if( uint256(DoubleEndedQueue.at(tasksWaitingConfirmation, i))==_taskID){
                    bytes32 prevFront = DoubleEndedQueue.popFront(tasksWaitingConfirmation);
                    if(i!=0){ // add back on if we weren't meant to remove front
                        tasksWaitingConfirmation._data[int128(tasksWaitingConfirmation._begin + int(i))] = prevFront;
                    }
                }
                unchecked{++i;}
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

    /**
     * @dev Modifier to ensure the caller is not another smart contract.
     */
    modifier onlyEOA() {
        require(tx.origin == msg.sender, "Cannot be called by a contract");
        _;
    }

    /// @dev Modifier to check if the caller is authorized to create a task.
    /// @param _wizardId The ID of the wizard being used for authentication.
    modifier onlyTaskCreators(uint256 _wizardId) {
        require(
            msg.sender == owner() || // Owner of the contract has unrestricted access.
            (msg.sender == wizardsNFT.ownerOf(_wizardId) && canCreateTaskTypes(_wizardId)), // Check if the caller owns the specified wizard and if the wizard has the right to create task types.
            "Must own a qualified wizard or be the contract owner"
        );
        _;
    }





}