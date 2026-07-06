// Nexus: inline wrappers for Lua C-API macros so they're callable from Swift.
#ifndef NEXUS_LUA_SHIMS_H
#define NEXUS_LUA_SHIMS_H
#include "lua.h"
#include "lauxlib.h"

static inline int nx_pcall(lua_State *L, int nargs, int nresults) {
    return lua_pcallk(L, nargs, nresults, 0, 0, NULL);
}
static inline int nx_loadfile(lua_State *L, const char *filename) {
    return luaL_loadfilex(L, filename, NULL);
}
static inline const char *nx_tostring(lua_State *L, int idx) {
    return lua_tolstring(L, idx, NULL);
}
static inline double nx_tonumber(lua_State *L, int idx) {
    return (double) lua_tonumberx(L, idx, NULL);
}
static inline void nx_pop(lua_State *L, int n) {
    lua_settop(L, -(n)-1);
}
static inline int nx_dostring(lua_State *L, const char *s) {
    return luaL_loadstring(L, s) || lua_pcallk(L, 0, LUA_MULTRET, 0, 0, NULL);
}
#endif
