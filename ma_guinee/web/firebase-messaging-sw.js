// web/firebase-messaging-sw.js

// Import SDK Firebase (compat) pour contexte Service Worker
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

// Config identique à firebase_options.dart -> section web
firebase.initializeApp({
  apiKey: "AIzaSyCGdReLQ995_MhCH7AjUqapfMw4kPADhWQ",
  authDomain: "camara-2001.firebaseapp.com",
  projectId: "camara-2001",
  storageBucket: "camara-2001.firebasestorage.app",
  messagingSenderId: "208848172830",
  appId: "1:208848172830:web:6576776512939cbf0bbb0f",
  measurementId: "G-H8SBFGS73C"
});

// Initialisation de Firebase Messaging
const messaging = firebase.messaging();

// Handler minimal pour messages en arrière-plan
messaging.onBackgroundMessage((_payload) => {
  // Ne rien faire de bloquant ici pour éviter les plantages
});
