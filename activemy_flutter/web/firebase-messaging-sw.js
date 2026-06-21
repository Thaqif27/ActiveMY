importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: 'AIzaSyA96mTnnPgKaogR3A9F3jNiZHKBvz9RBEE',
  appId: '1:564042764503:web:e3f5c9a463e0e7d53de092',
  messagingSenderId: '564042764503',
  projectId: 'activemy-a6bf1',
  authDomain: 'activemy-a6bf1.firebaseapp.com',
  databaseURL: 'https://activemy-a6bf1-default-rtdb.asia-southeast1.firebasedatabase.app',
  storageBucket: 'activemy-a6bf1.firebasestorage.app',
  measurementId: 'G-HYR096K798',
});

const messaging = firebase.messaging();
