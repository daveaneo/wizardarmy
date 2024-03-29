require('dotenv').config();
const hre = require("hardhat");
const { Wallet } = require('ethers');
const fs = require('fs');
const path = require('path');
const { verifyAll } = require('./verifyAll');

const USE_LAST_DEPLOYMENT = true; // Toggle this variable to control behavior
//const deployedAddresses = require('./deployedAddresses.json');
const NUM_CONFIRMATIONS_NEEDED = 2;

function getDeployedAddresses() {
    try {
        return require('./deployedAddresses.json');
    } catch (error) {
        if (error.code === 'MODULE_NOT_FOUND') {
            return {};  // Return an empty object if the file doesn't exist
        }
        throw error;  // Rethrow if it's some other error
    }
}

const deployedAddresses = getDeployedAddresses();


function getRandomUint256() {
  const max = BigInt("0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"); // 2^256 - 1
  const rand = BigInt(Math.floor(Math.random() * Number(max)));
  return rand;
}


const advanceTime = async (seconds) => {
    await network.provider.send("evm_increaseTime", [seconds])
    await ethers.provider.send("evm_mine");
};



async function saveContractAddresses(contracts) {
    // Detect the network
    const networkName = hre.network.name;

    // Path to your deployed contracts JSON file
    const filePath = path.join(__dirname, 'deployedAddresses.json');

    // Read existing data
    let data;
    try {
        data = JSON.parse(fs.readFileSync(filePath, 'utf8'));
    } catch (err) {
        data = {};
    }

    // Ensure there's an object for our network
    if (!data[networkName]) {
        data[networkName] = {};
    }

    // Update the data for the current network
    data[networkName] = {
        ...data[networkName],
        commonDefinitions: contracts.commonDefinitions,
        geneLogic: contracts.geneLogic,
        svgGenerator: contracts.svgGenerator,
        tokenURILibrary: contracts.tokenURILibrary,
        token: contracts.token,
        wizards: contracts.wizards,
        wizardTower: contracts.wizardTower,
        appointer: contracts.appointer,
        governance: contracts.governance,
        reputation: contracts.reputation,
    };

    // Write the updated data back to the file
    fs.writeFileSync(filePath, JSON.stringify(data, null, 2));
}


async function deploy_new() {
    //  const [deployer, secondary] = await ethers.getSigners();

    // Deploying the CommonDefinitions Library
    const CommonDefinitions = await ethers.getContractFactory("CommonDefinitions");
    const commonDefinitions = await CommonDefinitions.deploy();
    await commonDefinitions.deployed();
    console.log("CommonDefinitions Library deployed to:", commonDefinitions.address);

    // Wait for the transaction to be confirmed
    await commonDefinitions.deployTransaction.wait(NUM_CONFIRMATIONS_NEEDED);

    // Deploying the GeneLogic Library
    const GeneLogic = await ethers.getContractFactory("GeneLogic");
    const geneLogic = await GeneLogic.deploy();
    await geneLogic.deployed();
    console.log("GeneLogic Library deployed to:", geneLogic.address);

    // Wait for the transaction to be confirmed
    await geneLogic.deployTransaction.wait(NUM_CONFIRMATIONS_NEEDED);


    // Link the GeneLogic library to the SVGGenerator and deploy
    const SVGGenerator = await ethers.getContractFactory("SVGGenerator", {
        libraries: {
            "GeneLogic": geneLogic.address,
        }
    });
    const svgGenerator = await SVGGenerator.deploy();
    await svgGenerator.deployed();
    console.log("SVGGenerator Library deployed to:", svgGenerator.address);

    // Wait for the transaction to be confirmed
    await svgGenerator.deployTransaction.wait(NUM_CONFIRMATIONS_NEEDED);

    // Deploying the TokenURILibrary
    const TokenURILibrary = await ethers.getContractFactory("TokenURILibrary", {
        libraries: {
            "GeneLogic": geneLogic.address,
            "SVGGenerator": svgGenerator.address
        }
    });
    const tokenURILibrary = await TokenURILibrary.deploy();
    await tokenURILibrary.deployed();
    console.log("TokenURILibrary deployed to:", tokenURILibrary.address);

    // Wait for the transaction to be confirmed
    await tokenURILibrary.deployTransaction.wait(NUM_CONFIRMATIONS_NEEDED);

    // Deploying the Token
    const Token = await ethers.getContractFactory("Token", {
    });
    const token = await Token.deploy("Wizard Gold", "WGLD", 18, ethers.utils.parseEther("1000"));
    await token.deployed();
    console.log("Token deployed to:", token.address);

    // Wait for the transaction to be confirmed
    await token.deployTransaction.wait(NUM_CONFIRMATIONS_NEEDED);

    // Linking Libraries to the Wizards Contract
//    const WizardsArtifact = await ethers.getContractFactory("Wizards");
    const WizardsArtifact = await ethers.getContractFactory("Wizards", {
        libraries: {
            "TokenURILibrary": tokenURILibrary.address
        }
    });

    // Now deploy the Wizards contract as before:
    const wizards = await WizardsArtifact.deploy("Wizards", "WZD", token.address, "https://raw.githubusercontent.com/daveaneo/wizardarmy/master/token/wizard_army_pinata"); // todo -- add '/' or not documentation
    await wizards.deployed();
    console.log("Wizards deployed to:", wizards.address);

    // Wait for the transaction to be confirmed
    await wizards.deployTransaction.wait(NUM_CONFIRMATIONS_NEEDED);

    // Now deploy the Wizards contract as before:
    const Reputation = await ethers.getContractFactory("Reputation");
    const reputation = await Reputation.deploy(wizards.address);
    await reputation.deployed();
    console.log("Reputation deployed to:", reputation.address);

    // Wait for the transaction to be confirmed
    await reputation.deployTransaction.wait(NUM_CONFIRMATIONS_NEEDED);


    const WizardTower = await ethers.getContractFactory("WizardTower");
    const wizardTower = await WizardTower.deploy(token.address, wizards.address);
    await wizardTower.deployed();
    console.log("WizardTower deployed to:", wizardTower.address);

    // Wait for the transaction to be confirmed
    await wizardTower.deployTransaction.wait(NUM_CONFIRMATIONS_NEEDED);

    const Appointer = await ethers.getContractFactory("Appointer");
    const appointer = await Appointer.deploy(wizards.address);
    let res = await appointer.deployed();
    console.log("Appointer deployed to:", appointer.address);

    // Wait for the transaction to be confirmed
    await appointer.deployTransaction.wait(NUM_CONFIRMATIONS_NEEDED);

    const Governance = await ethers.getContractFactory("Governance");
    const governance = await Governance.deploy(token.address, wizards.address, wizardTower.address, appointer.address);
    await governance.deployed();
    console.log("Governance deployed to:", governance.address);

    // Wait for the transaction to be confirmed
    await governance.deployTransaction.wait(NUM_CONFIRMATIONS_NEEDED);

    // Save contract addresses
    const deployedContracts = {
        commonDefinitions: commonDefinitions.address,
        geneLogic: geneLogic.address,
        svgGenerator: svgGenerator.address,
        tokenURILibrary: tokenURILibrary.address,
        token: token.address,
        wizards: wizards.address,
        wizardTower: wizardTower.address,
        governance: governance.address,
        appointer: appointer.address,
        reputation: reputation.address
    };

//    fs.writeFileSync(path.join(__dirname, 'deployed_contracts.json'), JSON.stringify(deployedContracts, null, 2));
    await saveContractAddresses(deployedContracts);

    return { commonDefinitions, geneLogic, svgGenerator, tokenURILibrary, token, wizards, wizardTower, appointer, reputation };
}

async function get_deployed() {
    const networkName = hre.network.name;


    // Check if the current network has deployed addresses
    if (!deployedAddresses[networkName]) {
        throw new Error(`No deployed addresses found for network: ${networkName}`);
    }

    const addresses = deployedAddresses[networkName];

    const CommonDefinitions = await ethers.getContractFactory("CommonDefinitions");
    const commonDefinitions = CommonDefinitions.attach(addresses.commonDefinitions);

    const GeneLogic = await ethers.getContractFactory("GeneLogic");
    const geneLogic = GeneLogic.attach(addresses.geneLogic);

    const SVGGenerator = await ethers.getContractFactory("SVGGenerator", {
        libraries: {
            "GeneLogic": geneLogic.address,
        }
    });
    const svgGenerator = SVGGenerator.attach(addresses.svgGenerator);

    const TokenURILibrary = await ethers.getContractFactory("TokenURILibrary", {
        libraries: {
            "GeneLogic": geneLogic.address,
            "SVGGenerator": svgGenerator.address
        }
    });
    const tokenURILibrary = TokenURILibrary.attach(addresses.tokenURILibrary);

    const Token = await ethers.getContractFactory("Token");
    const token = Token.attach(addresses.token);

    const Wizards = await ethers.getContractFactory("Wizards", {
        libraries: {
            "TokenURILibrary": tokenURILibrary.address
        }
    });
    const wizards = Wizards.attach(addresses.wizards);

    const WizardTower = await ethers.getContractFactory("WizardTower");
    const wizardTower = WizardTower.attach(addresses.wizardTower);

    const Appointer = await ethers.getContractFactory("Appointer");
    const appointer = Appointer.attach(addresses.appointer);

    const Governance = await ethers.getContractFactory("Governance");
    const governance = Governance.attach(addresses.governance);


    // Now deploy the Wizards contract as before:
    const Reputation = await ethers.getContractFactory("Reputation");
    const reputation = await Reputation.attach(addresses.reputation);


    const contracts = {
        commonDefinitions,
        geneLogic,
        svgGenerator,
        tokenURILibrary,
        token,
        wizards,
        wizardTower,
        appointer,
        reputation
    };

    // Logging contract names and addresses
    for (let [contractName, contractInstance] of Object.entries(contracts)) {
        console.log(`${contractName}: ${contractInstance.address}`);
    }

    return contracts;}


async function main() {
    let contracts;
    const [deployer, secondary] = await ethers.getSigners();

    if (USE_LAST_DEPLOYMENT) {
        contracts = await get_deployed();
    } else {
        contracts = await deploy_new();
    }

    const { commonDefinitions, geneLogic, svgGenerator, tokenURILibrary, token, wizards, wizardTower, appointer, governance,  reputation } = contracts;



    wizards.connect(deployer).setReputationSmartContract(reputation.address);

    console.log("contracts exist. Minting...")

    // Get contract settings
    contractSettings = await wizards.contractSettings();

    let tx;

    // mint wizard
    tx = await wizards.mint(0); // upline id
    await tx.wait();
    console.log("Minted a wizard for:", deployer.address);

    // mint wizard
    tx = await wizards.mint(0); // upline id
    await tx.wait();
    console.log("Minted a wizard for:", deployer.address);

    // mint wizard
    tx = await wizards.mint(0); // upline id
    await tx.wait();
    console.log("Minted a wizard for:", deployer.address);

    // initiate wizard 1
    tx = await wizards.initiate(1, {value: contractSettings.initiationCost});
    await tx.wait();

    // initiate wizard 2
    tx = await wizards.initiate(2, {value: contractSettings.initiationCost});
    await tx.wait();

    //    // todo -- for testing only
    //    advanceTime(100000);


    // Set Salt

    const randomNumber = getRandomUint256();
    tx = await wizards.setRandomNumber(randomNumber); // upline id
    await tx.wait();
    console.log("salt set as: ", randomNumber.toString());


    // get token URI
    const tokenId = 1; // or whatever your starting tokenId is
    const uri = await wizards.tokenURI(tokenId);
    console.log("Token URI for wizard:", uri);

    tx.wait(20)
    await verifyAll();


}











main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
