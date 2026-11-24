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

// The two DNS addresses the console needs: this computer's address and 0.0.0.0.
function dnsRows(status) {
  var ip = status && typeof status.lan_ip === "string" ? status.lan_ip : ""
  if (!/^\d{1,3}(\.\d{1,3}){3}$/.test(ip)) return []
  return [{ label: "Primary DNS", value: ip }, { label: "Secondary DNS", value: "0.0.0.0" }]
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
