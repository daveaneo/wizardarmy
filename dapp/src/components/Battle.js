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
  const [myFloor, setMyFloor] = useState(0);

  const [time, setTime] = useState(Date.now());

  // contracts
  const { ethereum } = window;
  const ecosystemTokenContract = window.ecosystemToken;
  const wizardNFTContract = window.wizardNFTContract;
  const wizardTowerContract =window.wizardTowerContract;
  const wizardBattleContract =window.wizardBattleContract;
  const signer = window.signer;
  const ELEMENTS = ["Fire", "Wind", "Water", "Earth"]
  let isLoadingMyFloors = false;


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
                console.log("newFloorArray: ", newFloorArray)
                setFloors(newFloorArray);
            });
      }

      else {
        console.log("Not connected.");
      }
        isLoadingMyFloors = false;
    }

    useEffect(() => {
      const interval = setInterval(() => {
        LoadNeighborhood();
        LoadMyFloor();
      }, 60000);
      return () => clearInterval(interval);
    }, []);

    useEffect(() => {
      LoadNeighborhood();
      LoadMyFloor();
    }, [connected, address]);

    useEffect(() => {
      LoadMyFloor();
      LoadNeighborhood();
    }, []);

    useEffect(() => {
      LoadNeighborhood();
    }, [myFloor]);


//        uint16 floorPower; // todo -- may not use it this way (function, instead)
//        uint40 lastWithdrawalTimestamp;
//        uint16 occupyingWizardId;
//        ELEMENT element;
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
