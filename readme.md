# Apple TV IP Remote Control (pyatv)

## Features
- Virtually no latency for remote commands
- Show Now Playing within Touch Panels, EA Navigators or C4 app
- Show current app playing content
- Programming variables for content type and play state (good for lighting scenes!)
  - Play States:
    - playing
    - paused
    - loading
    - idle
  - Media Types:
    - music
    - video
    - unknown
- Typical remote control functions over IP
  - Buttons can be customized in Composer
- Universal MiniApp support
  - Launch apps on Apple TV programmatically or via MiniApps
  - Major streaming services are supported natively
    - Custom MiniApps can be added in the driver.lua file
## Known Issues
- SR260 Remotes may display an hourglass icon when choosing from Watch menu
  - Workaround: Press a different experience button (such as List) and back out
- iOS app will select previously selected media device (Watch or Listen) rather than the Apple TV itself
  - Workaround: Launch via MiniApps, otherwise no solution; all other devices work as expected
## Preparing the Linux Environment
·	Ensure Python3 is installed with pip

·	Install pyatv

·   `pip3 install pyatv`

·	Verify installation

·	`atvremote --version`

·	Copy the pyatv-webserver.py to your Linux environment.

·	Run the Webserver Python script in a screen or background process of your choice:

·	`python3 pyatv-webserver.py`

·	Server is now running on port 8080
## Pairing Apple TV
·	Run the Scan Devices action from Composer

·	Verify output in the Lua console, which will dump all Apple Related devices and protocols

·	The Device Selector property will populate with available devices

·	Select the desired device, the Protocols and Device ID property will populate

·	Select Companion or AirPlay (you will need to pair with both protocols)

·	After setting the protocol, the device will display a PIN on screen

·	Enter the PIN in Composer (perform the pairing again with the other Protocol)

·	Run the Test Connection action to verify everything works

·	The Lua console will display the result
## ToDos
· Create press and hold actions
