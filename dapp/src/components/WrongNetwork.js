import { useEffect, useState } from "react";
//import { ethers } from "ethers";
import { init, useConnectWallet } from '@web3-onboard/react'
import "../App.css";

function WrongNetwork(props) {
  const connected = props.connected;
  const onboard = props.onboard;

  const correctChainId = process.env.REACT_APP_CORRECT_CHAIN_ID;
  const [networkIsValid, setNetworkIsValid] = useState(true);
//  const { ethereum } = window;


    const myWallet = useConnectWallet();

    function sleep(ms) {
      return new Promise(resolve => setTimeout(resolve, ms));
    }

    async function ValidateNetwork() {
        if(onboard==undefined || myWallet[0].wallet == null){
            setNetworkIsValid(true);
        }
        else{
            const currentChainId = myWallet[0].wallet.chains[0].id;
            if(correctChainId===currentChainId && networkIsValid!=true){
                setNetworkIsValid(true)
            }
            else if(correctChainId!==currentChainId && networkIsValid!=false){
                setNetworkIsValid(false)
            }

        }
    }

  useEffect(() => {
    ValidateNetwork();
  }, []);

  useEffect(() => {
    ValidateNetwork();
  }, [myWallet]); //

  return (
      <>
        { !networkIsValid && <div id="wrong-network-overlay">
          Please connect to Mumbai Testnet
        </div>
        }
      </>
  );
}

export default WrongNetwork;
