// npx hardhat test ./test/governance-test.js


const { expect } = require('chai');
const { ethers } = require('hardhat');


//async function computeHashes(values) {
//    // Step 2: Hash each value and map to a new array
//    const leafHashes = values.map(value => ethers.utils.keccak256(ethers.utils.arrayify(value)));
//
//    // Step 3: Concatenate all of the hashes together (remove the "0x" from subsequent hashes)
//    const concatenatedHashes = leafHashes.reduce((acc, hash) => acc + hash.slice(2), "0x");
//
//    // Step 4: Produce a final hash of the concatenated string
//    const finalHash = ethers.utils.keccak256(concatenatedHashes);
//
//    return {
//        leafHashes,
//        finalHash
//    };
//}

async function computeHashes(values) {
    // Step 2: Hash each value and map to a new array
    const leafHashes = values.map(value => ethers.utils.keccak256(ethers.utils.toUtf8Bytes(value)));

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
            const event = receipt.events?.find(e => e.event === 'NewTaskCreated');
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
        let taskId, task, wizardId, wizardRole, roleDetails, wizardTwoId;
        beforeEach(async () => {
            // Create a task as a precondition for acceptance tests
            await wizards.connect(owner).mint(0);
            let totalWizards = await wizards.totalSupply();
            wizardId = totalWizards.toNumber();  // Assuming the ID is a number
            wizardRole = await wizards.getRole(wizardId);
            await wizards.mint(0);
            wizardTwoId = wizardId + 1;

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
                availableSlots: 1  // Example number of slots
            };

            const tx = await governance.connect(owner).createTask(wizardId, coreDetails, timeDetails, roleDetails);
            const receipt = await tx.wait();
            const event = receipt.events?.find(e => e.event === 'NewTaskCreated');
            task = event.args.task;
            taskId = event.args.taskId;
        });

        it('Should decrease available slots when a task is accepted', async function() {
              const tx = await governance.acceptTask(taskId, wizardId);
              const receipt = await tx.wait();
//              const event = receipt.events?.find(e => e.event === 'TaskAccepted');
//              const taskId = event.args.taskId;

              const task = await governance.getTaskById(taskId);
              expect(task.roleDetails.availableSlots).to.equal(roleDetails.availableSlots - 1);
        });

        it('Should not allow a task to be accepted if no slots are available', async function() {
              const tx = await governance.acceptTask(taskId, wizardId);
              const receipt = await tx.wait();

              // Now try accepting the same task again
              await expect(governance.acceptTask(taskId, wizardTwoId)).to.be.reverted;
        });

        it('Should not allow a wizard to accept same task twice before completing it first.', async function() {
              const tx = await governance.acceptTask(taskId, wizardId);
              const receipt = await tx.wait();

              // Now try accepting the same task again
              await expect(governance.acceptTask(taskId, wizardId)).to.be.reverted;
        });

        // todo -- wizard accepts same task after completing and after timeperiod
        // todo -- wizard accepts same task after completing and but not after timeperiod -- fail

    });

    describe('Verification', function() {
        let taskId, task, wizardId, verifyingWizardId, wizardRole, roleDetails, reportId, leafHashes, finalHash, leafArray,
        contractSettings;


        beforeEach(async () => {
            contractSettings = await wizards.connect(owner).contractSettings();

            // Create a task as a precondition for acceptance tests
            await wizards.connect(owner).mint(0);
            let totalWizards = await wizards.totalSupply();
            wizardId = totalWizards.toNumber();  // Assuming the ID is a number
            wizardRole = await wizards.getRole(wizardId);

            await wizards.connect(owner).mint(0);
            verifyingWizardId = wizardId + 1;
            await wizards.initiate(wizardId, {value: contractSettings.initiationCost});
            await wizards.initiate(verifyingWizardId, {value: contractSettings.initiationCost});

            let coreDetails = {
                IPFSHash: "QmT78zSuBmuS4z925WZfrqQ1qHaJ56DQaTfyMUF7F8ff5o",  // Example IPFS hash
                state: 0,  // Assuming 0 is the initial state for your TASKSTATE enum
                numFieldsToHash: 3,  // Example value
                taskType: 1,  // Assuming 1 is a valid value for your TASKTYPE enum
                payment: ethers.utils.parseEther("0")  // 1 ETH in Wei
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

            let tx = await governance.connect(owner).createTask(wizardId, coreDetails, timeDetails, roleDetails);
            let receipt = await tx.wait();
            let event = receipt.events?.find(e => e.event === 'NewTaskCreated');
            task = event.args.task;
            taskId = event.args.taskId;

            // accept task
            tx = await governance.acceptTask(taskId, wizardId);
            receipt = await tx.wait();
            event = receipt.events?.find(e => e.event === 'TaskAccepted');
            const reportId = event.args.reportId;

            // create hash
            leafArray = ['1', '2', '3'];
            const hashes = await computeHashes(leafArray);
            leafHashes = hashes.leafHashes;
            finalHash = hashes.finalHash;


            // complete task
            const res = await governance.completeTask(reportId, finalHash, wizardId);

            // set verifier of wizards contract
//            updateVerifier
            tx = await wizards.updateVerifier(governance.address);
            await tx.wait();

        });

        it('Verification should succeed with correct values', async function() {
            let tx = await governance.claimRandomTaskForVerification(verifyingWizardId);
            let receipt = await tx.wait();
            event = receipt.events?.find(e => e.event === 'VerificationAssigned');
            reportId = event.args.reportId;

//            console.log(verifyingWizardId);
//            console.log(taskId)
//            console.log(leafHashes)
//            console.log("reportId");
//            console.log(reportId)

//            const report = await governance.getReportById(reportId);
//            console.log("report: ");
//            console.log(report)

            tx = await governance.submitVerification(verifyingWizardId, reportId, leafHashes);
            receipt = await tx.wait();
            event = receipt.events?.find(e => e.event === 'VerificationSucceeded');

            const isHashCorrect = event.args.isHashCorrect;

            expect(isHashCorrect).to.equal(true);
        });

        it('Verification should fail with incorrect values', async function() {
            console.log("A");
            let tx = await governance.claimRandomTaskForVerification(verifyingWizardId);
            let receipt = await tx.wait();
            event = receipt.events?.find(e => e.event === 'VerificationAssigned');
            reportId = event.args.reportId;

            console.log("reportId: ");
            console.log(reportId)

//            const report = await governance.getReportById(reportId);
//            console.log("report: ");
//            console.log(report)

//            console.log(verifyingWizardId);
//            console.log(taskId)
//            console.log(leafHashes)
            console.log("B");

            console.log("leaf hashes: ");
            console.log(leafHashes);
            console.log("leafArray");
            console.log(leafArray);

            const incorrectHashes = await computeHashes(['3', '2', '1']);

            tx = await governance.submitVerification(verifyingWizardId, reportId, incorrectHashes.leafHashes);
            console.log("C");

            receipt = await tx.wait();
            event = receipt.events?.find(e => e.event === 'VerificationSucceeded');

            const isHashCorrect = event.args.isHashCorrect;

            expect(isHashCorrect).to.equal(false);
        });


    it('Should not allow a report to be verified more than once', async function() {
        let tx = await governance.claimRandomTaskForVerification(verifyingWizardId);
        let receipt = await tx.wait();
        event = receipt.events?.find(e => e.event === 'VerificationAssigned');
        reportId = event.args.reportId;

        tx = await governance.submitVerification(verifyingWizardId, reportId, leafHashes);
        receipt = await tx.wait();
        event = receipt.events?.find(e => e.event === 'VerificationSucceeded');
        const isHashCorrect = event.args.isHashCorrect;


        await expect(governance.submitVerification(verifyingWizardId, reportId, leafHashes))
            .to.be.reverted;


    });


        it('Should update the report state upon successful verification', async function() {
            let tx = await governance.claimRandomTaskForVerification(verifyingWizardId);
            let receipt = await tx.wait();
            event = receipt.events?.find(e => e.event === 'VerificationAssigned');
            reportId = event.args.reportId;

            tx = await governance.submitVerification(verifyingWizardId, reportId, leafHashes);
            receipt = await tx.wait();

            const report = await governance.getReportById(reportId);

            expect(report.reportState).to.equal(3);
        });
    });

    describe('Edge Cases and Error Handling', function() {
        let wizardId;
        beforeEach(async () => {
            await wizards.connect(owner).mint(0);
            let totalWizards = await wizards.totalSupply();
            wizardId = totalWizards.toNumber();  // Assuming the ID is a number
        });

        it('Should not allow task creation with end timestamp earlier than start timestamp', async function() {
            let coreDetails = {
                IPFSHash: "QmT78zSuBmuS4z925WZfrqQ1qHaJ56DQaTfyMUF7F8ff5o",  // Example IPFS hash
                state: 0,  // Assuming 0 is the initial state for your TASKSTATE enum
                numFieldsToHash: 3,  // Example value
                taskType: 1,  // Assuming 1 is a valid value for your TASKTYPE enum
                payment: ethers.utils.parseEther("0")  // 1 ETH in Wei
            };

            let timeDetails = {
                begTimestamp: Math.floor(Date.now() / 1000) + 604801,  // Current timestamp
                endTimestamp: Math.floor(Date.now() / 1000) + 604800,  // One week from now
                waitTime: 3600,  // 1 hour in seconds
                timeBonus: 86400  // 1 day in seconds
            };

            roleDetails = {
                creatorRole: 1,  // Example role ID
                restrictedTo: 0,  // Example role ID
                availableSlots: 10  // Example number of slots
            };

            await expect(governance.connect(owner).createTask(wizardId, coreDetails, timeDetails, roleDetails)).to.be.reverted;
        });

        it('Should not allow tasks with zero available slots', async function() {
            let coreDetails = {
                IPFSHash: "QmT78zSuBmuS4z925WZfrqQ1qHaJ56DQaTfyMUF7F8ff5o",  // Example IPFS hash
                state: 0,  // Assuming 0 is the initial state for your TASKSTATE enum
                numFieldsToHash: 3,  // Example value
                taskType: 1,  // Assuming 1 is a valid value for your TASKTYPE enum
                payment: ethers.utils.parseEther("0")  // 1 ETH in Wei
            };

            let timeDetails = {
                begTimestamp: Math.floor(Date.now() / 1000),  // Current timestamp
                endTimestamp: Math.floor(Date.now() / 1000) + 604800,  // One week from now
                waitTime: 3600,  // 1 hour in seconds
                timeBonus: 86400  // 1 day in seconds
            };

            roleDetails = {
                creatorRole: 1,  // Example role ID
                restrictedTo: 0,  // Example role ID
                availableSlots: 0  // Example number of slots
            };

            await expect(governance.connect(owner).createTask(wizardId, coreDetails, timeDetails, roleDetails)).to.be.reverted;
        });


    // todo -- should not allow task for creatorRole that doesn't exist

    });

    // ... Further in-depth tests ...
});
