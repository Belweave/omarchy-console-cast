import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

// Console Cast's state for the bar and the panel: one instance, however many bars there are.
//
// It reads Console Cast's control API on this computer (http://127.0.0.1:7777, asynchronous,
// every request with a timeout) and runs the consolecast command to see whether Console Cast is
// installed and, with the panel open while Console Cast is off, for the free week. Only that
// command decides "installed": an answer on the port alone proves nothing, and while the command
// is missing nothing from the port is shown. The console's DNS address is always one of this
// computer's own, read from the kernel (`ip -j -4 addr show`, `ip -j route get 1.1.1.1`, as
// stock Omarchy's network status does); the address the port reports only chooses among them.
// Nothing the port sends is run, opened or copied. It never reads or keeps a stream key or a
// license key (the API calls it makes return none), and it never starts a broadcast: Start
// only starts Console Cast itself.
Item {
  id: root

  // Set by the panel while it is open: fresher state, plus destinations and the free week.
  property bool panelOpen: false

  property string installed: "unknown" // "yes", "no" or "unknown"
  property string version: ""
  property bool reachable: false
  property var status: null
  property var destinations: []
  property var license: null
  property bool starting: false
  // This computer's own IPv4 addresses and its default-route address, from the kernel.
  property var localAddresses: []
  property string routeAddress: ""

  // Console Cast answers only counts once the consolecast command has proved it is installed.
  readonly property bool trusted: reachable && installed === "yes"
  readonly property string phase: starting && !trusted ? "starting" : Model.barState(installed, trusted, status)
  readonly property string stateLabel: Model.stateLabel(phase)
  readonly property var dns: trusted ? Model.dnsRows(status, localAddresses, routeAddress) : []
  readonly property var licenseRow: Model.licenseRow(license)
  readonly property bool running: Model.running(phase)
  readonly property bool onAir: Model.onAir(phase, destinations)

  readonly property string api: "http://127.0.0.1:7777"

  // GET or POST one control API path; done(ok, json) always runs once.
  function request(method, path, done) {
    var xhr = new XMLHttpRequest()
    var finished = false
    var timer = requestTimer.createObject(root)
    function finish(ok, body) {
      if (finished) return
      finished = true
      // After a plugin reload a late answer may reach an instance that is already gone.
      try {
        if (timer) { timer.stop(); timer.destroy() }
        if (done) done(ok, ok ? Model.parse(body) : null)
      } catch (e) {}
    }
    if (timer) timer.triggered.connect(function() { xhr.abort(); finish(false, "") })
    xhr.onreadystatechange = function() {
      if (xhr.readyState === XMLHttpRequest.DONE) finish(xhr.status === 200, xhr.responseText)
    }
    if (timer) timer.start()
    xhr.open(method, api + path)
    xhr.send()
  }

  Component {
    id: requestTimer
    Timer { interval: 2500 }
  }

  function refresh() {
    request("GET", "/status", function(ok, body) {
      root.reachable = ok && body !== null
      root.status = root.reachable ? body : null
      if (root.reachable) {
        root.starting = false
        if (root.installed === "unknown") probe()
      } else if (root.installed === "unknown") {
        probe()
      }
      if (!root.panelOpen) return
      if (root.trusted) {
        addresses()
        request("GET", "/relay", function(ok, list) { root.destinations = ok ? Model.destinations(list) : [] })
        request("GET", "/license", function(ok, lic) { if (ok) root.license = lic })
      } else if (root.reachable) {
        root.destinations = []
      } else {
        root.destinations = []
        if (root.installed === "yes") licenseProbe()
      }
    })
  }

  // Whether the consolecast command is here, and its version.
  function probe() {
    if (probeProc.running) return
    probeProc.running = true
    probeTimeout.restart()
  }

  // This computer's addresses, read again while the panel is open (networks change).
  function addresses() {
    if (!addrProc.running) addrProc.running = true
    if (!routeProc.running) routeProc.running = true
  }

  function licenseProbe() {
    if (licenseProc.running) return
    licenseProc.running = true
    licenseTimeout.restart()
  }

  // Start: Console Cast itself when it is not running (the app in the background, with its tray
  // icon; or, when the app is already open, its engine, which the app then shows); arm it when
  // it runs in pass-through. Never a broadcast.
  function start() {
    if (installed !== "yes") return
    if (!reachable) {
      starting = true
      startDeadline.restart()
      Quickshell.execDetached(["sh", "-c", "if pgrep -x console-cast >/dev/null 2>&1; then exec consolecast up >/dev/null 2>&1; else exec console-cast --background; fi"])
    } else if (status && status.state === "passthrough") {
      request("POST", "/arm", function() { refresh() })
    }
  }

  // Stop: quit Console Cast (the console loses its DNS until Console Cast runs again).
  function stop() {
    if (!trusted) return
    request("POST", "/shutdown", function() { refresh() })
  }

  function openApp() {
    if (installed === "yes") Quickshell.execDetached(["console-cast"])
    else Quickshell.execDetached(["xdg-open", "https://consolecast.app/download"])
  }

  function copy(text) {
    if (String(text || "") !== "") Quickshell.execDetached(["wl-copy", "--", String(text)])
  }

  onPanelOpenChanged: {
    if (panelOpen) {
      addresses()
      // Every time the panel opens: Console Cast may have been removed while something still
      // answers on the port.
      probe()
      refresh()
    }
  }

  // Polling, as slow as the state allows: the control API is a local request, and the command
  // is run only to notice Console Cast being installed or removed.
  Timer {
    id: pollTimer
    running: true
    repeat: true
    triggeredOnStart: true
    interval: root.reachable ? (root.panelOpen ? 2000 : 5000) : (root.starting ? 1000 : 15000)
    onTriggered: root.refresh()
  }

  Timer {
    running: root.installed === "no"
    repeat: true
    interval: 60000
    onTriggered: root.probe()
  }

  Timer {
    id: startDeadline
    interval: 30000
    onTriggered: root.starting = false
  }

  Process {
    id: probeProc
    command: ["sh", "-c", "command -v consolecast >/dev/null 2>&1 || exit 127; exec consolecast version --json"]
    stdout: StdioCollector { id: probeOut; waitForEnd: true }
    onExited: function(code) {
      probeTimeout.stop()
      var v = code === 0 ? Model.versionOf(probeOut.text) : ""
      root.version = v
      root.installed = v !== "" ? "yes" : (code === 127 ? "no" : root.installed === "unknown" ? "no" : root.installed)
    }
  }

  Timer {
    id: probeTimeout
    interval: 5000
    onTriggered: if (probeProc.running) probeProc.running = false
  }

  Process {
    id: licenseProc
    command: ["consolecast", "license", "status"]
    stdout: StdioCollector { id: licenseOut; waitForEnd: true }
    onExited: function(code) {
      licenseTimeout.stop()
      if (code === 0) root.license = Model.parse(licenseOut.text)
    }
  }

  Process {
    id: addrProc
    command: ["ip", "-j", "-4", "addr", "show"]
    stdout: StdioCollector { id: addrOut; waitForEnd: true }
    onExited: function(code) { root.localAddresses = code === 0 ? Model.localAddresses(addrOut.text) : [] }
  }

  Process {
    id: routeProc
    command: ["ip", "-j", "route", "get", "1.1.1.1"]
    stdout: StdioCollector { id: routeOut; waitForEnd: true }
    onExited: function(code) { root.routeAddress = code === 0 ? Model.routeSource(routeOut.text) : "" }
  }

  Timer {
    id: licenseTimeout
    interval: 5000
    onTriggered: if (licenseProc.running) licenseProc.running = false
  }
}
