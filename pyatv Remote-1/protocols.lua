function convertProtocol(p)

    p2 = ""

    if (p == "mrp") then
	   p2 = "MRP"
    elseif (p == "airplay") then
	   p2 = "AirPlay"
    elseif (p == "companion") then
	   p2 = "Companion"
    elseif (p == "raop") then
	   p2 = "RAOP"
    elseif (p == "dmap") then
	   p2 = "DMAP"
    else
	   print("Protocol mismatch: "..p)
    end
    return p2
    
end