//@ pragma UseQApplication

import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import Quickshell.Widgets
import "media.js" as Media
import "time.js" as Time

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

  // Shared shape and surface tokens. Hyprland rounds windows at 8px, so every
  // panel, button, and bar entry rounds the same way, and each hover, press,
  // and selection tint is defined once instead of per widget.
  readonly property int radius: 8
  readonly property int radiusSmall: 6
  readonly property int barHeight: 30
  readonly property int barItemHeight: 22
  readonly property int barSpacing: 2
  readonly property int barPadding: 4
  readonly property int panelGap: 5
  readonly property int osdGap: 16
  readonly property int panelMargin: 16
  readonly property int panelSpacing: 10
  readonly property int scrollGutter: 8
  readonly property int scrollInset: 4
  readonly property int panelHeaderHeight: 28
  // Text needs more contrast than decorative borders and inactive glyphs.
  readonly property color mutedText: subtext
  // Textured chrome. Surfaces stay translucent so the compositor's blur
  // shows through, a quiet vertical wash gives them depth, and a fixed grain
  // film keeps a large panel from reading as flat plastic.
  readonly property string grain: "grain.png"
  readonly property real grainOpacity: 0.05
  readonly property color panelColor: alpha(base, 0.86)
  readonly property color panelBorder: alpha(accent, 0.65)
  readonly property color hoverColor: alpha(accent, 0.18)
  readonly property color pressColor: alpha(accent, 0.42)
  readonly property color selectedColor: alpha(accent, 0.24)
  readonly property color activeTint: alpha(accent, 0.14)
  readonly property color fillColor: alpha(accent, 0.45)
  readonly property color fillDanger: alpha(red, 0.45)
  readonly property color successColor: alpha(green, 0.25)
  readonly property color dangerTint: alpha(red, 0.14)
  readonly property color dangerColor: alpha(red, 0.28)
  readonly property color dangerPress: alpha(red, 0.48)

  property bool agentsOpen: false
  // Panels stay on the screen they were opened from. Tracking Hyprland's
  // focused monitor instead would move an open panel to another output the
  // moment the pointer crossed a screen edge.
  property string overlayScreen: ""
  property string osdScreen: ""
  property string controlPanel: ""
  property bool trayMenuOpen: false
  property bool trayExpanded: false
  property int volumeDrag: -1
  property int microphoneDrag: -1
  property bool agentUsageOpen: false
  property bool agentModelsOpen: false
  property bool notificationHistoryOpen: false
  property string temporaryTimezone: ""
  property var clockData: ({ pinned: [], zones: [] })
  property var activeTrayItem: null
  property bool osdOpen: false
  property string osdKind: "volume"
  property bool airpodsOsdConnected: false
  property string airpodsOsdName: "AirPods"
  property var yubikeyTouchSources: ({})
  property bool yubikeyTouchRequired: false
  property bool statusInitialized: false
  property bool statusRefreshQueued: false
  property bool bluetoothStatusRefreshQueued: false
  property string pendingControlAction: ""
  property string pendingControlValue: ""
  property string pendingControlExtra: ""
  property string completedControlAction: ""
  property string completedControlValue: ""
  property string completedControlExtra: ""
  property string failedControlAction: ""
  property string failedControlValue: ""
  property string failedControlExtra: ""
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
    tailscale: { available: false, backend: "Unavailable", connected: false, needsLogin: false, name: "", ip: "", tailnet: "", peers: 0, onlinePeers: 0 },
    protonVpn: { available: false, connected: false, connection: "" },
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
  property string bluetoothAction: ""
  property int bluetoothScanIntent: -1
  property int bluetoothScanQueued: -1
  readonly property bool bluetoothScanActive: bluetoothScanIntent >= 0 ? bluetoothScanIntent === 1 : !!systemData.bluetoothScanning
  property string bluetoothForget: ""
  property string agentError: ""
  property var speedtestData: ({ ping: -1, jitter: -1, download: -1, upload: -1, server: "" })
  property string speedtestError: ""
  property string speedtestPhase: ""
  property bool speedtestReceived: false
  property date now: new Date()

  function alpha(color, opacity) {
    return Qt.rgba(color.r, color.g, color.b, opacity)
  }

  function focusedScreen(screen) {
    return !Hyprland.focusedMonitor || Hyprland.focusedMonitor.name === screen.name
  }

  function currentScreen() {
    return Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
  }

  function pinnedScreen(pin, screen) {
    if (!screen) return false
    return pin === "" ? focusedScreen(screen) : pin === screen.name
  }

  function panelHere(panel, screen) {
    return controlPanel === panel && pinnedScreen(overlayScreen, screen)
  }

  function agentsHere(screen) {
    return agentsOpen && pinnedScreen(overlayScreen, screen)
  }

  function closeTrayMenu() {
    trayMenuOpen = false
    activeTrayItem = null
  }

  function closeOverlays() {
    agentsOpen = false
    controlPanel = ""
    overlayScreen = ""
    closeTrayMenu()
    windowsCountdown = -1
    windowsTimer.stop()
    bluetoothForget = ""
    notificationHistoryOpen = false
    bluetoothForgetTimer.stop()
  }

  function toggleLauncher(mode) {
    closeOverlays()
    Quickshell.execDetached(["seele-control", "launcher-toggle"])
  }

  function toggleAgents(screen) {
    var shouldOpen = !agentsOpen
    closeOverlays()
    agentsOpen = shouldOpen
    if (!agentsOpen) return
    overlayScreen = screen || currentScreen()
    if (!agentData.generatedAt || agentError !== "") refreshAgents()
  }

  function toggleControl(panel, screen) {
    var shouldOpen = controlPanel !== panel
    closeOverlays()
    controlPanel = shouldOpen ? panel : ""
    if (controlPanel === "") return
    overlayScreen = screen || currentScreen()
    refreshStatus()
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
    if (statusProcess.running) root.statusRefreshQueued = true
    else statusProcess.running = true
  }

  function refreshBluetoothStatus() {
    if (bluetoothStatusProcess.running) root.bluetoothStatusRefreshQueued = true
    else bluetoothStatusProcess.running = true
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
        if (root.volumeDrag >= 0 && Number(parsed.volume) === root.volumeDrag) root.volumeDrag = -1
        if (root.microphoneDrag >= 0 && Number(parsed.microphoneVolume) === root.microphoneDrag) root.microphoneDrag = -1
        root.reconcileBluetoothScanIntent(!!parsed.bluetoothScanning)
      }
    } catch (error) {
      console.warn("seele-shell/status", error)
    }
  }

  function parseBluetoothData(output) {
    try {
      var parsed = JSON.parse(String(output || ""))
      if (!parsed) return
      root.patchSystemData({
        bluetoothAvailable: !!parsed.available,
        bluetoothPowered: !!parsed.powered,
        bluetoothScanning: !!parsed.scanning,
        bluetoothConnected: Number(parsed.connected || 0),
        bluetoothDevices: parsed.devices || [],
        airpodsConnected: !!parsed.airpodsConnected,
        airpodsName: String(parsed.airpodsName || "")
      })
      root.reconcileBluetoothScanIntent(!!parsed.scanning)
    } catch (error) {
      console.warn("seele-shell/bluetooth-status", error)
    }
  }

  function reconcileBluetoothScanIntent(scanning) {
    if (root.bluetoothScanIntent >= 0 && scanning === (root.bluetoothScanIntent === 1)) root.bluetoothScanIntent = -1
    if (!scanning) bluetoothScanTimer.stop()
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

  function activateWorkspace(id) {
    var values = Hyprland.workspaces.values || []
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) {
        values[i].activate()
        return
      }
    }
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

  function windowClasses(window) {
    if (!window) return []
    var ipc = window.lastIpcObject || {}
    var candidates = [ipc.class, ipc.initialClass, window.appId]
    var classes = []
    for (var i = 0; i < candidates.length; i++) {
      var appId = String(candidates[i] || "").trim()
      if (appId !== "") classes.push(appId)
    }
    return classes
  }

  function windowIcon(window) {
    if (DesktopEntries.applications.values.length === 0) return ""
    var classes = root.windowClasses(window)
    for (var i = 0; i < classes.length; i++) {
      var entry = DesktopEntries.heuristicLookup(classes[i])
      if (entry && entry.icon) return Quickshell.iconPath(String(entry.icon))
    }
    return ""
  }

  // Window titles follow the document, not the application: Spotify names the
  // playing track and browsers name the page. Always label the entry with the app.
  function windowAppName(window) {
    var classes = root.windowClasses(window)
    for (var i = 0; i < classes.length; i++) {
      var entry = DesktopEntries.heuristicLookup(classes[i])
      if (entry && String(entry.name || "") !== "") return String(entry.name)
    }
    if (classes.length === 0) return ""
    var fallback = classes[0].split(".").pop().replace(/[-_]+/g, " ").trim()
    return fallback === "" ? "" : fallback.charAt(0).toUpperCase() + fallback.slice(1)
  }

  function windowLabel(window) {
    return root.windowAppName(window) || root.windowTitle(window)
  }

  function spotifyPlayer() {
    return Media.spotifyPlayer(Mpris.players.values || [])
  }

  function devicePlayer() {
    return Media.devicePlayer(Mpris.players.values || [])
  }

  function mediaLabel(player) {
    return Media.label(player)
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
    if (root.bluetoothBusy === device.address) {
      if (root.bluetoothAction === "trust") return "Updating autoconnect…"
      if (root.bluetoothAction === "forget") return "Forgetting…"
      return device.connected ? "Disconnecting…" : device.paired ? "Connecting…" : "Pairing…"
    }
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
    if (bluetoothProcess.running) return false
    root.bluetoothAction = String(command)
    if (command !== "scan" && command !== "toggle") root.bluetoothBusy = String(value || "")
    bluetoothProcess.command = ["seele-control", "bluetooth", String(command), String(value || "")]
    bluetoothProcess.running = true
    return true
  }

  function setBluetoothScanning(active) {
    root.bluetoothScanIntent = active ? 1 : 0
    if (active) bluetoothScanTimer.restart()
    else bluetoothScanTimer.stop()
    if (bluetoothProcess.running) {
      root.bluetoothScanQueued = active ? 1 : 0
      return
    }
    root.runBluetooth("scan", active ? "on" : "off")
  }

  function toggleBluetoothPower() {
    var powered = !root.systemData.bluetoothPowered
    if (!root.runBluetooth("toggle", "")) return
    root.patchSystemData({ bluetoothPowered: powered })
    if (!powered) {
      root.bluetoothScanIntent = 0
      bluetoothScanTimer.stop()
    }
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
    var id = String(item.id)
    if (!root.runControl("tray", "toggle", id)) return
    var hidden = root.trayHiddenIds().slice()
    var index = hidden.indexOf(id)
    if (index >= 0) hidden.splice(index, 1)
    else hidden.push(id)
    root.patchSystemData({ trayHidden: hidden })
  }

  function setAudioDevice(id) {
    id = String(id)
    if (!root.runControl("audio-device", id)) return
    var devices = root.systemData.audioDevices || []
    var kind = ""
    for (var i = 0; i < devices.length; i++) if (String(devices[i].id) === id) kind = devices[i].kind
    var updated = []
    for (var j = 0; j < devices.length; j++) {
      var device = {}
      for (var key in devices[j]) device[key] = devices[j][key]
      if (device.kind === kind) device.default = String(device.id) === id
      updated.push(device)
    }
    root.patchSystemData({ audioDevices: updated })
  }

  function openCameraPreview(device) {
    cameraPreviewLaunchTimer.device = String(device || "")
    root.controlPanel = ""
    cameraPreviewLaunchTimer.restart()
  }

  function dismissNotification(id) {
    id = String(id)
    if (!root.runControl("notifications", "dismiss", id)) return
    var notifications = root.systemData.notifications || { count: 0, items: [], history: [] }
    var items = []
    for (var i = 0; i < (notifications.items || []).length; i++) {
      if (String(notifications.items[i].id) !== id) items.push(notifications.items[i])
    }
    root.patchSystemData({ notifications: { count: items.length, items: items, history: notifications.history || [] } })
  }

  function clearNotifications() {
    if (!root.runControl("notifications", "clear")) return
    root.patchSystemData({ notifications: { count: 0, items: [], history: [] } })
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

  function privateNetworkActive() {
    return !!(root.systemData.tailscale && root.systemData.tailscale.connected)
      || !!(root.systemData.protonVpn && root.systemData.protonVpn.connected)
  }

  function tailscaleDetail() {
    var state = root.systemData.tailscale || {}
    if (!state.available || state.backend === "Unavailable") return "Service unavailable"
    if (state.needsLogin) return "Sign in required"
    if (!state.connected) return "Disconnected"
    var identity = state.tailnet || state.ip || state.name || "Connected"
    return identity + " · " + Number(state.onlinePeers || 0) + "/" + Number(state.peers || 0) + " peers online"
  }

  function protonVpnDetail() {
    var state = root.systemData.protonVpn || {}
    if (!state.available) return "Client unavailable"
    return state.connected ? (state.connection || "Connected") : "Disconnected · fastest server on connect"
  }

  function startSpeedtest() {
    if (speedtestProcess.running) return
    root.speedtestError = ""
    root.speedtestPhase = "selecting"
    root.speedtestReceived = false
    root.speedtestData = { ping: -1, jitter: -1, download: -1, upload: -1, server: "" }
    speedtestProcess.running = true
  }

  function patchSpeedtestData(patch) {
    var next = {}
    for (var key in root.speedtestData) next[key] = root.speedtestData[key]
    for (var field in patch) next[field] = patch[field]
    root.speedtestData = next
  }

  function handleSpeedtestEvent(output) {
    try {
      var parsed = JSON.parse(String(output || ""))
      if (parsed.phase) {
        root.speedtestPhase = String(parsed.phase)
        var patch = {}
        if (parsed.ping !== undefined) patch.ping = Number(parsed.ping)
        if (parsed.jitter !== undefined) patch.jitter = Number(parsed.jitter)
        if (parsed.download !== undefined) patch.download = Number(parsed.download)
        if (parsed.upload !== undefined) patch.upload = Number(parsed.upload)
        root.patchSpeedtestData(patch)
      } else {
        root.parseSpeedtestData(output)
      }
    } catch (error) {
      root.speedtestError = "Speed test failed"
    }
  }

  function parseSpeedtestData(output) {
    try {
      var parsed = JSON.parse(String(output || ""))
      var ping = Number(parsed.ping)
      var download = Number(parsed.download)
      var upload = Number(parsed.upload)
      if (isNaN(ping) || isNaN(download) || isNaN(upload)) throw new Error("missing speed values")
      root.speedtestData = {
        ping: ping,
        jitter: Number(parsed.jitter || 0),
        download: download,
        upload: upload,
        server: String(parsed.server || "Ookla Speedtest")
      }
      root.speedtestReceived = true
      root.speedtestError = ""
      root.speedtestPhase = ""
    } catch (error) {
      root.speedtestReceived = false
      root.speedtestError = "Speed test failed"
      root.speedtestPhase = ""
    }
  }

  function speedtestPingText() {
    if (root.speedtestError !== "") return "Failed"
    var ping = Number(root.speedtestData.ping)
    if (ping >= 0) return ping.toFixed(1) + " ms"
    if (root.speedtestPhase === "selecting") return "Locating…"
    if (root.speedtestPhase === "ping") return "Measuring…"
    return "—"
  }

  function speedtestScale() {
    var maximum = Math.max(Number(root.speedtestData.download || 0), Number(root.speedtestData.upload || 0))
    if (maximum <= 100) return 100
    if (maximum <= 250) return 250
    if (maximum <= 500) return 500
    if (maximum <= 1000) return 1000
    return Math.ceil(maximum / 1000) * 1000
  }

  function speedtestValue(value) {
    value = Number(value)
    if (value < 0 || isNaN(value)) return "—"
    return value.toFixed(value >= 100 ? 0 : 1) + " Mbps"
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
    root.osdScreen = root.currentScreen()
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
      root.osdScreen = root.currentScreen()
      root.osdOpen = true
    } else if (root.osdKind === "yubikey") {
      root.osdOpen = false
    }
  }

  function startOsSession() {
    closeOverlays()
    Quickshell.execDetached(["seele-os-session"])
  }

  function runAgent(id, prompt) {
    agentsOpen = false
    var args = ["seele-agent", id || "pi"]
    if (String(prompt || "").trim() !== "") args.push(String(prompt).trim())
    Quickshell.execDetached(args)
  }

  function controlArgument(value) {
    return value === undefined || value === null ? "" : String(value)
  }

  function controlBusy(action, value, extra) {
    return root.pendingControlAction === String(action)
      && root.pendingControlValue === root.controlArgument(value)
      && root.pendingControlExtra === root.controlArgument(extra)
  }

  function controlCompleted(action, value, extra) {
    return root.completedControlAction === String(action)
      && root.completedControlValue === root.controlArgument(value)
      && root.completedControlExtra === root.controlArgument(extra)
  }

  function controlFailed(action, value, extra) {
    return root.failedControlAction === String(action)
      && root.failedControlValue === root.controlArgument(value)
      && root.failedControlExtra === root.controlArgument(extra)
  }

  function runControl(action, value, extra) {
    if (controlProcess.running) return false
    var controlValue = root.controlArgument(value)
    var controlExtra = root.controlArgument(extra)
    var args = ["seele-control", action]
    if (controlValue !== "") args.push(controlValue)
    if (controlExtra !== "") args.push(controlExtra)
    root.pendingControlAction = String(action)
    root.pendingControlValue = controlValue
    root.pendingControlExtra = controlExtra
    root.completedControlAction = ""
    root.failedControlAction = ""
    controlProcess.command = args
    controlProcess.running = true
    if (action === "volume") root.showTimedOsd("volume")
    return true
  }

  function audioWheelSteps(wheel) {
    var angle = Number(wheel.angleDelta.y)
    if (angle !== 0) return (angle > 0 ? 1 : -1) * Math.max(1, Math.round(Math.abs(angle) / 120))
    var pixels = Number(wheel.pixelDelta.y)
    return pixels === 0 ? 0 : pixels > 0 ? 1 : -1
  }

  function adjustAudioFromWheel(wheel, microphone) {
    var steps = root.audioWheelSteps(wheel)
    if (steps === 0) return
    var dragged = microphone ? root.microphoneDrag : root.volumeDrag
    var reported = Number(microphone ? root.systemData.microphoneVolume : root.systemData.volume)
    var current = dragged >= 0 ? dragged : isNaN(reported) ? 0 : reported
    var adjusted = Math.max(0, Math.min(100, Math.round(current + steps * 5)))
    if (microphone) {
      root.microphoneDrag = adjusted
      if (!microphoneDragTimer.running) microphoneDragTimer.start()
    } else {
      root.volumeDrag = adjusted
      if (!volumeDragTimer.running) volumeDragTimer.start()
    }
    wheel.accepted = true
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

  function refreshClock() {
    if (!clockProcess.running) clockProcess.running = true
  }

  function parseClockData(output) {
    try {
      var parsed = JSON.parse(String(output || ""))
      if (parsed && parsed.zones) root.clockData = parsed
    } catch (error) {
      console.warn("seele-shell/clock", error)
    }
  }

  function clockZone(id) {
    var zones = root.clockData.zones || []
    for (var i = 0; i < zones.length; i++) if (zones[i].id === id) return zones[i]
    return null
  }

  function shownTimezone() {
    return root.clockZone(root.temporaryTimezone)
  }

  function timezonePinned(id) {
    return (root.clockData.pinned || []).indexOf(id) >= 0
  }

  function filteredTimezones(query) {
    return Time.orderZones(root.clockData.zones || [], root.clockData.pinned || [], query)
  }

  function pinTimezone(id) {
    if (clockActionProcess.running) return
    clockActionProcess.command = root.timezonePinned(id) ? ["seele-clock", "unpin", id] : ["seele-clock", "pin", id]
    clockActionProcess.running = true
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
    id: clockProcess
    command: ["seele-clock", "list"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseClockData(text)
    }
  }

  Process {
    id: clockActionProcess
    onExited: root.refreshClock()
  }

  Process {
    id: statusProcess
    command: ["seele-control", "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseSystemData(text)
    }
    onExited: {
      if (root.statusRefreshQueued) {
        root.statusRefreshQueued = false
        Qt.callLater(function() { statusProcess.running = true })
      }
    }
  }

  Process {
    id: controlProcess
    environment: ({ SEELE_CONTROL_NO_STATUS: "1" })
    onExited: function(exitCode) {
      if (exitCode === 0) {
        root.completedControlAction = root.pendingControlAction
        root.completedControlValue = root.pendingControlValue
        root.completedControlExtra = root.pendingControlExtra
      } else {
        root.failedControlAction = root.pendingControlAction
        root.failedControlValue = root.pendingControlValue
        root.failedControlExtra = root.pendingControlExtra
        if (root.pendingControlAction === "volume" && String(root.volumeDrag) === root.pendingControlValue) root.volumeDrag = -1
        if (root.pendingControlAction === "microphone" && String(root.microphoneDrag) === root.pendingControlValue) root.microphoneDrag = -1
      }
      root.pendingControlAction = ""
      root.pendingControlValue = ""
      root.pendingControlExtra = ""
      controlFeedbackTimer.restart()
      root.refreshStatus()
    }
  }

  Process {
    id: bluetoothStatusProcess
    command: ["seele-control", "bluetooth-status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseBluetoothData(text)
    }
    onExited: {
      if (root.bluetoothStatusRefreshQueued) {
        root.bluetoothStatusRefreshQueued = false
        Qt.callLater(function() { bluetoothStatusProcess.running = true })
      }
    }
  }

  Process {
    id: speedtestProcess
    command: ["seele-control", "speedtest"]
    stdout: SplitParser {
      onRead: data => root.handleSpeedtestEvent(data)
    }
    onExited: function(exitCode) {
      Qt.callLater(function() {
        if (exitCode !== 0 || !root.speedtestReceived) {
          root.speedtestPhase = ""
          root.speedtestError = "Speed test failed"
        }
      })
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
    environment: ({ SEELE_CONTROL_NO_STATUS: "1" })
    onExited: {
      root.bluetoothBusy = ""
      root.bluetoothAction = ""
      root.refreshBluetoothStatus()
      if (root.bluetoothScanQueued >= 0) {
        var scan = root.bluetoothScanQueued === 1
        root.bluetoothScanQueued = -1
        Qt.callLater(function() { root.runBluetooth("scan", scan ? "on" : "off") })
      }
    }
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
    triggeredOnStart: true
    onTriggered: {
      root.now = new Date()
      root.refreshClock()
    }
  }

  Timer {
    id: controlFeedbackTimer
    interval: 1200
    onTriggered: {
      root.completedControlAction = ""
      root.completedControlValue = ""
      root.completedControlExtra = ""
      root.failedControlAction = ""
      root.failedControlValue = ""
      root.failedControlExtra = ""
    }
  }

  Timer {
    id: cameraPreviewLaunchTimer

    property string device: ""

    interval: 400
    onTriggered: root.runControl("camera-preview", device)
  }

  Timer {
    id: bluetoothScanTimer
    interval: 30000
    onTriggered: root.setBluetoothScanning(false)
  }

  Timer {
    interval: 500
    repeat: true
    running: root.bluetoothScanActive && root.controlPanel === "bluetooth"
    triggeredOnStart: true
    onTriggered: root.refreshBluetoothStatus()
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

  component RefreshGlyph: Item {
    id: refreshGlyph

    property bool spinning: false
    property color color: root.accent
    property alias font: idleRefresh.font
    onColorChanged: activitySpinner.requestPaint()

    Text {
      id: idleRefresh

      visible: !refreshGlyph.spinning
      anchors.fill: parent
      text: "󰑐"
      color: refreshGlyph.color
      font.family: root.fontFamily
      font.pixelSize: 16
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
    }

    Canvas {
      id: activitySpinner

      visible: refreshGlyph.spinning
      anchors.centerIn: parent
      width: Math.min(parent.width, parent.height, idleRefresh.font.pixelSize)
      height: width
      antialiasing: true
      transformOrigin: Item.Center
      onVisibleChanged: if (visible) requestPaint()
      onWidthChanged: requestPaint()
      onPaint: {
        var context = getContext("2d")
        context.clearRect(0, 0, width, height)
        context.beginPath()
        context.lineWidth = Math.max(1.5, width * 0.14)
        context.lineCap = "round"
        context.strokeStyle = refreshGlyph.color
        context.arc(width / 2, height / 2, Math.max(1, width / 2 - context.lineWidth), -Math.PI / 2, Math.PI)
        context.stroke()
      }

      NumberAnimation on rotation {
        from: 0
        to: 360
        duration: 720
        loops: Animation.Infinite
        running: activitySpinner.visible
      }
    }
  }

  component ControlSwitch: Rectangle {
    id: control

    property bool checked: false
    property bool busy: false
    signal toggled()

    implicitWidth: 40
    implicitHeight: 22
    opacity: enabled ? 1 : 0.42
    radius: height / 2
    color: switchMouse.pressed ? root.alpha(control.checked ? root.accent : root.text, 0.72) : control.checked ? root.accent : root.alpha(root.overlay, 0.4)
    border.width: 1
    border.color: control.busy ? root.accent : switchMouse.pressed ? root.text : switchMouse.containsMouse ? root.accent : "transparent"

    Behavior on color { ColorAnimation { duration: 80 } }

    Rectangle {
      visible: !control.busy
      width: parent.height - 6
      height: width
      radius: width / 2
      y: 3
      x: control.checked ? control.width - width - 3 : 3
      color: control.checked ? root.base : root.text

      Behavior on x { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
    }

    RefreshGlyph {
      visible: control.busy
      anchors.centerIn: parent
      width: 16
      height: 16
      spinning: visible
      color: control.checked ? root.base : root.text
      font.pixelSize: 11
    }

    MouseArea { id: switchMouse; anchors.fill: parent; enabled: control.enabled && !control.busy; hoverEnabled: true; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: control.toggled() }
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

  // Depth wash, drawn under a surface's content and inside its border.
  component SurfaceWash: Rectangle {
    anchors.fill: parent
    anchors.margins: 1
    color: "transparent"

    gradient: Gradient {
      GradientStop { position: 0.0; color: root.alpha(root.text, 0.06) }
      GradientStop { position: 0.55; color: "transparent" }
      GradientStop { position: 1.0; color: root.alpha(root.mantle, 0.45) }
    }
  }

  // Grain film and edge highlight, drawn over a surface's content so the
  // texture is even across the panel and the cards inside it. Neither layer
  // accepts input, so everything underneath stays clickable. A tiled image
  // cannot follow a rounded corner, so `inset` pulls the film inside the arc:
  // anything past radius * (1 - 1 / sqrt(2)) stays within the surface.
  component SurfaceGrain: Item {
    id: grainLayer

    property real inset: 0

    anchors.fill: parent
    z: 1

    Image {
      anchors.fill: parent
      anchors.margins: grainLayer.inset
      source: root.grain
      fillMode: Image.Tile
      opacity: root.grainOpacity
      smooth: false
    }

    Rectangle {
      anchors.top: parent.top
      anchors.topMargin: 1
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.leftMargin: grainLayer.inset * 3
      anchors.rightMargin: grainLayer.inset * 3
      height: 1
      color: root.alpha(root.text, 0.1)
    }
  }

  component HoverTip: PopupWindow {
    id: hoverTip

    property var mouse: null
    property string text: ""

    visible: mouse !== null && mouse.containsMouse && text !== ""
      && root.controlPanel === "" && !root.agentsOpen && !root.trayMenuOpen
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
      radius: root.radiusSmall
      color: root.panelColor
      border.color: root.panelBorder
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

  // Qt cannot round an Image or a live video surface, so the source is drawn
  // through a mask instead. The source item must hide itself; the effect draws
  // it in its place.
  component RoundedSource: Item {
    id: roundedSource

    property Item source: null
    property real radius: root.radius

    Item {
      id: roundedMask

      anchors.fill: parent
      layer.enabled: true
      visible: false

      Rectangle {
        anchors.fill: parent
        radius: roundedSource.radius
        color: "black"
      }
    }

    MultiEffect {
      anchors.fill: parent
      source: roundedSource.source
      maskEnabled: true
      maskSource: roundedMask
    }
  }

  // Every panel introduces itself with a glyph, the way the AI cockpit does.
  component PanelGlyph: Text {
    anchors.verticalCenter: parent.verticalCenter
    width: 32
    color: root.accent
    font.family: root.fontFamily
    font.pixelSize: 20
    horizontalAlignment: Text.AlignLeft
    verticalAlignment: Text.AlignVCenter
    transform: Translate { x: 2 }
  }

  component SpeedGauge: Rectangle {
    id: speedGauge

    property string label: ""
    property string icon: ""
    property real value: -1
    property real maximum: 100
    property color tint: root.accent
    property bool active: false
    readonly property real ratio: Math.max(0, Math.min(1, value / Math.max(1, maximum)))
    property real displayedRatio: ratio

    radius: root.radius
    color: root.mantle

    Behavior on displayedRatio {
      NumberAnimation { duration: 520; easing.type: Easing.OutCubic }
    }

    onDisplayedRatioChanged: gaugeCanvas.requestPaint()
    onTintChanged: gaugeCanvas.requestPaint()

    Text {
      anchors.top: parent.top; anchors.topMargin: 8; anchors.horizontalCenter: parent.horizontalCenter
      text: speedGauge.icon + "  " + speedGauge.label
      color: speedGauge.tint
      font.family: root.fontFamily
      font.pixelSize: 8
      font.bold: true
    }

    Canvas {
      id: gaugeCanvas

      anchors.fill: parent
      onWidthChanged: requestPaint()
      onHeightChanged: requestPaint()
      onPaint: {
        var context = getContext("2d")
        context.clearRect(0, 0, width, height)
        var centerX = width / 2
        var radius = Math.min(width * 0.36, height * 0.42)
        var centerY = height - radius * 0.55 - 8
        var start = Math.PI * 0.82
        var end = Math.PI * 2.18
        var sweep = end - start

        context.lineCap = "round"
        context.lineWidth = 6
        context.strokeStyle = root.alpha(root.overlay, 0.28)
        context.beginPath()
        context.arc(centerX, centerY, radius, start, end, false)
        context.stroke()

        if (speedGauge.displayedRatio > 0) {
          context.strokeStyle = speedGauge.tint
          context.beginPath()
          context.arc(centerX, centerY, radius, start, start + sweep * speedGauge.displayedRatio, false)
          context.stroke()
        }

        context.lineCap = "butt"
        context.lineWidth = 1
        context.strokeStyle = root.alpha(root.text, 0.34)
        for (var tick = 0; tick <= 10; tick++) {
          var tickAngle = start + sweep * tick / 10
          var tickInner = radius - (tick % 5 === 0 ? 9 : 6)
          var tickOuter = radius - 2
          context.beginPath()
          context.moveTo(centerX + Math.cos(tickAngle) * tickInner, centerY + Math.sin(tickAngle) * tickInner)
          context.lineTo(centerX + Math.cos(tickAngle) * tickOuter, centerY + Math.sin(tickAngle) * tickOuter)
          context.stroke()
        }

        var needleAngle = start + sweep * speedGauge.displayedRatio
        context.lineCap = "round"
        context.lineWidth = 2
        context.strokeStyle = speedGauge.tint
        context.beginPath()
        context.moveTo(centerX, centerY)
        context.lineTo(centerX + Math.cos(needleAngle) * (radius - 12), centerY + Math.sin(needleAngle) * (radius - 12))
        context.stroke()
        context.fillStyle = speedGauge.tint
        context.beginPath()
        context.arc(centerX, centerY, 3.5, 0, Math.PI * 2, false)
        context.fill()
      }
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom; anchors.bottomMargin: 12
      text: speedGauge.active && speedGauge.value < 0 ? "Measuring…" : speedGauge.value < 0 ? "" : root.speedtestValue(speedGauge.value)
      color: speedGauge.tint
      font.family: root.fontFamily
      font.pixelSize: 11
      font.bold: true
    }
  }

  // Shared chrome for every floating panel, so panels differ only in what
  // they hold, never in how they are framed.
  component PanelSurface: Rectangle {
    anchors.fill: parent
    radius: root.radius
    color: root.panelColor
    border.color: root.panelBorder
    border.width: 1
    antialiasing: true

    SurfaceWash { radius: root.radius - 1 }
    SurfaceGrain { inset: 3 }
  }

  // Scroll indicators are hairlines rather than the platform's full-width
  // bars, and panels reserve `scrollGutter` for them so a bar never sits on
  // top of the content's own edge.
  component SlimScrollBar: ScrollBar {
    id: scrollBar

    policy: ScrollBar.AsNeeded
    implicitWidth: root.scrollGutter
    padding: 2
    opacity: 1
    visible: policy !== ScrollBar.AlwaysOff && (policy === ScrollBar.AlwaysOn || size < 1)
    // An attached indicator is a sibling of the view's content, so without
    // this it renders behind the rows it belongs to.
    z: 2
    // A list of every timezone would otherwise grind the handle down to a few
    // pixels.
    minimumSize: height > 0 ? Math.min(0.5, 36 / height) : 0

    background: Item {}
    contentItem: Rectangle {
      implicitWidth: root.scrollGutter - 4
      radius: width / 2
      opacity: 1
      color: root.alpha(root.overlay, scrollBar.pressed ? 1 : 0.75)
    }
  }

  // Every bar entry is a rounded pill on the same radius as windows, buttons,
  // and panels, and takes its hover, press, and open state from here so the
  // whole strip reacts identically. The entry itself spans the bar's full
  // height while only the pill is inset, so a pointer thrown at the top of the
  // screen still lands on the entry under it.
  component BarItem: Item {
    property bool hovered: false
    property bool active: false

    anchors.verticalCenter: parent.verticalCenter
    height: root.barHeight

    Rectangle {
      anchors.fill: parent
      anchors.topMargin: root.barPadding
      anchors.bottomMargin: root.barPadding
      anchors.leftMargin: root.barSpacing / 2
      anchors.rightMargin: root.barSpacing / 2
      radius: root.radius
      color: parent.active ? root.selectedColor : parent.hovered ? root.hoverColor : "transparent"

      Behavior on color { ColorAnimation { duration: 110 } }
    }
  }

  Timer {
    id: volumeDragTimer
    interval: 32
    onTriggered: {
      if (root.volumeDrag < 0) return
      if (!root.runControl("volume", String(root.volumeDrag))) restart()
    }
  }

  Timer {
    id: microphoneDragTimer
    interval: 32
    onTriggered: {
      if (root.microphoneDrag < 0) return
      if (!root.runControl("microphone", String(root.microphoneDrag))) restart()
    }
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
      implicitHeight: root.barHeight
      color: root.alpha(root.mantle, 0.9)
      WlrLayershell.layer: WlrLayer.Top
      WlrLayershell.namespace: "seele-shell-bar"

      SurfaceWash {}

      Row {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        spacing: 0

        BarItem {
          width: 30
          hovered: menuMouse.containsMouse
          Image {
            anchors.centerIn: parent
            width: 20
            height: 20
            source: "seele.svg"
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
          }
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
              width: parent.active ? 42 : 20
              height: root.barItemHeight
              anchors.centerIn: parent
              radius: root.radius
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
              cursorShape: Qt.PointingHandCursor
              onClicked: root.activateWorkspace(parent.modelData)
            }
            HoverTip { mouse: workspaceMouse; text: "Workspace " + modelData }
          }
        }

        BarItem {
          readonly property var window: root.activeWindow(barWindow.modelData)
          visible: window !== null && root.windowLabel(window) !== ""
          width: Math.min(230, activeWindowRow.implicitWidth + 14)
          hovered: activeWindowMouse.containsMouse
          Row {
            id: activeWindowRow
            anchors.centerIn: parent
            height: parent.height
            spacing: 6
            IconImage {
              visible: source !== ""
              anchors.verticalCenter: parent.verticalCenter
              implicitWidth: 15; implicitHeight: 15
              source: root.windowIcon(parent.parent.window)
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              width: Math.min(190, implicitWidth)
              text: root.windowLabel(parent.parent.window)
              elide: Text.ElideRight
              color: root.subtext
              font.family: root.fontFamily
              font.pixelSize: 10
            }
          }
          MouseArea { id: activeWindowMouse; anchors.fill: parent; hoverEnabled: true }
          HoverTip { mouse: activeWindowMouse; text: root.windowTitle(activeWindowMouse.parent.window) }
        }

        BarItem {
          width: 30
          hovered: voxtypeMouse.containsMouse
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
        spacing: 0

        BarItem {
          width: localClock.implicitWidth + 14
          hovered: clockMouse.containsMouse
          active: root.panelHere("clock", barWindow.modelData)
          Text {
            id: localClock
            anchors.centerIn: parent
            text: Qt.formatDateTime(root.now, "HH:mm")
            color: root.text
            font.family: root.fontFamily
            font.pixelSize: 12
            font.bold: true
          }
          MouseArea { id: clockMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onPressed: root.toggleControl("clock", barWindow.modelData.name) }
          HoverTip { mouse: clockMouse; text: "Time zones" }
        }

        BarItem {
          width: localDate.implicitWidth + 14
          hovered: dateMouse.containsMouse
          active: root.panelHere("calendar", barWindow.modelData)
          Text {
            id: localDate
            anchors.centerIn: parent
            text: Qt.formatDateTime(root.now, "yyyy-MM-dd")
            color: root.subtext
            font.family: root.fontFamily
            font.pixelSize: 12
          }
          MouseArea { id: dateMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onPressed: root.toggleControl("calendar", barWindow.modelData.name) }
          HoverTip { mouse: dateMouse; text: "Calendar" }
        }

        BarItem {
          visible: root.systemData.microphoneMuted
          width: 30
          hovered: microphoneMutedIndicator.containsMouse
          Rectangle {
            anchors.centerIn: parent
            width: 26; height: 18; radius: root.radiusSmall
            color: root.alpha(root.overlay, 0.35)
            Text {
              anchors.centerIn: parent
              text: "󰍭"
              color: root.subtext
              font.family: root.fontFamily
              font.pixelSize: 12
            }
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

        BarItem {
          visible: root.systemData.microphoneActive && !root.systemData.microphoneMuted
          width: 20
          hovered: microphoneActiveIndicator.containsMouse
          Rectangle {
            anchors.centerIn: parent
            width: 9; height: 9; radius: 4.5
            color: root.iosOrange
          }
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

        BarItem {
          visible: root.systemData.cameraActive
          width: 20
          hovered: cameraActiveIndicator.containsMouse
          Rectangle {
            anchors.centerIn: parent
            width: 9; height: 9; radius: 4.5
            color: root.iosGreen
          }
          MouseArea { id: cameraActiveIndicator; anchors.fill: parent; hoverEnabled: true; onPressed: root.toggleControl("camera", barWindow.modelData.name) }
          HoverTip { mouse: cameraActiveIndicator; text: "Camera in use" }
        }

        BarItem {
          visible: root.systemData.screenRecording
          width: 20
          hovered: screenRecordingIndicator.containsMouse
          Rectangle {
            anchors.centerIn: parent
            width: 9; height: 9; radius: 4.5
            color: root.iosRed
          }
          MouseArea { id: screenRecordingIndicator; anchors.fill: parent; hoverEnabled: true }
          HoverTip { mouse: screenRecordingIndicator; text: "Screen is being recorded" }
        }
      }

      Row {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        spacing: 0

        BarItem {
          id: deviceMediaItem

          readonly property var player: root.devicePlayer()
          visible: player !== null
          width: visible ? Math.min(210, deviceMediaRow.implicitWidth + 14) : 0
          hovered: deviceMediaMouse.containsMouse
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
                visible: false
                source: deviceMediaItem.player ? String(deviceMediaItem.player.trackArtUrl || "") : ""
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: width * 4
                sourceSize.height: height * 4
                smooth: true
                mipmap: true
                asynchronous: true
                cache: true
              }
              RoundedSource {
                anchors.fill: parent
                source: deviceMediaArt
                radius: root.radiusSmall
                visible: deviceMediaArt.status === Image.Ready
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
              text: root.mediaLabel(parent.parent.player)
              elide: Text.ElideRight
              color: root.text
              font.family: root.fontFamily
              font.pixelSize: 10
            }
          }
          MouseArea { id: deviceMediaMouse; anchors.fill: parent; hoverEnabled: true; onClicked: if (parent.player) parent.player.togglePlaying() }
          HoverTip { mouse: deviceMediaMouse; text: root.mediaLabel(deviceMediaItem.player) }
        }

        BarItem {
          id: spotifyMediaItem

          readonly property var player: root.spotifyPlayer()
          visible: player !== null
          width: visible ? Math.min(210, spotifyMediaRow.implicitWidth + 14) : 0
          hovered: spotifyMediaMouse.containsMouse
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
                visible: false
                source: spotifyMediaItem.player ? String(spotifyMediaItem.player.trackArtUrl || "") : ""
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: width * 4
                sourceSize.height: height * 4
                smooth: true
                mipmap: true
                asynchronous: true
                cache: true
              }
              RoundedSource {
                anchors.fill: parent
                source: spotifyMediaArt
                radius: root.radiusSmall
                visible: spotifyMediaArt.status === Image.Ready
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
              text: root.mediaLabel(parent.parent.player)
              elide: Text.ElideRight
              color: root.text
              font.family: root.fontFamily
              font.pixelSize: 10
            }
          }
          MouseArea { id: spotifyMediaMouse; anchors.fill: parent; hoverEnabled: true; onClicked: if (parent.player) parent.player.togglePlaying() }
          HoverTip { mouse: spotifyMediaMouse; text: root.mediaLabel(spotifyMediaItem.player) }
        }

        BarItem {
          visible: root.trayHiddenCount() > 0
          width: 22
          hovered: trayExpandMouse.containsMouse
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
          BarItem {
            required property var modelData
            width: 30
            hovered: trayMouse.containsMouse
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
                    root.overlayScreen = barWindow.modelData.name
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

        BarItem {
          visible: root.systemData.cameraActive || (root.systemData.cameraDevices && root.systemData.cameraDevices.length > 0)
          width: 30
          hovered: cameraMouse.containsMouse
          active: root.panelHere("camera", barWindow.modelData)
          Text { anchors.centerIn: parent; text: root.systemData.cameraActive ? "󰄀" : "󰄁"; color: root.systemData.cameraActive ? root.red : root.text; font.family: root.fontFamily; font.pixelSize: 14 }
          MouseArea { id: cameraMouse; anchors.fill: parent; hoverEnabled: true; onPressed: root.toggleControl("camera", barWindow.modelData.name) }
          HoverTip { mouse: cameraMouse; text: root.systemData.cameraActive ? "Camera in use" : "Camera" }
        }

        Repeater {
          model: root.activeAgents()
          BarItem {
            required property var modelData
            id: agentBadgeItem

            readonly property color stateColor: root.agentColor(modelData.status)
            width: 28
            hovered: agentBadgeMouse.containsMouse
            Column {
              anchors.centerIn: parent
              spacing: 2
              Image {
                visible: modelData.id === "claude"
                anchors.horizontalCenter: parent.horizontalCenter
                width: 13
                height: 13
                source: "claude-code.svg"
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
              }
              Text {
                visible: modelData.id !== "claude"
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
            MouseArea { id: agentBadgeMouse; anchors.fill: parent; hoverEnabled: true; onPressed: root.toggleAgents(barWindow.modelData.name) }
            HoverTip { mouse: agentBadgeMouse; text: modelData.name + " · " + (modelData.status === "input" ? "needs input" : modelData.status) }
          }
        }


        BarItem {
          width: aiBarContent.implicitWidth + 14
          hovered: aiMouse.containsMouse
          active: root.agentsHere(barWindow.modelData)
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
            onPressed: function(mouse) {
              if (mouse.button === Qt.RightButton) root.runAgent("pi", "")
              else if (mouse.button === Qt.MiddleButton) root.refreshAgents()
              else root.toggleAgents(barWindow.modelData.name)
            }
          }
          HoverTip { mouse: aiMouse; text: "AI cockpit · middle-click to refresh · right-click to launch Pi" }
        }

        BarItem {
          visible: root.systemData.airpodsConnected
          width: 30
          hovered: airpodsMouse.containsMouse
          active: root.panelHere("airpods", barWindow.modelData)
          AirpodsIcon { anchors.centerIn: parent; tint: root.accent }
          MouseArea { id: airpodsMouse; anchors.fill: parent; hoverEnabled: true; onPressed: root.toggleControl("airpods", barWindow.modelData.name) }
          HoverTip { mouse: airpodsMouse; text: root.systemData.airpodsName || "AirPods" }
        }

        BarItem {
          visible: root.systemData.bluetoothAvailable
          width: 30
          hovered: bluetoothMouse.containsMouse
          active: root.panelHere("bluetooth", barWindow.modelData)
          Text {
            anchors.centerIn: parent
            text: root.systemData.bluetoothPowered ? "󰂯" : "󰂲"
            color: root.systemData.bluetoothConnected > 0 ? root.accent : root.text
            font.family: root.fontFamily
            font.pixelSize: 14
          }
          MouseArea { id: bluetoothMouse; anchors.fill: parent; hoverEnabled: true; onPressed: root.toggleControl("bluetooth", barWindow.modelData.name) }
          HoverTip { mouse: bluetoothMouse; text: "Bluetooth · " + (root.systemData.bluetoothPowered ? root.systemData.bluetoothConnected + " connected" : "off") }
        }

        BarItem {
          width: 30
          hovered: networkMouse.containsMouse
          active: root.panelHere("network", barWindow.modelData)
          Text {
            anchors.centerIn: parent
            text: root.systemData.connection === "Disconnected" ? "󰖪" : root.systemData.connectionType.indexOf("wireless") >= 0 ? "󰖩" : "󰈀"
            color: root.privateNetworkActive() ? root.accent : root.systemData.connectivity === "full" ? root.text : root.yellow
            font.family: root.fontFamily
            font.pixelSize: 14
          }
          MouseArea { id: networkMouse; anchors.fill: parent; hoverEnabled: true; onPressed: root.toggleControl("network", barWindow.modelData.name) }
          HoverTip {
            mouse: networkMouse
            text: "Network · " + (root.systemData.connection || "Disconnected")
              + (root.systemData.tailscale && root.systemData.tailscale.connected ? " · Tailscale" : "")
              + (root.systemData.protonVpn && root.systemData.protonVpn.connected ? " · Proton VPN" : "")
          }
        }


        BarItem {
          id: audioBarItem

          readonly property int shownVolume: root.volumeDrag >= 0 ? root.volumeDrag : Number(root.systemData.volume)
          width: audioBarContent.implicitWidth + 14
          hovered: audioMouse.containsMouse
          active: root.panelHere("audio", barWindow.modelData)
          Row {
            id: audioBarContent
            anchors.centerIn: parent
            height: parent.height
            spacing: 4
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: root.systemData.muted ? "󰝟" : audioBarItem.shownVolume > 55 ? "󰕾" : "󰖀"
              color: root.systemData.muted ? root.red : root.text
              font.family: root.fontFamily
              font.pixelSize: 14
            }
            Text { anchors.verticalCenter: parent.verticalCenter; text: audioBarItem.shownVolume + "%"; color: root.text; font.family: root.fontFamily; font.pixelSize: 10 }
          }
          MouseArea {
            id: audioMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            onPressed: function(mouse) {
              if (mouse.button === Qt.MiddleButton) {
                if (root.runControl("volume", "mute")) root.patchSystemData({ muted: !root.systemData.muted })
              } else {
                root.toggleControl("audio", barWindow.modelData.name)
              }
            }
            onWheel: function(wheel) { root.adjustAudioFromWheel(wheel, false) }
          }
          HoverTip { mouse: audioMouse; text: "Volume · " + (root.systemData.muted ? "muted" : audioBarItem.shownVolume + "%") }
        }

        BarItem {
          width: notificationBarContent.implicitWidth + 14
          hovered: notificationMouse.containsMouse
          active: root.panelHere("notifications", barWindow.modelData)
          Row {
            id: notificationBarContent
            anchors.centerIn: parent
            height: parent.height
            spacing: 4
            Text { anchors.verticalCenter: parent.verticalCenter; text: root.systemData.dnd ? "󰂛" : "󰂚"; color: root.systemData.dnd ? root.yellow : root.text; font.family: root.fontFamily; font.pixelSize: 14 }
            Text { visible: Number(root.systemData.notifications.count || 0) > 0; anchors.verticalCenter: parent.verticalCenter; text: String(root.systemData.notifications.count); color: root.text; font.family: root.fontFamily; font.pixelSize: 9; font.bold: true }
          }
          MouseArea { id: notificationMouse; anchors.fill: parent; hoverEnabled: true; onPressed: root.toggleControl("notifications", barWindow.modelData.name) }
          HoverTip { mouse: notificationMouse; text: "Notifications · " + (root.systemData.dnd ? "do not disturb" : root.systemData.notifications.count || 0) }
        }

        BarItem {
          id: batteryBarItem

          readonly property var entry: root.batteryPrimary()
          visible: root.batteryEntries().length > 0
          width: batteryBarContent.implicitWidth + 14
          hovered: batteryMouse.containsMouse
          active: root.panelHere("battery", barWindow.modelData)
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
          MouseArea { id: batteryMouse; anchors.fill: parent; hoverEnabled: true; onPressed: root.toggleControl("battery", barWindow.modelData.name) }
          HoverTip { mouse: batteryMouse; text: "Battery · " + (batteryBarItem.entry ? batteryBarItem.entry.name + " " + Number(batteryBarItem.entry.percent) + "%" : "unavailable") }
        }

        BarItem {
          width: 30
          hovered: sessionMouse.containsMouse
          active: root.panelHere("system", barWindow.modelData)
          Text { anchors.centerIn: parent; text: "󰐥"; color: root.windowsCountdown >= 0 ? root.yellow : root.text; font.family: root.fontFamily; font.pixelSize: 14 }
          MouseArea { id: sessionMouse; anchors.fill: parent; hoverEnabled: true; onPressed: root.toggleControl("system", barWindow.modelData.name) }
          HoverTip { mouse: sessionMouse; text: "Power and session" }
        }
      }

      SurfaceGrain {}

      Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        z: 1
        color: root.alpha(root.accent, 0.2)
      }
    }
  }

  // Click-away catcher ---------------------------------------------------------
  // Keep this surface mapped with an empty input mask while idle. Mapping it
  // under a stationary pointer can make Hyprland defer the next click until
  // pointer motion. The bar strip stays clickable so one press can toggle or
  // switch panels.
  Variants {
    model: Quickshell.screens
    PanelWindow {
      id: clickAwayWindow
      required property var modelData
      readonly property bool active: root.controlPanel !== "" || root.agentsOpen || root.trayMenuOpen
      screen: modelData
      visible: true
      anchors { top: true; bottom: true; left: true; right: true }
      margins { top: root.barHeight }
      exclusionMode: ExclusionMode.Ignore
      color: "transparent"
      mask: Region {
        width: clickAwayWindow.active ? clickAwayWindow.width : 0
        height: clickAwayWindow.active ? clickAwayWindow.height : 0
      }
      WlrLayershell.layer: WlrLayer.Top
      WlrLayershell.namespace: "seele-shell-clickaway"

      MouseArea {
        anchors.fill: parent
        enabled: clickAwayWindow.active
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onPressed: root.closeOverlays()
      }
    }
  }

  // Calendar ------------------------------------------------------------------
  Variants {
    model: Quickshell.screens
    PanelWindow {
      id: calendarWindow
      required property var modelData
      screen: modelData
      visible: root.controlPanel === "calendar" && root.pinnedScreen(root.overlayScreen, modelData)
      anchors { top: true }
      margins.top: root.barHeight + root.panelGap
      implicitWidth: 390
      implicitHeight: Math.min(modelData.height - 60, 470)
      exclusionMode: ExclusionMode.Ignore
      color: "transparent"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "seele-shell-calendar"

      onVisibleChanged: if (visible) Qt.callLater(function() { calendarMonths.positionViewAtIndex(60, ListView.Beginning) })

      PanelSurface {
        Column {
          anchors.fill: parent
          anchors.margins: root.panelMargin
          spacing: root.panelSpacing

          Row {
            width: parent.width
            height: 42
            PanelGlyph { text: "󰃭"; font.pixelSize: 24 }
            Column {
              width: parent.width - 116
              Text { text: Qt.formatDate(root.now, "dddd"); color: root.text; font.family: root.fontFamily; font.pixelSize: 18; font.bold: true }
              Text { text: Qt.formatDate(root.now, "d MMMM yyyy") + " · week " + Time.isoWeek(root.now); color: root.subtext; font.family: root.fontFamily; font.pixelSize: 10 }
            }
            Rectangle {
              width: 84; height: 30; radius: root.radius
              anchors.verticalCenter: parent.verticalCenter
              color: todayMouse.pressed ? root.pressColor : todayMouse.containsMouse ? root.hoverColor : root.surface
              Text { anchors.centerIn: parent; text: "Today"; color: root.text; font.family: root.fontFamily; font.pixelSize: 10; font.bold: true }
              MouseArea { id: todayMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: calendarMonths.positionViewAtIndex(60, ListView.Beginning) }
            }
          }

          ListView {
            id: calendarMonths
            width: parent.width
            height: parent.height - 52
            model: 121
            spacing: 8
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            delegate: Item {
              id: monthDelegate
              required property int modelData
              readonly property int monthOffset: modelData - 60
              readonly property date month: Time.monthDate(root.now, monthOffset)
              width: ListView.view.width
              height: 258

              Column {
                anchors.fill: parent
                spacing: 6
                Text {
                  width: parent.width
                  height: 28
                  text: Qt.formatDate(monthDelegate.month, "MMMM yyyy")
                  color: monthDelegate.monthOffset === 0 ? root.accent : root.text
                  font.family: root.fontFamily
                  font.pixelSize: 14
                  font.bold: true
                  verticalAlignment: Text.AlignVCenter
                }
                Grid {
                  width: parent.width
                  height: 22
                  columns: 8
                  Repeater {
                    model: ["Wk", "Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                    Text {
                      required property string modelData
                      width: parent.width / 8
                      height: 22
                      text: modelData
                      color: root.mutedText
                      font.family: root.fontFamily
                      font.pixelSize: 9
                      font.bold: true
                      horizontalAlignment: Text.AlignHCenter
                      verticalAlignment: Text.AlignVCenter
                    }
                  }
                }
                Grid {
                  id: monthGrid
                  width: parent.width
                  height: 198
                  columns: 8
                  Repeater {
                    model: Time.calendarCells(root.now, monthDelegate.monthOffset)
                    Item {
                      id: calendarCell
                      required property var modelData
                      width: monthGrid.width / 8
                      height: 33
                      Rectangle {
                        visible: !calendarCell.modelData.week && calendarCell.modelData.today
                        anchors.centerIn: parent
                        width: 27; height: 27; radius: 13.5
                        color: root.accent
                      }
                      Text {
                        anchors.centerIn: parent
                        text: calendarCell.modelData.week ? "W" + calendarCell.modelData.label : calendarCell.modelData.day
                        color: calendarCell.modelData.week ? root.mutedText : calendarCell.modelData.today ? root.base : calendarCell.modelData.inMonth ? root.text : root.mutedText
                        opacity: calendarCell.modelData.week || calendarCell.modelData.inMonth || calendarCell.modelData.today ? 1 : 0.72
                        font.family: root.fontFamily
                        font.pixelSize: calendarCell.modelData.week ? 9 : 10
                        font.bold: !!calendarCell.modelData.today || !!calendarCell.modelData.week
                      }
                    }
                  }
                }
              }
            }
            ScrollBar.vertical: SlimScrollBar {}
          }
        }
      }
    }
  }

  // World clock ---------------------------------------------------------------
  Variants {
    model: Quickshell.screens
    PanelWindow {
      id: clockWindow
      required property var modelData
      screen: modelData
      visible: root.controlPanel === "clock" && root.pinnedScreen(root.overlayScreen, modelData)
      anchors { top: true }
      margins.top: root.barHeight + root.panelGap
      implicitWidth: 430
      implicitHeight: Math.min(modelData.height - 60, 560)
      exclusionMode: ExclusionMode.Ignore
      color: "transparent"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
      WlrLayershell.namespace: "seele-shell-clock"
      onVisibleChanged: if (visible) Qt.callLater(function() {
        timezoneSearch.forceActiveFocus()
        timezoneSearch.selectAll()
      })

      PanelSurface {
        Column {
          anchors.fill: parent
          anchors.margins: root.panelMargin
          spacing: root.panelSpacing

          Row {
            width: parent.width
            height: 42
            PanelGlyph { text: "󰥔"; font.pixelSize: 24 }
            Column {
              width: parent.width - 104
              Text { text: "World clock"; color: root.text; font.family: root.fontFamily; font.pixelSize: 18; font.bold: true }
              Text { text: "Select temporarily, or pin multiple zones to the top"; color: root.subtext; font.family: root.fontFamily; font.pixelSize: 9 }
            }
            Text { anchors.verticalCenter: parent.verticalCenter; text: Qt.formatDateTime(root.now, "HH:mm"); color: root.accent; font.family: root.fontFamily; font.pixelSize: 18; font.bold: true; horizontalAlignment: Text.AlignRight }
          }

          Rectangle {
            id: selectedTimezoneCard
            readonly property var zone: root.shownTimezone()
            visible: zone !== null
            width: parent.width
            height: visible ? 58 : 0
            radius: root.radius
            color: root.alpha(root.surface, 0.72)
            Row {
              anchors.fill: parent
              anchors.leftMargin: 12
              anchors.rightMargin: 8
              spacing: 8
              Text { visible: selectedTimezoneCard.zone && selectedTimezoneCard.zone.flag !== ""; anchors.verticalCenter: parent.verticalCenter; text: selectedTimezoneCard.zone ? selectedTimezoneCard.zone.flag : ""; font.pixelSize: 19 }
              Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - clearTimezoneButton.width - (selectedTimezoneCard.zone && selectedTimezoneCard.zone.flag !== "" ? 55 : 28)
                Text { width: parent.width; text: selectedTimezoneCard.zone ? selectedTimezoneCard.zone.label : ""; color: root.text; font.family: root.fontFamily; font.pixelSize: 12; font.bold: true; elide: Text.ElideRight }
                Text { text: selectedTimezoneCard.zone ? selectedTimezoneCard.zone.id + " · " + selectedTimezoneCard.zone.day + " · " + selectedTimezoneCard.zone.abbreviation : ""; color: root.subtext; font.family: root.fontFamily; font.pixelSize: 9 }
              }
              Rectangle {
                id: clearTimezoneButton
                width: 66; height: 32; radius: root.radius
                anchors.verticalCenter: parent.verticalCenter
                color: clearTimezoneMouse.pressed ? root.pressColor : clearTimezoneMouse.containsMouse ? root.hoverColor : root.mantle
                Text { anchors.centerIn: parent; text: "Clear"; color: root.text; font.family: root.fontFamily; font.pixelSize: 9; font.bold: true }
                MouseArea {
                  id: clearTimezoneMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.temporaryTimezone = ""
                }
              }
            }
          }

          TextField {
            id: timezoneSearch
            width: parent.width
            height: 38
            placeholderText: "Search PST, UTC, Europe/London, city…"
            color: root.text
            placeholderTextColor: root.overlay
            selectionColor: root.accent
            selectedTextColor: root.base
            font.family: root.fontFamily
            font.pixelSize: 10
            leftPadding: 12
            rightPadding: 12
            background: Rectangle { radius: root.radius; color: root.surface; border.color: timezoneSearch.activeFocus ? root.accent : "transparent"; border.width: 1 }
            onAccepted: {
              var matches = root.filteredTimezones(text)
              if (matches.length > 0) root.temporaryTimezone = matches[0].id
            }
          }

          ListView {
            id: timezoneList
            width: parent.width
            height: parent.height - (selectedTimezoneCard.visible ? 168 : 100)
            model: root.filteredTimezones(timezoneSearch.text)
            spacing: 4
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            delegate: Rectangle {
              id: timezoneRow
              required property var modelData
              readonly property bool selected: root.temporaryTimezone === modelData.id
              readonly property bool pinned: root.timezonePinned(modelData.id)
              width: ListView.view.width
              height: 54
              radius: root.radius
              color: timezoneRowMouse.pressed ? root.pressColor : selected ? root.hoverColor : timezoneRowMouse.containsMouse ? root.surface : root.alpha(root.surface, 0.45)

              Text { visible: modelData.kind === "city"; anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter; width: 25; text: modelData.flag; font.pixelSize: 16; horizontalAlignment: Text.AlignHCenter }
              Column {
                anchors.left: parent.left
                anchors.leftMargin: modelData.kind === "city" ? 43 : 12
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - (modelData.kind === "city" ? 176 : 145)
                Text { width: parent.width; text: modelData.label; color: root.text; font.family: root.fontFamily; font.pixelSize: 11; font.bold: true; elide: Text.ElideRight }
                Text { width: parent.width; text: modelData.id + " · " + modelData.abbreviation + " " + modelData.offset; color: root.subtext; font.family: root.fontFamily; font.pixelSize: 8; elide: Text.ElideRight }
              }
              Column {
                anchors.right: pinTimezoneButton.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 76
                Text { width: parent.width; text: modelData.time; color: root.accent; font.family: root.fontFamily; font.pixelSize: 13; font.bold: true; horizontalAlignment: Text.AlignRight }
                Text { width: parent.width; text: modelData.day; color: root.mutedText; font.family: root.fontFamily; font.pixelSize: 8; horizontalAlignment: Text.AlignRight }
              }
              MouseArea {
                id: timezoneRowMouse
                anchors.left: parent.left; anchors.right: pinTimezoneButton.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.temporaryTimezone = timezoneRow.modelData.id
              }
              Rectangle {
                id: pinTimezoneButton
                anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
                width: 38; height: 30; radius: root.radius
                color: pinTimezoneMouse.pressed ? root.pressColor : timezoneRow.pinned ? root.selectedColor : pinTimezoneMouse.containsMouse ? root.hoverColor : root.mantle
                Text { anchors.centerIn: parent; text: timezoneRow.pinned ? "Unpin" : "Pin"; color: timezoneRow.pinned ? root.accent : root.subtext; font.family: root.fontFamily; font.pixelSize: 8; font.bold: true }
                MouseArea { id: pinTimezoneMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.pinTimezone(timezoneRow.modelData.id) }
              }
            }
            ScrollBar.vertical: SlimScrollBar {}
          }
        }
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
      visible: root.trayMenuOpen && root.pinnedScreen(root.overlayScreen, modelData)
      anchors { top: true; right: true }
      margins { top: root.barHeight + root.panelGap; right: root.panelGap }
      implicitWidth: 310
      implicitHeight: Math.min(420, 58 + Math.max(1, trayMenuOpener.children.values.length) * 36)
      exclusionMode: ExclusionMode.Ignore
      color: "transparent"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "seele-shell-tray-menu"
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

      PanelSurface {
        Column {
          anchors.fill: parent
          anchors.margins: root.panelSpacing
          spacing: 6

          Row {
            width: parent.width
            height: 30
            spacing: 8
            IconImage {
              visible: source !== ""
              anchors.verticalCenter: parent.verticalCenter
              implicitWidth: 18; implicitHeight: 18
              source: root.activeTrayItem ? (root.activeTrayItem.icon || "") : ""
            }
            Text {
              width: parent.width - 132
              anchors.verticalCenter: parent.verticalCenter
              text: root.activeTrayItem ? (root.activeTrayItem.title || root.activeTrayItem.id || "Tray menu") : "Tray menu"
              elide: Text.ElideRight
              color: root.text
              font.family: root.fontFamily
              font.pixelSize: 12
              font.bold: true
            }
            Rectangle {
              width: 72; height: 26; radius: root.radius
              anchors.verticalCenter: parent.verticalCenter
              color: trayHideMouse.pressed ? root.pressColor : trayHideMouse.containsMouse ? root.hoverColor : root.surface
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
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.toggleTrayItemHidden(root.activeTrayItem)
                  root.closeTrayMenu()
                }
              }
            }
            Rectangle {
              width: 30; height: 30; radius: root.radius
              color: trayMenuCloseMouse.pressed ? root.pressColor : trayMenuCloseMouse.containsMouse ? root.hoverColor : "transparent"
              Text { anchors.centerIn: parent; text: "󰅖"; color: root.subtext; font.family: root.fontFamily; font.pixelSize: 11 }
              MouseArea { id: trayMenuCloseMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.closeTrayMenu() }
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
                radius: root.radius
                color: trayMenuEntryMouse.pressed ? root.pressColor : trayMenuEntryMouse.containsMouse && parent.modelData.enabled ? root.hoverColor : "transparent"
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
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
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
      readonly property bool active: root.agentsOpen && root.pinnedScreen(root.overlayScreen, modelData)
      screen: modelData
      visible: true
      anchors { top: true; right: true }
      margins { top: root.barHeight + root.panelGap; right: root.panelGap }
      implicitWidth: 500
      implicitHeight: Math.min(modelData.height - 60, 760)
      exclusionMode: ExclusionMode.Ignore
      color: "transparent"
      mask: Region {
        width: agentsWindow.active ? agentsWindow.width : 0
        height: agentsWindow.active ? agentsWindow.height : 0
      }
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: active ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
      WlrLayershell.namespace: "seele-shell-agents"

      PanelSurface {
        visible: agentsWindow.active

        Flickable {
          id: agentsScroll

          anchors.fill: parent
          anchors.margins: root.panelMargin
          anchors.rightMargin: root.scrollInset
          clip: true
          contentWidth: width
          contentHeight: agentsContent.implicitHeight
          boundsBehavior: Flickable.StopAtBounds

          ScrollBar.vertical: SlimScrollBar {}

          Column {
            id: agentsContent

            width: agentsScroll.width - root.panelMargin + root.scrollInset
            spacing: 14

            Item {
              width: parent.width
              height: 42

              Text {
                id: cockpitGlyph
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "󱚣"
                color: root.accent
                font.family: root.fontFamily
                font.pixelSize: 28
              }
              Column {
                anchors.left: cockpitGlyph.right
                anchors.leftMargin: 10
                anchors.right: cockpitRefresh.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                Text { text: "AI cockpit"; color: root.text; font.family: root.fontFamily; font.pixelSize: 20; font.bold: true }
                Text {
                  width: parent.width
                  elide: Text.ElideRight
                  text: root.agentRefreshing ? "Refreshing usage…" : root.agentError !== "" ? "Usage unavailable" : root.subscriptionSummary()
                  color: root.agentError !== "" ? root.red : root.subtext
                  font.family: root.fontFamily; font.pixelSize: 11
                }
              }
              Rectangle {
                id: cockpitRefresh
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 34; height: 34; radius: root.radius
                color: refreshMouse.pressed ? root.pressColor : root.agentRefreshing ? root.activeTint : refreshMouse.containsMouse ? root.hoverColor : "transparent"
                RefreshGlyph { anchors.centerIn: parent; width: 20; height: 20; spinning: root.agentRefreshing }
                MouseArea { id: refreshMouse; anchors.fill: parent; enabled: !root.agentRefreshing; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.refreshAgents() }
                HoverTip { mouse: refreshMouse; text: "Refresh usage" }
              }
            }

            Text { text: "CHANGE THIS SYSTEM"; color: root.mutedText; font.family: root.fontFamily; font.pixelSize: 10; font.bold: true }

            Rectangle {
              width: parent.width; height: 48; radius: root.radius
              color: osSessionMouse.pressed ? root.pressColor : osSessionMouse.containsMouse ? root.hoverColor : root.surface
              border.color: root.alpha(root.accent, 0.45)
              border.width: 1
              Row {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 12
                Text { anchors.verticalCenter: parent.verticalCenter; text: "󱄅"; color: root.accent; font.family: root.fontFamily; font.pixelSize: 22 }
                Text { anchors.verticalCenter: parent.verticalCenter; width: parent.width - 46; text: "Describe a change to Seele"; color: root.text; font.family: root.fontFamily; font.pixelSize: 13; font.bold: true }
              }
              MouseArea {
                id: osSessionMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.startOsSession()
              }
            }

            Text { text: "LAUNCH"; color: root.mutedText; font.family: root.fontFamily; font.pixelSize: 10; font.bold: true }

            Grid {
              width: parent.width
              columns: 2
              spacing: 8
              Repeater {
                model: root.agentData.launchers || []
                Rectangle {
                  required property var modelData
                  readonly property string status: root.agentStatus(modelData.id)
                  width: (parent.width - 8) / 2; height: 68; radius: root.radius
                  color: launchMouse.pressed ? root.pressColor : launchMouse.containsMouse ? root.hoverColor : root.surface
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
                  MouseArea { id: launchMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.runAgent(parent.modelData.id, "") }
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
                width: (parent.width - 8) / 2; height: 68; radius: root.radius; color: root.surface
                Column { anchors.centerIn: parent; spacing: 4
                  Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.formatTokens(root.agentData.local.today.totalTokens || 0); color: root.accent; font.family: root.fontFamily; font.pixelSize: 20; font.bold: true }
                  Text { anchors.horizontalCenter: parent.horizontalCenter; text: "tokens today"; color: root.subtext; font.family: root.fontFamily; font.pixelSize: 10 }
                }
              }
              Rectangle {
                width: (parent.width - 8) / 2; height: 68; radius: root.radius; color: root.surface
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
                Text { width: parent.width - 20; anchors.verticalCenter: parent.verticalCenter; text: "LAST 7 DAYS"; color: usageHeaderMouse.pressed ? root.accent : usageHeaderMouse.containsMouse ? root.text : root.overlay; font.family: root.fontFamily; font.pixelSize: 10; font.bold: true }
                Text { width: 20; anchors.verticalCenter: parent.verticalCenter; text: root.agentUsageOpen ? "󰅃" : "󰅀"; color: root.overlay; font.family: root.fontFamily; font.pixelSize: 11; horizontalAlignment: Text.AlignRight }
              }
              MouseArea { id: usageHeaderMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.agentUsageOpen = !root.agentUsageOpen }
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
                Text { width: parent.width - 20; anchors.verticalCenter: parent.verticalCenter; text: "TOP MODELS"; color: modelsHeaderMouse.pressed ? root.accent : modelsHeaderMouse.containsMouse ? root.text : root.overlay; font.family: root.fontFamily; font.pixelSize: 10; font.bold: true }
                Text { width: 20; anchors.verticalCenter: parent.verticalCenter; text: root.agentModelsOpen ? "󰅃" : "󰅀"; color: root.overlay; font.family: root.fontFamily; font.pixelSize: 11; horizontalAlignment: Text.AlignRight }
              }
              MouseArea { id: modelsHeaderMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.agentModelsOpen = !root.agentModelsOpen }
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
      visible: root.controlPanel === "audio" && root.pinnedScreen(root.overlayScreen, modelData)
      anchors { top: true; right: true }
      margins { top: root.barHeight + root.panelGap; right: root.panelGap }
      implicitWidth: 350
      implicitHeight: audioContent.implicitHeight + root.panelMargin * 2
      exclusionMode: ExclusionMode.Ignore
      color: "transparent"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "seele-shell-audio"

      PanelSurface {
        Column {
          id: audioContent

          anchors.fill: parent; anchors.margins: root.panelMargin; spacing: root.panelSpacing
          Row {
            width: parent.width
            height: root.panelHeaderHeight
            PanelGlyph { text: "󰕾" }
            Text { anchors.verticalCenter: parent.verticalCenter; text: "Audio"; color: root.text; font.family: root.fontFamily; font.pixelSize: 18; font.bold: true }
          }
          Row {
            width: parent.width; spacing: 8
            Rectangle {
              id: outputSlider

              readonly property int shown: root.volumeDrag >= 0 ? root.volumeDrag : Number(root.systemData.volume)
              width: parent.width - 52; height: 44; radius: root.radius
              color: root.surface
              clip: true
              Rectangle {
                width: parent.width * Math.max(0, Math.min(1, parent.shown / 100))
                radius: parent.radius
                height: parent.height
                color: root.systemData.muted ? root.fillDanger : root.fillColor
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
                onWheel: function(wheel) { root.adjustAudioFromWheel(wheel, false) }
              }
            }
            Rectangle {
              width: 44; height: 44; radius: root.radius
              color: outputMuteMouse.pressed ? root.pressColor : root.systemData.muted ? root.dangerColor : outputMuteMouse.containsMouse ? root.hoverColor : root.surface
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
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (root.runControl("volume", "mute")) root.patchSystemData({ muted: !root.systemData.muted })
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
              width: parent.width - 52; height: 44; radius: root.radius
              color: root.surface
              clip: true
              Rectangle {
                width: parent.width * Math.max(0, Math.min(1, parent.shown / 100))
                radius: parent.radius
                height: parent.height
                color: root.systemData.microphoneMuted ? root.fillDanger : root.fillColor
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
                onWheel: function(wheel) { root.adjustAudioFromWheel(wheel, true) }
              }
            }
            Rectangle {
              width: 44; height: 44; radius: root.radius
              color: microphoneMuteMouse.pressed ? root.pressColor : root.systemData.microphoneMuted ? root.dangerColor : microphoneMuteMouse.containsMouse ? root.hoverColor : root.surface
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
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (root.runControl("microphone", "mute")) root.patchSystemData({ microphoneMuted: !root.systemData.microphoneMuted })
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
              readonly property bool busy: root.controlBusy("audio-device", String(modelData.id))
              readonly property bool complete: root.controlCompleted("audio-device", String(modelData.id))
              width: ListView.view.width; height: 28; radius: root.radius
              color: outputDeviceMouse.pressed ? root.pressColor : busy ? root.selectedColor : modelData.default || complete ? root.hoverColor : outputDeviceMouse.containsMouse ? root.surface : root.alpha(root.surface, 0.5)
              Row {
                visible: !parent.busy
                anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 8
                Text { anchors.verticalCenter: parent.verticalCenter; text: parent.parent.complete || modelData.default ? "󰄬" : "󰓃"; color: parent.parent.complete || modelData.default ? root.accent : root.subtext; font.family: root.fontFamily; font.pixelSize: 12 }
                Text { anchors.verticalCenter: parent.verticalCenter; width: parent.width - 30; text: modelData.name; elide: Text.ElideRight; color: root.text; font.family: root.fontFamily; font.pixelSize: 10 }
              }
              RefreshGlyph { visible: parent.busy; anchors.centerIn: parent; width: 16; height: 16; spinning: visible; font.pixelSize: 12 }
              MouseArea { id: outputDeviceMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.setAudioDevice(parent.modelData.id) }
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
              readonly property bool busy: root.controlBusy("audio-device", String(modelData.id))
              readonly property bool complete: root.controlCompleted("audio-device", String(modelData.id))
              width: ListView.view.width; height: 28; radius: root.radius
              color: inputDeviceMouse.pressed ? root.pressColor : busy ? root.selectedColor : modelData.default || complete ? root.hoverColor : inputDeviceMouse.containsMouse ? root.surface : root.alpha(root.surface, 0.5)
              Row {
                visible: !parent.busy
                anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 8
                Text { anchors.verticalCenter: parent.verticalCenter; text: parent.parent.complete || modelData.default ? "󰄬" : "󰍬"; color: parent.parent.complete || modelData.default ? root.accent : root.subtext; font.family: root.fontFamily; font.pixelSize: 12 }
                Text { anchors.verticalCenter: parent.verticalCenter; width: parent.width - 30; text: modelData.name; elide: Text.ElideRight; color: root.text; font.family: root.fontFamily; font.pixelSize: 10 }
              }
              RefreshGlyph { visible: parent.busy; anchors.centerIn: parent; width: 16; height: 16; spinning: visible; font.pixelSize: 12 }
              MouseArea { id: inputDeviceMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.setAudioDevice(parent.modelData.id) }
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
      visible: root.controlPanel === "network" && root.pinnedScreen(root.overlayScreen, modelData)
      anchors { top: true; right: true }
      margins { top: root.barHeight + root.panelGap; right: root.panelGap }
      implicitWidth: 390
      implicitHeight: networkContent.implicitHeight + root.panelMargin * 2
      exclusionMode: ExclusionMode.Ignore
      color: "transparent"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "seele-shell-network"

      PanelSurface {
        Column {
          id: networkContent

          anchors.fill: parent; anchors.margins: root.panelMargin; spacing: 6
          Row {
            width: parent.width; height: 34; spacing: 8
            PanelGlyph { text: "󰤨" }
            Text { width: root.systemData.wifiAvailable ? parent.width - 128 : parent.width - 40; anchors.verticalCenter: parent.verticalCenter; text: "Network"; color: root.text; font.family: root.fontFamily; font.pixelSize: 18; font.bold: true }
            Text { visible: root.systemData.wifiAvailable; anchors.verticalCenter: parent.verticalCenter; text: "Wi-Fi"; color: root.subtext; font.family: root.fontFamily; font.pixelSize: 10 }
            ControlSwitch {
              visible: root.systemData.wifiAvailable
              anchors.verticalCenter: parent.verticalCenter
              checked: root.systemData.wifiEnabled
              busy: root.controlBusy("wifi", "toggle")
              onToggled: if (root.runControl("wifi", "toggle")) root.patchSystemData({ wifiEnabled: !root.systemData.wifiEnabled })
            }
          }
          Row {
            width: parent.width; height: 22
            Text { width: parent.width * 0.64; text: root.systemData.connection || "Disconnected"; elide: Text.ElideRight; color: root.text; font.family: root.fontFamily; font.pixelSize: 12; font.bold: true }
            Text { width: parent.width * 0.36; text: root.systemData.connectivity; color: root.systemData.connectivity === "full" ? root.green : root.yellow; font.family: root.fontFamily; font.pixelSize: 9; horizontalAlignment: Text.AlignRight }
          }
          Rectangle {
            width: parent.width; height: 60; radius: root.radius; color: root.surface
            Column {
              anchors.fill: parent; anchors.margins: 9; spacing: 4
              Text { text: "IP address    " + (root.systemData.ipAddress || "Unavailable"); color: root.text; font.family: root.fontFamily; font.pixelSize: 9 }
              Text { text: "Gateway       " + (root.systemData.gateway || "Unavailable") + " · " + (root.systemData.connectionType || "None"); color: root.subtext; font.family: root.fontFamily; font.pixelSize: 9 }
            }
          }

          Rectangle {
            id: speedtestCard

            width: parent.width; height: 204; radius: root.radius; color: root.surface
            Column {
              anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 10; rightMargin: 10; topMargin: 8 }
              spacing: 8
              Item {
                width: parent.width; height: 30
                Column {
                  anchors.centerIn: parent
                  spacing: 0
                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "PING"
                    color: root.overlay
                    font.family: root.fontFamily
                    font.pixelSize: 8
                    font.bold: true
                  }
                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.speedtestPingText()
                    color: root.speedtestError !== "" ? root.red : root.text
                    font.family: root.fontFamily
                    font.pixelSize: 10
                    font.bold: true
                  }
                }
                Rectangle {
                  anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                  width: 64; height: 24; radius: root.radius
                  color: speedtestMouse.pressed ? root.pressColor : speedtestProcess.running ? root.selectedColor : speedtestMouse.containsMouse ? root.hoverColor : root.mantle
                  Text { visible: !speedtestProcess.running; anchors.centerIn: parent; text: root.speedtestReceived ? "Again" : "Run"; color: root.text; font.family: root.fontFamily; font.pixelSize: 9; font.bold: true }
                  RefreshGlyph { visible: speedtestProcess.running; anchors.centerIn: parent; width: 14; height: 14; spinning: visible; font.pixelSize: 10 }
                  MouseArea { id: speedtestMouse; anchors.fill: parent; enabled: !speedtestProcess.running; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.startSpeedtest() }
                }
              }
              Row {
                width: parent.width; height: 140; spacing: 8
                SpeedGauge {
                  width: (parent.width - 8) / 2; height: parent.height; radius: root.radius
                  label: "DOWNLOAD"
                  icon: "󰇚"
                  value: Number(root.speedtestData.download)
                  maximum: root.speedtestScale()
                  tint: root.accent
                  active: root.speedtestPhase === "download"
                }
                SpeedGauge {
                  width: (parent.width - 8) / 2; height: parent.height; radius: root.radius
                  label: "UPLOAD"
                  icon: "󰕒"
                  value: Number(root.speedtestData.upload)
                  maximum: root.speedtestScale()
                  tint: root.green
                  active: root.speedtestPhase === "upload"
                }
              }
            }
          }

          Text { text: "PRIVATE NETWORKS"; color: root.overlay; font.family: root.fontFamily; font.pixelSize: 9; font.bold: true }

          Rectangle {
            id: tailscaleCard
            readonly property var state: root.systemData.tailscale || ({})
            readonly property string action: state.connected ? "down" : state.needsLogin ? "login" : "up"
            readonly property bool busy: root.controlBusy("tailscale", action)
            readonly property bool failed: root.controlFailed("tailscale", action)
            width: parent.width; height: 66; radius: root.radius
            color: failed ? root.dangerTint : state.connected ? root.activeTint : root.surface
            Row {
              anchors.fill: parent; anchors.margins: 10; spacing: 9
              Text { width: 24; anchors.verticalCenter: parent.verticalCenter; text: "󰛳"; color: tailscaleCard.state.connected ? root.accent : root.subtext; font.family: root.fontFamily; font.pixelSize: 17; horizontalAlignment: Text.AlignHCenter }
              Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 82
                spacing: 3
                Text { text: "Tailscale"; color: root.text; font.family: root.fontFamily; font.pixelSize: 11; font.bold: true }
                Text { width: parent.width; text: tailscaleCard.failed ? "Action failed" : root.tailscaleDetail(); elide: Text.ElideRight; color: tailscaleCard.failed ? root.red : root.subtext; font.family: root.fontFamily; font.pixelSize: 8 }
              }
              ControlSwitch {
                anchors.verticalCenter: parent.verticalCenter
                enabled: !!tailscaleCard.state.available
                checked: !!tailscaleCard.state.connected
                busy: tailscaleCard.busy
                onToggled: root.runControl("tailscale", tailscaleCard.action)
              }
            }
          }

          Rectangle {
            id: protonVpnCard
            readonly property var state: root.systemData.protonVpn || ({})
            readonly property string action: state.connected ? "disconnect" : "connect"
            readonly property bool busy: root.controlBusy("proton-vpn", action)
            readonly property bool failed: root.controlFailed("proton-vpn", action)
            width: parent.width; height: 66; radius: root.radius
            color: failed ? root.dangerTint : state.connected ? root.activeTint : root.surface
            Row {
              anchors.fill: parent; anchors.margins: 10; spacing: 9
              Text { width: 24; anchors.verticalCenter: parent.verticalCenter; text: "󰒃"; color: protonVpnCard.state.connected ? root.accent : root.subtext; font.family: root.fontFamily; font.pixelSize: 17; horizontalAlignment: Text.AlignHCenter }
              Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 123
                spacing: 3
                Text { text: "Proton VPN"; color: root.text; font.family: root.fontFamily; font.pixelSize: 11; font.bold: true }
                Text { width: parent.width; text: protonVpnCard.failed ? "Quick connect failed · open the app" : root.protonVpnDetail(); elide: Text.ElideRight; color: protonVpnCard.failed ? root.red : root.subtext; font.family: root.fontFamily; font.pixelSize: 8 }
              }
              Rectangle {
                width: 32; height: 32; radius: root.radius
                anchors.verticalCenter: parent.verticalCenter
                color: protonAppMouse.pressed ? root.pressColor : protonAppMouse.containsMouse ? root.hoverColor : root.mantle
                Text { anchors.centerIn: parent; text: "󰏌"; color: root.subtext; font.family: root.fontFamily; font.pixelSize: 12 }
                MouseArea { id: protonAppMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.runControl("proton-vpn", "open") }
                HoverTip { mouse: protonAppMouse; text: "Open Proton VPN for sign-in and location selection" }
              }
              ControlSwitch {
                anchors.verticalCenter: parent.verticalCenter
                enabled: !!protonVpnCard.state.available
                checked: !!protonVpnCard.state.connected
                busy: protonVpnCard.busy
                onToggled: root.runControl("proton-vpn", protonVpnCard.action)
              }
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
                readonly property bool busy: root.controlBusy(modelData.action, modelData.value)
                readonly property bool complete: root.controlCompleted(modelData.action, modelData.value)
                readonly property bool failed: root.controlFailed(modelData.action, modelData.value)
                width: (parent.width - 8) / 2; height: 38; radius: root.radius
                color: networkActionMouse.pressed ? root.pressColor : failed ? root.dangerColor : complete ? root.successColor : busy ? root.selectedColor : networkActionMouse.containsMouse ? root.hoverColor : root.surface
                Text { visible: !parent.busy; anchors.centerIn: parent; text: parent.failed ? "× Failed" : parent.complete ? (modelData.action === "copy-ip" ? "✓ Copied" : "✓ Opened") : modelData.label; color: parent.failed ? root.red : parent.complete ? root.green : root.text; font.family: root.fontFamily; font.pixelSize: 9; font.bold: true }
                RefreshGlyph { visible: parent.busy; anchors.centerIn: parent; width: 18; height: 18; spinning: visible; font.pixelSize: 13 }
                MouseArea {
                  id: networkActionMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.runControl(parent.modelData.action, parent.modelData.value)
                }
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
      visible: root.controlPanel === "bluetooth" && root.pinnedScreen(root.overlayScreen, modelData)
      anchors { top: true; right: true }
      margins { top: root.barHeight + root.panelGap; right: root.panelGap }
      implicitWidth: 360
      implicitHeight: root.systemData.bluetoothPowered ? 124 + (devices.length === 0 ? 26 : listHeight) : 88
      exclusionMode: ExclusionMode.Ignore
      color: "transparent"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "seele-shell-bluetooth"

      PanelSurface {
        Column {
          anchors.fill: parent; anchors.margins: root.panelMargin; spacing: root.panelSpacing
          Row {
            width: parent.width; spacing: 8
            PanelGlyph { text: "󰂯" }
            Column {
              width: parent.width - 88
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
            ControlSwitch {
              anchors.verticalCenter: parent.verticalCenter
              checked: root.systemData.bluetoothPowered
              busy: bluetoothProcess.running && root.bluetoothAction === "toggle"
              onToggled: root.toggleBluetoothPower()
            }
          }
          Row {
            visible: root.systemData.bluetoothPowered
            width: parent.width; spacing: 8
            Text {
              width: parent.width - 42
              anchors.verticalCenter: parent.verticalCenter
              text: root.bluetoothScanActive ? "Searching for devices…" : "Search for new devices"
              color: root.bluetoothScanActive ? root.accent : root.subtext
              font.family: root.fontFamily
              font.pixelSize: 11
            }
            Rectangle {
              width: 34; height: 34; radius: root.radius
              color: bluetoothScanMouse.pressed ? root.pressColor : root.bluetoothScanActive ? root.activeTint : bluetoothScanMouse.containsMouse ? root.hoverColor : "transparent"
              RefreshGlyph { anchors.centerIn: parent; width: 20; height: 20; spinning: root.bluetoothScanActive }
              MouseArea {
                id: bluetoothScanMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.setBluetoothScanning(!root.bluetoothScanActive)
              }
              HoverTip { mouse: bluetoothScanMouse; text: root.bluetoothScanActive ? "Stop searching" : "Search for 30 seconds" }
            }
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
              readonly property bool busy: root.bluetoothBusy === modelData.address
              readonly property bool forgetArmed: root.bluetoothForget === modelData.address
              readonly property bool rowActions: !busy && modelData.paired && (deviceMouse.containsMouse || forgetMouse.containsMouse || autoConnectMouse.containsMouse || forgetArmed)
              width: ListView.view.width; height: 40; radius: root.radius
              color: deviceMouse.pressed ? root.pressColor : busy ? root.selectedColor : deviceMouse.containsMouse ? root.hoverColor : modelData.connected ? root.activeTint : root.alpha(root.surface, 0.55)
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
                  visible: !rowActions && !parent.parent.busy
                  text: root.bluetoothSignal(modelData)
                  color: root.overlay
                  font.family: root.fontFamily
                  font.pixelSize: 11
                }
              }
              RefreshGlyph { visible: parent.busy; anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; width: 16; height: 16; spinning: visible; font.pixelSize: 12 }
              MouseArea { id: deviceMouse; anchors.fill: parent; enabled: !parent.busy; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleBluetoothDevice(parent.modelData) }
              Rectangle {
                visible: rowActions
                anchors.right: parent.right
                anchors.rightMargin: 38
                anchors.verticalCenter: parent.verticalCenter
                width: 44; height: 24; radius: root.radius
                color: autoConnectMouse.pressed ? root.pressColor : modelData.trusted ? root.selectedColor : autoConnectMouse.containsMouse ? root.hoverColor : root.alpha(root.surface, 0.95)
                Text { anchors.centerIn: parent; text: "Auto"; color: modelData.trusted ? root.accent : root.subtext; font.family: root.fontFamily; font.pixelSize: 9; font.bold: true }
                MouseArea { id: autoConnectMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.runBluetooth("trust", modelData.address) }
                HoverTip { mouse: autoConnectMouse; text: modelData.trusted ? "Autoconnect on" : "Autoconnect off" }
              }
              Rectangle {
                visible: rowActions
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 24; height: 24; radius: root.radius
                color: forgetMouse.pressed || forgetArmed ? root.dangerPress : forgetMouse.containsMouse ? root.dangerColor : root.alpha(root.surface, 0.95)
                Text { anchors.centerIn: parent; text: "󰅖"; color: forgetArmed || forgetMouse.containsMouse ? root.red : root.subtext; font.family: root.fontFamily; font.pixelSize: 11 }
                MouseArea { id: forgetMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.forgetBluetoothDevice(modelData) }
              }
            }
          }
          Text {
            visible: root.systemData.bluetoothPowered && bluetoothWindow.devices.length === 0
            width: parent.width
            text: root.bluetoothScanActive ? "Looking for nearby devices…" : "No devices yet · start a search"
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
      visible: root.controlPanel === "airpods" && root.pinnedScreen(root.overlayScreen, modelData)
      anchors { top: true; right: true }
      margins { top: root.barHeight + root.panelGap; right: root.panelGap }
      implicitWidth: 340
      implicitHeight: 252
      exclusionMode: ExclusionMode.Ignore
      color: "transparent"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "seele-shell-airpods"

      PanelSurface {
        Column {
          anchors.fill: parent; anchors.margins: root.panelMargin; spacing: root.panelSpacing
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
                readonly property bool busy: root.controlBusy("airpods", modelData.mode)
                readonly property bool complete: root.controlCompleted("airpods", modelData.mode)
                readonly property bool failed: root.controlFailed("airpods", modelData.mode)
                width: (parent.width - 18) / 4; height: 40; radius: root.radius
                color: airpodsModeMouse.pressed ? root.pressColor : failed ? root.dangerColor : complete ? root.successColor : busy ? root.selectedColor : airpodsModeMouse.containsMouse ? root.hoverColor : root.surface
                Text { visible: !parent.busy; anchors.centerIn: parent; text: parent.failed ? "×" : parent.complete ? "✓ " + modelData.label : modelData.label; color: parent.failed ? root.red : parent.complete ? root.green : root.text; font.family: root.fontFamily; font.pixelSize: 9; font.bold: true }
                RefreshGlyph { visible: parent.busy; anchors.centerIn: parent; width: 16; height: 16; spinning: visible; font.pixelSize: 12 }
                MouseArea { id: airpodsModeMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.runControl("airpods", parent.modelData.mode) }
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
              busy: root.controlBusy("airpods", "ear-detection", "toggle")
              onToggled: if (root.runControl("airpods", "ear-detection", "toggle")) root.patchSystemData({ airpodsEarDetection: !root.systemData.airpodsEarDetection })
            }
          }
          Rectangle {
            readonly property bool busy: root.controlBusy("airpods", "open")
            readonly property bool complete: root.controlCompleted("airpods", "open")
            readonly property bool failed: root.controlFailed("airpods", "open")
            width: parent.width; height: 38; radius: root.radius
            color: airpodsDetailsMouse.pressed ? root.pressColor : failed ? root.dangerColor : complete ? root.successColor : busy ? root.selectedColor : airpodsDetailsMouse.containsMouse ? root.hoverColor : root.surface
            Text { visible: !parent.busy; anchors.centerIn: parent; text: parent.failed ? "× Could not open" : parent.complete ? "✓ Opened" : "Battery and AirPods settings"; color: parent.failed ? root.red : parent.complete ? root.green : root.text; font.family: root.fontFamily; font.pixelSize: 10; font.bold: true }
            RefreshGlyph { visible: parent.busy; anchors.centerIn: parent; width: 16; height: 16; spinning: visible; font.pixelSize: 12 }
            MouseArea { id: airpodsDetailsMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.runControl("airpods", "open") }
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
      visible: root.controlPanel === "battery" && root.pinnedScreen(root.overlayScreen, modelData)
      anchors { top: true; right: true }
      margins { top: root.barHeight + root.panelGap; right: root.panelGap }
      implicitWidth: 330
      implicitHeight: 78 + Math.max(1, Math.min(5, entries.length)) * 50
      exclusionMode: ExclusionMode.Ignore
      color: "transparent"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "seele-shell-battery"

      PanelSurface {
        Column {
          anchors.fill: parent; anchors.margins: root.panelMargin; spacing: root.panelSpacing
          Row {
            width: parent.width
            height: root.panelHeaderHeight
            PanelGlyph { text: "󰁹" }
            Text { anchors.verticalCenter: parent.verticalCenter; text: "Batteries"; color: root.text; font.family: root.fontFamily; font.pixelSize: 18; font.bold: true }
          }
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
      visible: root.controlPanel === "notifications" && root.pinnedScreen(root.overlayScreen, modelData)
      anchors { top: true; right: true }
      margins { top: root.barHeight + root.panelGap; right: root.panelGap }
      implicitWidth: 400
      implicitHeight: entries.length === 0 ? 162 : Math.min(520, 146 + entries.length * 66)
      exclusionMode: ExclusionMode.Ignore
      color: "transparent"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "seele-shell-notifications"

      function toggleHistory() {
        if (notificationSwap.running) return
        notificationSwap.fadeTarget = root.notificationHistoryOpen ? notificationSurface : notificationViewport
        notificationSwap.start()
      }

      onVisibleChanged: {
        if (visible) return
        notificationSwap.stop()
        notificationViewport.opacity = 1
        notificationSurface.opacity = 1
      }

      SequentialAnimation {
        id: notificationSwap

        property Item fadeTarget: notificationViewport

        NumberAnimation { target: notificationSwap.fadeTarget; property: "opacity"; to: 0; duration: 55; easing.type: Easing.OutQuad }
        ScriptAction { script: root.notificationHistoryOpen = !root.notificationHistoryOpen }
        PauseAnimation { duration: 16 }
        NumberAnimation { target: notificationSwap.fadeTarget; property: "opacity"; to: 1; duration: 75; easing.type: Easing.InQuad }
      }

      PanelSurface {
        id: notificationSurface

        Column {
          anchors.fill: parent; anchors.margins: root.panelMargin; spacing: root.panelSpacing
          Row {
            width: parent.width
            height: root.panelHeaderHeight
            PanelGlyph { text: root.systemData.dnd ? "󰂛" : "󰂚" }
            Text {
              width: parent.width - 152
              anchors.verticalCenter: parent.verticalCenter
              text: root.notificationHistoryOpen ? "Last 24 hours" : "Notifications"
              color: root.text
              font.family: root.fontFamily
              font.pixelSize: 18
              font.bold: true
            }
            Text { width: 40; anchors.verticalCenter: parent.verticalCenter; text: String(notificationWindow.entries.length); color: root.subtext; font.family: root.fontFamily; font.pixelSize: 11; horizontalAlignment: Text.AlignRight }
            Text { width: 40; anchors.verticalCenter: parent.verticalCenter; leftPadding: 10; text: "DND"; color: root.systemData.dnd ? root.yellow : root.subtext; font.family: root.fontFamily; font.pixelSize: 10 }
            ControlSwitch {
              anchors.verticalCenter: parent.verticalCenter
              checked: root.systemData.dnd
              busy: root.controlBusy("dnd", "")
              onToggled: if (root.runControl("dnd", "")) root.patchSystemData({ dnd: !root.systemData.dnd })
            }
          }
          Row {
            width: parent.width; spacing: 8
            Rectangle {
              width: (parent.width - 8) / 2; height: 36; radius: root.radius
              color: historyMouse.pressed ? root.pressColor : root.notificationHistoryOpen ? root.selectedColor : historyMouse.containsMouse ? root.hoverColor : root.surface
              Text {
                anchors.centerIn: parent
                text: root.notificationHistoryOpen ? "Back" : "History"
                color: root.text
                font.family: root.fontFamily
                font.pixelSize: 10
                font.bold: true
              }
              MouseArea { id: historyMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: notificationWindow.toggleHistory() }
              HoverTip { mouse: historyMouse; text: root.notificationHistoryOpen ? "Show current notifications" : "Show the past 24 hours" }
            }
            Rectangle {
              readonly property bool busy: root.controlBusy("notifications", "clear")
              readonly property bool complete: root.controlCompleted("notifications", "clear")
              readonly property bool failed: root.controlFailed("notifications", "clear")
              width: (parent.width - 8) / 2; height: 36; radius: root.radius
              color: clearMouse.pressed ? root.pressColor : failed ? root.dangerColor : complete ? root.successColor : busy ? root.selectedColor : clearMouse.containsMouse ? root.hoverColor : root.surface
              Text { visible: !parent.busy; anchors.centerIn: parent; text: parent.failed ? "× Failed" : parent.complete ? "✓ Cleared" : "Clear"; color: parent.failed ? root.red : parent.complete ? root.green : root.text; font.family: root.fontFamily; font.pixelSize: 10; font.bold: true }
              RefreshGlyph { visible: parent.busy; anchors.centerIn: parent; width: 16; height: 16; spinning: visible; font.pixelSize: 12 }
              MouseArea { id: clearMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clearNotifications() }
            }
          }
          Item {
            id: notificationViewport

            width: parent.width
            height: notificationWindow.entries.length > 0 ? parent.height - 78 : 46
            clip: true
            ListView {
              visible: notificationWindow.entries.length > 0
              anchors.fill: parent
              spacing: 6
              clip: true
              model: notificationWindow.entries
              delegate: Rectangle {
                id: notificationEntry

                required property var modelData
                width: ListView.view.width; height: 60; radius: root.radius; color: root.surface
                Column {
                  anchors.fill: parent; anchors.margins: 9; spacing: 3
                  Row {
                    width: parent.width
                    Text { width: parent.width - 84; text: modelData.summary || modelData.app_name || "Notification"; elide: Text.ElideRight; color: root.text; font.family: root.fontFamily; font.pixelSize: 11; font.bold: true }
                    Text { width: 58; text: root.agoText(modelData.time); color: root.overlay; font.family: root.fontFamily; font.pixelSize: 9; horizontalAlignment: Text.AlignRight }
                    Rectangle {
                      readonly property bool busy: root.controlBusy("notifications", "dismiss", String(notificationEntry.modelData.id))
                      visible: !root.notificationHistoryOpen
                      width: visible ? 26 : 0; height: 20; radius: root.radiusSmall
                      color: notificationDismissMouse.pressed ? root.dangerPress : busy ? root.selectedColor : notificationDismissMouse.containsMouse ? root.dangerColor : "transparent"
                      Text { visible: !parent.busy; anchors.centerIn: parent; text: "󰅖"; color: notificationDismissMouse.containsMouse ? root.red : root.subtext; font.family: root.fontFamily; font.pixelSize: 10 }
                      RefreshGlyph { visible: parent.busy; anchors.centerIn: parent; width: 14; height: 14; spinning: visible; font.pixelSize: 10 }
                      MouseArea {
                        id: notificationDismissMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.dismissNotification(notificationEntry.modelData.id)
                      }
                    }
                  }
                  Text { width: parent.width; text: modelData.body || modelData.app_name || ""; elide: Text.ElideRight; color: root.subtext; font.family: root.fontFamily; font.pixelSize: 9 }
                }
              }
            }
            Item {
              visible: notificationWindow.entries.length === 0
              anchors.fill: parent
              Text {
                anchors.top: parent.top; anchors.topMargin: 14; anchors.horizontalCenter: parent.horizontalCenter
                text: root.notificationHistoryOpen ? "Nothing arrived in the past 24 hours" : "No notifications right now"
                color: root.overlay
                font.family: root.fontFamily
                font.pixelSize: 10
                horizontalAlignment: Text.AlignHCenter
              }
            }
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
      visible: root.controlPanel === "camera" && root.pinnedScreen(root.overlayScreen, modelData)
      anchors { top: true; right: true }
      margins { top: root.barHeight + root.panelGap; right: root.panelGap }
      implicitWidth: 360
      implicitHeight: 344
      exclusionMode: ExclusionMode.Ignore
      color: "transparent"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "seele-shell-camera"

      PanelSurface {
        Column {
          anchors.fill: parent; anchors.margins: root.panelMargin; spacing: root.panelSpacing
          Row {
            width: parent.width
            height: root.panelHeaderHeight
            PanelGlyph { text: "󰄀" }
            Text { anchors.verticalCenter: parent.verticalCenter; text: "Webcam"; color: root.text; font.family: root.fontFamily; font.pixelSize: 18; font.bold: true }
          }
          Text { text: root.systemData.cameraActive ? "Camera is in use" : root.systemData.cameraDevices.length + " camera device" + (root.systemData.cameraDevices.length === 1 ? "" : "s"); color: root.systemData.cameraActive ? root.red : root.subtext; font.family: root.fontFamily; font.pixelSize: 11 }
          Text { width: parent.width; text: root.systemData.cameraDevices.length > 0 ? root.systemData.cameraDevices[0].name : "No camera detected"; elide: Text.ElideRight; color: root.text; font.family: root.fontFamily; font.pixelSize: 10 }
          ClippingRectangle {
            z: 2
            width: parent.width; height: 176; radius: root.radius; color: root.mantle
            Loader {
              id: cameraPreviewLoader
              anchors.fill: parent
              active: cameraWindow.visible && root.systemData.cameraDevices.length > 0
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
                readonly property bool busy: root.controlBusy(modelData.action, root.systemData.cameraDevice)
                readonly property bool complete: root.controlCompleted(modelData.action, root.systemData.cameraDevice)
                readonly property bool failed: root.controlFailed(modelData.action, root.systemData.cameraDevice)
                width: (parent.width - 8) / 2; height: 42; radius: root.radius
                color: cameraActionMouse.pressed ? root.pressColor : failed ? root.dangerColor : complete ? root.successColor : busy ? root.selectedColor : cameraActionMouse.containsMouse ? root.hoverColor : root.surface
                Text { visible: !parent.busy; anchors.centerIn: parent; text: parent.failed ? "× Failed" : parent.complete ? "✓ Opened" : modelData.label; color: parent.failed ? root.red : parent.complete ? root.green : root.text; font.family: root.fontFamily; font.pixelSize: 10; font.bold: true }
                RefreshGlyph { visible: parent.busy; anchors.centerIn: parent; width: 16; height: 16; spinning: visible; font.pixelSize: 12 }
                MouseArea {
                  id: cameraActionMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (parent.modelData.action === "camera-preview") root.openCameraPreview(root.systemData.cameraDevice)
                    else root.runControl(parent.modelData.action, root.systemData.cameraDevice)
                  }
                }
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
      visible: root.controlPanel === "system" && root.pinnedScreen(root.overlayScreen, modelData)
      anchors { top: true; right: true }
      margins { top: root.barHeight + root.panelGap; right: root.panelGap }
      implicitWidth: 420
      implicitHeight: 222
      exclusionMode: ExclusionMode.Ignore
      color: "transparent"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "seele-shell-session"

      PanelSurface {
        Column {
          anchors.fill: parent; anchors.margins: root.panelMargin; spacing: root.panelSpacing
          Row {
            width: parent.width
            height: root.panelHeaderHeight
            PanelGlyph { text: "󰐥" }
            Text { anchors.verticalCenter: parent.verticalCenter; text: "Power"; color: root.text; font.family: root.fontFamily; font.pixelSize: 18; font.bold: true }
          }
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
                width: (parent.width - 16) / 3; height: 72; radius: root.radius
                color: modelData.variant === "destructive" ? (sessionActionMouse.pressed ? root.dangerPress : sessionActionMouse.containsMouse ? root.dangerColor : root.dangerTint) : sessionActionMouse.pressed ? root.pressColor : sessionActionMouse.containsMouse ? root.hoverColor : root.surface
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
                  cursorShape: Qt.PointingHandCursor
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
      visible: root.osdOpen && root.pinnedScreen(root.osdScreen, modelData)
      anchors { top: true }
      margins.top: root.barHeight + root.osdGap
      implicitWidth: 300
      implicitHeight: 58
      exclusionMode: ExclusionMode.Ignore
      color: "transparent"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "seele-shell-osd"
      PanelSurface {
        Row {
          visible: root.osdKind === "volume"
          anchors.fill: parent; anchors.margins: 14; spacing: 12
          Text { anchors.verticalCenter: parent.verticalCenter; text: root.systemData.muted ? "󰝟" : "󰕾"; color: root.systemData.muted ? root.red : root.accent; font.family: root.fontFamily; font.pixelSize: 20 }
          Rectangle {
            width: 205; height: 8; anchors.verticalCenter: parent.verticalCenter; radius: 4; color: root.surface
            Rectangle { width: parent.width * Math.max(0, Math.min(1, Number(root.volumeDrag >= 0 ? root.volumeDrag : root.systemData.volume) / 100)); height: parent.height; radius: 4; color: root.accent }
          }
          Text { anchors.verticalCenter: parent.verticalCenter; text: (root.volumeDrag >= 0 ? root.volumeDrag : root.systemData.volume) + "%"; color: root.text; font.family: root.fontFamily; font.pixelSize: 11 }
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
