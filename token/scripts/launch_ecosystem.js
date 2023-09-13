const fs = require('fs');
const path = require('path');

async function main() {
    const [deployer, secondary] = await ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);

    // Deployment
    const Token = await ethers.getContractFactory("Token");
    const token = await Token.deploy("Test Token", "TST", 18, ethers.utils.parseEther("1000"));
    await token.deployed();
    console.log("Token deployed to:", token.address);

    const Wizards = await ethers.getContractFactory("Wizards");
    const wizards = await Wizards.deploy("Wizards", "WZD", token.address, "https://gateway.pinata.cloud/ipfs/");
    await wizards.deployed();
    console.log("Wizards deployed to:", wizards.address);

    const WizardTower = await ethers.getContractFactory("WizardTower");
    const wizardTower = await WizardTower.deploy(token.address, wizards.address);
    await wizardTower.deployed();
    console.log("WizardTower deployed to:", wizardTower.address);

    const Governance = await ethers.getContractFactory("Governance");
    const governance = await Governance.deploy(wizards.address, wizardTower.address);
    await governance.deployed();
    console.log("Governance deployed to:", governance.address);

    const Appointer = await ethers.getContractFactory("Appointer");
    const appointer = await Appointer.deploy(wizards.address);
    await appointer.deployed();
    console.log("Appointer deployed to:", appointer.address);

    // Save contract addresses
    const deployedContracts = {
        token: token.address,
        wizards: wizards.address,
        wizardTower: wizardTower.address,
        governance: governance.address,
        appointer: appointer.address
    };

    fs.writeFileSync(path.join(__dirname, 'deployed_contracts.json'), JSON.stringify(deployedContracts, null, 2));

    // Additional deployment logic if necessary...
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
