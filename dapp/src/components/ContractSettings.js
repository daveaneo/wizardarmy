import { useEffect, useState } from "react";
import { ethers } from "ethers";
//const dotenv = require('dotenv');


//const env = dotenv.config().parsed;
const WizardsNFTabi = require('../abi/wizards.json').abi;
const WizardTowerabi = require('../abi/wizardtower.json').abi;
const WizardBattleabi = require('../abi/wizardbattle.json').abi;
const WizardGovernanceabi = require('../abi/wizardgovernance.json').abi;
const ERC20abi = require('../abi/ERC20.json').abi;
const myInfuraMumbaiRPC = process.env.REACT_APP_MUMBAI_RPC;
const myInfuraRinkebyRPC = process.env.REACT_APP_RINKEBY_RPC;
const networkIdUsed=4;

let ecosystemTokenAddress = '0x600dafEF3d5E493F9bee74Cc4aBd73a86AD08Cc2';
let wizardNFTAddress = '0x2032c752b40D9ce5Fa734a5b752B13B8eBEA798E';
let wizardTowerAddress = '0xA3D74F6D5D3a6455ECd257a34599d865FD09aC56';
let wizardBattleAddress = '0x652fDEA334B1d136ddf5AD37633754049f7f48CF';
let wizardGovernanceAddress = '0xF1ddC2469E07Ef2dA2b005e32d84000bD60a58d9';


 // load some data without metamask or signer
async function getNFTContractNoSigner() {
  console.log("DAVID")
//  const provider = await( new ethers.providers.JsonRpcProvider());


//  const { chainId } = await provider.getNetwork();
  const chainId = networkIdUsed;
  let myRPC;
  console.log("chainId: ", chainId)
  if(chainId==4){
    myRPC= myInfuraRinkebyRPC;
  }
  else if(chainId==80001 ){
    myRPC= myInfuraMumbaiRPC;
  }
  else{
    return undefined; // errors???
  }

  const provider = new ethers.providers.JsonRpcProvider(myRPC);
  var icoContract = await( new ethers.Contract(wizardNFTAddress, WizardsNFTabi, provider));
  console.log("isoContract: ", icoContract)
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
      const noSigninNFTContract = getNFTContractNoSigner().then( (contract) => {
        window.NFTContractNoSigner = contract;
      });
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
