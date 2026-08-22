//@ pragma UseQApplication

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import Quickshell.Widgets

ShellRoot {
  id: root

  // Seele's native desktop shell.
  property color base: "#1e1e2e"
  property color mantle: "#181825"
  property color surface: "#313244"
  property color overlay: "#6c7086"
  property color text: "#cdd6f4"
  property color subtext: "#a6adc8"
  property color accent: "#b4befe"
  property color red: "#f38ba8"
  property color green: "#a6e3a1"
  property color yellow: "#f9e2af"
  property string fontFamily: "Maple Mono NF CN"
  // iOS-style privacy indicator colours, deliberately outside the theme palette.
  property color iosOrange: "#ff9f0a"
  property color iosGreen: "#30d158"
  property color iosRed: "#ff453a"
  property string wallpaper: Quickshell.env("SEELE_SHELL_WALLPAPER") || "/etc/wallpaper/wallpaper.jpg"

  property bool agentsOpen: false
  property string controlPanel: ""
  property bool trayMenuOpen: false
  property bool trayExpanded: false
  property int volumeDrag: -1
  property int microphoneDrag: -1
  property bool agentUsageOpen: false
  property bool agentModelsOpen: false
  property bool notificationHistoryOpen: false
  property var activeTrayItem: null
  property bool osdOpen: false
  property string osdKind: "volume"
  property bool airpodsOsdConnected: false
  property string airpodsOsdName: "AirPods"
  property var yubikeyTouchSources: ({})
  property bool yubikeyTouchRequired: false
  property bool statusInitialized: false
  property int windowsCountdown: -1
  property var agentData: ({
    subscriptions: [],
    local: { today: {}, daily: [], models: [], totalTokens: 0, totalCost: 0 },
    launchers: []
  })
  property var systemData: ({
    volume: 0,
    muted: false,
    microphoneVolume: 0,
    microphoneMuted: false,
    microphoneActive: false,
    connection: "Disconnected",
    connectionType: "",
    connectivity: "unknown",
    wifiEnabled: false,
    wifiAvailable: false,
    ipAddress: "",
    gateway: "",
    bluetoothAvailable: false,
    bluetoothPowered: false,
    bluetoothConnected: 0,
    bluetoothScanning: false,
    bluetoothDevices: [],
    airpodsConnected: false,
    airpodsName: "",
    voxtypeStatus: "unavailable",
    cameraDevices: [],
    cameraDevice: "",
    cameraActive: false,
    screenRecording: false,
    audioDevices: [],
    batteries: [],
    trayHidden: [],
    airpodsEarDetection: true,
    agentStates: {},
    notifications: { count: 0, items: [], history: [] },
    dnd: false
  })
  property bool agentRefreshing: false
  property string bluetoothBusy: ""
  property string bluetoothForget: ""
  property string agentError: ""
  property date now: new Date()

  function alpha(color, opacity) {
    return Qt.rgba(color.r, color.g, color.b, opacity)
  }

  function focusedScreen(screen) {
    return !Hyprland.focusedMonitor || Hyprland.focusedMonitor.name === screen.name
  }

  function closeTrayMenu() {
    trayMenuOpen = false
    activeTrayItem = null
  }

  function closeOverlays() {
    agentsOpen = false
    controlPanel = ""
    closeTrayMenu()
    windowsCountdown = -1
    windowsTimer.stop()
    bluetoothForget = ""
    notificationHistoryOpen = false
    bluetoothForgetTimer.stop()
  }

  function toggleLauncher(mode) {
    closeOverlays()
    Quickshell.execDetached(["vicinae", "toggle"])
  }

  function toggleAgents() {
    var shouldOpen = !agentsOpen
    closeOverlays()
    agentsOpen = shouldOpen
    if (agentsOpen && (!agentData.generatedAt || agentError !== "")) refreshAgents()
  }

  function toggleControl(panel) {
    var shouldOpen = controlPanel !== panel
    closeOverlays()
    controlPanel = shouldOpen ? panel : ""
    if (controlPanel !== "") refreshStatus()
  }

  function toggleControls() {
    toggleControl("system")
  }

  function refreshAgents() {
    if (!agentProcess.running) {
      agentRefreshing = true
      agentError = ""
      agentProcess.running = true
    }
  }

  function refreshStatus() {
    if (!statusProcess.running) statusProcess.running = true
  }

  function parseAgentData(output) {
    try {
      var parsed = JSON.parse(String(output || ""))
      if (!parsed || !parsed.subscriptions) throw new Error("missing subscription data")
      agentData = parsed
      agentError = ""
    } catch (error) {
      agentError = String(error)
    }
  }

  function parseSystemData(output) {
    try {
      var parsed = JSON.parse(String(output || ""))
      if (parsed) {
        if (root.statusInitialized && !!parsed.airpodsConnected !== !!root.systemData.airpodsConnected) {
          root.airpodsOsdConnected = !!parsed.airpodsConnected
          root.airpodsOsdName = String(parsed.airpodsName || root.systemData.airpodsName || "AirPods")
          root.showTimedOsd("airpods")
        }
        systemData = parsed
        root.statusInitialized = true
        root.volumeDrag = -1
        root.microphoneDrag = -1
      }
    } catch (error) {
      console.warn("seele-shell/status", error)
    }
  }

  function formatTokens(value) {
    var count = Number(value || 0)
    if (count >= 1000000000) return (count / 1000000000).toFixed(1) + "B"
    if (count >= 1000000) return (count / 1000000).toFixed(1) + "M"
    if (count >= 1000) return (count / 1000).toFixed(0) + "K"
    return String(Math.round(count))
  }

  function resetText(value) {
    if (!value) return ""
    var reset = new Date(value)
    var delta = reset.getTime() - now.getTime()
    if (!(delta > 0)) return "now"
    var minutes = Math.floor(delta / 60000)
    var hours = Math.floor(minutes / 60)
    var days = Math.floor(hours / 24)
    if (days > 0) return days + "d " + (hours % 24) + "h"
    if (hours > 0) return hours + "h " + (minutes % 60) + "m"
    return Math.max(1, minutes) + "m"
  }

  function workspaceIds(screen) {
    var ids = []
    var values = Hyprland.workspaces.values || []
    for (var i = 0; i < values.length; i++) {
      var workspace = values[i]
      var onScreen = workspace.monitor && screen && workspace.monitor.name === screen.name
      var occupied = workspace.toplevels && workspace.toplevels.values.length > 0
      if (workspace.id > 0 && onScreen && (workspace.active || occupied)) ids.push(workspace.id)
    }
    ids.sort(function(a, b) { return a - b })
    return ids
  }

  function workspaceActive(id, screen) {
    var values = Hyprland.workspaces.values || []
    for (var i = 0; i < values.length; i++) {
      var workspace = values[i]
      if (workspace.id === id && workspace.active && (!workspace.monitor || !screen || workspace.monitor.name === screen.name)) return true
    }
    return false
  }

  function workspaceOccupied(id) {
    var values = Hyprland.workspaces.values || []
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i].toplevels.values.length > 0
    }
    return false
  }

  function activeWindow(screen) {
    var monitors = Hyprland.monitors.values || []
    for (var i = 0; i < monitors.length; i++) {
      var monitor = monitors[i]
      if (screen && monitor.name === screen.name && monitor.activeWorkspace) {
        var windows = monitor.activeWorkspace.toplevels.values || []
        if (monitor.focused && Hyprland.activeToplevel && windowTitle(Hyprland.activeToplevel) !== "") return Hyprland.activeToplevel
        for (var j = 0; j < windows.length; j++) {
          if (windowTitle(windows[j]) !== "") return windows[j]
        }
        return null
      }
    }
    return null
  }

  function windowTitle(window) {
    if (!window) return ""
    var ipc = window.lastIpcObject || {}
    return String(ipc.title || window.title || "")
  }

  function windowIcon(window) {
    if (!window) return ""
    var ipc = window.lastIpcObject || {}
    var appId = String(ipc.class || ipc.initialClass || window.appId || "").toLowerCase()
    var entries = DesktopEntries.applications.values || []
    for (var i = 0; i < entries.length; i++) {
      var id = String(entries[i].id || "").toLowerCase().replace(/\.desktop$/, "")
      if (id === appId || appId.indexOf(id) >= 0 || id.indexOf(appId) >= 0) return entries[i].icon
    }
    return ""
  }

  function spotifyPlayer() {
    var players = Mpris.players.values || []
    for (var i = 0; i < players.length; i++) {
      if (players[i].isPlaying && String(players[i].identity || players[i].desktopEntry || "").toLowerCase().indexOf("spotify") >= 0) return players[i]
    }
    return null
  }

  function devicePlayer() {
    var players = Mpris.players.values || []
    for (var i = 0; i < players.length; i++) {
      var spotify = String(players[i].identity || players[i].desktopEntry || "").toLowerCase().indexOf("spotify") >= 0
      if (players[i].isPlaying && !spotify) return players[i]
    }
    for (var j = 0; j < players.length; j++) {
      if (players[j].isPlaying) return players[j]
    }
    return null
  }

  function agentStatus(id) {
    var states = systemData.agentStates || {}
    return states[id] ? String(states[id].status || "idle") : "idle"
  }

  function bluetoothDevices() {
    return root.systemData.bluetoothPowered ? (root.systemData.bluetoothDevices || []) : []
  }

  function bluetoothIcon(device) {
    var icon = String(device && device.icon || "")
    var name = String(device && device.name || "").toLowerCase()
    if (icon.indexOf("headset") >= 0 || icon.indexOf("headphone") >= 0 || /airpod|buds|headphone|headset|beats|wh-|wf-/.test(name)) return "󰋋"
    if (icon.indexOf("speaker") >= 0 || icon === "audio-card" || /speaker|soundcore|boom|jbl|sonos/.test(name)) return "󰓃"
    if (icon === "input-keyboard" || /keyboard|keychron|k[0-9]+ /.test(name)) return "󰌌"
    if (icon === "input-mouse" || /mouse|mx master/.test(name)) return "󰍽"
    if (icon === "input-gaming" || /controller|gamepad|dualsense|xbox/.test(name)) return "󰊴"
    if (icon === "phone" || /phone|pixel|galaxy|iphone/.test(name)) return "󰄜"
    if (icon === "computer" || /macbook|thinkpad|laptop/.test(name)) return "󰌢"
    if (icon === "video-display" || /\[tv\]|fernseher|television/.test(name)) return "󰔂"
    if (icon === "printer") return "󰐪"
    if (/watch|band/.test(name)) return "󰖐"
    return "󰂱"
  }

  function bluetoothDetail(device) {
    if (!device) return ""
    if (root.bluetoothForget === device.address) return "Tap again to forget"
    if (root.bluetoothBusy === device.address) return device.connected ? "Disconnecting…" : device.paired ? "Connecting…" : "Pairing…"
    var suffix = device.trusted ? " · auto" : ""
    if (device.connected) return "Connected" + suffix
    if (device.paired) return "Paired" + suffix
    return "Available"
  }

  function bluetoothSignal(device) {
    if (!device || device.connected) return ""
    if (device.battery !== null && device.battery !== undefined) return device.battery + "%"
    if (device.rssi === null || device.rssi === undefined) return ""
    if (device.rssi >= -60) return "󰤨"
    if (device.rssi >= -75) return "󰤥"
    return "󰤟"
  }

  function toggleBluetoothDevice(device) {
    if (!device || !device.address) return
    root.bluetoothForget = ""
    bluetoothForgetTimer.stop()
    root.runBluetooth(device.connected ? "disconnect" : "connect", device.address)
  }

  function runBluetooth(command, value) {
    if (bluetoothProcess.running) return
    if (command !== "scan") root.bluetoothBusy = String(value)
    bluetoothProcess.command = ["seele-control", "bluetooth", String(command), String(value)]
    bluetoothProcess.running = true
  }

  function forgetBluetoothDevice(device) {
    if (!device || !device.address) return
    if (root.bluetoothForget !== device.address) {
      root.bluetoothForget = device.address
      bluetoothForgetTimer.restart()
      return
    }
    root.bluetoothForget = ""
    bluetoothForgetTimer.stop()
    root.runBluetooth("forget", device.address)
  }

  function trayHiddenIds() {
    return root.systemData.trayHidden || []
  }

  function trayItemHidden(item) {
    return !!item && root.trayHiddenIds().indexOf(String(item.id)) >= 0
  }

  function trayItems() {
    var items = SystemTray.items.values || []
    var result = []
    for (var i = 0; i < items.length; i++) {
      if (root.trayExpanded || !root.trayItemHidden(items[i])) result.push(items[i])
    }
    return result
  }

  function trayHiddenCount() {
    var items = SystemTray.items.values || []
    var count = 0
    for (var i = 0; i < items.length; i++) {
      if (root.trayItemHidden(items[i])) count++
    }
    return count
  }

  function toggleTrayItemHidden(item) {
    if (!item) return
    root.runControl("tray", "toggle", String(item.id))
  }

  function batteryEntries() {
    return root.systemData.batteries || []
  }

  function batteryPrimary() {
    var entries = root.batteryEntries()
    var system = null
    var lowest = null
    for (var i = 0; i < entries.length; i++) {
      if (entries[i].kind === "system" && !system) system = entries[i]
      if (!lowest || Number(entries[i].percent) < Number(lowest.percent)) lowest = entries[i]
    }
    return system || lowest
  }

  function batteryCharging(entry) {
    return !!entry && String(entry.status || "").toLowerCase() === "charging"
  }

  function batteryIcon(entry) {
    if (!entry) return "󰂑"
    if (root.batteryCharging(entry)) return "󰂄"
    var percent = Number(entry.percent || 0)
    if (percent >= 80) return "󰁹"
    if (percent >= 55) return "󰂀"
    if (percent >= 30) return "󰁾"
    if (percent >= 15) return "󰁻"
    return "󰂃"
  }

  function batteryColor(entry) {
    if (root.batteryCharging(entry)) return root.green
    var percent = Number(entry && entry.percent || 0)
    if (percent <= 15) return root.red
    if (percent <= 30) return root.yellow
    return root.text
  }

  function airpodsBatteryText() {
    var entries = root.batteryEntries()
    var values = []
    for (var i = 0; i < entries.length; i++) {
      if (String(entries[i].name || "").toLowerCase().indexOf("airpods") >= 0) {
        var component = String(entries[i].name).replace(/^AirPods\s*/i, "") || "battery"
        values.push(component + " " + Number(entries[i].percent) + "%")
      }
    }
    return values.join(" · ")
  }

  function audioDevices(kind) {
    var devices = root.systemData.audioDevices || []
    var result = []
    for (var i = 0; i < devices.length; i++) {
      if (devices[i].kind === kind) result.push(devices[i])
    }
    return result
  }

  function activeAgents() {
    var launchers = root.agentData.launchers || []
    var states = root.systemData.agentStates || {}
    var names = { pi: "Pi", opencode: "OpenCode", codex: "Codex", claude: "Claude Code" }
    var ids = ["pi", "opencode", "codex", "claude"]
    var result = []
    for (var i = 0; i < launchers.length; i++) names[launchers[i].id] = launchers[i].name
    for (var id in states) if (ids.indexOf(id) < 0) ids.push(id)
    for (var j = 0; j < ids.length; j++) {
      var state = states[ids[j]]
      if (state && state.active) result.push({ id: ids[j], name: names[ids[j]] || ids[j], status: String(state.status || "running") })
    }
    return result
  }

  function agentBadge(id) {
    var badges = { pi: "PI", opencode: "OC", codex: "CX", claude: "CC" }
    return badges[id] || String(id).substring(0, 2).toUpperCase()
  }

  function agentColor(status) {
    if (status === "input") return root.yellow
    if (status === "working") return root.accent
    if (status === "finished") return root.green
    return root.subtext
  }

  function subscriptionSummary() {
    var subscriptions = root.agentData.subscriptions || []
    if (subscriptions.length === 0) return "No subscriptions"
    var names = []
    for (var i = 0; i < subscriptions.length; i++) names.push(subscriptions[i].name)
    return names.join(" · ")
  }

  function patchSystemData(patch) {
    var next = {}
    for (var key in root.systemData) next[key] = root.systemData[key]
    for (var field in patch) next[field] = patch[field]
    root.systemData = next
  }

  function agoText(value) {
    var seconds = Math.max(0, Math.floor(root.now.getTime() / 1000) - Number(value || 0))
    if (seconds < 60) return "just now"
    var minutes = Math.floor(seconds / 60)
    if (minutes < 60) return minutes + "m ago"
    var hours = Math.floor(minutes / 60)
    if (hours < 24) return hours + "h ago"
    return Math.floor(hours / 24) + "d ago"
  }

  QsMenuOpener {
    id: trayMenuOpener
    menu: root.activeTrayItem ? root.activeTrayItem.menu : null
  }

  function showTimedOsd(kind) {
    if (root.yubikeyTouchRequired) return
    root.osdKind = kind
    root.osdOpen = true
    osdTimer.restart()
  }

  function handleYubikeyEvent(value) {
    var event = String(value || "").trim()
    if (!/^(GPG|U2F|MAC)_[01]$/.test(event)) return
    var source = event.substring(0, 3)
    var next = {}
    for (var key in root.yubikeyTouchSources) next[key] = root.yubikeyTouchSources[key]
    if (event.endsWith("_1")) next[source] = true
    else delete next[source]
    root.yubikeyTouchSources = next

    var required = false
    for (var active in next) required = required || !!next[active]
    root.yubikeyTouchRequired = required
    if (required) {
      osdTimer.stop()
      root.osdKind = "yubikey"
      root.osdOpen = true
    } else if (root.osdKind === "yubikey") {
      root.osdOpen = false
    }
  }

  function runAgent(id, prompt) {
    agentsOpen = false
    var args = ["seele-agent", id || "pi"]
    if (String(prompt || "").trim() !== "") args.push(String(prompt).trim())
    Quickshell.execDetached(args)
  }

  function runControl(action, value, extra) {
    var args = ["seele-control", action]
    if (value !== undefined && String(value) !== "") args.push(String(value))
    if (extra !== undefined && String(extra) !== "") args.push(String(extra))
    controlProcess.command = args
    controlProcess.running = true
    if (action === "volume") root.showTimedOsd("volume")
  }

  function toggleWindowsReboot() {
    if (windowsCountdown >= 0) {
      windowsCountdown = -1
      windowsTimer.stop()
    } else {
      windowsCountdown = 10
      windowsTimer.restart()
    }
  }

  function subscriptionLimit(id) {
    var subscriptions = root.agentData.subscriptions || []
    var wanted = String(id).toLowerCase()
    var result = null
    for (var i = 0; i < subscriptions.length; i++) {
      var subscriptionId = String(subscriptions[i].id || "").toLowerCase()
      var subscriptionName = String(subscriptions[i].name || "").toLowerCase()
      if (subscriptionId !== wanted && subscriptionName.indexOf(wanted) < 0) continue
      var limits = subscriptions[i].limits || []
      for (var j = 0; j < limits.length; j++) {
        if (!result || Number(limits[j].usedPercent) > Number(result.usedPercent)) result = limits[j]
      }
    }
    return result
  }

  function freePercent(limit) {
    return limit ? Math.max(0, 100 - Math.round(Number(limit.usedPercent || 0))) : 100
  }

  function menuBarCapacity(id) {
    var limit = root.subscriptionLimit(id)
    return limit ? root.freePercent(limit) : -1
  }

  FileView {
    path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/seele-shell/theme.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try {
        var theme = JSON.parse(text())
        root.base = theme.base || root.base
        root.mantle = theme.mantle || root.mantle
        root.surface = theme.surface || root.surface
        root.overlay = theme.overlay || root.overlay
        root.text = theme.text || root.text
        root.subtext = theme.subtext || root.subtext
        root.accent = theme.accent || root.accent
        root.red = theme.red || root.red
        root.green = theme.green || root.green
        root.yellow = theme.yellow || root.yellow
        root.fontFamily = theme.fontFamily || root.fontFamily
      } catch (error) {
        console.warn("seele-shell/theme", error)
      }
    }
  }

  Process {
    id: agentProcess
    command: ["seele-agent-state"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseAgentData(text)
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (String(text).trim() !== "") root.agentError = String(text).trim()
    }
    onExited: root.agentRefreshing = false
  }

  Process {
    id: statusProcess
    command: ["seele-control", "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseSystemData(text)
    }
  }

  Process {
    id: controlProcess
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseSystemData(text)
    }
  }

  Process {
    id: yubikeyWatchProcess
    command: ["seele-yubikey-watch"]
    running: true
    stdout: SplitParser {
      onRead: data => root.handleYubikeyEvent(data)
    }
  }

  Process {
    id: bluetoothProcess
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseSystemData(text)
    }
    onExited: root.bluetoothBusy = ""
  }

  Timer {
    interval: 15 * 60 * 1000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refreshAgents()
  }

  Timer {
    interval: 5000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refreshStatus()
  }

  Timer {
    interval: 30000
    repeat: true
    running: true
    onTriggered: root.now = new Date()
  }

  Timer {
    id: bluetoothForgetTimer
    interval: 4000
    onTriggered: root.bluetoothForget = ""
  }

  Timer {
    id: osdTimer
    interval: root.osdKind === "airpods" ? 3200 : 1400
    onTriggered: if (root.osdKind !== "yubikey") root.osdOpen = false
  }

  Timer {
    id: windowsTimer
    interval: 1000
    repeat: true
    onTriggered: {
      if (root.windowsCountdown <= 1) {
        stop()
        root.windowsCountdown = -1
        root.controlPanel = ""
        root.runControl("reboot-windows")
      } else {
        root.windowsCountdown--
      }
    }
  }

  IpcHandler {
    target: "seele-shell"
    function ping(): string { return "ok" }
    function toggleLauncher(mode: string): void { root.toggleLauncher(mode) }
    function toggleAgents(): void { root.toggleAgents() }
    function toggleControls(): void { root.toggleControls() }
    function toggleControl(panel: string): void { root.toggleControl(panel) }
    function launchAgent(id: string, prompt: string): void { root.runAgent(id, prompt) }
    function refreshAgents(): void { root.refreshAgents() }
    function updateStatus(json: string): void { root.parseSystemData(json) }
    function refreshStatus(): void { root.refreshStatus() }
    function showVolume(): void { root.showTimedOsd("volume") }
    function close(): void { root.closeOverlays() }
  }

  component ControlSwitch: Rectangle {
    id: control

    property bool checked: false
    signal toggled()

    implicitWidth: 40
    implicitHeight: 22
    radius: height / 2
    color: control.checked ? root.accent : root.alpha(root.overlay, 0.4)
    border.width: 1
    border.color: switchMouse.containsMouse ? root.accent : "transparent"

    Behavior on color { ColorAnimation { duration: 140 } }

    Rectangle {
      width: parent.height - 6
      height: width
      radius: width / 2
      y: 3
      x: control.checked ? control.width - width - 3 : 3
      color: control.checked ? root.base : root.text

      Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    }

    MouseArea { id: switchMouse; anchors.fill: parent; hoverEnabled: true; onClicked: control.toggled() }
  }

  component AirpodsIcon: Item {
    id: airpodsIcon

    property color tint: root.text

    implicitWidth: 16
    implicitHeight: 16

    Repeater {
      model: [0, 1]
      Item {
        required property int modelData
        width: 6
        height: airpodsIcon.height
        x: modelData === 0 ? 1 : airpodsIcon.width - width - 1
        Rectangle { width: 6; height: 6; radius: 3; y: 2; color: airpodsIcon.tint }
        Rectangle { width: 2.4; height: 7; radius: 1.2; x: 1.8; y: 7.5; color: airpodsIcon.tint }
      }
    }
  }

  component HoverTip: PopupWindow {
    id: hoverTip

    property var mouse: null
    property string text: ""

    visible: mouse !== null && mouse.containsMouse && text !== ""
    implicitWidth: hoverTipLabel.implicitWidth + 20
    implicitHeight: 26
    color: "transparent"
    grabFocus: false

    onTextChanged: if (visible) Qt.callLater(hoverTip.reposition)

    anchor {
      window: hoverTip.mouse ? hoverTip.mouse.QsWindow.window : null
      adjustment: PopupAdjustment.Slide
      gravity: Edges.Bottom | Edges.Right

      onAnchoring: {
        if (!hoverTip.mouse) return
        var position = hoverTip.mouse.QsWindow.contentItem.mapFromItem(
          hoverTip.mouse,
          hoverTip.mouse.width / 2 - hoverTip.width / 2,
          hoverTip.mouse.height + 5
        )
        anchor.rect.x = position.x
        anchor.rect.y = position.y
      }
    }

    Rectangle {
      anchors.fill: parent
      radius: 7
      color: root.alpha(root.base, 0.98)
      border.color: root.alpha(root.accent, 0.55)
      border.width: 1

      Text {
        id: hoverTipLabel
        anchors.centerIn: parent
        text: hoverTip.text
        color: root.text
        font.family: root.fontFamily
        font.pixelSize: 10
      }
    }
  }

  Timer {
    id: volumeDragTimer
    interval: 80
    onTriggered: if (root.volumeDrag >= 0) root.runControl("volume", String(root.volumeDrag))
  }

  Timer {
    id: microphoneDragTimer
    interval: 80
    onTriggered: if (root.microphoneDrag >= 0) root.runControl("microphone", String(root.microphoneDrag))
  }

  // Wallpaper ----------------------------------------------------------------
  Variants {
    model: Quickshell.screens
    PanelWindow {
      required property var modelData
      screen: modelData
      anchors { top: true; bottom: true; left: true; right: true }
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.layer: WlrLayer.Background
      WlrLayershell.namespace: "seele-shell-background"
      color: root.base

      Image {
        anchors.fill: parent
        source: "file://" + root.wallpaper
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
      }
    }
  }

  // Bar ----------------------------------------------------------------------
  Variants {
    model: Quickshell.screens
    PanelWindow {
      id: barWindow
      required property var modelData
      screen: modelData
      anchors { top: true; left: true; right: true }
      implicitHeight: 30
      color: root.alpha(root.mantle, 0.96)
      WlrLayershell.layer: WlrLayer.Top
      WlrLayershell.namespace: "seele-shell-bar"

      Row {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        spacing: 0

        Rectangle {
          width: 30; height: parent.height; radius: 0
          color: menuMouse.containsMouse ? root.alpha(root.accent, 0.18) : "transparent"
          Text { anchors.centerIn: parent; text: "󰣇"; color: root.accent; font.family: root.fontFamily; font.pixelSize: 17 }
          MouseArea {
            id: menuMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.toggleLauncher("apps")
          }
          HoverTip { mouse: menuMouse; text: "Applications" }
        }

        Repeater {
          model: root.workspaceIds(barWindow.modelData)
          Item {
            required property int modelData
            readonly property bool active: root.workspaceActive(modelData, barWindow.modelData)
            readonly property bool occupied: root.workspaceOccupied(modelData)
            width: active ? 44 : 22
            height: parent.height

            Behavior on width {
              NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }

            Rectangle {
              id: workspacePill
              width: parent.active ? 40 : 18
              height: 18
              anchors.centerIn: parent
              radius: 9
              color: parent.active ? root.accent : workspaceMouse.containsMouse ? root.alpha(root.accent, 0.55) : parent.occupied ? root.alpha(root.subtext, 0.65) : root.alpha(root.subtext, 0.3)

              Behavior on width {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
              }

              Behavior on color {
                ColorAnimation { duration: 140 }
              }

              Text {
                anchors.centerIn: parent
                text: String(parent.parent.modelData)
                color: root.base
                font.family: root.fontFamily
                font.pixelSize: 10
                font.bold: parent.parent.active
              }
            }

            MouseArea {
              id: workspaceMouse
              anchors.fill: parent
              hoverEnabled: true
              onClicked: Quickshell.execDetached(["hyprctl", "dispatch", "workspace", String(parent.modelData)])
            }
            HoverTip { mouse: workspaceMouse; text: "Workspace " + modelData }
          }
        }

        Rectangle {
          readonly property var window: root.activeWindow(barWindow.modelData)
          visible: window !== null && root.windowTitle(window) !== ""
          width: Math.min(230, activeWindowRow.implicitWidth + 14)
          height: parent.height
          color: activeWindowMouse.containsMouse ? root.alpha(root.accent, 0.14) : "transparent"
          Row {
            id: activeWindowRow
            anchors.centerIn: parent
            height: parent.height
            spacing: 6
            IconImage {
              visible: source !== ""
              anchors.verticalCenter: parent.verticalCenter
              implicitWidth: 15; implicitHeight: 15
              source: root.windowIcon(parent.parent.window) === "" ? "" : Quickshell.iconPath(root.windowIcon(parent.parent.window))
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              width: Math.min(190, implicitWidth)
              text: root.windowTitle(parent.parent.window)
              elide: Text.ElideRight
              color: root.subtext
              font.family: root.fontFamily
              font.pixelSize: 10
            }
          }
          MouseArea { id: activeWindowMouse; anchors.fill: parent; hoverEnabled: true }
          HoverTip { mouse: activeWindowMouse; text: root.windowTitle(activeWindowMouse.parent.window) }
        }

        Rectangle {
          width: 30; height: parent.height
          color: voxtypeMouse.containsMouse ? root.alpha(root.accent, 0.18) : "transparent"
          Text {
            anchors.centerIn: parent
            text: root.systemData.voxtypeStatus === "recording" ? "󰍬" : root.systemData.voxtypeStatus === "transcribing" ? "󰔟" : "󰍭"
            color: root.systemData.voxtypeStatus === "recording" ? root.red : root.systemData.voxtypeStatus === "transcribing" ? root.yellow : root.subtext
            font.family: root.fontFamily
            font.pixelSize: 14
          }
          MouseArea { id: voxtypeMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.runControl("voxtype") }
          HoverTip { mouse: voxtypeMouse; text: "Voxtype: " + root.systemData.voxtypeStatus }
        }
      }

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        spacing: 8
        Text {
          height: parent.height
          text: Qt.formatDateTime(root.now, "HH:mm")
          color: root.text
          verticalAlignment: Text.AlignVCenter
          font.family: root.fontFamily
          font.pixelSize: 12
          font.bold: true
        }
        Text {
          height: parent.height
          text: Qt.formatDateTime(root.now, "yyyy-MM-dd")
          color: root.subtext
          verticalAlignment: Text.AlignVCenter
          font.family: root.fontFamily
          font.pixelSize: 12
        }

        Rectangle {
          visible: root.systemData.microphoneMuted
          anchors.verticalCenter: parent.verticalCenter
          width: 24; height: 18; radius: 6
          color: root.alpha(root.overlay, 0.35)
          Text {
            anchors.centerIn: parent
            text: "󰍭"
            color: root.subtext
            font.family: root.fontFamily
            font.pixelSize: 12
          }
          MouseArea {
            id: microphoneMutedIndicator
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
              root.patchSystemData({ microphoneMuted: false })
              root.runControl("microphone", "mute")
            }
          }
          HoverTip { mouse: microphoneMutedIndicator; text: "Microphone muted · click to unmute" }
        }

        Rectangle {
          visible: root.systemData.microphoneActive && !root.systemData.microphoneMuted
          anchors.verticalCenter: parent.verticalCenter
          width: 9; height: 9; radius: 4.5
          color: root.iosOrange
          MouseArea {
            id: microphoneActiveIndicator
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
              root.patchSystemData({ microphoneMuted: true })
              root.runControl("microphone", "mute")
            }
          }
          HoverTip { mouse: microphoneActiveIndicator; text: "Microphone in use · click to mute" }
        }

        Rectangle {
          visible: root.systemData.cameraActive
          anchors.verticalCenter: parent.verticalCenter
          width: 9; height: 9; radius: 4.5
          color: root.iosGreen
          MouseArea { id: cameraActiveIndicator; anchors.fill: parent; hoverEnabled: true; onClicked: root.toggleControl("camera") }
          HoverTip { mouse: cameraActiveIndicator; text: "Camera in use" }
        }

        Rectangle {
          visible: root.systemData.screenRecording
          anchors.verticalCenter: parent.verticalCenter
          width: 9; height: 9; radius: 4.5
          color: root.iosRed
          MouseArea { id: screenRecordingIndicator; anchors.fill: parent; hoverEnabled: true }
          HoverTip { mouse: screenRecordingIndicator; text: "Screen is being recorded" }
        }
      }

      Row {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        spacing: 0

        Rectangle {
          id: deviceMediaItem

          readonly property var player: root.devicePlayer()
          visible: player !== null
          width: visible ? Math.min(210, deviceMediaRow.implicitWidth + 14) : 0
          height: parent.height
          color: deviceMediaMouse.containsMouse ? root.alpha(root.accent, 0.18) : "transparent"
          Row {
            id: deviceMediaRow
            anchors.centerIn: parent
            height: parent.height
            spacing: 5
            Item {
              anchors.verticalCenter: parent.verticalCenter
              width: 16; height: 16
              Image {
                id: deviceMediaArt
                anchors.fill: parent
                source: deviceMediaItem.player ? String(deviceMediaItem.player.trackArtUrl || "") : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                visible: status === Image.Ready
              }
              Text {
                anchors.centerIn: parent
                visible: deviceMediaArt.status !== Image.Ready
                text: "󰎆"
                color: root.accent
                font.family: root.fontFamily
                font.pixelSize: 13
              }
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              width: Math.min(175, implicitWidth)
              text: parent.parent.player ? parent.parent.player.trackTitle : ""
              elide: Text.ElideRight
              color: root.text
              font.family: root.fontFamily
              font.pixelSize: 10
            }
          }
          MouseArea { id: deviceMediaMouse; anchors.fill: parent; hoverEnabled: true; onClicked: if (parent.player) parent.player.togglePlaying() }
          HoverTip { mouse: deviceMediaMouse; text: deviceMediaItem.player ? deviceMediaItem.player.trackArtist + " — " + deviceMediaItem.player.trackTitle : "" }
        }

        Rectangle {
          id: spotifyMediaItem

          readonly property var player: root.spotifyPlayer()
          readonly property var device: root.devicePlayer()
          visible: player !== null && player !== device
          width: visible ? Math.min(210, spotifyMediaRow.implicitWidth + 14) : 0
          height: parent.height
          color: spotifyMediaMouse.containsMouse ? root.alpha(root.green, 0.18) : "transparent"
          Row {
            id: spotifyMediaRow
            anchors.centerIn: parent
            height: parent.height
            spacing: 5
            Item {
              anchors.verticalCenter: parent.verticalCenter
              width: 16; height: 16
              Image {
                id: spotifyMediaArt
                anchors.fill: parent
                source: spotifyMediaItem.player ? String(spotifyMediaItem.player.trackArtUrl || "") : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                visible: status === Image.Ready
              }
              Text {
                anchors.centerIn: parent
                visible: spotifyMediaArt.status !== Image.Ready
                text: "󰓇"
                color: root.green
                font.family: root.fontFamily
                font.pixelSize: 13
              }
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              width: Math.min(175, implicitWidth)
              text: parent.parent.player ? parent.parent.player.trackTitle : ""
              elide: Text.ElideRight
              color: root.text
              font.family: root.fontFamily
              font.pixelSize: 10
            }
          }
          MouseArea { id: spotifyMediaMouse; anchors.fill: parent; hoverEnabled: true; onClicked: if (parent.player) parent.player.togglePlaying() }
          HoverTip { mouse: spotifyMediaMouse; text: spotifyMediaItem.player ? spotifyMediaItem.player.trackArtist + " — " + spotifyMediaItem.player.trackTitle : "" }
        }

        Rectangle {
          visible: root.trayHiddenCount() > 0
          width: 20; height: parent.height; radius: 0
          color: trayExpandMouse.containsMouse ? root.surface : "transparent"
          Text {
            anchors.centerIn: parent
            text: root.trayExpanded ? "󰅂" : "󰅁"
            color: root.trayExpanded ? root.accent : root.overlay
            font.family: root.fontFamily
            font.pixelSize: 13
          }
          MouseArea { id: trayExpandMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.trayExpanded = !root.trayExpanded }
          HoverTip { mouse: trayExpandMouse; text: root.trayHiddenCount() + " hidden tray icon" + (root.trayHiddenCount() === 1 ? "" : "s") }
        }

        Repeater {
          model: root.trayItems()
          Rectangle {
            required property var modelData
            width: 30; height: parent.height; radius: 0
            color: trayMouse.containsMouse ? root.surface : "transparent"
            opacity: root.trayItemHidden(modelData) ? 0.45 : 1
            IconImage {
              anchors.centerIn: parent
              implicitWidth: 16; implicitHeight: 16
              source: parent.modelData.icon
            }
            MouseArea {
              id: trayMouse
              anchors.fill: parent
              hoverEnabled: true
              acceptedButtons: Qt.LeftButton | Qt.MiddleButton
              preventStealing: true
              function openContextMenu() {
                if (parent.modelData.menu) {
                  var sameMenu = root.trayMenuOpen && root.activeTrayItem === parent.modelData
                  root.closeOverlays()
                  if (!sameMenu) {
                    root.activeTrayItem = parent.modelData
                    root.trayMenuOpen = true
                  }
                } else {
                  Quickshell.execDetached(["seele-control", "tray-menu", parent.modelData.id])
                }
              }
              onClicked: function(mouse) {
                if (mouse.button === Qt.MiddleButton) root.toggleTrayItemHidden(parent.modelData)
                else if (parent.modelData.onlyMenu) openContextMenu()
                else parent.modelData.activate()
              }
              onWheel: function(wheel) { parent.modelData.scroll(Math.round(wheel.angleDelta.y / 8), false) }
            }
            TapHandler {
              acceptedButtons: Qt.RightButton
              gesturePolicy: TapHandler.WithinBounds
              onTapped: trayMouse.openContextMenu()
            }
            HoverTip { mouse: trayMouse; text: modelData.title || modelData.id || "Tray item" }
          }
        }

        Rectangle {
          visible: root.systemData.cameraActive || (root.systemData.cameraDevices && root.systemData.cameraDevices.length > 0)
          width: 30; height: parent.height
          color: cameraMouse.containsMouse || root.controlPanel === "camera" ? root.alpha(root.accent, 0.18) : "transparent"
          Text { anchors.centerIn: parent; text: root.systemData.cameraActive ? "󰄀" : "󰄁"; color: root.systemData.cameraActive ? root.red : root.text; font.family: root.fontFamily; font.pixelSize: 14 }
          MouseArea { id: cameraMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.toggleControl("camera") }
          HoverTip { mouse: cameraMouse; text: root.systemData.cameraActive ? "Camera in use" : "Camera" }
        }

        Repeater {
          model: root.activeAgents()
          Rectangle {
            required property var modelData
            id: agentBadgeItem

            readonly property color stateColor: root.agentColor(modelData.status)
            width: 28; height: parent.height; radius: 0
            color: agentBadgeMouse.containsMouse ? root.alpha(root.accent, 0.18) : "transparent"
            Column {
              anchors.centerIn: parent
              spacing: 2
              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.agentBadge(modelData.id)
                color: agentBadgeItem.stateColor
                font.family: root.fontFamily
                font.pixelSize: 10
                font.bold: true
              }
              Rectangle {
                id: agentStateBar
                anchors.horizontalCenter: parent.horizontalCenter
                width: 14; height: 3; radius: 1.5
                color: agentBadgeItem.stateColor
                opacity: modelData.status === "running" ? 0.4 : 1

                SequentialAnimation on opacity {
                  running: modelData.status === "working" || modelData.status === "input"
                  loops: Animation.Infinite
                  NumberAnimation { from: 1; to: 0.25; duration: modelData.status === "input" ? 600 : 900; easing.type: Easing.InOutQuad }
                  NumberAnimation { from: 0.25; to: 1; duration: modelData.status === "input" ? 600 : 900; easing.type: Easing.InOutQuad }
                }
              }
            }
            MouseArea { id: agentBadgeMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.toggleAgents() }
            HoverTip { mouse: agentBadgeMouse; text: modelData.name + " · " + (modelData.status === "input" ? "needs input" : modelData.status) }
          }
        }


        Rectangle {
          width: aiBarContent.implicitWidth + 14; height: parent.height; radius: 0
          color: aiMouse.containsMouse || root.agentsOpen ? root.alpha(root.accent, 0.18) : "transparent"
          visible: root.agentData.launchers && root.agentData.launchers.length > 0
          Row {
            id: aiBarContent
            readonly property int codexCapacity: root.menuBarCapacity("codex")
            readonly property int claudeCapacity: root.menuBarCapacity("claude")
            anchors.centerIn: parent
            height: parent.height
            spacing: 5
            Text { anchors.verticalCenter: parent.verticalCenter; text: "󱚣"; color: root.accent; font.family: root.fontFamily; font.pixelSize: 15 }
            Text {
              visible: aiBarContent.codexCapacity >= 0
              anchors.verticalCenter: parent.verticalCenter
              text: "Codex " + aiBarContent.codexCapacity + "%"
              color: aiBarContent.codexCapacity <= 15 ? root.red : root.text
              font.family: root.fontFamily
              font.pixelSize: 11
              font.bold: true
            }
            Text {
              visible: aiBarContent.codexCapacity >= 0 && aiBarContent.claudeCapacity >= 0
              anchors.verticalCenter: parent.verticalCenter
              text: "·"
              color: root.overlay
              font.family: root.fontFamily
              font.pixelSize: 11
            }
            Text {
              visible: aiBarContent.claudeCapacity >= 0
              anchors.verticalCenter: parent.verticalCenter
              text: "Claude " + aiBarContent.claudeCapacity + "%"
              color: aiBarContent.claudeCapacity <= 15 ? root.red : root.text
              font.family: root.fontFamily
              font.pixelSize: 11
              font.bold: true
            }
            Text {
              visible: aiBarContent.codexCapacity < 0 && aiBarContent.claudeCapacity < 0
              anchors.verticalCenter: parent.verticalCenter
              text: "AI"
              color: root.text
              font.family: root.fontFamily
              font.pixelSize: 11
              font.bold: true
            }
          }
          MouseArea {
            id: aiMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: function(mouse) {
              if (mouse.button === Qt.RightButton) root.runAgent("pi", "")
              else if (mouse.button === Qt.MiddleButton) root.refreshAgents()
              else root.toggleAgents()
            }
          }
          HoverTip { mouse: aiMouse; text: "AI cockpit · middle-click to refresh · right-click to launch Pi" }
        }

        Rectangle {
          visible: root.systemData.airpodsConnected
          width: 30; height: parent.height; radius: 0
          color: airpodsMouse.containsMouse || root.controlPanel === "airpods" ? root.alpha(root.accent, 0.18) : "transparent"
          AirpodsIcon { anchors.centerIn: parent; tint: root.accent }
          MouseArea { id: airpodsMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.toggleControl("airpods") }
          HoverTip { mouse: airpodsMouse; text: root.systemData.airpodsName || "AirPods" }
        }

        Rectangle {
          visible: root.systemData.bluetoothAvailable
          width: 30; height: parent.height; radius: 0
          color: bluetoothMouse.containsMouse || root.controlPanel === "bluetooth" ? root.alpha(root.accent, 0.18) : "transparent"
          Text {
            anchors.centerIn: parent
            text: root.systemData.bluetoothPowered ? "󰂯" : "󰂲"
            color: root.systemData.bluetoothConnected > 0 ? root.accent : root.text
            font.family: root.fontFamily
            font.pixelSize: 14
          }
          MouseArea { id: bluetoothMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.toggleControl("bluetooth") }
          HoverTip { mouse: bluetoothMouse; text: "Bluetooth · " + (root.systemData.bluetoothPowered ? root.systemData.bluetoothConnected + " connected" : "off") }
        }

        Rectangle {
          width: 30; height: parent.height; radius: 0
          color: networkMouse.containsMouse || root.controlPanel === "network" ? root.alpha(root.accent, 0.18) : "transparent"
          Text {
            anchors.centerIn: parent
            text: root.systemData.connection === "Disconnected" ? "󰖪" : root.systemData.connectionType.indexOf("wireless") >= 0 ? "󰖩" : "󰈀"
            color: root.systemData.connectivity === "full" ? root.text : root.yellow
            font.family: root.fontFamily
            font.pixelSize: 14
          }
          MouseArea { id: networkMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.toggleControl("network") }
          HoverTip { mouse: networkMouse; text: "Network · " + (root.systemData.connection || "Disconnected") }
        }


        Rectangle {
          width: audioBarContent.implicitWidth + 12; height: parent.height; radius: 0
          color: audioMouse.containsMouse || root.controlPanel === "audio" ? root.alpha(root.accent, 0.18) : "transparent"
          Row {
            id: audioBarContent
            anchors.centerIn: parent
            height: parent.height
            spacing: 4
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: root.systemData.muted ? "󰝟" : Number(root.systemData.volume) > 55 ? "󰕾" : "󰖀"
              color: root.systemData.muted ? root.red : root.text
              font.family: root.fontFamily
              font.pixelSize: 14
            }
            Text { anchors.verticalCenter: parent.verticalCenter; text: root.systemData.volume + "%"; color: root.text; font.family: root.fontFamily; font.pixelSize: 10 }
          }
          MouseArea { id: audioMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.toggleControl("audio") }
          HoverTip { mouse: audioMouse; text: "Volume · " + (root.systemData.muted ? "muted" : root.systemData.volume + "%") }
        }

        Rectangle {
          width: notificationBarContent.implicitWidth + 12; height: parent.height
          color: notificationMouse.containsMouse || root.controlPanel === "notifications" ? root.alpha(root.accent, 0.18) : "transparent"
          Row {
            id: notificationBarContent
            anchors.centerIn: parent
            height: parent.height
            spacing: 4
            Text { anchors.verticalCenter: parent.verticalCenter; text: root.systemData.dnd ? "󰂛" : "󰂚"; color: root.systemData.dnd ? root.yellow : root.text; font.family: root.fontFamily; font.pixelSize: 14 }
            Text { visible: Number(root.systemData.notifications.count || 0) > 0; anchors.verticalCenter: parent.verticalCenter; text: String(root.systemData.notifications.count); color: root.text; font.family: root.fontFamily; font.pixelSize: 9; font.bold: true }
          }
          MouseArea { id: notificationMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.toggleControl("notifications") }
          HoverTip { mouse: notificationMouse; text: "Notifications · " + (root.systemData.dnd ? "do not disturb" : root.systemData.notifications.count || 0) }
        }

        Rectangle {
          id: batteryBarItem

          readonly property var entry: root.batteryPrimary()
          visible: root.batteryEntries().length > 0
          width: batteryBarContent.implicitWidth + 12; height: parent.height; radius: 0
          color: batteryMouse.containsMouse || root.controlPanel === "battery" ? root.alpha(root.accent, 0.18) : "transparent"
          Row {
            id: batteryBarContent
            anchors.centerIn: parent
            height: parent.height
            spacing: 4
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: root.batteryIcon(batteryBarItem.entry)
              color: root.batteryColor(batteryBarItem.entry)
              font.family: root.fontFamily
              font.pixelSize: 14
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: batteryBarItem.entry ? Number(batteryBarItem.entry.percent) + "%" : ""
              color: root.text
              font.family: root.fontFamily
              font.pixelSize: 10
            }
          }
          MouseArea { id: batteryMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.toggleControl("battery") }
          HoverTip { mouse: batteryMouse; text: "Battery · " + (batteryBarItem.entry ? batteryBarItem.entry.name + " " + Number(batteryBarItem.entry.percent) + "%" : "unavailable") }
        }

        Rectangle {
          width: 30; height: parent.height; radius: 0
          color: sessionMouse.containsMouse || root.controlPanel === "system" ? root.alpha(root.accent, 0.18) : "transparent"
          Text { anchors.centerIn: parent; text: "󰐥"; color: root.windowsCountdown >= 0 ? root.yellow : root.text; font.family: root.fontFamily; font.pixelSize: 14 }
          MouseArea { id: sessionMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.toggleControl("system") }
          HoverTip { mouse: sessionMouse; text: "Power and session" }
        }
      }
    }
  }

  // Click-away catcher ---------------------------------------------------------
  // Declared before the popouts so they stack above it; the bar strip stays
  // clickable so one click can switch between panels.
  Variants {
    model: Quickshell.screens
    PanelWindow {
      required property var modelData
      screen: modelData
      visible: root.controlPanel !== "" || root.agentsOpen || root.trayMenuOpen
      anchors { top: true; bottom: true; left: true; right: true }
      margins { top: 30 }
      exclusionMode: ExclusionMode.Ignore
      color: "transparent"
      WlrLayershell.layer: WlrLayer.Top
      WlrLayershell.namespace: "seele-shell-clickaway"

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onPressed: root.closeOverlays()
      }
    }
  }

  // Tray menu -----------------------------------------------------------------
  Variants {
    model: Quickshell.screens
    PanelWindow {
      id: trayMenuWindow
      required property var modelData
      screen: modelData
      visible: root.trayMenuOpen && root.focusedScreen(modelData)
      anchors { top: true; right: true }
      margins { top: 35; right: 5 }
      implicitWidth: 310
      implicitHeight: Math.min(420, 58 + Math.max(1, trayMenuOpener.children.values.length) * 36)
      exclusionMode: ExclusionMode.Ignore
      color: "transparent"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "seele-shell-tray-menu"
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

      Rectangle {
        anchors.fill: parent
        radius: 8
        color: root.alpha(root.base, 0.98)
        border.color: root.alpha(root.accent, 0.65)
        border.width: 1

        Column {
          anchors.fill: parent
          anchors.margins: 10
          spacing: 6

          Row {
            width: parent.width
            height: 30
            Text {
              width: parent.width - 106
              anchors.verticalCenter: parent.verticalCenter
              text: root.activeTrayItem ? (root.activeTrayItem.title || root.activeTrayItem.id || "Tray menu") : "Tray menu"
              elide: Text.ElideRight
              color: root.text
              font.family: root.fontFamily
              font.pixelSize: 12
              font.bold: true
            }
            Rectangle {
              width: 72; height: 26; radius: 8
              anchors.verticalCenter: parent.verticalCenter
              color: trayHideMouse.containsMouse ? root.alpha(root.accent, 0.2) : root.surface
              Text {
                anchors.centerIn: parent
                text: root.trayItemHidden(root.activeTrayItem) ? "Show icon" : "Hide icon"
                color: root.text
                font.family: root.fontFamily
                font.pixelSize: 9
                font.bold: true
              }
              MouseArea {
                id: trayHideMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                  root.toggleTrayItemHidden(root.activeTrayItem)
                  root.closeTrayMenu()
                }
              }
            }
            Rectangle {
              width: 30; height: 30; radius: 8
              color: trayMenuCloseMouse.containsMouse ? root.surface : "transparent"
              Text { anchors.centerIn: parent; text: "󰅖"; color: root.subtext; font.family: root.fontFamily; font.pixelSize: 11 }
              MouseArea { id: trayMenuCloseMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.closeTrayMenu() }
            }
          }

          ListView {
            id: trayMenuList
            width: parent.width
            height: parent.height - 36
            spacing: 2
            clip: true
            model: trayMenuOpener.children
            delegate: Item {
              required property var modelData
              width: trayMenuList.width
              height: modelData.isSeparator ? 9 : 34
              opacity: modelData.enabled ? 1 : 0.45

              Rectangle {
                visible: parent.modelData.isSeparator
                anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 8; anchors.rightMargin: 8
                height: 1
                color: root.alpha(root.overlay, 0.5)
              }

              Rectangle {
                visible: !parent.modelData.isSeparator
                anchors.fill: parent
                radius: 8
                color: trayMenuEntryMouse.containsMouse && parent.modelData.enabled ? root.alpha(root.accent, 0.18) : "transparent"
              }

              IconImage {
                id: trayMenuEntryIcon
                visible: !parent.modelData.isSeparator && source !== ""
                anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter
                implicitWidth: 16; implicitHeight: 16
                source: parent.modelData.icon || ""
              }

              Text {
                visible: !parent.modelData.isSeparator && parent.modelData.buttonType !== QsMenuButtonType.None
                anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter
                width: 16
                text: parent.modelData.checkState === Qt.Checked ? "✓" : ""
                color: root.accent
                horizontalAlignment: Text.AlignHCenter
                font.family: root.fontFamily
                font.pixelSize: 11
              }

              Text {
                visible: !parent.modelData.isSeparator
                anchors.left: parent.left; anchors.leftMargin: trayMenuEntryIcon.visible ? 32 : 28
                anchors.right: trayMenuSubmenu.left; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
                text: parent.modelData.text || ""
                elide: Text.ElideRight
                color: root.text
                font.family: root.fontFamily
                font.pixelSize: 11
              }

              Text {
                id: trayMenuSubmenu
                visible: !parent.modelData.isSeparator && parent.modelData.hasChildren
                anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
                text: "›"
                color: root.subtext
                font.family: root.fontFamily
                font.pixelSize: 15
              }

              MouseArea {
                id: trayMenuEntryMouse
                anchors.fill: parent
                hoverEnabled: true
                enabled: !parent.modelData.isSeparator && parent.modelData.enabled
                onClicked: {
                  if (parent.modelData.hasChildren) {
                    parent.modelData.display(trayMenuWindow, 10, parent.y + parent.height)
                  } else {
                    parent.modelData.triggered()
                    root.closeTrayMenu()
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  // AI cockpit ----------------------------------------------------------------
  Variants {
    model: Quickshell.screens
    PanelWindow {
      id: agentsWindow
      required property var modelData
      screen: modelData
      visible: root.agentsOpen && root.focusedScreen(modelData)
      anchors { top: true; right: true }
      margins { top: 35; right: 5 }
      implicitWidth: 470
      implicitHeight: Math.min(modelData.height - 60, 760)
      exclusionMode: ExclusionMode.Ignore
      color: "transparent"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
      WlrLayershell.namespace: "seele-shell-agents"

      Rectangle {
        anchors.fill: parent
        radius: 8
        color: root.alpha(root.base, 0.98)
        border.color: root.alpha(root.accent, 0.7)
        border.width: 1

        ScrollView {
          anchors.fill: parent
          anchors.margins: 18
          clip: true

          Column {
            id: agentsContent

            width: agentsWindow.width - 36
            spacing: 14

            Row {
              width: parent.width
              spacing: 10
              Text { text: "󱚣"; color: root.accent; font.family: root.fontFamily; font.pixelSize: 28 }
              Column {
                width: parent.width - 110
                Text { text: "AI cockpit"; color: root.text; font.family: root.fontFamily; font.pixelSize: 20; font.bold: true }
                Text {
                  text: root.agentRefreshing ? "Refreshing usage…" : root.agentError !== "" ? "Usage unavailable" : root.subscriptionSummary()
                  color: root.agentError !== "" ? root.red : root.subtext
                  font.family: root.fontFamily; font.pixelSize: 11
                }
              }
              Rectangle {
                width: 34; height: 34; radius: 9; color: refreshMouse.containsMouse ? root.surface : "transparent"
                Text { anchors.centerIn: parent; text: root.agentRefreshing ? "󰑓" : "󰑐"; color: root.accent; font.family: root.fontFamily; font.pixelSize: 16 }
                MouseArea { id: refreshMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.refreshAgents() }
              }
            }

            Text { text: "LAUNCH"; color: root.overlay; font.family: root.fontFamily; font.pixelSize: 10; font.bold: true }

            Grid {
              width: parent.width
              columns: 2
              spacing: 8
              Repeater {
                model: root.agentData.launchers || []
                Rectangle {
                  required property var modelData
                  readonly property string status: root.agentStatus(modelData.id)
                  width: (parent.width - 8) / 2; height: 68; radius: 8
                  color: launchMouse.containsMouse ? root.alpha(root.accent, 0.2) : root.surface
                  border.color: status === "input" ? root.yellow : status === "working" ? root.accent : status === "finished" ? root.green : root.alpha(root.overlay, 0.35)
                  border.width: status === "idle" ? 1 : 2
                  Column {
                    anchors.centerIn: parent
                    spacing: 3
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.name; color: root.text; font.family: root.fontFamily; font.pixelSize: 13; font.bold: true }
                    Text {
                      anchors.horizontalCenter: parent.horizontalCenter
                      text: parent.parent.status === "working" ? "● working" : parent.parent.status === "input" ? "◆ input needed" : parent.parent.status === "finished" ? "✓ finished" : modelData.id === "pi" ? "Primary" : "Ready"
                      color: parent.parent.status === "input" ? root.yellow : parent.parent.status === "working" ? root.accent : parent.parent.status === "finished" ? root.green : root.subtext
                      font.family: root.fontFamily
                      font.pixelSize: 9
                    }
                  }
                  MouseArea { id: launchMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.runAgent(parent.modelData.id, "") }
                }
              }
            }

            Text { text: "SUBSCRIPTION CAPACITY"; color: root.overlay; font.family: root.fontFamily; font.pixelSize: 10; font.bold: true }

            Repeater {
              model: root.agentData.subscriptions || []
              Column {
                required property var modelData
                width: parent.width
                spacing: 6
                Row {
                  width: parent.width
                  Text {
                    width: parent.width * 0.62
                    text: modelData.name + (modelData.plan ? " · " + modelData.plan : "")
                    elide: Text.ElideRight
                    color: root.text
                    font.family: root.fontFamily
                    font.pixelSize: 12
                    font.bold: true
                  }
                  Text {
                    width: parent.width * 0.38
                    text: modelData.credits !== null && modelData.credits !== undefined && Number(modelData.credits) > 0 ? Number(modelData.credits) + " credits" : modelData.source
                    color: root.overlay
                    font.family: root.fontFamily
                    font.pixelSize: 9
                    horizontalAlignment: Text.AlignRight
                  }
                }
                Repeater {
                  model: modelData.limits || []
                  Column {
                    required property var modelData
                    width: parent.width
                    spacing: 5
                    Row {
                      width: parent.width
                      Text { width: parent.width * 0.45; text: modelData.name; color: root.subtext; font.family: root.fontFamily; font.pixelSize: 11 }
                      Text { width: parent.width * 0.3; text: root.freePercent(modelData) + "% free"; color: root.freePercent(modelData) <= 15 ? root.red : root.subtext; font.family: root.fontFamily; font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter }
                      Text { width: parent.width * 0.25; text: "resets " + root.resetText(modelData.resetsAt); color: root.subtext; font.family: root.fontFamily; font.pixelSize: 10; horizontalAlignment: Text.AlignRight }
                    }
                    Rectangle {
                      width: parent.width; height: 8; radius: 4; color: root.surface
                      Rectangle { width: parent.width * root.freePercent(modelData) / 100; height: parent.height; radius: 4; color: root.freePercent(modelData) <= 15 ? root.red : root.accent }
                    }
                  }
                }
                Text {
                  visible: (modelData.limits || []).length === 0
                  text: "No usage window reported"
                  color: root.overlay
                  font.family: root.fontFamily
                  font.pixelSize: 9
                }
              }
            }
            Row {
              width: parent.width
              spacing: 8
              Rectangle {
                width: (parent.width - 8) / 2; height: 68; radius: 12; color: root.surface
                Column { anchors.centerIn: parent; spacing: 4
                  Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.formatTokens(root.agentData.local.today.totalTokens || 0); color: root.accent; font.family: root.fontFamily; font.pixelSize: 20; font.bold: true }
                  Text { anchors.horizontalCenter: parent.horizontalCenter; text: "tokens today"; color: root.subtext; font.family: root.fontFamily; font.pixelSize: 10 }
                }
              }
              Rectangle {
                width: (parent.width - 8) / 2; height: 68; radius: 12; color: root.surface
                Column { anchors.centerIn: parent; spacing: 4
                  Text { anchors.horizontalCenter: parent.horizontalCenter; text: "$" + Number(root.agentData.local.totalCost || 0).toFixed(2); color: root.green; font.family: root.fontFamily; font.pixelSize: 20; font.bold: true }
                  Text { anchors.horizontalCenter: parent.horizontalCenter; text: "estimated · 30 days"; color: root.subtext; font.family: root.fontFamily; font.pixelSize: 10 }
                }
              }
            }

            Item {
              width: parent.width
              height: 18
              Row {
                anchors.fill: parent
                Text { width: parent.width - 20; anchors.verticalCenter: parent.verticalCenter; text: "LAST 7 DAYS"; color: usageHeaderMouse.containsMouse ? root.text : root.overlay; font.family: root.fontFamily; font.pixelSize: 10; font.bold: true }
                Text { width: 20; anchors.verticalCenter: parent.verticalCenter; text: root.agentUsageOpen ? "󰅃" : "󰅀"; color: root.overlay; font.family: root.fontFamily; font.pixelSize: 11; horizontalAlignment: Text.AlignRight }
              }
              MouseArea { id: usageHeaderMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.agentUsageOpen = !root.agentUsageOpen }
            }

            Column {
              width: parent.width
              spacing: 4
              visible: root.agentUsageOpen
              Repeater {
                model: root.agentData.local.daily || []
                Row {
                  required property var modelData
                  width: parent.width; height: 24; spacing: 8
                  readonly property real peak: {
                    var days = root.agentData.local.daily || []
                    var value = 1
                    for (var i = 0; i < days.length; i++) value = Math.max(value, Number(days[i].totalTokens || 0))
                    return value
                  }
                  Text { width: 76; anchors.verticalCenter: parent.verticalCenter; text: modelData.date || ""; color: root.subtext; font.family: root.fontFamily; font.pixelSize: 10 }
                  Rectangle {
                    width: parent.width - 150; height: 7; anchors.verticalCenter: parent.verticalCenter; radius: 4; color: root.surface
                    Rectangle { width: parent.width * Number(modelData.totalTokens || 0) / parent.parent.peak; height: parent.height; radius: 4; color: root.accent }
                  }
                  Text { width: 58; anchors.verticalCenter: parent.verticalCenter; text: root.formatTokens(modelData.totalTokens || 0); color: root.text; font.family: root.fontFamily; font.pixelSize: 10; horizontalAlignment: Text.AlignRight }
                }
              }
            }

            Item {
              width: parent.width
              height: 18
              Row {
                anchors.fill: parent
                Text { width: parent.width - 20; anchors.verticalCenter: parent.verticalCenter; text: "TOP MODELS"; color: modelsHeaderMouse.containsMouse ? root.text : root.overlay; font.family: root.fontFamily; font.pixelSize: 10; font.bold: true }
                Text { width: 20; anchors.verticalCenter: parent.verticalCenter; text: root.agentModelsOpen ? "󰅃" : "󰅀"; color: root.overlay; font.family: root.fontFamily; font.pixelSize: 11; horizontalAlignment: Text.AlignRight }
              }
              MouseArea { id: modelsHeaderMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.agentModelsOpen = !root.agentModelsOpen }
            }
            Column {
              width: parent.width
              spacing: 2
              visible: root.agentModelsOpen
              Repeater {
                model: root.agentData.local.models || []
                Row {
                  required property var modelData
                  width: parent.width; height: 25
                  Text { width: parent.width * 0.62; text: modelData.name; elide: Text.ElideRight; color: root.text; font.family: root.fontFamily; font.pixelSize: 11 }
                  Text { width: parent.width * 0.2; text: root.formatTokens(modelData.tokens); color: root.subtext; font.family: root.fontFamily; font.pixelSize: 10; horizontalAlignment: Text.AlignRight }
                  Text { width: parent.width * 0.18; text: "$" + Number(modelData.cost || 0).toFixed(2); color: root.green; font.family: root.fontFamily; font.pixelSize: 10; horizontalAlignment: Text.AlignRight }
                }
              }
            }

            Text {
              width: parent.width
              text: "Usage is read locally through CodexBar. Credentials and account identity never enter the shell state."
              color: root.overlay
              font.family: root.fontFamily
              font.pixelSize: 9
              wrapMode: Text.WordWrap
            }
          }
        }
      }
    }
  }

  // Audio controls -------------------------------------------------------------
  Variants {
    model: Quickshell.screens
    PanelWindow {
      id: audioControlsWindow

      readonly property int outputHeight: Math.max(1, Math.min(4, root.audioDevices("output").length)) * 32
      readonly property int inputHeight: Math.max(1, Math.min(4, root.audioDevices("input").length)) * 32
      required property var modelData
      screen: modelData
      visible: root.controlPanel === "audio" && root.focusedScreen(modelData)
      anchors { top: true; right: true }
      margins { top: 35; right: 5 }
      implicitWidth: 350
      implicitHeight: 268 + outputHeight + inputHeight
      exclusionMode: ExclusionMode.Ignore
      color: "transparent"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "seele-shell-audio"

      Rectangle {
        anchors.fill: parent; radius: 8; color: root.alpha(root.base, 0.98); border.color: root.alpha(root.accent, 0.65); border.width: 1
        Column {
          anchors.fill: parent; anchors.margins: 16; spacing: 12
          Text { text: "Audio"; color: root.text; font.family: root.fontFamily; font.pixelSize: 18; font.bold: true }
          Row {
            width: parent.width; spacing: 8
            Rectangle {
              id: outputSlider

              readonly property int shown: root.volumeDrag >= 0 ? root.volumeDrag : Number(root.systemData.volume)
              width: parent.width - 52; height: 44; radius: 10
              color: root.surface
              clip: true
              Rectangle {
                width: parent.width * Math.max(0, Math.min(1, parent.shown / 100))
                radius: parent.radius
                height: parent.height
                color: root.systemData.muted ? root.alpha(root.red, 0.45) : root.alpha(root.accent, 0.45)
              }
              Row {
                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width - 46
                  text: root.systemData.muted ? "󰝟  Output muted" : "󰕾  Output"
                  color: root.text
                  font.family: root.fontFamily
                  font.pixelSize: 11
                  font.bold: true
                }
                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  width: 46
                  text: outputSlider.shown + "%"
                  color: root.subtext
                  font.family: root.fontFamily
                  font.pixelSize: 11
                  horizontalAlignment: Text.AlignRight
                }
              }
              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                function valueAt(x) { return Math.max(0, Math.min(100, Math.round(x / width * 100))) }
                onPressed: function(mouse) {
                  root.volumeDrag = valueAt(mouse.x)
                  volumeDragTimer.restart()
                }
                onPositionChanged: function(mouse) {
                  if (!pressed) return
                  root.volumeDrag = valueAt(mouse.x)
                  if (!volumeDragTimer.running) volumeDragTimer.restart()
                }
                onReleased: function(mouse) {
                  root.volumeDrag = valueAt(mouse.x)
                  volumeDragTimer.stop()
                  root.runControl("volume", String(root.volumeDrag))
                }
                onWheel: function(wheel) { root.runControl("volume", wheel.angleDelta.y > 0 ? "up" : "down") }
              }
            }
            Rectangle {
              width: 44; height: 44; radius: 10
              color: root.systemData.muted ? root.alpha(root.red, 0.28) : outputMuteMouse.containsMouse ? root.alpha(root.accent, 0.2) : root.surface
              Text {
                anchors.centerIn: parent
                text: root.systemData.muted ? "󰝟" : "󰕾"
                color: root.systemData.muted ? root.red : root.text
                font.family: root.fontFamily
                font.pixelSize: 15
              }
              MouseArea {
                id: outputMuteMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                  root.patchSystemData({ muted: !root.systemData.muted })
                  root.runControl("volume", "mute")
                }
              }
              HoverTip { mouse: outputMuteMouse; text: root.systemData.muted ? "Unmute output" : "Mute output" }
            }
          }
          Row {
            width: parent.width; spacing: 8
            Rectangle {
              id: microphoneSlider

              readonly property int shown: root.microphoneDrag >= 0 ? root.microphoneDrag : Number(root.systemData.microphoneVolume)
              width: parent.width - 52; height: 44; radius: 10
              color: root.surface
              clip: true
              Rectangle {
                width: parent.width * Math.max(0, Math.min(1, parent.shown / 100))
                radius: parent.radius
                height: parent.height
                color: root.systemData.microphoneMuted ? root.alpha(root.red, 0.45) : root.alpha(root.accent, 0.35)
              }
              Row {
                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width - 46
                  text: root.systemData.microphoneMuted ? "󰍭  Microphone muted" : root.systemData.microphoneActive ? "󰍬  Microphone in use" : "󰍬  Microphone"
                  color: root.text
                  font.family: root.fontFamily
                  font.pixelSize: 11
                  font.bold: true
                }
                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  width: 46
                  text: microphoneSlider.shown + "%"
                  color: root.subtext
                  font.family: root.fontFamily
                  font.pixelSize: 11
                  horizontalAlignment: Text.AlignRight
                }
              }
              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                function valueAt(x) { return Math.max(0, Math.min(100, Math.round(x / width * 100))) }
                onPressed: function(mouse) {
                  root.microphoneDrag = valueAt(mouse.x)
                  microphoneDragTimer.restart()
                }
                onPositionChanged: function(mouse) {
                  if (!pressed) return
                  root.microphoneDrag = valueAt(mouse.x)
                  if (!microphoneDragTimer.running) microphoneDragTimer.restart()
                }
                onReleased: function(mouse) {
                  root.microphoneDrag = valueAt(mouse.x)
                  microphoneDragTimer.stop()
                  root.runControl("microphone", String(root.microphoneDrag))
                }
                onWheel: function(wheel) { root.runControl("microphone", wheel.angleDelta.y > 0 ? "up" : "down") }
              }
            }
            Rectangle {
              width: 44; height: 44; radius: 10
              color: root.systemData.microphoneMuted ? root.alpha(root.red, 0.28) : microphoneMuteMouse.containsMouse ? root.alpha(root.accent, 0.2) : root.surface
              Text {
                anchors.centerIn: parent
                text: root.systemData.microphoneMuted ? "󰍭" : "󰍬"
                color: root.systemData.microphoneMuted ? root.red : root.text
                font.family: root.fontFamily
                font.pixelSize: 15
              }
              MouseArea {
                id: microphoneMuteMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                  root.patchSystemData({ microphoneMuted: !root.systemData.microphoneMuted })
                  root.runControl("microphone", "mute")
                }
              }
              HoverTip { mouse: microphoneMuteMouse; text: root.systemData.microphoneMuted ? "Unmute microphone" : "Mute microphone" }
            }
          }
          Text { text: "OUTPUT DEVICE"; color: root.overlay; font.family: root.fontFamily; font.pixelSize: 9; font.bold: true }
          ListView {
            width: parent.width
            height: audioControlsWindow.outputHeight
            spacing: 4
            clip: true
            model: root.audioDevices("output")
            delegate: Rectangle {
              required property var modelData
              width: ListView.view.width; height: 28; radius: 8
              color: modelData.default ? root.alpha(root.accent, 0.2) : outputDeviceMouse.containsMouse ? root.surface : root.alpha(root.surface, 0.5)
              Row {
                anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 8
                Text { anchors.verticalCenter: parent.verticalCenter; text: modelData.default ? "󰄬" : "󰓃"; color: modelData.default ? root.accent : root.subtext; font.family: root.fontFamily; font.pixelSize: 12 }
                Text { anchors.verticalCenter: parent.verticalCenter; width: parent.width - 30; text: modelData.name; elide: Text.ElideRight; color: root.text; font.family: root.fontFamily; font.pixelSize: 10 }
              }
              MouseArea { id: outputDeviceMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.runControl("audio-device", String(parent.modelData.id)) }
            }
          }
          Text { text: "INPUT DEVICE"; color: root.overlay; font.family: root.fontFamily; font.pixelSize: 9; font.bold: true }
          ListView {
            width: parent.width
            height: audioControlsWindow.inputHeight
            spacing: 4
            clip: true
            model: root.audioDevices("input")
            delegate: Rectangle {
              required property var modelData
              width: ListView.view.width; height: 28; radius: 8
              color: modelData.default ? root.alpha(root.accent, 0.2) : inputDeviceMouse.containsMouse ? root.surface : root.alpha(root.surface, 0.5)
              Row {
                anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 8
                Text { anchors.verticalCenter: parent.verticalCenter; text: modelData.default ? "󰄬" : "󰍬"; color: modelData.default ? root.accent : root.subtext; font.family: root.fontFamily; font.pixelSize: 12 }
                Text { anchors.verticalCenter: parent.verticalCenter; width: parent.width - 30; text: modelData.name; elide: Text.ElideRight; color: root.text; font.family: root.fontFamily; font.pixelSize: 10 }
              }
              MouseArea { id: inputDeviceMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.runControl("audio-device", String(parent.modelData.id)) }
            }
          }
        }
      }
    }
  }

  // Network controls -----------------------------------------------------------
  Variants {
    model: Quickshell.screens
    PanelWindow {
      required property var modelData
      screen: modelData
      visible: root.controlPanel === "network" && root.focusedScreen(modelData)
      anchors { top: true; right: true }
      margins { top: 35; right: 5 }
      implicitWidth: 370
      implicitHeight: 242
      exclusionMode: ExclusionMode.Ignore
      color: "transparent"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "seele-shell-network"

      Rectangle {
        anchors.fill: parent; radius: 8; color: root.alpha(root.base, 0.98); border.color: root.alpha(root.accent, 0.65); border.width: 1
        Column {
          anchors.fill: parent; anchors.margins: 16; spacing: 12
          Row {
            width: parent.width; spacing: 8
            Text { width: root.systemData.wifiAvailable ? parent.width - 88 : parent.width; anchors.verticalCenter: parent.verticalCenter; text: "Network"; color: root.text; font.family: root.fontFamily; font.pixelSize: 18; font.bold: true }
            Text { visible: root.systemData.wifiAvailable; anchors.verticalCenter: parent.verticalCenter; text: "Wi-Fi"; color: root.subtext; font.family: root.fontFamily; font.pixelSize: 10 }
            ControlSwitch { visible: root.systemData.wifiAvailable; anchors.verticalCenter: parent.verticalCenter; checked: root.systemData.wifiEnabled; onToggled: root.runControl("wifi", "toggle") }
          }
          Text { text: root.systemData.connection || "Disconnected"; color: root.text; font.family: root.fontFamily; font.pixelSize: 13; font.bold: true }
          Text { text: "Connectivity: " + root.systemData.connectivity; color: root.systemData.connectivity === "full" ? root.green : root.yellow; font.family: root.fontFamily; font.pixelSize: 10 }
          Rectangle {
            width: parent.width; height: 68; radius: 11; color: root.surface
            Column {
              anchors.fill: parent; anchors.margins: 10; spacing: 6
              Text { text: "IP address    " + (root.systemData.ipAddress || "Unavailable"); color: root.text; font.family: root.fontFamily; font.pixelSize: 10 }
              Text { text: "Gateway       " + (root.systemData.gateway || "Unavailable"); color: root.subtext; font.family: root.fontFamily; font.pixelSize: 10 }
              Text { text: "Type          " + (root.systemData.connectionType || "None"); color: root.subtext; font.family: root.fontFamily; font.pixelSize: 10 }
            }
          }
          Row {
            width: parent.width; spacing: 8
            Repeater {
              model: [
                {label:"Copy IP", action:"copy-ip", value:""},
                {label:"Settings", action:"network-settings", value:""}
              ]
              Rectangle {
                required property var modelData
                width: (parent.width - 8) / 2; height: 42; radius: 10; color: networkActionMouse.containsMouse ? root.alpha(root.accent, 0.2) : root.surface
                Text { anchors.centerIn: parent; text: modelData.label; color: root.text; font.family: root.fontFamily; font.pixelSize: 10; font.bold: true }
                MouseArea { id: networkActionMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.runControl(parent.modelData.action, parent.modelData.value) }
              }
            }
          }
        }
      }
    }
  }

  // Bluetooth controls ---------------------------------------------------------
  Variants {
    model: Quickshell.screens
    PanelWindow {
      id: bluetoothWindow

      required property var modelData
      readonly property var devices: root.bluetoothDevices()
      readonly property int listHeight: Math.min(6, devices.length) * 44
      screen: modelData
      visible: root.controlPanel === "bluetooth" && root.focusedScreen(modelData)
      anchors { top: true; right: true }
      margins { top: 35; right: 5 }
      implicitWidth: 360
      implicitHeight: root.systemData.bluetoothPowered ? 124 + (devices.length === 0 ? 26 : listHeight) : 88
      exclusionMode: ExclusionMode.Ignore
      color: "transparent"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "seele-shell-bluetooth"

      Rectangle {
        anchors.fill: parent; radius: 8; color: root.alpha(root.base, 0.98); border.color: root.alpha(root.accent, 0.65); border.width: 1
        Column {
          anchors.fill: parent; anchors.margins: 16; spacing: 10
          Row {
            width: parent.width; spacing: 8
            Column {
              width: parent.width - 48
              anchors.verticalCenter: parent.verticalCenter
              spacing: 2
              Text { text: "Bluetooth"; color: root.text; font.family: root.fontFamily; font.pixelSize: 18; font.bold: true }
              Text {
                text: root.systemData.bluetoothPowered ? root.systemData.bluetoothConnected + " connected device" + (root.systemData.bluetoothConnected === 1 ? "" : "s") : "Radio is off"
                color: root.subtext
                font.family: root.fontFamily
                font.pixelSize: 11
              }
            }
            ControlSwitch { anchors.verticalCenter: parent.verticalCenter; checked: root.systemData.bluetoothPowered; onToggled: root.runControl("bluetooth", "toggle") }
          }
          Row {
            visible: root.systemData.bluetoothPowered
            width: parent.width; spacing: 8
            Text {
              width: parent.width - 48
              anchors.verticalCenter: parent.verticalCenter
              text: root.systemData.bluetoothScanning ? "Searching for devices…" : "Search for new devices"
              color: root.systemData.bluetoothScanning ? root.accent : root.subtext
              font.family: root.fontFamily
              font.pixelSize: 11
            }
            ControlSwitch { anchors.verticalCenter: parent.verticalCenter; checked: root.systemData.bluetoothScanning; onToggled: root.runBluetooth("scan", "toggle") }
          }
          ListView {
            visible: root.systemData.bluetoothPowered && bluetoothWindow.devices.length > 0
            width: parent.width
            height: bluetoothWindow.listHeight
            spacing: 4
            clip: true
            model: bluetoothWindow.devices
            delegate: Rectangle {
              required property var modelData
              readonly property bool forgetArmed: root.bluetoothForget === modelData.address
              readonly property bool rowActions: modelData.paired && (deviceMouse.containsMouse || forgetMouse.containsMouse || autoConnectMouse.containsMouse || forgetArmed)
              width: ListView.view.width; height: 40; radius: 8
              color: deviceMouse.containsMouse ? root.alpha(root.accent, 0.2) : modelData.connected ? root.alpha(root.accent, 0.1) : root.alpha(root.surface, 0.55)
              Row {
                anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 10
                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.bluetoothIcon(modelData)
                  color: modelData.connected ? root.accent : root.subtext
                  font.family: root.fontFamily
                  font.pixelSize: 15
                }
                Column {
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width - 62
                  spacing: 1
                  Text { width: parent.width; text: modelData.name; elide: Text.ElideRight; color: root.text; font.family: root.fontFamily; font.pixelSize: 11 }
                  Text {
                    width: parent.width
                    text: root.bluetoothDetail(modelData)
                    elide: Text.ElideRight
                    color: forgetArmed ? root.red : modelData.connected ? root.green : root.bluetoothBusy === modelData.address ? root.yellow : root.overlay
                    font.family: root.fontFamily
                    font.pixelSize: 9
                  }
                }
                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  visible: !rowActions
                  text: root.bluetoothSignal(modelData)
                  color: root.overlay
                  font.family: root.fontFamily
                  font.pixelSize: 11
                }
              }
              MouseArea { id: deviceMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.toggleBluetoothDevice(parent.modelData) }
              Rectangle {
                visible: rowActions
                anchors.right: parent.right
                anchors.rightMargin: 38
                anchors.verticalCenter: parent.verticalCenter
                width: 44; height: 24; radius: 12
                color: modelData.trusted ? root.alpha(root.accent, 0.3) : autoConnectMouse.containsMouse ? root.alpha(root.accent, 0.2) : root.alpha(root.surface, 0.95)
                Text { anchors.centerIn: parent; text: "Auto"; color: modelData.trusted ? root.accent : root.subtext; font.family: root.fontFamily; font.pixelSize: 9; font.bold: true }
                MouseArea { id: autoConnectMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.runBluetooth("trust", modelData.address) }
                HoverTip { mouse: autoConnectMouse; text: modelData.trusted ? "Autoconnect on" : "Autoconnect off" }
              }
              Rectangle {
                visible: rowActions
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 24; height: 24; radius: 12
                color: forgetArmed ? root.alpha(root.red, 0.3) : forgetMouse.containsMouse ? root.alpha(root.red, 0.22) : root.alpha(root.surface, 0.95)
                Text { anchors.centerIn: parent; text: "󰅖"; color: forgetArmed || forgetMouse.containsMouse ? root.red : root.subtext; font.family: root.fontFamily; font.pixelSize: 11 }
                MouseArea { id: forgetMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.forgetBluetoothDevice(modelData) }
              }
            }
          }
          Text {
            visible: root.systemData.bluetoothPowered && bluetoothWindow.devices.length === 0
            width: parent.width
            text: root.systemData.bluetoothScanning ? "Looking for nearby devices…" : "No devices yet · turn on search"
            color: root.overlay
            font.family: root.fontFamily
            font.pixelSize: 10
          }
        }
      }
    }
  }

  // AirPods controls -----------------------------------------------------------
  Variants {
    model: Quickshell.screens
    PanelWindow {
      required property var modelData
      screen: modelData
      visible: root.controlPanel === "airpods" && root.focusedScreen(modelData)
      anchors { top: true; right: true }
      margins { top: 35; right: 5 }
      implicitWidth: 340
      implicitHeight: 252
      exclusionMode: ExclusionMode.Ignore
      color: "transparent"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "seele-shell-airpods"

      Rectangle {
        anchors.fill: parent; radius: 8; color: root.alpha(root.base, 0.98); border.color: root.alpha(root.accent, 0.65); border.width: 1
        Column {
          anchors.fill: parent; anchors.margins: 16; spacing: 10
          Row {
            width: parent.width; spacing: 8
            AirpodsIcon { anchors.verticalCenter: parent.verticalCenter; width: 22; height: 22; tint: root.accent }
            Column {
              width: parent.width - 32
              anchors.verticalCenter: parent.verticalCenter
              spacing: 2
              Text { text: root.systemData.airpodsName || "AirPods"; elide: Text.ElideRight; width: parent.width; color: root.text; font.family: root.fontFamily; font.pixelSize: 16; font.bold: true }
              Text {
                text: root.airpodsBatteryText() || "Connected"
                color: root.subtext
                font.family: root.fontFamily
                font.pixelSize: 11
              }
            }
          }
          Text { text: "NOISE CONTROL"; color: root.overlay; font.family: root.fontFamily; font.pixelSize: 9; font.bold: true }
          Row {
            width: parent.width; spacing: 6
            Repeater {
              model: [{label:"Off", mode:"off"}, {label:"ANC", mode:"anc"}, {label:"Aware", mode:"transparency"}, {label:"Adaptive", mode:"adaptive"}]
              Rectangle {
                required property var modelData
                width: (parent.width - 18) / 4; height: 40; radius: 8
                color: airpodsModeMouse.containsMouse ? root.alpha(root.accent, 0.22) : root.surface
                Text { anchors.centerIn: parent; text: modelData.label; color: root.text; font.family: root.fontFamily; font.pixelSize: 9; font.bold: true }
                MouseArea { id: airpodsModeMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.runControl("airpods", parent.modelData.mode) }
              }
            }
          }
          Row {
            width: parent.width; spacing: 8
            Column {
              width: parent.width - 48
              anchors.verticalCenter: parent.verticalCenter
              spacing: 1
              Text { text: "Auto play and pause"; color: root.text; font.family: root.fontFamily; font.pixelSize: 11 }
              Text { text: "Ear detection through librepods"; color: root.overlay; font.family: root.fontFamily; font.pixelSize: 9 }
            }
            ControlSwitch {
              anchors.verticalCenter: parent.verticalCenter
              checked: root.systemData.airpodsEarDetection
              onToggled: root.runControl("airpods", "ear-detection", "toggle")
            }
          }
          Rectangle {
            width: parent.width; height: 38; radius: 8; color: airpodsDetailsMouse.containsMouse ? root.alpha(root.accent, 0.2) : root.surface
            Text { anchors.centerIn: parent; text: "Battery and AirPods settings"; color: root.text; font.family: root.fontFamily; font.pixelSize: 10; font.bold: true }
            MouseArea { id: airpodsDetailsMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.runControl("airpods", "open") }
          }
        }
      }
    }
  }

  // Battery ---------------------------------------------------------------------
  Variants {
    model: Quickshell.screens
    PanelWindow {
      id: batteryWindow

      required property var modelData
      readonly property var entries: root.batteryEntries()
      screen: modelData
      visible: root.controlPanel === "battery" && root.focusedScreen(modelData)
      anchors { top: true; right: true }
      margins { top: 35; right: 5 }
      implicitWidth: 330
      implicitHeight: 74 + Math.max(1, Math.min(5, entries.length)) * 50
      exclusionMode: ExclusionMode.Ignore
      color: "transparent"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "seele-shell-battery"

      Rectangle {
        anchors.fill: parent; radius: 8; color: root.alpha(root.base, 0.98); border.color: root.alpha(root.accent, 0.65); border.width: 1
        Column {
          anchors.fill: parent; anchors.margins: 16; spacing: 10
          Text { text: "Batteries"; color: root.text; font.family: root.fontFamily; font.pixelSize: 18; font.bold: true }
          ListView {
            visible: batteryWindow.entries.length > 0
            width: parent.width
            height: Math.min(5, batteryWindow.entries.length) * 50
            spacing: 6
            clip: true
            model: batteryWindow.entries
            delegate: Column {
              required property var modelData
              width: ListView.view.width
              spacing: 5
              Row {
                width: parent.width; spacing: 8
                Text { anchors.verticalCenter: parent.verticalCenter; text: root.batteryIcon(modelData); color: root.batteryColor(modelData); font.family: root.fontFamily; font.pixelSize: 14 }
                Text { anchors.verticalCenter: parent.verticalCenter; width: parent.width - 90; text: modelData.name; elide: Text.ElideRight; color: root.text; font.family: root.fontFamily; font.pixelSize: 11 }
                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  width: 60
                  text: Number(modelData.percent) + "%" + (root.batteryCharging(modelData) ? " ⚡" : "")
                  color: root.batteryColor(modelData)
                  font.family: root.fontFamily
                  font.pixelSize: 11
                  horizontalAlignment: Text.AlignRight
                }
              }
              Rectangle {
                width: parent.width; height: 7; radius: 4; color: root.surface
                Rectangle {
                  width: parent.width * Math.max(0, Math.min(1, Number(modelData.percent) / 100))
                  height: parent.height
                  radius: 4
                  color: root.batteryColor(modelData)
                }
              }
            }
          }
          Text {
            visible: batteryWindow.entries.length === 0
            text: "No batteries reported"
            color: root.overlay
            font.family: root.fontFamily
            font.pixelSize: 10
          }
        }
      }
    }
  }

  // Notification center --------------------------------------------------------
  Variants {
    model: Quickshell.screens
    PanelWindow {
      id: notificationWindow

      required property var modelData
      readonly property var entries: root.notificationHistoryOpen
        ? (root.systemData.notifications.history || [])
        : (root.systemData.notifications.items || [])
      screen: modelData
      visible: root.controlPanel === "notifications" && root.focusedScreen(modelData)
      anchors { top: true; right: true }
      margins { top: 35; right: 5 }
      implicitWidth: 400
      implicitHeight: Math.min(520, 142 + Math.max(1, entries.length) * 66)
      exclusionMode: ExclusionMode.Ignore
      color: "transparent"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "seele-shell-notifications"

      Rectangle {
        anchors.fill: parent; radius: 8; color: root.alpha(root.base, 0.98); border.color: root.alpha(root.accent, 0.65); border.width: 1
        Column {
          anchors.fill: parent; anchors.margins: 16; spacing: 10
          Row {
            width: parent.width
            Text {
              width: parent.width - 120
              anchors.verticalCenter: parent.verticalCenter
              text: root.notificationHistoryOpen ? "Last 24 hours" : "Notifications"
              color: root.text
              font.family: root.fontFamily
              font.pixelSize: 18
              font.bold: true
            }
            Text { width: 40; anchors.verticalCenter: parent.verticalCenter; text: String(notificationWindow.entries.length); color: root.subtext; font.family: root.fontFamily; font.pixelSize: 11; horizontalAlignment: Text.AlignRight }
            Text { width: 40; anchors.verticalCenter: parent.verticalCenter; leftPadding: 10; text: "DND"; color: root.systemData.dnd ? root.yellow : root.subtext; font.family: root.fontFamily; font.pixelSize: 10 }
            ControlSwitch { anchors.verticalCenter: parent.verticalCenter; checked: root.systemData.dnd; onToggled: root.runControl("dnd", "") }
          }
          Row {
            width: parent.width; spacing: 8
            Rectangle {
              width: (parent.width - 8) / 2; height: 36; radius: 8
              color: root.notificationHistoryOpen ? root.alpha(root.accent, 0.25) : historyMouse.containsMouse ? root.alpha(root.accent, 0.2) : root.surface
              Text {
                anchors.centerIn: parent
                text: root.notificationHistoryOpen ? "Back" : "History"
                color: root.text
                font.family: root.fontFamily
                font.pixelSize: 10
                font.bold: true
              }
              MouseArea { id: historyMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.notificationHistoryOpen = !root.notificationHistoryOpen }
              HoverTip { mouse: historyMouse; text: root.notificationHistoryOpen ? "Show current notifications" : "Show the past 24 hours" }
            }
            Rectangle {
              width: (parent.width - 8) / 2; height: 36; radius: 8
              color: clearMouse.containsMouse ? root.alpha(root.accent, 0.2) : root.surface
              Text { anchors.centerIn: parent; text: "Clear"; color: root.text; font.family: root.fontFamily; font.pixelSize: 10; font.bold: true }
              MouseArea { id: clearMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.runControl("notifications", "clear") }
            }
          }
          ListView {
            visible: notificationWindow.entries.length > 0
            width: parent.width
            height: parent.height - 78
            spacing: 6
            clip: true
            model: notificationWindow.entries
            delegate: Rectangle {
              id: notificationEntry

              required property var modelData
              width: ListView.view.width; height: 60; radius: 8; color: root.surface
              Column {
                anchors.fill: parent; anchors.margins: 9; spacing: 3
                Row {
                  width: parent.width
                  Text { width: parent.width - 84; text: modelData.summary || modelData.app_name || "Notification"; elide: Text.ElideRight; color: root.text; font.family: root.fontFamily; font.pixelSize: 11; font.bold: true }
                  Text { width: 58; text: root.agoText(modelData.time); color: root.overlay; font.family: root.fontFamily; font.pixelSize: 9; horizontalAlignment: Text.AlignRight }
                  Rectangle {
                    visible: !root.notificationHistoryOpen
                    width: visible ? 26 : 0; height: 20; radius: 6
                    color: notificationDismissMouse.containsMouse ? root.alpha(root.red, 0.22) : "transparent"
                    Text { anchors.centerIn: parent; text: "󰅖"; color: notificationDismissMouse.containsMouse ? root.red : root.subtext; font.family: root.fontFamily; font.pixelSize: 10 }
                    MouseArea {
                      id: notificationDismissMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      onClicked: root.runControl("notifications", "dismiss", String(notificationEntry.modelData.id))
                    }
                  }
                }
                Text { width: parent.width; text: modelData.body || modelData.app_name || ""; elide: Text.ElideRight; color: root.subtext; font.family: root.fontFamily; font.pixelSize: 9 }
              }
            }
          }
          Text {
            visible: notificationWindow.entries.length === 0
            width: parent.width
            text: root.notificationHistoryOpen ? "Nothing arrived in the past 24 hours" : "No notifications right now"
            color: root.overlay
            font.family: root.fontFamily
            font.pixelSize: 10
          }
        }
      }
    }
  }
  // Camera controls ------------------------------------------------------------
  Variants {
    model: Quickshell.screens
    PanelWindow {
      id: cameraWindow

      required property var modelData
      screen: modelData
      visible: root.controlPanel === "camera" && root.focusedScreen(modelData)
      anchors { top: true; right: true }
      margins { top: 35; right: 5 }
      implicitWidth: 360
      implicitHeight: 348
      exclusionMode: ExclusionMode.Ignore
      color: "transparent"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "seele-shell-camera"

      Rectangle {
        anchors.fill: parent; radius: 8; color: root.alpha(root.base, 0.98); border.color: root.alpha(root.accent, 0.65); border.width: 1
        Column {
          anchors.fill: parent; anchors.margins: 16; spacing: 12
          Text { text: "Webcam"; color: root.text; font.family: root.fontFamily; font.pixelSize: 18; font.bold: true }
          Text { text: root.systemData.cameraActive ? "Camera is in use" : root.systemData.cameraDevices.length + " camera device" + (root.systemData.cameraDevices.length === 1 ? "" : "s"); color: root.systemData.cameraActive ? root.red : root.subtext; font.family: root.fontFamily; font.pixelSize: 11 }
          Text { width: parent.width; text: root.systemData.cameraDevices.length > 0 ? root.systemData.cameraDevices[0].name : "No camera detected"; elide: Text.ElideRight; color: root.text; font.family: root.fontFamily; font.pixelSize: 10 }
          Rectangle {
            width: parent.width; height: 176; radius: 8; color: root.mantle; clip: true
            Loader {
              id: cameraPreviewLoader
              anchors.fill: parent
              active: root.systemData.cameraDevices.length > 0
              asynchronous: true
              source: "CameraPreview.qml"
            }
            Binding {
              target: cameraPreviewLoader.item
              property: "device"
              value: root.systemData.cameraDevice
              when: cameraPreviewLoader.status === Loader.Ready
            }
            Binding {
              target: cameraPreviewLoader.item
              property: "active"
              value: cameraWindow.visible
              when: cameraPreviewLoader.status === Loader.Ready
            }
            Text {
              anchors.centerIn: parent
              visible: cameraPreviewLoader.status !== Loader.Ready || !(cameraPreviewLoader.item && cameraPreviewLoader.item.ready)
              text: root.systemData.cameraDevices.length === 0 ? "No camera detected" : root.systemData.cameraActive ? "Camera in use by another app" : cameraPreviewLoader.status === Loader.Ready ? "Starting camera…" : "Preview unavailable"
              color: root.overlay
              font.family: root.fontFamily
              font.pixelSize: 10
            }
          }
          Row {
            width: parent.width; spacing: 8
            Repeater {
              model: [{label:"Preview window", action:"camera-preview"}, {label:"Camera settings", action:"camera-settings"}]
              Rectangle {
                required property var modelData
                width: (parent.width - 8) / 2; height: 42; radius: 8; color: cameraActionMouse.containsMouse ? root.alpha(root.accent, 0.2) : root.surface
                Text { anchors.centerIn: parent; text: modelData.label; color: root.text; font.family: root.fontFamily; font.pixelSize: 10; font.bold: true }
                MouseArea { id: cameraActionMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.runControl(parent.modelData.action, root.systemData.cameraDevice) }
              }
            }
          }
        }
      }
    }
  }

  // Session controls -----------------------------------------------------------
  Variants {
    model: Quickshell.screens
    PanelWindow {
      required property var modelData
      screen: modelData
      visible: root.controlPanel === "system" && root.focusedScreen(modelData)
      anchors { top: true; right: true }
      margins { top: 35; right: 5 }
      implicitWidth: 420
      implicitHeight: 220
      exclusionMode: ExclusionMode.Ignore
      color: "transparent"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "seele-shell-session"

      Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: 8
        antialiasing: true
        color: root.alpha(root.base, 0.98)
        border.color: root.alpha(root.accent, 0.65)
        border.width: 1
        Column {
          anchors.fill: parent; anchors.margins: 16; spacing: 12
          Text { text: "Power"; color: root.text; font.family: root.fontFamily; font.pixelSize: 18; font.bold: true }
          Grid {
            width: parent.width
            columns: 3
            columnSpacing: 8
            rowSpacing: 8
            Repeater {
              model: [
                {label:(root.windowsCountdown >= 0 ? "Windows · " + root.windowsCountdown + "s" : "Windows"), icon:"󰍲", action:"reboot-windows", variant:"outline"},
                {label:"Lock", icon:"󰌾", action:"lock", variant:"default"},
                {label:"Log out", icon:"󰍃", action:"logout", variant:"default"},
                {label:"Suspend", icon:"󰒲", action:"lock-suspend", variant:"default"},
                {label:"Reboot", icon:"󰜉", action:"reboot", variant:"default"},
                {label:"Shut down", icon:"󰐥", action:"shutdown", variant:"destructive"}
              ]
              Rectangle {
                required property var modelData
                width: (parent.width - 16) / 3; height: 72; radius: 8
                color: modelData.variant === "destructive" ? (sessionActionMouse.containsMouse ? root.alpha(root.red, 0.28) : root.alpha(root.red, 0.14)) : sessionActionMouse.containsMouse ? root.alpha(root.accent, 0.2) : root.surface
                border.width: modelData.variant === "outline" ? 1 : 0
                border.color: root.windowsCountdown >= 0 && modelData.action === "reboot-windows" ? root.yellow : root.accent
                Column {
                  anchors.centerIn: parent
                  spacing: 4
                  Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.icon; color: modelData.variant === "destructive" ? root.red : modelData.action === "reboot-windows" && root.windowsCountdown >= 0 ? root.yellow : root.accent; font.family: root.fontFamily; font.pixelSize: 18 }
                  Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.label; color: root.text; font.family: root.fontFamily; font.pixelSize: 10; font.bold: true }
                }
                MouseArea {
                  id: sessionActionMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  onClicked: {
                    if (parent.modelData.action === "reboot-windows") root.toggleWindowsReboot()
                    else {
                      root.closeOverlays()
                      root.runControl(parent.modelData.action)
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  // Shell OSD ------------------------------------------------------------------
  Variants {
    model: Quickshell.screens
    PanelWindow {
      required property var modelData
      screen: modelData
      visible: root.osdOpen && root.focusedScreen(modelData)
      anchors { top: true }
      margins.top: 46
      implicitWidth: 300
      implicitHeight: 58
      exclusionMode: ExclusionMode.Ignore
      color: "transparent"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "seele-shell-osd"
      Rectangle {
        anchors.fill: parent; radius: 8; color: root.alpha(root.base, 0.96); border.color: root.alpha(root.accent, 0.65); border.width: 1
        Row {
          visible: root.osdKind === "volume"
          anchors.fill: parent; anchors.margins: 14; spacing: 12
          Text { anchors.verticalCenter: parent.verticalCenter; text: root.systemData.muted ? "󰝟" : "󰕾"; color: root.systemData.muted ? root.red : root.accent; font.family: root.fontFamily; font.pixelSize: 20 }
          Rectangle {
            width: 205; height: 8; anchors.verticalCenter: parent.verticalCenter; radius: 4; color: root.surface
            Rectangle { width: parent.width * Math.max(0, Math.min(1, Number(root.systemData.volume) / 100)); height: parent.height; radius: 4; color: root.accent }
          }
          Text { anchors.verticalCenter: parent.verticalCenter; text: root.systemData.volume + "%"; color: root.text; font.family: root.fontFamily; font.pixelSize: 11 }
        }
        Row {
          visible: root.osdKind === "airpods"
          anchors.fill: parent; anchors.margins: 14; spacing: 12
          AirpodsIcon { anchors.verticalCenter: parent.verticalCenter; width: 22; height: 22; tint: root.airpodsOsdConnected ? root.accent : root.subtext }
          Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 34
            spacing: 2
            Text { width: parent.width; text: root.airpodsOsdName; elide: Text.ElideRight; color: root.text; font.family: root.fontFamily; font.pixelSize: 12; font.bold: true }
            Text { text: root.airpodsOsdConnected ? (root.airpodsBatteryText() || "Connected") : "Disconnected"; color: root.airpodsOsdConnected ? root.green : root.subtext; font.family: root.fontFamily; font.pixelSize: 9 }
          }
        }
        Row {
          visible: root.osdKind === "yubikey"
          anchors.fill: parent; anchors.margins: 14; spacing: 12
          Text { anchors.verticalCenter: parent.verticalCenter; text: ""; color: root.yellow; font.family: root.fontFamily; font.pixelSize: 20 }
          Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 34
            spacing: 2
            Text { text: "Touch your YubiKey"; color: root.text; font.family: root.fontFamily; font.pixelSize: 12; font.bold: true }
            Text { text: "Waiting for hardware confirmation"; color: root.subtext; font.family: root.fontFamily; font.pixelSize: 9 }
          }
        }
      }
    }
  }
}
