import QtQuick
import QtQuick.Layouts
import qs.Commons

// A titled group of "keys → description" rows.
ColumnLayout {
  id: root

  property string title: ""
  property var rows: []
  property real keyWidth: Style.space(84)
  property bool appSection: false
  required property KeyTheme theme

  spacing: Style.spacing.sm

  Text {
    text: root.title.toUpperCase()
    color: root.appSection ? root.theme.heading : root.theme.muted
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    font.bold: true
    font.letterSpacing: 1
    bottomPadding: Style.spacing.xxs
  }

  Repeater {
    model: root.rows

    RowLayout {
      required property var modelData
      Layout.fillWidth: true
      spacing: Style.spacing.lg

      Item {
        Layout.preferredWidth: root.keyWidth
        Layout.preferredHeight: caps.implicitHeight
        Keycap {
          id: caps
          anchors.right: parent.right
          keys: modelData.keys !== undefined ? modelData.keys : modelData.key
          theme: root.theme
        }
      }

      Text {
        Layout.fillWidth: true
        text: modelData.desc
        color: root.theme.text
        opacity: 0.95
        elide: Text.ElideRight
        font.family: Style.font.family
        font.pixelSize: Style.font.heading
      }
    }
  }
}
