.pragma library

// Turns `omarchy-menu-keybindings --print` output into compact, grouped rows
// for one modifier set, plus a summary of the modifier layers one key deeper.

var MOD_ORDER = ["SUPER", "SHIFT", "CTRL", "ALT"]

var KEY_LABELS = {
  RETURN: "Enter", SPACE: "Space", ESCAPE: "Esc", BACKSPACE: "⌫", TAB: "Tab",
  LEFT: "←", RIGHT: "→", UP: "↑", DOWN: "↓", COMMA: ",", PERIOD: ".", SLASH: "/",
  MINUS: "-", EQUAL: "=", PRINT: "PrtSc", BRACKETLEFT: "[", BRACKETRIGHT: "]",
  DELETE: "Del", HOME: "Home", "LEFT MOUSE BUTTON": "Drag", "RIGHT MOUSE BUTTON": "R-Drag"
}

var DIRECTIONS = { LEFT: "←", RIGHT: "→", UP: "↑", DOWN: "↓" }

// Most useful first when Super alone is held. Anything unlisted follows in
// Omarchy's own order.
var SUPER_PRIORITY = [
  /^Close window$/, /^Full screen$/, /^Toggle window floating/, /^Focus/,
  /^Switch to workspace/, /^Toggle scratchpad/, /^Pop window out/, /^Toggle window split/,
  /^Omarchy menu$/, /^Keybindings$/, /^Terminal$/, /^Next workspace$/, /^Toggle window grouping/,
  /^Move window$/, /^Resize window$/
]

// Rows from one layer deeper that answer "how do I move / minimize this
// window?" right away, shown in the Super view with their extra modifier.
var SUPER_EXTRAS = [
  { mods: "SUPER SHIFT", rx: /^Move window to workspace/ },
  { mods: "SUPER SHIFT", rx: /^Swap window/ },
  { mods: "SUPER ALT", rx: /^Move window to scratchpad$/ }
]

var CATEGORIES = [
  { name: "Workspaces", rx: /workspace|scratchpad/i },
  { name: "Window", rx: /window|full screen|full width|split|float|pseudo|group|gaps|focus|swap|expand|shrink|aspect/i },
  { name: "System", rx: /menu|lock|notification|nightlight|idle|bar panel|audio|bluetooth|display|network|power|screen|capture|color picker|clipboard|emoji|dictation|zoom|reminder|battery|time|weather|theme|background|keybindings|copy|paste|cut|transcode|share|activity|hardware|calculator|scaling|webcam|top bar|ocr/i }
]

function canonicalMods(mods) {
  var set = String(mods || "").toUpperCase().split(/\s+/)
  return MOD_ORDER.filter(function(m) { return set.indexOf(m) !== -1 }).join(" ")
}

function category(desc) {
  for (var i = 0; i < CATEGORIES.length; i++)
    if (CATEGORIES[i].rx.test(desc)) return CATEGORIES[i].name
  return "Apps"
}

function keyLabel(key) {
  var upper = key.toUpperCase()
  if (KEY_LABELS[upper] !== undefined) return KEY_LABELS[upper]
  return key.length === 1 ? key.toUpperCase() : key
}

function parse(text) {
  var out = []
  var lines = String(text || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var m = lines[i].match(/^(.*?)\s+→\s+(.+)$/)
    if (!m) continue
    var combo = m[1].trim()
    var plus = combo.indexOf(" + ")
    var mods = plus === -1 ? "" : canonicalMods(combo.slice(0, plus))
    var key = plus === -1 ? combo : combo.slice(plus + 3).trim()
    if (/^mouse_(up|down)$/i.test(key) || /^XF86/.test(key) || key.indexOf("code:") === 0) continue
    out.push({ mods: mods, key: key, desc: m[2].trim(), order: i })
  }
  return out
}

// "Focus on left window" -> "Focus window"; "Swap window to the left" -> "Swap window".
function stripDirection(desc) {
  return desc
    .replace(/\b(left|right|up|down|above|below|top|bottom)\b/gi, "")
    .replace(/\b(on|to the|on the)\s+(?=window\b)/gi, "")
    .replace(/\s+(to the|to|on|the)\s*$/i, "")
    .replace(/\s{2,}/g, " ")
    .trim()
}

// Collapse digit families (workspaces 1-10) and arrow families into one row.
function collapse(bindings) {
  var rows = []
  var families = {}
  bindings.forEach(function(b) {
    var familyKey = null
    var label = b.desc
    var digit = b.key.match(/^\d$/) && b.desc.match(/^(.*?)\s*\d+$/)
    if (digit) {
      familyKey = "digit:" + digit[1]
      label = digit[1]
    } else if (DIRECTIONS[b.key.toUpperCase()]) {
      label = stripDirection(b.desc)
      familyKey = "dir:" + label
    }
    if (familyKey && families[familyKey]) {
      families[familyKey].members.push(b)
      return
    }
    var row = { key: keyLabel(b.key), desc: label, category: category(b.desc), order: b.order, members: [b], family: familyKey }
    if (familyKey) families[familyKey] = row
    rows.push(row)
  })
  rows.forEach(function(row) {
    if (!row.family) return
    if (row.members.length === 1) {
      row.desc = row.members[0].desc
      return
    }
    if (row.family.indexOf("digit:") === 0) {
      var digits = row.members.map(function(m) { return m.key }).sort()
      var hasZero = digits[0] === "0"
      var nonZero = digits.filter(function(d) { return d !== "0" })
      row.key = nonZero[0] + "–" + (hasZero ? "0" : nonZero[nonZero.length - 1])
    } else {
      var order = ["LEFT", "RIGHT", "UP", "DOWN"]
      row.key = row.members
        .map(function(m) { return m.key.toUpperCase() })
        .sort(function(a, b) { return order.indexOf(a) - order.indexOf(b) })
        .map(function(k) { return DIRECTIONS[k] }).join("")
    }
  })
  return rows
}

// Reword a few rows to match the focused window's state.
function contextualize(row, flags) {
  var has = function(f) { return flags.indexOf(f) !== -1 }
  var d = row.desc
  if (/^Toggle window floating/.test(d)) d = has("floating") ? "Tile window" : "Float window"
  else if (d === "Full screen") d = has("fullscreen") ? "Exit full screen" : "Full screen"
  else if (/^Pop window out/.test(d)) d = has("pinned") ? "Pop window back in" : "Pop out (float & pin)"
  else if (d === "Toggle window grouping") d = has("grouped") ? "Ungroup windows" : "Group windows"
  else if (d === "Toggle scratchpad") d = "Show / hide scratchpad"
  else if (d === "Move window to scratchpad") d = "Hide window (minimize)"
  else if (d === "Move window to workspace") d = "Send window to workspace"
  else if (d === "Switch to workspace") d = "Go to workspace"
  else if (d === "File manager (cwd)") d = "Files in this folder"
  else if (d === "Toggle window split") d = "Flip split direction"
  return { key: row.key, desc: d, category: row.category }
}

function priority(row) {
  for (var i = 0; i < SUPER_PRIORITY.length; i++)
    if (SUPER_PRIORITY[i].test(row.desc)) return i
  return 100 + row.order
}

// Apps worth a hotkey given what's in the focused window, by innermost app.
// Matched against Omarchy's binding descriptions on any Super layer.
var SUGGESTIONS = [
  { when: /^(Claude Code|Codex)$/, picks: [/^File manager \(cwd\)$/, /^File manager$/, /^Capture menu$/,
      /^Clipboard manager$/, /^Browser$/, /^Editor$/, /^Passwords$/] },
  { when: /^(herdr|Ghostty)/, picks: [/^File manager \(cwd\)$/, /^Editor$/, /^Browser$/, /^Docker$/,
      /^Clipboard manager$/, /^File manager$/] },
  { when: /^Browser$/, picks: [/^Passwords$/, /^File manager$/, /^Email$/, /^Calendar$/,
      /^Capture menu$/, /^Clipboard manager$/] },
  { when: /^Files$/, picks: [/^Terminal$/, /^Editor$/, /^Browser$/, /^Capture menu$/] },
  { when: /.*/, picks: [/^Terminal$/, /^Browser$/, /^File manager$/, /^Apps menu$/, /^Editor$/] }
]

// Everything launchable from a Super chord, for an empty desktop.
var LAUNCHER_EXTRAS = /^(Terminal|Herdr|Tmux|Apps menu|Calculator|Activity)$/

// Rows on every Super layer, with keys spelled from Super: "Shift F", "Alt Space".
function superRows(bindings) {
  var out = []
  var sets = {}
  bindings.forEach(function(b) {
    if (b.mods.split(" ").indexOf("SUPER") === -1) return
    ;(sets[b.mods] = sets[b.mods] || []).push(b)
  })
  Object.keys(sets).sort(function(a, b) { return a.split(" ").length - b.split(" ").length }).forEach(function(mods) {
    var extra = mods.replace(/^SUPER ?/, "").split(" ").filter(String)
      .map(function(m) { return m.charAt(0) + m.slice(1).toLowerCase() }).join(" ")
    collapse(sets[mods]).forEach(function(row) {
      row.key = extra ? extra + " " + row.key : row.key
      out.push(row)
    })
  })
  return out
}

function pick(rows, patterns) {
  var out = []
  patterns.forEach(function(rx) {
    var row = rows.filter(function(r) { return rx.test(r.desc) })[0]
    if (row && out.indexOf(row) === -1) out.push(row)
  })
  return out
}

// { sections: [{ title, rows }], launcher: [rows], hidden, total, next: [{ mod, count, summary }] }
// ctx: { winClass, chain } - chain is the focused window's app stack, outermost first.
function view(bindings, mods, flags, maxRows, ctx) {
  mods = canonicalMods(mods)
  ctx = ctx || {}
  var chain = ctx.chain || []
  var emptyDesktop = !ctx.winClass
  var appHints = ctx.appHints !== false  // off = Omarchy shortcuts only
  var rows = collapse(bindings.filter(function(b) { return b.mods === mods }))
  var suggested = []
  var launcher = []

  if (mods === "SUPER") {
    var everything = superRows(bindings)
    if (!appHints) {
      // Plain Omarchy view: keep its own Apps rows, no suggestions or launcher.
    } else if (emptyDesktop) {
      // No window: window commands are moot, so make room for every app.
      rows = rows.filter(function(r) { return r.category !== "Window" && r.category !== "Apps" })
      launcher = everything.filter(function(r) { return r.category === "Apps" || LAUNCHER_EXTRAS.test(r.desc) })
      launcher = launcher.filter(function(r, i) {
        return launcher.findIndex(function(o) { return o.desc === r.desc }) === i
      })
    } else {
      var inner = chain.length ? chain[chain.length - 1] : ""
      var rule = SUGGESTIONS.filter(function(r) { return r.when.test(inner) })[0]
      suggested = pick(everything, rule.picks).map(function(r) { return contextualize(r, flags || "") })
      rows = rows.filter(function(r) { return r.category !== "Apps" })
    }
    rows.sort(function(a, b) { return priority(a) - priority(b) })
    var extras = emptyDesktop ? [] : extraRows(bindings)
    var room = Math.max(0, maxRows - extras.length - suggested.length)
    rows = rows.slice(0, room).concat(extras, rows.slice(room))
  }
  var total = rows.length
  var shown = rows.slice(0, maxRows - suggested.length)

  var order = ["Window", "Workspaces", "Apps", "System"]
  var sections = []
  order.forEach(function(name) {
    var group = shown.filter(function(r) { return r.category === name })
      .map(function(r) { return contextualize(r, flags || "") })
    if (group.length) sections.push({ title: name, rows: group })
    if (name === "Workspaces" && suggested.length) {
      var inner = chain.length ? chain[chain.length - 1] : ""
      sections.push({ title: inner ? "Handy with " + inner : "Handy apps", rows: suggested, accent: true })
    }
  })

  return { sections: sections, launcher: launcher, hidden: total - shown.length, total: total,
    next: nextLayers(bindings, mods) }
}

function extraRows(bindings) {
  var out = []
  SUPER_EXTRAS.forEach(function(extra) {
    var deeper = collapse(bindings.filter(function(b) { return b.mods === extra.mods }))
    deeper.forEach(function(row) {
      if (!extra.rx.test(row.desc)) return
      var mod = extra.mods.replace("SUPER ", "")
      row.key = mod.charAt(0) + mod.slice(1).toLowerCase() + " " + row.key
      out.push(row)
    })
  })
  return out
}

// One modifier deeper: e.g. from SUPER, "+ SHIFT: 31 · apps, workspaces".
function nextLayers(bindings, mods) {
  var current = mods ? mods.split(" ") : []
  var out = []
  MOD_ORDER.forEach(function(mod) {
    if (current.indexOf(mod) !== -1) return
    var target = canonicalMods(current.concat([mod]).join(" "))
    var rows = collapse(bindings.filter(function(b) { return b.mods === target }))
    if (rows.length === 0) return
    var counts = {}
    rows.forEach(function(r) { counts[r.category] = (counts[r.category] || 0) + 1 })
    var top = Object.keys(counts).sort(function(a, b) { return counts[b] - counts[a] }).slice(0, 2)
    out.push({ mod: mod, count: rows.length, summary: top.join(" · ").toLowerCase() })
  })
  return out
}
