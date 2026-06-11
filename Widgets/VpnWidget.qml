import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    layerNamespacePlugin: "openfortivpn"

    // Settings data loaded reactively from pluginData
    property string vpnHost: pluginData.vpnHost || ""
    property string vpnPort: pluginData.vpnPort || "443"
    property string vpnUser: pluginData.vpnUser || ""
    property string vpnPassword: pluginData.vpnPassword || ""
    property string vpnCert: pluginData.vpnCert || ""
    property string postConnectCmd: pluginData.postConnectCmd || ""
    property string postDisconnectCmd: pluginData.postDisconnectCmd || ""
    property bool vpnEnabled: pluginData.vpnEnabled || false

    // Internal state
    property string connectionStatus: "disconnected" // "disconnected", "connecting", "connected", "disconnecting"
    property string logBuffer: ""
    property var logLines: []
    property bool _initialized: false

    Component.onCompleted: {
        Qt.callLater(function() {
            _initialized = true;
            if (vpnEnabled) {
                startVpn();
            }
        });
    }

    onVpnEnabledChanged: {
        if (_initialized) {
            if (vpnEnabled) {
                startVpn();
            } else {
                stopVpn();
            }
        }
    }

    function startVpn() {
        if (!vpnHost || vpnHost.trim() === "") {
            ToastService.showError("VPN Gateway Host is not configured. Set it in settings.");
            disableVpnToggle();
            return;
        }

        connectionStatus = "connecting";
        logBuffer = "Writing configuration file to ~/.config/openfortivpn/config...\n";
        logLines = ["Writing configuration file to ~/.config/openfortivpn/config..."];

        // Generate the configuration content safely
        let content = "host = " + vpnHost.trim() + "\n"
                    + "port = " + (vpnPort ? vpnPort.trim() : "443") + "\n";
        if (vpnUser && vpnUser.trim() !== "") {
            content += "username = " + vpnUser.trim() + "\n";
        }
        if (vpnPassword && vpnPassword.trim() !== "") {
            content += "password = " + vpnPassword + "\n";
        }
        if (vpnCert && vpnCert.trim() !== "") {
            content += "trusted-cert = " + vpnCert.trim() + "\n";
        }

        // JavaScript single-quote escaping for bash
        function escapeShellArg(arg) {
            return "'" + arg.replace(/'/g, "'\\''") + "'";
        }

        const escapedContent = escapeShellArg(content);
        const writeScript = "mkdir -p ~/.config/openfortivpn && echo -n " + escapedContent + " > ~/.config/openfortivpn/config && chmod 600 ~/.config/openfortivpn/config";

        Proc.runCommand("write_config", ["bash", "-c", writeScript], function(out, code) {
            if (code !== 0) {
                ToastService.showError("Failed to write VPN config: " + out);
                connectionStatus = "disconnected";
                disableVpnToggle();
                return;
            }

            handleLogLine("Config written to ~/.config/openfortivpn/config. Starting VPN tunnel...");
            vpnProcess.running = true;
        });
    }

    function stopVpn() {
        connectionStatus = "disconnecting";
        vpnProcess.running = false;

        // Ensure no orphaned processes exist
        cleanupOrphans();
    }

    function cleanupOrphans() {
        Proc.runCommand("cleanup_vpn", ["sudo", "killall", "openfortivpn"], function(out, code) {
            if (postDisconnectCmd && postDisconnectCmd.trim() !== "") {
                Quickshell.execDetached(["bash", "-c", postDisconnectCmd]);
            }
            connectionStatus = "disconnected";
            ToastService.showInfo("VPN Disconnected.");
        });
    }

    function disableVpnToggle() {
        pluginService.savePluginData(pluginId, "vpnEnabled", false);
    }

    function handleLogLine(line) {
        logBuffer += line + "\n";
        if (logBuffer.length > 5000) {
            logBuffer = logBuffer.substring(logBuffer.length - 5000);
        }

        let lines = [...root.logLines];
        lines.push(line);
        if (lines.length > 10) {
            lines.shift();
        }
        root.logLines = lines;

        console.log("[OpenFortiVPN] " + line);

        if (line.indexOf("INFO:   Tunnel is up and running.") !== -1 || line.indexOf("Tunnel is up and running.") !== -1) {
            connectionStatus = "connected";
            ToastService.showInfo("VPN Connected.");
            if (postConnectCmd && postConnectCmd.trim() !== "") {
                Quickshell.execDetached(["bash", "-c", postConnectCmd]);
            }
        }
    }

    Process {
        id: vpnProcess
        command: ["sudo", "openfortivpn", "-c", "/home/qrobcis/.config/openfortivpn/config"]
        running: false

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                root.handleLogLine(data);
            }
        }
        stderr: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                root.handleLogLine(data);
            }
        }

        onExited: (exitCode, exitStatus) => {
            handleLogLine("Process exited (code: " + exitCode + ", status: " + exitStatus + ")");
            if (root.connectionStatus === "connected" || root.connectionStatus === "connecting") {
                if (exitCode !== 0) {
                    ToastService.showError("VPN disconnected unexpectedly (code: " + exitCode + ").");
                }
                root.stopVpn();
                root.disableVpnToggle();
            }
        }
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingS
            anchors.verticalCenter: parent.verticalCenter

            DankIcon {
                name: "vpn_lock"
                size: root.iconSize
                color: root.connectionStatus === "connected" ? Theme.primary :
                       root.connectionStatus === "connecting" ? Theme.tertiary : Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: root.connectionStatus === "connected" ? "VPN On" :
                      root.connectionStatus === "connecting" ? "VPN..." : "VPN Off"
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS
            anchors.horizontalCenter: parent.horizontalCenter

            DankIcon {
                name: "vpn_lock"
                size: root.iconSize
                color: root.connectionStatus === "connected" ? Theme.primary :
                       root.connectionStatus === "connecting" ? Theme.tertiary : Theme.surfaceText
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: root.connectionStatus === "connected" ? "ON" :
                      root.connectionStatus === "connecting" ? "..." : "OFF"
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeSmall - 1
                font.weight: Font.Medium
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    popoutContent: Component {
        PopoutComponent {
            id: popoutColumn

            headerText: "OpenFortiVPN"
            detailsText: "Manage your secure VPN tunnel"
            showCloseButton: true

            Column {
                width: parent.width
                spacing: Theme.spacingL

                StyledRect {
                    width: parent.width
                    height: 60
                    radius: Theme.cornerRadius
                    color: root.connectionStatus === "connected" ? Theme.primaryContainer : Theme.surfaceContainerHigh

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingM
                        anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "vpn_lock"
                            size: 28
                            color: root.connectionStatus === "connected" ? Theme.primary : Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            StyledText {
                                text: root.connectionStatus === "connected" ? "VPN Connected" :
                                      root.connectionStatus === "connecting" ? "VPN Connecting..." : "VPN Inactive"
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Bold
                                color: root.connectionStatus === "connected" ? Theme.primaryText : Theme.surfaceText
                            }
                            StyledText {
                                text: root.connectionStatus === "connected" ? (root.vpnUser ? root.vpnUser + "@" + root.vpnHost : root.vpnHost) : "Tunnel interface inactive"
                                font.pixelSize: Theme.fontSizeSmall
                                color: root.connectionStatus === "connected" ? Theme.primaryText : Theme.surfaceVariantText
                                elide: Text.ElideRight
                                width: 220
                            }
                        }
                    }
                }

                DankToggle {
                    id: vpnToggle
                    width: parent.width
                    text: "Enable VPN Connection"
                    description: "Connect to corporate network"
                    checked: root.vpnEnabled
                    onToggled: (isChecked) => {
                        pluginService.savePluginData(pluginId, "vpnEnabled", isChecked);
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingS
                    visible: root.vpnHost !== ""

                    StyledText {
                        text: "Configuration Details"
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Bold
                        color: Theme.surfaceVariantText
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM
                        DankIcon {
                            name: "dns"
                            size: 18
                            color: Theme.surfaceVariantText
                        }
                        StyledText {
                            text: "Gateway: " + root.vpnHost + ":" + root.vpnPort
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            wrapMode: Text.WrapAnywhere
                            width: popoutColumn.width - 60
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM
                        DankIcon {
                            name: "person"
                            size: 18
                            color: Theme.surfaceVariantText
                            visible: root.vpnUser !== ""
                        }
                        StyledText {
                            text: "Username: " + root.vpnUser
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            wrapMode: Text.WrapAnywhere
                            width: popoutColumn.width - 60
                            visible: root.vpnUser !== ""
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingS
                    visible: root.logLines.length > 0

                    StyledText {
                        text: "Connection Log"
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Bold
                        color: Theme.surfaceVariantText
                    }

                    StyledRect {
                        width: parent.width
                        height: 120
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainerLow
                        border.color: Theme.outlineVariant
                        border.width: 1

                        ListView {
                            id: logView
                            anchors.fill: parent
                            anchors.margins: Theme.spacingS
                            model: root.logLines
                            delegate: StyledText {
                                text: modelData
                                font.family: "Adwaita Mono"
                                font.pixelSize: Theme.fontSizeSmall - 2
                                color: Theme.surfaceVariantText
                                width: logView.width
                                wrapMode: Text.WrapAnywhere
                            }
                            clip: true
                            onCountChanged: {
                                Qt.callLater(logView.positionViewAtEnd);
                            }
                        }
                    }
                }

                StyledText {
                    width: parent.width
                    text: "⚠️ VPN Gateway Host is not configured. Set it in Settings > Plugins > OpenFortiVPN."
                    color: Theme.error
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.WordWrap
                    visible: root.vpnHost === ""
                }
            }
        }
    }

    popoutWidth: 320
    popoutHeight: root.logLines.length > 0 ? 440 : (root.vpnHost !== "" ? 300 : 250)

    ccWidgetIcon: "vpn_lock"
    ccWidgetPrimaryText: "OpenFortiVPN"
    ccWidgetSecondaryText: root.connectionStatus === "connected" ? (root.vpnHost ? root.vpnHost : "Connected") :
                            root.connectionStatus === "connecting" ? "Connecting..." : "Disconnected"
    ccWidgetIsActive: root.vpnEnabled

    onCcWidgetToggled: {
        const newState = !root.vpnEnabled;
        pluginService.savePluginData(pluginId, "vpnEnabled", newState);
    }
}
