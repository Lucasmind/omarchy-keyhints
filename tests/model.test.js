// HintModel.js against a frozen `omarchy-menu-keybindings --print` from Omarchy 4.0.6.
// Run: node tests/model.test.js
const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const vm = require("node:vm")

const root = path.join(__dirname, "..")
const source = fs.readFileSync(path.join(root, "HintModel.js"), "utf8").replace(/^\.pragma library\s*$/m, "")
const model = {}
vm.runInNewContext(source + "\n;Object.assign(exports, { parse, view, usageStats, canonicalMods })", { exports: model })

const bindings = model.parse(fs.readFileSync(path.join(__dirname, "fixtures/keybindings.txt"), "utf8"))
const rowsOf = v => v.sections.flatMap(s => s.rows)
const find = (v, desc) => rowsOf(v).find(r => r.desc === desc)
let passed = 0
function test(name, fn) { fn(); passed++; console.log("ok -", name) }

test("parses bindings and drops XF86 and mouse-wheel keys", () => {
  assert.ok(bindings.length > 150)
  assert.ok(!bindings.some(b => /^XF86|^mouse_/.test(b.key)))
  const close = bindings.find(b => b.desc === "Close window")
  assert.equal(close.mods, "SUPER")
  assert.equal(close.key, "W")
})

test("canonical modifier order", () => {
  assert.equal(model.canonicalMods("alt shift SUPER"), "SUPER SHIFT ALT")
})

test("collapses digit and arrow families", () => {
  const v = model.view(bindings, "SUPER", "", 40, { winClass: "x", chain: [] })
  assert.equal(find(v, "Go to workspace").key, "1–0")
  assert.equal(find(v, "Focus window").key, "←→↑↓")
})

test("rewords by window state", () => {
  const tiled = model.view(bindings, "SUPER", "", 40, { winClass: "x" })
  const floating = model.view(bindings, "SUPER", "floating,fullscreen", 40, { winClass: "x" })
  assert.ok(find(tiled, "Float window"))
  assert.ok(find(floating, "Tile window"))
  assert.ok(find(floating, "Exit full screen"))
})

test("pins move/minimize answers from deeper layers into the Super view", () => {
  const v = model.view(bindings, "SUPER", "", 18, { winClass: "x" })
  assert.equal(find(v, "Send window to workspace").key, "Shift 1–0")
  assert.equal(find(v, "Hide window (minimize)").key, "Alt S")
})

test("suggests apps for the innermost app", () => {
  const v = model.view(bindings, "SUPER", "", 18, { winClass: "ghostty", chain: ["Ghostty", "herdr", "Claude Code"] })
  const handy = v.sections.find(s => s.title === "Handy with Claude Code")
  assert.ok(handy)
  assert.equal(handy.rows[0].desc, "Files in this folder")
  assert.equal(handy.rows[0].key, "Shift Alt F")
})

test("empty desktop drops window rows and lists every app", () => {
  const v = model.view(bindings, "SUPER", "", 18, { winClass: "", chain: [] })
  assert.ok(!v.sections.some(s => s.title === "Window"))
  assert.ok(v.launcher.length > 25)
  assert.ok(v.launcher.some(r => r.desc === "Terminal" && r.key === "Enter"))
})

test("app hints off keeps Omarchy's own rows only", () => {
  const v = model.view(bindings, "SUPER", "", 18, { winClass: "ghostty", chain: ["Claude Code"], appHints: false })
  assert.ok(!v.sections.some(s => /^Handy/.test(s.title)))
  assert.equal(v.launcher.length, 0)
})

test("next layers summarize one modifier deeper", () => {
  const v = model.view(bindings, "SUPER", "", 18, { winClass: "x" })
  assert.equal(v.next.map(n => n.mod).join(" "), "SHIFT CTRL ALT")
  assert.ok(v.next.every(n => n.count > 0))
})

test("learning: known shortcuts sink, at most three highlighted", () => {
  const usage = { "SUPER+W": 30 }
  const v = model.view(bindings, "SUPER", "", 40, { winClass: "x", usage, learning: true })
  const rows = rowsOf(v)
  const close = rows.find(r => r.desc === "Close window")
  assert.equal(close.state, "known")
  assert.ok(rows.filter(r => r.state === "new").length <= 3)
  const tight = model.view(bindings, "SUPER", "", 6, { winClass: "x", usage, learning: true })
  assert.ok(!find(tight, "Close window"), "known rows are the first cut")
})

test("learning off: no markers", () => {
  const v = model.view(bindings, "SUPER", "", 40, { winClass: "x", usage: { "SUPER+W": 30 }, learning: false })
  assert.ok(rowsOf(v).every(r => r.state === ""))
})

test("usage stats count families once", () => {
  const s = model.usageStats(bindings, { "SUPER+1": 5, "SUPER+2": 5 })
  assert.equal(s.known, 1)  // workspaces 1–0 together: 10 presses
  assert.equal(s.known + s.learning + s.untried, s.total)
})

console.log(`${passed} passed`)
