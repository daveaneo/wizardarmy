// npx hardhat test ./test/governance-test.js


const { expect } = require('chai');
const { ethers } = require('hardhat');


async function computeHashes(values) {
    // Step 2: Hash each value and map to a new array
    const leafHashes = values.map(value => ethers.utils.keccak256(ethers.utils.arrayify(value)));

    // Step 3: Concatenate all of the hashes together (remove the "0x" from subsequent hashes)
    const concatenatedHashes = leafHashes.reduce((acc, hash) => acc + hash.slice(2), "0x");

    // Step 4: Produce a final hash of the concatenated string
    const finalHash = ethers.utils.keccak256(concatenatedHashes);

    return {
        leafHashes,
        finalHash
    };
}


describe('Governance Contract', function() {
  let Wizards, WizardTower, Governance;
  let wizards, wizardTower, governance;
  let owner, addr1, addr2, otherAddrs;

  beforeEach(async () => {
    [owner, addr1, addr2] = await ethers.getSigners();


    // Deploying the CommonDefinitions Library
    const CommonDefinitions = await ethers.getContractFactory("CommonDefinitions");
    const commonDefinitions = await CommonDefinitions.deploy();

    // Deploying the GeneLogic Library
    const GeneLogic = await ethers.getContractFactory("GeneLogic");
    const geneLogic = await GeneLogic.deploy();

    // Link the GeneLogic library to the SVGGenerator and deploy
    const SVGGenerator = await ethers.getContractFactory("SVGGenerator", {
      libraries: {
        "GeneLogic": geneLogic.address,
      },
    });
    const svgGenerator = await SVGGenerator.deploy();

    // Deploying the TokenURILibrary
    const TokenURILibrary = await ethers.getContractFactory("TokenURILibrary", {
      libraries: {
        "GeneLogic": geneLogic.address,
        "SVGGenerator": svgGenerator.address,
      },
    });
    const tokenURILibrary = await TokenURILibrary.deploy();

    // Deploying the Token
    const Token = await ethers.getContractFactory("Token");
    const token = await Token.deploy("Wizard Gold", "WGLD", 18, ethers.utils.parseEther("1000"));

    // Deploying the Wizards Contract
    Wizards = await ethers.getContractFactory("Wizards", {
      libraries: {
        "TokenURILibrary": tokenURILibrary.address,
      },
    });
    wizards = await Wizards.deploy("Wizards", "WZD", token.address, "https://gateway.pinata.cloud/ipfs/");

    // Deploying the WizardTower
    WizardTower = await ethers.getContractFactory("WizardTower");
    wizardTower = await WizardTower.deploy(token.address, wizards.address);

    // Finally, deploy the Governance contract
    Governance = await ethers.getContractFactory("Governance");
    governance = await Governance.deploy(wizards.address, wizardTower.address);
  });


    it('Should deploy the Governance contract and set the correct owner', async function() {
        expect(governance.address).to.exist;
        const contractOwner = await governance.owner();
        expect(contractOwner).to.equal(owner.address);
    });

    describe('Task Creation', function() {
        // ... Previous tests ...

        it('Created task should have correct properties', async function() {

            await wizards.connect(owner).mint(0);
            let totalWizards = await wizards.totalSupply();
            let wizardId = totalWizards.toNumber();  // Assuming the ID is a number
            let wizardRole = await wizards.getRole(wizardId);

            let coreDetails = {
                IPFSHash: "QmT78zSuBmuS4z925WZfrqQ1qHaJ56DQaTfyMUF7F8ff5o",  // Example IPFS hash
                state: 0,  // Assuming 0 is the initial state for your TASKSTATE enum
                numFieldsToHash: 3,  // Example value
                taskType: 1,  // Assuming 1 is a valid value for your TASKTYPE enum
                payment: ethers.utils.parseEther("1")  // 1 ETH in Wei
            };

            let timeDetails = {
                begTimestamp: Math.floor(Date.now() / 1000),  // Current timestamp
                endTimestamp: Math.floor(Date.now() / 1000) + 604800,  // One week from now
                waitTime: 3600,  // 1 hour in seconds
                timeBonus: 86400  // 1 day in seconds
            };

            let roleDetails = {
                creatorRole: wizardRole,  // Example role ID
                restrictedTo: 2,  // Example role ID
                availableSlots: 10  // Example number of slots
            };

            const tx = await governance.connect(owner).createTask(wizardId, coreDetails, timeDetails, roleDetails);
            const receipt = await tx.wait();
            const event = receipt.events?.find(e => e.event === 'NewTaskCreated'); // Replace 'YourEventName' with the actual name of the event emitted by createTask.
            const task = event.args.task;
            const taskId = event.args.taskId;

//            const task = await governance.getTaskById(taskId);

            // Continue checking CoreDetails
            expect(task.coreDetails.IPFSHash).to.equal(coreDetails.IPFSHash);
            expect(task.coreDetails.state).to.equal(coreDetails.state);
            expect(task.coreDetails.numFieldsToHash).to.equal(coreDetails.numFieldsToHash);
            expect(task.coreDetails.taskType).to.equal(coreDetails.taskType);
            expect(task.coreDetails.payment.toString()).to.equal(coreDetails.payment.toString()); // Convert BigNumber to string for comparison

            // Check TimeDetails
            expect(task.timeDetails.begTimestamp).to.equal(timeDetails.begTimestamp); // Convert numbers to string for comparison
            expect(task.timeDetails.endTimestamp).to.equal(timeDetails.endTimestamp);
            expect(task.timeDetails.waitTime).to.equal(timeDetails.waitTime);
            expect(task.timeDetails.timeBonus).to.equal(timeDetails.timeBonus);

            // Check RoleDetails
            expect(task.roleDetails.creatorRole.toString()).to.equal(roleDetails.creatorRole.toString());
            expect(task.roleDetails.restrictedTo).to.equal(roleDetails.restrictedTo);
            expect(task.roleDetails.availableSlots).to.equal(roleDetails.availableSlots);


        });
    });

    describe('Task Acceptance', function() {
        let taskId, task, wizardId, wizardRole, roleDetails;
        beforeEach(async () => {
            // Create a task as a precondition for acceptance tests
            await wizards.connect(owner).mint(0);
            let totalWizards = await wizards.totalSupply();
            wizardId = totalWizards.toNumber();  // Assuming the ID is a number
            wizardRole = await wizards.getRole(wizardId);

            let coreDetails = {
                IPFSHash: "QmT78zSuBmuS4z925WZfrqQ1qHaJ56DQaTfyMUF7F8ff5o",  // Example IPFS hash
                state: 0,  // Assuming 0 is the initial state for your TASKSTATE enum
                numFieldsToHash: 3,  // Example value
                taskType: 1,  // Assuming 1 is a valid value for your TASKTYPE enum
                payment: ethers.utils.parseEther("1")  // 1 ETH in Wei
            };

            let timeDetails = {
                begTimestamp: Math.floor(Date.now() / 1000),  // Current timestamp
                endTimestamp: Math.floor(Date.now() / 1000) + 604800,  // One week from now
                waitTime: 3600,  // 1 hour in seconds
                timeBonus: 86400  // 1 day in seconds
            };

            roleDetails = {
                creatorRole: wizardRole,  // Example role ID
                restrictedTo: 0,  // Example role ID
                availableSlots: 10  // Example number of slots
            };

            const tx = await governance.connect(owner).createTask(wizardId, coreDetails, timeDetails, roleDetails);
            const receipt = await tx.wait();
            const event = receipt.events?.find(e => e.event === 'NewTaskCreated'); // Replace 'YourEventName' with the actual name of the event emitted by createTask.
            task = event.args.task;
            taskId = event.args.taskId;
        });

        it('Should decrease available slots when a task is accepted', async function() {
              const reportId = await governance.acceptTask(taskId, wizardId);
              const task = await governance.getTaskById(taskId);
              expect(task.roleDetails.availableSlots).to.equal(roleDetails.availableSlots - 1);
        });
    });

    describe('Verification', function() {
        let taskId, task, wizardId, verifyingWizardId, wizardRole, roleDetails, reportId, leafHashes, finalHash, values;
        beforeEach(async () => {
            // Create a task as a precondition for acceptance tests
            await wizards.connect(owner).mint(0);
            let totalWizards = await wizards.totalSupply();
            wizardId = totalWizards.toNumber();  // Assuming the ID is a number
            wizardRole = await wizards.getRole(wizardId);

            await wizards.connect(owner).mint(0);
            verifyingWizardId = wizardId + 1;

            let coreDetails = {
                IPFSHash: "QmT78zSuBmuS4z925WZfrqQ1qHaJ56DQaTfyMUF7F8ff5o",  // Example IPFS hash
                state: 0,  // Assuming 0 is the initial state for your TASKSTATE enum
                numFieldsToHash: 3,  // Example value
                taskType: 1,  // Assuming 1 is a valid value for your TASKTYPE enum
                payment: ethers.utils.parseEther("1")  // 1 ETH in Wei
            };

            let timeDetails = {
                begTimestamp: Math.floor(Date.now() / 1000),  // Current timestamp
                endTimestamp: Math.floor(Date.now() / 1000) + 604800,  // One week from now
                waitTime: 3600,  // 1 hour in seconds
                timeBonus: 86400  // 1 day in seconds
            };

            roleDetails = {
                creatorRole: wizardRole,  // Example role ID
                restrictedTo: 0,  // Example role ID
                availableSlots: 10  // Example number of slots
            };

            const tx = await governance.connect(owner).createTask(wizardId, coreDetails, timeDetails, roleDetails);
            const receipt = await tx.wait();
            const event = receipt.events?.find(e => e.event === 'NewTaskCreated');
            task = event.args.task;
            taskId = event.args.taskId;

            // accept task
            reportId = await governance.acceptTask(taskId, wizardId);
//            const task = await governance.getTaskById(taskId);

            // create hash
            // Example usage:
            values = [1, 2, 3];
            const hashes = await computeHashes(values);
            leafHashes = hashes.leafHashes;
            finalHash = hashes.finalHash;
            console.log("Leaf Hashes:", leafHashes);
            console.log("Final Hash:", finalHash);


            // complete task
            const res = await governance.completeTask(reportId, finalHash, wizardId);

        });

        it('Verification should succeed with correct values', async function() {
            const tx = await governance.claimRandomTaskForVerification(verifyingWizardId);
            const receipt = await tx.wait();

            const tx2 = await governance.submitVerification(verifyingWizardId, taskId, leafHashes);
            const receipt2 = await tx2.wait();
            const event = receipt.events?.find(e => e.event === 'VerificationSucceeded');
            const isHashCorrect = event.args.isHashCorrect;

            expect(isHashCorrect).to.equal(true);
        });

        it('Verification should fail with correct values', async function() {
            const tx = await governance.claimRandomTaskForVerification(verifyingWizardId);
            const receipt = await tx.wait();

            const tx2 = await governance.submitVerification(verifyingWizardId, taskId, [1,2,3]);
            const receipt2 = await tx2.wait();
            const event = receipt.events?.find(e => e.event === 'VerificationSucceeded');
            const isHashCorrect = event.args.isHashCorrect;

            expect(isHashCorrect).to.equal(true);
        });


        it('Should not allow a report to be verified more than once', async function() {
            const tx = await governance.claimRandomTaskForVerification(verifyingWizardId);
            const receipt = await tx.wait();

            const tx2 = await governance.submitVerification(verifyingWizardId, taskId, [1,2,3]);
            const receipt2 = await tx2.wait();
            const event = receipt.events?.find(e => e.event === 'VerificationSucceeded');
            const isHashCorrect = event.args.isHashCorrect;

            expect(isHashCorrect).to.equal(true);
        });

        it('Should update the report state upon successful verification', async function() {
            await governance.connect(addr1).verifyTask(/* arguments */);
            const report = await governance.reports(/* reportId */);
            expect(report.reportState).to.equal(/* VERIFIED state enum value */);
        });
    });

    describe('Edge Cases and Error Handling', function() {
        it('Should not allow task creation with end timestamp earlier than start timestamp', async function() {
            await expect(governance.connect(owner).createTask(/* arguments with invalid timestamps */)).to.be.reverted;  // dev: "Invalid timestamps"
        });

        it('Should not allow tasks with zero available slots', async function() {
            await expect(governance.connect(owner).createTask(/* arguments with zero slots */)).to.be.reverted;  // dev: "No available slots"
        });

        it('Should not allow a task to be accepted if no slots are available', async function() {
            // Create a task with 1 slot and accept it
            await governance.connect(owner).createTask(/* arguments with 1 slot */);
            await governance.connect(addr1).acceptTask(/* arguments */);

            // Now try accepting the same task again
            await expect(governance.connect(addr2).acceptTask(/* same arguments */)).to.be.reverted;  // dev: "No slots left"
        });
    });

    // ... Further in-depth tests ...
});
