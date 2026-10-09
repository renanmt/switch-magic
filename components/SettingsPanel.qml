pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "../lib/Model.js" as Model
import "../lib/ViewFields.js" as Fields

Rectangle {
    id: root
    required property var config
    required property var themeColors
    property string fontFamily: "sans-serif"
    property real screenWidth: 1920
    property real screenHeight: 1080
    readonly property var gridFit: Model.gridLimits(editingView.geometry, Math.max(280, screenWidth - 100), Math.max(180, screenHeight - 300))
    property string error: ""
    property bool saved: false
    property string tab: "shortcuts"
    property string selectedScope: "workspace"
    property var draft: Model.clone(config)
    property string editorId: config.profiles.workspace.view
    property string localError: ""
    property bool creating: false
    property string pendingDeleteId: ""
    property string copyName: ""
    property string renameText: ""
    property int editorGroup: 0
    readonly property var profile: draft.profiles[selectedScope]
    readonly property var editingView: Model.view(draft, editorId) || draft.views[0]
    readonly property bool locked: Model.builtin(draft, editingView.id)
    readonly property var validation: Model.validate(draft, config, Fields.groups)
    property bool dirty: false
    signal save(var next)
    signal dismiss()
    radius: 26; color: themeColors.surface
    border.width: 1; border.color: Qt.alpha(themeColors.text, .16)
    function setDraft(next) {
        draft = next; dirty = true; saved = false; localError = "";
        retrySave.stop(); autoSave.restart();
    }
    function flushChanges() {
        autoSave.stop();
        if (!dirty || validation.length) return;
        save(Model.clone(draft));
    }
    function saveCompleted(success) {
        if (success) { dirty = false; saved = true; retrySave.stop(); }
        else retrySave.restart();
    }
    function prepareClose() {
        forceActiveFocus(); // Commit any focused numeric or font field first.
        flushChanges();
        return !dirty;
    }
    Timer { id: autoSave; interval: 300; onTriggered: root.flushChanges() }
    Timer { id: retrySave; interval: 3000; onTriggered: root.flushChanges() }
    function selectView(id) { var next = Model.clone(draft); next.profiles[selectedScope].view = id; setDraft(next); }
    function changeField(path, value) {
        try {
            var next = Model.changeView(draft, editorId, path, value);
            var errors = Model.validate(next, config, Fields.groups);
            if (errors.length) { localError = errors[0]; return; }
            setDraft(next);
        }
        catch(e) { localError = String(e.message || e); }
    }
    function editName(text) { renameText = text; changeField("name", text); }
    function startCopy() {
        var base = "My " + editingView.name, candidate = base, index = 2;
        while (Model.nameError(draft, candidate)) candidate = base.slice(0, 52) + " " + index++;
        copyName = candidate; creating = true; localError = "";
    }
    function createView() {
        try {
            var result = Model.duplicate(draft, editorId, copyName);
            setDraft(result.config); editorId = result.id; creating = false; tab = "editor";
        } catch(e) { localError = String(e.message || e); }
    }
    function requestDeletion() {
        if (locked) return;
        pendingDeleteId = editingView.id;
        deleteDialog.open();
    }
    function removeView(id) {
        var target = Model.view(draft, id);
        if (!target) return;
        try { setDraft(Model.removeView(draft, id)); editorId = target.engine; }
        catch(e) { localError = String(e.message || e); }
    }
    onEditorIdChanged: { var chosenView = Model.view(draft, editorId); renameText = chosenView ? chosenView.name : ""; localError = ""; }
    Component.onCompleted: renameText = editingView.name
    Dialog {
        id: deleteDialog
        objectName: "deleteViewDialog"
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(460, root.width - 48)
        modal: true; dim: true; focus: true
        padding: 24
        closePolicy: Popup.CloseOnEscape
        header: null; footer: null
        background: Rectangle { radius: 18; color: root.themeColors.surface; border.width: 1; border.color: Qt.alpha(root.themeColors.accent, .45) }
        onOpened: cancelDelete.forceActiveFocus()
        onAccepted: root.removeView(root.pendingDeleteId)
        contentItem: Column {
            spacing: 18
            Text { width: parent.width; text: "Delete custom view?"; color: root.themeColors.text; font.family: root.fontFamily; font.pixelSize: 20; font.weight: Font.DemiBold; wrapMode: Text.Wrap }
            Text {
                width: parent.width; wrapMode: Text.Wrap; textFormat: Text.PlainText
                text: "“" + (Model.view(root.draft, root.pendingDeleteId) || {name: "This view"}).name + "” will be removed from your library. Any shortcut using it will return to its built-in layout."
                color: root.themeColors.muted; font.family: root.fontFamily; font.pixelSize: 13; lineHeight: 1.4
            }
            Row {
                anchors.right: parent.right; spacing: 10
                MagicButton { id: cancelDelete; text: "Cancel"; accent: root.themeColors.accent; foreground: root.themeColors.text; fontFamily: root.fontFamily; onClicked: deleteDialog.reject() }
                MagicButton { text: "Delete view"; chosen: true; accent: "#f07878"; foreground: root.themeColors.text; fontFamily: root.fontFamily; onClicked: deleteDialog.accept() }
            }
        }
    }
    MouseArea { anchors.fill: parent }
    Brand { showCredit: false; x: 30; y: 22; themeColors: root.themeColors; fontFamily: root.fontFamily; textSize: 20; sparkleSize: 30; tracking: 2 }
    MagicButton { anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 26; text: "Close  ×"; accent: root.themeColors.accent; foreground: root.themeColors.text; fontFamily: root.fontFamily; onClicked: root.dismiss() }
    Row {
        x: 30; y: 94; spacing: 10
        Repeater {
            model: [{id: "shortcuts", name: "Shortcuts"}, {id: "editor", name: "View studio"}, {id: "about", name: "About"}]
            MagicButton { required property var modelData; text: modelData.name; chosen: root.tab === modelData.id; accent: root.themeColors.accent; foreground: root.themeColors.text; fontFamily: root.fontFamily; onClicked: root.tab = modelData.id }
        }
    }
    Rectangle { x: 0; y: 149; width: parent.width; height: 1; color: Qt.alpha(root.themeColors.text, .08) }
    // Shortcuts: choose any shipped or custom view from the same carousel.
    Flickable {
        visible: root.tab === "shortcuts"
        x: 30; y: 176; width: parent.width - 60; height: parent.height - y - 60
        clip: true; contentHeight: mainContent.height; boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { }
        Column {
            id: mainContent
            width: parent.width; spacing: 24
            Flow {
                width: parent.width; spacing: 8
                Repeater {
                    model: [{id: "workspace", title: "Workspace · Ctrl Super Tab"}, {id: "monitor", title: "Monitor · Shift Alt Tab"}, {id: "all", title: "Everywhere · Ctrl Alt Tab"}, {id: "spaces", title: "Spaces · Alt Tab"}]
                    MagicButton { required property var modelData; text: modelData.title; chosen: root.selectedScope === modelData.id; accent: root.themeColors.accent; foreground: root.themeColors.text; fontFamily: root.fontFamily; onClicked: root.selectedScope = modelData.id }
                }
            }
            Column {
                width: parent.width; spacing: 14
                Text { text: "CHOOSE A VIEW"; color: root.themeColors.muted; font.family: root.fontFamily; font.pixelSize: 10; font.letterSpacing: 2 }
                ViewCarousel { screenWidth: root.screenWidth; screenHeight: root.screenHeight; width: parent.width; config: root.draft; selectedId: root.profile.view; themeColors: root.themeColors; fontFamily: root.fontFamily; onPicked: function(id) { root.selectView(id); } }
            }
            Column {
                width: parent.width; spacing: 8
                Text { text: "PICKER BRANDING"; color: root.themeColors.muted; font.family: root.fontFamily; font.pixelSize: 10; font.letterSpacing: 2 }
                MagicButton {
                    text: root.draft.behavior.showLogo ? "Logo and wordmark shown" : "Logo and wordmark hidden"
                    chosen: root.draft.behavior.showLogo
                    accent: root.themeColors.accent; foreground: root.themeColors.text; fontFamily: root.fontFamily
                    onClicked: { var next = Model.clone(root.draft); next.behavior.showLogo = !next.behavior.showLogo; root.setDraft(next); }
                }
            }
            Column {
                width: parent.width; spacing: 12
                Text { text: "WINDOW PREVIEWS"; color: root.themeColors.muted; font.family: root.fontFamily; font.pixelSize: 10; font.letterSpacing: 2 }
                Flow {
                    width: parent.width; spacing: 10
                    Repeater {
                        model: [{id: "view", name: "View default"}, {id: "live", name: "Live"}, {id: "snapshot", name: "Snapshot"}, {id: "hybrid", name: "Live selection"}, {id: "icon", name: "Icons only"}]
                        MagicButton {
                            required property var modelData
                            text: modelData.name; chosen: root.profile.preview === modelData.id
                            accent: root.themeColors.accent; foreground: root.themeColors.text; fontFamily: root.fontFamily
                            onClicked: { var next = Model.clone(root.draft); next.profiles[root.selectedScope].preview = modelData.id; root.setDraft(next); }
                        }
                    }
                }
                Text { width: parent.width; wrapMode: Text.Wrap; text: "Use the view’s preview setting, or choose a different mode for this shortcut. Motion and styling belong to the view."; color: root.themeColors.muted; font.family: root.fontFamily; font.pixelSize: 12 }
            }
            MagicButton { text: "Customize this view  →"; accent: root.themeColors.accent; foreground: root.themeColors.text; fontFamily: root.fontFamily; onClicked: { root.editorId = root.profile.view; root.tab = "editor"; } }
        }
    }
    // Studio: controls and preview use the very same declarative view object.
    Item {
        id: studio
        visible: root.tab === "editor"
        x: 30; y: 167; width: parent.width - 60; height: parent.height - y - 60
        readonly property bool narrow: width < 850
        readonly property int leftWidth: narrow ? width : Math.round(width * .49)
        PropertyEditor {
            id: library
            width: studio.width - 182; height: 46
            field: ({type: "enum", label: "VIEW LIBRARY", options: Model.catalog(root.draft).map(function(v) { return v.name; })})
            value: root.editingView.name; themeColors: root.themeColors; fontFamily: root.fontFamily
            onEdited: function(value) { var v = Model.catalog(root.draft).find(function(v) { return v.name === value; }); if (v) root.editorId = v.id; }
        }
        MagicButton { anchors.right: parent.right; width: 163; text: "+ Duplicate view"; accent: root.themeColors.accent; foreground: root.themeColors.text; fontFamily: root.fontFamily; onClicked: root.startCopy() }
        Rectangle {
            id: copyForm
            visible: root.creating; y: 52; width: parent.width; height: 62; radius: 12; color: Qt.alpha(root.themeColors.accent, .08); border.width: 1; border.color: Qt.alpha(root.themeColors.accent, .25)
            TextField { id: copyInput; x: 12; y: 12; width: parent.width - 232; height: 38; text: root.copyName; onTextEdited: root.copyName = text; placeholderText: "Name your new view"; font.family: root.fontFamily; font.pixelSize: 12; color: root.themeColors.text; maximumLength: 60; selectByMouse: true; onAccepted: root.createView(); background: Rectangle { color: Qt.alpha(root.themeColors.text, .04); radius: 7; border.width: 1; border.color: Qt.alpha(root.themeColors.text, .16) } }
            MagicButton { x: parent.width - 206; y: 12; width: 92; height: 38; text: "Create"; chosen: true; accent: root.themeColors.accent; foreground: root.themeColors.text; onClicked: root.createView() }
            MagicButton { x: parent.width - 104; y: 12; width: 92; height: 38; text: "Cancel"; accent: root.themeColors.accent; foreground: root.themeColors.text; onClicked: root.creating = false }
        }
        Flickable {
            id: editorScroll
            y: root.creating ? 126 : 58; width: studio.leftWidth; height: parent.height - y
            clip: true; contentHeight: controls.height; boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { }
            Column {
                id: controls
                width: parent.width - 14; spacing: 16
                Rectangle {
                    width: parent.width; height: root.locked ? 70 : 93; radius: 12; color: Qt.alpha(root.themeColors.accent, .06)
                    Column {
                        x: 12; y: 12; width: parent.width - 24; spacing: 8
                        Text { text: root.locked ? "BUILT-IN · READ-ONLY" : "YOUR CUSTOM VIEW"; color: root.themeColors.accent; font.family: root.fontFamily; font.pixelSize: 10; font.letterSpacing: 1 }
                        Text { visible: root.locked; width: parent.width; wrapMode: Text.Wrap; text: "Duplicate this template to make it yours. The original always stays intact."; color: root.themeColors.muted; font.family: root.fontFamily; font.pixelSize: 11 }
                        Row {
                            visible: !root.locked; width: parent.width; spacing: 8
                            TextField { width: parent.width - 95; height: 36; text: root.renameText; onTextEdited: root.editName(text); onEditingFinished: root.flushChanges(); color: root.themeColors.text; font.family: root.fontFamily; font.pixelSize: 12; maximumLength: 60; selectByMouse: true; onAccepted: root.flushChanges(); background: Rectangle { radius: 7; color: Qt.alpha(root.themeColors.text, .045); border.width: 1; border.color: Qt.alpha(root.themeColors.text, .13) } }
                            MagicButton { width: 87; height: 36; text: "Delete…"; accent: root.themeColors.accent; foreground: root.themeColors.text; onClicked: root.requestDeletion() }
                        }

                    }
                }
                Flow {
                    width: parent.width; spacing: 7
                    Repeater {
                        model: Fields.groups
                        MagicButton { required property var modelData; required property int index; text: modelData.name; chosen: root.editorGroup === index; height: 32; accent: root.themeColors.accent; foreground: root.themeColors.text; fontFamily: root.fontFamily; onClicked: root.editorGroup = index }
                    }
                }
                Text {
                    visible: root.editingView.engine === "grid" && root.editorGroup === 0
                    width: parent.width; wrapMode: Text.Wrap
                    text: "Columns and rows are maximums. If the tiles won’t fit on the screen, the grid automatically uses fewer. Extra windows appear on the next page."
                        + "\nThis screen fits up to " + root.gridFit.columns + " columns × " + root.gridFit.rows + " rows with these settings."
                        + (root.gridFit.columns < root.editingView.geometry.columns ? "\nYour column limit exceeds the available width; it will be reduced automatically." : "")
                        + (root.gridFit.rows < root.editingView.geometry.rows ? "\nYour row limit exceeds the available height; it will be reduced automatically." : "")
                    color: root.gridFit.columns < root.editingView.geometry.columns || root.gridFit.rows < root.editingView.geometry.rows ? root.themeColors.accent : root.themeColors.muted
                    font.family: root.fontFamily; font.pixelSize: 11; lineHeight: 1.4
                }
                Column {
                    width: parent.width; spacing: 6
                    enabled: !root.locked
                    Repeater {
                        model: Fields.groups[root.editorGroup].fields
                        PropertyEditor {
                            required property var modelData
                            width: parent.width
                            visible: !modelData.engines || modelData.engines.indexOf(root.editingView.engine) >= 0
                            height: visible ? implicitHeight : 0
                            field: modelData; value: Model.get(root.editingView, modelData.path)
                            themeColors: root.themeColors; fontFamily: root.fontFamily
                            onEdited: function(value) { root.changeField(modelData.path, value); }
                        }
                    }
                }
                Rectangle {
                    visible: studio.narrow; width: parent.width; height: visible ? 300 : 0; radius: 16; color: Qt.alpha(root.themeColors.text, .025)
                    ViewPreview { screenWidth: root.screenWidth; screenHeight: root.screenHeight; anchors.fill: parent; view: root.editingView; themeColors: root.themeColors; fontFamily: root.fontFamily }
                }
            }
        }
        Column {
            visible: !studio.narrow
            x: studio.leftWidth + 22; y: root.creating ? 126 : 58; width: studio.width - x; spacing: 18
            Text { text: "PREVIEW"; color: root.themeColors.muted; font.family: root.fontFamily; font.pixelSize: 10; font.letterSpacing: 2 }
            Rectangle {
                width: parent.width; height: 330; radius: 18; color: Qt.alpha(root.themeColors.text, .025); border.width: 1; border.color: Qt.alpha(root.themeColors.text, .07)
                ViewPreview { screenWidth: root.screenWidth; screenHeight: root.screenHeight; id: livePreview; anchors.fill: parent; anchors.margins: 8; view: root.editingView; themeColors: root.themeColors; fontFamily: root.fontFamily }
            }
            Text { width: parent.width; text: root.editingView.name; textFormat: Text.PlainText; wrapMode: Text.Wrap; color: root.themeColors.text; font.family: root.fontFamily; font.pixelSize: 18; font.weight: Font.DemiBold }
            Text { width: parent.width; wrapMode: Text.Wrap; text: "Every change is reflected here. Click a card to try the motion, and choose your view in Shortcuts. Changes save automatically."; color: root.themeColors.muted; font.family: root.fontFamily; font.pixelSize: 12; lineHeight: 1.4 }
            Row { spacing: 8
                MagicButton { text: "←"; accent: root.themeColors.accent; foreground: root.themeColors.text; onClicked: livePreview.selected = Model.wrap(livePreview.selected - 1, livePreview.count) }
                MagicButton { text: "Try switching →"; accent: root.themeColors.accent; foreground: root.themeColors.text; onClicked: livePreview.selected = Model.wrap(livePreview.selected + 1, livePreview.count) }
            }
        }
    }
    Flickable {
        visible: root.tab === "about"
        x: 30; y: 176; width: parent.width - 60; height: parent.height - y - 60
        contentHeight: about.height; clip: true
        Column {
            id: about
            width: Math.min(parent.width, 650); anchors.horizontalCenter: parent.horizontalCenter; spacing: 22
            BrandIcon { anchors.horizontalCenter: parent.horizontalCenter; width: 78; height: 78; color: root.themeColors.accent }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "A little magic between windows."; color: root.themeColors.text; font.family: root.fontFamily; font.pixelSize: 23; font.weight: Font.DemiBold }
            Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; text: "Switch Magic brings expressive layouts, live previews and personal style to the everyday act of changing windows."; color: root.themeColors.muted; font.family: root.fontFamily; font.pixelSize: 13; lineHeight: 1.6 }
            Rectangle {
                width: parent.width; height: 133; radius: 18; color: Qt.alpha(root.themeColors.accent, .07); border.width: 1; border.color: Qt.alpha(root.themeColors.accent, .18)
                Column { anchors.centerIn: parent; spacing: 12
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "DESIGNED & CREATED BY"; color: root.themeColors.muted; font.family: root.fontFamily; font.pixelSize: 10; font.letterSpacing: 2 }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Renan Tonheiro"; color: root.themeColors.text; font.family: root.fontFamily; font.pixelSize: 26; font.weight: Font.DemiBold }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "@renanmt"; color: root.themeColors.accent; font.family: root.fontFamily; font.pixelSize: 14 }
                }
            }
            Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: "Version 0.3.2  ·  Made for Omarchy  ·  MIT License"; color: root.themeColors.muted; font.family: root.fontFamily; font.pixelSize: 11 }
        }
    }
    Rectangle { anchors.bottom: parent.bottom; anchors.bottomMargin: 50; width: parent.width; height: 1; color: Qt.alpha(root.themeColors.text, .08) }
    Text {
        x: 30; anchors.bottom: parent.bottom; anchors.bottomMargin: 17; width: parent.width - 60
        text: root.localError || root.error || root.validation[0] || (root.dirty ? "Saving changes…" : root.saved ? "All changes saved." : "Changes save automatically.")
        color: root.localError || root.error || root.validation.length ? "#f07878" : root.saved ? root.themeColors.accent : root.themeColors.muted
        font.family: root.fontFamily; font.pixelSize: 11; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
    }
}
