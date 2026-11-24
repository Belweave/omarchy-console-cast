.pragma library

// Pure helpers for the Console Cast plugin: they turn what Console Cast reports (its control
// API on this computer, or `consolecast ... --json`) into what the bar and the panel show.
// Nothing here reads files, runs programs or talks to the network.

function parse(text) {
  try {
    var value = JSON.parse(String(text || ""))
    return value && typeof value === "object" ? value : null
  } catch (e) {
    return null
  }
}

// One word for the bar, from the install probe ("yes", "no", "unknown"), whether Console
// Cast answers, and its status.
//   missing    Console Cast is not installed
//   off        installed, not running
//   starting   starting or stopping
//   ready      armed, waiting for the console
//   connected  the console uses this computer's DNS
//   live       the console's picture is arriving
//   passthrough the console streams straight to Twitch
//   error      Console Cast reports an error
function barState(installed, reachable, status) {
  if (!reachable || !status) return installed === "no" ? "missing" : "off"
  var state = String(status.state || "")
  if (state === "starting" || state === "stopping") return "starting"
  if (state === "error") return "error"
  if (state === "passthrough") return "passthrough"
  if (state !== "armed") return "starting"
  if (status.stream && status.stream.live === true) return "live"
  if (status.console && status.console.seen === true) return "connected"
  return "ready"
}

function stateLabel(state) {
  switch (state) {
    case "missing": return "Not installed"
    case "off": return "Off"
    case "starting": return "Starting"
    case "ready": return "Ready"
    case "connected": return "Console connected"
    case "live": return "Live"
    case "passthrough": return "Pass-through"
    case "error": return "Error"
  }
  return ""
}

// Running means Stop applies; a console picture or a destination on air means stopping cuts it.
function running(state) {
  return state === "starting" || state === "ready" || state === "connected" || state === "live" || state === "passthrough" || state === "error"
}

function onAir(state, destinations) {
  if (state === "live") return true
  for (var i = 0; i < (destinations || []).length; i++)
    if (destinations[i].on) return true
  return false
}

function isIPv4(text) {
  var m = /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/.exec(String(text || ""))
  if (!m) return false
  for (var i = 1; i <= 4; i++) if (Number(m[i]) > 255 || (m[i].length > 1 && m[i][0] === "0")) return false
  return true
}

// This computer's own IPv4 addresses, from the kernel: `ip -j -4 addr show` (iproute2). Only
// addresses with global scope (not loopback, not link-local) on an interface that is up.
function localAddresses(text) {
  var links = parse(text)
  var out = []
  if (!Array.isArray(links)) return out
  for (var i = 0; i < links.length; i++) {
    var link = links[i] || {}
    var flags = Array.isArray(link.flags) ? link.flags : []
    if (flags.indexOf("UP") < 0 || flags.indexOf("LOOPBACK") >= 0) continue
    var infos = Array.isArray(link.addr_info) ? link.addr_info : []
    for (var j = 0; j < infos.length; j++) {
      var a = infos[j] || {}
      if (a.family === "inet" && a.scope === "global" && isIPv4(a.local) && out.indexOf(a.local) < 0) out.push(a.local)
    }
  }
  return out
}

// The address this computer uses for its default route, from the kernel: `ip -j route get
// 1.1.1.1` (asks the routing table, sends nothing), as stock Omarchy's network status does.
function routeSource(text) {
  var routes = parse(text)
  var src = Array.isArray(routes) && routes[0] ? routes[0].prefsrc : ""
  return isIPv4(src) ? src : ""
}

// The address to give the console: one of this computer's own addresses, never anything else.
// Console Cast's reported lan_ip only chooses among them (a computer with several networks);
// otherwise the kernel's default-route address; "" when the kernel reports neither.
function consoleAddress(status, local, route) {
  var own = Array.isArray(local) ? local : []
  var reported = status && typeof status.lan_ip === "string" ? status.lan_ip : ""
  if (reported !== "" && own.indexOf(reported) >= 0) return reported
  var viaRoute = isIPv4(route) ? route : ""
  if (viaRoute !== "" && own.indexOf(viaRoute) >= 0) return viaRoute
  return ""
}

// The two DNS addresses the console needs: this computer's address and 0.0.0.0. Only these
// two values can ever be copied; without an address of this computer, one row says so.
function dnsRows(status, local, route) {
  if (!status) return []
  var ip = consoleAddress(status, local, route || "")
  if (ip === "") return [{ label: "Primary DNS", value: "Not available", copy: false }]
  return [{ label: "Primary DNS", value: ip, copy: true }, { label: "Secondary DNS", value: "0.0.0.0", copy: true }]
}

// Destinations from GET /relay ({"destinations": [...]}) or `consolecast output list` (an
// array): only the host and whether it is on. Nothing else is kept.
function destinations(payload) {
  var list = Array.isArray(payload) ? payload : (payload && Array.isArray(payload.destinations) ? payload.destinations : [])
  var rows = []
  for (var i = 0; i < list.length; i++) {
    var d = list[i] || {}
    var state = String(d.state || "")
    rows.push({
      id: String(d.id || ""),
      host: String(d.host || d.id || ""),
      on: state === "streaming",
      label: state === "streaming" ? "On" : (state === "retrying" || state === "starting" ? "Connecting" : "Off")
    })
  }
  return rows
}

// The free week or the subscription, as one label and one value; empty for a build that
// needs no subscription.
function licenseRow(license) {
  if (!license || license.required !== true) return null
  if (license.plan && license.plan !== "trial") {
    var name = license.plan === "lifetime" ? "Lifetime" : "Subscription"
    return { label: name, value: license.active === true ? "Active" : "Ended" }
  }
  var week = license.free_week
  if (!week) return { label: "Subscription", value: license.active === true ? "Active" : "Ended" }
  if (week.ended === true || license.active !== true) return { label: "Free week", value: "Ended" }
  var days = Math.max(0, Math.round(Number(week.days_left) || 0))
  return { label: "Free week", value: days === 1 ? "1 day left" : days + " days left" }
}

// `consolecast version --json`: the version, or "" when the output is not Console Cast's.
function versionOf(text) {
  var v = parse(text)
  return v && typeof v.version === "string" && /^\d+\.\d+\.\d+/.test(v.version) ? v.version : ""
}
