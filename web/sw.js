// Minimal service worker so Chrome will offer "Install Notably".
// Flutter's production build also emits flutter_service_worker.js; this
// file covers `flutter run` and keeps the app installable in development.
self.addEventListener('install', (event) => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim());
});

self.addEventListener('fetch', (event) => {
  event.respondWith(fetch(event.request));
});
