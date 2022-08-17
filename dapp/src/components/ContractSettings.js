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

let ecosystemTokenAddress = '0x5cB89CCf854B603b357685F60Da9477B21f0bE3c';
let wizardNFTAddress = '0x06bbE541e5d53047cB3a4ffcaf7BfbfFe0C83181';
let wizardTowerAddress = '0x1576Ed09E37b2052f0110Cc8816A1C0Aa82415F9';
let wizardBattleAddress = '0xE4232E741eF69D62BCc48103A8e4EB115A4028F0';
let wizardGovernanceAddress = '0x30F0648a1aE1Ae3B8a6808F6981b37D1c8A59F71';


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
