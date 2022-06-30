import { useEffect, useState } from "react";
import { ethers } from "ethers";

const WizardsNFTabi = require('../abi/wizards.json').abi;
const WizardTowerabi = require('../abi/wizardtower.json').abi;
const WizardBattleabi = require('../abi/wizardbattle.json').abi;
const ERC20abi = require('../abi/ERC20.json').abi;

let ecosystemTokenAddress = '0xA55B9C38a7b4caA01A1F9B118c8F8e3688D6b01D';
let wizardNFTAddress = '0x26f4e2Fc2e49638197BAE42c9Ab09E863BCf2F59';
let wizardTowerAddress = '0x9fF44712b244F3a42E60B8803e77F0D4fFb51709';
let wizardBattleAddress = '0xb6680a1203A8a3AFDFB1807c6881e5704C505E47';


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
