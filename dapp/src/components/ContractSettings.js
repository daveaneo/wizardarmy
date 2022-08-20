import { useEffect, useState } from "react";
import { ethers } from "ethers";
//const dotenv = require('dotenv');


//const env = dotenv.config().parsed;
const WizardsNFTabi = require('../abi/wizards.json').abi;
const WizardTowerabi = require('../abi/wizardtower.json').abi;
const WizardBattleabi = require('../abi/wizardbattle.json').abi;
const WizardGovernanceabi = require('../abi/wizardgovernance.json').abi;
const ERC20abi = require('../abi/ERC20.json').abi;
const myInfuraRPC = process.env.REACT_APP_RINKEBY_RPC;

let ecosystemTokenAddress = '0x6547619143B65450CcB4870667d18670FB67C3C8';
let wizardNFTAddress = '0x146fDe4AdD4551b34dA92f5A218DB517eBCD3Ec9';
let wizardTowerAddress = '0xC01AC0e865CAc86BeADe722b8f74ca6562B2B00e';
let wizardBattleAddress = '0x78daf9c11365E3c91fE1d16eE3d269B7C4Cc1AC4';
let wizardGovernanceAddress = '0x8b87322a32f643af158d3402888256C444A6402e';


 // load some data without metamask or signer
const getNFTContractNoSigner = () => {
  const RPC = "https://... RPC provider e.g. Infura in my case";
  const provider = new ethers.providers.JsonRpcProvider(myInfuraRPC);
  const icoContract = new ethers.Contract(wizardNFTAddress, WizardsNFTabi, provider);

  return icoContract;
}

function ContractSettings(props) {
    const address = props.address;
    const setAddress = props.setAddress;
    const connected = props.connected;
    const setConnected = props.setConnected;

  let { ethereum } = window;


  // create contracts that don't need signatures
  if(window.NFTContractNoSigner===undefined){
      const noSigninNFTContract = getNFTContractNoSigner();
      window.NFTContractNoSigner = noSigninNFTContract;
   }


  if(ethereum){
    UpdateAddress();
  }
    async function UpdateAddress() {
        let provider = new ethers.providers.Web3Provider(ethereum);
        let signer = provider.getSigner();
        let newAddress = undefined;

        try{
          newAddress = await signer.getAddress();
        } catch(e) {
         // console.error("ERROR. No account signed in (likely).");
         }

        if(newAddress!== undefined){
            window.provider = provider;
            const ecosystemTokenContract = new ethers.Contract(ecosystemTokenAddress, ERC20abi, signer);
            const wizardNFTContract = new ethers.Contract(wizardNFTAddress, WizardsNFTabi, signer);
            const wizardTowerContract = new ethers.Contract(wizardTowerAddress, WizardTowerabi, signer);
            const wizardBattleContract = new ethers.Contract(wizardBattleAddress, WizardBattleabi, signer);
            const wizardGovernanceContract = new ethers.Contract(wizardGovernanceAddress, WizardGovernanceabi, signer);

//              Promise.all([ecosystemTokenContract, wizardNFTContract, wizardTowerContract, wizardBattleContract]).then( () =>{
            window.ecosystemToken = ecosystemTokenContract;
            window.wizardNFTContract = wizardNFTContract;
            window.wizardTowerContract = wizardTowerContract;
            window.wizardBattleContract = wizardBattleContract;
            window.wizardGovernanceContract = wizardGovernanceContract;
//              })
        }

        if(address!= newAddress){
          setAddress(newAddress);
        }


    }

    useEffect(() => {
        UpdateAddress();
    }, []);

    useEffect(() => {
        UpdateAddress();
    }, [address]);
}

//  return ()

export default ContractSettings;
