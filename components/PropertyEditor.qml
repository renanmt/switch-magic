pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

Item {
    id: root
    required property var field
    required property var value
    required property var themeColors
    property string fontFamily: "sans-serif"
    property real labelFraction: 0.42
    signal edited(var next)
    implicitHeight: field.type === "text" || field.type === "color" ? 68 : 54
    opacity: enabled ? 1 : 0.45
    function format(value) { return typeof value === "number" ? String(Math.round(value * 100) / 100) : String(value); }
    Text { id: label; visible: root.labelFraction > 0; x: 0; y: root.field.type === "text" || root.field.type === "color" ? 0 : 9; width: parent.width * root.labelFraction; text: root.field.label; color: root.themeColors.text; font.family: root.fontFamily; font.pixelSize: 12; wrapMode: Text.Wrap }
    Loader {
        x: root.field.type === "text" || root.field.type === "color" ? 0 : (root.labelFraction > 0 ? parent.width * (root.labelFraction + 0.02) : 0)
        y: root.field.type === "text" || root.field.type === "color" ? 24 : 0
        width: parent.width - x; height: 34
        sourceComponent: root.field.type === "boolean" ? booleanControl : root.field.type === "enum" ? choiceControl : root.field.type === "text" || root.field.type === "color" ? textControl : numberControl
    }
    Component {
        id: booleanControl
        MagicButton { text: root.value ? "On" : "Off"; chosen: root.value; accent: root.themeColors.accent; foreground: root.themeColors.text; fontFamily: root.fontFamily; onClicked: root.edited(!root.value) }
    }
    Component {
        id: choiceControl
        ComboBox {
            id: choice
            objectName: "propertyChoice"
            model: root.field.options
            currentIndex: root.field.options.indexOf(root.value)
            onActivated: {
                root.edited(root.field.options[currentIndex]);
                // Keep the displayed choice in sync if an edit is cancelled or rejected.
                currentIndex = Qt.binding(function() { return root.field.options.indexOf(root.value); });
            }
            font.family: root.fontFamily; font.pixelSize: 12
            contentItem: Text { leftPadding: 12; rightPadding: 26; text: choice.displayText; color: root.themeColors.text; verticalAlignment: Text.AlignVCenter; font: choice.font; elide: Text.ElideRight }
            background: Rectangle { color: Qt.alpha(root.themeColors.text, .04); radius: 8; border.width: 1; border.color: choice.activeFocus ? root.themeColors.accent : Qt.alpha(root.themeColors.text, .12) }
            indicator: Text { text: "⌄"; color: root.themeColors.muted; x: choice.width - 22; anchors.verticalCenter: parent.verticalCenter }
            delegate: ItemDelegate { required property var modelData; required property int index; width: choice.width; text: modelData; highlighted: choice.highlightedIndex === index; contentItem: Text { text: parent.text; color: root.themeColors.text; font: choice.font } background: Rectangle { color: parent.highlighted ? Qt.alpha(root.themeColors.accent, .18) : root.themeColors.surface } }
            popup: Popup { y: choice.height + 4; width: choice.width; padding: 5; implicitHeight: Math.min(contentItem.implicitHeight + 10, 250); contentItem: ListView { clip: true; implicitHeight: contentHeight; model: choice.popup.visible ? choice.delegateModel : null; currentIndex: choice.highlightedIndex } background: Rectangle { radius: 8; color: root.themeColors.surface; border.width: 1; border.color: Qt.alpha(root.themeColors.accent, .4) } }
        }
    }
    Component {
        id: textControl
        TextField {
            id: edit
            text: String(root.value); placeholderText: root.field.hint || ""
            font.family: root.fontFamily; font.pixelSize: 12
            color: root.themeColors.text; placeholderTextColor: root.themeColors.muted
            selectionColor: Qt.alpha(root.themeColors.accent, .35)
            maximumLength: root.field.maxLength || 80
            onEditingFinished: root.edited(text)
            background: Rectangle { radius: 8; color: Qt.alpha(root.themeColors.text, .04); border.width: 1; border.color: edit.activeFocus ? root.themeColors.accent : Qt.alpha(root.themeColors.text, .12) }
            Accessible.name: root.field.label
        }
    }
    Component {
        id: numberControl
        Item {
            Slider {
                id: slider
                width: Math.max(30, parent.width - 86); height: parent.height
                from: root.field.min; to: root.field.max; stepSize: root.field.step
                value: Number(root.value)
                onMoved: root.edited(Math.round(value * 100) / 100)
                background: Rectangle { x: slider.leftPadding; y: slider.topPadding + slider.availableHeight / 2 - 2; width: slider.availableWidth; height: 4; radius: 2; color: Qt.alpha(root.themeColors.text, .10); Rectangle { width: slider.visualPosition * parent.width; height: 4; radius: 2; color: root.themeColors.accent } }
                handle: Rectangle { x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width); y: slider.topPadding + slider.availableHeight / 2 - 6; width: 12; height: 12; radius: 6; color: root.themeColors.accent }
                Accessible.name: root.field.label
            }
            TextField {
                id: number
                anchors.right: parent.right; width: 76; height: parent.height
                text: root.format(root.value)
                font.family: root.fontFamily; font.pixelSize: 11; horizontalAlignment: Text.AlignRight
                color: root.themeColors.text; selectByMouse: true
                validator: DoubleValidator { bottom: root.field.min; top: root.field.max; decimals: root.field.step < 1 ? 2 : 0; locale: "C" }
                onEditingFinished: {
                    if (acceptableInput) root.edited(Number(text));
                    text = root.format(root.value);
                }
                background: Rectangle { radius: 7; color: Qt.alpha(root.themeColors.text, .04); border.width: 1; border.color: number.activeFocus ? root.themeColors.accent : Qt.alpha(root.themeColors.text, .10) }
                Accessible.name: root.field.label + " value " + (root.field.unit || "")
            }
        }
    }
}
