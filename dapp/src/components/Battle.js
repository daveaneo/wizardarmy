import { useEffect, useState } from "react";
import { ethers } from "ethers";
import {Link, useParams} from "react-router-dom";
// todo -- this page should be authenticated

function Battle(props) {
  const connected = props.connected;
  const address = props.address;
  let params = useParams();
  const wizardId = params.id;

//  let [connected, setConnected] = useState(false);
  const [floorIDs, setFloorIDs] = useState([]);
  const [floors, setFloors] = useState([]);
  const [activeFloors, setActiveFloors] = useState([]);
  const [myNumNeighboringFloors, setMyNumNeighboringFloors] = useState(0);
  const [myFloor, setMyFloor] = useState(undefined);

  const [time, setTime] = useState(Date.now());
  const [contractsLoaded, setContractsLoaded] = useState(false);

  // contracts
  const { ethereum } = window;
  const ecosystemTokenContract = window.ecosystemToken;
  const wizardNFTContract = window.wizardNFTContract;
  const wizardTowerContract =window.wizardTowerContract;
  const wizardBattleContract =window.wizardBattleContract;
  const signer = window.signer;
  const ELEMENTS = ["Fire", "Wind", "Water", "Earth"]
  let isLoadingMyFloors = false;
  var loadingContracts = false;

    // todo improve async flow
    async function processFloorStruct(floorNumber) {
        let floor = await wizardTowerContract.floorIdToInfo(floorNumber);
        let token_promise = wizardTowerContract.floorBalance(floorNumber);
        let processedFloor = {};
        processedFloor.floorNumber = parseInt(floorNumber);
        processedFloor.lastWithdrawalTimestamp = parseInt(floor.lastWithdrawalTimestamp);
        processedFloor.occupyingWizardId = parseInt(floor.occupyingWizardId);
        processedFloor.element = ELEMENTS[parseInt(floor.element)];

//        token_promise = wizardTowerContract.floorBalance(floorNumber);
        let tokens = parseInt(await token_promise);
        processedFloor.tokens = tokens;
        return processedFloor;
    }

    async function AttackTower() {
        // todo implement and add in specific floor
        console.log("I am attacking..")
    }

    async function LoadMyFloor() {
      let _activeFloors = parseInt(await wizardTowerContract.activeFloors());
      setActiveFloors(_activeFloors);

      let _myFloor = parseInt(await wizardTowerContract.wizardIdToFloor(wizardId));
      setMyFloor(_myFloor);

      //const data = await Promise.all([promise1, promise2])
    }

    async function LoadNeighborhood() {
      if(isLoadingMyFloors == true){
          return;
      }
      else {
        isLoadingMyFloors = true;
      }

      // get my floor
      if(myFloor===undefined){
        return;
      }

      // set floor IDs
      let ids = [];
      let startFloor = myFloor - 5 >0 ? myFloor - 5 : 1;
      let endFloor = myFloor + 5 <= activeFloors ? myFloor + 5 : activeFloors;
      for(let i=startFloor; i<endFloor; i++){
        ids.push(i);
      }
      setFloorIDs([ids]); // be wary of infinite loop

      setFloors([]);
      let newFloorArray = [];
      let myPromises = [];
      let myPromise;
      if(connected && (address !== undefined)) {
          setMyNumNeighboringFloors(ids.length);
          // iterate through floors
          for(let i=0; i < ids.length; i++) {
                let _floorNumber = ids[i];
                const myPromise = processFloorStruct(_floorNumber).then((floor) => {
                    newFloorArray.push(floor)
                })
                myPromises.push(processFloorStruct(_floorNumber));
            }
            Promise.all(myPromises).then(() => {
                newFloorArray.sort((a, b) => (a.floorNumber - b.floorNumber));
                setFloors(newFloorArray);
            });
      }

      else {
        console.log("Not connected.");
      }
        isLoadingMyFloors = false;
    }


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


    useEffect(() => {
      LoadContracts();
      const interval = setInterval(() => {
        if(contractsLoaded===true){
//            LoadNeighborhood();
            LoadMyFloor();
        }
      }, 60000);
      return () => clearInterval(interval);
    }, []);

    useEffect(() => {
      if(contractsLoaded===true){
//          LoadNeighborhood();
          LoadMyFloor();
      }
    }, [connected, address]);

    useEffect(() => {
      LoadContracts();
    }, []);

    useEffect(() => {
      if(contractsLoaded===true){
          LoadMyFloor();
      }
    }, [contractsLoaded]);

    useEffect(() => {
      if(contractsLoaded===true && (myFloor!==0 || myFloor !==undefined)){
          LoadNeighborhood();
      }
    }, [myFloor]);

  return (
    <div className="">
      <p className="DoubleBordered">Neighboring Floors</p>
        {floors && floors.map(floor =>
            <div key={floor.floorNumber} className="Double">
                <br/>

                Floor {floor.floorNumber}
                <br/>
                <div className="DoubleBordered">
                    <div>Number: {floor.floorNumber}</div>
                    <div>element: {floor.element}</div>
                    <div>Occupying Wizard ID: {floor.occupyingWizardId}</div>
                    <div>Tokens: {floor.tokens}</div>
                    <button onClick={AttackTower}> Attack </button>

                </div>
            </div>
        )}
        {!connected && "Please Connect"}
        {connected && (floors.length != myNumNeighboringFloors) && 'loading...'}
        {myNumNeighboringFloors == 0 && "you are not on the tower."}
    </div>
  );
}

export default Battle;
