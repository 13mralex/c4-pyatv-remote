# Apple TV IP Remote Control (pyatv)

## Features
- Virtually no latency for remote commands
- Show Now Playing within Touch Panels, EA/Core Navigators or C4 app
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
- Create presets using supported deep links
	- Fully customizable name, URL, and icon
	- Created presets are expected to be added as favorites or executed via Programming
	- To create a preset:
	  	1. *TESTING:* For quicker testing, URLs can be launched in the Lua console in Composer with the following command: `PYATV.LaunchApp("URL here")`
		2. Gather necessary info (name, launch URL, icon URL)
		3. Launch the Apple TV from C4 (watch or listen)
			1. Navigate to the Presets tab
			2. Press the create entry
		4. *OR:* if the Apple TV is already active:
			1. Open the Now Playing page on a C4 app/navigator
			2. Press **Queue**
			3. Press **Create Preset**
		5. Enter information
			1. **Media type:** automatically choose Watch or Listen
			2. **Simulate button press:** This will fire the **Select** button after desired amount of time. Apple Music for example does not automatically play, but will always land on a screen with the Play button ready to be selected
		6. **Save**
		7. Press the newly created preset
		8. Press **Favorite to Room**
	- For more info: [pyatv apps page](https://pyatv.dev/development/apps/)
- Typical remote control functions over IP
  - Buttons can be customized in Composer
- User switching & app launching from remotes or C4 apps
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
- Run the **Scan Devices** action from Composer
- The Latest Status property will state when scan is complete
- The Device Selector property will populate with available devices
- Select the desired device, the Protocols property will populate
- Select Companion or AirPlay **(you will need to pair with both protocols)**
- After setting the protocol, the device will display a PIN on screen
- Enter the PIN in Composer (perform the pairing again with the other protocol)
- Run the **Refresh Connection** action to start connection to the server

## ToDos
- Nothing currently, open to suggestions :)
