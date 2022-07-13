import { useEffect, useState } from "react";
import { ethers } from "ethers";
import { BrowserRouter, Link, Route, Routes} from "react-router-dom";
import WizardTower from './components/WizardTower';
import MyWizards from './components/MyWizards';
import Wizard from './components/Wizard';
import Battle from './components/Battle';
import Home from './components/Home';
import NavBar from './components/NavBar';
import ContractSettings from './components/ContractSettings';
import "./App.css";
// Temp notes here


function App() {
  const [text, setText] = useState("");
  const [savedText, setSavedText] = useState("");
  const [connected, setConnected] = useState(undefined);
  const [numWizards, setNumWizards] = useState(0);
  const [address, setAddress] = useState(undefined);
  const [counter, setCounter] = useState(1);

  return (

    <BrowserRouter>
        <div className="App">
          <ContractSettings
           connected={connected}
           address={address}
           setAddress={setAddress}
           setConnected={setConnected}
        />

          <NavBar connected={connected} address={address} setAddress={setAddress} setConnected={setConnected}/>
        <Routes>
            <Route path="/tower"
              element = {<WizardTower />}
            />
            <Route path="/wizard/:id/battle/"
                element = {<Battle connected={connected} address={address} />}
            />
            <Route path="/wizard/:id"
                element = {<Wizard connected={connected} numWizards={numWizards} address={address} />}
            />
            <Route path="/"
              element = {<Home address={address} connected={connected} numWizards={numWizards} / >}
              />
        </Routes>
        </div>
    </BrowserRouter>
  );
}

export default App;
