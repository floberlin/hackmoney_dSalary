import { IonButton, IonCol, IonContent, IonGrid, IonHeader, IonPage, IonRow, IonText, IonTitle, IonToolbar } from '@ionic/react';
import Web3Modal from "web3modal";
import WalletConnectProvider from '@walletconnect/web3-provider/dist/umd/index.min.js';
import { Contract, providers, utils } from "ethers";
import { useState } from 'react';
import { formatAuthMessage } from "../utils";
//import { isMobile } from "react-device-detect";

import CoinbaseWalletSDK from '@coinbase/wallet-sdk';

const providerOptions = {
  coinbasewallet: {
    package: CoinbaseWalletSDK, // Required
    options: {
      appName: "dSalary", // Required
      infuraId: "c4fe7eca7f744d1d83fc99a06ed38c2a", // Required
      rpc: "", // Optional if `infuraId` is provided; otherwise it's required
      chainId: 1, // Optional. It defaults to 1 if not provided
      darkMode: true // Optional. Use dark theme, defaults to false
    }
  },
  walletconnect: {
    package: WalletConnectProvider,
    options: {
      infuraId: "c4fe7eca7f744d1d83fc99a06ed38c2a",
    },
  },
  binancechainwallet: {
    package: true
  }
};



let provider: providers.Web3Provider | undefined; 
let signer: providers.JsonRpcSigner;

const Employee: React.FC = () => {

  const web3Modal = new Web3Modal({
    network: "mainnet",
    cacheProvider: true,
    providerOptions: providerOptions,
  });

const [chainId, setChainId] = useState<number>(1);
const [address, setAddress] = useState<string>("Connect Wallet");
const [verified, setVerified] = useState<Boolean>(false);


function reset() {
  console.log("reset");
  setAddress("");
  provider = undefined;
  web3Modal.clearCachedProvider();
}

async function connect() {
  const web3Provider = await web3Modal.connect();

  web3Provider.on("disconnect", reset);

  const accounts = (await web3Provider.send("eth_requestAccounts", [])) as string[];
  setAddress(accounts[0]);
  setChainId(web3Provider.chainId);

  const providertemp = new providers.Web3Provider(web3Provider);
  provider = providertemp;
  signer = provider.getSigner();
  const addr = await signer.getAddress();
  return addr;
}

async function signMessage() {
  if (!provider) {
    throw new Error("Provider not connected");
  }
  const msg = formatAuthMessage(address, chainId);
  const sig = await provider.send("personal_sign", [msg, address]);
  console.log("Signature", sig);
  console.log("isValid", utils.verifyMessage(msg, sig).toLowerCase ===  address.toLowerCase);
}


  return (
    <IonPage>
    <IonHeader>
      <IonToolbar>
        <IonTitle>dSalary Dashboard | Employee Perspective</IonTitle>
      </IonToolbar>
    </IonHeader>
    <IonContent fullscreen>
      <IonHeader collapse="condense">
        <IonToolbar>
          <IonTitle size="large">dSalary Dashboard | Employee Perspective</IonTitle>
        </IonToolbar>
      </IonHeader>
      
      {address !== "Connect Wallet" ? (
        <>
          <IonButton onClick={async () => setAddress(await connect())}>{address}</IonButton>
          <IonButton onClick={signMessage}>Sign Message</IonButton>
          <IonButton onClick={() => {reset();setAddress("Connect Wallet")}}>Disconnect Wallet</IonButton>
        </>
      ) : (
        <IonButton onClick={async () => setAddress(await connect())}>{address}</IonButton>
      )}
    </IonContent> 
  </IonPage>
  );
};

export default Employee;
