// Copyright (c) 2010 Judge Maygarden
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "lauxlib.h"
#include "lua.h"
#include "lualib.h"

#include "mongoose.h"
#include "luamongoose.h"

#ifdef UNUSED 
#elif defined(__GNUC__) 
# define UNUSED(x) UNUSED_ ## x __attribute__((unused)) 
#elif defined(__LCLINT__) 
# define UNUSED(x) /*@unused@*/ x 
#else 
# define UNUSED(x) x 
#endif

#define MARK()  do { \
    printf("%s:%d (%s)\n", __FILE__, __LINE__, __FUNCTION__); \
} while (0)

typedef struct LuaMgContext LuaMgContext;
typedef struct LuaCallback LuaCallback;

struct LuaCallback {
    char *buf;
    size_t len;
    const char *name;
};

struct LuaMgContext {
    lua_State *L;
    struct mg_context *ctx;
    int ref;
    LuaCallback user_callback;
};

static const char MODULE_NAME[] = "mg";
static const char CONNECTION_METETABLE[] = "mg_connection";
static const char CONTEXT_METATABLE[] = "mg_context";

static int
lua_mg_context_gc(lua_State *L)
{
    LuaMgContext *lctx = luaL_checkudata(L, 1, CONTEXT_METATABLE);

    mg_stop(lctx->ctx);

    return 0;
}

static int
lua_mg_context_stop(lua_State *L)
{
    LuaMgContext *lctx = luaL_checkudata(L, 1, CONTEXT_METATABLE);

    luaL_unref(L, LUA_REGISTRYINDEX, lctx->ref);
    lua_gc(L, LUA_GCCOLLECT, 0);

    return 0;
}

static int
lua_mg_connection_print(lua_State *L)
{
    struct mg_connection *conn = *(struct mg_connection **)
                                 luaL_checkudata(L, lua_upvalueindex(1),
                                                 CONNECTION_METETABLE);
    const void *buf;
    size_t len;
    int i, j;

    j = lua_gettop(L);
    for (i = 1; i <= j; ++i) {
        buf = luaL_checklstring(L, i, &len);
        mg_write(conn, buf, len);
    }

    return 0;
}

static int
lua_mg_connection_execute_cgi(lua_State *L)
{
    struct mg_connection *conn = *(struct mg_connection **)
                                 luaL_checkudata(L, lua_upvalueindex(1),
                                                 CONNECTION_METETABLE);
    const char *prog = luaL_checkstring(L, 1);
    
    mg_execute_cgi(conn, prog);

    return 0;
}

// pushes a connection object onto the stack
static void
push_connection(lua_State *L, struct mg_connection *conn)
{
    *(struct mg_connection **)
        lua_newuserdata(L, sizeof (struct mg_connection *)) = conn;

    luaL_getmetatable(L, CONNECTION_METETABLE);
    lua_setmetatable(L, -2);
}

// pushes request info on the Lua stack as a table
static void
push_request(lua_State *L, const struct mg_request_info *ri)
{
    int i;

    lua_createtable(L, 0, 14);
    lua_pushstring(L, ri->request_method);
    lua_setfield(L, -2, "request_method");
    lua_pushstring(L, ri->uri);
    lua_setfield(L, -2, "uri");
    lua_pushstring(L, ri->http_version);
    lua_setfield(L, -2, "http_version");
    lua_pushstring(L, ri->query_string);
    lua_setfield(L, -2, "query_string");
    lua_pushstring(L, ri->remote_user);
    lua_setfield(L, -2, "remote_user");
    lua_pushstring(L, ri->log_message);
    lua_setfield(L, -2, "log_message");
    lua_pushinteger(L, ri->remote_ip);
    lua_setfield(L, -2, "remote_ip");
    lua_pushinteger(L, ri->remote_port);
    lua_setfield(L, -2, "remote_port");
    lua_pushinteger(L, ri->status_code);
    lua_setfield(L, -2, "status_code");
    lua_pushboolean(L, ri->is_ssl);
    lua_setfield(L, -2, "is_ssl");

    lua_createtable(L, 0, ri->num_headers);
    for (i = 0; i < ri->num_headers; ++i) {
        lua_pushstring(L, ri->http_headers[i].value);
        lua_setfield(L, -2, ri->http_headers[i].name);
    }
    lua_setfield(L, -2, "http_headers");
}

// dispatches a callback to a Lua function if one is registered
static void *
user_callback_proxy(enum mg_event event,
                    struct mg_connection *conn,
                    const struct mg_request_info *ri)
{
    LuaMgContext *lctx;
    LuaCallback *dump;
    lua_State *L;
    int e;

    lctx = (LuaMgContext *) ri->user_data;
    dump = &lctx->user_callback;

    if (dump->buf) {
        L = luaL_newstate();
        luaL_openlibs(L);
        luaL_newmetatable(L, CONNECTION_METETABLE);
        push_connection(L, conn);
        lua_pushvalue(L, -1);
        lua_pushcclosure(L, lua_mg_connection_print, 1);
        lua_setglobal(L, "print");
        redefine_lua_dofile(L);

        luaL_loadbuffer(L, dump->buf, dump->len, dump->name);
        switch (event) {
        case MG_NEW_REQUEST:    lua_pushstring(L, "MG_NEW_REQUEST");    break;
        case MG_HTTP_ERROR:     lua_pushstring(L, "MG_HTTP_ERROR");     break;
        case MG_EVENT_LOG:      lua_pushstring(L, "MG_EVENT_LOG");      break;
        case MG_INIT_SSL:       lua_pushstring(L, "MG_INIT_SSL");       break;
        default:                lua_pushnil(L);                         break;
        }
        push_request(L, ri);
        lua_call(L, 2, 1);
        e = lua_toboolean(L, -1) ? 1 : 0;
        lua_close(L);
        return (void *) e;
    }

    return NULL;
}

// helper function to extract a single mg_config value from a Lua table
static void
fetchfield(lua_State *L, const char *key, char **value, const char *d)
{
    const char *s;

    lua_getfield(L, 1, key);
    s = luaL_optstring(L, -1, d);
    *value = s ? mg_strdup(s) : NULL;
    lua_pop(L, 1);
}

// initializes an options string array from a Lua table
static void
fetchoptions(lua_State *L, const char **options)
{
    struct {
        const char *key;
        const char *value;
    } OPTIONS[] = {
        { "cgi_extensions", ".cgi,.pl,.php" },
        { "cgi_environment", NULL },
        { "put_delete_passwords_file", NULL },
        { "cgi_interpreter", NULL },
        { "protect_uri", NULL },
        { "authentication_domain", "mydomain.com" },
        { "ssi_extensions", ".shtml,.shtm" },
        { "access_log_file", NULL },
        { "ssl_chain_file", NULL },
        { "enable_directory_listing", "yes" },
        { "error_log_file", NULL },
        { "global_passwords_file", NULL },
        { "index_files", "index.html,index.htm,index.cgi" },
        { "enable_keep_alive", "no" },
        { "access_control_list", NULL },
        { "max_request_size", "16384" },
        { "extra_mime_types", NULL },
        { "listening_ports", "8080" },
        { "document_root",  "." },
        { "ssl_certificate", NULL },
        { "num_threads", "10" },
        { "run_as_user", NULL },
        { NULL, NULL }
    };
    char *value;
    int i, j;

    luaL_checktype(L, 1, LUA_TTABLE);

    for (i = 0, j = 0; OPTIONS[i].key; ++i) {
        fetchfield(L, OPTIONS[i].key, &value, OPTIONS[i].value);
        if (NULL != value) {
            options[j++] = mg_strdup(OPTIONS[i].key);
            options[j++] = value;
        }
    }
    options[j] = NULL;
}

// callback for storing Lua callback functions as binary strings
static int
dumpwriter(lua_State * UNUSED(L), const void *p, size_t sz, void *ud)
{
    LuaCallback *dump = ud;

#if defined(_MSC_VER)
    L;
#endif // _MSC_VER

    dump->buf = realloc(dump->buf, dump->len + sz);
    if (NULL == dump->buf)
        return 1;

    memcpy(dump->buf + dump->len, p, sz);
    dump->len += sz;

    return 0;
}

// creates a reference dispatching callbacks to Lua functions
static void
fetchcallback(lua_State *L, const char *key, LuaCallback *dump)
{
    luaL_checktype(L, 1, LUA_TTABLE);
    lua_getfield(L, 1, key);

    dump->buf = NULL;
    dump->len = 0;
    dump->name = key;

    if (lua_isfunction(L, -1))
        lua_dump(L, dumpwriter, dump);

    lua_pop(L, 1);
}

// creates a new server using a configuration table
static int
lua_mg_start(lua_State *L)
{
    LuaMgContext *lctx;
    const char *options[64];
    int i;
   
    // create a new Lua Mongoose context
    lctx = lua_newuserdata(L, sizeof (LuaMgContext));
    luaL_getmetatable(L, CONTEXT_METATABLE);
    lua_setmetatable(L, -2);

    // store a reference to the context so it doesn't get garbage collected
    lua_pushvalue(L, -1);
    lctx->ref = luaL_ref(L, LUA_REGISTRYINDEX);

    // store the Lua state for use in callback proxies
    lctx->L = L;

    // prepare the mg_config structure from the Lua table argument
    memset(options, 0, sizeof (options));
    fetchoptions(L, options);
    fetchcallback(L, "user_callback", &lctx->user_callback);

    lctx->ctx = mg_start(user_callback_proxy, lctx, options);

    // throw an error if the server did not start
    if (NULL == lctx->ctx) {
        lua_pushnil(L);
        lua_error(L);
    }

    // free the options string list memory
    for (i = 0; options[i]; ++i)
        free((void *) options[i]);

    // return the context so it can be stopped later
    return 1;
}

static const luaL_reg contextMethods[] = {
    { "__gc", lua_mg_context_gc },
    { "stop", lua_mg_context_stop },
    { NULL, NULL }
};

static const luaL_reg moduleFunctions[] = {
    { "start", lua_mg_start },
    { "stop", lua_mg_context_stop },
    { NULL, NULL }
};

int
luaopen_mongoose(lua_State *L)
{
    luaL_newmetatable(L, CONTEXT_METATABLE);
    lua_pushvalue(L, -1);
    luaL_register(L, NULL, contextMethods);
    lua_setfield(L, -2, "__index");

    luaL_register(L, MODULE_NAME, moduleFunctions);
    lua_pushvalue(L, -1);
    lua_setglobal(L, MODULE_NAME);

    return 1;
}

