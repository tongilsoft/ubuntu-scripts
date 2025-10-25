#!/bin/bash

# Update and upgrade the system
sudo apt update && sudo apt upgrade -y

# Install XFCE (lightweigh GUI engine)
sudo apt install -y xfce4 xfce4-goodies

# Install TigerVNC
sudo apt install -y tigervnc-standalone-server tigervnc-common

# Configure VNC Password
echo "System will ask a password for vnc"
vncpasswd

# Start vnc server to configure environment
vncserver

# Stop vnc server to config XFCE
vncserver -kill :1

cat <<EOF > ~/.vnc/xstartup
#!/bin/bash
xrdb $HOME/.Xresources
startxfce4 &
EOF

echo "Check XFCE config"
vim ~/.vnc/xstartup

# Make the script executable
chmod +x ~/.vnc/xstartup

# Restart VNC Server
vncserver

echo "Finished"


