pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

// Keep the native input permanently read-only: Qt's canPaste update otherwise
// reads foreign clipboard text on dataChanged, even for hidden/unfocused fields.
// Only bounded key-event text is edited here. Never temporarily unset readOnly,
// call paste(), or add an editable TextInput for input-method support.
TextField {
    id: root
    property string value: ""
    property bool numeric: false
    property var undoHistory: []
    property var redoHistory: []
    readOnly: true
    maximumLength: 80
    selectByMouse: true
    activeFocusOnTab: true
    Accessible.description: "Keyboard entry only. Paste and input-method composition are unavailable."
    ToolTip.visible: hovered
    ToolTip.delay: 800
    ToolTip.text: "Type to edit. Pasting is unavailable."

    onValueChanged: syncValue()
    Component.onCompleted: syncValue()
    function syncValue() {
        if (text === value) return;
        text = value;
        undoHistory = []; redoHistory = [];
    }
    onActiveFocusChanged: {
        cursorVisible = activeFocus;
        // Native validators suppress editingFinished for invalid input. Give
        // numeric consumers a chance to restore the saved value on focus loss.
        if (!activeFocus && !acceptableInput) editingFinished();
    }
    function snapshot() { return {text: text, cursor: cursorPosition}; }
    function restore(state) {
        text = state.text;
        cursorPosition = state.cursor;
        textEdited();
    }
    function replaceSelection(replacement) {
        var start = selectionStart, end = selectionEnd;
        var room = maximumLength - (text.length - (end - start));
        replacement = replacement.slice(0, Math.max(0, room));
        // Do not split a UTF-16 surrogate pair at the length limit.
        if (replacement.length && /[\uD800-\uDBFF]/.test(replacement.slice(-1)))
            replacement = replacement.slice(0, -1);
        var next = text.slice(0, start) + replacement + text.slice(end);
        if (next === text || (numeric && !/^-?\d*\.?\d*$/.test(next))) return;
        undoHistory = undoHistory.concat([snapshot()]).slice(-100);
        redoHistory = [];
        text = next;
        cursorPosition = start + replacement.length;
        textEdited();
    }
    function erase(backwards, word) {
        if (selectionStart === selectionEnd) {
            var start = cursorPosition, end = cursorPosition;
            if (word) {
                if (backwards) start -= (text.slice(0, start).match(/\s*\S+\s*$/) || [""])[0].length;
                else end += (text.slice(end).match(/^\s*\S+\s*/) || [""])[0].length;
            } else if (backwards && start > 0) {
                start--;
                if (start > 0 && /[\uDC00-\uDFFF]/.test(text[start]) && /[\uD800-\uDBFF]/.test(text[start - 1])) start--;
            } else if (!backwards && end < text.length) {
                end++;
                if (end < text.length && /[\uD800-\uDBFF]/.test(text[end - 1]) && /[\uDC00-\uDFFF]/.test(text[end])) end++;
            }
            select(start, end);
        }
        replaceSelection("");
    }
    Keys.priority: Keys.BeforeItem
    Keys.onPressed: function(event) {
        var control = !!(event.modifiers & Qt.ControlModifier);
        var shift = !!(event.modifiers & Qt.ShiftModifier);
        if ((control && event.key === Qt.Key_V) || (shift && event.key === Qt.Key_Insert)) {
            event.accepted = true;
        } else if (control && (event.key === Qt.Key_Z || event.key === Qt.Key_Y)) {
            var redo = event.key === Qt.Key_Y || shift;
            var history = redo ? redoHistory : undoHistory;
            if (history.length) {
                var state = history[history.length - 1];
                if (redo) {
                    undoHistory = undoHistory.concat([snapshot()]).slice(-100);
                    redoHistory = redoHistory.slice(0, -1);
                } else {
                    redoHistory = redoHistory.concat([snapshot()]).slice(-100);
                    undoHistory = undoHistory.slice(0, -1);
                }
                restore(state);
            }
            event.accepted = true;
        } else if ((control && event.key === Qt.Key_X) || (shift && event.key === Qt.Key_Delete)) {
            copy();
            replaceSelection("");
            event.accepted = true;
        } else if (event.key === Qt.Key_Backspace || event.key === Qt.Key_Delete) {
            erase(event.key === Qt.Key_Backspace, control);
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (acceptableInput) { editingFinished(); accepted(); }
            event.accepted = true;
        } else if (!(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
                   && event.text.length && !/[\x00-\x1f\x7f]/.test(event.text)) {
            replaceSelection(event.text);
            event.accepted = true;
        } else {
            // Native read-only navigation, selection and copy remain available.
            event.accepted = false;
        }
    }
}
