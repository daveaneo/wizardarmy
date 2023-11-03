const hre = require("hardhat");

async function verifyContract(contractAddress, contractNameWithPath, constructorArgs = []) {
  const networkId = await hre.network.provider.send("eth_chainId");
  const localNetworkId = "0x7a69"; // hardhat local

  // If on Hardhat's local network, simply return
  if (networkId === localNetworkId) {
    return;
  }

  try{
      await hre.run("verify:verify", {
        address: contractAddress,
        contract: contractNameWithPath,  // specify the contract name here
        constructorArguments: constructorArgs,
      });
  } catch (error) {
    console.error(`Error verifying ${contractNameWithPath}:`, error);
  }
}

async function verifyAll() {
    const deployedContracts = require('./deployedAddresses.json');
    const networkName = hre.network.name;

    console.log(deployedContracts)

    // Check if the current network has deployed addresses
    if (!deployedContracts[networkName]) {
        throw new Error(`No deployed addresses found for network: ${networkName}`);
    }

    const addresses = deployedContracts[networkName];


    await verifyContract(addresses.commonDefinitions, "contracts/libraries/CommonDefinitions.sol:CommonDefinitions");
    await verifyContract(addresses.geneLogic, "contracts/libraries/GeneLogic.sol:GeneLogic");
    await verifyContract(addresses.svgGenerator, "contracts/libraries/SVGGenerator.sol:SVGGenerator");
    await verifyContract(addresses.tokenURILibrary, "contracts/libraries/TokenURILibrary.sol:TokenURILibrary");
    await verifyContract(addresses.token, "contracts/Token.sol:Token", ["Wizard Gold", "WGLD", 18, ethers.utils.parseEther("1000")]);
    await verifyContract(addresses.wizards, "contracts/Wizards.sol:Wizards", ["Wizards", "WZD", addresses.token, "https://raw.githubusercontent.com/daveaneo/wizardarmy/master/token/wizard_army_pinata"]);
    await verifyContract(addresses.reputation, "contracts/Reputation.sol:Reputation", [addresses.wizards]);
    await verifyContract(addresses.wizardTower, "contracts/WizardTower.sol:WizardTower", [addresses.token, addresses.wizards]);
    await verifyContract(addresses.appointer, "contracts/Appointer.sol:Appointer", [addresses.wizards]);
    await verifyContract(addresses.governance, "contracts/Governance.sol:Governance", [addresses.token, addresses.wizards, addresses.wizardTower, addresses.appointer]);
}

// Export the verifyAll function
module.exports = {
  verifyAll
};
