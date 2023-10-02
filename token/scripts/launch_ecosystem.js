require('dotenv').config();

const { Wallet } = require('ethers');
const fs = require('fs');
const path = require('path');


function getRandomUint256() {
  const max = BigInt("0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"); // 2^256 - 1
  const rand = BigInt(Math.floor(Math.random() * Number(max)));
  return rand;
}


async function main() {
    const [deployer, secondary] = await ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);


    const myWallet = new Wallet('0x' + process.env.EVM_PRIVATE_KEY);
    console.log("Polygon account address:", myWallet.address);

    exit(0);

    // Deploying the CommonDefinitions Library
    const CommonDefinitions = await ethers.getContractFactory("CommonDefinitions");
    const commonDefinitions = await CommonDefinitions.deploy();
    await commonDefinitions.deployed();
    console.log("CommonDefinitions Library deployed to:", commonDefinitions.address);

    // Deploying the GeneLogic Library
    const GeneLogic = await ethers.getContractFactory("GeneLogic");
    const geneLogic = await GeneLogic.deploy();
    await geneLogic.deployed();
    console.log("GeneLogic Library deployed to:", geneLogic.address);


    // Link the GeneLogic library to the SVGGenerator and deploy
    const SVGGenerator = await ethers.getContractFactory("SVGGenerator", {
        libraries: {
            "GeneLogic": geneLogic.address,
//            "CommonDefinitions": commonDefinitions.address
        }
    });
    const svgGenerator = await SVGGenerator.deploy();
    await svgGenerator.deployed();
    console.log("SVGGenerator Library deployed to:", svgGenerator.address);


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


    // Deploying the Token
    const Token = await ethers.getContractFactory("Token", {
    });
    const token = await TokenURILibrary.deploy();
    await token.deployed();
    console.log("Token deployed to:", token.address);



    // Linking Libraries to the Wizards Contract
//    const WizardsArtifact = await ethers.getContractFactory("Wizards");
    const WizardsArtifact = await ethers.getContractFactory("Wizards", {
        libraries: {
            "TokenURILibrary": tokenURILibrary.address
        }
    });

    // Now deploy the Wizards contract as before:
    const wizards = await WizardsArtifact.deploy("Wizards", "WZD", token.address, "https://gateway.pinata.cloud/ipfs/");
    await wizards.deployed();
    console.log("Wizards deployed to:", wizards.address);



    const WizardTower = await ethers.getContractFactory("WizardTower");
    const wizardTower = await WizardTower.deploy(token.address, wizards.address);
    await wizardTower.deployed();
    console.log("WizardTower deployed to:", wizardTower.address);

    // todo -- fix Governance Cost
    const governance = {}
//
//    const Governance = await ethers.getContractFactory("Governance");
//    const governance = await Governance.deploy(wizards.address, wizardTower.address);
//    await governance.deployed();
//    console.log("Governance deployed to:", governance.address);


    const Appointer = await ethers.getContractFactory("Appointer");
    const appointer = await Appointer.deploy(wizards.address);
    await appointer.deployed();
    console.log("Appointer deployed to:", appointer.address);

    // Save contract addresses
//    todo -- update with library addresses
    const deployedContracts = {
        token: token.address,
        wizards: wizards.address,
        wizardTower: wizardTower.address,
        governance: governance.address,
        appointer: appointer.address
    };

    fs.writeFileSync(path.join(__dirname, 'deployed_contracts.json'), JSON.stringify(deployedContracts, null, 2));

    // Additional deployment logic if necessary...

    // mint wizard
    await wizards.mint(0); // upline id
    console.log("Minted a wizard for:", deployer.address);

    // Set Salt

    const randomNumber = getRandomUint256();
    await wizards.setRandomNumber(randomNumber); // upline id
    console.log("salt set as: ", randomNumber.toString());


    // get token URI
    const tokenId = 1; // or whatever your starting tokenId is
    const uri = await wizards.tokenURI(tokenId);
    console.log("Token URI for wizard:", uri);


    //

}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
