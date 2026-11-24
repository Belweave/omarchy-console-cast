import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Console Cast in the bar: one icon whose look is the state. Left click opens the panel.
BarWidget {
  id: root
  moduleName: "belweave.console-cast"

  // The plugin's one service (Service.qml), shared by every bar.
  readonly property var service: bar && bar.shell && typeof bar.shell.serviceFor === "function"
    ? bar.shell.serviceFor(root.moduleName) : null
  readonly property string phase: service ? service.phase : "off"

  readonly property color foreground: bar ? bar.barForeground : Commons.Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function toggle() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    target.bar = root.bar
    target.anchorItem = button
    target.hostWidget = root
    target.service = root.service
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  onBarChanged: injectPanel()
  onServiceChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    // Broadcast waves when Console Cast runs, crossed out when it does not; dimmed while it is
    // not installed or starting, the accent once the console is connected, and the bar's alert
    // colour while the console's picture is live (crossed out on an error).
    text: String.fromCodePoint(root.phase === "missing" || root.phase === "off" || root.phase === "error" ? 0xF1721 : 0xF1720)
    foreground: root.phase === "connected" ? Commons.Color.accent
      : (root.phase === "missing" || root.phase === "starting") ? root.dim
      : root.foreground
    active: root.phase === "live" || root.phase === "error"
    tooltipText: root.service ? root.service.stateLabel : ""
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.toggle()
    }
  }
}
