pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

Item {
    id: root
    required property var workspace
    required property var themeColors
    required property var style
    required property string previewMode
    required property var captureFor
    property bool selected: false
    property bool compact: false
    property bool hoverSelect: false
    property int duration: 180
    property string fontFamily: "sans-serif"
    signal picked()
    signal hovered()
    readonly property var windows: workspace.windows || []
    readonly property int radius: style.radius

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Qt.alpha(root.themeColors.surface, root.style.surfaceOpacity)
        border.width: root.selected ? root.style.selectedBorderWidth : root.style.borderWidth
        border.color: root.selected ? root.themeColors.accent : Qt.alpha(root.themeColors.text, root.style.borderOpacity)
        Behavior on border.color { ColorAnimation { duration: root.duration } }
    }
    Item {
        id: previewGrid
        x: root.style.padding
        y: root.style.padding
        width: Math.max(1, root.compact ? Math.min(root.style.compactPreviewWidth, root.width * 0.45) : root.width - root.style.padding * 2)
        height: Math.max(1, root.compact ? root.height - root.style.padding * 2 : root.height - root.style.footerHeight - root.style.padding * 2)
        Repeater {
            model: Math.min(root.windows.length, 4)
            ClippingRectangle {
                id: previewTile
                required property int index
                readonly property var windowInfo: root.windows[index]
                readonly property var desktopEntry: DesktopEntries.heuristicLookup(windowInfo.appId || "")
                readonly property string appName: desktopEntry ? desktopEntry.name : windowInfo.appId || "Application"
                readonly property string appIcon: desktopEntry && desktopEntry.icon ? Quickshell.iconPath(desktopEntry.icon, true) : ""
                width: Math.max(1, (previewGrid.width - 5) / 2)
                height: Math.max(1, (previewGrid.height - 5) / 2)
                x: (index % 2) * (width + 5)
                y: Math.floor(index / 2) * (height + 5)
                radius: 5
                color: Qt.alpha(root.themeColors.text, 0.05)
                Loader {
                    id: captureLoader
                    anchors.fill: parent
                    active: root.previewMode !== "icon"
                    sourceComponent: Component {
                        ScreencopyView {
                            captureSource: root.captureFor(windowInfo.address)
                            live: root.previewMode === "live" || (root.previewMode === "hybrid" && root.selected)
                            constraintSize: Qt.size(parent.width, parent.height)
                            paintCursor: false
                        }
                    }
                }
                Item {
                    anchors.fill: parent
                    visible: root.previewMode === "icon" || !captureLoader.item || !captureLoader.item.hasContent
                    Rectangle { anchors.fill: parent; color: Qt.alpha(root.themeColors.accent, 0.08) }
                    Rectangle {
                        id: iconTile
                        width: Math.max(1, Math.min(root.style.previewIconSize, parent.width - 8, parent.height - 8))
                        height: width
                        radius: width * 0.26
                        anchors.centerIn: parent
                        color: Qt.alpha(root.themeColors.accent, 0.10)
                        border.width: 1
                        border.color: Qt.alpha(root.themeColors.accent, 0.14)
                        Image { id: appIconImage; anchors.centerIn: parent; width: parent.width * 0.62; height: width; source: previewTile.appIcon; fillMode: Image.PreserveAspectFit; visible: status === Image.Ready }
                        Text { anchors.centerIn: parent; visible: !appIconImage.visible; text: previewTile.appName.slice(0, 1).toUpperCase(); color: root.themeColors.accent; font.pixelSize: Math.max(12, parent.width * 0.43); font.family: root.fontFamily }
                    }
                }
            }
        }
        Text {
            anchors.centerIn: parent
            visible: root.windows.length === 0
            text: "Empty space"
            color: root.themeColors.muted
            font.family: root.fontFamily
            font.pixelSize: 12
        }
        Rectangle {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            visible: root.windows.length > 4
            width: moreText.implicitWidth + 14
            height: 22
            radius: 7
            color: Qt.alpha(root.themeColors.surface, 0.94)
            Text { id: moreText; anchors.centerIn: parent; text: "+" + (root.windows.length - 4); color: root.themeColors.text; font.family: root.fontFamily; font.pixelSize: 10 }
        }
    }
    Row {
        x: root.compact ? previewGrid.x + previewGrid.width + root.style.padding : root.style.padding + 3
        y: root.compact ? (parent.height - height) / 2 : parent.height - root.style.footerHeight + (root.style.footerHeight - height) / 2
        width: Math.max(1, parent.width - x - root.style.padding - 3)
        spacing: 8
        Rectangle {
            width: 30; height: 30; radius: 9
            color: root.workspace.active ? Qt.alpha(root.themeColors.accent, 0.2) : Qt.alpha(root.themeColors.text, 0.06)
            Text { anchors.centerIn: parent; text: String(root.workspace.id); color: root.workspace.active ? root.themeColors.accent : root.themeColors.muted; font.family: root.fontFamily; font.pixelSize: 12; font.weight: Font.DemiBold }
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 38
            Text { width: parent.width; text: root.workspace.name === String(root.workspace.id) ? "Workspace " + root.workspace.name : root.workspace.name; color: root.themeColors.text; font.family: root.fontFamily; font.pixelSize: root.style.titleSize; font.weight: Font.DemiBold; elide: Text.ElideRight }
            Text { width: parent.width; text: root.windows.length + (root.windows.length === 1 ? " window" : " windows"); color: root.themeColors.muted; font.family: root.fontFamily; font.pixelSize: root.style.subtitleSize; elide: Text.ElideRight }
        }
    }
    MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onPositionChanged: if (root.hoverSelect && containsMouse) root.hovered(); onClicked: root.picked() }
    Accessible.role: Accessible.ListItem
    Accessible.name: "Workspace " + root.workspace.name + ", " + root.windows.length + " windows"
    Accessible.selected: root.selected
}
