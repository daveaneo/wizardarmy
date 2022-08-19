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

let ecosystemTokenAddress = '0xC778A37162735eA8323711311800F6Ea5D063648';
let wizardNFTAddress = '0x648D94430079eff58726b29B87B74EE784E7b3EF';
let wizardTowerAddress = '0x3Ed539E41e9431BDbC403939806352A68ee91daA';
let wizardBattleAddress = '0xA4D5375BF4Cd5cb328B38f59c23908275609b92c';
let wizardGovernanceAddress = '0xea5867Cb3ccf04BF5D8e82df3fDf557a2Cb3f45f';


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
