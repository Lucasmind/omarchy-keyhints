import QtQuick
import qs.Commons

// One chord, e.g. "Shift 1–0" or a sequence like "Ctrl Space, Z", drawn as
// small keycaps. "/" and the sequence comma render as plain separators.
Row {
  id: root

  required property string keys
  property bool accent: false

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
      radius: Math.min(Style.cornerRadius, Style.space(4))
      color: modelData.sep ? "transparent" : Util.alpha(Color.popups.text, 0.10)
      border.width: modelData.sep ? 0 : Math.max(1, Style.spacing.hairline)
      border.color: Util.alpha(root.accent ? Color.accent : Color.popups.border, root.accent ? 0.55 : 0.35)

      Text {
        id: label
        anchors.centerIn: parent
        text: modelData.text
        color: modelData.sep ? Util.alpha(Color.popups.text, 0.45)
          : (root.accent ? Color.accent : Color.popups.text)
        font.family: Style.font.family
        font.pixelSize: Style.font.subtitle
        font.bold: !modelData.sep
      }
    }
  }
}
