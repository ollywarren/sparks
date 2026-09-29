import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Bar widget + popup for browsing logged ideas. The floating quick-capture
// window (Capture.qml) is a separate overlay entry point summoned by a
// keybinding; this panel is read/manage-only: search, filter, open, hand off
// to the coding agent, archive, delete.
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
  readonly property string projectsDir: expandHome(setting("projectsDir", "~/Work"))

  // Handing an idea to an agent is opt-in: until it is switched on in the
  // settings view, the popup has no Review or Create and never launches one.
  // Once on, the agent starts in plan mode unless the user picks otherwise.
  readonly property bool agentHandoff: {
    var v = setting("agentHandoff", false)
    return v === true || v === "true"
  }
  readonly property string agentMode: {
    var v = String(setting("agentMode", "plan"))
    return (v === "ask" || v === "auto") ? v : "plan"
  }
  property string defaultAgent: ""

  readonly property var modeOptions: [
    { value: "plan", label: "Plan", tooltip: "Read-only: proposes, then waits for your approval" },
    { value: "ask",  label: "Ask",  tooltip: "Prompts before each action" },
    { value: "auto", label: "Auto", tooltip: "Omarchy's auto-approve launch" }
  ]

  function modeLabel(mode) {
    return mode === "auto" ? "Auto-approve" : (mode === "ask" ? "Ask" : "Plan")
  }

  function modeCaption(mode) {
    if (mode === "auto")
      return "The agent acts without asking, as Omarchy launches it by default. Review is still told to change nothing, but nothing enforces it."
    if (mode === "ask")
      return "The agent prompts you before each action it takes."
    return "Read-only. The agent researches and proposes, and changes nothing until you approve."
  }

  function agentName() {
    return root.defaultAgent !== "" ? root.defaultAgent : "your default agent"
  }

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
  property string statusFilter: "active"
  property string query: ""
  // Files whose *body* matched the query, from a debounced grep. Titles and
  // tags are already in `ideas`, so the script only has to answer the part
  // the panel can't.
  property var bodyMatches: []
  property int selectedIndex: -1
  property bool showSettings: false
  // What the confirm dialog is asking about: { kind: "delete" | "review" |
  // "create" | "auto", file }. Nothing it guards runs until it is confirmed.
  property var pendingAction: null

  readonly property var statusOptions: [
    { value: "active",   label: "Active",   tooltip: "New, planned and in progress" },
    { value: "done",     label: "Done" },
    { value: "archived", label: "Archived" },
    { value: "all",      label: "All" }
  ]

  function statusOf(idea) {
    return (idea && idea.status) ? String(idea.status) : "new"
  }

  function statusVisible(status) {
    if (root.statusFilter === "all") return true
    if (root.statusFilter === "done") return status === "done"
    if (root.statusFilter === "archived") return status === "archived"
    return status !== "done" && status !== "archived"
  }

  // A `#token` filters on tags; anything else has to appear in the title or,
  // via the grep, somewhere in the file body. All tokens must match.
  function matchesQuery(idea) {
    var q = root.query.trim().toLowerCase()
    if (q === "") return true
    var tokens = q.split(/\s+/)
    var title = String(idea.title || "").toLowerCase()
    var tags = (idea.tags || []).join(" ").toLowerCase()
    var inBody = root.bodyMatches.indexOf(idea.file) !== -1
    for (var i = 0; i < tokens.length; i++) {
      var t = tokens[i]
      if (t.charAt(0) === "#") {
        if (t.length > 1 && tags.indexOf(t.slice(1)) === -1) return false
      } else if (title.indexOf(t) === -1 && !inBody) {
        return false
      }
    }
    return true
  }

  readonly property var statusScoped: root.ideas.filter(function(i) {
    return root.statusVisible(root.statusOf(i))
  })

  readonly property var filteredIdeas: root.statusScoped.filter(function(i) {
    return (root.activeTag === "" || (i.tags && i.tags.indexOf(root.activeTag) !== -1))
      && root.matchesQuery(i)
  })

  readonly property var tagCounts: computeTagCounts(statusScoped)
  readonly property int newCount: root.ideas.filter(function(i) {
    return root.statusOf(i) === "new"
  }).length

  onFilteredIdeasChanged: {
    if (root.selectedIndex >= root.filteredIdeas.length)
      root.selectedIndex = root.filteredIdeas.length - 1
  }

  onQueryChanged: {
    root.selectedIndex = -1
    searchDebounce.restart()
  }

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

  // ------------------------------------------------------------- actions
  function refresh() {
    if (!listProc.running) listProc.running = true
  }

  // Anything that ends in a long-lived window of its own — the markdown app,
  // the agent's terminal — is launched detached. A Quickshell `Process` owns
  // the PID it spawns, and nothing in these chains forks, so the window ends
  // up wearing that PID: the Process never leaves `running`, and the window
  // dies the moment this widget is torn down for a theme change or a monitor
  // event. Detached costs us the stderr log line, so bin/sparks notifies on
  // the failure paths instead.
  function openIdea(file) {
    // Routed through bin/sparks rather than a plain xdg-open: a .md file's
    // detected mimetype here is text/plain, not text/markdown, so xdg-open
    // would hand it to the text/plain default (nvim) instead of whatever
    // markdown app the user actually has set (Omawrite by default).
    Util.execArgv(["bash", root.scriptPath, "open", file])
  }

  // Quick, self-terminating, and worth knowing the result of, so this one
  // stays a tracked Process — and keeps `actionProc` to itself, so a handoff
  // can never be what stops a status change from happening.
  function setStatus(file, value) {
    if (actionProc.running) return
    actionProc.command = ["bash", root.scriptPath, "set", root.ideasDir, file, "status", value]
    actionProc.running = true
  }

  // The two agent handoffs. bin/sparks assembles the prompt and opens the
  // user's default agent in a terminal, in the chosen mode — so the panel gets
  // out of the way once the process is away. Only reachable from the confirm
  // dialog, and bin/sparks refuses a handoff without --confirmed.
  function reviewIdea(file) {
    if (!root.agentHandoff) return
    Util.execArgv(["bash", root.scriptPath, "review", root.ideasDir, file,
                   "--confirmed", "--mode", root.agentMode])
    root.close()
  }

  function createIdea(file) {
    if (!root.agentHandoff) return
    Util.execArgv(["bash", root.scriptPath, "create", root.ideasDir, file, root.projectsDir,
                   "--confirmed", "--mode", root.agentMode])
    root.close()
  }

  function openProject(dir) {
    Util.execArgv(["xdg-open", dir])
    root.close()
  }

  // The workspace name `sparks create` will use: the file name without its
  // capture timestamp.
  function workspaceFor(file) {
    var base = String(file).split("/").pop().replace(/\.md$/, "")
    var slug = base.replace(/^\d{4}-\d{2}-\d{2}-\d{6}(-\d+)?-/, "")
    return root.projectsDir + "/" + (slug || base)
  }

  function requestAction(kind, file) {
    root.pendingAction = { kind: kind, file: file || "" }
    confirmDialog.opened = true
  }

  function requestDelete(file) { requestAction("delete", file) }

  function confirmMessage() {
    var a = root.pendingAction
    if (!a) return ""
    var mode = root.modeLabel(root.agentMode)
    if (a.kind === "review")
      return "Hand this idea to " + root.agentName() + " in " + mode + " mode? It is given the idea's"
        + " text and your ideas folder, and sends what it reads to that agent's provider."
        + (root.agentMode === "auto"
           ? " In Auto it acts without asking."
           : " It changes nothing on this machine, and writes the brief into this idea file once you approve.")
    if (a.kind === "create")
      return "Create " + root.workspaceFor(a.file) + " (a git repo and a BRIEF.md link to this note) and hand"
        + " it to " + root.agentName() + " in " + mode + " mode? It is given the idea's text, works inside that"
        + " folder, and asks before anything outside it."
    if (a.kind === "auto")
      return "Auto-approve lets the agent run commands, install packages and change settings without asking you first. Use it?"
    return "Delete this idea? This can't be undone."
  }

  function confirmLabel() {
    var kind = root.pendingAction ? root.pendingAction.kind : ""
    if (kind === "review") return "Review"
    if (kind === "create") return "Create"
    if (kind === "auto") return "Use auto"
    return "Delete"
  }

  function confirmPending() {
    confirmDialog.opened = false
    var a = root.pendingAction
    root.pendingAction = null
    if (!a) return
    if (a.kind === "review") root.reviewIdea(a.file)
    else if (a.kind === "create") root.createIdea(a.file)
    else if (a.kind === "auto") root.writeSetting("agentMode", "auto", false)
    else if (a.kind === "delete") {
      removeProc.command = ["bash", root.scriptPath, "remove", root.ideasDir, a.file]
      removeProc.running = true
    }
  }

  function cancelPending() {
    confirmDialog.opened = false
    root.pendingAction = null
  }

  // Settings are written the way `omarchy bar set` writes them — onto this
  // widget's entry in shell.json, which hot-reloads back into setting(). Only
  // ever called from a control the user has just operated.
  function writeSetting(key, value, isJson) {
    var argv = ["omarchy-bar", "set", root.moduleName, key, String(value)]
    if (isJson) argv.push("--json")
    settingsQueue.push(argv)
    root.drainSettings()
  }

  property var settingsQueue: []
  function drainSettings() {
    if (settingsProc.running || settingsQueue.length === 0) return
    settingsProc.command = settingsQueue.shift()
    settingsProc.running = true
  }

  function requestMode(mode) {
    if (mode === root.agentMode) return
    // Moving to auto takes away the agent's own prompts, so it asks first;
    // plan and ask only ever make the agent more careful.
    if (mode === "auto") root.requestAction("auto", "")
    else root.writeSetting("agentMode", mode, false)
  }

  function applyFolder(key, field, current) {
    var v = field.text.trim()
    if (v === "" || v === current) { field.text = current; return }
    root.writeSetting(key, v, false)
  }

  function openIdeasFolder() {
    Util.execArgv(["xdg-open", root.ideasDir])
  }

  function moveSelection(delta) {
    var n = root.filteredIdeas.length
    if (n === 0) {
      root.selectedIndex = -1
      return
    }
    var next = root.selectedIndex < 0 ? (delta > 0 ? 0 : n - 1) : root.selectedIndex + delta
    root.selectedIndex = Math.max(0, Math.min(n - 1, next))
    listView.positionViewAtIndex(root.selectedIndex, ListView.Contain)
  }

  function selectedIdea() {
    if (root.selectedIndex < 0 || root.selectedIndex >= root.filteredIdeas.length) return null
    return root.filteredIdeas[root.selectedIndex]
  }

  function runBodySearch() {
    var q = root.query.trim()
    if (q.length < 2) {
      root.bodyMatches = []
      return
    }
    if (searchProc.running) {
      searchDebounce.restart()
      return
    }
    searchProc.fire(q)
  }

  // ------------------------------------------------------------ processes
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

  // The query goes down stdin for the same reason the captured idea does: what
  // the user typed would otherwise sit in a world-readable process line.
  Process {
    id: searchProc
    property string pending: ""
    function fire(query) {
      pending = query
      stdinEnabled = true
      command = ["bash", root.scriptPath, "search", root.ideasDir]
      running = true
    }
    onStarted: {
      write(pending)
      pending = ""
      stdinEnabled = false
    }
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var parsed = JSON.parse(text)
          root.bodyMatches = Array.isArray(parsed) ? parsed : []
        } catch (e) {
          root.bodyMatches = []
        }
      }
    }
  }

  Process {
    id: actionProc
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var err = String(text || "").trim()
        if (err) console.warn("ollywarren.sparks: status change failed:", err)
      }
    }
    onRunningChanged: if (!running) root.refresh()
  }

  Process {
    id: removeProc
    stdout: StdioCollector { waitForEnd: true }
    onRunningChanged: if (!running) root.refresh()
  }

  Process {
    id: settingsProc
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var err = String(text || "").trim()
        if (err) console.warn("ollywarren.sparks: saving a setting failed:", err)
      }
    }
    onRunningChanged: if (!running) root.drainSettings()
  }

  // Only to name the agent in the confirm dialog; bin/sparks reads it again
  // at launch, so a stale name here can't change what runs.
  Process {
    id: agentProc
    command: ["omarchy-default-agent"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.defaultAgent = String(text || "").trim()
    }
  }

  Timer {
    id: searchDebounce
    interval: 250
    onTriggered: root.runBodySearch()
  }

  onOpenedChanged: {
    if (opened) {
      searchField.text = ""
      root.query = ""
      root.bodyMatches = []
      root.selectedIndex = -1
      root.showSettings = false
      refresh()
      if (!agentProc.running) agentProc.running = true
    }
  }

  Timer {
    // Catches ideas logged from the capture window (or edited externally)
    // while the panel is sitting open.
    interval: 4000
    running: root.opened
    repeat: true
    onTriggered: root.refresh()
  }

  // ------------------------------------------------------------- bar face
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.iconGlyph
    // Lit while anything is still unreviewed, so a captured idea is visible
    // without opening the popup.
    active: root.newCount > 0
    tooltipText: "Sparks — " + root.ideas.length + " idea" + (root.ideas.length === 1 ? "" : "s")
      + (root.newCount > 0 ? " · " + root.newCount + " new" : "")

    onPressed: function(code) { root.toggle() }
  }

  // ---------------------------------------------------------------- popup
  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: searchField
    contentWidth: panel.fittedContentWidth(Style.space(root.panelWidth))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      // The search field owns the keyboard while it has focus — otherwise the
      // catcher would eat h/j/k/l and x before they reached the text box.
      blocked: searchField.activeFocus || ideasDirField.activeFocus || projectsDirField.activeFocus
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        width: parent.width
        spacing: Style.space(10)

        PanelHero {
          width: parent.width
          title: "Sparks"
          meta: root.showSettings
            ? "Settings"
            : root.filteredIdeas.length === root.ideas.length
              ? (root.ideas.length + " idea" + (root.ideas.length === 1 ? "" : "s"))
              : (root.filteredIdeas.length + " of " + root.ideas.length
                 + (root.activeTag === "" ? "" : " · #" + root.activeTag))
          trailingControl: Component {
            PanelActionButton {
              iconText: root.showSettings ? "󰁍" : "󰒓"
              tooltipText: root.showSettings ? "Back to ideas" : "Settings"
              foreground: root.dim
              hoverColor: root.accent
              fontFamily: root.fontFamily
              onClicked: root.showSettings = !root.showSettings
            }
          }
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

        // The list and the settings share the popup; one shows at a time.
        Column {
          id: listPage
          width: parent.width
          spacing: Style.space(10)
          visible: !root.showSettings

          // -------------------------------------------------------- search
          TextField {
            id: searchField
            width: parent.width
            placeholderText: "Search ideas… #tag to filter"
            foreground: root.foreground
            accent: root.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall

            onTextChanged: root.query = text

            Keys.priority: Keys.BeforeItem
            Keys.onPressed: function(event) {
              if (event.key === Qt.Key_Escape) {
                // First Esc clears a query, second closes — the clipboard
                // panel's behaviour, and the one people expect from a filter.
                if (searchField.text !== "") searchField.text = ""
                else root.close()
                event.accepted = true
              } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                root.switchPanel((event.modifiers & Qt.ShiftModifier)
                  || event.key === Qt.Key_Backtab ? -1 : 1)
                event.accepted = true
              } else if (event.key === Qt.Key_Down) {
                root.moveSelection(1)
                event.accepted = true
              } else if (event.key === Qt.Key_Up) {
                root.moveSelection(-1)
                event.accepted = true
              } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                var idea = root.selectedIdea()
                if (idea) root.openIdea(idea.file)
                event.accepted = true
              } else if (event.key === Qt.Key_Delete && (event.modifiers & Qt.ShiftModifier)) {
                var target = root.selectedIdea()
                if (target) root.requestDelete(target.file)
                event.accepted = true
              }
            }
          }

          // ------------------------------------------------- status filter
          ButtonGroup {
            width: parent.width
            options: root.statusOptions
            value: root.statusFilter
            foreground: root.foreground
            accent: root.accent
            fontFamily: root.fontFamily
            fontSize: Style.font.bodySmall
            focusable: false
            onChanged: function(value) {
              root.statusFilter = value
              root.selectedIndex = -1
            }
          }

          // ---------------------------------------------------- tag chips
          Flow {
            width: parent.width
            spacing: Style.space(6)
            visible: root.tagCounts.length > 0

            Button {
              text: "All"
              bordered: true
              focusable: false
              selected: root.activeTag === ""
              foreground: root.foreground
              accent: root.accent
              fontFamily: root.fontFamily
              onClicked: root.activeTag = ""
            }

            Repeater {
              model: root.tagCounts
              delegate: Button {
                required property var modelData
                text: "#" + modelData.tag + " " + modelData.count
                bordered: true
                focusable: false
                selected: root.activeTag === modelData.tag
                foreground: root.foreground
                accent: root.accent
                fontFamily: root.fontFamily
                onClicked: root.activeTag = (root.activeTag === modelData.tag ? "" : modelData.tag)
              }
            }
          }

          PanelSeparator { width: parent.width; visible: root.tagCounts.length > 0 }

          // ---------------------------------------------------------- list
          Text {
            width: parent.width
            visible: root.filteredIdeas.length === 0
            text: root.ideas.length === 0
              ? "No ideas yet — use your capture keybinding to log one."
              : "Nothing matches these filters."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.Wrap
          }

          ListView {
            id: listView
            width: parent.width
            height: Math.min(contentHeight, Style.space(360))
            model: root.filteredIdeas
            spacing: Style.space(4)
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            visible: root.filteredIdeas.length > 0

            delegate: Rectangle {
              id: row
              required property var modelData
              required property int index

              readonly property string rowStatus: root.statusOf(modelData)
              readonly property bool selected: root.selectedIndex === index
              readonly property bool showActions: ideaHover.hovered || selected

              width: ListView.view.width
              height: ideaRow.implicitHeight + Style.space(12)
              radius: Style.cornerRadius
              color: selected
                ? Style.selectedFillFor(root.foreground, root.accent)
                : (ideaHover.hovered ? Util.alpha(root.foreground, 0.06) : "transparent")

              HoverHandler { id: ideaHover }
              MouseArea {
                anchors.fill: parent
                anchors.rightMargin: row.showActions ? actions.width + Style.space(8) : 0
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.selectedIndex = row.index
                  root.openIdea(row.modelData.file)
                }
              }

              Column {
                id: ideaRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Style.space(6)
                // The action cluster only reserves room while it is showing, so
                // a resting row gets the full width for its title.
                anchors.rightMargin: Style.space(6)
                  + (row.showActions ? actions.width + Style.space(4) : 0)
                spacing: Style.space(2)

                Text {
                  width: parent.width
                  textFormat: Text.PlainText
                  text: row.modelData.title
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  elide: Text.ElideRight
                }

                Text {
                  width: parent.width
                  textFormat: Text.PlainText
                  text: root.relativeTime(row.modelData.mtime)
                    + (row.rowStatus === "new" ? "" : "  ·  " + row.rowStatus)
                    + (row.modelData.tags && row.modelData.tags.length
                       ? "  ·  #" + row.modelData.tags.join(" #") : "")
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                }
              }

              // Revealed on hover or when the row is the keyboard selection, so
              // a 380px row isn't permanently five icons wide.
              Row {
                id: actions
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: Style.space(4)
                spacing: Style.space(2)
                visible: row.showActions

                PanelActionButton {
                  visible: root.agentHandoff
                  iconText: "󰧑"
                  tooltipText: (row.rowStatus === "new"
                    ? "Research this into a brief with your agent"
                    : "Re-review with your agent") + " · " + root.modeLabel(root.agentMode)
                  foreground: root.dim
                  hoverColor: root.accent
                  fontFamily: root.fontFamily
                  onClicked: root.requestAction("review", row.modelData.file)
                }

                PanelActionButton {
                  visible: root.agentHandoff && row.modelData.project === "" && row.rowStatus === "planned"
                  iconText: "󰐊"
                  tooltipText: "Create it — a workspace, and your agent to start in it · " + root.modeLabel(root.agentMode)
                  foreground: root.dim
                  hoverColor: root.accent
                  fontFamily: root.fontFamily
                  onClicked: root.requestAction("create", row.modelData.file)
                }

                PanelActionButton {
                  visible: root.agentHandoff && row.modelData.project !== ""
                  iconText: "󰝰"
                  tooltipText: "Open " + row.modelData.project
                  foreground: root.dim
                  hoverColor: root.accent
                  fontFamily: root.fontFamily
                  onClicked: root.openProject(row.modelData.project)
                }

                PanelActionButton {
                  visible: row.rowStatus !== "done" && row.rowStatus !== "archived"
                  iconText: "󰗠"
                  tooltipText: "Mark done"
                  foreground: root.dim
                  hoverColor: root.accent
                  fontFamily: root.fontFamily
                  onClicked: root.setStatus(row.modelData.file, "done")
                }

                PanelActionButton {
                  iconText: row.rowStatus === "archived" ? "󰑐" : "󱉙"
                  tooltipText: row.rowStatus === "archived" ? "Restore" : "Archive"
                  foreground: root.dim
                  hoverColor: root.accent
                  fontFamily: root.fontFamily
                  onClicked: root.setStatus(row.modelData.file,
                    row.rowStatus === "archived" ? "new" : "archived")
                }

                PanelActionButton {
                  iconText: "󰆴"
                  tooltipText: "Delete"
                  foreground: root.dim
                  hoverColor: Color.urgent
                  fontFamily: root.fontFamily
                  onClicked: root.requestDelete(row.modelData.file)
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
              focusable: false
              foreground: root.foreground
              accent: root.accent
              fontFamily: root.fontFamily
              tooltipText: root.ideasDir
              onClicked: root.openIdeasFolder()
            }
          }
        }

        // -------------------------------------------------------- settings
        // Everything that decides what Sparks may do on this machine, in one
        // place. Each control writes its own key the moment it is operated;
        // nothing here is saved on the user's behalf.
        Column {
          id: settingsPage
          width: parent.width
          spacing: Style.space(10)
          visible: root.showSettings

          PanelSeparator { width: parent.width }
          PanelSectionHeader {
            text: "AGENT HANDOFF"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Item {
            width: parent.width
            implicitHeight: Math.max(handoffText.implicitHeight, handoffSwitch.implicitHeight)

            Column {
              id: handoffText
              anchors.left: parent.left
              anchors.right: handoffSwitch.left
              anchors.rightMargin: Style.space(10)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Text {
                width: parent.width
                textFormat: Text.PlainText
                text: "Review and Create"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
              }
              Text {
                width: parent.width
                textFormat: Text.PlainText
                text: root.agentHandoff
                  ? "Open " + root.agentName() + " in a terminal, after you confirm each one."
                  : "Off. Sparks only captures, lists, searches and opens ideas."
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.Wrap
              }
            }

            ToggleSwitch {
              id: handoffSwitch
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              checked: root.agentHandoff
              busy: settingsProc.running
              foreground: root.foreground
              accent: root.accent
              onToggled: root.writeSetting("agentHandoff", root.agentHandoff ? "false" : "true", true)
            }
          }

          Text {
            width: parent.width
            textFormat: Text.PlainText
            text: "Mode"
            color: root.agentHandoff ? root.foreground : root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }

          ButtonGroup {
            width: parent.width
            enabled: root.agentHandoff
            opacity: enabled ? 1 : 0.5
            options: root.modeOptions
            value: root.agentMode
            foreground: root.foreground
            accent: root.accent
            fontFamily: root.fontFamily
            fontSize: Style.font.bodySmall
            focusable: false
            onChanged: function(value) { root.requestMode(value) }
          }

          Text {
            width: parent.width
            textFormat: Text.PlainText
            text: root.modeCaption(root.agentMode)
            color: root.agentMode === "auto" && root.agentHandoff ? Color.urgent : root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.Wrap
          }

          Text {
            width: parent.width
            textFormat: Text.PlainText
            visible: root.agentHandoff
            text: "Each handoff opens " + root.agentName() + " in a terminal you can watch. It is given the "
              + "idea's text, your ideas folder and the skill to follow, and sends what it reads to that "
              + "agent's provider. Sparks makes no network calls itself and runs nothing in the background."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.Wrap
          }

          PanelSeparator { width: parent.width }
          PanelSectionHeader {
            text: "FOLDERS"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Text {
            width: parent.width
            textFormat: Text.PlainText
            text: "Ideas"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
          TextField {
            id: ideasDirField
            width: parent.width
            text: root.ideasDirRaw
            foreground: root.foreground
            accent: root.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            onAccepted: root.applyFolder("ideasDir", ideasDirField, root.ideasDirRaw)
            Keys.onEscapePressed: { text = root.ideasDirRaw; focus = false }
          }

          Text {
            width: parent.width
            textFormat: Text.PlainText
            text: "Workspaces (where Create scaffolds)"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
          TextField {
            id: projectsDirField
            width: parent.width
            text: root.setting("projectsDir", "~/Work")
            foreground: root.foreground
            accent: root.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            onAccepted: root.applyFolder("projectsDir", projectsDirField, root.setting("projectsDir", "~/Work"))
            Keys.onEscapePressed: { text = root.setting("projectsDir", "~/Work"); focus = false }
          }

          Text {
            width: parent.width
            textFormat: Text.PlainText
            text: "Press Enter to save a folder. Each control here writes its own key to this widget's entry "
              + "in ~/.config/omarchy/shell.json the moment you use it. Sparks changes nothing there on its own."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.Wrap
          }
        }
      }

      ConfirmDialog {
        id: confirmDialog
        anchors.fill: parent
        z: 10
        opened: false
        message: root.confirmMessage()
        confirmText: root.confirmLabel()
        cancelText: "Cancel"
        foreground: root.foreground
        fontFamily: root.fontFamily
        onCanceled: root.cancelPending()
        onConfirmed: root.confirmPending()
      }
    }
  }
}
