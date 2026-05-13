self.addEventListener("push", (event) => {
  const payload = event.data ? event.data.json() : {};
  const notification = payload.notification || {};
  const data = payload.data || {};

  event.waitUntil(
    self.registration.showNotification(notification.title || "Synced Alarm", {
      body: notification.body || "Alarm update received",
      tag: data.alarmId || data.commandId || "synced-alarm",
      data,
      renotify: true
    })
  );
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  event.waitUntil(
    self.clients.matchAll({type: "window", includeUncontrolled: true}).then((clients) => {
      for (const client of clients) {
        if ("focus" in client) return client.focus();
      }
      if (self.clients.openWindow) return self.clients.openWindow("/");
      return undefined;
    })
  );
});
