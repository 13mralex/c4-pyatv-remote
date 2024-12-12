import falcon.asgi
import uvicorn
import asyncio
import json
import pyatv.conf
import pyatv.const
import pyatv.interface
import requests
import logging
import os
from falcon import WebSocketDisconnected


logging.basicConfig(level="INFO")

"""
GLOBALS
"""
APPLE_BUNDLES = {
    "com.apple.TVMusic": {
        "id": "com.apple.Music",
        "name": "Apple Music"
    },
    "com.apple.TVWatchList": {
        "id": "com.apple.tv",
        "name": "Apple TV+"
    },
    "com.apple.TVShows": {
        "id": "com.apple.MobileStore"
    },
    "com.apple.TVMovies": {
        "id": "com.apple.MobileStore"
    },
    "com.apple.TVPhotos": {
        "id": "com.apple.Photos",
        "name": "Apple Photos"
    },
    "com.apple.Arcade": {
        "id": "com.apple.Arcade",
        "name": "Apple Arcade"
    },
    "com.apple.podcasts": {
        "id": "com.apple.podcasts",
        "name": "Apple Podcasts"
    }
}

"""
CLASSES
"""

class PYATV:
    def __init__(self,atv_app):
        self.loop = asyncio.get_event_loop()
        self.scanresults = []
        self.get_protocols()
        self.atv_app = atv_app
    
    async def on_get_scan(self,req,resp):

        self.scanresults = await pyatv.scan(self.loop,timeout=5)
        #print("Scan:",scan)

        devices = []

        for device in self.scanresults:
            d = {
                "name": device.name,
                "model": device.device_info.model_str,
                "os": f"{device.device_info.operating_system.name} {device.device_info.version}",
                "identifier": device.identifier,
                "address": str(device.address),
                "services": [],
            }
            
            for service in device.services:
                s = {
                    "name": service.protocol.name,
                    "enabled": service.enabled,
                    "password": service.requires_password
                }
                d["services"].append(s)

            devices.append(d)

        resp.media = {
            "status": "OK",
            "results": devices
        }

    async def on_get_pair(self,req,resp):
        id = req.params["id"]
        protocol = req.params["protocol"]
        pin = req.params["pin"]
        
        if not pin:
            resp.media = await self.send_pair_request(id,protocol)
        else:
            resp.media = await self.send_pair_pin(pin)

    async def on_post_pair(self,req,resp):
        data = await req.media
        id = data["id"]
        protocol = data["protocol"]
        pin = data.get("pin")
        
        if not pin:
            resp.media = await self.send_pair_request(id,protocol)
        else:
            resp.media = await self.send_pair_pin(pin)

    async def on_post_connect(self,req,resp):
        data = await req.media

        try:
            id = data["id"]
            device = await self.get_device_by_id(id)
        
            if device:
                
                for protocol,cred in data["creds"].items():
                    p = self.protocols[protocol]
                    c = cred
                    logging.info(f"Setting credentials for {p.name} on {device.name}")
                    device.set_credentials(p,c)

                atv = await pyatv.connect(device,self.loop)
                await self.atv_app.add_atv(atv,id)
                resp.media = {"status":"Connection successful!"}
            else:
                resp.media = {"status":"Connection failed, try pairing again.","connected":False}
        except Exception as e:
            logging.exception("Connection failed")
            resp.media = {"status":f"Connection failed: {str(e)}"}

    async def send_pair_pin(self,pin):
        logging.info(f"Sending code: {pin}")
        try:
            self.pairing.pin(pin)
            await self.pairing.finish()
            result = {
                "status":"Pairing successful!",
                "creds": self.pairing.service.credentials
            }
            return result
        except Exception as e:
            logging.exception("Pairing failed")
            return {"status":f"Pairing failed: {str(e)}"}

    async def send_pair_request(self,id,protocol):

        atv = await self.get_device_by_id(id)
        proto = self.protocols[protocol]

        if atv:
            logging.info(f"Begin pairing {atv.name} with {proto.name}")
            self.pairing = await pyatv.pair(atv,proto,self.loop)
            await self.pairing.begin()
            return {"status": "Waiting for code..."}
        else:
            return {"status": "No ATV found with specified ID. Try scanning again."}

    async def get_device_by_id(self,id):
        
        results = await pyatv.scan(self.loop,identifier=id)

        if results:
            return results[0]
        else:
            return None
    
    def get_protocols(self):
        self.protocols = {}
        for p in pyatv.const.Protocol:
            self.protocols[p.name] = p

class Listener(pyatv.interface.DeviceListener, pyatv.interface.PushListener):
    def __init__(self,atv,id,update_callback):
        self.atv = atv
        self.id = id
        self.update_callback = update_callback

    def connection_lost(self, exception: Exception) -> None:
        logging.error(f"pyatv reports connection lost for {self.id}")
        self.send_msg({"connected":False})

    def connection_closed(self) -> None:
        logging.error(f"pyatv reports connection closed for {self.id}")
        self.send_msg({"connected":False})

    def playstatus_update(self, updater, playstatus):
        self.send_msg(playstatus)

    def playstatus_error(self, updater, exception: Exception):
        logging.exception(f"pyatv reports playstatus error for {self.id}")

    def send_msg(self,msg):
        asyncio.ensure_future(self.update_callback(msg,self.atv,self.id))

class ATV:
    def __init__(self):
        self.loop = asyncio.get_event_loop()
        self.atv_list = {}
        self.app_icon_store = {}
        self.ws_clients = []
        self.connected = False
        self.failed = {"status":"ATV not connected","connected":False}

    async def on_websocket_ws(self,req,ws,id):
        logging.info(f"WS request for {id}")
        _ws = {
            "id": id,
            "ws": ws
        }
        self.ws_clients.append(_ws)
        await ws.accept()

        #Try to send state on connection
        try:
            atv = self.get_atv(id)
            state = await self.parse_metadata(atv)
            await ws.send_media(state)
        except Exception as e:
            logging.exception(f"Couldn't send state on WS: {str(e)}")

        while True:
            try:
                payload = await ws.receive_media()
                logging.info(f"WS Inbound: {payload}")
            except WebSocketDisconnected:
                logging.info("WS Disconnected")
                self.ws_clients.remove(_ws)
                return
        
    async def on_get_features(self,req,resp,id):
        atv = self.get_atv(id)

        if atv:
            features = self.get_features(atv)
            resp.media = features
        else:
            resp.media = {"status":"failed"}

    async def on_post_remote(self,req,resp):
        data = await req.media
        id = data["id"]
        command = data["command"]
        action = data.get("action")

        try:
            
            atv = self.get_atv(id)

            if atv:
                cmd = None
                
                if command=="turn_on" or command=="turn_off":
                    cmd = getattr(atv.power, command)
                else:
                    cmd = getattr(atv.remote_control, command)

                if action:
                    act = None
                    if command=="set_shuffle":
                        act = getattr(pyatv.const.ShuffleState,action)
                    elif command=="set_repeat":
                        act = getattr(pyatv.const.RepeatState,action)
                    else:
                        act = getattr(pyatv.const.InputAction,action)
                    
                    await cmd(act)
                else:
                    await cmd()

                resp.media = {"status":"OK"}
            else:
                resp.media = self.failed
        except Exception as e:
            logging.exception(f"Remote command failed: {str(e)}")
            resp.media = {"status":f"Failed: {str(e)}"}

    async def on_post_keyboard(self,req,resp):
        data = await req.media
        id = data["id"]
        string = data.get("string")
        action = data["action"]

        try:
            
            atv = self.get_atv(id)

            if atv:
                if action=="append":
                    await atv.keyboard.text_append(string)
                elif action=="srt":
                    await atv.keyboard.text_set(string)
                elif action=="clear":
                    await atv.keyboard.text_clear()
                resp.media = {"status":"OK"}
            else:
                resp.media = self.failed
        except Exception as e:
            resp.media = {"status":f"Failed: {str(e)}"}
        
    async def on_get_artwork(self,req,resp,id):
        atv = self.get_atv(id)
        art = await atv.metadata.artwork()
        resp.data = art.bytes

    async def on_get_apps(self,req,resp,id):
        atv = self.get_atv(id)
        #load = req.params.get("load")

        if atv:
            app_list = await atv.apps.app_list()
            apps = []
            for app in app_list:
                a = self.get_app(app)
                apps.append(a)

            data = {
                "status": "OK",
                "apps": apps
            }
            resp.media = data

        else:
            resp.media = {"status":"ATV not found or connected."}

    async def on_get_users(self,req,resp,id):
        atv = self.get_atv(id)

        if atv:
            user_list = await atv.user_accounts.account_list()
            users = []
            for user in user_list:
                u = {
                    "name": user.name,
                    "id": user.identifier
                }
                users.append(u)

            data = {
                "status": "OK",
                "users": users
            }
            resp.media = data

        else:
            resp.media = {"status":"ATV not found or connected."}

    async def on_post_users(self,req,resp,id):
        data = await req.media
        id = data["id"]
        userId = data["userId"]
        atv = self.get_atv(id)

        if atv:
            await atv.user_accounts.switch_account(userId)
            resp.media = {"status":"User switched!"}

        else:
            resp.media = {"status":"ATV not found or connected."}

    async def on_post_app_launch(self,req,resp,id=None):
        data = await req.media
        id = data["id"]
        appId = data["appId"]
        atv = self.get_atv(id)

        logging.info(f"Launch app: {appId}")

        try:
            await atv.apps.launch_app(appId)
            resp.media = {"status":"App successfully launched!"}
        except Exception as e:
            logging.exception("App failed to launch")
            resp.media = {"status":"App failed to launch"}

    async def on_post_stream(self,req,resp):
        data = await req.media
        id = data["id"]
        url = data["url"]
        atv = self.get_atv(id)

        logging.info(f"Launch stream: {url}")

        try:
            await atv.stream.play_url(url)
            resp.media = {"status":"Stream successfully started!"}
        except Exception as e:
            logging.exception("Stream failed to start")
            resp.media = {"status":"Stream failed to start"}

    async def on_get_info(self,req,resp,id):
        atv = self.get_atv(id)
        if atv:
            data = await self.parse_metadata(atv)
            resp.media = data
        else:
            resp.media = self.failed

    async def on_get_disconnect(self,req,resp,id):
        atv = self.get_atv(id)
        atv.close()
        resp.media = self.failed

    async def add_atv(self,atv:pyatv.interface.AppleTV,id):
        logging.info(f"Adding ATV...")
        listener = Listener(atv,id,self.atv_listener_callback)

        atv.listener = listener
        atv.push_updater.listener = listener
        atv.push_updater.start()
        self.atv_list[id] = listener

    async def atv_listener_callback(self,data,atv,id):

        msg = {}
        logging.debug(f"Listener callback: {data}")

        if type(data)==dict:
            msg = data
        else: 
            msg = await self.parse_metadata(atv,data)

        for client in self.ws_clients:
            if id == client["id"]:
                await client["ws"].send_media(msg)

    async def parse_metadata(self,atv:pyatv.interface.AppleTV,data=None):
        metadata = {}

        try:
            metadata = await atv.metadata.playing()
        except:
            logging.error(f"Returning failed connection to WS")
            return self.failed
            
        art = await atv.metadata.artwork()
        art_id = atv.metadata.artwork_id

        if art_id:
            try:
                art_id = art_id.format(w=512,h=512)
            except:
                pass

        media = {
            "album": metadata.album,
            "artist": metadata.artist,
            "title": metadata.title,
            "genre": metadata.genre,
            "position": metadata.position,
            "total_time": metadata.total_time,
            "shuffle": metadata.shuffle.name,
            "repeat": metadata.repeat.name,
            "content_identifier": metadata.content_identifier,
            "series_name": metadata.series_name,
            "season_number": metadata.season_number,
            "episode_number": metadata.episode_number,
            "hash": metadata.hash,
            "media_type": metadata.media_type.name,
            "state": metadata.device_state.name,
            "artwork": True if art else False,
            "artwork_id": art_id
        }
        app = self.get_app(atv.metadata.app)

        features = self.get_features(atv)

        state = {
            "media": media,
            "app": app,
            "features": features,
        }

        #logging.info(f"ATV State:\n{json.dumps(state,indent=2)}")

        return state

    def get_features(self,atv):
        feature_list = {}
        features = atv.features.all_features()
        
        for feature,info in features.items():
            name = feature.name
            state = info.state.name
            feature_list[name] = state

        return feature_list

    def get_atv(self,id) -> pyatv.interface.AppleTV:
        listener = self.atv_list.get(id)
        if listener:
            atv = listener.atv
            return atv
        else:
            return None

    def get_app(self,app):

        if not app:
            a = {
                "name": None,
                "id": None,
                "icon": None
            }
            return a

        a = {}
        appId = app.identifier

        if appId in APPLE_BUNDLES:
            #logging.info(f"Found {appId}: {APPLE_BUNDLES[appId]['id']}")
            newId = APPLE_BUNDLES[appId].get("id") or app.identifier
            a = {
                "name": APPLE_BUNDLES[appId].get("name") or app.name,
                "id": app.identifier, #APPLE_BUNDLES[appId].get("id") want to return original id for launching purposes
            }
            a["icon"] = self.get_icon(newId)
        else:
            a = {
                "name": app.name,
                "id": app.identifier,
                "icon": self.get_icon(app.identifier)
            }
        return a

    def get_icon(self,id):

        icon_cache_path = "app_icon_store.json"
        icon_cache_file = None
        icon_cache = {}

        if not os.path.exists(icon_cache_path):
            icon_cache_file = open(icon_cache_path,"w")
        else:
            icon_cache_file = open(icon_cache_path,"r")
            try:
                icon_cache = json.load(icon_cache_file)
            except:
                logging.error(f"Failed to load JSON file. Will rebuild.")
                icon_cache = {}
            icon_cache_file = open(icon_cache_path,"w")

        icon = icon_cache.get(id)

        if not icon:
            logging.info(f"Getting app icon for {id}")
            
            try:
                url = f"http://itunes.apple.com/lookup?bundleId={id}"
                resp = requests.get(url,timeout=0.3)
                data = resp.json()

                if data["resultCount"] > 0:
                    icon = data["results"][0]["artworkUrl512"]
                    icon_cache[id] = icon
                else:
                    icon = None
            except:
                logging.warning(f"Failed to get icon. Is the internet reachable?")
                icon = None
            
        icon_cache_file.write(json.dumps(icon_cache,indent=2))
        icon_cache_file.close()

        return icon


"""
SERVER SETUP
"""

app = falcon.asgi.App()
pyatv_atv = ATV()
pyatv_app = PYATV(pyatv_atv)

app.add_route("/scan",pyatv_app,suffix="scan")
app.add_route("/pair",pyatv_app,suffix="pair")
app.add_route("/connect",pyatv_app,suffix="connect")
app.add_route("/disconnect/{id}",pyatv_atv,suffix="disconnect")
app.add_route("/features/{id}",pyatv_atv,suffix="features")
app.add_route("/remote",pyatv_atv,suffix="remote")
app.add_route("/keyboard",pyatv_atv,suffix="keyboard")
app.add_route("/artwork/{id}/art.png",pyatv_atv,suffix="artwork")
app.add_route("/users/{id}",pyatv_atv,suffix="users")
app.add_route("/apps/{id}",pyatv_atv,suffix="apps")
app.add_route("/app_launch",pyatv_atv,suffix="app_launch") # Migrate to /apps?
app.add_route("/stream",pyatv_atv,suffix="stream")
app.add_route("/info/{id}",pyatv_atv,suffix="info")
app.add_route("/ws/{id}",pyatv_atv,suffix="ws")

async def main():
    config = uvicorn.Config("pyatv-webserver:app",host="0.0.0.0", port=8080, log_level="info")
    server = uvicorn.Server(config)
    await server.serve()

if __name__ == "__main__":
    asyncio.run(main())
