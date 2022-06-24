import { ethers } from "ethers";

const WizardsNFTabi = require('./abi/wizards.json').abi;
const WizardTowerabi = require('./abi/wizardtower.json').abi;
const WizardBattleabi = require('./abi/wizardbattle.json').abi;
const ERC20abi = require('./abi/ERC20.json').abi;

let ecosystemTokenAddress = '0x2d53d04DC404e69a78195cD20cCa30a8e8aD993D';
let wizardNFTAddress = '0x7e810087848937c3845530Dc0c2b240fFC8956dA';
let wizardTowerAddress = '0xb51E7d64A2894dd8e6D1B514564187a0ae4146E3';
let wizardBattleAddress = '0x129B0be1438EC823Bc8706ef6bEF437F29912Ec4';


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