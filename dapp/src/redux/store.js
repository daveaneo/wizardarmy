//import { configureStore } from '@reduxjs/toolkit';
import { createStore } from 'redux';
import { nftContractNoSigner } from '../components/Connect'

const initialState = {
  loading: false,
  account: null,
  smartContracts: {nftContractNoSigner: nftContractNoSigner},
  web3: null,
  errorMsg: "",
};

const reduceFn = (state = { ...initialState }, action) => {
    console.log("in reduceFn...");
    console.log("state: ", state);
    console.log("action: ", action);
    switch (action.type) {
        case "DISCONNECT":
          return {
            ...initialState,
          };
        case "CONNECTION_REQUEST":
          return {
            ...initialState,
            loading: true,
          };
        case "CONNECTION_SUCCESS":
          return {
            ...state,
            loading: false,
            account: action.payload.account,
            smartContracts: {...action.payload.smartContracts, nftContractNoSigner: initialState.smartContracts.nftContractNoSigner} ,
            web3: action.payload.web3,
          };
        case "CONNECTION_FAILED":
          return {
            ...initialState,
            loading: false,
            errorMsg: action.payload,
          };
        case "UPDATE_ACCOUNT":
          return {
            ...state,
            account: action.payload.account,
            smartContracts: {...action.payload.smartContracts, nftContractNoSigner: initialState.smartContracts.nftContractNoSigner} ,
            web3: action.payload.web3,
          };
        default:
          return state;
    }
}

const store = createStore(reduceFn);
export default store;
//export default configureStore({
//	reducer: {},
//});