import QtQuick
import qs.Commons

// One chord, e.g. "Shift 1–0" or a sequence like "Ctrl Space, Z", drawn as
// small keycaps. "/" and the sequence comma render as plain separators.
Row {
  id: root

  required property string keys
  property bool accent: false
  required property KeyTheme theme

  function tokens(keys) {
    var out = []
    var words = keys.split(" ").filter(String)
    words.forEach(function(word, i) {
      // "Ctrl = / -" separates alternatives; a trailing "/" (Shift /) is the key itself.
      if (word === "/" && i < words.length - 1) { out.push({ text: "/", sep: true }); return }
      var then = word.length > 1 && word.charAt(word.length - 1) === ","
      out.push({ text: then ? word.slice(0, -1) : word, sep: false })
      if (then) out.push({ text: "›", sep: true })
    })
    return out
  }

  spacing: Style.spacing.xxs

  Repeater {
    model: root.tokens(root.keys)

    Rectangle {
      required property var modelData

      implicitWidth: modelData.sep ? label.implicitWidth : Math.max(implicitHeight, label.implicitWidth + Style.spacing.md * 2)
      implicitHeight: Style.space(24)
      radius: root.theme.keyRadius
      color: modelData.sep ? "transparent" : (root.accent ? Util.alpha(root.theme.accent, 0.12) : root.theme.keyFill)
      border.width: modelData.sep ? 0 : root.theme.keyBorderWidth
      border.color: root.accent ? Util.alpha(root.theme.accent, 0.6) : root.theme.keyBorder

      Text {
        id: label
        anchors.centerIn: parent
        text: modelData.text
        color: modelData.sep ? root.theme.muted
          : (root.accent ? root.theme.accent : root.theme.keyText)
        font.family: Style.font.family
        font.pixelSize: Style.font.subtitle
        font.bold: !modelData.sep
      }
    }
  }
}
