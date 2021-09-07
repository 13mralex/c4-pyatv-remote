# Apple TV IP Remote Control (pyatv)

## Preparing the Linux Environment
·	Ensure Python3 is installed with pip

·	Install pyatv

    pip3 install pyatv

·	Verify installation

    atvremote --version

·	Run the Webserver

    python3 pyatv-webserver.py

·	Server is now running on port 8080
## Pairing Apple TV
·	Run the Scan Devices action from Composer

·	Verify output in the Lua console, which will dump all Apple Related devices and protocols

·	The Device Selector property will populate with available devices

·	Select the desired device, the Protocols and Device ID property will populate

·	Select MRP for remote commands, Companion to launch apps

·	After setting the protocol, the device will display a PIN on screen

·	Enter the PIN in Composer

·	Run the Test Connection action to verify everything works

·	The Lua console will display the result
## Notes
·	I threw in some MiniApps to experiment with Universal Drivers via Programming

