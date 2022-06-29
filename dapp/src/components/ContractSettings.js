import { useEffect, useState } from "react";
import { ethers } from "ethers";

const WizardsNFTabi = require('../abi/wizards.json').abi;
const WizardTowerabi = require('../abi/wizardtower.json').abi;
const WizardBattleabi = require('../abi/wizardbattle.json').abi;
const ERC20abi = require('../abi/ERC20.json').abi;

let ecosystemTokenAddress = '0x69dCeccbc22A30d7f215A364e7475395EB8F1141';
let wizardNFTAddress = '0xf397C5d01b9bC2f221127579C508af6c58a1Db32';
let wizardTowerAddress = '0x6946614a78e43De296766C45eaE5177a80FD24fe';
let wizardBattleAddress = '0x1941F8cAcc32Dfc41468f7E0c83940238c71dce5';


function ContractSettings(props) {
    const address = props.address;
    const setAddress = props.setAddress;
    const connected = props.connected;
    const loadAddress = props.loadAddress;
    const setConnected = props.setConnected;

  let { ethereum } = window;

//  console.log("ContractSettings");
//  console.log("props: ", props);
//  console.log("address, connected: ", address, connected)

  if(ethereum){
    UpdateAddress();
  }

    async function UpdateAddress() {
        let provider = new ethers.providers.Web3Provider(ethereum);
        let signer = provider.getSigner();

        window.provider = provider;
        window.ecosystemToken = new ethers.Contract(ecosystemTokenAddress, ERC20abi, signer);
        window.wizardNFTContract = new ethers.Contract(wizardNFTAddress, WizardsNFTabi, signer);
        window.wizardTowerContract = new ethers.Contract(wizardTowerAddress, WizardTowerabi, signer);
        window.wizardBattleContract = new ethers.Contract(wizardBattleAddress, WizardBattleabi, signer);
        const newAddress = await signer.getAddress();
//        console.log("newAddress: ", newAddress);
        if(address!= newAddress){
          setAddress(newAddress);
//          setConnected(true);
        }
    }

    useEffect(() => {
        UpdateAddress();
    }, []);
}

//  return ()

export default ContractSettings;
