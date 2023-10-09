// npx hardhat test ./test/governance-test.js


const { expect } = require('chai');
const { ethers } = require('hardhat');

const verificationFee = ethers.BigNumber.from(10**9);

//
//async function computeHashes(values) {
//    let paddedValues = [];  // Array to store the padded values
//
//    // Pad each value to the desired byte length and then hash it
//    const leafHashes = values.map(value => {
//        let paddedValue = ethers.utils.hexZeroPad(ethers.utils.hexlify(ethers.BigNumber.from(value)), 32);
//        paddedValues.push(paddedValue);  // Add the padded value to the array
//        return ethers.utils.keccak256(paddedValue);
//    });
//
//    // Concatenate all of the hashes together (remove the "0x" from subsequent hashes)
//    const concatenatedHashes = leafHashes.reduce((acc, hash) => acc + hash.slice(2), "0x");
//
//    // Produce a final hash of the concatenated string
//    const finalHash = ethers.utils.keccak256(concatenatedHashes);
//
//    return {
//        paddedValues,
//        leafHashes,
//        finalHash
//    };
//}


async function computeHashes(values) {
    // Convert each value to a hex string and concatenate them together
    const paddedValues = values.reduce((acc, value) => {
        return acc + ethers.utils.hexZeroPad(ethers.utils.hexlify(ethers.BigNumber.from(value)), 32).slice(2);
    }, "0x");

    // Generate the first hash from the concatenated hex string
    const leafHashes = ethers.utils.keccak256(paddedValues);

    // Generate the second hash from the first hash
    const finalHash = ethers.utils.keccak256(leafHashes);

    return {
        paddedValues,
        leafHashes,
        finalHash
    };

    // todo -- adjust to this naming convention
    //    return {
    //        concatenatedHexValues,
    //        firstHash,
    //        secondHash
    //    };

}



const advanceTime = async (seconds) => {
    await network.provider.send("evm_increaseTime", [seconds])
    await ethers.provider.send("evm_mine");
};


describe('Governance Contract', function() {
  let Wizards, WizardTower, Governance, Appointer, Token;
  let wizards, wizardTower, governance, appointer, token;
  let owner, addr1, addr2, addr3, addr4, otherAddrs;

  beforeEach(async () => {
    [owner, addr1, addr2, addr3, addr4] = await ethers.getSigners();


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
    Token = await ethers.getContractFactory("Token");
    token = await Token.deploy("Wizard Gold", "WGLD", 18, ethers.utils.parseEther("1000"));


    // Deploying the Wizards Contract
    Wizards = await ethers.getContractFactory("Wizards", {
      libraries: {
        "TokenURILibrary": tokenURILibrary.address,
      },
    });
    wizards = await Wizards.deploy("Wizards", "WZD", token.address, "https://gateway.pinata.cloud/ipfs/");

    // Deploying the Appointer
    Appointer = await ethers.getContractFactory("Appointer");
    appointer = await Appointer.deploy(wizards.address);

    // Deploying the WizardTower
    WizardTower = await ethers.getContractFactory("WizardTower");
    wizardTower = await WizardTower.deploy(token.address, wizards.address);

    // Finally, deploy the Governance contract
    Governance = await ethers.getContractFactory("Governance");
    governance = await Governance.deploy(token.address, wizards.address, wizardTower.address, appointer.address);


    // set certain roles
    await wizards.updateAppointer(appointer.address);

  });


    it('Should deploy the Governance contract and set the correct owner', async function() {
        expect(governance.address).to.exist;
        const contractOwner = await governance.owner();
        expect(contractOwner).to.equal(owner.address);
    });

    describe('Task Creation', function() {
        let wizardId, wizardRole, coreDetails, timeDetails, roleDetails;
        beforeEach(async () => {
            await wizards.connect(owner).mint(0);
            let totalWizards = await wizards.totalSupply();
            wizardId = totalWizards.toNumber();  // Assuming the ID is a number
            wizardRole = await wizards.getRole(wizardId);

            coreDetails = {
                IPFSHash: "QmT78zSuBmuS4z925WZfrqQ1qHaJ56DQaTfyMUF7F8ff5o",  // Example IPFS hash
                state: 0,  // Assuming 0 is the initial state for your TASKSTATE enum
                numFieldsToHash: 3,
                taskType: 1,  // Assuming 1 is a valid value for your TASKTYPE enum
                reward: ethers.utils.parseEther(".1"),
                verificationFee: verificationFee
            };

            timeDetails = {
                begTimestamp: Math.floor(Date.now() / 1000),  // Current timestamp
                endTimestamp: Math.floor(Date.now() / 1000) + 604800,  // One week from now
                waitTime: 3600,  // 1 hour in seconds
                timeBonus: 86400  // 1 day in seconds
            };

            roleDetails = {
                creatorRole: wizardRole,  // Example role ID
                restrictedTo: 2,  // Example role ID
                availableSlots: 10  // Example number of slots
            };

        }); // end

        it('Task can not be created without token allowance', async function() {
            await expect(governance.connect(owner).createTask(wizardId, coreDetails, timeDetails, roleDetails)).to.be.reverted;
        });

        it('Created task should have correct properties', async function() {
            // Approve the allowance
            let tx = await token.approve(governance.address, coreDetails.reward);
            await tx.wait();

            tx = await token.approve(governance.address, coreDetails.reward);
            tx = await governance.createTask(wizardId, coreDetails, timeDetails, roleDetails);
            const receipt = await tx.wait();
            const event = receipt.events?.find(e => e.event === 'NewTaskCreated');
            const task = event.args.task;
            const taskId = event.args.taskId;

            // Continue checking CoreDetails
            expect(task.coreDetails.IPFSHash).to.equal(coreDetails.IPFSHash);
            expect(task.coreDetails.state).to.equal(coreDetails.state);
            expect(task.coreDetails.numFieldsToHash).to.equal(coreDetails.numFieldsToHash);
            expect(task.coreDetails.taskType).to.equal(coreDetails.taskType);
            expect(task.coreDetails.reward.toString()).to.equal(coreDetails.reward.toString()); // Convert BigNumber to string for comparison

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
                numFieldsToHash: 3,
                taskType: 1,  // Assuming 1 is a valid value for your TASKTYPE enum
                reward: ethers.utils.parseEther(".1"),
                verificationFee: verificationFee
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

            // Approve the allowance
            let tx = await token.connect(owner).approve(governance.address, coreDetails.reward);
            await tx.wait();

            tx = await governance.connect(owner).createTask(wizardId, coreDetails, timeDetails, roleDetails);
            const receipt = await tx.wait();
            const event = receipt.events?.find(e => e.event === 'NewTaskCreated');
            task = event.args.task;
            taskId = event.args.taskId;
        });

        it('Should decrease available slots when a task is accepted', async function() {
              const tx = await governance.acceptTask(taskId, wizardId, {value: verificationFee});
              const receipt = await tx.wait();
//              const event = receipt.events?.find(e => e.event === 'TaskAccepted');
//              const taskId = event.args.taskId;

              const task = await governance.getTaskById(taskId);
              expect(task.roleDetails.availableSlots).to.equal(roleDetails.availableSlots - 1);
        });

        it('Should not allow a task to be accepted if no slots are available', async function() {
              const tx = await governance.acceptTask(taskId, wizardId, {value: verificationFee});
              const receipt = await tx.wait();

              // Now try accepting the same task again
              await expect(governance.acceptTask(taskId, wizardTwoId, {value: verificationFee})).to.be.reverted;
        });

        it('Should not allow a wizard to accept same task twice before completing it first.', async function() {
              const tx = await governance.acceptTask(taskId, wizardId, {value: verificationFee});
              const receipt = await tx.wait();

              // Now try accepting the same task again
              await expect(governance.acceptTask(taskId, wizardId, {value: verificationFee})).to.be.reverted;
        });

        // todo -- wizard accepts same task after completing and after timeperiod
        // todo -- wizard accepts same task after completing and but not after timeperiod -- fail

    });

    describe('Verification', function() {
        let taskId, task, creatorWizardId, reporterWizardId, verifyingWizardId, roleDetails, reportId, paddedValues, leafHashes, finalHash, leafArray,
        contractSettings, verifyingWizardIdTwo;


        beforeEach(async () => {
            contractSettings = await wizards.connect(owner).contractSettings();
            //  updateVerifier
            let tx = await wizards.updateVerifier(governance.address);
            await tx.wait();

            // Create a task as a precondition for acceptance tests
            await wizards.connect(addr1).mint(0);
            let totalWizards = await wizards.totalSupply();
            creatorWizardId = totalWizards.toNumber();  // Assuming the ID is a number

            await wizards.connect(addr2).mint(0);
            reporterWizardId = creatorWizardId + 1;

            await wizards.connect(addr3).mint(0);
            verifyingWizardId = creatorWizardId + 2;

            await wizards.connect(addr4).mint(0);
            verifyingWizardIdTwo = creatorWizardId + 3;

            await wizards.connect(addr1).initiate(creatorWizardId, {value: contractSettings.initiationCost});
            await wizards.connect(addr2).initiate(reporterWizardId, {value: contractSettings.initiationCost});
            await wizards.connect(addr3).initiate(verifyingWizardId, {value: contractSettings.initiationCost});
            await wizards.connect(addr4).initiate(verifyingWizardIdTwo, {value: contractSettings.initiationCost});

            // assign creatorWizardId to creator Role
            tx = await appointer.createRole("first_creator", true, 1, []);
            let receipt = await tx.wait();
            let event = receipt.events?.find(e => e.event === 'RoleCreated');
            let creatorRoleId = event.args.roleId;


            tx = await appointer.appointAsAdmin(creatorWizardId, creatorRoleId);
            await tx.wait();

            let coreDetails = {
                IPFSHash: "QmT78zSuBmuS4z925WZfrqQ1qHaJ56DQaTfyMUF7F8ff5o",  // Example IPFS hash
                state: 0,  // Assuming 0 is the initial state for your TASKSTATE enum
                numFieldsToHash: 3,
                taskType: 1,  // Assuming 1 is a valid value for your TASKTYPE enum
                reward: ethers.utils.parseEther("0"),
                verificationFee: verificationFee
            };

            let timeDetails = {
                begTimestamp: Math.floor(Date.now() / 1000),  // Current timestamp
                endTimestamp: Math.floor(Date.now() / 1000) + 604800,  // One week from now
                waitTime: 3600,  // 1 hour in seconds
                timeBonus: 86400  // 1 day in seconds
            };

            roleDetails = {
                creatorRole: creatorRoleId,  // Example role ID
                restrictedTo: 0,  // Example role ID
                availableSlots: 10  // Example number of slots
            };

            // Approve the allowance
            tx = await token.connect(addr1).approve(governance.address, coreDetails.reward);
            await tx.wait();

            let numRoles = await appointer.numRoles();
            let creatorWizard = await wizards.getStatsGivenId(creatorWizardId);

            //  create Task
            tx = await governance.connect(addr1).createTask(creatorWizardId, coreDetails, timeDetails, roleDetails);
            receipt = await tx.wait();
            event = receipt.events?.find(e => e.event === 'NewTaskCreated');
            task = event.args.task;
            taskId = event.args.taskId;

            // accept task
            tx = await governance.connect(addr2).acceptTask(taskId, reporterWizardId, {value: verificationFee}); // todo -- make this a different wizard
            receipt = await tx.wait();
            event = receipt.events?.find(e => e.event === 'TaskAccepted');
            const reportId = event.args.reportId;

            // create hash
            leafArray = ['1', '2', '3'];
            const hashes = await computeHashes(leafArray);
            paddedValues = hashes.paddedValues;
            leafHashes = hashes.leafHashes;
            finalHash = hashes.finalHash;

            // complete task
            const res = await governance.connect(addr2).completeTask(reportId, finalHash, reporterWizardId);
        });

        it('Verification fails with incorrect payment.', async function() {
            await expect(governance.claimReportToVerify(verifyingWizardId, {value: verificationFee*2})).to.be.reverted;
            await expect(governance.claimReportToVerify(verifyingWizardId, {value: verificationFee/2})).to.be.reverted;
            await expect(governance.claimReportToVerify(verifyingWizardId, {value: 0})).to.be.reverted;
        });

        it('Verification assignment works with one task.', async function() {
            let tx = await governance.connect(addr3).claimReportToVerify(verifyingWizardId, {value: verificationFee});
            let receipt = await tx.wait();
            event = receipt.events?.find(e => e.event === 'VerificationAssigned');
            reportId = event.args.reportId;

            expect(reportId).to.equal(1);
        });

        it('Verification should succeed with correct values', async function() {
            let tx = await governance.connect(addr3).claimReportToVerify(verifyingWizardId, {value: verificationFee});
            let receipt = await tx.wait();
            event = receipt.events?.find(e => e.event === 'VerificationAssigned');
            reportId = event.args.reportId;

            tx = await governance.connect(addr3).submitVerification(verifyingWizardId, reportId, leafHashes);
            receipt = await tx.wait();
            event = receipt.events?.find(e => e.event === 'VerificationSubmitted');

            const reportState = event.args.reportState;
            expect(reportState).to.equal(5);


        });

        it('Verification should fail with incorrect values', async function() {
            let tx = await governance.connect(addr3).claimReportToVerify(verifyingWizardId, {value: verificationFee});
            let receipt = await tx.wait();
            event = receipt.events?.find(e => e.event === 'VerificationAssigned');
            reportId = event.args.reportId;

            const incorrectHashes = await computeHashes(['3', '2', '1']);

            tx = await governance.connect(addr3).submitVerification(verifyingWizardId, reportId, incorrectHashes.leafHashes);

            receipt = await tx.wait();
            event = receipt.events?.find(e => e.event === 'VerificationSubmitted');

            const reportState = event.args.reportState;
            expect(reportState).to.equal(2);
        });


        it('Refuted Verification with consensus returns correct values', async function() {
            let tx = await governance.connect(addr3).claimReportToVerify(verifyingWizardId, {value: verificationFee});
            let receipt = await tx.wait();
            event = receipt.events?.find(e => e.event === 'VerificationAssigned');
            reportId = event.args.reportId;

            let incorrectLeaves = ['3', '2', '1'];
            const incorrectHashes = await computeHashes(incorrectLeaves);
            let hexlifiedLeaves = incorrectHashes.paddedValues;
            tx = await governance.connect(addr3).submitVerification(verifyingWizardId, reportId, incorrectHashes.leafHashes);
            receipt = await tx.wait();
            event = receipt.events?.find(e => e.event === 'VerificationSubmitted');
            let reportState = event.args.reportState;
            expect(reportState).to.equal(2);

            let reportsWaitingConf = await governance.reportsWaitingConfirmationLength();
            let numClaims = await governance.reportsClaimedForConfirmationLength();
            let claimInfo = await governance.reportsClaimedForConfirmationValue(0);

            // Advance the blockchain by 1 hour (3600 seconds)
            await advanceTime(10000);

            // Move report from queue
            await governance.processReportsClaimedForConfirmation(1);

            reportsWaitingConf = await governance.reportsWaitingConfirmationLength();
            numClaims = await governance.reportsClaimedForConfirmationLength();


            await advanceTime(10000);
            await governance.processReportsClaimedForConfirmation(1);

            reportsWaitingConf = await governance.reportsWaitingConfirmationLength();
            numClaims = await governance.reportsClaimedForConfirmationLength();

            //          expect this to fail
            tx = await governance.connect(addr4).claimReportToVerify(verifyingWizardIdTwo, {value: verificationFee});
            receipt = await tx.wait();
            event = receipt.events?.find(e => e.event === 'VerificationAssigned');
            reportId = event.args.reportId;

            // submit same verification
            // todo -- this succeded using verifyingWizardId -- need a new test for this to fail
            tx = await governance.connect(addr4).submitVerification(verifyingWizardIdTwo, reportId, hexlifiedLeaves);
            receipt = await tx.wait();
            event = receipt.events?.find(e => e.event === 'VerificationSubmitted');
            reportState = event.args.reportState;
            expect(reportState).to.equal(3);
        });


        it('Refuted Verification without consensus returns correct values', async function() {
            let tx = await governance.connect(addr3).claimReportToVerify(verifyingWizardId, {value: verificationFee});
            let receipt = await tx.wait();
            event = receipt.events?.find(e => e.event === 'VerificationAssigned');
            reportId = event.args.reportId;

            let incorrectHashes = await computeHashes(['3', '2', '1']);
            tx = await governance.connect(addr3).submitVerification(verifyingWizardId, reportId, incorrectHashes.leafHashes);
            receipt = await tx.wait();
            event = receipt.events?.find(e => e.event === 'VerificationSubmitted');
            let reportState = event.args.reportState;
            expect(reportState).to.equal(2);

            // Advance the blockchain by 1 hour (3600 seconds)
            await advanceTime(10000);

            // Move report from queue
            await governance.processReportsClaimedForConfirmation(1);

            tx = await governance.connect(addr4).claimReportToVerify(verifyingWizardIdTwo, {value: verificationFee});
            receipt = await tx.wait();
            event = receipt.events?.find(e => e.event === 'VerificationAssigned');
            reportId = event.args.reportId;

            // todo -- test this with verifyingWizardId (original)
            // submit same verification
            incorrectHashes = await computeHashes(['4', '5', '6']);
            tx = await governance.connect(addr4).submitVerification(verifyingWizardIdTwo, reportId, incorrectHashes.leafHashes);
            receipt = await tx.wait();
            event = receipt.events?.find(e => e.event === 'VerificationSubmitted');
            reportState = event.args.reportState;
            expect(reportState).to.equal(4);
        });


        it('Should not allow a report to be verified more than once', async function() {
            let tx = await governance.connect(addr3).claimReportToVerify(verifyingWizardId, {value: verificationFee});
            let receipt = await tx.wait();
            event = receipt.events?.find(e => e.event === 'VerificationAssigned');
            reportId = event.args.reportId;

            tx = await governance.connect(addr3).submitVerification(verifyingWizardId, reportId, leafHashes);
            receipt = await tx.wait();
            event = receipt.events?.find(e => e.event === 'VerificationSubmitted');
            const isHashCorrect = event.args.isHashCorrect;


            await expect(governance.connect(addr3).submitVerification(verifyingWizardId, reportId, leafHashes))
                .to.be.reverted;
        });


        it('Should update the report state upon successful verification', async function() {
            let tx = await governance.connect(addr3).claimReportToVerify(verifyingWizardId, {value: verificationFee});
            let receipt = await tx.wait();
            event = receipt.events?.find(e => e.event === 'VerificationAssigned');
            reportId = event.args.reportId;

            tx = await governance.connect(addr3).submitVerification(verifyingWizardId, reportId, leafHashes);
            receipt = await tx.wait();

            const report = await governance.getReportById(reportId);

            expect(report.reportState).to.equal(5);
        });


       it('Should be able to fetch number of reports needing verification', async function() {
            let reports = await governance.reportsWaitingConfirmationLength();
            expect(reports).to.equal(ethers.BigNumber.from("1"));
        });

       it('Should be able to get correct report number', async function() {
            let report = await governance.reportsWaitingConfirmation(0);
            expect(report).to.equal(ethers.BigNumber.from("1"));
        });

       it('Reporter and Verifier should receive funds back on successful verification', async function() {
            let tx = await governance.connect(addr3).claimReportToVerify(verifyingWizardId, {value: verificationFee});
            let receipt = await tx.wait();
            event = receipt.events?.find(e => e.event === 'VerificationAssigned');
            reportId = event.args.reportId;

            const initETHReporter = await ethers.provider.getBalance(addr2.address);
            const initETHVerifier = await ethers.provider.getBalance(addr3.address);

            tx = await governance.connect(addr3).submitVerification(verifyingWizardId, reportId, leafHashes);
            receipt = await tx.wait();
            const report = await governance.getReportById(reportId);
            const ethSpentOnGas = receipt.gasUsed.mul(receipt.effectiveGasPrice);

            const finalETHReporter = await ethers.provider.getBalance(addr2.address);
            const finalETHVerifier = await ethers.provider.getBalance(addr3.address);

            expect(finalETHReporter).to.equal(initETHReporter.add(verificationFee));
            expect(finalETHVerifier).to.equal(initETHVerifier.add(verificationFee).sub(ethSpentOnGas));
        });

       it('Reporter and second Refuter should receive extra funds on successful verification after challenge', async function() {
            let tx = await governance.connect(addr3).claimReportToVerify(verifyingWizardId, {value: verificationFee});
            let receipt = await tx.wait();
            event = receipt.events?.find(e => e.event === 'VerificationAssigned');
            reportId = event.args.reportId;

            const initETHReporter = await ethers.provider.getBalance(addr2.address);

            let incorrectLeaves = ['3', '2', '1'];
            const incorrectHashes = await computeHashes(incorrectLeaves);

            tx = await governance.connect(addr3).submitVerification(verifyingWizardId, reportId, incorrectHashes.leafHashes);
            receipt = await tx.wait();

            await advanceTime(10000);
            await governance.connect(owner).processReportsClaimedForConfirmation(1);

            tx = await governance.connect(addr4).claimReportToVerify(verifyingWizardIdTwo, {value: verificationFee});
            receipt = await tx.wait();
            const initETHVerifier = await ethers.provider.getBalance(addr4.address);

            tx = await governance.connect(addr4).submitVerification(verifyingWizardIdTwo, reportId, paddedValues);
            receipt = await tx.wait();

            const report = await governance.getReportById(reportId);
            const ethSpentOnGas = receipt.gasUsed.mul(receipt.effectiveGasPrice);

            const finalETHReporter = await ethers.provider.getBalance(addr2.address);
            const finalETHVerifier = await ethers.provider.getBalance(addr4.address);

            expect(finalETHReporter).to.equal(initETHReporter.add(verificationFee.mul(3).div(2)));
            expect(finalETHVerifier).to.equal(initETHVerifier.add(verificationFee.mul(3).div(2)).sub(ethSpentOnGas));
        });

       it('Refuters should receive extra funds after converging/agreeing refuting', async function() {
            // data
            let incorrectLeaves = ['3', '2', '1'];
            const incorrectHashes = await computeHashes(incorrectLeaves);

            // claim report for first verifier
            let tx = await governance.connect(addr3).claimReportToVerify(verifyingWizardId, {value: verificationFee});
            let receipt = await tx.wait();
            event = receipt.events?.find(e => e.event === 'VerificationAssigned');
            reportId = event.args.reportId;

            // get post claim ETH values in wallet
            const initETHReporter = await ethers.provider.getBalance(addr2.address);
            const initETHVerifier = await ethers.provider.getBalance(addr3.address);

            // submit verification for first verifier
            tx = await governance.connect(addr3).submitVerification(verifyingWizardId, reportId, incorrectHashes.leafHashes);
            receipt = await tx.wait();
            const ethSpentOnGas = receipt.gasUsed.mul(receipt.effectiveGasPrice);

            // advance time and processing claims
            await advanceTime(10000);
            await governance.connect(owner).processReportsClaimedForConfirmation(1);


            // claim report for second verifier
            tx = await governance.connect(addr4).claimReportToVerify(verifyingWizardIdTwo, {value: verificationFee});
            receipt = await tx.wait();

            // get post claim ETH values in wallet
            const initETHVerifierTwo = await ethers.provider.getBalance(addr4.address);

            // submit verification for second verifier
            tx = await governance.connect(addr4).submitVerification(verifyingWizardIdTwo, reportId, incorrectHashes.paddedValues);
            receipt = await tx.wait();
            event = receipt.events?.find(e => e.event === 'VerificationSubmitted');
            const ethSpentOnGasTwo = receipt.gasUsed.mul(receipt.effectiveGasPrice);

            const finalETHVerifierTwo = await ethers.provider.getBalance(addr4.address);
            const finalETHReporter = await ethers.provider.getBalance(addr2.address);
            const finalETHVerifier = await ethers.provider.getBalance(addr3.address);

            // expect eth balances to be adjusted accordingly
            expect(finalETHReporter).to.equal(initETHReporter); // no change for reporter
            expect(finalETHVerifier).to.equal(initETHVerifier.add(verificationFee.mul(3).div(2)).sub(ethSpentOnGas));
            expect(finalETHVerifierTwo).to.equal(initETHVerifierTwo.add(verificationFee.mul(3).div(2)).sub(ethSpentOnGasTwo));
        });

       it('DAO should receive funds after diverging refuting', async function() {
            // data
            let incorrectLeaves = ['3', '2', '1'];
            const incorrectHashes = await computeHashes(incorrectLeaves);

            let incorrectLeavesTwo = ['333', '222', '111'];
            const incorrectHashesTwo = await computeHashes(incorrectLeavesTwo);

            // claim report for first verifier
            let tx = await governance.connect(addr3).claimReportToVerify(verifyingWizardId, {value: verificationFee});
            let receipt = await tx.wait();
            event = receipt.events?.find(e => e.event === 'VerificationAssigned');
            reportId = event.args.reportId;

            // get post claim ETH values in wallet
            const initETHReporter = await ethers.provider.getBalance(addr2.address);
            const initETHVerifier = await ethers.provider.getBalance(addr3.address);

            // submit verification for first verifier
            tx = await governance.connect(addr3).submitVerification(verifyingWizardId, reportId, incorrectHashes.leafHashes);
            receipt = await tx.wait();
            const ethSpentOnGas = receipt.gasUsed.mul(receipt.effectiveGasPrice);

            // advance time and processing claims
            await advanceTime(10000);
            await governance.connect(owner).processReportsClaimedForConfirmation(1);


            // claim report for second verifier
            tx = await governance.connect(addr4).claimReportToVerify(verifyingWizardIdTwo, {value: verificationFee});
            receipt = await tx.wait();

            // get post claim ETH values in wallet
            const initETHVerifierTwo = await ethers.provider.getBalance(addr4.address);

            // submit verification for second verifier
            const initETHOwner = await ethers.provider.getBalance(owner.address);
            tx = await governance.connect(addr4).submitVerification(verifyingWizardIdTwo, reportId, incorrectHashesTwo.paddedValues);
            receipt = await tx.wait();
            event = receipt.events?.find(e => e.event === 'VerificationSubmitted');
            const ethSpentOnGasTwo = receipt.gasUsed.mul(receipt.effectiveGasPrice);

            const finalETHVerifierTwo = await ethers.provider.getBalance(addr4.address);
            const finalETHReporter = await ethers.provider.getBalance(addr2.address);
            const finalETHVerifier = await ethers.provider.getBalance(addr3.address);
            const finalETHOwner = await ethers.provider.getBalance(owner.address);

            // expect eth balances to be adjusted accordingly
            expect(finalETHReporter).to.equal(initETHReporter); // no change for reporter
            expect(finalETHVerifier).to.equal(initETHVerifier.sub(ethSpentOnGas));
            expect(finalETHVerifierTwo).to.equal(initETHVerifierTwo.sub(ethSpentOnGasTwo));
            expect(finalETHOwner).to.equal(initETHOwner.add(verificationFee.mul(3)));
        });



    }); // end describe


    describe('Verification with restrictedTo', function() {
        let taskId, task, wizardId, verifyingWizardId, wizardRole, roleDetails, reportId, leafHashes, finalHash, leafArray,
        contractSettings, taskDoerId, taskDoerRole;


        beforeEach(async () => {
            contractSettings = await wizards.connect(owner).contractSettings();

            let wizAppointer = await wizards.appointer();

            // Create a task as a precondition for acceptance tests
            await wizards.connect(owner).mint(0);
            let totalWizards = await wizards.totalSupply();
            wizardId = totalWizards.toNumber();  // Assuming the ID is a number
            wizardRole = await wizards.getRole(wizardId);

            await wizards.mint(0);
            verifyingWizardId = wizardId + 1;

            await wizards.mint(0);
            taskDoerId = wizardId + 2;

            await wizards.initiate(wizardId, {value: contractSettings.initiationCost});
            await wizards.initiate(verifyingWizardId, {value: contractSettings.initiationCost});
            await wizards.initiate(taskDoerId, {value: contractSettings.initiationCost});

            let tx = await appointer.createRole("test_role", false, 1, []);
            let receipt = await tx.wait();
            let event = receipt.events?.find(e => e.event === 'RoleCreated');
            let newRoleId = event.args.roleId;

            let isActive = await wizards.isActive(taskDoerId);

            await appointer.appointAsAdmin(taskDoerId, newRoleId);
            taskDoerRole = await wizards.getRole(taskDoerId);

            let coreDetails = {
                IPFSHash: "QmT78zSuBmuS4z925WZfrqQ1qHaJ56DQaTfyMUF7F8ff5o",  // Example IPFS hash
                state: 0,  // Assuming 0 is the initial state for your TASKSTATE enum
                numFieldsToHash: 3,
                taskType: 1,  // Assuming 1 is a valid value for your TASKTYPE enum
                reward: ethers.utils.parseEther("0"),
                verificationFee: verificationFee
            };

            let timeDetails = {
                begTimestamp: Math.floor(Date.now() / 1000),  // Current timestamp
                endTimestamp: Math.floor(Date.now() / 1000) + 604800,  // One week from now
                waitTime: 3600,  // 1 hour in seconds
                timeBonus: 86400  // 1 day in seconds
            };

            roleDetails = {
                creatorRole: wizardRole,  // Example role ID
                restrictedTo: taskDoerRole,  // Example role ID
                availableSlots: 10  // Example number of slots
            };

            // Approve the allowance
            tx = await token.connect(owner).approve(governance.address, coreDetails.reward);
            await tx.wait();

            tx = await governance.connect(owner).createTask(wizardId, coreDetails, timeDetails, roleDetails);
            receipt = await tx.wait();
            event = receipt.events?.find(e => e.event === 'NewTaskCreated');
            task = event.args.task;
            taskId = event.args.taskId;

            // accept task
            tx = await governance.acceptTask(taskId, taskDoerId, {value: verificationFee});
            receipt = await tx.wait();
            event = receipt.events?.find(e => e.event === 'TaskAccepted');
            reportId = event.args.reportId;

            // create hash
            leafArray = ['1', '2', '3'];
            const hashes = await computeHashes(leafArray);
            leafHashes = hashes.leafHashes;
            finalHash = hashes.finalHash;

            // complete task
            const res = await governance.completeTask(reportId, finalHash, taskDoerId);

            // set verifier of wizards contract
//            updateVerifier
            tx = await wizards.updateVerifier(governance.address);
            await tx.wait();

        });

        it('Task can not be claimed.', async function() {
            await expect(governance.claimReportToVerify(verifyingWizardId, {value: verificationFee})).to.be.reverted;
        });

        it('Verification with true produces expected event', async function() {
            let tx = await governance.verifyRestrictedTask(verifyingWizardId, reportId, true);
            let receipt = await tx.wait();
            event = receipt.events?.find(e => e.event === 'VerificationSubmitted');
            reportState = event.args.reportState;

            expect(reportState).to.equal(5);
        });

        it('Verification with false produces expected event', async function() {
            let tx = await governance.verifyRestrictedTask(verifyingWizardId, reportId, false);
            let receipt = await tx.wait();
            event = receipt.events?.find(e => e.event === 'VerificationSubmitted');
            reportState = event.args.reportState;

            expect(reportState).to.equal(3);
        });
    }); // end describe







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
                numFieldsToHash: 3,
                taskType: 1,  // Assuming 1 is a valid value for your TASKTYPE enum
                reward: ethers.utils.parseEther("0"),
                verificationFee: verificationFee
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

            // Approve the allowance
            let tx = await token.connect(owner).approve(governance.address, coreDetails.reward);
            await tx.wait();

            await expect(governance.connect(owner).createTask(wizardId, coreDetails, timeDetails, roleDetails)).to.be.reverted;
        });

        it('Should not allow tasks with zero available slots', async function() {
            let coreDetails = {
                IPFSHash: "QmT78zSuBmuS4z925WZfrqQ1qHaJ56DQaTfyMUF7F8ff5o",  // Example IPFS hash
                state: 0,  // Assuming 0 is the initial state for your TASKSTATE enum
                numFieldsToHash: 3,
                taskType: 1,  // Assuming 1 is a valid value for your TASKTYPE enum
                reward: ethers.utils.parseEther("0"),
                verificationFee: verificationFee
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

            // Approve the allowance
            let tx = await token.connect(owner).approve(governance.address, coreDetails.reward);
            await tx.wait();

            await expect(governance.connect(owner).createTask(wizardId, coreDetails, timeDetails, roleDetails)).to.be.reverted;
        });


    // todo -- should not allow task for creatorRole that doesn't exist

    });

    // ... Further in-depth tests ...
});
