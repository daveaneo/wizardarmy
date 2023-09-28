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
    enum REPORTSTATE { ACTIVE, SUBMITTED, REFUTED, VERIFIED, FAILED }

    struct TimeDetails {
        uint40 begTimestamp;
        uint40 endTimestamp;
        uint24 waitTime;
        uint24 timeBonus;
    }

    struct RoleDetails {
        uint16 creatorRole;
        uint16 restrictedTo; // roles that can do this task. 0 means no restriction
        // uint16[8] restrictedFrom; // if you choose to include this later
        uint16 availableSlots;
    }

    struct CoreDetails {
        string IPFSHash; // holds description
        TASKSTATE state;
        uint8 numFieldsToHash;
        TASKTYPE taskType;
        uint128 payment;
    }

    struct Task {
        TimeDetails timeDetails;
        RoleDetails roleDetails;
        CoreDetails coreDetails;
    }

    struct Report {
        REPORTSTATE reportState;
        uint16 reporterID; // wizard ID of reported
        uint16 verifierID; // wizardId of Verifier
        uint16 refuterID; // wizardId of Verifier
        bytes32 hash; // hashed input to be validated
        bytes32 refuterHash; // correct hash according to refuter
        uint128 taskId;
        uint40 verificationReservedTimestamp; // time when verification period ends
    }

    uint256[] public reportsWaitingConfirmation;
//    uint256[] public reportsClaimedForConfirmation;

//    DoubleEndedQueue.Bytes32Deque public reportsWaitingConfirmation;
    DoubleEndedQueue.Bytes32Deque public reportsClaimedForConfirmation;

    // todo -- do we need to pass more information in the report?

    // This mapping holds the next active time thresholds for each task.
    // The outer mapping uses the task ID as the key.
    // The inner mapping uses a uint40 (presumably a timestamp or similar) as the key,
    // mapping to a uint256 value that represents the threshold.
    // task -> wizard -> timestamp
    mapping (uint256 => mapping(uint256 => uint256)) internal nextEligibleTime; // todo -- compare performance if change mapping uint256 to less
    mapping(uint256 => Task) public tasks;
    mapping (uint256 => Report) public reports;

    uint256 public tasksCount;
    uint256 public reportsCount; // todo what does this do?
    uint256 CLAIMED_REPORTS_TO_PROCESS = 5; // max claimed reports/iterations to process // todo -- updateable

    // todo -- Adjustable
    uint256 verificationTime = 10*60; // 10 minutes // todo -- bigger tasks may want custom verification
    uint40 taskVerificationTimeBonus = 1 days; // 1 day

    /// @notice Emitted when a verification is assigned to a wizard for a task.
    /// @param wizardId ID of the wizard to whom the verification is assigned.
    /// @param taskId ID of the task for which the verification is assigned.
    /// @param myReport The report associated with the verification assignment.
    event VerificationAssigned(uint256 indexed wizardId, uint256 indexed taskId, Report myReport);

    /// @notice Emitted when the verification process fails.
    /// @param VerifierIdFirst ID of the first verifier.
    /// @param VerifierIdSecond ID of the second verifier (if applicable).
    /// @param taskId ID of the task for which verification failed.
    event VerificationFailed(uint256 indexed VerifierIdFirst, uint256 indexed VerifierIdSecond, uint256 indexed taskId);

    /// @notice Emitted when the verification process succeeds.
    /// @param taskDoer ID of the wizard who completed the task.
    /// @param Verifier ID of the verifying wizard.
    /// @param taskId ID of the verified task.
    /// @param hash The hash associated with the verification.
    /// @param isHashCorrect Boolean indicating if the hash is correct.
    event VerificationSucceeded(uint256 indexed taskDoer, uint256 indexed Verifier, uint256 indexed taskId, bytes32 hash, bool isHashCorrect);

    /// @notice Emitted for testing hash functionality.
    /// @param hash The hash being tested.
    /// @param isHashCorrect Boolean indicating if the hash is correct.
    /// @param firstEncoded The encoded version of the hash.
    /// @param firstUnencoded The unencoded version of the hash.
    event HashTesting(bytes32 hash, bool isHashCorrect, bytes32 firstEncoded, bytes firstUnencoded);

    /// @notice Emitted when a new task is created.
    /// @param task The new task that was created.
    event NewTaskCreated(uint256 taskId, Task task);

    /// @notice Emitted when a task is completed by a wizard.
    /// @param wizardId ID of the wizard who completed the task.
    /// @param reportId ID of the completed task.
    event TaskCompleted(uint256 indexed wizardId, uint256 indexed reportId, uint256 indexed taskId);

    /// @notice Emitted when a task is accepted by a wizard.
    /// @param reportId ID of the report associated with the accepted task.
    /// @param taskId ID of the accepted task.
    /// @param wizardId ID of the wizard who accepted the task.
    event TaskAccepted(uint256 indexed reportId, uint256 indexed taskId, uint40 indexed wizardId);



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
    function getNextEligibleTime(uint256 _taskId, uint256 _wizId) external view returns (uint256) {
        return nextEligibleTime[_taskId][_wizId];
    }


//    /**
//     * @notice Returns the number of reports currently waiting for confirmation.
//     * @return The number of reports in the waiting confirmation queue.
//     */
//    function reportsWaitingConfirmationLength() external view returns (uint256) {
//        return DoubleEndedQueue.length(reportsWaitingConfirmation);
//    }


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
        require(tasks[_taskId].coreDetails.state != TASKSTATE.ENDED && tasks[_taskId].coreDetails.state != desiredState); // dev: "Task is ended and cannot change state or already in desired state."

        // Check if the caller is either the contract owner or has the appropriate role
        if (msg.sender != owner()) {
            require(wizardsNFT.ownerOf(_wizId) == msg.sender); // dev: , "Not the wizard owner"
            uint256 role = wizardsNFT.getRole(_wizId);
            require(tasks[_taskId].roleDetails.creatorRole == role); // dev: "Must have role of task creator."
        }

        // Set the task's state based on the desired state
        tasks[_taskId].coreDetails.state = desiredState;

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
    }

    // Required to receive ETH
    receive() external payable {
    }

    function createTask(
        uint256 _wizardId,
        CoreDetails calldata coreDetails,
        TimeDetails calldata timeDetails,
        RoleDetails calldata roleDetails
    ) external onlyTaskCreators(_wizardId)  {
        tasksCount++;

        tasks[tasksCount] = Task({
            coreDetails: coreDetails,
            timeDetails: timeDetails,
            roleDetails: roleDetails
        });

        // Override specific parameters after copying from arguments
        tasks[tasksCount].coreDetails.state = coreDetails.state == TASKSTATE.PAUSED ? TASKSTATE.PAUSED : TASKSTATE.ACTIVE;
        tasks[tasksCount].roleDetails.creatorRole = uint16(wizardsNFT.getRole(_wizardId));

        emit NewTaskCreated(tasksCount, tasks[tasksCount]);
    }


    /**
     * @notice Accept a task for a specific wizard.
     * @dev Allows a wizard owner to accept a task if the wizard is eligible, there are available slots,
     * and the wizard hasn't claimed the task already.
     *
     * @param _taskId The ID of the task to accept.
     * @param _wizId The ID of the wizard accepting the task.
     */
    function acceptTask(uint256 _taskId, uint16 _wizId) onlyWizardOwner(_wizId) external returns(uint256 reportId) {
        require(_taskId <= tasksCount && _taskId != 0, "invalid task"); // dev: invalid task
        Task memory myTask = tasks[_taskId];

        // Make sure the wizard is eligible
        uint16 wizRole = uint16(wizardsNFT.getRole(_wizId));
//        todo include time restrictions with start and stop and pause
        require(((
                myTask.roleDetails.restrictedTo == 0) || (myTask.roleDetails.restrictedTo == wizRole))
                && block.timestamp >= nextEligibleTime[_taskId][_wizId]
                && block.timestamp >= myTask.timeDetails.begTimestamp && block.timestamp < myTask.timeDetails.endTimestamp
                && myTask.coreDetails.state == TASKSTATE.ACTIVE
                && myTask.roleDetails.availableSlots > 0
        , "wizard not elible"); // dev: "Wizard not eligible"


        // Decrease the available slots
        tasks[_taskId].roleDetails.availableSlots--;

        // Update the nextEligibleTime for the wizard
        nextEligibleTime[_taskId][_wizId] = uint40(block.timestamp + myTask.timeDetails.waitTime);

        // Create a report and emit the event
        uint256 reportId = createReport(_wizId, _taskId);
        return reportId;
    }


    /// @notice Allows a wizard to complete a task by submitting a hash.
    /// @dev This function updates the report with the submitted hash, changes the report's state to submitted,
    /// adds the report ID to the double-ended queue, and emits a TaskCompleted event.
    /// @param _reportId The ID of the report being updated.
    /// @param _hash The hash being submitted for the task completion.
    /// @param _wizId The ID of the wizard completing the task.
    function completeTask(uint256 _reportId, bytes32 _hash, uint16 _wizId) onlyWizardOwner(_wizId) external {
        // Ensure the report exists and belongs to the wizard
        require(reports[_reportId].reporterID == _wizId); // dev: "Wizard is not the reporter for this task."

        // Update the report's hash and state
        reports[_reportId].hash = _hash;
        reports[_reportId].reportState = REPORTSTATE.SUBMITTED;


        // todo -- determine if we still need this doubleEndedQueue or if we can just get away with a list
        // Add the report ID to the double-ended queue
        // Assuming the queue's name is 'reportQueue' and it has an 'enqueue' function
//        DoubleEndedQueue.pushBack(reportsWaitingConfirmation, bytes32(_reportId));
//        reportsWaitingConfirmation.push(_reportId);

        // if this is restrictedTo -- and can only be approved by one role -- do not put into the confirmation queue
        if (tasks[reports[_reportId].taskId].roleDetails.restrictedTo == 0){
            reportsWaitingConfirmation.push(_reportId);
        }


        // Emit the TaskCompleted event
        emit TaskCompleted(_wizId, _reportId, reports[_reportId].taskId);
//        we may need to have restrictedTo

    }


    /**
     * @notice Creates a report for a claimed task.
     * @dev This function initializes a report with the reporter's ID and sets it to the ACTIVE state.
     * @param _reporterId The ID of the wizard making the report.
     * @param _taskId The ID of the task being reported.
     * @return reportId The ID of the newly created report.
     */
    function createReport(uint16 _reporterId, uint256 _taskId) internal returns (uint256 reportId) {
        Report memory newReport;

        newReport.reportState = REPORTSTATE.ACTIVE;
        newReport.reporterID = _reporterId;
        newReport.taskId = uint128(_taskId);
        // The other fields remain at their default values (which are 0 for numeric values)

        reportsCount++;
        reports[reportsCount] = newReport;

        emit TaskAccepted(reportsCount, _taskId, _reporterId);

        return reportsCount;
    }


    //    todo -- tasks that are restrictedTo will cause this to be a problem. We need them to go somewhere else.
    // how about those tasks don't get sent here

    /// @notice Allows a wizard to claim a random task for verification.
    /// @dev The function ensures the caller is not a contract, randomly selects a report for verification,
    /// moves the report from reportsWaitingConfirmation to reportsClaimed, and updates the verifierID of the report.
    /// @param _wizId The ID of the wizard claiming the task for verification.
    function claimRandomTaskForVerification(uint256 _wizId) onlyWizardOwner(_wizId) external {
        // Ensure the caller is not a contract
        require(tx.origin == msg.sender); // dev: "Contracts are not allowed to claim tasks."

        // process reports
        processReportsClaimedForConfirmation(CLAIMED_REPORTS_TO_PROCESS); // todo -- adjustable variable

        require(reportsWaitingConfirmation.length > 0); // dev: "No tasks available for verification."

        // Implement randomness - for simplicity, using blockhash and modulo. In a real-world scenario, consider a more robust method.
        uint256 randomIndex = uint256(keccak256(abi.encodePacked(blockhash(block.number - 1), _wizId))) % reportsWaitingConfirmation.length;
        uint256 taskId = reportsWaitingConfirmation[randomIndex];

        Report memory myReport = reports[taskId];
        require(myReport.reporterID != _wizId && myReport.refuterID != _wizId); // dev: "Wizard is not allowed to verify/refute their own task."

        // Update the report's verifierID and move it from one queue to another
        myReport.verifierID = uint16(_wizId);
        reports[taskId] = myReport;

        // place into queue for processing
        DoubleEndedQueue.pushBack(reportsClaimedForConfirmation, bytes32(taskId));
        // remove from current queue
        removeElement(reportsWaitingConfirmation, randomIndex);

        emit VerificationAssigned(_wizId, taskId, reports[taskId]);
    }

    /**
     * @notice Allows a wizard with a specific role to verify a report for a restricted task.
     * @dev Only the owner of the specified wizard can call this function, and the wizard must have the same role as the creator of the task.
     * @param _wizId The ID of the wizard performing the verification.
     * @param _reportId The ID of the report being verified.
     * @param approve If `true`, the report is approved; otherwise, it is failed.
     */
    function verifyRestrictedTask(uint256 _wizId, uint256 _reportId, bool approve) onlyWizardOwner(_wizId) external {
        require(tasks[reports[_reportId].taskId].roleDetails.creatorRole == wizardsNFT.getRole(_wizId)); // dev: wizard must have role of assigned task
        if (approve){
            // todo -- handle approval
        }
        else{
            // todo -- handle failure
        }
    }


    /**
     * @notice Processes reports that have been claimed for confirmation, up to a maximum number.
     * @dev Iterates through reportsClaimedForConfirmation and handles them based on their REPORTSTATE.
     * If the verificationReservedTimestamp of a report has expired, it processes the report and moves it to reportsWaitingConfirmation.
     * It will process up to the smaller of 'n' reports or the total length of reportsClaimedForConfirmation.
     * @param n The maximum number of reports to process from the reportsClaimedForConfirmation array.
     */
    function processReportsClaimedForConfirmation(uint256 n) public {
        uint256 totalReportsClaimed = DoubleEndedQueue.length(reportsClaimedForConfirmation);
        uint256 toProcess = n < totalReportsClaimed ? n : totalReportsClaimed;
        uint256 processed = 0;

        while (processed < toProcess) {
            uint256 reportId = uint256(DoubleEndedQueue.front(reportsClaimedForConfirmation));
            Report storage report = reports[reportId];

            // If the report's verification timestamp hasn't passed yet, break out of the loop
            if (report.verificationReservedTimestamp > block.timestamp) {
                break;
            }

            // Remove the front element from reportsClaimedForConfirmation
            DoubleEndedQueue.popFront(reportsClaimedForConfirmation);

            // Check the state of the report
            if (report.reportState == REPORTSTATE.SUBMITTED) {
                // Handle the case where the report was submitted but time ran out
                handleReportPastDeadline(reportId);
            } else if (report.reportState == REPORTSTATE.REFUTED) {
                // Handle the refuted state
                handleRefutedReport(reportId);
            } else if (report.reportState == REPORTSTATE.VERIFIED) {
                // Handle the verified state
                handleVerifiedReport(reportId);
            } else if (report.reportState == REPORTSTATE.FAILED) {
                // Handle the failed state
                handleFailedReport(reportId);
            } else {
                //this should never happen
            }

            unchecked {
                processed++;
            }
        }
    }


    // Dummy function handlers for each state. You should replace these with actual implementations.
    function handleReportPastDeadline(uint256 reportId) internal {
        // Implementation for handling SUBMITTED state
    }

    function handleRefutedReport(uint256 reportId) internal {
        // Implementation for handling REFUTED state
    }

    function handleVerifiedReport(uint256 reportId) internal {
        // Implementation for handling VERIFIED state
    }

    function handleFailedReport(uint256 reportId) internal {
        // Implementation for handling FAILED state
    }




    // If submitted, we send in hashed leaves. The result is that it is either verified or refuted
    // if refuted, we send in NON-hashed leaves. The result is that it is either verified, or failed. Failed has two possibilities, two refuters agree (they split funds) or all disagree
    // todo -- review
    // @dev -- hash structure: leaves of merkle tree are hashed. Unrefuted reports must send in hashed leafs. Refuted, unhashed.
    function submitVerification(uint256 _wizId, uint256 _taskID, bytes32[] memory _fields) onlyWizardOwner(_wizId) external {
    //todo -- uncomment out requirement (testing)
//        require(wizardsNFT.ownerOf(_wizId) == msg.sender && reports[_taskID].verifierID==_wizId, "Must be owner of assigned wizard");
        require(_fields.length > 0);

        Report storage myReport = reports[_taskID];
        bool deleteTaskFlag = true;

        // if refuted, we want to hash the leaves
        if(myReport.reportState == REPORTSTATE.REFUTED){
//        if(myReport.refuterID > 0) {
            for(uint256 i = 0; i < _fields.length;){
                _fields[i] = keccak256(abi.encodePacked(_fields[i]));
                unchecked{++i;}
            }
        }

        bytes32 myHash = keccak256(abi.encodePacked(_fields));
        uint256 hashIsCorrect = myReport.hash == myHash ? 1 : 0;

        // consider if this should be one event for success, failure, or state
        emit VerificationSucceeded(_wizId, myReport.reporterID, _taskID, myHash, hashIsCorrect==1);

        if (hashIsCorrect ==1){
            // todo -- the amount to send is wrong. We want to give the verifier back their funds
            // todo -- we want to reward the task submitter with any reward
            // todo -- we want to reward the task submitter with any fee
            // todo -- consider eth fee, stablecoin, or wizard gold
            // todo -- consider set fee or adjustable. If later, we will need to save this info in the report

            // if refuterId exists, then refuter gets no refund
            uint256 split = tasks[myReport.taskId].coreDetails.payment/2;
            address payable taskSubmitter = payable(wizardsNFT.ownerOf(myReport.verifierID));
//            address payable verifier = msg.sender;

            wizardsNFT.increaseProtectedUntilTimestamp(myReport.reporterID, tasks[myReport.taskId].timeDetails.timeBonus);
            wizardsNFT.increaseProtectedUntilTimestamp(myReport.verifierID, taskVerificationTimeBonus);

            myReport.reportState = REPORTSTATE.VERIFIED;

            // send to task submitter
            (bool sent, bytes memory data) = taskSubmitter.call{value: split}("");
            require(sent); // dev: "Failed to send Ether"

            // send to verifier
            (sent, data) = msg.sender.call{value: split}("");
            require(sent); // dev: "Failed to send Ether"

        }
        else { // if incorrect Hash
            // case 2 -- if no match, send to DAO


            // could also check state
            if(myReport.refuterID==0){ // myReport.reportState == REPORTSTATE.SUBMITTED
                myReport.refuterID=uint16(_wizId);
                myReport.refuterHash=myHash;
                myReport.reportState = REPORTSTATE.REFUTED;
            }
            else {
                // case 1 -- if matches hash of refuter, split
                if(myReport.refuterHash==myHash){
                    uint256 split = tasks[myReport.taskId].coreDetails.payment/2;
                    address payable taskRefuter = payable(wizardsNFT.ownerOf(myReport.refuterID));

                    wizardsNFT.increaseProtectedUntilTimestamp(myReport.refuterID, taskVerificationTimeBonus);
                    wizardsNFT.increaseProtectedUntilTimestamp(_wizId, taskVerificationTimeBonus);

                    // myReport.payment=0; // thwart reentrancy attacks
                    delete reports[_taskID];

                    // send to task submitter
                    (bool sent, bytes memory data) = taskRefuter.call{value: split}("");
                    require(sent); // dev: "Failed to send Ether"

                    // send to verifier
                    (sent, data) = msg.sender.call{value: split}("");
                    require(sent); // dev: "Failed to send Ether"
                    myReport.reportState = REPORTSTATE.FAILED; // todo -- consider if we have REFUTED or FAILED here -- ie, should we have a third state (?DISPARATE) to ackowlege 0 consensus
                    // todo -- perhaps we can include a bool to say if there is consensus

                    // emit event
                }
                else{
                    // no agreement in the 3 submissions
                    // send ETH to DAO
                    uint256 split = tasks[myReport.taskId].coreDetails.payment;
                    delete reports[_taskID];
                    (bool sent, bytes memory data) = owner().call{value: split}(""); // todo -- decide on how to structure DAO address
                    require(sent); // dev: "Failed to send Ether"


                    myReport.reportState = REPORTSTATE.FAILED;

                    // emit event
                }
            }
        }
    }

    //////////////////////
    ////// Util /////
    //////////////////////

    function removeElement(uint[] storage arr, uint index) internal {
        require(index < arr.length); // dev: "Index out of bounds"

        // If it's not the last element, swap with the last one
        if (index != arr.length - 1) {
            arr[index] = arr[arr.length - 1];
        }

        // Remove the last element
        arr.pop();
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