const { expect } = require("chai");
const { ethers } = require("hardhat");

const advanceTime = async (seconds) => {
    await network.provider.send("evm_increaseTime", [seconds])
    await ethers.provider.send("evm_mine");
};


async function getBlockTimestamp() {
    // Get the latest block number
    const blockNumber = await ethers.provider.getBlockNumber();

    // Get the block details using the block number
    const block = await ethers.provider.getBlock(blockNumber);

    // Return the timestamp of the latest block
    return block.timestamp;
}

describe("Wizards - State Variables & Initialization", function() {

  let Wizards, WizardTower, Governance, Appointer, Token;
  let wizards, wizardTower, governance, appointer, token;
  let owner, addr1, addr2, addr3, addr4;

  const imageBaseURI = "https://raw.githubusercontent.com/daveaneo/wizardarmy/master/token/wizard_army_pinata";

    let initialContractSettings = {
        mintCost: 5,
        initiationCost: 10,
        maxSupply: 8192,
        maxActiveWizards: 8192,
        protectionTimeExtension: 86400, // 1 day in seconds
        exileTimePenalty: 2592000,      // 30 days in seconds
        ecosystemTokenAddress: "_ERC20Address", // replace with actual address or variable
        phaseDuration: 3600,           // 60 minutes in seconds
        totalPhases: 8,
        maturityThreshold: 4,
        imageBaseURI: imageBaseURI,
        wizardSaltSet: false
    };


  beforeEach(async function() {

//    // Deploying the CommonDefinitions Library
//    const CommonDefinitions = await ethers.getContractFactory("CommonDefinitions");
//    const commonDefinitions = await CommonDefinitions.deploy();
//    await commonDefinitions.deployed();
//
//    // Wait for the transaction to be confirmed
//    await commonDefinitions.deployTransaction.wait();

    // Deploying the GeneLogic Library
    const GeneLogic = await ethers.getContractFactory("GeneLogic");
    const geneLogic = await GeneLogic.deploy();
    await geneLogic.deployed();

    // Wait for the transaction to be confirmed
    await geneLogic.deployTransaction.wait();


    // Link the GeneLogic library to the SVGGenerator and deploy
    const SVGGenerator = await ethers.getContractFactory("SVGGenerator", {
        libraries: {
            "GeneLogic": geneLogic.address,
        }
    });
    const svgGenerator = await SVGGenerator.deploy();
    await svgGenerator.deployed();

    // Wait for the transaction to be confirmed
    await svgGenerator.deployTransaction.wait();

    // Deploying the TokenURILibrary
    const TokenURILibrary = await ethers.getContractFactory("TokenURILibrary", {
        libraries: {
            "GeneLogic": geneLogic.address,
            "SVGGenerator": svgGenerator.address
        }
    });
    const tokenURILibrary = await TokenURILibrary.deploy();
    await tokenURILibrary.deployed();

    // Wait for the transaction to be confirmed
    await tokenURILibrary.deployTransaction.wait();

    // Deploying the Token
    Token = await ethers.getContractFactory("Token");
    token = await Token.deploy("Wizard Gold", "WGLD", 18, ethers.utils.parseEther("1000"));
    await token.deployed();



    // Wait for the transaction to be confirmed
    await token.deployTransaction.wait();

    initialContractSettings.ecosystemTokenAddress = token.address;


    Wizards = await ethers.getContractFactory("Wizards", {
      libraries: {
          "TokenURILibrary": tokenURILibrary.address
      }
    });
    // Now deploy the Wizards contract as before:
    wizards = await Wizards.deploy("Wizards", "WZD", token.address, "https://raw.githubusercontent.com/daveaneo/wizardarmy/master/token/wizard_army_pinata"); // todo -- add '/' or not documentation
    await wizards.deployed();

    // Wait for the transaction to be confirmed
    await wizards.deployTransaction.wait();

    // Deploying the Appointer
    Appointer = await ethers.getContractFactory("Appointer");
    appointer = await Appointer.deploy(wizards.address);


    [owner, addr1, addr2, addr3, addr4,  ...addrs] = await ethers.getSigners();

    // mint 3 wizards, initatiate first 2
    await wizards.connect(addr1).mint(0); // wizid 1
    await wizards.connect(addr1).initiate(1, {value: initialContractSettings.initiationCost});

    await wizards.connect(addr2).mint(1); // wizid 2
    await wizards.connect(addr2).initiate(2, {value: initialContractSettings.initiationCost});

    await wizards.connect(addr3).mint(2);


    // set certain roles
    await wizards.updateAppointer(appointer.address);

    // transfer tokens to each of the accounts
    const amountToSend = ethers.utils.parseEther("1"); // This will convert 1 to 10**18

    await token.transfer(addr1.address, amountToSend);
    await token.transfer(addr2.address, amountToSend);
    await token.transfer(addr3.address, amountToSend);
    await token.transfer(addr4.address, amountToSend);


  });

  // Test Case 1.1: Ensure the contract is initialized with the correct default state.
  it("should initialize with the correct default state", async function() {
    const verifier = await wizards.connect(addr1).verifier();
    expect(verifier).to.equal(owner.address);

    const culler = await wizards.culler();
    expect(culler).to.equal(owner.address);

    const appAddr = await wizards.appointer();
    expect(appAddr).to.equal(appointer.address);

  });


  // Test Case 1.2: Validate that the contract settings (ContractSettings) are initialized correctly.
  it("should initialize contract settings correctly", async function() {
    const settings = await wizards.connect(addr1).contractSettings();

    expect(settings.mintCost).to.equal(initialContractSettings.mintCost);
    expect(settings.initiationCost).to.equal(initialContractSettings.initiationCost);
    expect(settings.maxActiveWizards).to.equal(initialContractSettings.maxActiveWizards);
    expect(settings.protectionTimeExtension).to.equal(initialContractSettings.protectionTimeExtension);
    expect(settings.exileTimePenalty).to.equal(initialContractSettings.exileTimePenalty);
    expect(settings.ecosystemTokenAddress).to.equal(initialContractSettings.ecosystemTokenAddress);
    expect(settings.phaseDuration).to.equal(initialContractSettings.phaseDuration);
    expect(settings.totalPhases).to.equal(initialContractSettings.totalPhases);
    expect(settings.maturityThreshold).to.equal(initialContractSettings.maturityThreshold);
    expect(settings.imageBaseURI).to.equal(initialContractSettings.imageBaseURI);
    expect(settings.wizardSaltSet).to.equal(initialContractSettings.wizardSaltSet);

  });

  // Test Case 1.3: Correct totalSupply
  it("should have tokens owned by expected addresses", async function() {
    const total = await wizards.totalSupply();
    expect(total).to.be.equal(3);
  });


    describe("Wizards - Wizard Management", function() {

      // ... (previous setup code remains unchanged)

      // Test Case 2.1: Testing the isActive function.
      it("should correctly identify active wizards", async function() {
        // Assuming you have a way to make a wizard active/inactive
        const isFirstWizardActive = await wizards.isActive(1);
        const isSecondWizardActive = await wizards.isActive(2);
        const isThirdWizardActive = await wizards.isActive(3);

        expect(isFirstWizardActive).to.be.true;
        expect(isSecondWizardActive).to.be.true;
        expect(isThirdWizardActive).to.be.false;
      });

      // Test Case 2.2: Testing the isExiled, hasDeserted, and isMature functions.
      it("should correctly identify exiled, deserted, and mature wizards", async function() {
        let exiled = await wizards.isExiled(1);
        expect(exiled).to.be.false;

        let deserted = await wizards.hasDeserted(1);
        expect(deserted).to.be.false;

        let mature = await wizards.isMature(1);
        expect(mature).to.be.false;

        exiled = await wizards.isExiled(3);
        expect(exiled).to.be.false;

        deserted = await wizards.hasDeserted(3);
        expect(deserted).to.be.false;

        mature = await wizards.isMature(3);
        expect(mature).to.be.false;

      });

      // Test Case 2.3: Testing the isExiled, hasDeserted, and isMature functions.
      it("should correctly identify phase as 0 for initiated or not, at start", async function() {
        const myPhase = await wizards.getPhaseOf(1);
        const myPhaseThree = await wizards.getPhaseOf(3);

        expect(myPhase).to.equal(0);
        expect(myPhaseThree).to.equal(0);
      });

      // Test Case 2.4: Testing the _isValidWizard function.
      it("should revert for invalid wizards", async function() {
        await expect(wizards.isActive(9999)).to.be.reverted;
        await expect(wizards.isActive(0)).to.be.reverted;
      });
    });


    describe("Wizards - Reputation and Roles", function() {

      // ... (previous setup code remains unchanged)

      // Test Case 3.1: Testing the getReputation function.
// todo -- create reputation smart contract
// tasks completed
// tasks failed
// seconds added
// exiled
// lifespan
// accolades
// tokens earned

//      it("should fetch the correct reputation for a given wizard", async function() {
//        expect(true).to.equal(false);
//        const wizardId = 4;  // This would be a known wizard ID for testing
//        const expectedReputation = 10;  // This would be a mock expected reputation value for testing
//
//        const reputation = await wizards.getReputation(wizardId);
//        expect(reputation).to.equal(expectedReputation);
//      });

      // Test Case 3.2: Testing the appointRole function (Role assignment).
      it("should assign a role to a wizard correctly", async function() {
        const wizardId = 1;  // This would be a known wizard ID for testing

        // assign creatorWizardId to creator Role
        let tx = await appointer.createRole("first_creator", true, 1, []);
        let receipt = await tx.wait();
        let event = receipt.events?.find(e => e.event === 'RoleCreated');
        let creatorRoleId = event.args.roleId;

        tx = await appointer.connect(owner).appointAsAdmin(wizardId, creatorRoleId);
        await tx.wait();

        // await wizards.appointRole(wizardId, roleId);

        const wizardStats = await wizards.getStatsGivenId(wizardId);
        expect(wizardStats.role).to.equal(creatorRoleId);
      });
    });


    describe("Wizards - Contract Settings", function() {
      // Test Case 4.1: Testing the modifyContractSettings function.
      it("should modify contract settings correctly", async function() {
        const newImageBaseURI = "https://new.base.uri/";
        const newPhaseDuration = 7200;
        const newProtectionTimeExtension = 2 * 24 * 60 * 60;  // 2 days
        const newMintCost = 7;
        const newInitiationCost = 15;
        const newMaturityThreshold = 1;

        await wizards.modifyContractSettings(newImageBaseURI, newPhaseDuration, newProtectionTimeExtension, newMintCost, newInitiationCost, newMaturityThreshold);

        const settings = await wizards.contractSettings();
        expect(settings.imageBaseURI).to.equal(newImageBaseURI);
        expect(settings.phaseDuration).to.equal(newPhaseDuration);
        expect(settings.protectionTimeExtension).to.equal(newProtectionTimeExtension);
        expect(settings.mintCost).to.equal(newMintCost);
        expect(settings.initiationCost).to.equal(newInitiationCost);
        expect(settings.maturityThreshold).to.equal(newMaturityThreshold);
      });
    });


    describe("Wizards - Wizards Life Cycle", function() {
      // Test Case 5.1: Testing the mint function.
      it("should mint a new wizard correctly", async function() {
        const uplineId = 1;  // Mock upline ID for testing
        const initialSupply = await wizards.totalSupply();

        await wizards.mint(uplineId);

        const newSupply = await wizards.totalSupply();
        expect(newSupply - initialSupply).to.equal(1);
      });

      // Test Case 5.2: Testing the initiate function.
      it("should initiate a wizard correctly", async function() {
        const wizardId = 3;  // This would be a known wizard ID for testing

        await wizards.connect(addr3).initiate(wizardId, { value: initialContractSettings.initiationCost });

        const wizardStats = await wizards.getStatsGivenId(wizardId);
        expect(wizardStats.initiationTimestamp).to.not.equal(0);
      });

      // Test Case 5.2: Testing the initiate function.
      it("non-owner can't initiate", async function() {
        const wizardId = 3;  // This would be a known wizard ID for testing

        await expect(wizards.connect(addr2).initiate(wizardId, { value: initialContractSettings.initiationCost })).to.be.reverted;
        await expect(wizards.connect(owner).initiate(wizardId, { value: initialContractSettings.initiationCost })).to.be.reverted;
      });


      // Test Case 5.2: Testing the initiate function.
      it("Can't initiate twice", async function() {
        const wizardId = 1;  // This would be a known wizard ID for testing

        await expect(wizards.connect(addr1).initiate(wizardId, { value: initialContractSettings.initiationCost })).to.be.reverted;
      });


      // Test Case 5.3: Testing the exile and cull functions.
      it("should exile a wizard correctly", async function() {
        const wizardId = 1;  // This would be a known wizard ID for testing

        // expect to revert
        await expect(wizards.connect(addr3).exile(1)).to.be.reverted;

        // advance time to when wizard is inactive
        await advanceTime(1000000);

        // expect to not be active, deserted
        expect (await wizards.connect(addr3).isActive(1)).to.equal(false);
        expect (await wizards.connect(addr3).hasDeserted(1)).to.equal(true);

        // exile
        await wizards.exile(wizardId);
        let isExiled = await wizards.isExiled(wizardId);
        expect(isExiled).to.equal(true);

        // can't exile again -- expect to revert
        await expect(wizards.connect(addr3).exile(1)).to.be.reverted;
        await expect(wizards.connect(owner).cull(1)).to.be.reverted;
        await expect(wizards.connect(addr1).initiate(1, { value: initialContractSettings.initiationCost })).to.be.reverted;

        // advance time to when wizard is inactive
        await advanceTime(initialContractSettings.exileTimePenalty + 1);

        isExiled = await wizards.isExiled(wizardId);
        expect(isExiled).to.equal(true);

        await wizards.connect(addr1).initiate(1, { value: initialContractSettings.initiationCost });

        const wizardStats = await wizards.getStatsGivenId(wizardId);
        expect(wizardStats.initiationTimestamp).to.not.equal(0);

        await wizards.cull(wizardId);
        const isExiledAfterCull = await wizards.isExiled(wizardId);
        expect(isExiledAfterCull).to.equal(true);
      });


      // Test Case 5.3.b: Testing the exile and cull functions.
      it("should exile a wizard correctly", async function() {
        const wizardId = 1;  // This would be a known wizard ID for testing


        await wizards.connect(owner).cull(wizardId);
        const isExiledAfterCull = await wizards.isExiled(wizardId);
        expect(isExiledAfterCull).to.equal(true);

        // can't exile again -- expect to revert
        await expect(wizards.connect(addr3).exile(1)).to.be.reverted;
        await expect(wizards.connect(owner).cull(1)).to.be.reverted;
        await expect(wizards.connect(addr1).initiate(1, { value: initialContractSettings.initiationCost })).to.be.reverted;

        // advance time to when wizard is inactive
        await advanceTime(initialContractSettings.exileTimePenalty + 1);

        let isExiled = await wizards.isExiled(wizardId);
        expect(isExiled).to.equal(true);

        await wizards.connect(addr1).initiate(1, { value: initialContractSettings.initiationCost });

        const wizardStats = await wizards.getStatsGivenId(wizardId);
        expect(wizardStats.initiationTimestamp).to.not.equal(0);
      });


      // Test Case 5.4: Testing the transferFrom function.
      it("should transfer a wizard and reset its statistics correctly", async function() {
        const wizardId = 2;  // This would be a known wizard ID for testing
        const recipient = addrs[5].address;  // Mock recipient for testing


        // assign creatorWizardId to creator Role
        let tx = await appointer.createRole("first_creator", true, 1, []);
        let receipt = await tx.wait();
        let event = receipt.events?.find(e => e.event === 'RoleCreated');
        let creatorRoleId = event.args.roleId;

        tx = await appointer.connect(owner).appointAsAdmin(wizardId, creatorRoleId);
        const wizardStatsInitial = await wizards.getStatsGivenId(wizardId);

        await wizards.connect(addr2).transferFrom(addr2.address, recipient, wizardId);

        const newOwner = await wizards.ownerOf(wizardId);
        expect(newOwner).to.equal(recipient);

        const wizardStatsFinal = await wizards.getStatsGivenId(wizardId);
        expect(wizardStatsFinal.initiationTimestamp).to.equal(0);
        expect(wizardStatsFinal.protectedUntilTimestamp).to.equal(0);
        expect(wizardStatsFinal.role).to.not.equal(wizardStatsInitial.role);
        expect(wizardStatsFinal.role).to.equal(0);
        expect(wizardStatsFinal.uplineId).to.equal(wizardStatsInitial.uplineId);


      });

      // Test Case 5.5: Can't initiate exiled wizard
      it("should not allow initiating an exiled wizard that hasn't completed its exile duration", async function() {
        await wizards.connect(owner).cull(1);  // Assuming the wizard meets the criteria for exile.
        await advanceTime(initialContractSettings.exileTimePenalty - 1);  // Almost completing the exile duration but not fully.
        await expect(wizards.connect(addr1).initiate(1, { value: initialContractSettings.initiationCost })).to.be.reverted;
      });

      // Test Case 5.6: Ensure uplineId cannot be higher than the total supply of wizards during minting.
      it("should revert if uplineId is greater than the total supply during minting", async function() {
        const invalidUplineId = 9999;
        await expect(wizards.connect(addr1).mint(invalidUplineId)).to.be.reverted;
      });

      // Test Case 5.7: Ensure proper behavior when trying to interact with non-existing wizards.
      it("should revert when trying to interact with a wizard that doesn't exist", async function() {
        const nonExistingWizardId = 9999;  // Assuming this ID is greater than the total number of minted wizards.
        await expect(wizards.isActive(nonExistingWizardId)).to.be.reverted;
        await expect(wizards.getUplineId(nonExistingWizardId)).to.be.reverted;
      });


    });

    describe("Wizards - Verifier Functions", function() {
      // Test Case 6.1: Testing the increaseProtectedUntilTimestamp function by the verifier.
      it("should increase the protectedUntilTimestamp correctly", async function() {
        const wizardId = 1;  // This would be a known wizard ID for testing
        const timeReward = 3600;  // 1 hour for testing

        const initialProtectionTimestamp = (await wizards.tokenIdToStats(wizardId)).protectedUntilTimestamp;

        await wizards.connect(owner).increaseProtectedUntilTimestamp(wizardId, timeReward);

        const finalProtectionTimestamp = (await wizards.tokenIdToStats(wizardId)).protectedUntilTimestamp;
        expect(finalProtectionTimestamp - initialProtectionTimestamp).to.equal(timeReward);
      });

      it("non-verifier can not update timestamp", async function() {
        const wizardId = 1;  // This would be a known wizard ID for testing
        await expect(wizards.connect(addr1).increaseProtectedUntilTimestamp(wizardId, 3600)).to.be.reverted;
        await expect(wizards.connect(addr2).increaseProtectedUntilTimestamp(wizardId, 3600)).to.be.reverted;
      });

      it("verifier can add 0 time without reverting", async function() { // todo -- could go either way
        const wizardId = 1;  // This would be a known wizard ID for testing

        const initialProtectionTimestamp = (await wizards.tokenIdToStats(wizardId)).protectedUntilTimestamp;
        await wizards.connect(owner).increaseProtectedUntilTimestamp(wizardId, 0);
        const finalProtectionTimestamp = (await wizards.tokenIdToStats(wizardId)).protectedUntilTimestamp;
        expect(initialProtectionTimestamp).to.equal(finalProtectionTimestamp);
      });

    });

    describe("Wizards - Modifiers", function() {

      // ... (previous setup code remains unchanged)

      // Test Case 8.1: Testing the onlyVerifier modifier.
      it("should revert when a non-verifier tries to call a verifier-only function", async function() {
        // An example function that requires the onlyVerifier modifier is increaseProtectedUntilTimestamp
        const wizardId = 1;
        const timeReward = 120;

        // Assuming addrs[1] is not the verifier.
        await expect(wizards.connect(addrs[1]).increaseProtectedUntilTimestamp(wizardId, timeReward))
          .to.be.revertedWith("only verifier");
      });

      // Test Case 8.2: Testing the onlyAppointer modifier.
      it("should revert when a non-appointer tries to call an appointer-only function", async function() {
        // An example function that requires the onlyAppointer modifier is appointRole
        const wizardId = 1;
        const roleId = 2;

        // Assuming addrs[1] is not the appointer.
        await expect(wizards.connect(addrs[1]).appointRole(wizardId, roleId))
          .to.be.revertedWith("only appointer");
      });

      // Test Case 8.3: Testing the onlyCuller modifier.
      it("should revert when a non-culler tries to call a culler-only function", async function() {
        // An example function that requires the onlyCuller modifier is cull
        const wizardId = 1;

        // Assuming addrs[1] is not the culler.
        await expect(wizards.connect(addrs[1]).cull(wizardId))
          .to.be.revertedWith("Only culler can call this function.");
      });

      // Test Case 8.4: Testing the saltNotSet modifier.
      it("should revert when trying to set random number after it has already been set", async function() {
        // The function setRandomNumber requires the saltNotSet modifier
        const wizardSalt = 12345;

        // Set the wizard salt for the first time
        await wizards.setRandomNumber(wizardSalt);

        // Trying to set it again should revert
        await expect(wizards.setRandomNumber(wizardSalt))
          .to.be.revertedWith("Number is already set");
      });


      // Test Case 8.: Testing the onlyVerifier modifier.
      it("should restrict non-verifiers from accessing verifier functions", async function() {
        const nonVerifier = addrs[1];
        const _wizardId = 1;
        const _timeReward = 1000;

        // Attempt to access a function with the onlyVerifier modifier using a non-verifier account
        await expect(wizards.connect(nonVerifier).increaseProtectedUntilTimestamp(_wizardId, _timeReward))
          .to.be.revertedWith("only verifier");
      });

      // Test Case 8.: Testing the onlyAppointer modifier.
      it("should restrict non-appointers from accessing appointer functions", async function() {
        const nonAppointer = addrs[2];
        const _wizardId = 1;
        const _roleId = 5;

        // Attempt to access a function with the onlyAppointer modifier using a non-appointer account
        await expect(wizards.connect(nonAppointer).appointRole(_wizardId, _roleId))
          .to.be.revertedWith("only appointer");
      });

      // Test Case 8.: Testing the onlyCuller modifier.
      it("should restrict non-cullers from accessing culler functions", async function() {
        const nonCuller = addrs[3];
        const _wizardId = 1;

        // Attempt to access a function with the onlyCuller modifier using a non-culler account
        await expect(wizards.connect(nonCuller).cull(_wizardId))
          .to.be.revertedWith("Only culler can call this function.");
      });

      // Test Case 8.: Testing the saltNotSet modifier.
      it("should restrict setting random number when already set", async function() {
        const _wizardSalt = 123456;

        // Set the random number for the first time
        await wizards.setRandomNumber(_wizardSalt);

        // Attempt to set the random number again
        await expect(wizards.setRandomNumber(_wizardSalt))
          .to.be.revertedWith("Number is already set");
      });
    });

    describe("Wizards - Admin Functions", function() {
      // Test Case 9.1: Testing the updateCuller function.
      it("should allow owner to update the culler", async function() {
        const newCuller = addrs[2].address;

        // Update the culler
        await wizards.updateCuller(newCuller);

        // Validate the new culler address
        expect(await wizards.culler()).to.equal(newCuller);
      });

      // Test Case 9.2: Testing the updateVerifier function.
      it("should allow owner to update the verifier", async function() {
        const newVerifier = addrs[3].address;

        // Update the verifier
        await wizards.updateVerifier(newVerifier);

        // Validate the new verifier address
        expect(await wizards.verifier()).to.equal(newVerifier);
      });

      // Test Case 9.3: Testing the updateAppointer function.
      it("should allow owner to update the appointer", async function() {
        const newAppointer = addrs[4].address;

        // Update the appointer
        await wizards.updateAppointer(newAppointer);

        // Validate the new appointer address
        expect(await wizards.appointer()).to.equal(newAppointer);
      });

      // Test Case 9.4: Testing the setReputationSmartContract function.
      it("should allow owner to set the reputation smart contract address", async function() {
        const reputationContractMock = addrs[5].address;

        // Set the reputation smart contract address
        await wizards.setReputationSmartContract(reputationContractMock);

        // Validate the new reputation smart contract address
        expect(await wizards.reputationSmartContract()).to.equal(reputationContractMock);
      });

      // Test Case 4.2: Testing the admin functions (updateCuller, updateVerifier, updateAppointer).
      it("should update the addresses for culler, verifier, and appointer correctly", async function() {
        const newCuller = addrs[1].address;
        const newVerifier = addrs[2].address;
        const newAppointer = addrs[3].address;

        await wizards.updateCuller(newCuller);
        await wizards.updateVerifier(newVerifier);
        await wizards.updateAppointer(newAppointer);

        expect(await wizards.culler()).to.equal(newCuller);
        expect(await wizards.verifier()).to.equal(newVerifier);
        expect(await wizards.appointer()).to.equal(newAppointer);
      });

      // Test Case 9.5: Testing the withdraw function.
      it("Owner can withdraw accumulated fees", async function() {
        const initialBalance = await ethers.provider.getBalance(owner.address);
        let tx = await wizards.withdraw();
        receipt = await tx.wait();
        const ethSpentOnGas = receipt.gasUsed.mul(receipt.effectiveGasPrice);

        const finalBalance = await await ethers.provider.getBalance(owner.address);
        expect(finalBalance.add(ethSpentOnGas).gt(initialBalance)).to.be.true;
      });

      // Test Case 9.6: Testing the withdraw function.
      it("should allow only the owner to withdraw the accumulated fees", async function() {
        await expect(wizards.connect(addr2).withdraw()).to.be.reverted;
      });

    });


    describe("Wizards - TokenURI", function() {

      // Test Case 10.1: Testing the tokenURI function for placeholder URI
      it("should generate correct token URI for placeholder", async function() {
        // This test can be expanded based on different states of a wizard - uninitiated, exiled, active, etc.

        const wizardId = 1;

        // Fetch token URI for a wizard
        const encodedUri = await wizards.tokenURI(wizardId);
        // Decode the base64 string
        const base64Data = encodedUri.split(",")[1];
        const uri = Buffer.from(base64Data, 'base64').toString('utf-8');

        // Parse the JSON and extract the image link
        const jsonObj = JSON.parse(uri);
        const imageLink = jsonObj.image;

        // Validation can be based on expected URIs or URI components
        expect(uri).to.contain("placeholder.jpg");
      });

      // Test Case 10.2: uninitiated URI
      it("should generate correct token URI for uninitiated", async function() {
        // This test can be expanded based on different states of a wizard - uninitiated, exiled, active, etc.

        const wizardId = 3;

        // Set the wizard salt for the first time
        await wizards.setRandomNumber(22159);

        // Fetch token URI for a wizard
        const encodedUri = await wizards.tokenURI(wizardId);
        // Decode the base64 string
        const base64Data = encodedUri.split(",")[1];
        const uri = Buffer.from(base64Data, 'base64').toString('utf-8');

        // Parse the JSON and extract the image link
        const jsonObj = JSON.parse(uri);
        const imageLink = jsonObj.image;

        // Validation can be based on expected URIs or URI components
        expect(imageLink).to.contain("uninitiated.jpg");
      });


      // Test Case 10.3: deserted URI
      it("should generate correct token URI for deserted", async function() {
        // This test can be expanded based on different states of a wizard - uninitiated, exiled, active, etc.

        const wizardId = 1;

        // Set the wizard salt for the first time
        await wizards.setRandomNumber(22159);

        // Advance time beyond
        await advanceTime(initialContractSettings.protectionTimeExtension + 1);

        // Fetch token URI for a wizard
        const encodedUri = await wizards.tokenURI(wizardId);
        // Decode the base64 string
        const base64Data = encodedUri.split(",")[1];
        const uri = Buffer.from(base64Data, 'base64').toString('utf-8');

        // Parse the JSON and extract the image link
        const jsonObj = JSON.parse(uri);
        const imageLink = jsonObj.image;

        // Validation can be based on expected URIs or URI components
        expect(imageLink).to.contain("inactive.jpg"); // todo -- note discrepancy in  naming convention: inactive vs deserted
      });


      // Test Case 10.4: exiled URI
      it("should generate correct token URI for exiled", async function() {
        // This test can be expanded based on different states of a wizard - uninitiated, exiled, active, etc.

        const wizardId = 3;

        // Set the wizard salt for the first time
        await wizards.setRandomNumber(22159);

        // Cull (exile)
        await wizards.cull(wizardId);

        // Fetch token URI for a wizard
        const encodedUri = await wizards.tokenURI(wizardId);
        // Decode the base64 string
        const base64Data = encodedUri.split(",")[1];
        const uri = Buffer.from(base64Data, 'base64').toString('utf-8');

        // Parse the JSON and extract the image link
        const jsonObj = JSON.parse(uri);
        const imageLink = jsonObj.image;

        // Validation can be based on expected URIs or URI components
        expect(imageLink).to.contain("exiled.jpg");
      });


      // Test Case 10.4: non-adult stages URI
      it("should generate correct token URI for non adult", async function() {
        // This test can be expanded based on different states of a wizard - uninitiated, exiled, active, etc.

        const wizardId = 1;

        // Set the wizard salt for the first time
        await wizards.setRandomNumber(22159);

        // set protectUntil to beyond non-adult
        await wizards.connect(owner).increaseProtectedUntilTimestamp(wizardId, initialContractSettings.phaseDuration*100)


        for(let i=0; i< 4; i++){
            // Fetch token URI for a wizard
            const encodedUri = await wizards.tokenURI(wizardId);
            // Decode the base64 string
            const base64Data = encodedUri.split(",")[1];
            const uri = Buffer.from(base64Data, 'base64').toString('utf-8');

            // Parse the JSON and extract the image link
            const jsonObj = JSON.parse(uri);
            const imageLink = jsonObj.image;

            // Validation can be based on expected URIs or URI components
            expect(imageLink).to.contain(i.toString() + ".jpg");

            // Advance time beyond
            await advanceTime(initialContractSettings.phaseDuration);
        }
      });




      // Test Case 10.5: Testing the tokenURI function for images of adult wizard.
      it("should generate correct token URI adult wizard", async function() {
        // This test can be expanded based on different states of a wizard - uninitiated, exiled, active, etc.

        const wizardId = 1;


        // Set the wizard salt for the first time
        await wizards.setRandomNumber(22159);

        // Advance time beyond
        await advanceTime(initialContractSettings.phaseDuration*10);


        // Fetch token URI for a wizard
        const encodedUri = await wizards.tokenURI(wizardId);
        // Decode the base64 string
        const base64Data = encodedUri.split(",")[1];
        const uri = Buffer.from(base64Data, 'base64').toString('utf-8');

        // Parse the JSON and extract the image link
        const jsonObj = JSON.parse(uri);
        const imageLink = jsonObj.image;

        // Validation can be based on expected URIs or URI components
        expect(imageLink).to.contain("data:image/svg+xml"); // As an example, check if it's a base64 encoded JSON
      });


      // Test Case 10.6: Testing the tokenURI function for misc.
      it("Should generate correct metadata about project", async function() {
        const wizardId = 1;
        // Fetch token URI for a wizard
        const encodedUri = await wizards.tokenURI(wizardId);
        // Decode the base64 string
        const base64Data = encodedUri.split(",")[1];
        const uri = Buffer.from(base64Data, 'base64').toString('utf-8');
        const jsonObj = JSON.parse(uri);

        // todo -- confirm this is what we want
        expect(jsonObj.name).to.be.equal("Wizard");
        expect(jsonObj.description).to.be.equal("Wizard Army DAO");
        expect(jsonObj.external_url).to.be.equal("https://www.wizards.club");
      });

      // Test Case 10.7: Testing the tokenURI function for misc.
      it("Should generate correct metadata about token", async function() {
        const wizardId = 1;

        // Fetch token URI for a wizard
        const encodedUri = await wizards.tokenURI(wizardId);
        // Decode the base64 string
        const base64Data = encodedUri.split(",")[1];
        const uri = Buffer.from(base64Data, 'base64').toString('utf-8');
        const jsonObj = JSON.parse(uri);

        // todo -- confirm these are the names we want and formatting
        const traitsToCheck = ["magic genes", "role", "upline id", "initiation timestamp", "protected until timestamp", "initiation timestamp"];

        traitsToCheck.forEach(trait => {
            expect(jsonObj.attributes.some(attr => attr.trait_type === trait), `Trait not found: ${trait}`).to.be.true;
        });

      });

    }); // end inner describe

    describe("Wizards - Events", function() {
      // Test Case 14.1: Testing NewVerifier event.
      it("should emit NewVerifier event when the verifier is updated", async function() {
        const newVerifier = addrs[0].address;

        await expect(wizards.updateVerifier(newVerifier))
          .to.emit(wizards, 'NewVerifier')
          .withArgs(newVerifier);
      });

      // Test Case 14.2: Testing NewCuller event.
      it("should emit NewCuller event when the culler is updated", async function() {
        const newCuller = addrs[0].address;

        await expect(wizards.updateCuller(newCuller))
          .to.emit(wizards, 'NewCuller')
          .withArgs(newCuller);
      });

      // Test Case 14.3: Testing NewAppointer event.
      it("should emit NewAppointer event when the appointer is updated", async function() {
        const newAppointer = addrs[0].address;

        await expect(wizards.updateAppointer(newAppointer))
          .to.emit(wizards, 'NewAppointer')
          .withArgs(newAppointer);
      });

      // Test Case 14.4: Testing Initiated event.
      it("should emit Initiated event when a wizard is initiated", async function() {
        const wizardId = 3; // assuming a valid wizardId for this test

        await expect(wizards.connect(addr3).initiate(wizardId, { value: initialContractSettings.initiationCost }))
          .to.emit(wizards, 'Initiated')
          .withNamedArgs({initiator: addr3.address, wizardId: wizardId});
      });

      // Test Case 14.5: Testing Exiled event.
      it("should emit Exiled event when a wizard is exiled", async function() {
        const wizardId = 1; // assuming a valid wizardId for this test

        await expect(wizards.connect(owner).cull(wizardId))
          .to.emit(wizards, 'Exiled')
          .withNamedArgs({exilee: addr1.address, wizardId: wizardId});
      });

    });

    // todo -- add to other sections
    describe("Wizards - Additional/Edge Tests", function() {
      // Test Case 17.1: Ensure minting costs are correct.
      it("should revert if trying to mint with less than the required minting cost", async function() {
        await expect(wizards.mint(0, {value: initialContractSettings.mintCost - 1})).to.be.reverted;
      });

      // Test Case 17.2: Ensure initiation costs are correct.
      it("should revert if trying to initiate with less than the required initiation cost", async function() {
        await expect(wizards.connect(addr3).initiate(1, {value: initialContractSettings.initiationCost - 1})).to.be.reverted;
      });

      // Test Case 17.3: Ensure that wizards that have been exiled cannot be initiated again immediately.
      it("should revert if trying to initiate an exiled wizard before the required exile time has passed", async function() {
        const wizardId = 1;
        await wizards.connect(owner).cull(wizardId); // Assuming the wizard meets the criteria for exile.
        await expect(wizards.connect(addr1).initiate(wizardId)).to.be.reverted;
      });

      // Test Case 17.4: Ensure wizards can't be initiated more than once.
      it("should revert if trying to initiate an already initiated wizard", async function() {
        const wizardId = 1;
//        await wizards.connect(addr1).initiate(wizardId);
        await expect(wizards.connect(addr1).initiate(wizardId)).to.be.reverted;
      });

      // Test Case 17.5: Ensure only the owner of a wizard can initiate it.
      it("should revert if a non-owner tries to initiate a wizard", async function() {
        const wizardId = 3;
        const nonOwner = addrs[2];
        await expect(wizards.connect(nonOwner).initiate(wizardId)).to.be.reverted;
      });

      // Test Case 21.2: Ensure that the contract does not accept Ether without a valid function call.
      it("should reject raw Ether transfers", async function() {
        await expect(addrs[1].sendTransaction({ to: wizards.address, value: ethers.utils.parseEther("1") })).to.be.reverted;
      });

    });


}); // end outer describe
