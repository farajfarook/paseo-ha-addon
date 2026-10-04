## 1. Real-HA verification

- [ ] 1.1 On a real HA instance: update the add-on and open the panel in a browser that still remembers an older server ID. The panel connects and lists the running daemon's sessions without clearing site data, and the browser console shows the `[paseo-ha] removed ... stale host` line. Then uninstall and reinstall the add-on and open the panel again: `/api/status` reports the same server ID as before the reinstall and the panel connects at once (carried over from `heal-stale-host-after-reinstall` task 4.1)
