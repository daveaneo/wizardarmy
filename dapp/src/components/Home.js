import { useEffect, useState } from "react";
import { ethers } from "ethers";
import MyWizards from '../components/MyWizards';
import "../App.css";
import { useSelector } from "react-redux";


function Home(props) {
//  const connected = props.connected;
//  const address = props.address;
  const numWizards = props.numWizards;
  const setNumWizards = props.setNumWizards;
  const smartContracts = useSelector(state => state.smartContracts)
  const address = useSelector(state => state.account)

  // Load signed, unsigned contracts from Redux
  const NFTContractNoSigner = smartContracts.nftContractNoSigner;
//  const ecosystemTokenContract = smartContracts.ecosystemTokenContract;
  const wizardNFTContract = smartContracts.wizardNFTContract;
//  const wizardTowerContract =smartContracts.wizardTowerContract;
//  const wizardBattleContract =smartContracts.wizardBattleContract;


  async function mintWizard() {
     wizardNFTContract.mint().then( tx => {
         tx.wait(1).then( (res) => {
             if(tx.status !=0 ){
               setNumWizards(numWizards + 1);
             }
             else {
               console.log("Something went wrong with minting.")
             }
         });
     });
  }

  async function updateNumWizards() {
    if(NFTContractNoSigner!==undefined){
        let num = parseInt((await NFTContractNoSigner.totalSupply()));
        setNumWizards(num);
    }
    else{
    }
  }

  useEffect(() => {
  }, []);

  useEffect(() => {
    updateNumWizards();
  }, [smartContracts]); //


  return (
        <div className="App">
          <div className="wizardarmy-title">
            Wizard
            {"\n"} Army
           </div>
          <div className="wizardarmy-subtitle">{numWizards} strong! </div>
            {address && <MyWizards
//                  connected = {connected}
                  numWizards = {numWizards}
//                  address = {address}
               />
            }
        </div>
  );
}

export default Home;
