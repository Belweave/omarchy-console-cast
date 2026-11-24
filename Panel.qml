import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// The details panel under the bar icon: the state, Start and Stop, the two DNS addresses for
// the console (with copy), the destinations and whether each is on, the free week or the
// subscription, and a way to open Console Cast.
Panel {
  id: panelRoot
  moduleName: "belweave.console-cast"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var service: null

  readonly property string phase: service ? service.phase : "off"
  readonly property bool installed: service ? service.installed === "yes" : false
  readonly property bool running: service ? service.running : false
  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color urgent: bar ? bar.urgent : Commons.Color.urgent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // Stopping while the console's picture or a destination is on air takes a second click.
  property bool confirmStop: false

  function open() {
    panelRoot.confirmStop = false
    panelRoot.controller.show()
  }

  function close() {
    panelRoot.confirmStop = false
    panelRoot.controller.hide()
  }

  function toggle() {
    if (panelRoot.opened) panelRoot.close()
    else panelRoot.open()
  }

  function switchPanel(direction) {
    if (panelRoot.bar && typeof panelRoot.bar.switchPanelFrom === "function")
      return panelRoot.bar.switchPanelFrom(panelRoot.hostWidget || panelRoot, direction)
    return false
  }

  function stop() {
    if (!service) return
    if (service.onAir && !confirmStop) {
      confirmStop = true
      confirmTimer.restart()
      return
    }
    confirmStop = false
    service.stop()
  }

  // The service polls faster, and fetches destinations and the free week, only while open.
  Binding {
    target: panelRoot.service
    property: "panelOpen"
    value: panelRoot.opened
    when: panelRoot.service !== null
  }

  Timer {
    id: confirmTimer
    interval: 4000
    onTriggered: panelRoot.confirmStop = false
  }

  KeyboardPanel {
    id: panel
    anchorItem: panelRoot.anchorItem
    owner: panelRoot.hostWidget || panelRoot
    bar: panelRoot.bar
    open: panelRoot.opened
    focusTarget: panel.loadedContent
    contentWidth: panel.fittedContentWidth(Style.space(300))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight)

    content: PanelKeyCatcher {
      implicitHeight: column.implicitHeight
      anchors.fill: parent
      onCloseRequested: panelRoot.close()
      onTabRequested: function(direction) { panelRoot.switchPanel(direction) }

      Column {
        id: column
        width: parent.width
        spacing: Style.space(12)

        PanelHero {
          width: parent.width
          title: "Console Cast"
          meta: panelRoot.service ? panelRoot.service.stateLabel : ""
          foreground: panelRoot.foreground
          fontFamily: panelRoot.fontFamily
          iconOpacity: panelRoot.phase === "missing" || panelRoot.phase === "off" ? 0.5 : 1.0
          iconComponent: Component {
            Text {
              textFormat: Text.PlainText
              text: String.fromCodePoint(panelRoot.phase === "missing" || panelRoot.phase === "off" || panelRoot.phase === "error" ? 0xF1721 : 0xF1720)
              color: panelRoot.phase === "live" || panelRoot.phase === "error" ? panelRoot.urgent
                : panelRoot.phase === "connected" ? Commons.Color.accent : panelRoot.foreground
              font.family: panelRoot.fontFamily
              font.pixelSize: Style.font.display
            }
          }
        }

        Text {
          visible: panelRoot.phase === "error" && panelRoot.service !== null && !!panelRoot.service.status && !!panelRoot.service.status.error
          width: parent.width
          textFormat: Text.PlainText
          text: visible ? String(panelRoot.service.status.error) : ""
          color: panelRoot.urgent
          font.family: panelRoot.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        Row {
          spacing: Style.space(8)

          Button {
            visible: panelRoot.installed && (!panelRoot.running || panelRoot.phase === "passthrough")
            text: "Start"
            foreground: panelRoot.foreground
            fontFamily: panelRoot.fontFamily
            bordered: true
            enabled: panelRoot.phase !== "starting"
            onClicked: panelRoot.service.start()
          }

          Button {
            visible: panelRoot.installed && panelRoot.running && panelRoot.phase !== "starting"
            text: panelRoot.confirmStop ? "Stop broadcast" : "Stop"
            foreground: panelRoot.confirmStop ? panelRoot.urgent : panelRoot.foreground
            fontFamily: panelRoot.fontFamily
            bordered: true
            onClicked: panelRoot.stop()
          }

          Button {
            text: panelRoot.installed ? "Open Console Cast" : "Get Console Cast"
            foreground: panelRoot.foreground
            fontFamily: panelRoot.fontFamily
            bordered: true
            enabled: panelRoot.service !== null && panelRoot.service.installed !== "unknown"
            onClicked: { panelRoot.service.openApp(); panelRoot.close() }
          }
        }

        PanelSeparator {
          visible: dnsColumn.visible
          foreground: panelRoot.foreground
        }

        Column {
          id: dnsColumn
          visible: panelRoot.service !== null && panelRoot.service.dns.length > 0
          width: parent.width
          spacing: Style.space(6)

          PanelSectionHeader {
            text: "Console DNS"
            foreground: panelRoot.foreground
            fontFamily: panelRoot.fontFamily
          }

          Repeater {
            model: panelRoot.service ? panelRoot.service.dns : []

            Item {
              required property var modelData
              width: dnsColumn.width
              implicitHeight: Math.max(dnsLabel.implicitHeight, copyButton.height)

              Text {
                id: dnsLabel
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: modelData.label
                color: panelRoot.dim
                font.family: panelRoot.fontFamily
                font.pixelSize: Style.font.body
              }

              Text {
                anchors.right: copyButton.left
                anchors.rightMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: modelData.value
                color: modelData.copy ? panelRoot.foreground : panelRoot.dim
                font.family: panelRoot.fontFamily
                font.pixelSize: modelData.copy ? Style.font.title : Style.font.body
              }

              // Only this computer's own address and 0.0.0.0 can be copied (Model.dnsRows).
              PanelActionButton {
                id: copyButton
                visible: modelData.copy === true
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                iconText: String.fromCodePoint(0xF018F)
                tooltipText: "Copy"
                foreground: panelRoot.foreground
                fontFamily: panelRoot.fontFamily
                onClicked: if (modelData.copy === true) panelRoot.service.copy(modelData.value)
              }
            }
          }
        }

        PanelSeparator {
          visible: destinationColumn.visible
          foreground: panelRoot.foreground
        }

        Column {
          id: destinationColumn
          visible: panelRoot.service !== null && panelRoot.service.destinations.length > 0
          width: parent.width
          spacing: Style.space(6)

          PanelSectionHeader {
            text: "Destinations"
            foreground: panelRoot.foreground
            fontFamily: panelRoot.fontFamily
          }

          Repeater {
            model: panelRoot.service ? panelRoot.service.destinations : []

            Item {
              required property var modelData
              width: destinationColumn.width
              implicitHeight: hostText.implicitHeight

              Text {
                id: hostText
                anchors.left: parent.left
                anchors.right: onText.left
                anchors.rightMargin: Style.space(8)
                textFormat: Text.PlainText
                text: modelData.host
                elide: Text.ElideRight
                color: panelRoot.foreground
                font.family: panelRoot.fontFamily
                font.pixelSize: Style.font.body
              }

              Text {
                id: onText
                anchors.right: parent.right
                textFormat: Text.PlainText
                text: modelData.label
                color: modelData.on ? Commons.Color.accent : panelRoot.dim
                font.family: panelRoot.fontFamily
                font.pixelSize: Style.font.body
              }
            }
          }
        }

        PanelSeparator {
          visible: licenseItem.visible
          foreground: panelRoot.foreground
        }

        Item {
          id: licenseItem
          visible: panelRoot.installed && panelRoot.service !== null && panelRoot.service.licenseRow !== null
          width: parent.width
          implicitHeight: licenseLabel.implicitHeight

          Text {
            id: licenseLabel
            anchors.left: parent.left
            textFormat: Text.PlainText
            text: licenseItem.visible ? panelRoot.service.licenseRow.label : ""
            color: panelRoot.dim
            font.family: panelRoot.fontFamily
            font.pixelSize: Style.font.body
          }

          Text {
            anchors.right: parent.right
            textFormat: Text.PlainText
            text: licenseItem.visible ? panelRoot.service.licenseRow.value : ""
            color: panelRoot.foreground
            font.family: panelRoot.fontFamily
            font.pixelSize: Style.font.body
          }
        }
      }
    }
  }
}
