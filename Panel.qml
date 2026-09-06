import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Bar widget + popup for browsing logged ideas. The floating quick-capture
// window (Capture.qml) is a separate overlay entry point summoned by a
// keybinding; this panel is read/manage-only: filter by tag, open, delete.
Panel {
  id: root
  moduleName: "ollywarren.sparks"
  ipcTarget: "ollywarren.sparks"

  // ---------------------------------------------------------------- theme
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color accent: Color.accent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // ---------------------------------------------------------------- config
  readonly property string iconGlyph: setting("icon", "✨")
  readonly property int panelWidth: Math.max(280, parseInt(setting("panelWidth", 380), 10) || 380)
  readonly property int maxListItems: Math.max(5, parseInt(setting("maxListItems", 40), 10) || 40)
  readonly property string ideasDirRaw: setting("ideasDir", "~/Notes/ideas")
  readonly property string ideasDir: expandHome(ideasDirRaw)

  function expandHome(path) {
    var home = Quickshell.env("HOME") || ""
    var p = String(path || "")
    if (p === "~") return home
    if (p.indexOf("~/") === 0) return home + p.slice(1)
    return p
  }

  readonly property string scriptPath: String(Qt.resolvedUrl("bin/sparks")).replace(/^file:\/\//, "")

  // ---------------------------------------------------------------- state
  property var ideas: []
  property string activeTag: ""
  property string pendingDeleteFile: ""

  readonly property var tagCounts: computeTagCounts(ideas)
  readonly property var filteredIdeas: activeTag === ""
    ? ideas
    : ideas.filter(function(i) { return i.tags && i.tags.indexOf(activeTag) !== -1 })

  function computeTagCounts(list) {
    var counts = {}
    for (var i = 0; i < list.length; i++) {
      var tags = list[i].tags || []
      for (var j = 0; j < tags.length; j++) counts[tags[j]] = (counts[tags[j]] || 0) + 1
    }
    var out = []
    for (var t in counts) out.push({ tag: t, count: counts[t] })
    out.sort(function(a, b) { return b.count - a.count || a.tag.localeCompare(b.tag) })
    return out
  }

  function relativeTime(mtimeSeconds) {
    var deltaSeconds = Math.max(0, Date.now() / 1000 - mtimeSeconds)
    if (deltaSeconds < 60) return "just now"
    var minutes = Math.floor(deltaSeconds / 60)
    if (minutes < 60) return minutes + "m ago"
    var hours = Math.floor(minutes / 60)
    if (hours < 24) return hours + "h ago"
    var days = Math.floor(hours / 24)
    if (days < 30) return days + "d ago"
    var months = Math.floor(days / 30)
    if (months < 12) return months + "mo ago"
    return Math.floor(months / 12) + "y ago"
  }

  function refresh() {
    if (!listProc.running) listProc.running = true
  }

  function openIdea(file) {
    // Routed through bin/sparks rather than a plain xdg-open: a .md file's
    // detected mimetype here is text/plain, not text/markdown, so xdg-open
    // would hand it to the text/plain default (nvim) instead of whatever
    // markdown app the user actually has set (Omawrite by default). Run as
    // a tracked Process (not execDetached) so a failure lands in the log
    // instead of vanishing silently.
    openProc.command = ["bash", root.scriptPath, "open", file]
    openProc.running = true
  }

  function requestDelete(file) {
    pendingDeleteFile = file
    confirmDialog.opened = true
  }

  function confirmDelete() {
    confirmDialog.opened = false
    if (!pendingDeleteFile) return
    removeProc.command = ["bash", root.scriptPath, "remove", root.ideasDir, pendingDeleteFile]
    removeProc.running = true
    pendingDeleteFile = ""
  }

  function openIdeasFolder() {
    Util.execArgv(["xdg-open", root.ideasDir])
  }

  Process {
    id: openProc
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var err = String(text || "").trim()
        if (err) console.warn("ollywarren.sparks: open failed:", err)
      }
    }
  }

  onOpenedChanged: if (opened) refresh()

  Timer {
    // Catches ideas logged from the capture window (or edited externally)
    // while the panel is sitting open.
    interval: 4000
    running: root.opened
    repeat: true
    onTriggered: root.refresh()
  }

  Process {
    id: listProc
    command: ["bash", root.scriptPath, "list", root.ideasDir]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var parsed = JSON.parse(text)
          root.ideas = (Array.isArray(parsed) ? parsed : []).slice(0, root.maxListItems)
        } catch (e) {
          root.ideas = []
        }
        if (root.activeTag !== "" && root.tagCounts.every(function(t) { return t.tag !== root.activeTag }))
          root.activeTag = ""
      }
    }
  }

  Process {
    id: removeProc
    stdout: StdioCollector { waitForEnd: true }
    onRunningChanged: if (!running) root.refresh()
  }

  // ------------------------------------------------------------- bar face
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.iconGlyph
    tooltipText: "Sparks — " + root.ideas.length + " idea" + (root.ideas.length === 1 ? "" : "s")

    onPressed: function(code) { root.toggle() }
  }

  // ---------------------------------------------------------------- popup
  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(root.panelWidth))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        width: parent.width
        spacing: Style.space(10)

        PanelHero {
          width: parent.width
          title: "Sparks"
          meta: root.activeTag === ""
            ? (root.ideas.length + " idea" + (root.ideas.length === 1 ? "" : "s"))
            : (root.filteredIdeas.length + " of " + root.ideas.length + " · #" + root.activeTag)
          foreground: root.foreground
          fontFamily: root.fontFamily
          iconComponent: Component {
            Text {
              textFormat: Text.PlainText
              text: root.iconGlyph
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
            }
          }
        }

        // ------------------------------------------------------ tag chips
        Flow {
          width: parent.width
          spacing: Style.space(6)
          visible: root.tagCounts.length > 0

          Button {
            text: "All"
            bordered: true
            focusable: true
            selected: root.activeTag === ""
            foreground: root.foreground
            accent: root.accent
            fontFamily: root.fontFamily
            onClicked: root.activeTag = ""
          }

          Repeater {
            model: root.tagCounts
            delegate: Button {
              text: "#" + modelData.tag + " " + modelData.count
              bordered: true
              focusable: true
              selected: root.activeTag === modelData.tag
              foreground: root.foreground
              accent: root.accent
              fontFamily: root.fontFamily
              onClicked: root.activeTag = (root.activeTag === modelData.tag ? "" : modelData.tag)
            }
          }
        }

        PanelSeparator { width: parent.width; visible: root.tagCounts.length > 0 }

        // ------------------------------------------------------------ list
        Text {
          width: parent.width
          visible: root.filteredIdeas.length === 0
          text: root.ideas.length === 0
            ? "No ideas yet — use your capture keybinding to log one."
            : "No ideas with this tag."
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.Wrap
        }

        Flickable {
          id: listFlick
          width: parent.width
          height: Math.min(ideaList.implicitHeight, Style.space(360))
          contentWidth: width
          contentHeight: ideaList.implicitHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          flickableDirection: Flickable.VerticalFlick
          visible: root.filteredIdeas.length > 0

          Column {
            id: ideaList
            width: parent.width
            spacing: Style.space(4)

            Repeater {
              model: root.filteredIdeas
              delegate: Rectangle {
                width: ideaList.width
                height: ideaRow.implicitHeight + Style.space(12)
                radius: Style.cornerRadius
                color: ideaHover.hovered ? Util.alpha(root.foreground, 0.06) : "transparent"

                HoverHandler { id: ideaHover }
                MouseArea {
                  anchors.fill: parent
                  anchors.rightMargin: Style.space(30)
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.openIdea(modelData.file)
                }

                Column {
                  id: ideaRow
                  anchors.left: parent.left
                  anchors.right: deleteButton.left
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.leftMargin: Style.space(6)
                  anchors.rightMargin: Style.space(6)
                  spacing: Style.space(2)

                  Text {
                    width: parent.width
                    textFormat: Text.PlainText
                    text: modelData.title
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                    elide: Text.ElideRight
                  }

                  Text {
                    width: parent.width
                    textFormat: Text.PlainText
                    text: root.relativeTime(modelData.mtime)
                      + (modelData.tags && modelData.tags.length ? "  ·  #" + modelData.tags.join(" #") : "")
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                  }
                }

                Button {
                  id: deleteButton
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.rightMargin: Style.space(4)
                  iconText: "󰆴"
                  tooltipText: "Delete"
                  bordered: false
                  focusable: true
                  foreground: root.dim
                  accent: Color.urgent
                  fontFamily: root.fontFamily
                  onClicked: root.requestDelete(modelData.file)
                }
              }
            }
          }
        }

        PanelSeparator { width: parent.width }

        Row {
          width: parent.width
          spacing: Style.space(8)

          Button {
            text: "Open folder"
            iconText: "󰉋"
            bordered: true
            focusable: true
            foreground: root.foreground
            accent: root.accent
            fontFamily: root.fontFamily
            tooltipText: root.ideasDir
            onClicked: root.openIdeasFolder()
          }
        }
      }

      ConfirmDialog {
        id: confirmDialog
        anchors.fill: parent
        z: 10
        opened: false
        message: "Delete this idea? This can't be undone."
        confirmText: "Delete"
        cancelText: "Cancel"
        foreground: root.foreground
        fontFamily: root.fontFamily
        onCanceled: { confirmDialog.opened = false; root.pendingDeleteFile = "" }
        onConfirmed: root.confirmDelete()
      }
    }
  }
}
