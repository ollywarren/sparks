import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import qs.Commons
import qs.Ui

// Floating quick-capture window, summoned by a Hyprland keybinding via
// `omarchy-shell shell toggle ollywarren.sparks '{}'` — independent of the
// bar. Type or dictate (Omarchy's own dictation toggle types into whatever
// has focus, so the text box just needs to be focused) and hit Ctrl+Enter,
// or simply close the window: any non-empty text is saved as a new idea.
Item {
  id: root

  property bool opened: false
  property string ideasDir: expandHome("~/Notes/ideas")

  readonly property color background: Color.menu.background
  readonly property color foreground: Color.menu.text
  readonly property color border: Color.menu.border
  readonly property color scrim: Color.menu.scrim
  readonly property string fontFamily: Style.font.family
  readonly property int cornerRadius: Style.cornerRadius

  readonly property string scriptPath: String(Qt.resolvedUrl("bin/sparks")).replace(/^file:\/\//, "")

  function expandHome(path) {
    var home = Quickshell.env("HOME") || ""
    var p = String(path || "")
    if (p === "~") return home
    if (p.indexOf("~/") === 0) return home + p.slice(1)
    return p
  }

  function open(payloadJson) {
    var payload = ({})
    try { payload = JSON.parse(payloadJson || "{}") } catch (e) { payload = ({}) }
    if (payload.ideasDir) root.ideasDir = expandHome(payload.ideasDir)

    editor.text = ""
    root.opened = true
    Qt.callLater(function() { editor.forceActiveFocus() })
  }

  function close() {
    root.opened = false
  }

  function toggle() {
    if (root.opened) trySaveAndDismiss()
    else root.open("{}")
  }

  function trySaveAndDismiss() {
    var text = editor.text
    if (text && text.trim().length > 0) saveProc.fire(root.scriptPath, root.ideasDir, text)
    root.opened = false
  }

  Process {
    id: saveProc
    function fire(scriptPath, dir, text) {
      command = ["bash", scriptPath, "new", dir, text]
      running = true
    }
    stdout: StdioCollector { waitForEnd: true }
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-sparks-capture"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.trySaveAndDismiss()
    }

    BorderSurface {
      id: card
      width: Math.min(Style.space(520), panel.width - Style.gapsOut * 2)
      height: Style.space(240)
      radius: root.cornerRadius
      anchors.centerIn: parent
      color: root.background
      borderSpec: Border.surfaceSpec("menu", "border", root.border, Math.max(1, Style.space(2)))
      padding: Style.spacing.panelPadding

      MouseArea { anchors.fill: parent; onClicked: {} }

      Column {
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        spacing: Style.space(8)

        Text {
          textFormat: Text.PlainText
          text: "New idea"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.heading
          font.bold: true
        }

        BorderSurface {
          id: editorSurface
          width: parent.width
          height: parent.height - Style.space(60)
          radius: Style.cornerRadius
          padding: Style.spacing.md
          color: Style.controlFill(editor.activeFocus, false, root.foreground, Color.accent)
          borderSpec: Border.controlSpec(editor.activeFocus ? "focus" : "normal", root.foreground, Color.accent)

          Flickable {
            id: editorFlick
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.topMargin: editorSurface.contentTopInset
            anchors.leftMargin: editorSurface.contentLeftInset
            anchors.rightMargin: editorSurface.contentRightInset
            anchors.bottomMargin: editorSurface.contentBottomInset
            contentWidth: width
            contentHeight: Math.max(height, editor.implicitHeight)
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick

            function ensureCursorVisible() {
              var y = editor.cursorRectangle.y
              var h = editor.cursorRectangle.height
              if (y < contentY) contentY = y
              else if (y + h > contentY + height) contentY = y + h - height
            }

            TextEdit {
              id: editor
              width: editorFlick.width
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: TextEdit.Wrap
              textFormat: TextEdit.PlainText
              selectByMouse: true
              selectByKeyboard: true
              activeFocusOnPress: true
              focus: true

              onCursorRectangleChanged: editorFlick.ensureCursorVisible()

              Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                  root.trySaveAndDismiss()
                  event.accepted = true
                } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                           && (event.modifiers & Qt.ControlModifier)) {
                  root.trySaveAndDismiss()
                  event.accepted = true
                }
              }
            }

            Text {
              anchors.top: parent.top
              anchors.left: parent.left
              visible: editor.text.length === 0
              text: "Type or dictate an idea… #tag anywhere to categorize it."
              color: Qt.darker(root.foreground, 1.55)
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.Wrap
              width: editorFlick.width
            }
          }
        }

        Text {
          textFormat: Text.PlainText
          text: "Ctrl+Enter or Esc to save · click outside to save & close"
          color: Qt.darker(root.foreground, 1.55)
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }
  }
}
