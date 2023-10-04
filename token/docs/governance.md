# Governance Contract Documentation

## Overview

The Governance contract is an advanced EVM smart contract that forms the backbone of a decentralized task management system. Its primary functions are to allow users to create tasks, claim tasks for verification, and submit verifications or refutations for tasks. The contract ensures that these operations are carried out securely and transparently, using Ethereum's consensus mechanism. There are various types of tasks, which affect if they can be redone and how they are payed out. Tasks are payed out in the ecosystem token. Claiming verification requires ETH, which is refunded upon successful verification or consensus refution, which is used to prevent spam.

## Table of Contents

- [Task Creation](#task-creation)
- [Task Verification](#task-verification)
  - [Unrestricted Verification](#unrestricted-verification)
  - [Restricted Verification](#restricted-verification)
- [Task Refutation](#task-refutation)
- [Admin Settings](#admin-settings)
- [Hashing Mechanism](#hashing-mechanism)

## Task Creation

Tasks can be created by users with the appropriate permissions. Here's a typical flow:

1. The user calls the `createTask` function, passing in details about the task.
2. The function checks if the user has the appropriate permissions to create the task.
3. If all conditions are met, the task is created and stored on the blockchain.

## Task Verification

### Unrestricted Verification

1. The user calls the `claimReportToVerify` function.
2. The function checks if there are reports available for verification.
3. If a report is available, it gets assigned to the user.
4. The user then verifies the report and submits the verification using the `submitVerification` function.
5. If the reports match, the report is verified. If not, it is marked as challenged and will face one more round of verification. That round will result in three posibilities: the original report verified or being refuted--either with or without consensus.

### Restricted Verification

1. If a task has a non-zero restricteTo, then all wizards who have roles that match the creatorRole of the task can can call reports of that task by calling the `verifyRestrictedTask` function directly. There is no need to request to verify the task.


## Admin Settings

The contract owner has the ability to adjust various parameters of the system, including:

1. Setting the verification fee.
2. Adjusting the verification time.
3. Updating the task creator role.
4. And other administrative functions to ensure smooth operation of the system.

## Hashing Mechanism

The hashing mechanism is a crucial part of the system to ensure data integrity and confidentiality:

1. **Task Creation:** When a task is created, the details of the task are stored on IPFS. The address hash is stored in the task. The task also has the number of fields that will be required for submission and verification.
its details are hashed using a Keccak256 hash function, producing a unique hash that represents the task.
2. **Task Submission:** Offchain, the leaves/fields (strings as padded hex) are hashed and then the array of values is hashed. This single hash is sent into the blockchain and stored for future verification.
2. **Task Verification:** During verification, the user submits the hashed leaves. These are hashed on chain to verify the the original hash stored on the blockchain to determine if the verification is correct.
3. **Task Refutation:** If a task is refuted, unhashed leaves are sent to the blockchain. They are hashed twice and compared to the other hashes to verify if either is correct.

The use of hashing ensures that task details remain confidential, while still allowing for verification and refutation operations to be carried out transparently.

## Governance Contract Documentation

### Enums

#### TASKTYPE
- **BASIC**: Basic task type. Not repeatable. I think This may be removed because I see no difference with equal split.
- **RECURRING**: Task that allows user to repeat the task after some time period.
- **SINGLE_WINNER**: Task with a single winner. Many can claim the task, but only one will be rewarded.
- **EQUAL_SPLIT**: Task where the payment is split equally among participants. The amount is per participant per verified completion is the same regardless participants.
- **SHARED_SPLIT**: Task where the reward is shared based on contribution. The more verified completions, the less each contributer gets.

#### TASKSTATE
- **ACTIVE**: Task is currently active.
- **PAUSED**: Task has been paused.
- **ENDED**: Task has manually ended. Once ended, it can not be restarted.

#### REPORTSTATE
- **ACTIVE**: Report is currently active.
- **SUBMITTED**: Report has been submitted.
- **CHALLENGED**: Report has been challenged.
- **REFUTED_CONSENSUS**: Report has been refuted with consensus -- both refuters had same hash.
- **REFUTED_DISAGREEMENT**: Report has been refuted with disagreement -- no common hash.
- **VERIFIED**: Report has been verified.

### Structs

#### TimeDetails
- `begTimestamp`: Start timestamp.
- `endTimestamp`: End timestamp. Must be after betTimeStamp
- `waitTime`: Time in seconds each wizard must wait before redoing task. 0 -> can no redo.
- `timeBonus`: Time added to Wizard's protectedUntil.

#### RoleDetails
- `creatorRole`: RoleId of the task creator.
- `restrictedTo`: Role that can perform this task. 0 means no restriction.
- `availableSlots`: Remaining slots available for claiming task.

#### CoreDetails
- `IPFSHash`: Hash which contains the detailed task data.
- `state`: Current state of the task, using TASKSTATE.
- `numFieldsToHash`: Number of fields to hash.
- `taskType`: Type of the task, using TASKTYPE.
- `payment`: Payment amount, in ecosystemToken.

#### Task
- Contains `TimeDetails`, `RoleDetails`, and `CoreDetails` structs.

#### Report
- `reportState`: State of the report using REPORTSTATE.
- `reporterID`: ID of the reporter -- the person who completed the task.
- `verifierID`: ID of the verifier.
- `refuterID`: ID of the first refuter.
- `hash`: Hashed input to be validated.
- `refuterHash`: Correct hash according to refuter.
- `taskId`: Task ID corresponding to the report.
- `verificationReservedTimestamp`: Timestamp when the verification period ends. If it ends without action from the verifier, the verifier loses their verification payment and the report goes back to the queue. todo -- More details needed about how verifierId changes in this situation.

### Events

#### NewTaskCreated
- Emitted when a new task is created.
- Parameters: `taskId`, `task`

#### TaskAccepted
- Emitted when a task is accepted by a wizard.
- Parameters: `reportId`, `taskId`, `wizardId`

#### TaskCompleted
- Emitted when a task is completed by a wizard.
- Parameters: `wizardId`, `reportId`, `taskId`

#### VerificationAssigned
- Emitted when a verification task is assigned to a user.
- Parameters: `wizardId`, `reportId`

#### VerificationSubmitted
- Emitted when the verification is submitted.
- Parameters: `VerifierId`, `reportId`, `reportState`

#### TaskManuallyEnded
- Emitted when a task is forcibly ended.
- Parameters: `taskId`
