// Tests for Model.js, the plugin's pure helpers: `node tests/model.test.mjs` (Node 18 or later,
// no dependencies). Model.js is a QML JavaScript library; it is loaded here without its
// `.pragma library` line, in a fresh context, and nothing it does touches the system.
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import vm from "node:vm";
import assert from "node:assert/strict";

const here = dirname(fileURLToPath(import.meta.url));
const source = readFileSync(join(here, "..", "Model.js"), "utf8").replace(/^\.pragma library\s*$/m, "");
const Model = {};
vm.runInNewContext(source, Model);

let failures = 0;
function test(name, fn) {
  try { fn(); console.log(`ok   ${name}`); } catch (e) { failures++; console.log(`FAIL ${name}\n     ${e.message}`); }
}

// `ip -j -4 addr show` and `ip -j route get 1.1.1.1` as iproute2 prints them.
const addr = (links) => JSON.stringify(links);
const link = (ifname, flags, addrs) => ({ ifname, flags, addr_info: addrs.map(([local, scope]) => ({ family: "inet", local, scope, prefixlen: 24 })) });
const oneNetwork = addr([
  link("lo", ["LOOPBACK", "UP", "LOWER_UP"], [["127.0.0.1", "host"]]),
  link("enp0s4", ["BROADCAST", "MULTICAST", "UP", "LOWER_UP"], [["10.0.2.15", "global"]]),
]);
const twoNetworks = addr([
  link("lo", ["LOOPBACK", "UP", "LOWER_UP"], [["127.0.0.1", "host"]]),
  link("enp0s4", ["BROADCAST", "MULTICAST", "UP", "LOWER_UP"], [["10.0.2.15", "global"]]),
  link("enp0s5", ["BROADCAST", "MULTICAST", "UP", "LOWER_UP"], [["10.0.3.15", "global"], ["169.254.7.1", "link"]]),
  link("wlan0", ["BROADCAST", "MULTICAST"], [["192.168.1.30", "global"]]), // down: not used
]);
const route = (prefsrc) => JSON.stringify([{ dst: "1.1.1.1", gateway: "10.0.2.2", dev: "enp0s4", prefsrc, flags: [] }]);
const values = (rows) => [...rows].map((r) => r.value);
const copyable = (rows) => [...rows].filter((r) => r.copy === true).map((r) => r.value);

test("localAddresses: global IPv4 on interfaces that are up, nothing else", () => {
  assert.deepEqual([...Model.localAddresses(oneNetwork)], ["10.0.2.15"]);
  assert.deepEqual([...Model.localAddresses(twoNetworks)], ["10.0.2.15", "10.0.3.15"]);
  assert.deepEqual([...Model.localAddresses("not json")], []);
  assert.deepEqual([...Model.localAddresses('{"a":1}')], []);
});

test("routeSource: the default route's source address, or nothing", () => {
  assert.equal(Model.routeSource(route("10.0.2.15")), "10.0.2.15");
  assert.equal(Model.routeSource("[]"), "");
  assert.equal(Model.routeSource(route("999.1.1.1")), "");
  assert.equal(Model.routeSource(""), "");
});

test("normal case: Console Cast's own address is shown and copied, with 0.0.0.0", () => {
  const rows = Model.dnsRows({ state: "armed", lan_ip: "10.0.2.15" }, Model.localAddresses(oneNetwork), Model.routeSource(route("10.0.2.15")));
  assert.deepEqual(values(rows), ["10.0.2.15", "0.0.0.0"]);
  assert.deepEqual(copyable(rows), ["10.0.2.15", "0.0.0.0"]);
});

test("a foreign lan_ip is never shown or copied: this computer's own address instead", () => {
  const rows = Model.dnsRows({ state: "armed", lan_ip: "192.168.1.30" }, Model.localAddresses(oneNetwork), Model.routeSource(route("10.0.2.15")));
  assert.ok(!values(rows).includes("192.168.1.30"));
  assert.deepEqual(copyable(rows), ["10.0.2.15", "0.0.0.0"]);
});

test("a foreign lan_ip with no address from the kernel: 'Not available', nothing to copy", () => {
  for (const [local, src] of [[[], ""], [[], "10.0.2.15"], [Model.localAddresses(oneNetwork), ""]]) {
    const rows = Model.dnsRows({ state: "armed", lan_ip: "192.168.1.30" }, local, src);
    assert.deepEqual(values(rows), ["Not available"]);
    assert.deepEqual(copyable(rows), []);
  }
});

test("several networks: lan_ip chooses among this computer's own addresses only", () => {
  const local = Model.localAddresses(twoNetworks), src = Model.routeSource(route("10.0.2.15"));
  assert.deepEqual(copyable(Model.dnsRows({ lan_ip: "10.0.3.15" }, local, src)), ["10.0.3.15", "0.0.0.0"]);
  assert.deepEqual(copyable(Model.dnsRows({ lan_ip: "192.168.1.30" }, local, src)), ["10.0.2.15", "0.0.0.0"]); // down interface
  assert.deepEqual(copyable(Model.dnsRows({ lan_ip: "169.254.7.1" }, local, src)), ["10.0.2.15", "0.0.0.0"]); // link-local
  assert.deepEqual(copyable(Model.dnsRows({ lan_ip: "127.0.0.1" }, local, src)), ["10.0.2.15", "0.0.0.0"]); // loopback
});

test("odd lan_ip values never reach the panel", () => {
  const local = Model.localAddresses(oneNetwork), src = Model.routeSource(route("10.0.2.15"));
  for (const lan_ip of ["10.0.2.15 ", "010.0.2.15", "10.0.2.15; rm -rf /", 167903759, null, ["10.0.2.15"], "$(id)"]) {
    const rows = Model.dnsRows({ lan_ip }, local, src);
    assert.deepEqual(copyable(rows), ["10.0.2.15", "0.0.0.0"], String(lan_ip));
  }
});

test("no status, no rows", () => {
  assert.deepEqual([...Model.dnsRows(null, Model.localAddresses(oneNetwork), "10.0.2.15")], []);
});

test("isIPv4: dotted quads only", () => {
  for (const ok of ["0.0.0.0", "10.0.2.15", "255.255.255.255"]) assert.equal(Model.isIPv4(ok), true, ok);
  for (const bad of ["256.1.1.1", "1.2.3", "01.2.3.4", "1.2.3.4.5", "", "a.b.c.d", " 1.2.3.4"]) assert.equal(Model.isIPv4(bad), false, bad);
});

test("versionOf: only Console Cast's version JSON", () => {
  assert.equal(Model.versionOf('{"version":"0.3.5","install_kind":"arch"}'), "0.3.5");
  assert.equal(Model.versionOf('{"version":"x"}'), "");
  assert.equal(Model.versionOf("consolecast: not found"), "");
});

console.log(failures ? `${failures} failed` : "all passed");
process.exit(failures ? 1 : 0);
