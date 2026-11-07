
Edited flock you for Wemos D1 mini (ESP8266) boards, standalone / dashboard over USB for live GPS-tagged wardriving.**

Wemos D1 mini / ESP8266MOD

The Wemos scans by itself; plug over usb and run scripts below to see dashboard. 

Linux

```bash
sudo apt update
sudo apt install -y git python3 python3-venv
git clone https://github.com/caterpy/flock-you-wemos-d1.git
cd flock-you-wemos-d1
chmod +x install_linux.sh
./install_linux.sh --device-port /dev/ttyUSB0
```
Windows

```powershell
git clone https://github.com/caterpy/flock-you-wemos-d1.git
Set-Location flock-you-wemos-d1
powershell -ExecutionPolicy Bypass -File .\install_windows.ps1 -Port COM5
```


https://github.com/colonelpanichacks/flock-you
