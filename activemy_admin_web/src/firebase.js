import { initializeApp } from "firebase/app";
import { getFirestore } from "firebase/firestore";
import { getAuth } from "firebase/auth";
import { getStorage } from "firebase/storage";

const firebaseConfig = {
  apiKey: "AIzaSyA96mTnnPgKaogR3A9F3jNiZHKBvz9RBEE",
  appId: "1:564042764503:web:e3f5c9a463e0e7d53de092",
  messagingSenderId: "564042764503",
  projectId: "activemy-a6bf1",
  authDomain: "activemy-a6bf1.firebaseapp.com",
  databaseURL: "https://activemy-a6bf1-default-rtdb.asia-southeast1.firebasedatabase.app",
  storageBucket: "activemy-a6bf1.firebasestorage.app",
  measurementId: "G-HYR096K798"
};

const app = initializeApp(firebaseConfig);
export const db = getFirestore(app);
export const auth = getAuth(app);
export const storage = getStorage(app);
