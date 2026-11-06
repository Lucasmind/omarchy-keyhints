import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "components"
import "HintModel.js" as HintModel

// Hold Super: after a short delay a translucent card appears in the top-right
// corner, under the bar. Left column: Omarchy shortcuts for the held modifiers
// plus what one more modifier unlocks. Right column (Super only): hints for the
// app stack in the focused window, e.g. Ghostty › herdr › Claude Code.
// Driven by hypr/keyhints.lua over IPC; never takes keyboard or pointer input.
Item {
  id: root

  // ------------------------------------------------------------ settings
  readonly property int holdDelay: 300        // ms Super must be held before the card shows
  readonly property int maxRows: 14           // Omarchy rows before "+N more"
  readonly property real glassAlpha: 0.86     // card background opacity (blurred behind)
  readonly property string contextScript: String(Qt.resolvedUrl("bin/keyhints-context")).replace(/^file:\/\//, "")

  // ------------------------------------------------------------ state
  property bool opened: false
  property string targetMonitor: ""
  property string mods: "SUPER"
  property string winClass: ""
  property string winTitle: ""
  property string winFlags: ""
  property var bindings: []
  property var hints: ({ sections: [], hidden: 0, total: 0, next: [] })
  property var appContext: ({ chain: [], sections: [] })
  property real contentOpacity: 1

  readonly property bool superOnly: mods === "SUPER"
  readonly property bool showApps: superOnly && appContext.sections.length > 0
  // Games own the keyboard; a card over Helldivers is just noise.
  readonly property bool suppressed: /^steam_app_/.test(winClass)
  readonly property var modChips: mods.split(" ").map(function(m) { return m.charAt(0) + m.slice(1).toLowerCase() })

  function refreshHints() {
    hints = HintModel.view(bindings, mods, winFlags, maxRows)
  }

  function show(newMods, monitor, cls, title, flags) {
    targetMonitor = monitor
    mods = HintModel.canonicalMods(newMods) || "SUPER"
    var sameWindow = cls === winClass && title === winTitle
    winClass = cls
    winTitle = title
    winFlags = flags
    refreshHints()
    if (suppressed) return
    if (!sameWindow) appContext = { chain: [], sections: [] }
    contextProcess.running = false
    contextProcess.command = [contextScript, cls, title]
    contextProcess.running = true
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

  Timer {
    id: holdTimer
    interval: root.holdDelay
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
          if (parsed && Array.isArray(parsed.sections)) root.appContext = parsed
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
  }

  Component.onCompleted: bindingProcess.running = true

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: panel
      required property var modelData

      readonly property bool isTarget: String(modelData.name || "") === root.targetMonitor

      screen: modelData
      visible: isTarget && (root.opened || card.opacity > 0.01)
      anchors { top: true; right: true }
      margins { top: Style.gapsOut * 2; right: Style.gapsOut * 2 }
      implicitWidth: card.width
      implicitHeight: card.height
      color: "transparent"
      // Sit below the bar rather than over it, without reserving space.
      exclusionMode: ExclusionMode.Normal
      exclusiveZone: 0
      mask: Region {}

      WlrLayershell.namespace: "keyhints"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

      Rectangle {
        id: card

        width: body.implicitWidth + Style.spacing.popupPadding * 2
        height: body.implicitHeight + Style.spacing.popupPadding * 2
        radius: Style.cornerRadius
        color: Util.alpha(Color.popups.background, root.glassAlpha)
        border.width: Math.max(1, Style.spacing.hairline)
        border.color: Util.alpha(Color.popups.border, 0.45)
        opacity: root.opened ? 1 : 0
        transform: Translate { y: root.opened ? 0 : -Style.space(6) }

        Behavior on opacity { NumberAnimation { duration: root.opened ? 140 : 90; easing.type: Easing.OutCubic } }

        ColumnLayout {
          id: body
          x: Style.spacing.popupPadding
          y: Style.spacing.popupPadding
          spacing: Style.spacing.xl
          opacity: root.contentOpacity

          Behavior on opacity { NumberAnimation { duration: 60 } }

          // Header: held modifiers on the left, the focused app stack on the right.
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.spacing.sm

            Repeater {
              model: root.modChips
              Keycap { required property string modelData; keys: modelData; accent: true }
            }

            Item { Layout.fillWidth: true; Layout.minimumWidth: Style.space(16) }

            Text {
              visible: root.superOnly && root.appContext.chain.length > 0
              text: root.appContext.chain.join("  ›  ")
              color: Util.alpha(Color.popups.text, 0.55)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
          }

          RowLayout {
            spacing: Style.spacing.huge
            Layout.alignment: Qt.AlignTop

            // Omarchy column
            ColumnLayout {
              Layout.alignment: Qt.AlignTop
              Layout.preferredWidth: Style.space(262)
              spacing: Style.spacing.lg

              Repeater {
                model: root.hints.sections
                HintSection {
                  required property var modelData
                  Layout.fillWidth: true
                  title: modelData.title
                  rows: modelData.rows
                  keyWidth: Style.space(84)
                }
              }

              Text {
                visible: root.hints.sections.length === 0
                text: "Nothing bound here"
                color: Util.alpha(Color.popups.text, 0.55)
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
              }
            }

            // Focused app column
            ColumnLayout {
              visible: root.showApps
              Layout.alignment: Qt.AlignTop
              Layout.preferredWidth: Style.space(262)
              spacing: Style.spacing.lg

              Repeater {
                model: root.showApps ? root.appContext.sections : []
                HintSection {
                  required property var modelData
                  Layout.fillWidth: true
                  title: modelData.app
                  rows: modelData.hints
                  keyWidth: Style.space(104)
                  appSection: true
                }
              }
            }
          }

          // Footer: what one more modifier unlocks, and what didn't fit.
          Rectangle {
            Layout.fillWidth: true
            implicitHeight: Math.max(1, Style.spacing.hairline)
            color: Util.alpha(Color.popups.border, 0.25)
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
                  color: Util.alpha(Color.popups.text, 0.45)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                }
                Keycap { keys: modelData.mod.charAt(0) + modelData.mod.slice(1).toLowerCase() }
                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: modelData.summary + "  " + modelData.count
                  color: Util.alpha(Color.popups.text, 0.6)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                }
              }
            }
          }

          Text {
            visible: root.hints.hidden > 0
            text: "+" + root.hints.hidden + " more  ·  Super K lists every shortcut"
            color: Util.alpha(Color.popups.text, 0.42)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }
        }
      }
    }
  }
}
