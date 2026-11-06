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
  property var prefs: ({ enabled: true, appHints: true, holdDelay: 300 })

  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  function load(text) {
    var next = { enabled: true, appHints: true, holdDelay: 300 }
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
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(480))

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
          text: "Pressing any shortcut hides the hints. Steam games never show them."
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }
  }
}
