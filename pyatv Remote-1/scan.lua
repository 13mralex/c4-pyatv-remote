JSON = (require "JSON")
require "protocols"

device_list = {}
device_list["state"] = "initial"
device_id = {}

current_pairing_device = {}

function scan_devices()
    --print("Starting device scan...")
    ip = Properties["Server IP"].."/scan"
    C4:urlGet(ip)
    --print("Calling IP: "..ip)
    function ReceivedAsync(ticketId, strData)
	   --print("Start ReceivedAsync")
	   array = JSON:decode(strData)
	   device_list = array["devices"]
	   devices = ""
	   num = 0
	   print("---Devices Found---")
	   for k,v in pairs(array["devices"]) do
		  name = v["name"]
		  id = v["identifier"]
		  num = v
		  devices = devices..name..','
		  device_id[name] = k
		  print(name)
		  print("..ID: "..id)
		  for x,y in pairs(v["services"]) do
			 p2 = convertProtocol(y["protocol"])
			 print(".."..p2..": "..y["port"])
		  end
	   end
	   print("---Scan Complete---")
	   devices = devices:sub(1, -2)
	   device_list["state"] = "scanned"
	   C4:UpdatePropertyList("Device Selector", devices)
    end
end

function pair(name)
    print("Begin pairing for "..name)
    if (device_list["state"]=="initial") then
	   print("Scanning not complete, please re-scan for devices.")
    else
	   protocols = ""
	   x = device_id[name]
	   id = device_list[x]["identifier"]
	   current_pairing_device["name"] = name
	   current_pairing_device["id"] = id
	   print(name.." ID: "..id)
	   C4:UpdateProperty("Device ID", id)
	   for k,v in pairs(device_list[x]["services"]) do
		  protocol = convertProtocol(v["protocol"])
		  protocols = protocols..protocol..","
	   end
	   protocols = protocols:sub(1, -2)
	   --print("Protocols: "..protocols)
	   C4:UpdatePropertyList("Protocol to Pair", protocols)
    end
end

function pair2(protocol)
    name = current_pairing_device["name"]
    id = current_pairing_device["id"]
    current_pairing_device["protocol"] = protocol
    print("Begin protocol "..protocol.." pairing for "..name.." ("..id..")")
    ip = Properties["Server IP"]
    url = ip.."/pair/"..id.."/"..protocol
    print("Calling URL: "..url)
    C4:urlGet(url)
    function ReceivedAsync(ticketId, strData)
	   print("Result: "..strData)
    end
end

function pair3(pin)

    name = current_pairing_device["name"]
    id = current_pairing_device["id"]
    protocol = current_pairing_device["protocol"]
    print("Sending PIN "..pin.." to "..name)
    ip = Properties["Server IP"]
    url = ip.."/pair/"..id.."/"..protocol.."/"..pin
    print("Calling URL: "..url)
    C4:urlGet(url)
    function ReceivedAsync(ticketId, strData)
	   print("Result: "..strData)
    end
    C4:UpdateProperty("Pairing Code", "")
    connect_device()
end

function connect_device()
    name = Properties["Device Selector"]
    id = Properties["Device ID"]
    print("Connecting to "..name)
    ip = Properties["Server IP"].."/connect/"..id
    C4:urlGet(ip)
    function ReceivedAsync(ticketId, strData)
	   print("Result: "..strData)
    end
end