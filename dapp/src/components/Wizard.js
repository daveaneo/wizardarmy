import { useEffect, useState } from "react";
import { ethers } from "ethers";
import { useParams } from "react-router-dom";


function Wizard(props) {
  const connected = props.connected;
  const numWizards = props.numWizards;
  const address = props.address;
  console.log("props info: ", props );
  console.log("separate: ", connected, numWizards, address );
  console.log("connected: ", connected);
  let params = useParams();
  const wizardId = params.id;
  console.log("wizardId: ", wizardId);

  const [myWizard, setMyWizard] = useState({});

  // contracts
  const { ethereum } = window;
  const ecosystemTokenContract = window.ecosystemToken;
  const wizardNFTContract = window.wizardNFTContract;
  const wizardTowerContract =window.wizardTowerContract;
  const wizardBattleContract =window.wizardBattleContract;
  const signer = window.signer;
  const ELEMENTS = ["Fire", "Wind", "Water", "Earth"]
  let isLoadingMyWizards = false;

//        uint256 hp;
//        uint256 mp;
//        uint256 wins;
//        uint256 losses;
//        uint256 battles;
//        uint256 tokensClaimed;
//        uint256 goodness;
//        uint256 badness;
//        uint256 initiationTimestamp; // 0 if uninitiated
//        uint256 protectedUntilTimestamp; // after this timestamp, NFT can be crushed
//        ELEMENT element;
    async function processWizardStruct(wiz, id) {
        let processedWizard = {};
        processedWizard.id = parseInt(id);
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
        return processedWizard;
    }


    async function LoadMyWizard() {
        let wiz = await wizardNFTContract.tokenIdToStats(wizardId);
        await processWizardStruct(wiz, wizardId).then( (processed) => {
                setMyWizard(processed);
        });
    }

//    useEffect(() => {
//      const interval = setInterval(() => {
//        LoadMyWizards();
//      }, 60000);
//      return () => clearInterval(interval);
//    }, []);

    useEffect(() => {
      LoadMyWizard();
    }, []);


  return (
    <div className="">
      <p className="DoubleBordered">Wizard {wizardId}</p>
        {myWizard &&
            <div className="Double">
                <div className="DoubleBordered">
                    <div>element: {myWizard.element}</div>
                    <div>HP: {myWizard.hp}</div>
                    <div>MP: {myWizard.mp}</div>
                    <div>Tokens Claimed: {myWizard.tokensClaimed}</div>
                    <div>wins: {myWizard.wins}</div>
                    <div>losses: {myWizard.losses}</div>
                    <div>goodness: {myWizard.goodness}</div>
                    <div>badness: {myWizard.badness}</div>
                    <div>Time Initiated: {myWizard.initiationTimestamp}</div>
                    <div>Protected Until: {myWizard.protectedUntilTimestamp}</div>
                </div>
            </div>
        }
        {!myWizard && 'loading...'}
        <div>
          <button>Complete Task</button>
          <button>Withdraw from Tower</button>
          <button>Battle (Wizard tower Floors)</button>
        </div>

    </div>
  );
}

export default Wizard;
