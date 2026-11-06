import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "components"
import "HintModel.js" as HintModel

// Hold Super: after a short delay the whole screen dims and the hints appear
// in the top-right corner, under the bar, with no card around them. Left column: Omarchy shortcuts for the held modifiers
// plus what one more modifier unlocks. Right column (Super only): hints for the
// app stack in the focused window, e.g. Ghostty › herdr › Claude Code.
// Driven by hypr/keyhints.lua over IPC; never takes keyboard or pointer input.
Item {
  id: root

  // ------------------------------------------------------------ settings
  // On/off, app hints and hold delay are set from the bar icon (SettingsWidget.qml),
  // which saves them here and pushes each change over IPC (setPrefs).
  readonly property string settingsPath: Quickshell.env("HOME") + "/.config/keyhints/settings.json"
  property var prefs: ({ enabled: true, appHints: true, holdDelay: 300 })
  readonly property int maxRows: 18           // Omarchy rows before "+N more"
  readonly property string contextScript: String(Qt.resolvedUrl("bin/keyhints-context")).replace(/^file:\/\//, "")

  // Colors come from the active Omarchy theme; see components/KeyTheme.qml.
  readonly property KeyTheme theme: KeyTheme {}

  // ------------------------------------------------------------ state
  property bool opened: false
  property string targetMonitor: ""
  property string mods: "SUPER"
  property string winClass: ""
  property string winTitle: ""
  property string winFlags: ""
  property var bindings: []
  property var hints: ({ sections: [], launcher: [], hidden: 0, total: 0, next: [] })
  property var appContext: ({ chain: [], sections: [] })
  property real contentOpacity: 1

  readonly property bool superOnly: mods === "SUPER"
  readonly property bool showApps: superOnly && prefs.appHints && appContext.sections.length > 0
  readonly property int launcherRows: 16
  // Empty desktop: every app launchable from a Super chord, in columns of 16.
  readonly property var launcherColumns: {
    var rows = hints.launcher || []
    var out = []
    for (var i = 0; i < rows.length; i += launcherRows) out.push(rows.slice(i, i + launcherRows))
    return out
  }
  // Games own the keyboard; a card over Helldivers is just noise.
  readonly property bool suppressed: /^steam_app_/.test(winClass)
  readonly property var modChips: mods.split(" ").map(function(m) { return m.charAt(0) + m.slice(1).toLowerCase() })

  function refreshHints() {
    hints = HintModel.view(bindings, mods, winFlags, maxRows,
      { winClass: winClass, chain: appContext.chain, appHints: prefs.appHints })
  }

  function show(newMods, monitor, cls, title, flags) {
    targetMonitor = monitor
    mods = HintModel.canonicalMods(newMods) || "SUPER"
    var sameWindow = cls === winClass && title === winTitle
    winClass = cls
    winTitle = title
    winFlags = flags
    refreshHints()
    if (suppressed || !prefs.enabled) return
    if (!sameWindow) appContext = { chain: [], sections: [] }
    if (prefs.appHints) {
      contextProcess.running = false
      contextProcess.command = [contextScript, cls, title]
      contextProcess.running = true
    }
    holdTimer.restart()
  }

  function update(newMods) {
    var next = HintModel.canonicalMods(newMods)
    if (!next || next === mods) return
    mods = next
    refreshHints()
    if (opened) {
      contentOpacity = 0.4
      settleTimer.restart()
    }
  }

  function hide() {
    holdTimer.stop()
    opened = false
  }

  function reload() {
    hide()
    bindingProcess.running = true
  }

  function loadPrefs(text) {
    var next = { enabled: true, appHints: true, holdDelay: 300 }
    try {
      var saved = JSON.parse(text || "{}")
      for (var k in next) if (saved[k] !== undefined) next[k] = saved[k]
    } catch (e) { }
    prefs = next
    if (!prefs.enabled) hide()
    refreshHints()
  }

  FileView {
    path: root.settingsPath
    printErrors: false
    onLoaded: root.loadPrefs(text())
    onLoadFailed: root.loadPrefs("")
  }

  Timer {
    id: holdTimer
    interval: Number(root.prefs.holdDelay) || 300
    onTriggered: root.opened = true
  }

  Timer {
    id: settleTimer
    interval: 60
    onTriggered: root.contentOpacity = 1
  }

  Process {
    id: bindingProcess
    command: ["omarchy-menu-keybindings", "--print"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = HintModel.parse(text)
        if (parsed.length === 0) return
        root.bindings = parsed
        root.refreshHints()
      }
    }
  }

  Process {
    id: contextProcess
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var parsed = JSON.parse(text)
          if (parsed && Array.isArray(parsed.sections)) {
            root.appContext = parsed
            root.refreshHints()  // app suggestions depend on the app stack
          }
        } catch (e) { }
      }
    }
  }

  IpcHandler {
    target: "keyhints"

    function show(mods: string, monitor: string, cls: string, title: string, flags: string): string {
      root.show(mods, monitor, cls, title, flags)
      return "ok"
    }
    function update(mods: string): string { root.update(mods); return "ok" }
    function hide(): string { root.hide(); return "ok" }
    function reload(): string { root.reload(); return "ok" }
    function state(): string { return root.opened ? root.mods : "closed" }
    function setPrefs(json: string): string { root.loadPrefs(json); return "ok" }
  }

  Component.onCompleted: bindingProcess.running = true

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: panel
      required property var modelData

      readonly property bool isTarget: String(modelData.name || "") === root.targetMonitor

      screen: modelData
      visible: isTarget && (root.opened || scrim.opacity > 0.01)
      anchors { top: true; right: true; bottom: true; left: true }
      color: "transparent"
      // Cover the whole output, bar included, and stay click-through.
      exclusionMode: ExclusionMode.Ignore
      mask: Region {}

      WlrLayershell.namespace: "keyhints"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

      Rectangle {
        id: scrim
        anchors.fill: parent
        color: root.theme.scrim
        opacity: root.opened ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: root.opened ? 160 : 100; easing.type: Easing.OutCubic } }
      }

      Item {
        id: card

        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: Style.bar.sizeHorizontal + Style.space(28)
        anchors.rightMargin: Style.space(40)
        width: body.implicitWidth
        height: body.implicitHeight
        opacity: scrim.opacity
        transform: Translate { y: root.opened ? 0 : -Style.space(8) }

        ColumnLayout {
          id: body
          spacing: Style.spacing.xl
          opacity: root.contentOpacity

          Behavior on opacity { NumberAnimation { duration: 60 } }

          // Header: held modifiers on the left, the focused app stack on the right.
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.spacing.sm

            Repeater {
              model: root.modChips
              Keycap { required property string modelData; keys: modelData; accent: true; theme: root.theme }
            }

            Item { Layout.fillWidth: true; Layout.minimumWidth: Style.space(16) }

            Text {
              visible: root.showApps && root.appContext.chain.length > 0
              text: root.appContext.chain.join("  ›  ")
              color: root.theme.muted
              font.family: Style.font.family
              font.pixelSize: Style.font.body
            }
          }

          RowLayout {
            spacing: Style.space(48)
            Layout.alignment: Qt.AlignTop

            // Omarchy column
            ColumnLayout {
              Layout.alignment: Qt.AlignTop
              Layout.preferredWidth: Style.space(400)
              spacing: Style.spacing.lg

              Repeater {
                model: root.hints.sections
                HintSection {
                  required property var modelData
                  theme: root.theme
                  Layout.fillWidth: true
                  title: modelData.title
                  rows: modelData.rows
                  keyWidth: Style.space(110)
                  appSection: modelData.accent === true
                }
              }

              Text {
                visible: root.hints.sections.length === 0
                text: "Nothing bound here"
                color: root.theme.muted
                font.family: Style.font.family
                font.pixelSize: Style.font.title
              }
            }

            // Focused app column
            ColumnLayout {
              visible: root.showApps
              Layout.alignment: Qt.AlignTop
              Layout.preferredWidth: Style.space(400)
              spacing: Style.spacing.lg

              Repeater {
                model: root.showApps ? root.appContext.sections : []
                HintSection {
                  required property var modelData
                  theme: root.theme
                  Layout.fillWidth: true
                  title: modelData.app
                  rows: modelData.hints
                  keyWidth: Style.space(140)
                  appSection: true
                }
              }
            }

            // Empty-desktop launcher columns
            Repeater {
              model: root.superOnly && root.prefs.appHints ? root.launcherColumns : []
              HintSection {
                required property var modelData
                required property int index
                theme: root.theme
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: Style.space(330)
                title: index === 0 ? "Launch" : " "
                rows: modelData
                keyWidth: Style.space(120)
                appSection: true
              }
            }
          }

          // Footer: what one more modifier unlocks, and what didn't fit.
          Rectangle {
            Layout.fillWidth: true
            implicitHeight: Math.max(1, Style.spacing.hairline)
            color: Util.alpha(root.theme.text, 0.18)
            visible: root.hints.next.length > 0 || root.hints.hidden > 0
          }

          Flow {
            Layout.fillWidth: true
            spacing: Style.spacing.xl
            visible: root.hints.next.length > 0

            Repeater {
              model: root.hints.next
              Row {
                required property var modelData
                spacing: Style.spacing.sm
                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: "+"
                  color: root.theme.muted
                  font.family: Style.font.family
                  font.pixelSize: Style.font.body
                }
                Keycap { keys: modelData.mod.charAt(0) + modelData.mod.slice(1).toLowerCase(); theme: root.theme }
                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: modelData.summary + "  " + modelData.count
                  color: root.theme.muted
                  font.family: Style.font.family
                  font.pixelSize: Style.font.body
                }
              }
            }
          }

          Text {
            visible: root.hints.hidden > 0
            text: "+" + root.hints.hidden + " more  ·  Super K lists every shortcut"
            color: root.theme.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.body
          }
        }
      }
    }
  }
}
