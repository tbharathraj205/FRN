import { initializeApp } from "firebase/app";
import { getFirestore } from "firebase/firestore";
import { getAuth } from "firebase/auth";
import { getStorage } from "firebase/storage";

const firebaseConfig = {
    apiKey: "AIzaSyB18281Budxh4mXJXmTQybl4dmNvQgtrq8",
    authDomain: "first-responder-network.firebaseapp.com",
    projectId: "first-responder-network",
    storageBucket: "first-responder-network.firebasestorage.app",
    messagingSenderId: "370067865961",
    appId: "1:370067865961:web:11d93b9723140255e97df8"
};

const app = initializeApp(firebaseConfig);

export const db = getFirestore(app);
export const auth = getAuth(app);
export const storage = getStorage(app);