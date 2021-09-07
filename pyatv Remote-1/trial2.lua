--Copyright 2019 Control4 Corporation.  All rights reserved.



function GetRegistrationHelp(locale)
	local lines = g_RegistrationHelp[locale]
	if (lines == nil) then
		local primary, secondary
		for k,v in string.gmatch(locale, "(%w+)[-_](%w+)") do
			primary = string.lower(k)
			secondary = string.upper(v)
		end

		if (primary == nil) then
			primary = string.lower(locale)
		end

		if (secondary ~= nil) then
			lines = g_RegistrationHelp[primary .. "-" .. secondary]
			if (lines == nil) then
				lines = g_RegistrationHelp[primary]
			end
		else
			lines = g_RegistrationHelp[primary]
		end

		if (lines == nil) then
			for i,v in pairs(g_RegistrationHelp) do
				for k,w in string.gmatch(i, "(%w+)[-_](%w+)") do
					if (k == primary) then
						lines = v
						break
					end
				end

				if (lines ~= nil) then
					break
				end
			end
		end
	end

	if (lines == nil) then
		-- Fall back to English
		lines = g_RegistrationHelp["en-US"]
	end
	return lines
end

function OnWatchedVariableChanged(idDevice, idVariable, strValue)
	if ((idDevice == 100002) and (idVariable == 1009)) then
		-- Update the room map
		local oldMap = g_roomMapInfo
		g_roomMapInfo = strValue

		Navigator:OnUpdatedRoomMapInfo(oldMap, strValue)
	end
end

function NormalizeLocale(locale)
	if ((locale == nil) or (locale == "") or (locale == "C")) then
		locale = "en-US"
	end
	return locale
end

function GetLocale()
	return NormalizeLocale(C4:GetLocale(true))
end

function GetGlobalArgs()
	return("render=json&" .. GetGlobalArgsNoRender())
end

function GetGlobalArgsNoRender()
	local latitude = C4:GetVariable(1, 1001)
	local longitude = C4:GetVariable(1, 1002)
	local latlon = ""
	if ((latitude ~= "") and (longitude ~= "")) then
		latlon = "&latlon=" .. latitude .. "," .. longitude
	end

	local serial = g_mySerial
	if (g_deviceGroup > 0) then
		serial = serial .. "-" .. tostring(g_deviceGroup)
	end

	-- We don't include the locale in the global arguments because it might be different for a specific navigator
	return "partnerId=" .. g_partnerId .. "&serial=" .. serial .. "&formats=" .. g_formats .. latlon
end

function startDebugTimer()
  if (g_DebugTimer) then
	 g_DebugTimer = C4:KillTimer(g_DebugTimer)
  end
  g_DebugTimer = C4:AddTimer(15, "MINUTES")
end

function dbg(strDebugText)
  if (g_debugprint) then print(strDebugText) end
  if (g_debuglog) then C4:ErrorLog(strDebugText) end
end

function PrintPacket(msg, packet)
  if (g_debugprint) then
	 print("........Hex Packet: " .. msg)
	 hexdump(packet)
  end
end

function OnPropertyChanged(strProperty)
	if (strProperty == "Debug Mode") then
		if (Properties[strProperty] == "Off") then
			g_debugprint = false
			g_debuglog = false
			g_DebugTimer = 0
		 end
		 if (Properties[strProperty] == "Print") then
			g_debugprint = true
			g_debuglog = false
			startDebugTimer()
		 end
		 if (Properties[strProperty] == "Log") then
			g_debugprint = false
			g_debuglog = true
			startDebugTimer()
		 end
		 if (Properties[strProperty] == "Print and Log") then
			g_debugprint = true
			g_debuglog = true
			startDebugTimer()
		 end
	elseif ((strProperty == "Username") or (strProperty == "Password") ) then
		-- Mark the project as dirty
		C4:InvalidateState()
	elseif(strProperty == "Disabled") then
		if (Properties[strProperty] == "True") then
			SendToProxy(MEDIA_SERVICE_PROXY_BINDING_ID, "DISABLE_DRIVER", {}, "COMMAND")
	         else
			if (CheckControllerTypeAndVersion() ) then
				SendToProxy(MEDIA_SERVICE_PROXY_BINDING_ID, "ENABLE_DRIVER", {}, "COMMAND")
			end
		end
		C4:InvalidateState()
	elseif (strProperty == "Allow Browse Settings") then
		local prevValue = g_browseSettings
		if (Properties[strProperty] == "True") then
			g_browseSettings = true
		else
			g_browseSettings = false
		end

		if (prevValue ~= g_browseSettings) then
			-- Mark the project as dirty
			C4:InvalidateState()
		end
	elseif (strProperty == "Now Playing History Length") then
		local prevValue = gNowPlayingLength
		gNowPlayingLength = tonumber(Properties[strProperty])
		if (prevValue ~= gNowPlayingLength) then
			C4:InvalidateState()
		end
	elseif (strProperty == "TuneIn Account Group") then
		if (g_deviceGroup ~= Properties[strProperty]) then
			g_deviceGroup = tonumber(Properties[strProperty])
			C4:InvalidateState()
			UpdateAccountJoinState()
		end
	elseif (strProperty == "Search History Length") then
		if (g_SearchHistory.maxEntries ~= Properties[strProperty]) then
			g_SearchHistory:setMaxEntries(tonumber(Properties[strProperty]))
			C4:InvalidateState()
		end
	elseif (strProperty == "Fade-in") then
		local prevValue = g_fadeIn
		if (Properties[strProperty] == "True") then
			g_fadeIn = true
		else
			g_fadeIn = false
		end

		if (prevValue ~= g_fadeIn) then
			-- Mark the project as dirty
			C4:InvalidateState()
		end
	end
end

function ExecuteCommand(strCommand, tParams)
	dbg("ExecuteCommand function called with : " .. strCommand)
	if (tParams == nil) then
		if (strCommand =="GET_PROPERTIES") then
		--nyi CMDS.GET_PROPERTIES()
		else
			dbg ("From ExecuteCommand Function - Unutilized command: " .. strCommand)
		end
	end
	if (strCommand == "LUA_ACTION") then
		if tParams ~= nil then
			for cmd,cmdv in pairs(tParams) do
				print (cmd,cmdv)
				if cmd == "ACTION" then
          proxyDev = C4:GetProxyDevices()
          if (proxyDev) then
	          C4:MediaSetDeviceContext(proxyDev)
          end
				  if cmdv == "Join" then
  					Join()
				  elseif cmdv == "Drop" then
  					Drop()
				  elseif cmdv == "UpdateStatus" then
  					UpdateAccountJoinState(nil)
				  elseif cmdv == "SyncPresetsForProgramming" then
  					SyncPresetsWithMMDB()
				  elseif cmdv == "ClearSearchHistory" then
					g_SearchHistory:clear()
				  else
					dbg("From ExecuteCommand Function - Undefined Action")
					dbg("Key: " .. cmd .. "  Value: " .. cmdv)
				  end
				else
					dbg("From ExecuteCommand Function - Undefined Command")
					dbg("Key: " .. cmd .. "  Value: " .. cmdv)
				end
			end
		end
	end
end

function OnTimerExpired(idTimer)
	if (idTimer == g_DebugTimer) then
		dbg("Turning Debug Mode back to Print [default] (timer expired)")
		C4:UpdateProperty("Debug Mode", "Print")
	elseif(idTimer == gArtworkConfigTimer) then
		RequestArtworkConfig()
		return
	elseif (idTimer == gReportingTimer) then
		if (not CheckQueuesForReporting()) then
			C4:KillTimer(gReportingTimer)
			gReportingTimer = nil
		end
		return
	else
		Navigator:OnTimerExpired(idTimer)
		return
	end
	C4:KillTimer(idTimer)
end

JSON=require "json"

function JSON:assert()
	-- We don't want the JSON library to assert but rather return nil in case of parsing errors
end

-------------------------------------- Search History ----------------------------------------

g_SearchHistory = {
	add = function(self, str)
		if (self.maxEntries == 0) then
			return false
		end

		if (not self:find(str, searchFilter)) then
			self.index = self.index + 1
			table.insert(self.entries, 1, { ["id"] = self.index, ["text"] = str, ["candelete"] = "true" })
			while (#self.entries > self.maxEntries) do
				table.remove(self.entries)
			end
			return true
		end

		return false
	end,
	find = function(self, str)
		for i,v in pairs(self.entries) do
			if (v["text"] == str) then
				return true
			end
		end

		return false
	end,
	get = function(self, searchFilter)
		return self.entries
	end,
	delete = function(self, id)
		for j,w in pairs(self.entries) do
			if (w["id"] == id) then
				table.remove(self.entries, j)
				return true
			end
		end

		return false
	end,
	count = function(self)
		return #self.entries
	end,
	setMaxEntries = function(self, newMax)
		if (self.maxEntries > newMax) then
			while (#self.entries > self.maxEntries) do
				table.remove(self.entries)
			end
		end
		self.maxEntries = newMax
	end,
	clear = function(self)
		self.entries = {}
	end,
	index = 0,
	maxEntries = 100,
	entries = {}
}

----------------------------------------- URL cache ------------------------------------------

gUrlCache = {}

function getCachedUrlInfo(url)
	local info = gUrlCache[url]
	if (info ~= nil) then
		if (not isCachedUrlExpired(info, os.clock())) then
			return info
		else
			gUrlCache[url] = nil -- Cached data has expires, get rid of it
		end
	end
end

function isUrlCached(url)
	return (getCachedUrlInfo(url) ~= nil)
end

function isCachedUrlExpired(info, curTime)
	local expires = info["EXPIRES"]
	return (expires ~= nil) and (curTime > expires)
end

function doCleanupUrlCache()
	local curTime = os.clock()
	for i,v in pairs(gUrlCache) do
		if (isCachedUrlExpired(v, curTime)) then
			gUrlCache[i] = nil
		end
	end
end

function cleanupUrlCache()
	if ((gUrlCacheCleanupCounter == nil) or (gUrlCacheCleanupCounter <= 0)) then
		gUrlCacheCleanupCounter = 10

		doCleanupUrlCache()
	else
		gUrlCacheCleanupCounter = gUrlCacheCleanupCounter - 1
	end
end

function cacheUrl(url, responseCode, strData, tHeaders)
	local expires
	local maxAge = parseMaxAge(tHeaders["Cache-Control"])
	if (maxAge ~= nil) then
		local curTime = math.floor(os.clock())
		expires = curTime + maxAge
	end

	if (expires ~= nil) then
		local info = {}
		info["CODE"] = responseCode
		info["DATA"] = strData
		info["HEADERS"] = tHeaders
		info["EXPIRES"] = expires
		gUrlCache[url] = info

		cleanupUrlCache() -- Cleanup the cache
		return true
	else
		return false
	end
end

function parseMaxAge(strValue)
	-- This function parses the max-age header from the Cache-Control header
	if (strValue ~= nil) then
		for w in string.gmatch(strValue, "max%-age=(%d+)") do
			return w
		end
	end
end

g_tickets = {}

function urlGet(url, callback, context, noJSON, noCache)
	local info = {}
	info["CALLBACK"] = callback
	info["CONTEXT"] = context
	info["URL"] = url
	if (noJSON == true) then
		info["NO_JSON"] = true
	end

	local cached = false
	if ((g_enableCache) and (noCache ~= true)) then
		local cacheInfo = getCachedUrlInfo(url)
		if (cacheInfo ~= nil) then
			info["CACHE"] = cacheInfo
			cached = true
		end
	end

	if (not cached) then
		local ticketId = C4:urlGet(url)
		g_tickets[ticketId] = info
	else
		C4:CallAsync(function()
			local cacheInfo = info["CACHE"]
			dbg("Use cached response for URL " .. info["URL"])
			callUrlCallback(info, nil, cacheInfo["CODE"], cacheInfo["DATA"], cacheInfo["HEADERS"])
		end)
	end
end

function urlPost(url, data, callback, context)
	local info = {}
	info["CALLBACK"] = callback
	info["CONTEXT"] = context
	info["URL"] = url
	local ticketId = C4:urlPost(url, data)
	g_tickets[ticketId] = info
end

function pullTicketById(ticketId)
	local ticket = g_tickets[ticketId]
	if (ticket ~= nil) then
		g_tickets[ticketId] = nil
		return ticket
	end
end

function callUrlCallback(info, strError, responseCode, strData, tHeaders)
	local data

	if (strError == nil) then
		if (info["NO_JSON"] == true) then
			data = strData
		else
			data = JSON:decode(strData)
			if (data == nil) then
				dbg("ERROR parsing json data: " .. strData)
				strError = "Error parsing response"
			end
		end
	else
		dbg(strError)
	end

	local callback = info["CALLBACK"]
	callback(strError, responseCode, tHeaders, data, info["CONTEXT"])
end

function ReceivedAsync(ticketId, strData, responseCode, tHeaders, strError)
	local info = pullTicketById(ticketId)
	if (info ~= nil) then
		-- If caching is enabled, save the response to the cache
		if ((g_enableCache) and (not isUrlCached(info["URL"])) and (strError == nil) and (not cacheUrl(info["URL"], responseCode, strData, tHeaders))) then
			--dbg("Not caching URL " .. info["URL"])
		end

		--dbg("Received response: " .. strData)
		callUrlCallback(info, strError, responseCode, strData, tHeaders)
	end
end

----------------------------------------- Other Functions -----------------------------------------

function string.starts(String,Start)
   return string.sub(String,1,string.len(Start))==Start
end

function string.formatTemplate(str, tValues)
	-- This function formats a string using a table with key-value pairs and a string that contains {{key}} patterns
	for i,v in pairs(tValues) do
		local pat = "{{" .. i .. "}}"
		local n,j, i = 1
		while true do
			n, j = string.find(str, pat, i, true)
			if (n ~= nil) then
				str = str.sub(str, 1, n - 1) .. v .. str.sub(str, j + 1)
			else
				break
			end
		end
	end
	return str
end

function string.find_last_of(String,Sub)
	local pos = Start
	local len = string.len(Sub)
	local ret

	repeat
		pos = string.find(String, Sub, pos, true)
		if (pos ~= nil) then
			ret = pos
			pos = pos + len
		end
	until (pos == nil)

	return ret
end

function string.split(str, sep)
	local ret = {}

	if (#str > 0) then
		local pos = 1
		while true do
			local found = string.find(str, sep, pos, true)
			if (found ~= nil) then
				table.insert(ret, string.sub(str, pos, found - 1))
				pos = found + #sep
			else
				table.insert(ret, string.sub(str, pos))
				break
			end
		end
	end

	return ret
end

-- http://lua-users.org/wiki/StringRecipes
function url_encode(str)
  if (str) then
    str = string.gsub (str, "\n", "\r\n")
    str = string.gsub (str, "([^%w ])",
        function (c) return string.format ("%%%02X", string.byte(c)) end)
    str = string.gsub (str, " ", "+")
  end
  return str
end

-- http://lua-users.org/wiki/StringRecipes
function url_decode(str)
  str = string.gsub (str, "+", " ")
  str = string.gsub (str, "%%(%x%x)",
      function(h) return string.char(tonumber(h,16)) end)
  str = string.gsub (str, "\r\n", "\n")
  return str
end

function url_getarg(url, arg)
	local start = string.find(url, "?", 1, true)
	if (start ~= nil) then
		local argStart = string.find(url, "&" .. arg .. "=", start, true)
		if (argStart == nil) then
			argStart = string.find(url, "?" .. arg .. "=", start, true)
		end
		if (argStart ~= nil) then
			argStart = argStart + string.len(arg) + 2
			local argEnd = string.find(url, "&", argStart, true)
			if (argEnd ~= nil) then
				return url_decode(string.sub(url, argStart, argEnd - 1))
			else
				return url_decode(string.sub(url, argStart))
			end
		end
	end
end

function url_getprotocol(url)
	local sep = string.find(url, "://", 1, true)
	if (sep ~= nil) then
		return string.sub(url, 1, sep - 1)
	end
end

function url_setprotocol(url, proto)
	local sep = string.find(url, "://", 1, true)
	if (sep ~= nil) then
		return proto .. string.sub(url, sep)
	end
end

function url_getfilename(url)
	local sep = string.find(url, "?", 1, true)
	if (sep ~= nil) then
		url = string.sub(url, 1, sep - 1)
	end
	sep = string.find(url, "://", 1, true)
	if (sep ~= nil) then
		url = string.sub(url, sep + 3)
	end
	sep = string.find_last_of(url, "/")
	if (sep ~= nil) then
		if (sep == string.len(url)) then
			-- Slash at the end of the file name, return "" as filename
			return ""
		else
			return string.sub(url, sep + 1)
		end
	else
		-- Just a hostname like http://localhost?arg, return "" as filename
		return ""
	end
end

-- Release things this driver had allocated...
function OnDriverDestroyed()
  -- Kill open timers
  if (gDbgTimer ~= nil) then gDbgTimer = C4:KillTimer(gDbgTimer) end
  Navigator:Destroy()
end

function OnDriverInit ()
	MEDIA_SERVICE_PROXY_BINDING_ID = 5001

	g_partnerId = "7vGvIDO5"
	g_mySerial = C4:GetUniqueMAC()

	g_maxReportingDelay = 300 -- Maximum listen time reporting delay
	g_fadeIn = true -- This enables a fade-in effect
	g_browseSettings = true -- Set to true to enable browsing into "Settings"
	g_formats = "mp3,aac,wma" -- comma seperated list of formats we can support
	g_enableCache = true -- This enables as much caching as permitted by the TuneIn servers
	g_roomMapInfo = nil
	g_deviceGroup = 0 -- This is added as a suffix to the MAC address and allows multiple drivers to be joined to different accounts

	-- Images for root menu items
	g_rootIcons = {
		["language"] = "ico_tunein_language.png",
		["local"] = "ico_tunein_localradio.png",
		["location"] = "ico_tunein_location.png",
		["music"] = "ico_tunein_music.png",
		["news"] = "ico_tunein_news.png",
		["podcast"] = "ico_tunein_podcast.png",
		["presets"] = "ico_tunein_myfavorites.png",
		["settings"] = "ico_tunein_settings.png",
		["sports"] = "ico_tunein_sports.png",
		["talk"] = "ico_tunein_talk.png",
		["trending"] = "ico_tunein_trending.png"
	}

	g_RegistrationHelp = {
		["en-US"] = {
			"Follow these steps to associate your TuneIn account:",
			"1. From www.tunein.com logon with your account.",
			"2. Go to My Info > Devices or tunein.com/devices.",
			"3. Enter the code displayed below.",
			"TuneIn Registration Code: {{key}}",
		},
		["fr-FR"] = {
			"Suivez ces étapes pour associer votre compte TuneIn :",
			"1. Connectez-vous à votre compte depuis www.tunein.com.",
			"2. Allez à Mes Infos > Terminaux ou tunein.com/devices.",
			"3. Entrez le code affiché ci-dessous.",
			"Code d’Enregistrement TuneIn : {{key}}",
		},
		["ru"] = {
			"Проделайте следующие шаги для связывания устройства с вашей учетной записью TuneIn:",
			"1. Зайдите на вашу учетную запись на www.tunein.com",
			"2. Зайдите на “Моя информация - Устройства” или “tunein.com/devices”",
			"3. Введите код, указанный ниже",
			"Регистрационный код TuneIn: {{key}}"
		},
		["ko"] = {
			"귀하의 TuneIn 계정을 연결하려면 다음 단계를 따르십시오 :",
			"1. www.tunein.com 에서 귀하의 계정으로 로그인을 하여.",
			"2. 내 정보> 장치 또는 tunein.com / 장치로 이동합니다.",
			"3. 아래에 표시된 코드를 입력합니다.",
			"TuneIn 등록 번호 : {{key}}",
		},
		["sv-SE"] = {
			"Gör på följande sätt för att koppla ditt TuneIn-konto:",
			"1. Logga in på ditt konto på TuneIn.com.",
			"2. Gå till “Min profil” > “Enheter” eller till tunein.com/devices.",
			"3. Ange koden som visas här nedanför.",
			"Din registreringskod till TuneIn: {{key}}",
		},
		["de"] = {
			"Führen Sie die folgenden Schritte aus, um ein Gerät mit Ihrem TuneIn Konto zu verknüpfen:",
			"1. Loggen Sie sich auf www.tunein.com mit Ihrem Konto ein.",
			"2. Gehes Sie da auf “Meine Infos” und dann auf “Geräte” oder direkt auf “tunein.com/devices”.",
			"3. Geben Sie den unten stehenden Code ein.",
			"TuneIn Registrierungs-Code: {{key}}",
		},
		["pt-BR"] = {
			"Siga estes passos para associar sua conta TuneIn::",
			"1. Conecte-se com sua conta a partir do www.tunein.com",
			"2. Siga até MINHA CONTA > Dispositivos ou tunein.com/devices.",
			"3. Digite o código mostrado abaixo",
			"Código de Registro TuneIn: {{key}}",
		},
		["ja-JP"] = {
			"次のステップでTuneInアカウントを関連付けることができます：",
			"1. www.tunein.com にて、お客様のアカウントでログインします。",
			"2. ”マイページ”から > \"デバイス”、または “tunein.com/devices”へ行きます。",
			"3. 下記のコードを入力します。",
			"TuneIn 登録コード：{{key}}",
		},
		["es-MX"] = {
			"Sigue estos pasos para asociar tu cuenta de TuneIn:",
			"1. Desde www.tunein.com ingresa a cuenta.",
			"2. Ve a Mi Información > Dispositivos o en tunein.com/devices.",
			"3. Ingresa el código que aparece en la parte de abajo.",
			"Código de registro de TuneIn: {{key}}",
		},
		["zh-TW"] = {
			"请按照如下步骤关联您的TuneIn帐户：",
			"1. 在www.tunein.com上x登陆您的账户",
			"2. 点击＂我的信息＂＞＂设备＂，或访问tunein.com/devices",
			"3. 输入如下代码",
			"TuneIn注册码：{{key}}",
		},
		["zh-CN"] = {
			"請按照如下步驟關聯您的TuneIn帳戶：",
			"1. 在www.tunein.com上登陸您的賬戶",
			"2. 點擊＂我的信息＂＞＂設備＂，或訪問tunein.com/devices",
			"3. 輸入如下代碼",
			"TuneIn註冊碼：{{key}}",
		},
		["it-IT"] = {
			"Segui i seguenti passi per associare al tuo account TuneIn:",
			"1. Logga sul tuo account da www.tunein.com",
			"2. Vai a Mie Info > Dispositivi o tunein.com/dispositivi.",
			"3. Inserisci il codice visualizzato di seguito.",
			"Codice di Registrazione TuneIn: {{key}}",
		},
	}
end

function OnDriverLateInit ()
	C4:urlSetTimeout(30)

	for k,v in pairs(Properties) do
		OnPropertyChanged(k)
	end

	RequestArtworkConfig() -- Query the album configuration

	UpdateAccountJoinState()

	g_roomMapInfo = C4:GetVariable(100002, 1009)
	C4:RegisterVariableListener(100002, 1009) -- Watch digital audio's room map variable

	CheckDriverDisabled()
end

function SendToProxy(idBinding, strCommand, tParams, strCallType, bAllowEmptyValues)
	--dbg("SendToProxy (" .. idBinding .. ", " .. strCommand .. ")")
	if (strCallType ~= nil) then
		if (bAllowEmptyValues ~= nil) then
			C4:SendToProxy(idBinding, strCommand, tParams, strCallType, bAllowEmptyValues)
		else
			C4:SendToProxy(idBinding, strCommand, tParams, strCallType)
		end
	else
		if (bAllowEmptyValues ~= nil) then
			C4:SendToProxy(idBinding, strCommand, tParams, bAllowEmptyValues)
		else
			C4:SendToProxy(idBinding, strCommand, tParams)
		end
	end
end

function DataReceivedError(idBinding, navId, seq, msg)
	local tParams = {}
	tParams["NAVID"] = navId
	tParams["SEQ"] = seq
	tParams["DATA"] = ""
	tParams["ERROR"] = msg
	SendToProxy(idBinding, "DATA_RECEIVED", tParams)
end

function DataReceived(idBinding, navId, seq, tdata)
	local tParams = {}
	tParams["NAVID"] = navId
	tParams["SEQ"] = seq

	local data = ""
	if (tdata ~= nil) then
		for i,v in pairs(tdata) do
			data = data .. "<" .. i .. ">" .. v .. "</" .. i .. ">"
		end
	end
	tParams["DATA"] = data
	SendToProxy(idBinding, "DATA_RECEIVED", tParams)
end

function UpdateMediaInfoForRoom(idBinding, roomId, station, title, genre, imageUrl)
	local tParams = {}
	--dbg("UpdateMediaInfoForRoom(room: " .. roomId .. " station: " .. station .. " title: " .. title .. " genre: " .. genre .. " url: " .. imageUrl .. ")")
	tParams["ROOMID"] = roomId
	tParams["FORCE"] = "1"
	tParams["LINE1"] = title
	tParams["LINE2"] = station
	if (genre ~= nil) then
		tParams["LINE3"] = genre
	end
	tParams["IMAGEURL"] = imageUrl
	SendToProxy(idBinding, "UPDATE_MEDIA_INFO", tParams, "COMMAND", true)
end

function UpdateMediaInfoForNowPlaying(idBinding, queueId, imageUrl)
	local tParams = {}
	--dbg("UpdateMediaInfoForQueue(queueId: " .. queueId .. " url: " .. imageUrl .. ")")
	tParams["QUEUEID"] = queueId
	tParams["MERGE"] = "True"
	tParams["IMAGEURL"] = imageUrl
	SendToProxy(idBinding, "UPDATE_MEDIA_INFO", tParams, "COMMAND", true)
end

----------------------------------------- Navigator Events -----------------------------------------

function SendEvent(idBinding, navId, tRooms, name, tArgs)
	-- This function must have a registered navigator event set up
	local tParams = {}
	if (navId ~= nil) then
		tParams["NAVID"] = navId
		--dbg("SendEvent " .. name .. " to navigator " .. navId)
	elseif (tRooms ~= nil) then
		local rooms = ""
		for i,v in pairs(tRooms) do
			if (string.len(rooms) > 0) then
				rooms = rooms .. ","
			end
			rooms = rooms .. tostring(v)
		end

		if (string.len(rooms) > 0) then
			tParams["ROOMS"] = rooms
		end
		--dbg("SendEvent " .. name .. " to navigators in rooms " .. rooms)
	else
		--dbg("SendEvent " .. name .. " to all navigators (broadcast)")
	end
	tParams["NAME"] = name
	tParams["EVTARGS"] = BuildSimpleXml(nil, tArgs, false)
	SendToProxy(idBinding, "SEND_EVENT", tParams, "COMMAND")
end

function BroadcastEvent(idBinding, name, tArgs)
	SendEvent(idBinding, nil, nil, name, tArgs)
end

----------------------------------------- Actions --------------------------------------------

gCurrentStatus = ""

function UpdateStatusProperty(actionStatus)
	if (actionStatus ~= nil) then
		C4:UpdateProperty("Status", actionStatus .. " " .. gCurrentStatus)
	else
		C4:UpdateProperty("Status", gCurrentStatus)
	end
end

function Join(callback)
	Drop(function(_)
		UpdateStatusProperty("Joining to account...")

		local url = "https://opml.radiotime.com/Account.ashx?c=join&" .. GetGlobalArgs() .. "&username=" .. url_encode(Properties.Username) .. "&password=" .. url_encode(Properties.Password) .. "&locale=" .. GetLocale()
		urlGet(url, function (strError, responseCode, tHeaders, jobj)
			local status
			if (strError ~= nil) then
				status = "Error joining device."
				dbg("Joining account failed: " .. strError)
			else
				if (jobj["head"]["status"] == "200") then
					status = "Successfully joined device."
					dbg("Successfully joined device with account!")
				else
					if (jobj["head"]["fault_code"] == "validation.deviceExists") then
						-- status should be nil
						dbg("Device has already been joined with this account")
					else
						status = jobj["head"]["fault"] .. "."
						dbg("Joining account failed (" .. jobj["head"]["status"] .. "): " .. jobj["head"]["fault"])
					end
				end
			end

			-- Query what account the device is joined to
			UpdateAccountJoinState(status)

			if (callback) then
				callback(status)
			end
		end)
	end)
end

function Drop(callback)
	UpdateStatusProperty("Dropping device...")

	local url = "https://opml.radiotime.com/Account.ashx?c=drop&" .. GetGlobalArgs() .. "&locale=" .. GetLocale()
	urlGet(url, function (strError, responseCode, tHeaders, jobj)
		local status
		if (strError ~= nil) then
			status = "Error dropping device from account!"
			dbg("Dropping device from account failed: " .. strError)
		else
			if (jobj["head"]["status"] == "200") then
				status = "Successfully dropped device."
				dbg("Successfully dropped device from account!")
			else
				if (jobj["head"]["fault_code"] == "validation.deviceNotAssociated") then
					status = "Device is not joined."
					dbg("Device is not associated with account")
				else
					status = jobj["head"]["fault"] .. "."
					dbg("Dropping device from account failed (" .. jobj["head"]["status"] .. "): " .. jobj["head"]["fault"])
				end
			end
		end

		-- Query what account the device is joined to
		UpdateAccountJoinState(status)

		if (callback) then
			callback(status)
		end
	end)
end

function Authenticate()
	local url = "https://opml.radiotime.com/Account.ashx?c=auth&" .. GetGlobalArgs() .. "&username=" .. url_encode(Properties.Username) .. "&password=" .. url_encode(Properties.Password) .. "&locale=" .. GetLocale()
	urlGet(url, function (strError, responseCode, tHeaders, jobj)
		if (strError ~= nil) then
			dbg("Error authenticating: " .. strError)
		else
			if (jobj["head"]["status"] == "200") then
				dbg("Successfully authenticated!")
			else
				dbg("Authentication failed!")
			end
		end
	end)

	-- We don't update the "Status" property here because this action has no effect on the join status
end

function UpdateAccountJoinState(actionStatus)
	local url = "https://opml.radiotime.com/Account.ashx?c=query&" .. GetGlobalArgs() .. "&locale=" .. GetLocale()
	local context = {}
	context["actionStatus"] = actionStatus -- May be nil
	urlGet(url, _G.UpdateAccountJoinStateHandler, context, false, true) -- Don't use the cache

	gCurrentStatus = "Updating..."
	UpdateStatusProperty(actionStatus)
end

function UpdateAccountJoinStateHandler(strError, responseCode, tHeaders, jobj, context)
	local status
	local actionStatus = context["actionStatus"]

	if (strError ~= nil) then
		status = "Error querying account status: " .. strError
	else
		if (jobj["head"]["status"] == "200") then
			if ((#jobj["body"] > 0) and (jobj["body"][1]["text"] ~= nil)) then
				status = "Joined with account " .. jobj["body"][1]["text"] .. "."
			else
				status = "Unknown success response."
			end
		else
			if (jobj["head"]["fault_code"] == "validation.deviceNotAssociated") then
				status = "Not joined to any account."
			else
				if (jobj["head"]["fault"] ~= nil) then
					status = jobj["head"]["fault"] .. "."
				else
					status = "Unknown error"
				end
			end
		end
	end

	gCurrentStatus = status
	UpdateStatusProperty(actionStatus)
end


function IsSupportedController(controllerType)
  -- Older controllers unsupported, 250, 1000, windows, 800 and beyond supported by default
  if (controllerType == "XDT_MediaController" or controllerType == "XDT_HomeTheaterController" or
        controllerType == "XDT_MiniTouchScreen" or controllerType == "XDT_MiniTouchScreenV2" or
        controllerType == "XDT_SpeakerPoint" or controllerType == "XDT_TouchPanel" or
        controllerType == "XDT_Z10TouchPanel" or controllerType == "XDT_Z7TouchPanel" or
        controllerType == "XDT_Z7PTouchPanel" or controllerType == "XDT_TouchPanelV2" or
        controllerType == "XDT_HomeController500" or controllerType == "XDT_HomeController300" or
        controllerType == "XDT_HomeController200" or controllerType == "XDT_HomeController300V2" or
        controllerType == "XDT_HomeController200V2" or controllerType == "XDT_LGController200" or
        controllerType == "XDT_IOExtender" or controllerType == "XDT_5Inch" or
        controllerType == "XDT_7Inch" or controllerType == "XDT_EnergyController100" or
        controllerType == "XDT_Sony_Receiver" or controllerType == "XDT_BCM911211" or
        controllerType == "XDT_BCMDoorStation" or controllerType == "XDT_BCMDoorStation_SC" or
        controllerType == "XDT_BCM7Portable" or controllerType == "XDT_BCM7TouchScreen") then
    -- This large list exists out of paranoid desire to maintain exact functionality while
    -- changing a whitelist to a blacklist
    return(false);
  else
    return(true);
  end
end

function VersionAtLeast(major, minor, rev)
	local ver = string.split(C4:GetVersionInfo().version, '.')
	local mj = tonumber(ver[1])
	local mn = tonumber(ver[2])
	local r = tonumber(ver[3])
	if (mj > major) then
		return true
	elseif (mj == major and mn > minor) then
		return true
	elseif (mj == major and mn == minor and r >= rev) then
		return true
	else
		return false
	end
end

function CheckControllerTypeAndVersion()
	local myType = C4:GetSystemType()

	if (IsSupportedController(myType)) then
		if (VersionAtLeast(2, 4, 0)) then
			return true
		end
		print("The controller version is insufficient for the TuneIn driver.  A version of at least version 2.4 is required.  Please contact technical support.")
	else
		print("The controller type of " ..  myType .. " does not support TuneIn.  Please contact technical support.")
	end
	return false
end

--------------------------------- TuneIn News/Trending "Categories" ---------------------------------

gRootMenuInfoHandlers = {
	["news"] = {
		request = function(itemType, locale, callback, context)
			local url = "http://opml.radiotime.com/Browse.ashx?" .. GetGlobalArgs() .. "&id=c57922&locale=" .. locale
			local info = {}
			info["callback"] = callback
			info["context"] = context
			info["type"] = itemType
			info["locale"] = locale
			info["url"] = url
			return url, info
		end,
		processResponse = function(itemType, locale, url, strError, responseCode, tHeaders, jobj)
			if (strError ~= nil) then
				dbg("Error browsing News[" .. locale .. "]: " .. strError)
			else
				if (jobj["head"]["status"] == "200") then
					local item = {}
					item["title"] = jobj["head"]["title"]
					item["url"] = url
					return item
				end
			end
		end
	},
	["trending"] = {
		request = function(itemType, locale, callback, context)
			local url = "http://opml.radiotime.com/Browse.ashx?" .. GetGlobalArgs() .. "&c=trending&locale=" .. locale
			local info = {}
			info["callback"] = callback
			info["context"] = context
			info["type"] = itemType
			info["locale"] = locale
			info["url"] = url
			return url, info
		end,
		processResponse = function(itemType, locale, url, strError, responseCode, tHeaders, jobj)
			if (strError ~= nil) then
				dbg("Error browsing Trending[" .. locale .. "]: " .. strError)
			else
				if (jobj["head"]["status"] == "200") then
					local item = {}
					item["title"] = jobj["head"]["title"]
					item["url"] = url
					return item
				end
			end
		end
	}
}

gRootMenuInfo = {
	["news"] = {}, -- This is a hash table with the locale as index
	["trending"] = {} -- This is a hash table with the locale as index
}

function PopNextRootMenuInfo(fetchInfo)
	for i,v in pairs(fetchInfo) do
		fetchInfo[i] = nil
		return i, v
	end
end

function GetNextRootMenuInfo(fetchInfo, locale, callback, context)
	while true do
		local i, v = PopNextRootMenuInfo(fetchInfo)
		if (i ~= nil) then
			local info = {}
			info["fetchinfo"] = fetchInfo
			info["locale"] = locale
			info["callback"] = callback
			info["context"] = context
			local url, ctx = gRootMenuInfoHandlers[i].request(i, locale, _G["GetRootMenuInfoHandler"], info)
			if (url ~= nil) then
				urlGet(url, _G.GetRootMenuInfoResponseHandler, ctx)
				return true
			end
		else
			return false
		end
	end
end

function GetRootMenuInfo(locale, callback, context)
	-- Create a table with items we still need to get
	local fetchInfo = {}
	for i,v in pairs(gRootMenuInfo) do
		if (v[locale] == nil) then
			fetchInfo[i] = v
		end
	end

	if (not GetNextRootMenuInfo(fetchInfo, locale, callback, context)) then
		return gRootMenuInfo
	end
end

function GetRootMenuInfoHandler(info, itemType, item)
	local fetchInfo = info["fetchinfo"]
	local locale = info["locale"]
	local callback = info["callback"]
	local context = info["context"]

	if (not GetNextRootMenuInfo(fetchInfo, locale, callback, context)) then
		callback(context, gRootMenuInfo)
	end
end

function GetRootMenuInfoResponseHandler(strError, responseCode, tHeaders, jobj, info)
	local callback = info["callback"]
	local context = info["context"]
	local itemType = info["type"]
	local locale = info["locale"]
	local url = info["url"]

	local item = gRootMenuInfoHandlers[itemType].processResponse(itemType, locale, url, strError, responseCode, tHeaders, jobj)
	if (item ~= nil) then
		gRootMenuInfo[itemType][locale] = item
	end
	callback(context, itemType, item)
end

----------------------------------------- TuneIn Artwork -------------------------------------

gArtworkConfigTimer = nil
gArtworkConfigTimerInterval = 23 * 60 -- Query after 23 hours rather than 24 hours so we have some time to recover from errors
gArtworkConfig = nil

function RequestArtworkConfig()
	if (gArtworkConfigTimer) then
		gArtworkConfigTimer = C4:KillTimer(gArtworkConfigTimer)
	end

	local url = "http://opml.radiotime.com/Config.ashx?c=api&" .. GetGlobalArgs() .. "&locale=" .. GetLocale()
	urlGet(url, _G.RequestArtworkConfigHandler)
end

function RequestArtworkConfigHandler(strError, responseCode, tHeaders, jobj)
	local isValid = false
	local err = ""

	if (gArtworkConfigTimer) then
		gArtworkConfigTimer = C4:KillTimer(gArtworkConfigTimer)
	end

	if (strError ~= nil) then
		err = "Error requesting artwork configuration: " .. strError
	else
		if (jobj["head"]["status"] == "200") then
			if (#jobj["body"] > 0) then
				local config = jobj["body"][1]

				if ((config["albumart.lookupurl"] ~= nil) and (string.len(config["albumart.lookupurl"]) > 0) and
					(config["albumart.url"] ~= nil) and (string.len(config["albumart.url"]) > 0)) then
					for i,v in pairs(config) do
						if (string.starts(i, "albumart.extension.")) then
							isValid = true
							break
						end
					end
				end

				if (isValid) then
					-- Store the configuration we got
					gArtworkConfig = config

					-- Reset the timer to request the album config
					gArtworkConfigTimer = C4:AddTimer(gArtworkConfigTimerInterval, "MINUTES")
				else
					err = "Invalid artwork configuration"
				end
			else
				err = "Error parsing artwork configuration"
			end
		else
			err = jobj["head"]["fault"]
		end
	end

	if (not isValid) then
		dbg(err .. ", try again in 5 minutes")
		gArtworkConfigTimer = C4:AddTimer(5, "MINUTES") -- Try again in 5 minutes
	end
end

function LookupArtwork(artist, title, callback, context)
	if (gArtworkConfig == nil) then
		local obj = {}
		obj["error"] = "No artwork configuration"
		callback(context, obj)
		return
	end

	local url = gArtworkConfig["albumart.lookupurl"] .. "?" .. GetGlobalArgs() .. "&locale=" .. GetLocale() .. "&artist=" .. url_encode(artist) .. "&title=" .. url_encode(title)
	local info = {}
	info["callback"] = callback
	info["context"] = context
	urlGet(url, _G.LookupArtworkHandler, info)
end

function BuildArtworkUrls(key)
	local ret = {}
	local found = false
	local prefix = "albumart.extension."
	for i,v in pairs(gArtworkConfig) do
		if (string.starts(i, prefix)) then
			local size = string.sub(i, string.len(prefix) + 1)
			ret[size] = gArtworkConfig["albumart.url"] .. key .. v
			found = true
		end
	end

	if (found) then
		return ret
	end
end

function LookupArtworkHandler(strError, responseCode, tHeaders, jobj, info)
	local callback = info["callback"]
	local context = info["context"]

	local obj = {}

	if (strError ~= nil) then
		obj["error"] = "Error looking up artwork: " .. strError
	else
		if (gArtworkConfig ~= nil) then
			if (jobj["head"]["status"] == "200") then
				if (#jobj["body"] > 0) then
					local info = jobj["body"][1]
					local found = false

					-- Check if we got anything back and build the URLs
					if (info["album_art"] ~= nil) then
						obj["album_urls"] = BuildArtworkUrls(info["album_art"])
						if (obj["album_urls"] ~= nil) then
							found = true
						end
					end

					if (info["artist_art"] ~= nil) then
						obj["artist_urls"] = BuildArtworkUrls(info["artist_art"])
						if (obj["artist_urls"] ~= nil) then
							found = true
						end
					end

					obj["found"] = found
				else
					obj["error"] = "Could not parse artwork response"
				end
			else
				obj["error"] = jobj["head"]["fault"]
			end
		else
			obj["error"] = "No artwork configuration"
		end
	end

	-- Call the callback function with the information or error
	callback(context, obj)
end

----------------------------------------- Reporting ----------------------------------------

gReportingTimer = nil

function AddPlayTime(queueInfo, seconds)
	local secs = queueInfo["SECONDS"]
	secs = secs + seconds
	dbg("Adding " .. seconds .. " second(s) to play time of " .. queueInfo["SECONDS"] .. " second(s) for station " .. queueInfo["STATION_ID"])
	queueInfo["SECONDS"] = secs
end

function CheckQueuesForReporting()
	local ret = false
	local curTime = os.time()
	for i,v in pairs(gQueues) do
		if ((v["SECONDS"] > 0) and (v["STATE"] == "STOP")) then
			local delay = curTime - v["END_TIME"]
			if (delay >= g_maxReportingDelay) then
				ReportPlayingTime(v, v["STATE"])
			else
				ret = true
			end
		end
	end

	return ret
end

function ReportPlayingTime(queueInfo, state)
	local stationId = queueInfo["STATION_ID"]
	if ((stationId ~= nil) and (stationId ~= "") and not string.starts(stationId, "u") and (queueInfo["SECONDS"] > 0)) then
		local delay = os.time() - queueInfo["END_TIME"]
		if ((state == "END") or ((state == "STOP") and (delay >= g_maxReportingDelay))) then
			local url = "http://opml.radiotime.com/Report.ashx?c=timelist&" .. GetGlobalArgs() .. "&listenId=" .. queueInfo["START_TIME"] .. "&time1=" .. queueInfo["SECONDS"] .. "|0|" .. delay .. "&id=" .. stationId
			if (state == "END") then
				url = url .. "&trigger=stop"

				dbg("Report (final) that station " .. stationId.. " played for a total of " .. queueInfo["SECONDS"] .. " second(s) with a reporting delay of " .. delay .. " second(s)")
			else
				dbg("Report that station " .. stationId .. " played for a total of " .. queueInfo["SECONDS"] .. " second(s) with a reporting delay of " .. delay .. " second(s)")
			end
			urlPost(url, "", _G.ReportPlayingTimeHandler)

			queueInfo["SECONDS"] = 0 -- Reset counter so we don't report multiple times
		elseif (state == "STOP") then
			dbg("Delay reporting playing time for station " .. stationId .. " that played for a total of " .. queueInfo["SECONDS"] .. " second(s)")

			if (not gReportingTimer) then
				-- Setup the reporting timer if needed
				dbg("Creating reporting timer")
				gReportingTimer = C4:AddTimer(1, "SECONDS", true)
			end
		end
	end
end

function ReportPlayingTimeHandler(strError, responseCode, tHeaders, jobj)
	if (strError ~= nil) then
		dbg("Error reporting playing time: " .. strError)
	else
		if (jobj["head"]["status"] == "200") then
			dbg("Successfully reported playing time")
		else
			dbg("Error (" .. jobj["head"]["status"] .. ") reporting playing time: " .. jobj["head"]["fault"])
		end
	end
end

----------------------------------------- Now Playing ----------------------------------------

gQueues = {}          -- Audio queue information of any queues that this driver created or plays audio in
gNowPlaying = {}      -- Now playing information for any queues that this driver created or plays audio in
gNowPlayingCache = {}      -- Tunein now playing cache
gNowPlayingLength = 1

function CreateNowPlayingForUrl(id, text, image, isPreset, url)
	local nowPlaying = {}
	nowPlaying["GUIDE_ID"] = id
	nowPlaying["STATION"] = text
	nowPlaying["TITLE"] = text
	nowPlaying["LOGO_URL"] = image
	nowPlaying["is_preset"] = tostring(isPreset)
	nowPlaying["ITEM_TYPE"] = "url"
	nowPlaying["PLAY_ITEM_TYPE"] = "url"
	nowPlaying["URL"] = url
	return nowPlaying
end

function CacheNowPlaying(id, guideId, station, showTitle, showGenre, logoUrl, delay, isPreset, itemType, playItemType, url)
	local nowPlaying = {}

	if (delay ~= nil) then
		local curTime = math.floor(os.clock())
		local expires = curTime + delay
		nowPlaying["EXPIRES"] = expires
	end

	nowPlaying["GUIDE_ID"] = guideId
	nowPlaying["URL"] = url
	nowPlaying["STATION"] = station
	nowPlaying["TITLE"] = showTitle
	if (showGenre ~= nil) then
		nowPlaying["GENRE"] = showGenre
	end
	if (logoUrl ~= nil) then
		nowPlaying["LOGO_URL"] = logoUrl
	end
	nowPlaying["is_preset"] = tostring(isPreset)
	nowPlaying["ITEM_TYPE"] = itemType
	nowPlaying["PLAY_ITEM_TYPE"] = playItemType

	gNowPlayingCache[id] = nowPlaying

	--dbg("Caching now playing information for station id " .. id)

	return nowPlaying
end

function GetNowPlaying(id, isPreset, url)
	local nowPlaying = gNowPlayingCache[id]
	if (nowPlaying ~= nil) then
		local expires = nowPlaying["EXPIRES"]
		if ((expires ~= nil) and (os.clock() > expires)) then
			--dbg("Deleting expired now playing information for station id " .. id)
			gNowPlayingCache[id] = nil
		else
			nowPlaying["is_preset"] = tostring(isPreset) -- Update this field in case it has changed
			nowPlaying["URL"] = url -- Update this field in case it has changed

			--dbg("Returning cached now playing information for station id " .. id)
			return nowPlaying
		end
	end
end

function SendNowPlayingToRooms(idBinding, roomId, nowPlaying)
	local station = nowPlaying["STATION"]
	local showTitle = nowPlaying["TITLE"]
	local showGenre = nowPlaying["GENRE"]
	local imageUrl = nowPlaying["LOGO_URL"]

	if (showGenre ~= nil) then
		dbg("SendNowPlayingToRooms: Station: " .. station .. " Show: " .. showTitle .. " Genre: " .. showGenre)
	else
		dbg("SendNowPlayingToRooms: Station: " .. station .. " Show: " .. showTitle)
	end

	UpdateMediaInfoForRoom(idBinding, roomId, station, showTitle, showGenre, imageUrl)
end

function OnInternetRadioSelected(idBinding, tParams)
	-- This is the response to the SELECT_INTERNET_RADIO command
	local queueId = tonumber(tParams["QUEUE_ID"])
	local url = tParams["STATION_URL"]
	local stationId = tParams["QUEUE_INFO"]

	local curTime = os.time()

	local queueInfo = {}
	queueInfo["QUEUE_ID"] = queueId
	queueInfo["STATE"] = "PLAY"
	queueInfo["DASHBOARD"] = GetDashboardByState(queueInfo["STATE"])
	queueInfo["STATION_URL"] = url
	queueInfo["STATION_ID"] = stationId
	queueInfo["SECONDS"] = 0
	queueInfo["START_TIME"] = curTime
	queueInfo["END_TIME"] = curTime
	gQueues[queueId] = queueInfo

	dbg("OnInternetRadioSelected: Playing station " .. stationId .. " with URL " .. url .. " in queue " .. queueId)

	DashboardChanged(queueId, queueInfo["DASHBOARD"])
end

function DashboardChanged(queueId, ids)
	dbg("DashboardChanged(" .. queueId .. ", " .. ids .. ")")

	local args = {}
	args["QueueId"] = queueId
	args["Items"] = ids

	local rooms = GetRoomsByQueue (nil, queueId)
	SendEvent (MEDIA_SERVICE_PROXY_BINDING_ID, nil, rooms, "DashboardChanged", args)
end

function ChangeDashboard(queueInfo, newState)
	local dashboard = GetDashboardByState(newState)
	dbg("ChangeDashboard: " .. queueInfo["DASHBOARD"] .. " => " .. dashboard)
	if (dashboard ~= queueInfo["DASHBOARD"]) then
		queueInfo["DASHBOARD"] = dashboard
		DashboardChanged(queueInfo["QUEUE_ID"], queueInfo["DASHBOARD"])
	end
end

function GetDashboardByState(state)
	if (state == "PLAY") then
		return "Pause"
	elseif ((state == "PAUSE") or (state == "STOP")) then
		return "Play"
	else
		return ""
	end
end

function OnQueueDeleted(idBinding, tParams)
	-- This is a notification that we receive when the queue gets deleted
	local queueId = tonumber(tParams["QUEUE_ID"])
	local lastQueueState = tParams["LAST_STATE"]
	local lastQueueStateTime = tonumber(tParams["LAST_STATE_TIME"])

	dbg("OnQueueDeleted for queue " .. queueId .. ", last state was " .. lastQueueState .. " for " .. lastQueueStateTime .. " seconds")

	local queueInfo = gQueues[queueId]
	if (queueInfo ~= nil) then
		dbg("Deleting queue info for queue " .. queueId .. ", was playing station " .. queueInfo["STATION_ID"] .. ": " .. queueInfo["STATION_URL"])

		ChangeDashboard(queueInfo, nil) -- Clear the media dashboard

		if (lastQueueState == "PLAY") then
			-- Add play time to currently playing station.
			AddPlayTime(queueInfo, lastQueueStateTime)

			-- Save the current time when this station stopped playing for reporting purposes
			queueInfo["END_TIME"] = os.time()
		end

		-- Report the playing time
		ReportPlayingTime(queueInfo, "END")

		gQueues[queueId] = nil
		queueInfo = nil

		Navigator:ClearNowPlayingQueue(queueId) -- Clear the now playing queue
	end
end

function OnQueueStreamStatusChanged(idBinding, tParams)
	-- This is a notification that we receive when the queue status change
	local queueId = tonumber(tParams["QUEUE_ID"])

	--dbg("OnQueueStreamStatusChanged for queue " .. queueId .. ": " .. tParams["STATUS"])

	local values = {}
	for i,v in pairs(string.split(tParams["STATUS"], ",")) do
		local sep = string.find(v, "=", 1, true)
		if ((sep ~= nil) and (sep > 1)) then
			values[string.sub(v, 1, sep - 1)] = string.sub(v, sep + 1)
		end
	end

	local queueInfo = gQueues[queueId]
	if (queueInfo ~= nil) then
		local prevStreamImage = queueInfo["STREAM_ART"]
		local streamImage = values["image"]
		if (streamImage ~= nil and streamImage ~= "") then
			g_random = (g_random or 0) + 1
			queueInfo["STREAM_ART"] = streamImage .. "?random=" .. g_random
		else
			queueInfo["STREAM_ART"] = nil
		end
		if (prevStreamImage ~= queueInfo["STREAM_ART"]) then
			if (queueInfo["STREAM_ART"] ~= nil) then
				local url = queueInfo["STREAM_ART"]
				dbg("Update queue " .. queueId .. " with artwork provided by stream: " .. url)
				UpdateMediaInfoForNowPlaying(MEDIA_SERVICE_PROXY_BINDING_ID, queueId, url)
			else
				dbg("Update queue " .. queueId .. " revert artwork")
			end
		end

		local tRooms = GetRoomsByQueue(nil, queueId)
		if (tRooms ~= nil) then
			local tArgs = {}
			for i,v in pairs(values) do
				tArgs[i] = v
			end
			SendEvent(idBinding, nil, tRooms, "ProgressChanged", tArgs)
		end
	end
end

function OnQueueStatusChanged(idBinding, tParams)
	-- This is a notification that we receive when the queue state changed
	local queueId = tonumber(tParams["QUEUE_ID"])
	local state = tParams["STATE"]
	local prevState = tParams["PREV_STATE"]
	local prevStateTime = tonumber(tParams["PREV_STATE_TIME"])
	local stationId = tParams["QUEUE_INFO"]

	dbg("OnQueueStatusChanged for queue " .. queueId .. ": " .. prevState .. " (" .. prevStateTime .. " seconds) -> " .. state .. " Station: " .. stationId)

	local queueInfo = gQueues[queueId]
	if (queueInfo ~= nil) then
		queueInfo["STATE"] = state

		if (prevState == "PLAY") then
			-- Add play time to currently playing station.
			-- Do this even when stations are about to change, which is the case if we're going from PLAY -> PLAY (with different station ID).
			AddPlayTime(queueInfo, prevStateTime)

			-- Save the current time when this station stopped playing for reporting purposes
			queueInfo["END_TIME"] = os.time()
		end
	end

	if (queueInfo ~= nil) then
		ChangeDashboard(queueInfo, state)
	end

	if ((queueInfo ~= nil) and (queueInfo["STATION_ID"] ~= stationId)) then
		-- We're now playing a new station, report how long the previous one was played
		ReportPlayingTime(queueInfo, "END")

		dbg("Deleting queue info for queue " .. queueId .. ", was playing station " .. queueInfo["STATION_ID"] .. ", now playing station " .. stationId)

		gQueues[queueId] = nil
		queueInfo = nil
	end

	if ((state == "STOP") or (state == "END")) then
		if (queueInfo ~= nil) then
			-- We stopped playing the station, so report how long it was played
			ReportPlayingTime(queueInfo, state)
		else
			dbg("No queue info found")
		end
	end
end

function OnQueueMediaInfoUpdated(idBinding, tParams)
	local queueId = tonumber(tParams["QUEUE_ID"])
	local mediaInfo = tParams["MEDIA_INFO"]

	Navigator:OnUpdateMediaInfo(queueId, mediaInfo)
end

function PlayStation(stationId, roomId, stationUrl, volume)
	dbg("PlayStation: Playing station " .. stationId .. " in room " .. roomId .. " with station \"" .. stationUrl .. "\"")
	local tParams = {}
	tParams["ROOM_ID"] = roomId
	tParams["STATION_URL"] = stationUrl
	tParams["QUEUE_INFO"] = stationId
	if (volume ~= nil) then
		tParams["VOLUME"] = volume
	end
	local stationTag
	if (string.starts(stationId, "t")) then
		-- If we're playing a podcast topic then figure out the id of the
		-- podcast, so we can include that meta data in the driver tag
		stationTag = url_getarg(stationUrl, "sid")
		if (stationTag ~= nil and stationTag ~= "") then
			stationTag = stationTag .. "_" .. stationId
		end
	else
		stationTag = stationId
	end
	
	if (stationTag == nil or stationTag == "") then
		stationTag = stationId
	end
	local flags = "driver=tunein-" .. stationTag
	if (g_fadeIn) then
		flags = flags .. ",fade-in=0:1000"
	end
	tParams["FLAGS"] = flags
	SendToProxy(MEDIA_SERVICE_PROXY_BINDING_ID, "SELECT_INTERNET_RADIO", tParams, "COMMAND")
end

function GetNodesByPath(xml, path)
	-- This function returns all nodes matching this path
	local ret = {}
	if (xml.ChildNodes ~= nil) then
		local found = string.find(path, "/", 1, true)
		if (found ~= nil) then
			local name = string.sub(path, 1, found - 1)
			for i,v in pairs(xml.ChildNodes) do
				local node = v
				if (node.Name == name) then
					local nodes = GetNodesByPath(node, string.sub(path, found + 1))
					if (nodes ~= nil) then
						for j,w in pairs(nodes) do
							table.insert(ret, w)
						end
					end
				end
			end
		else
			for i,v in pairs(xml.ChildNodes) do
				if (v.Name == path) then
					table.insert(ret, v)
				end
			end
		end
	end
	return ret
end

function GetNodeValueByPath(xml, path)
	-- This function assumes that only one node with the path exists and returns its value
	for i,v in pairs(GetNodesByPath(xml, path)) do
		return v.Value
	end
end

function GetNodesValuesByPath(xml, path)
	-- This function returns all values of all nodes with this path
	local ret = {}
	for i,v in pairs(GetNodesByPath(xml, path)) do
		table.insert(ret, v.Value)
	end
	return ret
end

function GetQueueFromRoom(map, roomId)
	-- This function queries digital audio for the room/queue map to figure out what
	-- queue id is used by a room
	if (map == nil) then
		map = g_roomMapInfo
	end
	if (map ~= nil) and (map ~= "") then
		local info = C4:ParseXml(map)
		if (info ~= nil) then
			for i,v in pairs(GetNodesByPath(info, "audioQueueInfo/queue")) do
				local queueId = tonumber(GetNodeValueByPath(v, "id"))
				for j,w in pairs(GetNodesValuesByPath(v, "rooms/id")) do
					if (w == roomId) then
						return queueId
					end
				end
			end
		end
	end

	return 0
end

function GetRoomsByQueue(map, queueId)
	-- This function returns an array of room ids in a given queue
	if (map == nil) then
		map = g_roomMapInfo
	end

	if (map ~= nil) and (string.len(map) > 0) then
		local info = C4:ParseXml(map)
		if (info ~= nil) then
			for i,v in pairs(GetNodesByPath(info, "audioQueueInfo/queue")) do
				local id = tonumber(GetNodeValueByPath(v, "id"))
				if (id == queueId) then
					local rooms = {}
					for j,w in pairs(GetNodesValuesByPath(v, "rooms/id")) do
						table.insert(rooms, w)
					end
					return rooms
				end
			end
		end
	end
end

----------------------------------------- Navigators -----------------------------------------
gNavigators = {}

function NavigatorTicketsCallback(strError, responseCode, tHeaders, data, info)
	local nav = info["NAV"]
	local idBinding = info["BINDING"]
	local room = info["ROOM"]
	local seq = info["SEQ"]
	local callback = info["CALLBACK"]
	local context = info["CONTEXT"]

	local success, ret = pcall(callback, nav, idBinding, seq, strError, data, responseCode, tHeaders, context)
	if (success) then
		if (ret ~= nil) then
			dbg("Called navigator callback.  Returning data now.")
			DataReceived(idBinding, nav._nav, seq, ret)
		end
	else
		dbg("Called navigator callback.  An error occured: " .. ret)
		DataReceivedError(idBinding, nav._nav, seq, ret)
	end
end

function NavigatorGetRootMenuInfoCallback(info, rootMenuInfo)
	local nav = info["nav"]
	local callback = info["callback"]
	local context = info["context"]

	local func = nav[callback]
	func(nav, context, rootMenuInfo)
end

function NetworkError(strError)
	dbg("Network error: " .. strError)
	error("Network error", 0) -- This is the error message that gets sent to the Navigators
end

Navigator = {}
function Navigator:Create(navId, locale)
	local n = {}

	n._locale = NormalizeLocale(locale)
	n._nav = navId
	n._room = 0

	function n:urlGet(idBinding, seq, url, callback, context, noJSON)
		-- This function registers a callback

		local info = {}
		info["NAV"] = self
		info["BINDING"] = idBinding
		info["ROOM"] = self._room
		info["SEQ"] = seq
		info["CALLBACK"] = callback
		info["CONTEXT"] = context
		urlGet(url, _G.NavigatorTicketsCallback, info, noJSON)
	end

	function n:Destroy()
		dbg("Navigator.Destroy () for nav " .. self._nav)
	end

	function n:OnTimerExpired(idTimer)
		dbg("Navigator.OnTimerExpired (" .. idTimer .. ") for nav " .. self._nav)
	end

	function n:GetLocale()
		if (self._locale ~= nil) then
			return NormalizeLocale(self._locale)
		end

		return GetLocale()
	end

	function n:GetDashboard(idBinding, seq, args)
		-- This is called when navigators want to know the dashboard controls to be displayed.
		local queueId = GetQueueFromRoom(nil, self._room)

		dbg("GetDashboard for queue " .. queueId)

		local queueInfo = gQueues[queueId]
		if (queueInfo ~= nil) then
			DashboardChanged(queueId, queueInfo["DASHBOARD"])
		else
			DashboardChanged(queueId, "")
		end
	end

	function n:GetQueue(idBinding, seq, args)
		-- This function triggers a QueueChanged event for the navigator that requested it

		dbg("Navigator.GetQueue (" .. idBinding .. ", " .. seq .. ") for nav " .. self._nav)

		SendEvent(MEDIA_SERVICE_PROXY_BINDING_ID, self._nav, nil, "QueueChanged", Navigator:BuildNowPlayingQueue(GetQueueFromRoom(nil, self._room)))
		return {} -- Complete the call
	end

	function n:GetBrowseSettingsMenu(idBinding, seq, args)
		dbg("Navigator.GetBrowseSettingsMenu (" .. idBinding .. ", " .. seq .. ") for nav " .. self._nav)

		local url
		url = args["URL"]

		url = url .. "&locale=" .. self:GetLocale()

		-- The Settings.asmx service does not output json!!!
		local info = {}
		info["url"] = url
		self:urlGet(idBinding, seq, url, self.GetBrowseSettingsMenuHandler, info, true)

		-- We don't return anything at this point, which means that the response to the list data request
		-- will be deferred until the ticket handler is called
	end

	function n:BuildBrowseSettingsMenu(xml, pageUrl)
		-- This function builds the Browse menu list to be returned to the navigator

		local items = {}
		if (xml ~= nil) then
			local parseMenu = true
			if (url_getfilename(pageUrl) == "Register.aspx") then
				local key

				for i,v in pairs(GetNodesByPath(xml, "body/outline")) do
					if ((v.Attributes["key"] ~= nil) and (v.Attributes["text"] ~= nil) and (string.len(v.Attributes["key"]) > 0) and
					    (string.find(v.Attributes["text"], v.Attributes["key"], 1, true) ~= nil)) then
						key = v.Attributes["key"]
					end
				end

				if (key ~= nil) then
					local lines = GetRegistrationHelp(self:GetLocale())
					if (lines ~= nil) then
						local formatData = { ["key"] = key }
						for i,v in pairs(lines) do
							local item = {}
							item["type"] = "text"
							item["text"] = string.formatTemplate(v, formatData)
							table.insert(items, item)
						end

						parseMenu = false
					end
				end
			end

			if (parseMenu) then
				for i,v in pairs(GetNodesByPath(xml, "body/outline")) do
					local itemType = v.Attributes["type"]
					if (itemType == "link") then
						local url = v.Attributes["url"]
						if ((url_getfilename(url) == "Register.aspx") and (url_getprotocol(url) == "http")) then
							-- TuneIn sent us an invalid link, this needs to use https!  Fixup the URL
							url = url_setprotocol(url, "https")
						end

						local item = {}
						item["type"] = "link"
						item["folder"] = "true"
						item["text"] = v.Attributes["text"]
						item["localize"] = "true"
						item["URL"] = url
						table.insert(items, item)
					elseif (itemType == "text") then
						local item = {}
						item["type"] = "text"
						item["text"] = v.Attributes["text"]
						table.insert(items, item)
					end
				end
			end
		end

		local ret = ""
		for i,v in pairs(items) do
			ret = ret .. BuildSimpleXml("item", v, true)
		end

		return ret
	end

	function n:GetBrowseSettingsMenuHandler(idBinding, seq, strError, strData, responseCode, tHeaders, context)
		-- This function is called when the ticket that was created in "GetBrowseSettingsMenu" completes.  We
		-- need to return the list to be displayed to the navigator!

		dbg("Navigator.GetBrowseSettingsMenuHandler for nav " .. self._nav)

		local url = context["url"]

		local list = ""
		if (strError ~= nil) then
			dbg("Error browsing settings menu: " .. strError)
			NetworkError(strError)
		else
			list = self:BuildBrowseSettingsMenu(C4:ParseXml(strData), url)
		end

		-- Complete the original "GetBrowseSettingsMenu" call by returning the list
		local ret = {}
		ret["List"] = list
		return ret
	end

	function n:BrowseSettingsCommand(idBinding, seq, args)
		local url = args["URL"]

		if (url ~= nil) then
			dbg("BrowseSettingsCommand: " .. url)
			return { NextScreen = args["screen"] } -- Complete the call
		else
			dbg("BrowseSettingsCommand: no url")
		end

		return {} -- Complete the call
	end

	function n:GetBrowseMenu(idBinding, seq, args)
		dbg("Navigator.GetBrowseMenu (" .. idBinding .. ", " .. seq .. ") for nav " .. self._nav)

		local url
		local isRootMenu = false
		local search = args["search"]
		if (search ~= nil) then
			local searchFilter = args["search_filter"]
			local filter = ""
			local category = ""
			if ((searchFilter == "station") or (searchFilter == "show")) then
				filter = "&filter=" .. searchFilter
			elseif ((searchFilter == "song") or (searchFilter == "artist")) then
				category = "&c=" .. searchFilter
			end

			g_SearchHistory:add(search)

			url = "http://opml.radiotime.com/Search.ashx?" .. GetGlobalArgs() .. "&query=" .. url_encode(search) .. filter .. category
			dbg("Searching (" .. searchFilter .. ") for " .. search)
		else
			url = args["URL"]
			if (url ~= nil) then
				-- Make sure we're requesting json output
				if (url_getarg(url, "render") == nil) then
					url = url .. "&render=json"
				end
			else
				local category = ""
				if (args["screen"] == "MyFavorites") then
					category = "&c=presets"
					SyncPresetsWithMMDB()
				end
				url = "http://opml.radiotime.com/Browse.ashx?" .. GetGlobalArgs() .. category

				if (category == "") then
					isRootMenu = true
				end
			end
			dbg("Browsing " .. url)
		end

		url = url .. "&locale=" .. self:GetLocale()

		local info = {}
		info["isRootMenu"] = isRootMenu
		self:urlGet(idBinding, seq, url, self.GetBrowseMenuTicketHandler, info)

		-- We don't return anything at this point, which means that the response to the list data request
		-- will be deferred until the ticket handler is called
	end

	function n:FavoriteToRoom (idBinding, seq, args)
		local favResponse = XMLTag (nil, {
			Title = args.text,
			Context = args,
			['ImageUrl width="145" height="145"'] = args.image,
		}, true)

		return ({FavoriteResponse = favResponse})
	end

	function n:RecallFavorite (idBinding, seq, args)
		self:BrowseCommand (idBinding, seq, args)
	end

	function n:ParseBrowseMenuItem(jitem)
		local type = jitem["type"]
		jitem.default_action = 'Browse'

		if (type == 'audio' and jitem.item == 'station') then
			jitem.actions_list = 'Browse FavoriteToRoom'
		end
		if ((type == "link") or (type == "audio")) then
			local url = jitem["URL"]
			if (url ~= nil) then
				local key = jitem["key"]

				if ((type == "link") and (jitem["image"] == nil) and (key ~= nil)) then
					-- Check if we want to use a hardcoded image
					if (g_rootIcons[key] ~= nil) then
						jitem["icon"] = g_rootIcons[key]
					end
				end

				if ((key == "settings") and (not g_browseSettings)) then
					-- Ignore "Settings" item
				elseif (key == "presets") then
					-- Ignore "My favorites" item
				else
					if ((type == "link") and (jitem["item"] ~= "url")) then
						-- Can't browse into custom URLs
						jitem["folder"] = "true"
					end
					return jitem
				end
			end
		end
	end

	function n:ParseBrowseMenu(jobj, ret)
		local body = jobj["body"]
		if (body ~= nil) then
			for i,v in pairs(body) do
				local item = self:ParseBrowseMenuItem(v)
				if (item ~= nil) then
					table.insert(ret, item)
				else
					local children = v["children"]
					if (children ~= nil) then
						-- Add any children in this header
						local childCnt = 0
						for j,w in pairs(children) do
							item = self:ParseBrowseMenuItem(w)
							if (item ~= nil) then
								-- If this is the first item in this group, add a header row
								if (childCnt == 0) then
									-- Add the header row
									local header = {
										["text"] = v["text"],
										["is_header"] = "true"
									}
									table.insert(ret, header)
								end
								childCnt = childCnt + 1
								-- Add the item to the group
								table.insert(ret, item)
							end
						end
					end
				end
			end
		end
	end

	function n:BuildRootMenuItem(itemType, rootMenuInfo)
		if (rootMenuInfo ~= nil) then
			local itemInfo = rootMenuInfo[itemType]
			if (itemInfo ~= nil) then
				local info = itemInfo[self:GetLocale()]
				if (info ~= nil) then
					local item = {}
					item["type"] = "link"
					item["folder"] = "true"
					item["text"] = info["title"]
					item["URL"] = info["url"]
					item["key"] = itemType
					item["default_action"] = "Browse"
					if (g_rootIcons[itemType] ~= nil) then
						item["icon"] = g_rootIcons[itemType]
					end
					return item
				end
			end
		end
	end

	function n:InsertRootMenuItem(items, insertAfter, item)
		local pos = 1
		for i,v in pairs(items) do
			if (v["key"] == insertAfter) then
				pos = i + 1
				break
			end
		end

		table.insert(items, pos, item)
	end

	function n:BuildBrowseMenu(jobj, rootMenuInfo)
		-- This function builds the Browse menu list to be returned to the navigator

		local items = {}
		self:ParseBrowseMenu(jobj, items)

		local item = self:BuildRootMenuItem("news", rootMenuInfo)
		if (item ~= nil) then
			-- Insert the News category after the local stations category
			self:InsertRootMenuItem(items, "local", item)
		end

		item = self:BuildRootMenuItem("trending", rootMenuInfo)
		if (item ~= nil) then
			-- Insert the Trending category after the news category
			self:InsertRootMenuItem(items, "news", item)
		end

		local ret = ""
		for i,v in pairs(items) do
			ret = ret .. BuildSimpleXml("item", v, true)
		end

		return ret
	end

	function n:GetRootMenuInfo(callback, context)
		local info = {}
		info["nav"] = self
		info["callback"] = callback
		info["context"] = context
		return GetRootMenuInfo(self:GetLocale(), _G["NavigatorGetRootMenuInfoCallback"], info)
	end

	function n:GetInfoForRootMenuHandler(context, rootMenuInfo)
		local idBinding = context["idBinding"]
		local seq = context["seq"]
		local jobj = context["jobj"]

		local list = self:BuildBrowseMenu(jobj, rootMenuInfo)

		-- Complete the original "GetBrowseMenu" call by returning the list.  Here we can't
		-- simply return from the function anymore, we have to call DataReceived() manually!
		local ret = {}
		ret["List"] = list

		DataReceived(idBinding, self._nav, seq, ret)
	end

	function n:GetBrowseMenuTicketHandler(idBinding, seq, strError, jobj, responseCode, tHeaders, info)
		-- This function is called when the ticket that was created in "GetBrowseMenu" completes.  We
		-- need to return the list to be displayed to the navigator!

		dbg("Navigator.GetBrowseMenuTicketHandler for nav " .. self._nav)

		local list = ""

		if (strError ~= nil) then
			dbg("Error browsing: " .. strError)
			NetworkError(strError)
		else
			local rootMenuInfo = nil
			if (info["isRootMenu"] == true) then
				-- Query the news category information
				local context = {}
				context["idBinding"] = idBinding
				context["seq"] = seq
				context["jobj"] = jobj
				rootMenuInfo = self:GetRootMenuInfo("GetInfoForRootMenuHandler", context)
				if (rootMenuInfo == nil) then
					-- Do not complete the original call, we might still need to fetch more data
					-- for the root menu!  We need to complete this call in GetInfoForRootMenuHandler()
					return nil
				end
			end

			list = self:BuildBrowseMenu(jobj, rootMenuInfo)
		end

		-- Complete the original "GetBrowseMenu" call by returning the list
		local ret = {}
		ret["List"] = list
		return ret
	end

	function n:PlayItem(idBinding, seq, url, item, isPreset, guideId, text, imageUrl, volume)
		dbg("PlayItem(): Calling PlayStation for " .. item)
		PlayStation(guideId, self._room, url, volume)

		if (item == "station") then
			dbg("Querying now playing information for station " .. guideId)
			if (self:QueryNowPlayingById(idBinding, seq, guideId, guideId, isPreset, item, item, url)) then
				return true
			end
		elseif (item == "url") then
			-- This is a simple URL, we have no now playing information or other
			-- information that can be queried.

			local nowPlaying = CreateNowPlayingForUrl(guideId, text, imageUrl, isPreset, url)
			if (nowPlaying ~= nil) then
				SendNowPlayingToRooms(idBinding, self._room, nowPlaying)
				Navigator:UpdateNowPlayingQueue(GetQueueFromRoom(nil, self._room), nowPlaying, guideId, isPreset)
			end

			return true
		elseif (item == "topic") then
			dbg("Getting information for podcast topic " .. guideId)
			self:DescribeByGuideId(idBinding, seq, guideId, isPreset, url, nil)
		else
			return true
		end
	end

	function n:NowPlayingCommand(idBinding, seq, args)
		dbg("Navigator.NowPlayingCommand for nav " .. self._nav)

		local url = args["URL"]
		local item = args["itemType"]

		local isPreset = false
		if (args["is_preset"] == "true") then
			-- The is_preset field is not available for podcast topics
			isPreset = true
		end

		local guideId = args["Id"]
		if (guideId == nil) then
			guideId = url
		end

		dbg("NowPlayingCommand: guideId: " .. guideId)

		if (self:PlayItem(idBinding, seq, url, item, isPreset, guideId, args["text"], args["image"], nil)) then
			return {} -- Complete the call
		end

		-- Do not complete the call at this point
	end

	function n:BrowseCommand(idBinding, seq, args)
		local url = args["URL"]

		dbg("Navigator.BrowseCommand for nav " .. self._nav .. " with url=" .. url .. " on screen " .. (args["screen"] or ''))

		local item = args["item"]
		if ((args["type"] == "link") and ((item == nil) or (item == "show"))) then
			if (args["key"] == "presets") then
				-- We're browsing into the "My favorites" portion on the Browse screen.
				if (args["screen"] ~= "MyFavorites") then
					-- We need to switch to the MyFavorites screen!
					dbg("Need to switch to MyFavorites screen")
					return { NextScreen = "MyFavorites" } -- Complete the call
				end
			elseif ((args["key"] == "settings") and g_browseSettings) then
				-- We're browsing into the "Settings" portion on the Browse screen.
				return { NextScreen = "Settings" } -- Complete the call
			end

			return { NextScreen = args["screen"] } -- Complete the call
		elseif ((item == "station") or (item == "url") or (item == "topic") or ((item == nil) and (args["type"] == "audio"))) then
			local isPreset = false
			if (args["is_preset"] == "true") then
				-- The is_preset field is not available for podcast topics
				isPreset = true
			end

			if ((item == nil) and (args["type"] == "audio")) then
				-- If we don't get a item type, assume it's a station
				item = "station"
			end

			local guideId = args["guide_id"]
			if (guideId == nil) then
				-- Not all entries may have a guide_id, if not use the URL instead
				-- Search for the special "aa2" will return a list of URLs without guide_id
				guideId = url
			end

			if (self:PlayItem(idBinding, seq, url, item, isPreset, guideId, args["text"], args["image"], nil)) then
				return { NextScreen = "#nowplaying" } -- Complete the call
			end

			-- Do not complete the call at this point
		else
			return {} -- Complete the call
		end
	end

	function n:DescribeByGuideId(idBinding, seq, guideId, isPreset, tuneUrl, infoContext)
		local url = "http://opml.radiotime.com/Describe.ashx?" .. GetGlobalArgs() .. "&id=" .. guideId .. "&locale=" .. self:GetLocale()
		local context = {}
		context["id"] = guideId
		context["infoContext"] = infoContext
		context["is_preset"] = isPreset
		context["url"] = tuneUrl
		self:urlGet(idBinding, seq, url, self.DescribeByGuideIdHandler, context)
	end

	function n:DescribeByGuideIdHandler(idBinding, seq, strError, jobj, responseCode, tHeaders, context)
		local isPreset = context["is_preset"]
		local guideId = context["id"]
		local url = context["url"]

		local ret = { NextScreen = "#nowplaying" }

		if (strError ~= nil) then
			dbg("Error describing id " .. guideId .. ": " .. strError)
			-- Don't call NetworkError() at this point, we're already streaming but just couldn't get data from TuneIn
			return ret -- Complete the call
		else
			if (jobj["head"]["status"] == "200") then
				local itemType = jobj["body"][1]["element"]
				if (itemType == "topic") then
					local topicId = guideId

					--dbg("DescribeByGuideIdHandler: Describing topic " .. topicId)

					-- This is a podcast topic.  We need to get the show_id because a podcast topic
					-- can't be added to the presets.  We need this information on the now playing
					-- page so that we can bookmark the show rather than the topic.
					local showId = jobj["body"][1]["show_id"]
					if (showId == nil) then
						-- No show id?  Fall back to the guide_id we had in the first place
						dbg("DescribeByGuideIdHandler(): No show_id for " .. topicId)
						return ret -- Complete the call
					end


					-- Now we need to find out more about the associated show, e.g. if it has been
					-- bookmarked already.  Pass the topic id as infoContext
					self:DescribeByGuideId(idBinding, seq, showId, isPreset, url, topicId)

					-- Don't complete the call here, we're querying stuff still
				elseif (itemType == "show") then
					-- This is a show.  This code path should not be exercised normally
					local topicId = context["infoContext"]
					local showId = guideId

					--dbg("DescribeByGuideIdHandler: Describing show " .. guideId)

					if (jobj["body"][1]["is_preset"] ~= nil) then
						-- We now know whether this show has been bookmarked already
						isPreset = false
						if (tostring(jobj["body"][1]["is_preset"]) == "true") then
							isPreset = true
						end
					end

					if (topicId ~= nil) then
						-- Now that we know the show_id and is_preset values for the topic and show, query the
						-- now playing information for the topic (not the show!)
						if (self:QueryNowPlayingById(idBinding, seq, topicId, showId, isPreset, itemType, "topic", url)) then
							return ret -- Complete the call at this point, the information was already cached
						end
					else
						return ret -- Complete the call
					end
				end
			else
				-- Could not describe the object
				dbg("Error describing id " .. guideId .. ": " .. jobj["head"]["fault"])
				return ret -- Complete the call
			end
		end
	end

	function n:QueryNowPlayingById(idBinding, seq, id, bookmarkId, isPreset, itemType, playItemType, tuneUrl)
		--dbg("Navigator.QueryNowPlayingById for nav " .. self._nav .. " id=" .. id)

		-- The id argument contains the id of the item actually playing.
		-- The bookmarkId argument contains the id of the item that can be used to add it to the presets.
		-- In case of podcasts, this will be the guide_id of the show because it's not possible to bookmark
		-- individual topics of a podcast.
		local nowPlaying = GetNowPlaying(id, isPreset, tuneUrl)
		if (nowPlaying ~= nil) then
			dbg("Sending now playing info to room")
			SendNowPlayingToRooms(idBinding, self._room, nowPlaying)
			Navigator:UpdateNowPlayingQueue(GetQueueFromRoom(nil, self._room), nowPlaying, id, isPreset)
			return true
		end

		local url = "http://opml.radiotime.com/Describe.ashx?" .. GetGlobalArgs() .. "&c=nowplaying&id=" .. id .. "&locale=" .. self:GetLocale()
		local context = {}
		context["id"] = id
		context["bookmarkId"] = bookmarkId
		context["is_preset"] = isPreset
		context["itemType"] = itemType
		context["playItemType"] = playItemType
		context["url"] = tuneUrl
		self:urlGet(idBinding, seq, url, self.QueryNowPlayingByIdHandler, context)
		return false
	end

	function n:ParseNowPlayingRecursive(jobj, ret)
		-- This function parses the JSON now playing information into a table
		for i,v in pairs(jobj) do
			if (type(v) == "table") then
				self:ParseNowPlayingRecursive(v, ret)
			else
				if ((i == "type") and (v == "text")) then
					-- we have an addable item
					local text = jobj["text"]
					if (text ~= nil) then
						table.insert(ret["LINES"], text)
					end
				elseif (i == "guide_id") then
					if (ret["ID"] == nil) then
						ret["ID"] = jobj["guide_id"]
					end
				elseif (i == "image") then
					if (ret["LOGO_URL"] == nil) then
						ret["LOGO_URL"] = jobj["image"]
					end
				end
			end
		end
	end

	function n:ParseNowPlaying(jobj)
		local ret = {}
		ret["LINES"] = {}
		self:ParseNowPlayingRecursive(jobj, ret)
		return ret
	end

	function n:QueryNowPlayingByIdHandler(idBinding, seq, strError, jobj, responseCode, tHeaders, context)
		--dbg("Navigator.QueryNowPlayingByIdHandler for nav " .. self._nav)
		local id = context["id"]

		if (strError ~= nil) then
			dbg("Error querying now playing information for " .. id .. ": " .. strError)
			-- Don't call NetworkError() at this point, we're already streaming but just couldn't get data from TuneIn
		else
			local delay = parseMaxAge(tHeaders["Cache-Control"])

			--if (delay ~= nil) then
			--	dbg("Now Playing information should be cached for " .. delay .. " seconds")
			--else
			--	dbg("Now Playing information does not need to be cached")
			--end

			local info = self:ParseNowPlaying(jobj)
			local lines = info["LINES"]
			if (#lines >= 2) then
				local station = lines[1]
				local showTitle = lines[2]
				local showGenre = ""

				if (#lines >= 3) then
					showGenre = lines[3]
				end

				local bookmarkId = context["bookmarkId"]
				local isPreset = context["is_preset"]
				local itemType = context["itemType"]
				local playItemType = context["playItemType"]
				local url = context["url"]

				local nowPlaying = CacheNowPlaying(id, bookmarkId, station, showTitle, showGenre, info["LOGO_URL"], delay, isPreset, itemType, playItemType, url)
				if (nowPlaying ~= nil) then
					SendNowPlayingToRooms(idBinding, self._room, nowPlaying)
					Navigator:UpdateNowPlayingQueue(GetQueueFromRoom(nil, self._room), nowPlaying, id, isPreset)
				end
			end
		end

		return { NextScreen = "#nowplaying" } -- Complete the call at this point
	end

	function n:GetSearchHistory(idBinding, seq, args)
		local items = g_SearchHistory:get()
		local list = ""
		for i,v in pairs(items) do
			list = list .. BuildSimpleXml("item", v, true)
		end
		return { ["List"] = list }
	end

	function n:DeleteSearchHistory(idBinding, seq, args)
		local id = tonumber(args["id"])
		g_SearchHistory:delete(id)
		return {}
	end

	function n:PresetCommand(idBinding, seq, args)
		local id = args["id"]

		local add = true
		if (args["is_preset"] == "true") then
			add = false
		end

		local url

		if (id ~= nil) then
			if (add) then
				url = "http://opml.radiotime.com/Preset.ashx?c=add&" .. GetGlobalArgs() .. "&id=" .. id .. "&locale=" .. self:GetLocale()
			else
				url = "http://opml.radiotime.com/Preset.ashx?c=remove&" .. GetGlobalArgs() .. "&id=" .. id .. "&locale=" .. self:GetLocale()
			end
		else
			if (add) then
				dbg("Cannot add to presets!")
			else
				dbg("Cannot remove from presets!")
			end
		end

		if (url ~= nil) then
			local context = {}
			context["stationId"] = id
			context["add"] = add

			self:urlGet(idBinding, seq, url, self.PresetCommandTicketHandler, context)
			-- No need to "complete" the call at this point, will be done in PresetCommandTicketHandler
		else
			return {} -- Complete the call
		end
	end

	function n:PresetCommandTicketHandler(idBinding, seq, strError, jobj, responseCode, tHeaders, context)
		local id = context["stationId"]

		if (strError ~= nil) then
			dbg("Preset command failed: " .. strError)
			NetworkError(strError)
		else
			if (jobj["head"]["status"] == "200") then
				dbg("Preset command successful, querying station " .. id .. " for updated status...")

				-- Update the preset in any now playing information.  We assume that the action succeeded as expected.
				-- If this assumption is unreliable, comment the UpdateNowPlayingQueueForStation call and return statement
				--  out and enable the code below
				Navigator:UpdateNowPlayingQueueForStation(id, context["add"])

				SyncPresetsWithMMDB()

				return { RefreshScreen = "true" } -- Complete the call

				-- Uncomment the following to enable double-checking against TuneIn for the is_preset flag
	--[[
				local url = "http://opml.radiotime.com/Describe.ashx?" .. GetGlobalArgs() .. "&id=" .. id .. "&locale=" .. self:GetLocale()
				self:urlGet(idBinding, seq, url, self.PresetCommandDescribeStationTicketHandler, context)
				-- No need to "complete" the call at this point, will be done in PresetCommandDescribeStationTicketHandler
	--]]
			else
				dbg("Preset command failed: " .. jobj["head"]["fault"])
				return {} -- Complete the call
			end
		end
	end

--[[
	function n:PresetCommandDescribeStationTicketHandler(idBinding, seq, strError, jobj, responseCode, tHeaders, context)
		-- This code is currently not used (see comment in PresetCommandTicketHandler()).  If it turns out that
		-- we cannot trust whether an item actually was marked as a preset (or removed), this queries the actual
		-- status after the add/remove action was performed.
		local id = context["stationId"]
		local add = context["add"]

		if (strError ~= nil) then
			dbg("Could not describe station " .. id .. ", assuming preset action succeeded: " .. strError)
			-- Don't call NetworkError() at this point, things worked well, only double-checking failed
		else
			if (jobj["head"]["status"] == "200") then
				local isPreset
				if (#jobj["body"] > 0) then
					isPreset = false
					if (jobj["body"][1]["is_preset"] == "true") then
						isPreset = true
					end
				end

				if (isPreset ~= nil) then
					-- Check the actual preset status
					add = isPreset
				end
			else
				dbg("Could not describe station " .. id .. ", assuming preset action succeeded")
			end
		end

		-- Update the preset in any now playing information
		Navigator:UpdateNowPlayingQueueForStation(id, add)

		SyncPresetsWithMMDB()

		-- TODO: Don't do refresh on the now playing screen
		return { RefreshScreen = "true" } -- Complete the call
	end
--]]

	function n:OnUpdatedRoomMapInfo(oldMap, newMap)
		-- This function is called when the queue's room map information is updated.  This allows
		-- us to handle situations when a room gets added or removed from a queue.
		local oldQueue = GetQueueFromRoom(oldMap, self._room)
		local newQueue = GetQueueFromRoom(newMap, self._room)

		--dbg("n:OnUpdatedRoomMapInfo() room: " .. self._room .. " oldQueue: " .. oldQueue .. " newQueue: " .. newQueue)
		if (oldQueue ~= newQueue) then
			if (newQueue ~= 0) then
				dbg("Navigator.OnUpdatedRoomMapInfo for nav " .. self._nav .. ": Room " .. self._room .. " joined queue " .. newQueue)
			else
				dbg("Navigator.OnUpdatedRoomMapInfo for nav " .. self._nav .. ": Room " .. self._room .. " no longer in queue " .. oldQueue)
			end

			-- Update the navigator now playing.  If newQueue is 0, it will clear the now playing screen.
			Navigator:SendQueueChangedEvent(newQueue)
		end
	end

	function n:DescribeById(idBinding, id, roomId, volume)
         	local url = "http://opml.radiotime.com/Describe.ashx?" .. GetGlobalArgs() .. "&id=" .. id .. "&locale=" .. GetLocale()
         	local context = {}
         	context["roomId"] = roomId
			context["volume"] = volume
         	self:urlGet(idBinding, 0, url, self.DescribeByIdHandler, context)
         end

         function n:DescribeByIdHandler(idBinding, seq, strError, jobj, responseCode, tHeaders, context)
			if (strError ~= nil) then
				dbg("DescribeByIdHandler failed: " .. strError)
			else
				if (jobj["head"]["status"] == "200") then
					dbg("DescribeByIdHandler parsing data...")
					local itemType = jobj["body"][1]["element"]
						if (itemType == "station") then
							local roomId = context["roomId"]
							local volume = context["volume"]
							local guideId = jobj["body"][1]["guide_id"]
							local item = jobj["body"][1]["element"]
							local text = jobj["body"][1]["slogan"]
							local imageUrl = jobj["body"][1]["logo"]
							if (text == nil) then
								text = ""
							end
							if (imageUrl == nil) then
								imageUrl = ""
							end

							dbg("Got guide id of " .. guideId .. " for roomId " .. roomId)
							local url = "http://opml.radiotime.com/Tune.ashx?" .. GetGlobalArgsNoRender() .. "&id=" .. guideId .. "&locale=" .. GetLocale()
							self:PlayItem(idBinding, seq, url, item, true, guideId, text, imageUrl, volume)
						elseif (itemType == "show") then
							dbg("TBD:  WE NEED TO HANDLE PODCASTS FOR THIS TO WORK")
						elseif (itemType == "topic") then
							-- Make sure to include the sid= in the URL here!
							dbg("TBD:  WE NEED TO HANDLE ??? FOR THIS TO WORK")
						end
				else
					dbg("DescribeByIdHandler failed!")
				end
			end
         end

         function n:OnDeviceSelected(idBinding, tParams)
         	local roomId = tParams["idRoom"]
			local volume = tParams["volume"]
         	local presetId = tParams["location"]

			if (presetId ~= nil) then
				if (string.starts(presetId, "u")) then
					dbg("OnMediaSelected for roomId " .. roomId .. " with presetId " .. presetId .. " (custom url)")
					local favoriteHandler = function(strError, favorites, ctx)
						if (strError ~= nil) then
							dbg("Error searching presets: " .. strError)
						else
							local info = favorites[presetId]
							if (info ~= nil) then
								local url = "http://opml.radiotime.com/Tune.ashx?" .. GetGlobalArgsNoRender() .. "&id=" .. presetId .. "&locale=" .. GetLocale()
								self:PlayItem(idBinding, 0, url, "url", true, presetId, info["text"], info["image"], volume)
							else
								dbg("Could not find presets: " .. presetId)
							end
						end
					end
					GetFavorites(favoriteHandler, presetId)
				else
					dbg("OnMediaSelected for roomId " .. roomId .. " with presetId " .. presetId)
					self:DescribeById(idBinding, presetId, roomId, volume)
				end
			end
         end

	return n
end

function Navigator:Destroy()
	dbg("Navigator:Destroy ()")
	for i,v in pairs(gNavigators) do
		v:Destroy()
	end
end

function Navigator:OnTimerExpired(idTimer)
	for i,v in pairs(gNavigators) do
		v:OnTimerExpired(idTimer)
	end
end

function Navigator:BuildNowPlayingQueue(queueId)
	local nowPlaying = gNowPlaying[queueId]
	if (nowPlaying == nil) then
		nowPlaying = {}
	end

	local ret = {}
	local list = ""
	local first = true
	for i,v in ipairs(nowPlaying) do
		list = list .. BuildSimpleXml("item", v, true)
		if (first) then
			ret["NowPlaying"] = BuildSimpleXml(nil, v, true)
			ret["NowPlayingIndex"] = 0
			first = false
		end
	end
	if (first) then
		ret["NowPlaying"] = ""
	end
	ret["List"] = list
	return ret
end

function Navigator:UpdateNowPlayingQueueEntry(entry, nowPlaying, isPreset)
	entry["Title"] = nowPlaying["STATION"]
	entry["SubTitle"] = nowPlaying["TITLE"]
	entry["ImageUrl"] = nowPlaying["LOGO_URL"]
	entry["guide_id"] = nowPlaying["GUIDE_ID"]
	entry["is_preset"] = tostring(isPreset)
	entry["item"] = nowPlaying["ITEM_TYPE"]
	entry["itemType"] = nowPlaying["PLAY_ITEM_TYPE"]
	entry["URL"] = nowPlaying["URL"]
end

function Navigator:UpdateNowPlayingQueue(queueId, nowPlaying, id, isPreset)
	-- Update any existing items
	local nowPlayingQueue = gNowPlaying[queueId]

	if (nowPlayingQueue ~= nil) and (nowPlayingQueue[1]["Id"] == id) then
		local info = nowPlayingQueue[1]
		if (info["Id"] == id) then
			--dbg("Update item to GuideId " .. nowPlaying["GUIDE_ID"])
			Navigator:UpdateNowPlayingQueueEntry(info, nowPlaying, isPreset)
		end
	else
		if (nowPlayingQueue ~= nil) then
			-- Delete any matching entries
			local removed
			repeat
				removed = false
				for i,v in pairs(nowPlayingQueue) do
					if (v["Id"] == id) then
						table.remove(nowPlayingQueue, i)
						removed = true
						break
					end
				end
			until not removed
		end

		-- Now add the new item to the top of the queue
		local info = {}
		info["Id"] = id
		Navigator:UpdateNowPlayingQueueEntry(info, nowPlaying, isPreset)

		if (nowPlayingQueue == nil) then
			nowPlayingQueue = {}
			gNowPlaying[queueId] = nowPlayingQueue
		end
		table.insert(nowPlayingQueue, 1, info)
	end

	-- Get rid of items too far down in the list
	while (#gNowPlaying[queueId] > gNowPlayingLength) do
		table.remove(gNowPlaying[queueId], #gNowPlaying[queueId])
	end

	-- Update the navigators that care
	Navigator:SendQueueChangedEvent(queueId)
end

function Navigator:SendQueueChangedEvent(queueId)
	dbg("Navigator:SendQueueChangedEvent(" .. queueId .. ")")
	local tRooms = GetRoomsByQueue(nil, queueId)
	if (tRooms ~= nil) then
		SendEvent(MEDIA_SERVICE_PROXY_BINDING_ID, nil, tRooms, "QueueChanged", Navigator:BuildNowPlayingQueue(queueId))
	end
end

function Navigator:UpdateNowPlayingQueueForStation(id, isPreset)
	for i,v in pairs(gNowPlaying) do
		local queueId = i
		local updated = false
		for j,w in pairs(v) do
			local info = w
			if (info["guide_id"] == id) then
				local prevValue = info["is_preset"]
				info["is_preset"] = tostring(isPreset)

				if (prevValue ~= tostring(isPreset)) then
					updated = true
				end
			end
		end

		if (updated) then
			-- The is_preset field was updated, make sure we update all navigators that care
			Navigator:SendQueueChangedEvent(queueId)
		end
	end
end

function Navigator:ClearNowPlayingQueue(queueId)
	gNowPlaying[queueId] = nil

	-- Update all navigators that care
	Navigator:SendQueueChangedEvent(queueId)
end

function Navigator:OnUpdatedRoomMapInfo(oldMap, newMap)
	for i,v in pairs(gNavigators) do
		v:OnUpdatedRoomMapInfo(oldMap, newMap)
	end
end

function Navigator:OnUpdateMediaInfo(queueId, mediaInfo)
	local nowPlaying = gNowPlaying[queueId]
	if (nowPlaying ~= nil) then
		local info = C4:ParseXml(mediaInfo)
		if (info ~= nil) then
			-- We actually have now playing information for this queue,
			-- check if the now playing title has changed
			local title = GetNodeValueByPath(info, "title")

			-- Ignore certain "titles"...
			if ((title ~= nil) and (title ~= "Internet Radio") and (title ~= "Waiting for data...")) then
				local guideId = GetNodeValueByPath(info, "queueInfo")

				local updated = false
				for i,v in pairs(nowPlaying) do
					if (v["guide_id"] == guideId) then
						--dbg("Updating item " .. i)
						local oldTitle = v["SubTitle"]
						if (oldTitle ~= title) then
							-- The information actually updated, save it
							v["SubTitle"] = title
							updated = true
						end
					end
				end

				if (updated) then
					-- TODO: Update the information in the now playing cache as well,
					-- assuming this is what TuneIn would update to

					-- Update the navigators that care
					Navigator:SendQueueChangedEvent(queueId)

					UpdateNowPlayingArtwork(queueId, guideId, title)
				end
			end
		end
	end
end

function UpdateNowPlayingArtwork(queueId, guideId, line)
	local queueInfo = gQueues[queueId]
	if (queueInfo ~= nil and queueInfo["STREAM_ART"] ~= nil) then
		local url = queueInfo["STREAM_ART"]
		dbg("Update queue " .. queueId .. " with artwork provided by stream: " .. url)

		UpdateMediaInfoForNowPlaying(MEDIA_SERVICE_PROXY_BINDING_ID, queueId, url)
		return
	end
	
	local artist
	local title

	-- Try to parse the line for an artist and title
	local index = string.find(line, " - ", 1, true)
	if (index ~= nil) then
		artist = string.sub(line, 1, index - 1)
		title = string.sub(line, index + 3)
	else
		index = string.find(line, "-", 1, true)
		if (index ~= nil) then
			artist = string.sub(line, 1, index - 1)
			title = string.sub(line, index + 1)
		else
			artist = line
			title = line
		end
	end

	-- Query the artwork from TuneIn.  If either artist or title is an empty string,
	-- use the same for both.  Otherwise TuneIn will return an error.
	if ((string.len(artist) == 0) and (string.len(title) > 0)) then
		artist = title
	end
	if ((string.len(title) == 0) and (string.len(artist) > 0)) then
		title = artist
	end

	local context = {}
	context["queueId"] = queueId
	context["guideId"] = guideId
	context["artist"] = artist
	context["title"] = title
	context["line"] = line
	LookupArtwork(artist, title, _G["UpdateNowPlayingArtworkLookupArtworkCallback"], context)
end

function ChooseArtworkUrl(artworkUrls, size)
	-- Try to find the size specified
	for i,v in pairs(artworkUrls) do
		if (i == size) then
			return v
		end
	end

	-- Nothing found, default to size "default"
	for i,v in pairs(artworkUrls) do
		if (i == "default") then
			return v
		end
	end

	-- Still nothing found, pick anything
	for i,v in pairs(artworkUrls) do
		return v
	end
end

function UpdateNowPlayingArtworkLookupArtworkCallback(context, info)
	local queueId = context["queueId"]
	local guideId = context["guideId"]
	local artist = context["artist"]
	local title = context["title"]
	local line = context["line"]

	local url = nil

	if (info["error"] ~= nil) then
		dbg("Error looking up artwork (artist: " .. artist .. " title: " .. title .. "): " .. info["error"])
	else
		if (info["found"]) then
			if (info["album_urls"] ~= nil) then
				url = ChooseArtworkUrl(info["album_urls"], "large")
			end

			if ((url == nil) and (info["artist_urls"] ~= nil)) then
				url = ChooseArtworkUrl(info["artist_urls"], "large")
			end

			if (url == nil) then
				dbg("Didn't pick any TuneIn artwork! artist: " .. artist .. " title: " .. title)
			end
		else
			dbg("TuneIn does not have any artwork! artist: " .. artist .. " title: " .. title)
		end
	end

	if (url == nil) then
		-- We don't have any artwork, use the station logo instead
		local nowPlaying = gNowPlaying[queueId]
		if (nowPlaying ~= nil) then
			for i,v in pairs(nowPlaying) do
				if (v["guide_id"] == guideId) then
					url = v["ImageUrl"]
					break
				end
			end
		end

		if (url ~= nil) then
			dbg("No artwork available, use station logo instead: " .. url)
		else
			dbg("No artwork available and no station logo available")
		end
	end

	if (url ~= nil) then
		dbg("Update queue " .. queueId .. " with artwork for artist " .. artist .. " and title " .. title .. ", artwork url " .. url)

		UpdateMediaInfoForNowPlaying(MEDIA_SERVICE_PROXY_BINDING_ID, queueId, url)
	end
end

function BuildSimpleXml(tag, tData, escapeValue)
	local xml = ""

	if (tag ~= nil) then
		xml = "<" .. tag .. ">"
	end

	if (escapeValue) then
		for i,v in pairs(tData) do
			xml = xml .. "<" .. i .. ">" .. C4:XmlEscapeString(v) .. "</" .. i .. ">"
		end
	else
		for i,v in pairs(tData) do
			xml = xml .. "<" .. i .. ">" .. v .. "</" .. i .. ">"
		end
	end

	if (tag ~= nil) then
		xml = xml .. "</" .. tag .. ">"
	end
	return xml
end

RoomCommands = {
	["PLAY"] = function(idRoom)
			-- Let digital audio handle this command
			return false
		end,
	["PAUSE"] = function(idRoom)
			-- Let digital audio handle this command
			return false
		end,
	["STOP"] = function(idRoom)
			-- Let digital audio handle this command
			return false
		end,
	["SKIP_FWD"] = function(idRoom)
			-- Override this command, we don't want digital audio to handle this
			return true
		end,
	["SKIP_REV"] = function(idRoom)
			-- Override this command, we don't want digital audio to handle this
			return true
		end
}

function ReceivedFromProxy(idBinding, strCommand, tParams)
	--dbg("ReceivedFromProxy (" .. idBinding .. ", " .. strCommand .. ")")
	if (strCommand ~= nil) then
		if(tParams == nil)		-- initial table variable if nil
			then tParams = {}
		end
		--dbg("Received from Proxy: " .. strCommand .. " on binding " .. idBinding)
		if (idBinding == MEDIA_SERVICE_PROXY_BINDING_ID) then
			local navId = tParams["NAVID"]
			local nav = gNavigators[navId]
			if (strCommand == "DESTROY_NAV") then
				if (nav ~= nil) then
					dbg("ReceivedFromProxy: Destroying navigator")
					nav:Destroy()
					nav = nil
					gNavigators[navId] = nil
				end
			elseif (strCommand == "INTERNET_RADIO_SELECTED") then
				OnInternetRadioSelected(idBinding, tParams)
			elseif (strCommand == "QUEUE_STATE_CHANGED") then
				OnQueueStatusChanged(idBinding, tParams)
			elseif (strCommand == "QUEUE_DELETED") then
				OnQueueDeleted(idBinding, tParams)
			elseif (strCommand == "QUEUE_STREAM_STATUS_CHANGED") then
				OnQueueStreamStatusChanged(idBinding, tParams)
			elseif (strCommand == "QUEUE_MEDIA_INFO_UPDATED") then
				OnQueueMediaInfoUpdated(idBinding, tParams)
			elseif (strCommand == "DEVICE_SELECTED") then
				navId = "Prog_Room" .. tParams["idRoom"]
				nav = gNavigators[navId]
				if (nav == nil) then
					nav = Navigator:Create(navId, nil)
					gNavigators[navId] = nav
				end
				nav._room = tParams["idRoom"]
				nav.OnDeviceSelected(nav, idBinding, tParams)
				return
			elseif ((strCommand == "PLAY") or (strCommand == "PAUSE") or
				(strCommand == "STOP") or (strCommand == "SKIP_REV") or
				(strCommand == "SKIP_FWD")) then
				-- Handle notification
				local idRoom = tonumber(tParams["ROOM_ID"])
				local ret = RoomCommands[strCommand](idRoom)
				if (ret) then
					return "<ret><handled>true</handled></ret>"
				else
					return "<ret><handled>false</handled></ret>"
				end
			elseif ((nav == nil) and (navId ~= nil)) then
				nav = Navigator:Create(navId, tParams["LOCALE"])
				gNavigators[navId] = nav
			end
			if (nav ~= nil) then
				local cmd = nav[strCommand]

				if (cmd == nil) then
					dbg("ReceivedFromProxy: Unhandled command = " .. strCommand)
					return
				end

				nav._locale = tParams["LOCALE"] -- Update the local in case it has changed
				nav._room = tParams["ROOMID"] -- Update the room id in case it has changed

				local seq = tParams["SEQ"]
				local args = {}
				local parsedArgs = C4:ParseXml(tParams["ARGS"])
				for i,v in pairs(parsedArgs.ChildNodes) do
					args[v.Attributes["name"]] = v.Value
				end
				local success, ret = pcall(cmd, nav, idBinding, seq, args)
				if (success) then
					if (ret ~= nil) then
						dbg("Called " .. strCommand .. ".  Returning data immediately")
						DataReceived(idBinding, navId, seq, ret)
					else
						dbg("Called " .. strCommand .. ".  Defer returning data...")
					end
				else
					dbg("Called " .. strCommand .. ".  An error occured: " .. ret)
					DataReceivedError(idBinding, navId, seq, ret)
				end
			end
		end
	end
end


--------------- Programming Support ----------------

function GetFavorites(callback, context)
	local browseHandler, reportError
	local requestCount = 1
	local failed = false

	local favorites = {}

	reportError = function(strError)
		failed = true
		dbg("Error getting favorites: " .. strError)
		callback(strError, nil, context)
	end

	browseHandler = function(strError, responseCode, tHeaders, jobj)
		requestCount = requestCount - 1

		if (not failed) then
			if (strError ~= nil) then
				reportError(strError)
			elseif (jobj["head"] == nil or jobj["body"] == nil) then
				reportError("Unexpected response")
			elseif (jobj["head"]["status"] ~= "200") then
				reportError("Service responded with error: " .. tostring(jobj["head"]["status"]))
			else
				local parseItems
				parseItems = function(json)
					for i,v in pairs(json) do
						if (type(v) == "table") then
							local itemType = v["type"]
							if ((itemType == "link" and v["item"] ~= "show") or itemType == "audio") then
								local url = v["URL"]

								if (url ~= nil) then
									local presetId = v["preset_id"]
									if (presetId == nil) then
										--dbg("Folder detected:  " .. v["text"])
										requestCount = requestCount + 1
										urlGet(url .. "&render=json", browseHandler, nil, false, true)
									else
										local item = {
											["id"] = presetId,
											["type"] = v["type"],
											["text"] = v["text"],
											["image"] = v["image"]
										}
										favorites[presetId] = item
									end
								end
							else
								local key = v["key"]
								if (key ~= "settings") then -- Filter out the "Settings" entry that is shown on unjoined devices
									local children = v["children"]
									if (type(children) == "table") then
										parseItems(children)
									end
								end
							end
						end
					end
				end

				parseItems(jobj["body"])

				if (requestCount == 0) then
					-- Call the callback with the final results
					callback(nil, favorites, context)
				end
			end
		end
	end

	local url = "http://opml.radiotime.com/Browse.ashx?" .. GetGlobalArgs() .. "&c=presets&locale=" .. GetLocale()
	urlGet(url, browseHandler, nil, false, true)
end

function SyncFavorites(callback, context)
	local getFavoritesHandler, reportError
	local failed = false

	reportError = function(strError)
		failed = true
		dbg("Error syncing favorites: " .. strError)
		callback(strError, context)
	end

	getFavoritesHandler = function(strError, favorites, ctx)
		if (strError ~= nil) then
			reportError(strError)
		else
			local proxyDev = C4:GetProxyDevices()
			if (proxyDev) then
				C4:MediaSetDeviceContext(proxyDev)
			end

			local removeMediaDbEntries = C4:MediaGetAllBroadcastAudio() or {}
			local addDbEntries = {}
			for id,v in pairs(favorites) do
				local found = false
				for j,w in pairs(removeMediaDbEntries) do
					if (w == id) then
						removeMediaDbEntries[j] = nil
						found = true
						break
					end
				end

				if (not found) then
					addDbEntries[id] = v
				end
			end

			local syncWithDatabase = function()
				dbg("Retrieved all data, now synchronize with database")

				for id,v in pairs(addDbEntries) do
					local dbData = v["dbData"]
					if (dbData ~= nil) then
						local mediaId = C4:MediaAddBroadcastAudioInfo(dbData["presetId"], dbData["name"], dbData)
						dbg("Added preset " .. id .. " (" .. dbData["name"] .. ") with id " ..  mediaId .. " to the database")
					--else
					--	dbg("Not adding preset " .. id .. ", not a station.")
					end
				end

				for id,presetId in pairs(removeMediaDbEntries) do
					dbg("Remove preset " .. presetId .. " with media id " .. id .. " from Media Database")
					C4:MediaRemoveBroadcastAudio(id)
				end

				-- Now call the final callback, the operation completed
				callback(nil, context)
			end

			local requestsCnt = 0

			local fetchArtwork = function(url, dbData)
				local artworkHandler = function(strError, responseCode, tHeaders, httpData, dbData)
					requestsCnt = requestsCnt - 1

					if (not failed) then
						if (strError ~= nil) then
							dbg("Could not fetch artwork for preset " .. dbData["presetId"] .. ": " .. strError)
						else
							dbData["cover_art"] = C4:Base64Encode(httpData)
						end

						if (requestsCnt == 0) then
							syncWithDatabase()
						end
					end
				end

				requestsCnt = requestsCnt + 1
				urlGet(url, artworkHandler, dbData, true)
			end

			local describeHandler = function(strError, responseCode, tHeaders, jobj, addingItem)
				requestsCnt = requestsCnt - 1

				if (not failed) then
					if (strError ~= nil) then
						reportError(strError)
					elseif (jobj["head"] == nil or jobj["body"] == nil) then
						reportError("Unexpected response")
					elseif (jobj["head"]["status"] ~= "200") then
						reportError("Service responded with error: " .. tostring(jobj["head"]["status"]))
					else
						local data = jobj["body"][1]
						if (data == nil) then
							dbg("Not adding " .. addingItem["id"] .. ", no information available")
							addDbEntries[addingItem["id"]] = nil
						else
							local itemType = data["element"]
							if (itemType == "station") then
								local id = data["preset_id"]
								--dbg("Fetching art work for " .. id .. " (" .. data["name"] .. ") at URL " .. data["logo"])
								local dbData = {
									presetId = id,
									name = data["name"],
									description = data["description"],
									genre = data["genre_name"],
									audio_only = "True",
									url = data["url"]
								}

								addingItem["dbData"] = dbData

								fetchArtwork(string.gsub(data["logo"], "q.png", ".jpg"), dbData)
							elseif (itemType == "show") then
								--dbg("TBD:  WE NEED TO HANDLE PODCASTS FOR THIS TO WORK")
							elseif (itemType == "topic") then
								--dbg("TBD:  WE NEED TO HANDLE ??? FOR THIS TO WORK")
							end
						end

						if (requestsCnt == 0) then
							syncWithDatabase()
						end
					end
				end
			end

			if (next(addDbEntries)) then
				for id, v in pairs(addDbEntries) do
					if (v["type"] == "link") then
						local dbData = {
							presetId = id,
							name = v["text"],
							description = "",
							genre = "",
							audio_only = "True",
							url = v["URL"]
						}

						v["dbData"] = dbData
						if (v["image"] ~= nil) then
							--dbg("Fetching art work for " .. id .. " (" .. v["text"] .. ") at URL " .. v["image"])
							fetchArtwork(string.gsub(v["image"], "q.png", ".jpg"), dbData)
						end
					else
						requestsCnt = requestsCnt + 1
						local url = "http://opml.radiotime.com/Describe.ashx?id=" .. id .. "&" .. GetGlobalArgs() .. "&locale=" .. GetLocale()
						urlGet(url, describeHandler, v)
					end
				end

				if (requestsCnt == 0) then
					syncWithDatabase()
				end
			else
				syncWithDatabase()
			end
		end
	end

	GetFavorites(getFavoritesHandler, nil)
end

function SyncPresetsWithMMDB()
	local syncFavoritesHandler = function(strError, context)
		if (strError ~= nil) then
			dbg("Syncing favorites failed: " .. strError)
		else
			dbg("Syncing favorites succeeded.")
		end
	end
	dbg("Synchronizing favorites...")
	SyncFavorites(syncFavoritesHandler, nil)
end

--------------- End Programming Support ----------------

------------------- Initialization ---------------------

function CheckDriverDisabled()
 if (CheckControllerTypeAndVersion() ) then
   C4:UpdateProperty("Supported Controller",  "True")
   g_controllerValid = true
   if (Properties["Disabled"] == "True") then
 	SendToProxy(MEDIA_SERVICE_PROXY_BINDING_ID, "DISABLE_DRIVER", {}, "COMMAND")
   else
 	SendToProxy(MEDIA_SERVICE_PROXY_BINDING_ID, "ENABLE_DRIVER", {}, "COMMAND")
   end
 else
   C4:UpdateProperty("Supported Controller", "False")
   g_controllerValid = false
   SendToProxy(MEDIA_SERVICE_PROXY_BINDING_ID, "DISABLE_DRIVER", {}, "COMMAND")
 end
end

function XMLEncode (s)
	if (s == nil) then return end
	s = tostring (s)

	s = string.gsub (s, '&',	'&amp;')
	s = string.gsub (s, '"',	'&quot;')
	s = string.gsub (s, '<',	'&lt;')
	s = string.gsub (s, '>',	'&gt;')
	s = string.gsub (s, '\'',	'&apos;')
	return s
end

function XMLTag (strName, tParams, tagSubTables, xmlEncodeElements)
	local retXML = {}

	local addTag = function (tagName, closeTag)
		if (tagName == nil) then return end

		if (closeTag) then
			tagName = string.match (tostring (tagName), '^(%S+)')
		end

		if (tagName and tagName ~= '') then
			table.insert (retXML, '<')
			if (closeTag) then
				table.insert (retXML, '/')
			end
			table.insert (retXML, tostring (tagName))
			table.insert (retXML, '>')
		end
	end

	if (type (strName) == 'table' and tParams == nil) then
		tParams = strName
		strName = nil
	end

	addTag (strName)

	if (type (tParams) == 'table') then
		local arraySize = #tParams
		local tableSize = 0
		for _, _ in pairs (tParams) do
			tableSize = tableSize + 1
		end
		if (arraySize == tableSize) then
			for _, subItem in ipairs (tParams) do
				table.insert (retXML, XMLTag (nil, subItem, tagSubTables, xmlEncodeElements))
			end

		else
			for k, v in pairs (tParams) do
				if (v == nil) then v = '' end
				if (type (v) == 'table') then
					if (k == 'image_list') then
						for _, image_list in pairs (v) do
							table.insert (retXML, image_list)
						end
					elseif (tagSubTables == true) then
						table.insert (retXML, XMLTag (k, v, tagSubTables, xmlEncodeElements))
					end
				else
					if (v == nil) then v = '' end

					addTag (k)

					if (xmlEncodeElements ~= false) then
						table.insert (retXML, XMLEncode (tostring (v)))
					else
						table.insert (retXML, tostring (v))
					end

					addTag (k, true)
				end
			end
		end

	elseif (tParams) then
		if (xmlEncodeElements ~= false) then
			table.insert (retXML, XMLEncode (tostring (tParams)))
		else
			table.insert (retXML, tostring (tParams))
		end
	end

	addTag (strName,true)

	return (table.concat (retXML))
end
