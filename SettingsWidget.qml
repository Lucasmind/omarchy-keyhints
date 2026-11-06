import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Bar icon for Key Hints. Left click: settings panel. Right click: on/off.
// Settings are saved to ~/.config/keyhints/settings.json and pushed to the
// overlay over IPC, so every change applies the next time Super is held.
Panel {
  id: root
  moduleName: "keyhints"
  ipcTarget: "keyhints-panel"

  readonly property string settingsPath: Quickshell.env("HOME") + "/.config/keyhints/settings.json"
  property var prefs: ({ enabled: true, appHints: true, holdDelay: 300, learning: true, overFullscreen: false })
  property var stats: null   // from the overlay: { known, learning, untried, total, presses, baseline }

  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  function load(text) {
    var next = { enabled: true, appHints: true, holdDelay: 300, learning: true, overFullscreen: false }
    try {
      var saved = JSON.parse(text || "{}")
      for (var k in next) if (saved[k] !== undefined) next[k] = saved[k]
    } catch (e) { }
    prefs = next
  }

  function set(key, value) {
    var next = JSON.parse(JSON.stringify(prefs))
    next[key] = value
    prefs = next
    var json = JSON.stringify(next, null, 2) + "\n"
    settingsFile.setText(json)
    Quickshell.execDetached(["omarchy-shell", "-q", "keyhints", "setPrefs", json])
  }

  function refreshStats() {
    statsProcess.running = false
    statsProcess.running = true
  }

  onOpenedChanged: if (opened) refreshStats()

  Process {
    id: statsProcess
    command: ["omarchy-shell", "keyhints", "stats"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { root.stats = JSON.parse(text) } catch (e) { root.stats = null }
      }
    }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  FileView {
    id: settingsFile
    path: root.settingsPath
    atomicWrites: true
    printErrors: false
    onLoaded: root.load(text())
    onLoadFailed: root.load("")
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰌌"
    opacity: root.prefs.enabled ? 1 : 0.45
    tooltipText: root.opened ? "" : (root.prefs.enabled ? "Key Hints: hold Super" : "Key Hints (off)")
    onPressed: function(b) {
      if (b === Qt.RightButton) root.set("enabled", !root.prefs.enabled)
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(720))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        width: parent.width
        spacing: Style.space(12)

        PanelHero {
          id: hero
          width: parent.width
          title: "Key Hints"
          meta: root.prefs.enabled ? "Hold Super for shortcut hints" : "Off"
          foreground: root.foreground
          fontFamily: root.fontFamily
          iconOpacity: root.prefs.enabled ? 1 : 0.5
          iconComponent: Component {
            Text {
              text: "󰌌"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
            }
          }
          trailingControl: Component {
            ToggleSwitch {
              checked: root.prefs.enabled
              foreground: root.foreground
              onToggled: root.set("enabled", !root.prefs.enabled)
            }
          }
        }

        PanelSeparator { foreground: root.foreground }

        PanelSectionHeader {
          text: "WHAT TO SHOW"
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        Toggle {
          width: parent.width
          label: "Omarchy shortcuts"
          description: "Window, workspace and system keys for the modifiers you hold. Always on."
          checked: true
          enabled: false
          opacity: 0.6
          foreground: root.foreground
        }

        Toggle {
          width: parent.width
          label: "App hints"
          description: "Keys for the focused app (Ghostty, herdr, Claude Code…), apps that suit what you're doing, and every launchable app on an empty desktop."
          checked: root.prefs.appHints
          enabled: root.prefs.enabled
          foreground: root.foreground
          onClicked: root.set("appHints", !root.prefs.appHints)
        }

        Toggle {
          width: parent.width
          label: "Show over full-screen windows"
          description: "Off: hidden over full-screen apps (Super F), like videos and presentations. Steam games never show hints."
          checked: root.prefs.overFullscreen
          enabled: root.prefs.enabled
          foreground: root.foreground
          onClicked: root.set("overFullscreen", !root.prefs.overFullscreen)
        }

        PanelSeparator { foreground: root.foreground }

        PanelSectionHeader {
          text: "LEARNING"
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        Toggle {
          width: parent.width
          label: "Learn from my usage"
          description: "Counts which Super shortcuts you press, on this machine only (never typing). Ones you know fade; a few worth trying get highlighted."
          checked: root.prefs.learning
          enabled: root.prefs.enabled
          foreground: root.foreground
          onClicked: root.set("learning", !root.prefs.learning)
        }

        Item {
          width: parent.width
          height: Math.max(statsText.implicitHeight, resetButton.implicitHeight)
          visible: root.prefs.learning && root.stats !== null

          Text {
            id: statsText
            anchors.left: parent.left
            anchors.right: resetButton.left
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            wrapMode: Text.WordWrap
            text: !root.stats ? ""
              : root.stats.presses < root.stats.baseline
                ? "Getting to know you: " + root.stats.presses + " of " + root.stats.baseline + " shortcut presses before hints adapt."
                : "You use " + root.stats.known + " of " + root.stats.total + " shortcuts, are learning "
                  + root.stats.learning + ", and haven't tried " + root.stats.untried + "."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          Button {
            id: resetButton
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "Reset"
            bordered: true
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: {
              Quickshell.execDetached(["omarchy-shell", "-q", "keyhints", "resetUsage"])
              statsDelay.restart()
            }
          }

          Timer { id: statsDelay; interval: 300; onTriggered: root.refreshStats() }
        }

        PanelSeparator { foreground: root.foreground }

        PanelSectionHeader {
          text: "HOLD SUPER FOR"
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        ButtonGroup {
          options: [
            { value: "150", label: "Quick" },
            { value: "300", label: "Normal" },
            { value: "600", label: "Relaxed" }
          ]
          value: String(root.prefs.holdDelay)
          enabled: root.prefs.enabled
          foreground: root.foreground
          fontFamily: root.fontFamily
          onChanged: function(v) { root.set("holdDelay", Number(v)) }
        }

        Text {
          width: parent.width
          wrapMode: Text.WordWrap
          text: "Pressing a shortcut, dragging with the mouse or switching workspace hides the hints until you let go of Super."
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }
  }
}
