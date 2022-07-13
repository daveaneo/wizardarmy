import { useEffect, useState } from "react";
import { ethers } from "ethers";
import {Link, useParams} from "react-router-dom";
// todo -- this page should be authenticated

function Tasks(props) {
  const connected = props.connected;
  const address = props.address;
  let params = useParams();
  const wizardId = params.id;

  const [floorIDs, setFloorIDs] = useState([]);
  const [taskTypes, setTaskTypes] = useState([]);
  const [activeFloors, setActiveFloors] = useState([]);
  const [myNumNeighboringFloors, setMyNumNeighboringFloors] = useState(0);
  const [myFloor, setMyFloor] = useState(undefined);
//  const [isInitiated, setIsInitiated] = useState(undefined);

  const [time, setTime] = useState(Date.now());
  const [contractsLoaded, setContractsLoaded] = useState(false);

  // contracts
  const { ethereum } = window;
  const ecosystemTokenContract = window.ecosystemToken;
  const wizardNFTContract = window.wizardNFTContract;
  const wizardTowerContract = window.wizardTowerContract;
  const wizardBattleContract = window.wizardBattleContract;
  const wizardGovernanceContract = window.wizardGovernanceContract;
  const signer = window.signer;
  const ELEMENTS = ["Fire", "Wind", "Water", "Earth"]
  var isInitiated = undefined;
  let isLoadingMyTasks = false;
  var loadingContracts = false;

    // todo -- create new tasks for board members

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

    async function CompleteTask(_id) {
        console.log("Task will be completed: ", _id);
    }

    async function LoadMyTasks() {
      if(isLoadingMyTasks == true){
          return;
      }
      else {
        isLoadingMyTasks = true;
      }

      if(wizardGovernanceContract===undefined || wizardNFTContract === undefined){
        console.log("GovernanceContract or NFT is not defined.")
        return;
      }
      else if(isInitiated===undefined){
        isInitiated = await wizardNFTContract.getStatsGivenId(wizardId);
        isInitiated = parseInt(isInitiated.initiationTimestamp) !== 0;
      }

      let newTaskTypes = [];
      let taskObjects = []
      let taskObject = undefined;
      if(connected && (address !== undefined)) {
          taskObject = {}
          newTaskTypes = await wizardGovernanceContract.getMyAvailableTaskTypes();
          for(let i = 0; i< newTaskTypes.length; i++){
            taskObject.id = i;
            taskObject.IPFS = newTaskTypes;
            taskObjects.push(taskObject);
          }

//          newTaskTypes.sort((a, b) => (a.floorNumber - b.floorNumber));
//          setTaskTypes(newTaskTypes);
          taskObjects.sort((a, b) => (a.id - b.id));
          setTaskTypes(taskObjects);
      }

      else {
        console.log("Not connected.");
      }
        isLoadingMyTasks = false;
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
         window.wizardBattleContract == undefined &&
         window.wizardGovernanceContract == undefined
      ) {
          await sleep(100);
      }
      var ecosystemTokenContract = window.ecosystemToken;
      var wizardNFTContract = window.wizardNFTContract;
      var wizardTowerContract = window.wizardTowerContract;
      var wizardBattleContract = window.wizardBattleContract;
      var wizardGovernanceContract = window.wizardGovernanceContract;
      loadingContracts = false;
      setContractsLoaded(true);
  }


    useEffect(() => {
      LoadContracts();
      const interval = setInterval(() => {
        if(contractsLoaded===true){
            LoadMyTasks();
        }
      }, 60000);
      return () => clearInterval(interval);
    }, []);


    useEffect(() => {
        LoadMyTasks();
    }, [connected, address]);

    useEffect(() => {
      LoadContracts();
    }, []);

    useEffect(() => {
      if(contractsLoaded===true){
         LoadMyTasks();
      }
    }, [contractsLoaded]);

  return (
    <div className="">
      <p className="DoubleBordered">Available tasks</p>
        {taskTypes && taskTypes.map(taskType =>
            <div key={taskType.id} className="Double">
                <br/>

                Task {taskType.id}
                <br/>
                <div className="DoubleBordered">
                    <div>IPFS Link: {taskType.IPFS}</div>
                    <div>Assignment: {taskType.IPFS}</div>
                    <div>
                       <button onClick={() => CompleteTask(taskType.ID)}> Complete </button>
                    </div>
                </div>
            </div>
        )}
        {!connected && "Please Connect"}
        {connected && (taskTypes == undefined) && 'loading...'}
    </div>
  );
}

export default Tasks;
