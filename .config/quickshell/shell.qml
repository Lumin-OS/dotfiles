// LuminOS's desktop shell: a bar on every screen, and notification
// popups. Quickshell runs ~/.config/quickshell/shell.qml, and hyprland.lua
// starts it. https://quickshell.org/docs/

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Quickshell.Widgets

ShellRoot {
    id: shell

    // Rosé Pine, like the window borders and the rofi theme.
    readonly property color base: "#191724"
    readonly property color surface: "#1f1d2e"
    readonly property color overlay: "#26233a"
    readonly property color text: "#e0def4"
    readonly property color accent: "#9ccfd8"
    readonly property color urgent: "#eb6f92"
    readonly property string font: "JetBrains Mono"

    // Nerd Font icons, from the Nerd symbols fonts.
    readonly property string volumeIcon: String.fromCodePoint(0xF057E)
    readonly property string mutedIcon: String.fromCodePoint(0xF0581)
    readonly property string batteryIcon: String.fromCodePoint(0xF0079)
    readonly property string chargingIcon: String.fromCodePoint(0xF0084)

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // Keeps the default output's volume and mute state up to date.
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bar

            required property var modelData
            screen: modelData

            anchors {
                top: true
                left: true
                right: true
            }
            implicitHeight: 30
            color: shell.base

            // This screen's workspaces; a click switches to one.
            Row {
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Repeater {
                    model: Hyprland.workspaces

                    Rectangle {
                        id: workspace

                        required property HyprlandWorkspace modelData

                        // Special workspaces have negative ids.
                        visible: modelData.id > 0 && modelData.monitor?.name === bar.screen.name
                        width: 22
                        height: 22
                        radius: 6
                        color: modelData.focused ? shell.accent : (modelData.active ? shell.overlay : "transparent")

                        Text {
                            anchors.centerIn: parent
                            text: workspace.modelData.name
                            color: workspace.modelData.focused ? shell.base : shell.text
                            font.family: shell.font
                            font.pixelSize: 12
                        }

                        MouseArea {
                            anchors.fill: parent
                            // A Lua dispatcher, as Hyprland's Lua config expects.
                            onClicked: Hyprland.dispatch(`hl.dsp.focus({ workspace = ${workspace.modelData.id} })`)
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                text: Qt.formatDateTime(clock.date, "ddd d MMM   HH:mm")
                color: shell.text
                font.family: shell.font
                font.pixelSize: 13
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 14

                // Tray icons: a left click activates the app, a right click
                // opens its menu.
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Repeater {
                        model: SystemTray.items

                        IconImage {
                            id: trayIcon

                            required property SystemTrayItem modelData

                            source: modelData.icon
                            implicitSize: 18

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: mouse => {
                                    const item = trayIcon.modelData;
                                    if (mouse.button === Qt.LeftButton && !item.onlyMenu) {
                                        item.activate();
                                    } else if (item.hasMenu) {
                                        const position = bar.itemPosition(trayIcon);
                                        item.display(bar, position.x, position.y + trayIcon.height);
                                    }
                                }
                            }
                        }
                    }
                }

                // Volume: a click mutes, the scroll wheel turns it up or down.
                Text {
                    id: volume

                    readonly property PwNode sink: Pipewire.defaultAudioSink

                    anchors.verticalCenter: parent.verticalCenter
                    visible: sink?.audio != null
                    text: !visible ? "" : sink.audio.muted
                        ? `${shell.mutedIcon} muted`
                        : `${shell.volumeIcon} ${Math.round(sink.audio.volume * 100)}%`
                    color: shell.text
                    font.family: shell.font
                    font.pixelSize: 13

                    MouseArea {
                        anchors.fill: parent
                        onClicked: volume.sink.audio.muted = !volume.sink.audio.muted
                        onWheel: wheel => {
                            const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                            volume.sink.audio.volume = Math.max(0, Math.min(1, volume.sink.audio.volume + step));
                        }
                    }
                }

                // Battery, on laptops.
                Text {
                    readonly property UPowerDevice battery: UPower.displayDevice
                    // Quickshell 0.3 gives a fraction (energy / capacity);
                    // older versions gave 0 to 100.
                    readonly property int percent: Math.round(battery.percentage > 1 ? battery.percentage : battery.percentage * 100)

                    anchors.verticalCenter: parent.verticalCenter
                    visible: battery.isLaptopBattery
                    text: `${UPower.onBattery ? shell.batteryIcon : shell.chargingIcon} ${percent}%`
                    color: percent <= 10 && UPower.onBattery ? shell.urgent : shell.text
                    font.family: shell.font
                    font.pixelSize: 13
                }
            }
        }
    }

    NotificationServer {
        id: notifications

        // Keep each notification until it times out or is clicked away.
        onNotification: notification => notification.tracked = true
    }

    // Notification popups, in the top-right corner of the focused screen.
    PanelWindow {
        screen: {
            const screens = Quickshell.screens;
            for (let i = 0; i < screens.length; i++) {
                if (screens[i].name === Hyprland.focusedMonitor?.name)
                    return screens[i];
            }
            return screens[0];
        }

        anchors {
            top: true
            right: true
        }
        margins {
            top: 8
            right: 8
        }
        exclusiveZone: 0
        implicitWidth: 360
        implicitHeight: Math.max(1, popups.implicitHeight)
        color: "transparent"
        visible: notifications.trackedNotifications.values.length > 0

        Column {
            id: popups

            width: parent.width
            spacing: 8

            Repeater {
                model: notifications.trackedNotifications

                Rectangle {
                    id: popup

                    required property Notification modelData

                    width: popups.width
                    implicitHeight: content.implicitHeight + 20
                    radius: 10
                    color: shell.surface
                    border.width: 1
                    border.color: modelData.urgency === NotificationUrgency.Critical ? shell.urgent : shell.accent

                    Column {
                        id: content

                        anchors {
                            top: parent.top
                            left: parent.left
                            right: parent.right
                            margins: 10
                        }
                        spacing: 4

                        Text {
                            width: parent.width
                            text: popup.modelData.summary
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: shell.text
                            font.family: shell.font
                            font.pixelSize: 13
                            font.bold: true
                        }

                        Text {
                            width: parent.width
                            visible: text !== ""
                            text: popup.modelData.body
                            textFormat: Text.PlainText
                            wrapMode: Text.Wrap
                            maximumLineCount: 4
                            elide: Text.ElideRight
                            color: shell.text
                            font.family: shell.font
                            font.pixelSize: 12
                        }
                    }

                    // A click dismisses it.
                    MouseArea {
                        anchors.fill: parent
                        onClicked: popup.modelData.dismiss()
                    }

                    // Critical ones stay until clicked; the rest go after
                    // their own timeout, or 5 seconds.
                    Timer {
                        running: popup.modelData.urgency !== NotificationUrgency.Critical
                        interval: (popup.modelData.expireTimeout > 0 ? popup.modelData.expireTimeout : 5) * 1000
                        onTriggered: popup.modelData.expire()
                    }
                }
            }
        }
    }
}
