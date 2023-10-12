# Governance Contract Documentation

## Introduction

The Governance contract is an advanced EVM smart contract that forms the backbone of a decentralized task management system. Its primary functions are to allow users to create tasks, claim tasks for verification, and submit verifications or refutations for tasks. The contract ensures that these operations are carried out securely and transparently, using Ethereum's consensus mechanism. There are various types of tasks, which affect if they can be redone and how they are payed out. Tasks are payed out in the ecosystem token. Claiming verification requires ETH, which is refunded upon successful verification or consensus refution, which is used to prevent spam.

## Table of Contents

- [Introduction](#introduction)
- [Enums](#enums)
- [Structs](#structs)
  - [TimeDetails](#timedetails)
  - [RoleDetails](#roledetails)
  - [CoreDetails](#coredetails)
  - [Task](#task)
  - [Report](#report)
- [Events](#events)
- [Workflow](#workflow)
  - [Task Creation ](#task-creation)
  - [Accepting and Submitting Tasks](#accepting-and-submitting-tasks)
    - [Unrestricted](#unrestricted)
    - [With RestrictedTo](#with-restrictedto)
  - [Report Verification](#report-verification)
    - [Unrestricted](#unrestricted-verification)
    - [With RestrictedTo](#restricted-verification)
- [Workflow](#workflow)
  - [Creating Tasks](#creating-tasks)
  - [Admin/Owner Settings](#adminowner-settings)
- [Admin Settings](#admin-settings)
- [Hashing Mechanism](#hashing-mechanism)

## Enums

[//]: # (REMOVED)

[//]: # (### TASKTYPE)

[//]: # ()
[//]: # (- **BASIC**: Basic task type. Not repeatable. This may be removed because there's no difference with equal split.)

[//]: # (- **RECURRING**: Task that allows user to repeat the task after some time period.)

[//]: # (- **SINGLE_WINNER**: Task with a single winner. Many can claim the task, but only one will be rewarded.)

[//]: # (- **EQUAL_SPLIT**: Task where the payment is split equally among participants. The amount per participant per verified completion is the same regardless of participants.)

[//]: # (- **SHARED_SPLIT**: Task where the reward is shared based on contribution. The more verified completions, the less each contributor gets.)


### TASKSTATE

- **ACTIVE**: Task is currently active.
- **PAUSED**: Task has been paused.
- **ENDED**: Task has manually ended. Once ended, it cannot be restarted.

### REPORTSTATE

- **ACTIVE**: Report is currently active.
- **SUBMITTED**: Report has been submitted.
- **CHALLENGED**: Report has been challenged.
- **REFUTED_CONSENSUS**: Report has been refuted with consensus — both refuters had the same hash.
- **REFUTED_DISAGREEMENT**: Report has been refuted with disagreement — no common hash.
- **VERIFIED**: Report has been verified.

## Structs

### TimeDetails

- `begTimestamp`: Start timestamp.
- `endTimestamp`: End timestamp. Must be after `begTimeStamp`.
- `waitTime`: Time in seconds each wizard must wait before redoing the task. 0 -> cannot redo.
- `timeBonus`: Time added to Wizard's `protectedUntil`.

### RoleDetails

- `creatorRole`: RoleId of the task creator.
- `restrictedTo`: Role that can perform this task. 0 means no restriction.
- `availableSlots`: Remaining slots available for claiming the task.

### CoreDetails

- `IPFSHash`: Hash which contains the detailed task data.
- `state`: Current state of the task, using `TASKSTATE`.
- `numFieldsToHash`: Number of fields to hash.
- `taskType`: Type of the task, using `TASKTYPE`.
- `payment`: Payment amount, in ecosystemToken.

### Task

Combines `TimeDetails`, `RoleDetails`, and `CoreDetails` structs.

### Report

- `reportState`: State of the report using `REPORTSTATE`.
- `reporterID`: ID of the reporter — the person who completed the task.
- `verifierID`: ID of the verifier.
- `refuterID`: ID of the first refuter.
- `hash`: Hashed input to be validated.
- `refuterHash`: Correct hash according to refuter.
- `taskId`: Task ID corresponding to the report.
- `verificationReservedTimestamp`: Timestamp when the verification period ends. If it ends without action from the verifier, the verifier loses their verification payment and the report goes back to the queue. TODO: More details needed about how `verifierId` changes in this situation.

## Events

### NewTaskCreated

- Emitted when a new task is created.
- Parameters: `taskId`, `task`.

### TaskAccepted

- Emitted when a task is accepted by a wizard.
- Parameters: `reportId`, `taskId`, `wizardId`.

### TaskCompleted

- Emitted when a task is completed by a wizard.
- Parameters: `wizardId`, `reportId`, `taskId`.

### VerificationAssigned

- Emitted when a verification task is assigned to a user.
- Parameters: `wizardId`, `reportId`.

### VerificationSubmitted

- Emitted when the verification is submitted.
- Parameters: `VerifierId`, `reportId`, `reportState`.

### TaskManuallyEnded

- Emitted when a task is forcibly ended.
- Parameters: `taskId`.

## Workflow

### Task Creation

Tasks can be created by users with appropriate permissions. The flow is as follows:

1. The user calls the `createTask` function, passing in details about the task. Enough information needs to be included in both the IPFS and in the fields so that wizards can fully complete tasks and other wizards can find and verify those tasks. No other information will be given except what is presented here.
   2. Example
      3. IPFS: share http://www.wizards.club on twitter with hashtag #WAD and include WIZARD414 (or whatever your ID is).
      4. Fields: 1, link.

3. The function checks if the user has the appropriate permissions to create the task.
3. If all conditions are met, the task is created and stored on the blockchain.



### Accepting and Submitting Tasks

Tasks are the primary entities that users interact with. Depending on the task's configuration, the process to accept and submit tasks can vary.

#### Unrestricted

For tasks that do not have role-based restrictions:

1. **Claiming a Task**: Any user can claim an unrestricted task by calling the `claimTask` function.
2. **Submitting a Task**: After completing the task, the user submits the task using the `submitTask` function. The submission typically includes a hashed representation of the task output or result.
3. **Verification**: Once submitted, the task enters the verification phase where other users can verify the correctness of the task submission. If the submission is verified successfully, the task is marked as completed, and the user is rewarded.

#### With RestrictedTo

For tasks that have specific role-based restrictions:

1. **Claiming a Task**: Only users with a matching role (as defined in the `restrictedTo` field of the task) can claim the task. This is ensured by the smart contract which checks the role of the user against the `restrictedTo` field.
2. **Submitting a Task**: Similar to unrestricted tasks, after completing the task, the user submits the task using the `submitTask` function. The submission typically includes a hashed representation of the task output or result.
3. **Verification**: The verification phase is similar to unrestricted tasks. Other users verify the correctness of the task submission. If verified successfully, the task is marked as completed, and the user is rewarded.

Remember, tasks with `restrictedTo` set to 0 are considered unrestricted, meaning any user can claim them.



### Report Verification

#### Unrestricted Verification

1. The user calls the `claimReportToVerify` function.
2. The function checks if there are reports available for verification.
3. If a report is available, it's assigned to the user.
4. The user then verifies the report and submits the verification using the `submitVerification` function.
5. If the reports match, the report is verified. If not, it's marked as challenged and will face one more round of verification. That round results in three possibilities: the original report is verified, or it's refuted—either with or without consensus.

#### Restricted Verification

1. If a task has a non-zero `restricteTo`, then all wizards with roles that match the `creatorRole` of the task can directly call reports of that task by calling the `verifyRestrictedTask` function. There's no need to request to verify the task.

## Admin Settings

The contract owner can adjust various parameters of the system to ensure the smooth operation of the platform:

1. **Setting the Verification Fee**: Adjust the verification fee using the `setVerificationFee` function.
2. **Adjusting the Verification Time**: Adjust the verification time duration using the `setVerificationTime` function.
3. **Updating the Task Creator Role**: Set roles authorized to create tasks with the `setTaskCreatorRole` function.
4. **Manually Ending a Task**: If necessary, end a task using the `endTask` function.
5. **Adjusting Processed Claimed Reports**: Set the number of claimed reports to process using the `setClaimedReportsToProcess` function.

## Hashing Mechanism

The hashing mechanism ensures data integrity and confidentiality:

### Overview 
Data is hashed to conceal its content so that it can be verified later. The data has four stages:

        dataArray, -- the data
        concatenatedHexValues, -- hexlified, padded, and combined version of the dataArray, resulting in a single string
        firstHash, -- a keccack256 hash of concatenatedHexValues
        secondHash -- a keccack256 hash of firstHash

### Processes
1. **Task Creation**: Store task details on IPFS. The address hash is then stored in the task. The task also specifies the number of fields required for submission and verification.
2. **Task Accepted**:  No hashing needed.
3. **Task Submission**: Off-chain, pad and hash the leaves/fields into a single bytes string. Then hash the string twice. This resulting hash (secondHash) is sent to the blockchain for storage and future verification.
4. **Task Verification**: During verification, submit the hashed leaves (firstHash). These are hashed on-chain and compared to the original stored hash to determine if the verification is correct.
5. **Task Refutation**: If refuted, unhashed leaves (concatenatedHexValues) are sent to the blockchain where they are hashed twice, and compared to other hashes to determine if either is correct.

Hashing ensures that task details remain confidential, while still allowing verification and refutation operations to be transparent.
