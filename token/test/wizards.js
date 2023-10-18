const { expect } = require("chai");
const { ethers } = require("hardhat");

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
    Token = await ethers.getContractFactory("Token", {
    });
    token = await TokenURILibrary.deploy();
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

    [owner, addr1, addr2, addr3, addr4,  ...addrs] = await ethers.getSigners();

    // mint 3 wizards, initatiate first 2
    await wizards.connect(addr1).mint(0); // wizid 1
    await wizards.connect(addr1).initiate(1, {value: initialContractSettings.initiationCost});

    await wizards.connect(addr2).mint(1); // wizid 2
    await wizards.connect(addr2).initiate(2, {value: initialContractSettings.initiationCost});

    await wizards.connect(addr3).mint(2);

  });

  // Test Case 1.1: Ensure the contract is initialized with the correct default state.
  it("should initialize with the correct default state", async function() {
    const verifier = await wizards.connect(addr1).verifier();
    expect(verifier).to.equal(owner.address);

    const culler = await wizards.culler();
    expect(culler).to.equal(owner.address);

    const appointer = await wizards.appointer();
    expect(appointer).to.equal(owner.address);

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







});
