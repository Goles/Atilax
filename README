## Motivation! ##

I've been wanting a web server that has lua support and can be run on my iPhone. This is great if you want to debug Games or other sort of apps with Lua support. You could display and modify your lua tables in your web browser (you'll have to write that piece of code yourself, because it's not something currently implemented), or you could modify your application behavior from your web browser... etc.

Besides... it's fun! :)

## Installing ##

To install you must copy:
	
	file_utils.h
	luamongoose.h
	luamongoose.m
	mongoose.c
	mongoose.h
	
To your Xcode project

Besides that, you may want to copy:
	
	delegate.lua
	ios_sample.lua
	
To your project Resources group.

## Usage ##

To get the web server running in your iOS App just use this piece of C code:
	
	#include "lua.h"
	#include "luamongoose.h"
	#include "file_utils.h"
	
	lua_State *L = lua_open();
	luaL_openlibs(L);

	/* Expose web server to Lua context */
	luaopen_mongoose(L);

	/* Set the server Root */
	redefine_lua_dofile(L);    

	/* Execute a File in Lua */
	if (luaL_dofile(L, fullCPathFromRelativePath("ios_sample.lua")))
	{
	    printf("%s\n", lua_tostring(L, -1));
	}

## Functions ##

1. mg_print(): Sends text to the receiver's end.
	
	
## Structure ##

In Lua, you can instanciate a mongoose web server by doing:

	mg.start{}
	
Lua mongoose script structure:

	mg.start{
		
		user_callback = function(event, request)
			
	 		local event_handlers = {
				
				['MG_NEW_REQUEST'] = function(request)
					
					-- New Requests handler settings
					local uri_handlers = {
					
					},
					
				end,
				
				['MG_HTTP_ERROR'] = function(request)
				 	
					-- Error handler settings
					local error_handlers = {
					
					},
					
				end,
			}
	}

To add new http handlers for new requests just add a new uri\_handler key to the uri\_handlers table in your lua script.
	
	['MG_NEW_REQUEST'] = function(request)

		-- URL handler settings
		local uri_handlers = {
	
			["/a_handler"] = function(request)
			
				mg_print("<h1>Request Received!</h1>")
				
			end,
	
			["/another_handler"] = function(request)
			
				mg_print("<h1>Another Request Received!</h1>")
				dofile("my_script.lua")
				
			end,
		},
		
	end,

## Notes ##

Take a look at how "ios\_sample.lua" is written, you can access "/deferred\_delegate" in order to actually reload the "delegate.lua" script and then run it with the http request parameters.

		http://localhost:8080/deferred_delegate
		
This means that when running your Application, you could actually run the http server and then start editing a lua script (located in the package contents of the installed app). Then just query the correct URL in order reload the script and watch the changes happen (no recompiling or re-launching the app is necessary).

## To-Do ##

Improve the API to handle web requests.
Maybe include an API to htmlize a Lua table for displaying/editing from the browser.
Cool stuff!...

### Some Credits ###

[Lua Mongoose](http://code.google.com/r/jmaygarden-lua/) is a fork of the Mongoose project. It was made by [Judge Maygarden](https://github.com/jmaygarden) and is under the MIT license ( "Created Lua bindings to Mongoose using hand rolled C code" ).