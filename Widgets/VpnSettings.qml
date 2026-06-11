import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "openfortivpn"

    StyledText {
        width: parent.width
        text: "OpenFortiVPN Settings"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Configure gateway host, credentials, trusted certificate, and custom hooks. Activating the VPN will generate the local openfortivpn config file and execute the tunnel connection daemon."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    StringSetting {
        settingKey: "vpnHost"
        label: "VPN Gateway Host"
        description: "Address of the Fortinet VPN gateway (e.g. vpn.company.com)"
        placeholder: "vpn.company.com"
        defaultValue: ""
    }

    StringSetting {
        settingKey: "vpnPort"
        label: "Port"
        description: "VPN gateway port (default: 443)"
        placeholder: "443"
        defaultValue: "443"
    }

    StringSetting {
        settingKey: "vpnUser"
        label: "Username"
        description: "VPN username"
        placeholder: "username"
        defaultValue: ""
    }

    Column {
        width: parent.width
        spacing: Theme.spacingS

        property string settingKey: "vpnPassword"
        property string label: "Password"
        property string description: "VPN password"
        property string defaultValue: ""
        property string value: defaultValue
        property bool isInitialized: false

        function loadValue() {
            const settings = root;
            if (settings) {
                const loadedValue = settings.loadValue(settingKey, defaultValue);
                if (pwdField.getActiveFocus() && isInitialized)
                    return;
                value = loadedValue;
                pwdField.text = loadedValue;
                isInitialized = true;
            }
        }

        Component.onCompleted: {
            Qt.callLater(loadValue);
        }

        function commit() {
            if (!isInitialized)
                return;
            if (pwdField.text === value)
                return;
            value = pwdField.text;
            const settings = root;
            if (settings)
                settings.saveValue(settingKey, value);
        }

        StyledText {
            text: parent.label
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        StyledText {
            text: parent.description
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            width: parent.width
            wrapMode: Text.WordWrap
        }

        DankTextField {
            id: pwdField
            width: parent.width
            placeholderText: "password"
            showPasswordToggle: true
            echoMode: passwordVisible ? TextInput.Normal : TextInput.Password
            onEditingFinished: parent.commit()
            onFocusStateChanged: (hasFocus) => {
                if (!hasFocus)
                    parent.commit();
            }
        }
    }

    StringSetting {
        settingKey: "vpnCert"
        label: "Trusted Certificate Hash (Optional)"
        description: "The trusted-cert sha256 hash. If left empty, it will be omitted (though openfortivpn may require it if gateway cert is untrusted)."
        placeholder: "e.g. 5d57b282..."
        defaultValue: ""
    }

    StringSetting {
        settingKey: "postConnectCmd"
        label: "Post-Connect Command"
        description: "A shell command to run after the VPN connection is fully established (e.g. notify-send 'VPN Active')"
        placeholder: "notify-send 'VPN Connected!'"
        defaultValue: ""
    }

    StringSetting {
        settingKey: "postDisconnectCmd"
        label: "Post-Disconnect Command"
        description: "A shell command to run after the VPN connection is terminated (e.g. notify-send 'VPN Off')"
        placeholder: "notify-send 'VPN Disconnected!'"
        defaultValue: ""
    }

    ToggleSetting {
        settingKey: "vpnEnabled"
        label: "Activate VPN"
        description: "Start or stop the openfortivpn connection tunnel"
        defaultValue: false
    }
}
