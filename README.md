
Edited flock you for Wemos D1 mini (ESP8266) boards, standalone / dashboard over USB for live GPS-tagged wardriving.**

## Quick start: Wemos D1 mini / ESP8266MOD

The Wemos scans by itself; for live logs and green detection alerts, plug it
into a computer running this project's Flask dashboard. 

On Linux, connect the Wemos with a data-capable USB cable and run
these commands from a terminal:

```bash
sudo apt update
sudo apt install -y git python3 python3-venv
git clone https://github.com/caterpy/flock-you-wemos-d1.git
cd flock-you-wemos-d1
chmod +x install_linux.sh
./install_linux.sh --device-port /dev/ttyUSB0
```

Use the port listed by `ls /dev/serial/by-id/` if your board appears there;
otherwise CH340-based ESP8266MOD boards commonly use `/dev/ttyUSB0`. The
installer sets up the dashboard and PlatformIO, builds and flashes the Wemos,
then starts the dashboard. Open `http://localhost:5000`, select the Wemos port
under **Sniffer**, and click **Connect**. See [Linux setup](#linux-install-flash-and-run-the-dashboard)
for permissions, options, and Windows instructions.

https://github.com/colonelpanichacks/flock-you
