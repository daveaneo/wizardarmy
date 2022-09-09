import { useEffect, useState } from "react";
import { ethers } from "ethers";
import { BrowserRouter, Link, Route, Routes} from "react-router-dom";
import WizardTower from './components/WizardTower';
import MyWizards from './components/MyWizards';
import Wizard from './components/Wizard';
import Battle from './components/Battle';
import Tasks from './components/Tasks';
import Home from './components/Home';
import WrongNetwork from './components/WrongNetwork';
import NavBar from './components/NavBar';
//import ContractSettings from './components/ContractSettings';
import {Connect} from './components/Connect';
import { useDispatch, useSelector } from "react-redux";

import {onboard} from './components/Onboard';

import "./App.css";

//const injected = injectedModule()
//const walletConnect = walletConnectModule()


function App() {
  const [connected, setConnected] = useState(undefined);
  const [numWizards, setNumWizards] = useState(0);
  const [address, setAddress] = useState(undefined);
  const [counter, setCounter] = useState(1);

//  const dispatch = useDispatch();
//  const connect = Connect();
//  const res = connect(dispatch);
//  console.log("res: ", res)
//  const res = dispatch(Connect());
//  console.log("res: ", res)

  return (

    <BrowserRouter>
        <div className="App">
{/*
          <ContractSettings
           connected={connected}
           address={address}
           setAddress={setAddress}
           setConnected={setConnected}
           onboard={onboard}
          />
*/}
        <Connect
           connected={connected}
           address={address}
           setAddress={setAddress}
           setConnected={setConnected}
           onboard={onboard}
          />


          <NavBar connected={connected} address={address} setAddress={setAddress} setConnected={setConnected} numWizards={numWizards} setNumWizards={setNumWizards}
            onboard={onboard}
          />

        <WrongNetwork connected={connected} onboard={onboard} />


        <Routes>
            <Route path="/tower"
              element = {<WizardTower />}
            />
            <Route path="/wizard/:id/battle/"
                element = {<Battle connected={connected} address={address} />}
            />
            <Route path="/wizard/:id/tasks/"
                element = {<Tasks connected={connected} address={address} />}
            />
            <Route path="/wizard/:id"
                element = {<Wizard connected={connected} numWizards={numWizards} address={address} />}
            />
            <Route path="/"
              element = {<Home address={address} connected={connected} numWizards={numWizards} setNumWizards={setNumWizards}/ >}
              />
        </Routes>
        </div>
    </BrowserRouter>
  );
}

export default App;
