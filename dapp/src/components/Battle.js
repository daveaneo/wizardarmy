import { useEffect, useState } from "react";
import { ethers } from "ethers";
import {Link, useParams} from "react-router-dom";
import { useSelector } from "react-redux";
// todo -- this page should be authenticated

function Battle(props) {
  let params = useParams();
  const wizardId = params.id;

  const [floorIDs, setFloorIDs] = useState([]);
  const [floors, setFloors] = useState([]);
  const [activeFloors, setActiveFloors] = useState([]);
  const [myNumNeighboringFloors, setMyNumNeighboringFloors] = useState(0);
  const [myFloor, setMyFloor] = useState(undefined);

  const [time, setTime] = useState(Date.now());
  const [contractsLoaded, setContractsLoaded] = useState(false);

  const smartContracts = useSelector(state => state.smartContracts)
  const address = useSelector(state => state.account)

  // Load signed, unsigned contracts from Redux
//  const NFTContractNoSigner = smartContracts.nftContractNoSigner;
//  const ecosystemTokenContract = smartContracts.ecosystemTokenContract;
  const wizardNFTContract = smartContracts.wizardNFTContract;
  const wizardTowerContract = smartContracts.wizardTowerContract;
  const wizardBattleContract = smartContracts.wizardBattleContract;


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


    async function AttackTower(_floor) {

        // approve token
        // todo -- approval is tricky as balance is changing constantly
        const floorBalance = parseInt( await wizardTowerContract.floorBalance(_floor));
//        const tx = await ecosystemTokenContract.approve(wizardBattleContract.address, parseInt(floorBalance/10));

//        var res = await tx.wait();
        console.log("flor balance: ", floorBalance);
        const tx = await wizardBattleContract.attack(wizardId, _floor, {value: parseInt(floorBalance*1.1)});//{value: parseInt(floorBalance*1.1)}); // send a little extra

        const res = await tx.wait(1);
        const attackEvent = res.events?.filter((x) => {return x.event == "Attack"})[0];
        const outcome = parseInt(attackEvent.args[4]);
        const tokensWonLost = parseInt(attackEvent.args[3]);
        console.log("You have won/lost. Coins: ", tokensWonLost);
        console.log("outcome: ", outcome);

        if(outcome==0){
          console.log("You lost.")
        }
        else if(outcome==1){
          console.log("You won.")
        }
        else if(outcome==2){
          console.log("You drew.")
        }
        else if(outcome==3){
          console.log("You captured enemy wizard, a deserter.")
        }
        else{
          console.log("Unknown battle outcome.")
        }
        LoadNeighborhood();

    }

    async function LoadMyFloor() {
      let _activeFloors = parseInt(await wizardTowerContract.activeFloors());
      setActiveFloors(_activeFloors);

      let _myFloor = parseInt(await wizardTowerContract.wizardIdToFloor(wizardId));
      setMyFloor(_myFloor);
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
      for(let i=startFloor; i <= endFloor; i++){
        ids.push(i);
      }
      setFloorIDs([ids]); // be wary of infinite loop

      setFloors([]);
      let newFloorArray = [];
      let myPromises = [];
      let myPromise;
      if(address && (address !== undefined)) {

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


    useEffect(() => {
      const interval = setInterval(() => {
        if(smartContracts.wizardTowerContract!=undefined){
            LoadMyFloor();
        }
      }, 60000);
      return () => clearInterval(interval);
    }, []);


    useEffect(() => {
      if(smartContracts.wizardTowerContract != undefined){
            LoadMyFloor();
      }

    }, [smartContracts, address]);

    useEffect(() => {
      if(smartContracts.wizardTowerContract != undefined && (myFloor!==0 || myFloor !==undefined)){
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
                    <div>
                       {(myFloor!= floor.floorNumber) && <button onClick={() => AttackTower(floor.floorNumber)}> Attack </button>}
                    </div>
                </div>
            </div>
        )}
        {!address && "Please Connect"}
        {address && (floors.length != myNumNeighboringFloors) && 'loading...'}
        {myFloor == 0 && "you are not on the tower."}
        {myNumNeighboringFloors == 0 && "You are alone on the tower."}
    </div>
  );
}

export default Battle;
