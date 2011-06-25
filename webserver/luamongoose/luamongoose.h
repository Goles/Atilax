//
//  luamongoose.h
//  lalo
//
//  Created by Nicolas Goles on 6/20/11.
//  Copyright 2011 GandoGames. All rights reserved.
//

#ifndef __IOS_LUA_MONGOOSE_H__
#define __IOS_LUA_MONGOOSE_H__

#include "lua.h"
#include "file_utils.h"

/**
 Exposes a Lua enabled mongoose web server to a Lua Context.
 
 After calling this function you can instanciate a web server from a Lua script like this:
 
 -- Lua Code
 local ctx = mg.start{}
 */
int luaopen_mongoose(lua_State *L);

/**
 Redefines Lua dofile function in order for it to use the iOS Application root folder as it's
 absolute path.
 
 eg:
 MyIOSApp.app/test.lua
 
 -- Lua Code
 dofile("test.lua") -- Will Execute test.lua
 
 eg 2:
 MyIOSApp.app/scripts/test.lua -- Note that scripts is a folder, not an Xcode Group!
 
 -- Lua Code
 dofile("scripts/test.lua")
 */           

static inline void redefine_lua_dofile(lua_State* L)
{    
    const char *root_path = relativeCPathForFile(".");    
    
    size_t needed = snprintf(NULL, 0, "do local oldDoFile = dofile; dofile = function (file_name); return oldDoFile( \"%s\" .. '/' .. file_name) end; end;", root_path);
    char  *buffer = malloc(needed + 1);
    snprintf(buffer, needed + 1, "do local oldDoFile = dofile; dofile = function (file_name) return oldDoFile( \"%s\" .. '/' .. file_name) end end", root_path);
    
    if(luaL_dostring(L, buffer))
    {
        printf("%s\n", lua_tostring(L, -1));
    }
    
    free(buffer);
}


#endif
