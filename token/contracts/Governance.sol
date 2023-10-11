pragma solidity 0.8.15;
// SPDX-License-Identifier: Unlicensed

import "./helpers/console.sol";

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

// todo add nonreentrant guard
// todo -- dApp -- add verified social media so as to better track. These get wiped with wizard transfers.

interface IAppointer {
    function canRoleCreateTasks(uint256 _roleId) external view returns(bool);
    function numRoles() external view returns(uint256);
}

contract Governance is ReentrancyGuard, Ownable {

    /// thoughts wizardGold -> payments, ETH -> task verification
    IERC20  ecosystemTokens;
    Wizards wizardsNFT;
    WizardTower wizardTower;
    IAppointer public appointer;
    address public DAOAddres;

//    enum TASKTYPE {BASIC, RECURRING, SINGLE_WINNER, EQUAL_SPLIT, SHARED_SPLIT}
    enum TASKSTATE { ACTIVE, PAUSED, ENDED }
    enum REPORTSTATE { ACTIVE, SUBMITTED, CHALLENGED, REFUTED_CONSENSUS, REFUTED_DISAGREEMENT, VERIFIED }

    struct TimeDetails {
        uint40 begTimestamp;
        uint40 endTimestamp;
        uint24 waitTime;
        uint24 timeBonus;
    }

    struct RoleDetails {
        uint16 creatorRole;
        uint16 restrictedTo; // roles that can do this task. 0 means no restriction
        uint16 availableSlots;
    }

    struct CoreDetails {
        string IPFSHash; // holds description
        TASKSTATE state;
        uint8 numFieldsToHash;
//        TASKTYPE taskType; // removed for simplicity
        uint128 reward;
        uint128 verificationFee;
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
        uint16 refuterID; // wizardId of first Refuter
        uint16 secondRefuterID; // wizardId of second Refuter
        bytes32 hash; // hashed input to be validated
        bytes32 refuterHash; // correct hash according to refuter
        uint128 taskId;
        uint40 verificationReservedTimestamp; // time when verification period ends
    }

    uint256[] public reportsWaitingConfirmation; // allows random selection of confirmation
    DoubleEndedQueue.Bytes32Deque public reportsClaimedForConfirmation; //  time-sorted queue

    // This mapping holds the next active time thresholds for each task.
    // The outer mapping uses the task ID as the key.
    // The inner mapping uses a uint40 (presumably a timestamp or similar) as the key,
    // mapping to a uint256 value that represents the threshold.
    // task -> wizard -> timestamp
    mapping (uint256 => mapping(uint256 => uint256)) internal nextEligibleTime; // todo -- compare performance if change mapping uint256 to less
    mapping(uint256 => Task) public tasks;
    mapping (uint256 => Report) public reports;

    uint256 public tasksCount;
    uint256 public reportsCount;

    uint256 immutable verificationTime = 30*60; // 30 minutes

    uint16 CLAIMED_REPORTS_TO_PROCESS = 5; // max claimed reports/iterations to process
    uint40 taskVerificationTimeBonus = 1 days; // 1 day
    uint128 verificationFee = 10**9;


    /// @notice Emitted when a new task is created.
    /// @param task The new task that was created.
    event NewTaskCreated(uint256 taskId, Task task);

    /// @notice Emitted when a task is accepted by a wizard.
    /// @param reportId ID of the report associated with the accepted task.
    /// @param taskId ID of the accepted task.
    /// @param wizardId ID of the wizard who accepted the task.
    event TaskAccepted(uint256 indexed reportId, uint256 indexed taskId, uint40 indexed wizardId);

    /// @notice Emitted when a task is completed by a wizard.
    /// @param wizardId ID of the wizard who completed the task.
    /// @param reportId ID of the completed task.
    event TaskCompleted(uint256 indexed wizardId, uint256 indexed reportId, uint256 indexed taskId);

     /// @notice Emitted when a verification is assigned to a wizard for a task.
    /// @param wizardId ID of the wizard to whom the verification is assigned.
    /// @param reportId The report id associated with the verification assignment.
    event VerificationAssigned(uint256 indexed wizardId, uint256 reportId);

    /// @notice Emitted when the verification process succeeds.
    /// @param VerifierId ID of the verifying wizard.
    /// @param reportId ID of the verified task.
    /// @param reportState state of the report after verification attempt.
    event VerificationSubmitted(uint256 indexed VerifierId, uint256 indexed reportId, REPORTSTATE reportState);

    /// @notice Emitted when a task is forcibly ended
    /// @param taskId The id of the task that has ended.
    event TaskManuallyEnded(uint256 taskId);




    /////////////////////////////
    //////  Temp Functions ///////
    /////////////////////////////

//    /**
//     * @notice Returns the number of reports currently in the claimed dequeue.
//     * @return The number of reports in the claimed for confirmation queue.
//     */
//    function reportsClaimedForConfirmationLength() external view returns (uint256) {
//        return DoubleEndedQueue.length(reportsClaimedForConfirmation);
//    }
//
//
//    /**
//     * @notice Returns the number of at position n in the claimed dequeue.
//     * @return The value of the queue at position n.
//     */
//    function reportsClaimedForConfirmationValue(uint256 n) external view returns (uint256) {
//        require(n < DoubleEndedQueue.length(reportsClaimedForConfirmation), "invalid pos in deque.");
//        return uint256(DoubleEndedQueue.at(reportsClaimedForConfirmation, n));
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
        return wizardsNFT.isActive(_wizId) && appointer.canRoleCreateTasks(roleId);
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


    /**
     * @notice Returns the number of reports currently waiting for confirmation.
     * @return The number of reports in the waiting confirmation array.
     */
    function reportsWaitingConfirmationLength() external view returns (uint256) {
        return reportsWaitingConfirmation.length;
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
        appointer = IAppointer(_addy);
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
            // todo endTaskCleanup(_taskId); -- pay task doers?
            emit TaskManuallyEnded(_taskId);
        }
    }


    /**
     * @notice Set the value for CLAIMED_REPORTS_TO_PROCESS.
     * @param _value The new value for CLAIMED_REPORTS_TO_PROCESS.
     */
    function setClaimedReportsToProcess(uint16 _value) external onlyOwner {
        require(CLAIMED_REPORTS_TO_PROCESS != _value);
        CLAIMED_REPORTS_TO_PROCESS = _value;
    }

    /**
     * @notice Set the value for taskVerificationTimeBonus.
     * @param _value The new value for taskVerificationTimeBonus in seconds.
     */
    function setTaskVerificationTimeBonus(uint40 _value) external onlyOwner {
        require(taskVerificationTimeBonus != _value);
        taskVerificationTimeBonus = _value;
    }

    /**
     * @notice Set the value for verificationFee.
     * @param _value The new value for verificationFee.
     */
    function setVerificationFee(uint128 _value) external onlyOwner {
        require(verificationFee != _value);
        verificationFee = _value;
    }


    /**
     * @notice Set the value for the DAO address.
     * @param _DAOAddress The new DAO Address for verificationFee.
     */
    function setDAOAddress(address _DAOAddress) external onlyOwner {
        require(_DAOAddress != DAOAddres);
        DAOAddres = payable(_DAOAddress);
    }


    //////////////////////////////
    //////  Main Functions ///////
    //////////////////////////////

    /** @dev Constructor for HOADAO
        @param _nft -- contract address for NFTs
      */
    constructor(address _erc20, address _nft, address _wizardTower, address _appointer){
        ecosystemTokens = IERC20(_erc20);
        wizardsNFT = Wizards(_nft);
        wizardTower = WizardTower(_wizardTower);
        appointer = IAppointer(_appointer);
        DAOAddres = payable(msg.sender);
    }

    // Required to receive ETH
    receive() external payable {
    }

    function createTask(
        uint256 _wizardId,
        CoreDetails calldata coreDetails,
        TimeDetails calldata timeDetails,
        RoleDetails calldata roleDetails
    ) external  onlyTaskCreators(_wizardId)   {
        require(
            timeDetails.endTimestamp > timeDetails.begTimestamp // dev: must begin before it ends
            && roleDetails.creatorRole !=0 &&  roleDetails.creatorRole <= appointer.numRoles() // dev: must be vaild creatorRole
            && roleDetails.availableSlots != 0 // dev: must have non-zero slots
            && coreDetails.numFieldsToHash < 9 // We need to keep this small because of for loops for confirming refuter
        );

        if(coreDetails.reward != 0){
            // Ensure that the sender has approved this contract to move the payment amount on their behalf
            require(
                IERC20(ecosystemTokens).allowance(msg.sender, address(this)) >= coreDetails.reward * roleDetails.availableSlots,
                "Token allowance not sufficient"
            );

            // Transfer the payment amount from the sender to this contract (or wherever you intend)
            require(
                IERC20(ecosystemTokens).transferFrom(msg.sender, address(this), coreDetails.reward * roleDetails.availableSlots),
                "Token transfer failed"
            );
        }

        tasksCount++;

        tasks[tasksCount] = Task({
            coreDetails: coreDetails,
            timeDetails: timeDetails,
            roleDetails: roleDetails
        });

        // Override specific parameters after copying from arguments
        tasks[tasksCount].coreDetails.state = coreDetails.state == TASKSTATE.PAUSED ? TASKSTATE.PAUSED : TASKSTATE.ACTIVE;
        tasks[tasksCount].coreDetails.verificationFee = verificationFee;
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
    function acceptTask(uint256 _taskId, uint16 _wizId) onlyWizardOwner(_wizId) external payable returns(uint256) {
        require(_taskId <= tasksCount && _taskId != 0, "invalid task"); // dev: invalid task
        // Ensure that the sent ETH matches the verificationFee
        require(msg.value >= tasks[_taskId].coreDetails.verificationFee, "Incorrect ETH amount sent.");

        Task memory myTask = tasks[_taskId];

        // Make sure the wizard is eligible
        uint16 wizRole = uint16(wizardsNFT.getRole(_wizId));
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

        // reimburse extra ETH -- this is because vericationFee will change and we won't know how much to send.

        if (msg.value > tasks[_taskId].coreDetails.verificationFee){
            (bool sent, bytes memory data) = msg.sender.call{value: msg.value - tasks[_taskId].coreDetails.verificationFee}("");
            require(sent, "sending failed"); // dev: "Failed to send Ether"
        }

        // Create a report and emit the event
        return createReport(_wizId, _taskId);
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

        // if this is restrictedTo -- and can only be approved by one role -- do not put into the confirmation queue
        // tasks that are restricted are confirmed directly, passing over the selection queue
        if (tasks[reports[_reportId].taskId].roleDetails.restrictedTo == 0){
            reportsWaitingConfirmation.push(_reportId);
        }

        emit TaskCompleted(_wizId, _reportId, reports[_reportId].taskId);
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

    /// @notice Allows a wizard to claim a random task for verification.
    /// @dev The function ensures the caller is not a contract, randomly selects a report for verification,
    /// moves the report from reportsWaitingConfirmation to reportsClaimed, and updates the verifierID of the report.
    /// @param _wizId The ID of the wizard claiming the task for verification.
    function claimReportToVerify(uint256 _wizId) external payable onlyWizardOwner(_wizId) /*nonReentrant*/ {
        // Ensure the caller is not a contract
        require(tx.origin == msg.sender,"Contracts are not allowed to claim tasks." ); // dev: "Contracts are not allowed to claim tasks."

        // Ensure that the sent ETH matches the verificationFee
        require(msg.value == verificationFee, "Incorrect ETH amount sent.");

        // process reports
        processReportsClaimedForConfirmation(CLAIMED_REPORTS_TO_PROCESS);

        require(reportsWaitingConfirmation.length > 0, "no reports to claim"); // dev: "No tasks available for verification."

        // Implement randomness - for simplicity, using blockhash and modulo. In a real-world scenario, consider a more robust method.
        uint256 randomIndex = uint256(keccak256(abi.encodePacked(blockhash(block.number - 1), _wizId))) % reportsWaitingConfirmation.length;
        uint256 reportId = reportsWaitingConfirmation[randomIndex];

        Report storage myReport = reports[reportId];
        require(myReport.reporterID != _wizId && myReport.refuterID != _wizId, "Wizard is not allowed to verify/refute their own task."); // dev: "Wizard is not allowed to verify/refute their own task."

        // Update the report's verifierID and move it from one queue to another
        myReport.verifierID = uint16(_wizId);
        myReport.verificationReservedTimestamp = uint40(block.timestamp + verificationTime);

        // place into queue for processing
        DoubleEndedQueue.pushBack(reportsClaimedForConfirmation, bytes32(reportId));
        // remove from current queue
        removeElement(reportsWaitingConfirmation, randomIndex);

        emit VerificationAssigned(_wizId, reportId);
    }

    /**
     * @notice Allows a wizard with a specific role to verify a report for a restricted task.
     * @dev Only the owner of the specified wizard can call this function, and the wizard must have the same role as the creator of the task.
     * @param _wizId The ID of the wizard performing the verification.
     * @param _reportId The ID of the report being verified.
     * @param approve If `true`, the report is approved; otherwise, it is failed.
     */
    function verifyRestrictedTask(uint256 _wizId, uint256 _reportId, bool approve) onlyWizardOwner(_wizId) external /*nonReentrant*/ {
        Report storage myReport = reports[_reportId];
        require(tasks[myReport.taskId].roleDetails.creatorRole == wizardsNFT.getRole(_wizId)); // dev: wizard must have role of assigned task
        uint256 reward = tasks[myReport.taskId].coreDetails.reward;
        if (approve){
            myReport.reportState = REPORTSTATE.VERIFIED;
            // send ecosystem tokens
            if (reward > 0 ){
                require(
                    IERC20(ecosystemTokens).transfer(wizardsNFT.ownerOf(myReport.reporterID), reward),
                    "Token transfer failed"
                );
            }
            emit VerificationSubmitted(_wizId, _reportId, REPORTSTATE.VERIFIED);
        }
        else{
            myReport.reportState = REPORTSTATE.REFUTED_CONSENSUS;
            emit VerificationSubmitted(_wizId, _reportId, REPORTSTATE.REFUTED_CONSENSUS);
        }
    }


    /**
     * @notice Processes reports that have been claimed for confirmation, up to a maximum number.
     * @dev Iterates through reportsClaimedForConfirmation and handles them based on their REPORTSTATE.
     * If the verificationReservedTimestamp of a report has expired, it processes the report and moves it to reportsWaitingConfirmation.
     * It will process up to the smaller of 'n' reports or the total length of reportsClaimedForConfirmation.
     * @param n The maximum number of reports to process from the reportsClaimedForConfirmation array.
     */
    function processReportsClaimedForConfirmation(uint256 n) public /*nonReentrant*/ {
        uint256 totalReportsClaimed = DoubleEndedQueue.length(reportsClaimedForConfirmation);
        uint256 toProcess = n < totalReportsClaimed ? n : totalReportsClaimed;
        uint256 processed = 0;

        while (processed < toProcess && !DoubleEndedQueue.empty(reportsClaimedForConfirmation)) {
            uint256 reportId = uint256(DoubleEndedQueue.front(reportsClaimedForConfirmation));
            Report storage report = reports[reportId];

            // If the report's verification timestamp hasn't passed yet, break out of the loop
            if (report.reportState == REPORTSTATE.REFUTED_CONSENSUS
                || report.reportState == REPORTSTATE.REFUTED_DISAGREEMENT
                || report.reportState == REPORTSTATE.VERIFIED
            ){
                // Remove the front element from reportsClaimedForConfirmation
                DoubleEndedQueue.popFront(reportsClaimedForConfirmation);
            }
            else if(report.reportState == REPORTSTATE.CHALLENGED && report.verifierID == 0){
                // Remove the front element from reportsClaimedForConfirmation
                DoubleEndedQueue.popFront(reportsClaimedForConfirmation);
                reportsWaitingConfirmation.push(reportId);
            }
            else if (block.timestamp >= report.verificationReservedTimestamp) {
                // Remove the front element from reportsClaimedForConfirmation
                DoubleEndedQueue.popFront(reportsClaimedForConfirmation);
                handleReportPastDeadline(reportId);
            }
            else {
                break;
            }

            unchecked {
                processed++;
            }
        }
    }


    // Dummy function handlers for each state. You should replace these with actual implementations.
    function handleReportPastDeadline(uint256 reportId) internal {
        // Implementation for handling SUBMITTED state
        reportsWaitingConfirmation.push(reportId);
        address payable receiver = payable(msg.sender==wizardsNFT.ownerOf(reports[reportId].verifierID) ? owner() : msg.sender);
        (bool sent, bytes memory data) = receiver.call{value: tasks[reports[reportId].taskId].coreDetails.verificationFee}("");
        require(sent, "sending failed"); // dev: "Failed to send Ether"
    }

    function handleVerifiedReport(uint256 _wizId, uint256 _reportId) internal {
        Report storage myReport = reports[_reportId];
        // if refuterId exists, then refuter gets no refund
        uint256 feeSplit = myReport.refuterID == 0 ? tasks[myReport.taskId].coreDetails.verificationFee : tasks[myReport.taskId].coreDetails.verificationFee * 3 /2;
        address payable taskSubmitter = payable(wizardsNFT.ownerOf(myReport.reporterID));

        wizardsNFT.increaseProtectedUntilTimestamp(myReport.reporterID, tasks[myReport.taskId].timeDetails.timeBonus);
        wizardsNFT.increaseProtectedUntilTimestamp(myReport.verifierID, taskVerificationTimeBonus);
        myReport.reportState = REPORTSTATE.VERIFIED;
        uint256 reward = tasks[myReport.taskId].coreDetails.reward;

        if(feeSplit > 0){
            // send to task submitter
            (bool sent, bytes memory data) = taskSubmitter.call{value: feeSplit}("");
            require(sent, "sending failed"); // dev: "Failed to send Ether"

            // send to verifier
            (sent, data) = msg.sender.call{value: feeSplit}("");
            require(sent, "sending failed"); // dev: "Failed to send Ether"
        }

        // send ecosystem tokens
        if (reward > 0 ){
            require(
                IERC20(ecosystemTokens).transfer(wizardsNFT.ownerOf(myReport.reporterID), reward),
                "Token transfer failed"
            );
        }

        emit VerificationSubmitted(_wizId, _reportId, myReport.reportState);
    }

    function handleRefutedConvergenceReport(uint256 _secondRefuterId, uint256 _reportId) internal {
        Report storage myReport = reports[_reportId];
        uint256 split = tasks[myReport.taskId].coreDetails.verificationFee*3/2;
        address payable firstRefuter = payable(wizardsNFT.ownerOf(myReport.refuterID));

        myReport.verifierID = 0;
        myReport.secondRefuterID = uint16(_secondRefuterId);

        wizardsNFT.increaseProtectedUntilTimestamp(myReport.refuterID, taskVerificationTimeBonus);
        wizardsNFT.increaseProtectedUntilTimestamp(_secondRefuterId, taskVerificationTimeBonus);

        if(split > 0 ){
            // send to task submitter
            (bool sent, bytes memory data) = firstRefuter.call{value: split}("");
            require(sent, "sending failed"); // dev: "Failed to send Ether"

            // send to verifier
            (sent, data) = msg.sender.call{value: split}("");
            require(sent, "sending failed"); // dev: "Failed to send Ether"
        }
        myReport.reportState = REPORTSTATE.REFUTED_CONSENSUS;
        emit VerificationSubmitted(_secondRefuterId, _reportId, myReport.reportState);
    }

    function handleRefutedDisagreementReport(uint256 _secondRefuterId, uint256 _reportId) internal {
        Report storage myReport = reports[_reportId];

        myReport.verifierID = 0;
        myReport.secondRefuterID = uint16(_secondRefuterId);

        // send ETH to DAO
        uint256 split = tasks[myReport.taskId].coreDetails.verificationFee *3;
        if(split > 0){
            (bool sent, bytes memory data) = DAOAddres.call{value: split}("");
            require(sent, "sending failed"); // dev: "Failed to send Ether"
        }

        myReport.reportState = REPORTSTATE.REFUTED_DISAGREEMENT;
        emit VerificationSubmitted(_secondRefuterId, _reportId, myReport.reportState);
    }


    function handleChallengedReport(uint256 _refuterId, uint256 _reportId, bytes32 myHash) internal {
        Report storage myReport = reports[_reportId];
        myReport.refuterID=uint16(_refuterId);
        myReport.refuterHash=myHash;
        myReport.reportState = REPORTSTATE.CHALLENGED;
        myReport.verifierID = 0;

        // report is now in the queue and we have to wait until enough time is cleared.
        // processReportsClaimedForConfirmation(CLAIMED_REPORTS_TO_PROCESS);
        emit VerificationSubmitted(_refuterId, _reportId, myReport.reportState);
    }


    // If submitted, we send in hashed leaves. The result is that it is either verified or refuted
    // if refuted, we send in NON-hashed leaves. The result is that it is either verified, or failed. Failed has two possibilities, two refuters agree (they split funds) or all disagree
    // @dev -- hash structure: leaves of merkle tree are hashed. Unrefuted reports must send in hashed leafs. Refuted, unhashed.
    function submitVerification(uint256 _wizId, uint256 _reportId, bytes memory _Hash) onlyWizardOwner(_wizId) /*nonReentrant*/ external {
        Report storage myReport = reports[_reportId];
        require(
            (myReport.reportState == REPORTSTATE.SUBMITTED || myReport.reportState == REPORTSTATE.CHALLENGED)
            && myReport.verificationReservedTimestamp > block.timestamp
            && myReport.verifierID == _wizId
        );

        // we need to make sure the right wizard is verifying it

        // single hash if not challenged, doublehash otherwise
        bytes32 myHash = (myReport.reportState == REPORTSTATE.CHALLENGED)
            ? keccak256(abi.encodePacked(keccak256(abi.encodePacked(_Hash)))) : keccak256(abi.encodePacked(_Hash));


        bool reportVerified = (myReport.hash == myHash);
        bool reportNotChallenged = (myReport.reportState == REPORTSTATE.SUBMITTED);
        bool hashMatchesRefuter = (myReport.refuterHash == myHash);

        if (reportVerified) {
            handleVerifiedReport(_wizId, _reportId);
        } else if (reportNotChallenged) {
            handleChallengedReport(_wizId, _reportId, myHash);
        } else if (hashMatchesRefuter) {
            handleRefutedConvergenceReport(_wizId, _reportId);
        } else {
            handleRefutedDisagreementReport(_wizId, _reportId);
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
        require(wizardsNFT.ownerOf(tokenId) == msg.sender, "not owner of wizard"); // dev: "Caller is not the owner of this NFT"
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