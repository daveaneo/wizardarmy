import { useEffect, useState } from "react";
import { ethers } from "ethers";
//const dotenv = require('dotenv');


//const env = dotenv.config().parsed;
const WizardsNFTabi = require('../abi/wizards.json').abi;
const WizardTowerabi = require('../abi/wizardtower.json').abi;
const WizardBattleabi = require('../abi/wizardbattle.json').abi;
const WizardGovernanceabi = require('../abi/wizardgovernance.json').abi;
const ERC20abi = require('../abi/ERC20.json').abi;
const myInfuraRPC = process.env.REACT_APP_MUMBAI_RPC;

let ecosystemTokenAddress = '0x6E6FFeBF8327406623Bce7D9e7c6e9a4aeBa9DCA';
let wizardNFTAddress = '0x5F5CAF7ffcB0828E7Cc84C276b743873a54D3243';
let wizardTowerAddress = '0x5F5CAF7ffcB0828E7Cc84C276b743873a54D3243';
let wizardBattleAddress = '0x28B9E0BE9C7eC72DA736d6805C1A9D6Db9421134';
let wizardGovernanceAddress = '0x34C51ff2b057fe5a595ecc1FaA00f819fdCE69f6';


 // load some data without metamask or signer
const getNFTContractNoSigner = () => {
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
