import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import qs.Commons
import qs.Ui

// Floating quick-capture window, summoned by a Hyprland keybinding via
// `omarchy-shell shell toggle ollywarren.sparks '{}'` — independent of the
// bar. Type or dictate (Omarchy's own dictation types into whatever has
// focus, so the text box just needs to be focused) and hit Ctrl+Enter, or
// simply close the window: any non-empty text is saved as a new idea.
Item {
  id: root

  // Injected by the shell host for overlay plugins, same as the reminders
  // flow: `shell` to report our own dismissal, `manifest` for our id, and
  // `shell.shellConfig` to read the bar entry's settings.
  property var shell: null
  property var manifest: null

  property bool opened: false
  // Set only when the IPC payload names a folder; otherwise the bar entry's
  // `ideasDir` setting wins, so the two halves of the plugin can't drift.
  property string payloadIdeasDir: ""
  property var knownTags: []
  property bool hasVoxtype: false

  readonly property string ideasDir: expandHome(
    payloadIdeasDir !== "" ? payloadIdeasDir
      : (configuredIdeasDir() !== "" ? configuredIdeasDir() : "~/Notes/ideas"))

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

  // The bar widget's own settings block, wherever the user has put the widget.
  // Entries are either a bare id string or an object with inline settings.
  function configuredIdeasDir() {
    var cfg = root.shell ? root.shell.shellConfig : null
    if (!cfg || !cfg.bar || !cfg.bar.layout) return ""
    var sections = ["left", "center", "right"]
    for (var s = 0; s < sections.length; s++) {
      var entries = cfg.bar.layout[sections[s]]
      if (!entries || !entries.length) continue
      for (var i = 0; i < entries.length; i++) {
        var entry = entries[i]
        if (!entry || typeof entry !== "object") continue
        if (String(entry.id || "") !== "ollywarren.sparks") continue
        if (entry.ideasDir) return String(entry.ideasDir)
      }
    }
    return ""
  }

  // ------------------------------------------------------ tag completion
  // The `#word` the cursor is sitting in, or null when it isn't in one.
  function currentTagFragment() {
    var before = editor.text.slice(0, editor.cursorPosition)
    var m = before.match(/#([A-Za-z0-9_-]*)$/)
    return m ? m[1].toLowerCase() : null
  }

  readonly property var tagSuggestions: {
    var fragment = root.tagFragment
    if (fragment === null) return []
    var already = (editor.text.match(/#[A-Za-z0-9_-]+/g) || [])
      .map(function(t) { return t.slice(1).toLowerCase() })
    var out = []
    for (var i = 0; i < root.knownTags.length && out.length < 5; i++) {
      var tag = String(root.knownTags[i].tag || "")
      if (tag.indexOf(fragment) !== 0) continue
      if (fragment !== "" && tag === fragment) continue
      if (already.indexOf(tag) !== -1) continue
      out.push(tag)
    }
    return out
  }

  // Recomputed on every edit and cursor move; a plain property so both the
  // suggestion list and its visibility depend on the same value.
  property var tagFragment: null
  function refreshTagFragment() { root.tagFragment = root.currentTagFragment() }

  function completeTag(tag) {
    var pos = editor.cursorPosition
    var before = editor.text.slice(0, pos)
    var after = editor.text.slice(pos)
    var m = before.match(/#([A-Za-z0-9_-]*)$/)
    if (!m) return
    var start = before.length - m[0].length
    var replacement = "#" + tag + " "
    editor.text = before.slice(0, start) + replacement + after
    editor.cursorPosition = start + replacement.length
    root.refreshTagFragment()
  }

  // ------------------------------------------------------------ lifecycle
  function open(payloadJson) {
    var payload = ({})
    try { payload = JSON.parse(payloadJson || "{}") } catch (e) { payload = ({}) }
    root.payloadIdeasDir = payload.ideasDir ? String(payload.ideasDir) : ""

    editor.text = ""
    root.tagFragment = null
    root.opened = true
    tagsProc.running = true
    Qt.callLater(function() { editor.forceActiveFocus() })
  }

  // Called by the host when it hides us. Must not call back into
  // shell.hide() — that is what dismiss() is for.
  function close() {
    root.opened = false
  }

  function dismiss() {
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "ollywarren.sparks")
  }

  function toggle() {
    if (root.opened) trySaveAndDismiss()
    else root.open("{}")
  }

  // The window goes away at once, but the host is only told after the write
  // finishes: shell.hide() unloads this overlay, and an unloaded overlay takes
  // its running Process with it.
  function trySaveAndDismiss() {
    var text = editor.text
    root.opened = false
    if (text && text.trim().length > 0) saveProc.fire(root.scriptPath, root.ideasDir, text)
    else root.dismiss()
  }

  function toggleDictation() {
    Util.execArgv(["voxtype", "record", "toggle"])
    Qt.callLater(function() { editor.forceActiveFocus() })
  }

  Process {
    id: saveProc
    function fire(scriptPath, dir, text) {
      command = ["bash", scriptPath, "new", dir, text]
      running = true
    }
    stdout: StdioCollector { waitForEnd: true }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var err = String(text || "").trim()
        if (err) console.warn("ollywarren.sparks: save failed:", err)
      }
    }
    onExited: root.dismiss()
  }

  Process {
    id: tagsProc
    command: ["bash", root.scriptPath, "tags", root.ideasDir]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var parsed = JSON.parse(text)
          root.knownTags = Array.isArray(parsed) ? parsed : []
        } catch (e) {
          root.knownTags = []
        }
      }
    }
  }

  Process {
    // Same guard the stock dictation keybinding uses (`o.cmd_present`): no
    // voxtype, no button.
    id: voxtypeProbe
    running: true
    command: ["bash", "-c", "command -v voxtype >/dev/null 2>&1"]
    onExited: function(code) { root.hasVoxtype = code === 0 }
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
      height: Style.space(268)
      radius: root.cornerRadius
      anchors.centerIn: parent
      color: root.background
      borderSpec: Border.surfaceSpec("menu", "border", root.border, Math.max(1, Style.space(2)))
      padding: Style.spacing.panelPadding

      MouseArea { anchors.fill: parent; onClicked: {} }

      Column {
        id: cardColumn
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        spacing: Style.space(8)

        Text {
          id: headerText
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
          height: parent.height - headerText.height - footerRow.height
            - (suggestionRow.visible ? suggestionRow.height + cardColumn.spacing : 0)
            - cardColumn.spacing * 2
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
              onTextChanged: root.refreshTagFragment()
              onCursorPositionChanged: root.refreshTagFragment()

              Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Tab && root.tagSuggestions.length > 0) {
                  root.completeTag(root.tagSuggestions[0])
                  event.accepted = true
                } else if (event.key === Qt.Key_Escape) {
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

        // Tags you have already used, offered while the cursor sits in a
        // `#token`. Tab takes the first one; clicking takes any of them.
        Row {
          id: suggestionRow
          width: parent.width
          spacing: Style.space(6)
          height: visible ? implicitHeight : 0
          visible: root.tagSuggestions.length > 0

          Repeater {
            model: root.tagSuggestions
            delegate: Button {
              required property var modelData
              text: "#" + modelData
              bordered: true
              focusable: false
              foreground: root.foreground
              accent: Color.accent
              fontFamily: root.fontFamily
              fontSize: Style.font.caption
              onClicked: root.completeTag(modelData)
            }
          }
        }

        Item {
          id: footerRow
          width: parent.width
          height: Math.max(hintText.implicitHeight, micButton.visible ? micButton.height : 0)

          Text {
            id: hintText
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: micButton.left
            anchors.rightMargin: Style.space(8)
            textFormat: Text.PlainText
            text: root.tagSuggestions.length > 0
              ? "Tab to complete #" + root.tagSuggestions[0]
              : "Ctrl+Enter or Esc to save · click outside to save & close"
            color: Qt.darker(root.foreground, 1.55)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
          }

          PanelActionButton {
            id: micButton
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: root.hasVoxtype
            iconText: "󰍬"
            tooltipText: "Toggle dictation"
            foreground: Qt.darker(root.foreground, 1.55)
            hoverColor: Color.accent
            fontFamily: root.fontFamily
            onClicked: root.toggleDictation()
          }
        }
      }
    }
  }
}
