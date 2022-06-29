import { ethers } from "ethers";

const WizardsNFTabi = require('./abi/wizards.json').abi;
const WizardTowerabi = require('./abi/wizardtower.json').abi;
const WizardBattleabi = require('./abi/wizardbattle.json').abi;
const ERC20abi = require('./abi/ERC20.json').abi;

let ecosystemTokenAddress = '0xa1ED495b9fD64F1cde3D0474AC2FA202f7a81D0D';
let wizardNFTAddress = '0x2f04B981Df0B008d04C5230122ceBEb9251c1d14';
let wizardTowerAddress = '0x4519eF35be35CC5F3D2e91B83123AebCa8743926';
let wizardBattleAddress = '0x2D82Df4c05e3ed6c47Db238b21b0347214C91557';


  let { ethereum } = window;

  if (ethereum) {
    let provider = new ethers.providers.Web3Provider(ethereum);
    let signer = provider.getSigner();

    window.provider = provider;
    window.ecosystemToken = new ethers.Contract(ecosystemTokenAddress, ERC20abi, signer);
    window.wizardNFTContract = new ethers.Contract(wizardNFTAddress, WizardsNFTabi, signer);
    window.wizardTowerContract = new ethers.Contract(wizardTowerAddress, WizardTowerabi, signer);
    window.wizardBattleContract = new ethers.Contract(wizardBattleAddress, WizardBattleabi, signer);
    window.signer = signer;
    signer.getAddress().then((prom) => {
      window.address = prom;
    });


    // const { chainId } = provider.getNetwork();
//    console.log(ethereum);
//    console.log(provider);
//    console.log(signer);
  }