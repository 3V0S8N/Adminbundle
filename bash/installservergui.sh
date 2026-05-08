if [ "$EUID" -ne 0 ]; then
  exec sudo "$0" "$@"
fi

set -e
clear
echo "===================================================="
echo "          DEBIAN GUI SETUP                          "
echo "===================================================="
echo ""
echo "Select your configuration:"
echo "1) Full Desktop Mode (Boot into GUI)"
echo "2) Server Mode       (Boot to Console + Manual GUI)"
echo "----------------------------------------------------"

read -p "Choice [1 or 2]: " choice

echo "--> Updating package lists..."
apt update -qq

echo "--> Installing XFCE4, Xorg and LightDM..."
apt install -y xfce4 xfce4-goodies xorg lightdm --no-install-recommends

if [ "$choice" = "1" ]; then
    echo "--> Configuring: AUTO-START GUI"
    systemctl set-default graphical.target
    systemctl enable lightdm
else
    echo "--> Configuring: CONSOLE ONLY"
    systemctl set-default multi-user.target
    systemctl disable lightdm
fi

echo "--> Creating gui-switch in /usr/local/bin/..."

cat << 'EOF' > /usr/local/bin/gui-on
#!/bin/bash
echo "Starting Graphical User Interface..."
sudo systemctl start lightdm
EOF

cat << 'EOF' > /usr/local/bin/gui-off
#!/bin/bash
echo "Stopping Graphical User Interface..."
sudo systemctl stop lightdm
EOF

# chmod +x
chmod +x /usr/local/bin/gui-on /usr/local/bin/gui-off

# endscreen
echo ""
echo "===================================================="
echo " Setup Complete!"
echo "===================================================="
echo " You can now use the following commands:"
echo "  gui-on  -> starts the desktop"
echo "  gui-off -> lights-out back to console"
echo "----------------------------------------------------"

if [ "$choice" = "1" ]; then
    echo " STATUS: System will boot into GUI automatically."
else
    echo " STATUS: System will boot to CLI. Use 'gui-on' if needed."
fi
echo "===================================================="
echo ""