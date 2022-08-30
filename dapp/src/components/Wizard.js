import { useEffect, useState } from "react";
import { ethers } from "ethers";
import { useParams, Link } from "react-router-dom";

function Wizard(props) {
  const connected = props.connected;
  const numWizards = props.numWizards;
  const address = props.address;

  let params = useParams();
  const wizardId = params.id;

  const [myWizard, setMyWizard] = useState({});
  const [myFloor, setMyFloor] = useState(undefined);
  const [isInitiated, setIsInitiated] = useState(false);
  const [isActive, setIsActive] = useState(false);
  const [isOwner, setIsOwner] = useState(false);
  const [isOnTheTower, setIsOnTheTower] = useState(false);
  const [myTowerTokens, setMyTowerTokens] = useState(0);
  const [totalTowerTokens, setTotalTowerTokens] = useState(0);
  const [totalWizards, setTotalWizards] = useState(0);
  const [contractsLoaded, setContractsLoaded] = useState(false);
  const [myPhase, setMyPhase] = useState(undefined);
  const [pageRefreshes, setPageRefreshes] = useState(0)
  const TOTALPHASES = 8;

  // contracts
  const { ethereum } = window;
  var ecosystemTokenContract = window.ecosystemToken;
  var wizardNFTContract = window.wizardNFTContract;
  var wizardTowerContract =window.wizardTowerContract;
  var wizardBattleContract =window.wizardBattleContract;
  var NFTContractNoSigner =window.NFTContractNoSigner;
  var loadingContracts = false;




  const signer = window.signer;
  const ELEMENTS = ["Fire", "Wind", "Water", "Earth"]
  let isLoadingMyWizards = false;


function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

  async function LoadContracts() {
      if(loadingContracts) { return}
      loadingContracts = true;

      while(window.ecosystemToken == undefined &&
         window.wizardNFTContract == undefined &&
         window.wizardTowerContract == undefined &&
         window.wizardBattleContract == undefined
      ) {
          await sleep(100);
      }
      var ecosystemTokenContract = window.ecosystemToken;
      var wizardNFTContract = window.wizardNFTContract;
      var wizardTowerContract =window.wizardTowerContract;
      var wizardBattleContract =window.wizardBattleContract;
      loadingContracts = false;
      setContractsLoaded(true);
  }

    // todo -- could combine this or import this function in MyWizards.js
    async function processWizardStruct(wiz, id) {
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

        // todo -- update smart contract
        processedWizard.isActive = processedWizard.protectedUntilTimestamp > Date.now()/1000; // todo -- this doesn't use the official time
//        processedWizard.isActive = parseInt(await wizardNFTContract.isActive(id));

        return processedWizard;
    }

    async function CompleteTask() {
        console.log("Todo complete task?");
        // todo -- backend work. Load a task and submit the hashed details to the blockchain
        // todo -- confirm smart contracts comply -- may need a verifier contract
    }

    async function Rebirth() {
        let tx = await wizardNFTContract.rebirth(wizardId);
        let res = await tx.wait(1)
        if(res){
//            window.location.reload(false);
            setPageRefreshes(pageRefreshes+1); // reload all
        }
        else{
          console.error("rebirth failed.")
        }
    }


    async function UpdateMyPhase() {
        let _phase = await wizardNFTContract.getPhaseOf(wizardId);
        setMyPhase(_phase)
    }

    async function LoadMyWizard() {
        if(wizardNFTContract===undefined) { return }
        let wiz = await wizardNFTContract.tokenIdToStats(wizardId);
        await processWizardStruct(wiz, wizardId).then( (processed) => {
                setMyWizard(processed);
        });
    }

    async function LoadTotalWizards() {
        let total = parseInt(await wizardNFTContract.totalSupply());
        setTotalWizards(total);
    }


    async function SetIsOwner() {
        if(!connected || wizardId===undefined || wizardNFTContract ===undefined ){
          setIsOwner(false);
        }
        else {
            const ownerAddress = await wizardNFTContract.ownerOf(wizardId);
            setIsOwner(ownerAddress==address);
        }
    }


    async function LoadMyFloor() {
        const _floor = parseInt(await wizardTowerContract.wizardIdToFloor(wizardId));
        if (_floor!= 0){
            setIsOnTheTower(true);
        }
        else if(isOnTheTower==true){
            setIsOnTheTower(false);
        }

        setMyFloor(_floor);
    }

    async function Initiate() {
        let tx = await wizardNFTContract.initiate(wizardId);
        let res = await tx.wait(1);
        let tempWizard = {...myWizard}; // this creates a shallow copy (not nested arrays)
        if(res){
            const timestamp = parseInt(res.events[0].args[2]);
            tempWizard.initiationTimestamp = timestamp;
            setMyWizard(tempWizard);
        }
        else {
          console.log("error.");
        }
       const floor = parseInt(res.events[0].args[1]);

    }

    async function LoadTowerTokens() {
        const towerBalance = parseInt(await ecosystemTokenContract.balanceOf(wizardTowerContract.address));
        setTotalTowerTokens(towerBalance);
        if(myFloor==0 || myFloor ==undefined) {return;}

        const myBalance = parseInt(await wizardTowerContract.floorBalance(myFloor));
        setMyTowerTokens(myBalance);
    }


    async function WithdrawFromTower() {
        const activeFloors = parseInt(await wizardTowerContract.activeFloors());
        const tx = await wizardTowerContract.withdraw(myFloor);
        const res = await tx.wait(1);
        if(res){
            console.log("Tokens have been withdrawn.");
        }
        else {
            console.log("Withdrawal failed.")
        }
    }

// todo -- did not automatically change to show on the tower
    async function GetOnTheTower() {
       const tx = await wizardTowerContract.claimFloor(wizardId);
       const res = await tx.wait();
//       const floor = parseInt(res.events[0].args[1]);


       const towerEvent = res.events?.filter((x) => {return x.event == "FloorClaimed"})[0];
       const floor = parseInt(towerEvent.args[1]);

       setMyFloor(floor)
       if(floor>0){
         setIsOnTheTower(true);
       }
    }


    useEffect(() => {
      LoadContracts();
    }, []);

    useEffect(() => {
        if(contractsLoaded===true){
            LoadTotalWizards();
            LoadMyWizard();
            LoadMyFloor();
            SetIsOwner();
            LoadTowerTokens();
            UpdateMyPhase();
        }
    }, [contractsLoaded, pageRefreshes]);


    useEffect(() => {
      if(wizardTowerContract!==undefined){
        LoadTowerTokens();
      }
    }, [myFloor]);

    useEffect(() => {
      LoadContracts();
    }, [address]);


    useEffect(() => {
      SetIsOwner();
    }, [connected, address]);

    useEffect(() => {
    }, [isOwner]);


  return (
    <div className="">
      <p>{totalTowerTokens} TOKENS TOTAL </p>
      <p className="DoubleBordered">Wizard {wizardId} {isOnTheTower ? "is on floor " + myFloor : "not in the tower."}</p>
        {myWizard && wizardId <= totalWizards &&
            <div className="Double">
                <div className="DoubleBordered">
                    <div>element: {myWizard.element}</div>
                    <div>Level: {myWizard.level}</div>
                    <div>Floor: {myFloor}</div>
                    <div>HP: {myWizard.hp}</div>
                    <div>Magical Power: {myWizard.magicalPower}</div>
                    <div>Magical Defense: {myWizard.magicalDefense}</div>
                    <div>Speed: {myWizard.speed}</div>
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

        {wizardId > totalWizards && 'Wizard does not exist.'}
        {!myWizard && 'loading...'}
        {!myWizard &&
          <div>
          {myWizard.isActive ? "Active" : "Inactive"}
          </div>
        }
        {isOwner &&
        <div>
          {myWizard.initiationTimestamp === 0 ? "Not initiated" : "Initiated" } <br/>
          {myWizard.isActive === false ? "Not active" : "Active" } <br/>
          {isOnTheTower==false ? "Not on the tower" : "On the tower" } <br/>

          {myWizard.initiationTimestamp === 0 && <button onClick={Initiate}>Initiate</button> }
          {myWizard.initiationTimestamp !== 0 &&
            <div>
                 <Link to={"/wizard/" + wizardId + "/tasks/"}>
                   <button onClick={CompleteTask}>Complete Task</button>   <br/>
                </Link>

                 { isOnTheTower===false && <button onClick={GetOnTheTower}>Get on the Tower</button> }  <br/>
                 { isOnTheTower===true &&
                 <div>
                     {myTowerTokens} <button onClick={WithdrawFromTower}>Withdraw from Tower</button> <br/>
                    <Link to={"battle/"}>
                      <button>Battle (Wizard tower Floors)</button> <br/>
                    </Link>
                  </div>
                }
                { myPhase == (TOTALPHASES -1)
                   && <div>
                    <button onClick={Rebirth}>Rebirth</button> <br/>
                   </div>
                 }
            </div>
          }
        </div>
        }
    </div>
  );
}

export default Wizard;
