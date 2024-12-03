
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
## Known Issues
- iOS app: inconsistent behavior when trying to start from "Watch"
	- When selecting the device from the "Watch" menu, it will trigger a "Listen" action instead
	- A hot fix has been applied to sidestep this issue, forcing "Watch" after an app is launched or user selected
## Preparing the Linux Environment
- Ensure Python3 is installed with pip (virtual environment is recommended)
- Install requirements.txt file
	- `pip install -r requirements.txt`
- Copy the pyatv-webserver.py to your Linux environment
- Run the Webserver Python script in a screen or background process of your choice:
	- `python3 pyatv-webserver.py`
- Server is now running on port 8080
## Pairing Apple TV
- Run the Scan Devices action from Composer
- The Latest Status property will state when scan is complete
- The Device Selector property will populate with available devices
- Select the desired device, the Protocols property will populate
- Select Companion or AirPlay (you will need to pair with both protocols)
- After setting the protocol, the device will display a PIN on screen
- Enter the PIN in Composer (perform the pairing again with the other protocol)
- Run the Test Connection action to verify everything works

## ToDos
- Nothing currently, open to suggestions :)
