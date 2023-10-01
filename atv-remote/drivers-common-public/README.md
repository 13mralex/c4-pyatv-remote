# Common Libraries for Control4 development

This repository contains a number of Control4-developed libraries to provide specific functionality on top of that built-in to Driverworks.

## Functionality

Lua files in the `global` directory import all their functions into the `_G` global namespace without any additional statements needed.  They can be used with a simple `require` statement: `require ('drivers-common-public.global.lib')` will import all the functions from the `lib.lua` file into the global namespace.

Lua files in the `module` directory create an object that can only be accessed by being assigned to a variable.

### Globals

- `handlers.lua` : Defines handler functions for all built-in incoming Driverworks functions to allow for easier specific handling of network connections, proxy/command requests and so on.
- `lib.lua` : Simple helper functions used in many drivers.
- `make_short_link.lua` : Makes short links on the link.ctrl4.co or link.control4dev.com URLs.  Requires an API key for use: contact your Control4 representative for more details.
- `msp.lua` : Manages many of the key features of all Control4 native-audio MSP drivers.  Also contains many helper functions for dealing with Navigators in MSP.
- `timer.lua` : Helper library to manage all things timer related in Driverworks.
- `url.lua` : Abstracts out much of the necessary callback functionality to use asynchronous URL requests in Driverworks.

### Modules

- `auth_code_grant.lua` : Setup an OAuth 2 connection using the Authorization Code Grant flow.  Requires an API key to use : contact your Control4 representative for more details.
- `auth_device_PIN.lua` : Setup an OAuth 2 connection using the PIN Grant flow.  Requires an API key to use : contact your Control4 representative for more details.
- `json.lua` : Pure Lua implementation of a JSON parser for encode/decode.  Copyright 2010-2017 Jeffrey Friedl, see LICENSE.md for details.
- `ssdp.lua` : Implements SSDP discovery in pure Driverworks.  Does not register a listening server.
- `websocket.lua` : Implements a websocket client in pure Driverworks.
