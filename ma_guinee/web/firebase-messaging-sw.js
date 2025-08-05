importScripts('https://www.gstatic.com/firebasejs/10.4.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.4.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyCdRelQ995_MhCH7AjUqapfMw4kPADhWqQ",
  authDomain: "camara-2001.firebaseapp.com",
  projectId: "camara-2001",
  messagingSenderId: "208848172830",
  appId: "1:208848172830:web:6576776512399cbf0bb80f" // ✅ ICI
});

const messaging = firebase.messaging();
