pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "../lib/Model.js" as Model

Item {
    id: root
    required property string label
    required property string shortcut
    required property var choices
    required property var themeColors
    property string fontFamily: "sans-serif"
    property real labelFraction: 0.42
    property bool customEditing: false
    property string customText: shortcut
    signal requested(string shortcut)
    implicitHeight: customEditing ? 108 : 54
    onShortcutChanged: { customText = shortcut; customEditing = false; }
    PropertyEditor {
        labelFraction: root.labelFraction
        width: parent.width
        field: ({type: "enum", label: root.label, options: root.choices.map(Model.shortcutLabel).concat(["Custom…"])})
        value: root.customEditing ? "Custom…" : Model.shortcutLabel(root.shortcut)
        themeColors: root.themeColors; fontFamily: root.fontFamily
        onEdited: function(value) {
            if (value === "Custom…") { root.customEditing = true; input.forceActiveFocus(); return; }
            root.customEditing = false;
            root.requested(root.choices[root.choices.map(Model.shortcutLabel).indexOf(value)]);
        }
    }
    Row {
        visible: root.customEditing
        y: 54; width: parent.width; spacing: 10
        TextField {
            id: input
            objectName: "customShortcutInput"
            width: parent.width - apply.width - 10; height: 38
            text: root.customText; onTextEdited: root.customText = text
            placeholderText: "Example: Ctrl + Super + K"
            maximumLength: 80; selectByMouse: true
            color: root.themeColors.text; placeholderTextColor: root.themeColors.muted
            font.family: root.fontFamily; font.pixelSize: 12
            onAccepted: root.requested(root.customText)
            background: Rectangle { radius: 8; color: Qt.alpha(root.themeColors.text, .04); border.width: 1; border.color: input.activeFocus ? root.themeColors.accent : Qt.alpha(root.themeColors.text, .16) }
            Accessible.name: root.label + " custom shortcut"
        }
        MagicButton { id: apply; text: "Apply"; height: 38; accent: root.themeColors.accent; foreground: root.themeColors.text; fontFamily: root.fontFamily; onClicked: root.requested(root.customText) }
    }
}
