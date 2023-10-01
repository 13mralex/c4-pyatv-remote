import asyncio
from aiohttp import WSMsgType, web
import pyatv
from pyatv.interface import (
    App,
    DeviceListener,
    Playing,
    PowerListener,
    PushListener,
    RemoteControl,
    retrieve_commands,
    Audio
)
from pyatv.const import (
    InputAction
)
from enum import Enum
import datetime
from pyatv.const import Protocol
import base64
from io import BytesIO
import os
import json
import urllib.request
import requests

PAGE = """
<script>
let socket = new WebSocket('ws://' + location.host + '/ws/DEVICE_ID');

socket.onopen = function(e) {
  document.getElementById('status').innerText = 'Connected!';
};

socket.onmessage = function(event) {
  document.getElementById('state').innerText = event.data;
};

socket.onclose = function(event) {
  if (event.wasClean) {
    document.getElementById('status').innerText = 'Connection closed cleanly!';
  } else {
    document.getElementById('status').innerText = 'Disconnected due to error!';
  }
  document.getElementById('state').innerText = "";
};

socket.onerror = function(error) {
  document.getElementById('status').innerText = 'Failed to connect!';
};
</script>
<div id="status">Connecting...</div>
<div id="state"></div>
"""

routes = web.RouteTableDef()

APPLE_BUNDLES = {}
APPLE_BUNDLES["com.apple.TVMusic"]      = "com.apple.Music"
APPLE_BUNDLES["com.apple.TVWatchList"]  = "com.apple.tv"
APPLE_BUNDLES["com.apple.TVShows"]   	= "com.apple.MobileStore"
APPLE_BUNDLES["com.apple.TVMovies"]   	= "com.apple.MobileStore"

class DeviceListener(pyatv.interface.DeviceListener, pyatv.interface.PushListener):
    def __init__(self, app, identifier):
        self.app = app
        self.identifier = identifier

    def connection_lost(self, exception: Exception) -> None:
        self._remove()

    def connection_closed(self) -> None:
        self._remove()

    def _remove(self):
        self.app["atv"].pop(self.identifier)
        self.app["listeners"].remove(self)

    def playstatus_update(self, updater, playstatus: pyatv.interface.Playing) -> None:
        clients = self.app["clients"].get(self.identifier, [])
        for client in clients:
            atv = self.app["atv"].get(self.identifier)
            status = output_playing(playstatus,atv.metadata.app)
            asyncio.ensure_future(client.send_str(str(status)))

    def playstatus_error(self, updater, exception: Exception) -> None:
        pass


def web_command(method):
    async def _handler(request):
        device_id = request.match_info["id"]
        atv = request.app["atv"].get(device_id)
        if not atv:
            return web.Response(text=f"Not connected to {device_id}", status=500)
        return await method(request, atv)

    return _handler


def add_credentials(config, query):
    for service in config.services:
        proto_name = service.protocol.name.lower()
        if proto_name in query:
            config.set_credentials(service.protocol, query[proto_name])


def output(success: bool, error=None, exception=None, values=None):
    """Produce output in intermediate format before conversion."""
    now = datetime.datetime.now(datetime.timezone.utc).astimezone().isoformat()
    result = {"result": "success" if success else "failure", "datetime": str(now)}
    if error:
        result["error"] = error
    if exception:
        result["exception"] = str(exception)
        result["stacktrace"] = "".join(
            traceback.format_exception(
                type(exception), exception, exception.__traceback__
            )
        )
    if values:
        result.update(**values)
    return json.dumps(result)


def output_playing(playing: Playing, app: App):
    """Produce output for what is currently playing."""

    def _convert(field):
        if isinstance(field, Enum):
            return field.name.lower()
        return field if field else "none"

    commands = retrieve_commands(Playing)
    values = {k: _convert(getattr(playing, k)) for k in commands}
    if app:
        values["app"] = app.name
        values["app_id"] = app.identifier
        values["app_icon"] = getAppIcon(app.identifier)
    else:
        values["app"] = "none"
        values["app_id"] = "none"
    return output(True, values=values)


def getAppIcon(bundle_id):
    """print("App icon request for: "+bundle_id)"""
    url = "http://itunes.apple.com/lookup?bundleId="
    if bundle_id in APPLE_BUNDLES:
        bundle_id = APPLE_BUNDLES[bundle_id]
    else:
        bundle_id = bundle_id
    url = url+bundle_id
    """print("Calling url: "+url)"""
    r = requests.get(url)
    r = r.content
    r = json.loads(r)
    if r['resultCount'] == 0:
        result = ''
    else:
        result = r['results'][0]['artworkUrl512']
    return result

@routes.get("/state/{id}")
async def state(request):
    return web.Response(
        text=PAGE.replace("DEVICE_ID", request.match_info["id"]),
        content_type="text/html",
    )


@routes.get("/scan")
async def scan(request):
    results = os.popen("atvscript scan").read()
    return web.Response(text=results)

@routes.get("/pair/{id}/{protocol}")
#@web_command
async def pair1(request):
    proto1 = request.match_info["protocol"]
    id = request.match_info["id"]
    loop = asyncio.get_event_loop()
    proto2 = eval("Protocol."+proto1)
    global pairing
    try:
        atvs = await pyatv.scan(loop, timeout=30, identifier=id)
        pairing = await pyatv.pair(atvs[0], proto2, loop)
        await pairing.begin()
    except Exception as ex:
        return web.Response(text=f"Pairing Failed: Error: {ex}")
    return web.Response(text=f"Successfully Sent Pair Request: {proto1}")

@routes.get("/pair/{id}/{protocol}/{pin}")
#@web_command
async def pair2(request):
    proto1 = request.match_info["protocol"]
    #id = request.match_info["id"]
    pin = request.match_info["pin"]
    loop = asyncio.get_event_loop()
    #proto2 = Protocol.proto1
    try:
        #atvs = await pyatv.scan(loop, timeout=30, identifier=id)
        #pairing = await pyatv.pair(atvs[0], Protocol.proto1, loop)
        pairing.pin(pin)
        await pairing.finish()
        creds = pairing.service.credentials
        response = {"status":"Successfully paired with "+proto1,"protocol":proto1,"credentials":creds}
    except Exception as ex:
        return web.Response(text=f"Pairing Failed with pin {pin}: Error: {ex}")
    return web.json_response(response)

@routes.get("/connect/{id}")
async def connect(request):
    loop = asyncio.get_event_loop()
    device_id = request.match_info["id"]
    if device_id in request.app["atv"]:
        return web.Response(text=f"Already connected to {device_id}")

    results = await pyatv.scan(identifier=device_id, loop=loop)
    if not results:
        return web.Response(text="Device not found", status=500)

    add_credentials(results[0], request.query)

    try:
        atv = await pyatv.connect(results[0], loop=loop)
    except Exception as ex:
        return web.Response(text=f"Failed to connect to device: {ex}", status=500)

    listener = DeviceListener(request.app, device_id)
    atv.listener = listener
    atv.push_updater.listener = listener
    atv.push_updater.start()
    request.app["listeners"].append(listener)

    request.app["atv"][device_id] = atv
    return web.Response(text=f"Connected to device {device_id}")


@routes.get("/remote_control/{id}/{command}")
@web_command
async def remote_control(request, atv):
    try:
        await getattr(atv.remote_control, request.match_info["command"])()
    except Exception as ex:
        return web.Response(text=f"Remote control command failed: {ex}")
    return web.Response(text="OK")

@routes.get("/remote_control/{id}/{command}/{action}")
@web_command
async def remote_control(request, atv):
    try:
        rawCmd = request.match_info["command"]
        action = request.match_info["action"]
        cmd = getattr(atv.remote_control, rawCmd)
        act = 0
        if action == "doubletap":
            act = 1
        elif action == "hold":
            act = 2
        finalCmd = await cmd(InputAction(act))
    except Exception as ex:
        return web.Response(text=f"Remote control command failed: {ex}")
    return web.Response(text=f"OK")

@routes.get("/set_volume/{id}/{level}")
@web_command
async def set_volume(request, atv):
    try:
        level = float(request.match_info["level"])
        atv.audio.set_volume(level)
    except Exception as ex:
        return web.Response(text=f"Set volume command failed: {ex}")
    return web.Response(text="OK")

@routes.get("/playing/{id}")
@web_command
async def playing(request, atv):
    try:
        status = output_playing(await atv.metadata.playing(), atv.metadata.app)
        
    except Exception as ex:
        return web.Response(text=f"Remote control command failed: {ex}")
    return web.Response(text=str(status))

@routes.get("/playing/{id}/repeat")
@web_command
async def playing(request, atv):
    try:
        status = await atv.metadata.playing()
    except Exception as ex:
        return web.Response(text=f"Remote control command failed: {ex}")
    return web.Response(text=str(status.repeat))

@routes.get("/playing/{id}/shuffle")
@web_command
async def playing(request, atv):
    try:
        status = await atv.metadata.playing()
    except Exception as ex:
        return web.Response(text=f"Remote control command failed: {ex}")
    return web.Response(text=str(status.shuffle))

@routes.get("/art/{id}/art.png")
@web_command
async def artwork(request, atv):
    try:
        status = await atv.metadata.artwork()
    except Exception as ex:
        return web.Response(text=f"Artwork get failed: {ex}")

    return web.Response(body=bytes(status.bytes))

@routes.get("/art/{id}/art.jpg")
@web_command
async def artwork(request, atv):
    try:
        status = await atv.metadata.artwork()
    except Exception as ex:
        return web.Response(text=f"Artwork get failed: {ex}")

    return web.Response(body=bytes(status.bytes))

@routes.get("/art/{id}/stats")
@web_command
async def artstats(request, atv):
    try:
        status = await atv.metadata.artwork()
    except Exception as ex:
        return web.Response(text=f"Remote control command failed: {ex}")
    return web.Response(text=str(status))

@routes.get("/art/{id}/art")
@web_command
async def artwork0(request, atv):
    #device_id = request.match_info["id"]
    path = await atv.metadata.artwork()
    #stat = web.Response(body=bytes(path.bytes))
    bytes = path.bytes
    #img = Image.open(io.BytesIO(bytes))
    #with open
    try:
        encoded_string = base64.b64encode(bytes)
        result = encoded_string.decode('utf-8')
    except Exception as ex:
        return web.Response(text=f"Artwork get failed: {ex}")
    return web.Response(text=str(result))

@routes.get("/app/{id}")
@web_command
async def artstats(request, atv):
    try:
        status = atv.metadata.app
    except Exception as ex:
        return web.Response(text=f"Remote control command failed: {ex}")
    return web.Response(text=str(status))

@routes.get("/app_list/{id}")
@web_command
async def app_list(request, atv):
    apps = atv.apps
    try:
        app_list = await apps.app_list()
        data = {}
        data["Apps"] = {}
        for app in app_list:
            data["Apps"][app.name] = app.identifier
    except Exception as ex:
        return web.Response(text=f"failed listing apps: error: {ex}")
    return web.json_response(data)

@routes.get("/launch_app/{id}/{app_id}")
@web_command
async def launch_app(request, atv):
    app_id = request.match_info["app_id"]
    apps = atv.apps
    try:
        status = await apps.launch_app(app_id)
    except Exception as ex:
        return web.Response(text=f"failed launching {app_id}: error: {ex}")
    return web.Response(text=f"Launched app: {app_id}")

@routes.get("/close/{id}")
@web_command
async def close_connection(request, atv):
    atv.close()
    return web.Response(text="OK")


@routes.get("/ws/{id}")
@web_command
async def websocket_handler(request, atv):
    device_id = request.match_info["id"]

    ws = web.WebSocketResponse()
    await ws.prepare(request)
    request.app["clients"].setdefault(device_id, []).append(ws)

    status = output_playing(await atv.metadata.playing(), atv.metadata.app)
    await ws.send_str(str(status))

    async for msg in ws:
        if msg.type == WSMsgType.TEXT:
            # Handle custom commands from client here
            if msg.data == "close":
                await ws.close()
        elif msg.type == WSMsgType.ERROR:
            print(f"Connection closed with exception: {ws.exception()}")

    request.app["clients"][device_id].remove(ws)

    return ws


async def on_shutdown(app: web.Application) -> None:
    for atv in app["atv"].values():
        atv.close()


def main():
    app = web.Application()
    app["atv"] = {}
    app["listeners"] = []
    app["clients"] = {}
    app.add_routes(routes)
    app.on_shutdown.append(on_shutdown)
    listen_port = 8080
    web.run_app(app, port=listen_port)


if __name__ == "__main__":
    main()
