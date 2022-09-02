import { useEffect, useState } from "react";
import { ethers } from "ethers";
import {Link} from "react-router-dom";

function MyWizards(props) {
  const connected = props.connected;
  const numWizards = props.numWizards;
  const address = props.address;
//  let [connected, setConnected] = useState(false);
  const [wizardIDs, setWizardIDs] = useState([]);
  const [wizards, setWizards] = useState([]);
  const [myNumWizards, setMyNumWizards] = useState(0);
  const [myTokens, setMyTokens] = useState(undefined);

  const [time, setTime] = useState(Date.now());

  // contracts
  const { ethereum } = window;
  const ecosystemTokenContract = window.ecosystemToken;
  const wizardNFTContract = window.wizardNFTContract;
  const wizardTowerContract =window.wizardTowerContract;
  const wizardBattleContract =window.wizardBattleContract;
  const signer = window.signer;
  const ELEMENTS = ["Fire", "Wind", "Water", "Earth"]
  let isLoadingMyWizards = false;


    async function processWizardStructByIndex(ind) {
        let id = parseInt(await wizardNFTContract.tokenOfOwnerByIndex(address, ind));
        let wiz = await wizardNFTContract.tokenIdToStats(id);
        let processedWizard = {};
        processedWizard.id = parseInt(id);
        processedWizard.level = parseInt(wiz.level);
        processedWizard.hp = parseInt(wiz.hp);
        processedWizard.magicalPower = parseInt(wiz.magicalPower);
        processedWizard.magicalDefense = parseInt(wiz.magicalDefense);
        processedWizard.speed = parseInt(wiz.speed);
        processedWizard.wins = parseInt(wiz.wins);
        processedWizard.losses = parseInt(wiz.losses);
        processedWizard.battles = parseInt(wiz.battles);
        processedWizard.tokensClaimed = parseInt(wiz.tokensClaimed);
        processedWizard.goodness = parseInt(wiz.goodness);
        processedWizard.badness = parseInt(wiz.badness);
        processedWizard.initiationTimestamp = parseInt(wiz.initiationTimestamp);
        processedWizard.protectedUntilTimestamp = parseInt(wiz.protectedUntilTimestamp);
        processedWizard.element = ELEMENTS[parseInt(wiz.element)];
        const tokenURI = JSON.parse(await wizardNFTContract.tokenURI(id));
        processedWizard.imageURL = tokenURI.image;
        return processedWizard;
    }


    async function processWizardStruct(wiz, id) {
        let processedWizard = {};
        processedWizard.id = parseInt(id);
        processedWizard.level = parseInt(wiz.level);
        processedWizard.hp = parseInt(wiz.hp);
        processedWizard.mp = parseInt(wiz.mp);
        processedWizard.wins = parseInt(wiz.wins);
        processedWizard.losses = parseInt(wiz.losses);
        processedWizard.battles = parseInt(wiz.battles);
        processedWizard.tokensClaimed = parseInt(wiz.tokensClaimed);
        processedWizard.goodness = parseInt(wiz.goodness);
        processedWizard.badness = parseInt(wiz.badness);
        processedWizard.initiationTimestamp = parseInt(wiz.initiationTimestamp);
        processedWizard.protectedUntilTimestamp = parseInt(wiz.protectedUntilTimestamp);
        processedWizard.element = ELEMENTS[parseInt(wiz.element)];
        const tokenURI = JSON.parse(await wizardNFTContract.tokenURI(id));
        processedWizard.imageURL = tokenURI.image;
        return processedWizard;
    }


    async function GetMyTokens() {
        if(ecosystemTokenContract!= undefined){
            const tokens = parseInt(await ecosystemTokenContract.balanceOf(address));
            setMyTokens(tokens);
        }
    }

    async function LoadMyWizards() {
      if(isLoadingMyWizards == true){
          return;
      }
      else {
        isLoadingMyWizards = true;
      }

      setWizardIDs([]);
      setWizards([]);
      let newWizArray = [];
      const myPromises = [];
      let myPromise;
      if(address !== undefined) {
            let bal = await wizardNFTContract.balanceOf(address);
            setMyNumWizards(parseInt(bal));
            setWizardIDs([]);
            for(let i=0; i< bal; i++) {
                myPromise = processWizardStructByIndex(i).then( (processed) => {
                    newWizArray.push(processed);
                });
                myPromises.push(myPromise);
            }

            await Promise.all(myPromises).then(() => {
                newWizArray.sort((a, b) => (a.id - b.id));
                setWizards(newWizArray);
            });
      }
      else {
//        console.log("Not connected.");
      }
        isLoadingMyWizards = false;
    }

    useEffect(() => {
      const interval = setInterval(() => {
        LoadMyWizards();
      }, 60000);
      return () => clearInterval(interval);
    }, []);

    useEffect(() => {
      LoadMyWizards();
      GetMyTokens();
    }, [connected, address, numWizards]);

    useEffect(() => {
      LoadMyWizards();
    }, []);

    useEffect(() => {
      LoadMyWizards();
    }, [numWizards]); // this is total amount of wizards, not my amount of my wizards

  return (
    <div className="">
      {/*
      <p>I own {wizards.length} wizards and have {isNaN(myTokens) ? "0" : myTokens} tokens.</p>
      */}
        <div className="wizards-container">
            {wizards && wizards.map(wizard =>
                <div className="wizard-container" key={wizard.id}>
                    <Link to={"wizard/" + wizard.id}>
                        <img className="wizard-image" src={wizard.imageURL} alt={"wizard " + wizard.id}/>
                    </Link>
                </div>
            )}
        </div>
        {wizards.length != myNumWizards && 'loading...'}
        {myNumWizards == 0 && "you have no wizards."}
    </div>
  );
}

export default MyWizards;
