/* web/firebase-messaging-sw.js */

/* Firebase compat (service worker) */
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

/* ⚙️ Config identique à firebase_options.dart */
firebase.initializeApp({
  apiKey: "AIzaSyCGdReLQ995_MhCH7AjUqapfMw4kPADhWQ",
  authDomain: "camara-2001.firebaseapp.com",
  projectId: "camara-2001",
  storageBucket: "camara-2001.firebasestorage.app",
  messagingSenderId: "208848172830",
  appId: "1:208848172830:web:6576776512939cbf0bbb0f",
  measurementId: "G-H8SBFGS73C"
});

const messaging = firebase.messaging();

/* 🔔 Afficher la notification quand le message arrive en arrière-plan */
messaging.onBackgroundMessage((payload) => {
  // payload.notification.* ou fallback sur payload.data.*
  const n = payload.notification || {};
  const title = n.title || (payload.data && payload.data.title) || 'Notification';
  const body  = n.body  || (payload.data && payload.data.body)  || '';

  // URL cible éventuelle
  const url = (payload.data && (payload.data.click_action || payload.data.url)) || '/';

  const options = {
    body,
    icon: '/icons/Icon-192.png',   // adapte si besoin
    badge: '/icons/Icon-192.png',
    data: { url },
    tag: 'soneya-msg',
    // Actions (facultatif)
    // actions: [{ action: 'open', title: 'Ouvrir' }],
  };

  self.registration.showNotification(title, options);
});

/* 👉 Ouvrir/Focus la fenêtre quand l’utilisateur clique la notif */
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const url = (event.notification?.data && event.notification.data.url) || '/';
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((wins) => {
      const same = wins.find((w) => w.url.includes(url));
      if (same) return same.focus();
      return clients.openWindow(url);
    })
  );
});
