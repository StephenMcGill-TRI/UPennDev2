/*
Author: Daniel D. Lee <ddlee@seas.upenn.edu>, 05/10
: Stephen McGill 10/10
: Yida Zhang 05/13
*/

#define LUA_COMPAT_MODULE
#include <lauxlib.h>
#include <lua.h>
#include <lualib.h>

#include <poll.h>
#include <stdint.h>
#include <stdio.h>
#include <sys/time.h>

#include "v4l2.h"

/* metatable name for V4L2 */
#define MT_NAME "v4l2_mt"

static v4l2_device *lua_checkv4l2(lua_State *L, int narg) {
  void *ud = luaL_checkudata(L, narg, MT_NAME);
  luaL_argcheck(L, ud != NULL, narg, "Invalid V$L2 userdata");
  return (v4l2_device *)ud;
}

static int lua_v4l2_index(lua_State *L) {
  if (!lua_getmetatable(L, 1)) {
    /* push metatable */
    lua_pop(L, 1);
    return 0;
  }
  lua_pushvalue(L, 2); /* copy key */
  lua_rawget(L, -2);   /* get metatable function */
  lua_remove(L, -2);   /* delete metatable */
  return 1;
}

static int lua_v4l2_delete(lua_State *L) {
  v4l2_device *ud = lua_checkv4l2(L, 1);
  if (ud->init) {
    v4l2_stream_off(ud);
    ud->init = 0;
  }
  if (v4l2_close(ud) != 0) {
    luaL_error(L, "Closing video device Error");
  }
  return 0;
}

static int lua_v4l2_init(lua_State *L) {
  const char *video_device = luaL_optstring(L, 1, "/dev/video0");
  v4l2_device *ud = (v4l2_device *)lua_newuserdata(L, sizeof(v4l2_device));
  ud->width = luaL_optint(L, 2, 320);
  ud->height = luaL_optint(L, 3, 240);
  ud->pixelformat = luaL_optstring(L, 4, "yuyv");
  /* default 15 fps */
  ud->fps_num = luaL_optint(L, 5, 1);
  ud->fps_denum = luaL_optint(L, 6, 15);

  ud->init = 0;
  ud->count = 0;
  ud->ctrl_map = NULL;
  ud->menu_map = NULL;
  ud->buf_len = NULL;
  ud->buffer = NULL;

  ud->fd = v4l2_open(video_device);
  if (ud->fd < 0) {
    // luaL_error(L, "Could not open video device");
    lua_pushboolean(L, 0);
    lua_pushliteral(L, "Could not open device");
    return 2;
  }
  if (v4l2_init(ud) < 0) {
    lua_pushboolean(L, 0);
    lua_pushliteral(L, "Bad initialization");
    return 2;
  }

  luaL_getmetatable(L, MT_NAME);
  lua_setmetatable(L, -2);
  return 1;
}

static int lua_v4l2_stream_on(lua_State *L) {
  v4l2_device *ud = lua_checkv4l2(L, 1);
  if (ud->init) {
    lua_pushboolean(L, 0);
    lua_pushliteral(L, "Already stream_on");
    return 2;
  }
  if (v4l2_stream_on(ud) < 0) {
    lua_pushboolean(L, 0);
    lua_pushliteral(L, "Bad stream_on");
    return 2;
  }
  ud->init = 1;
  lua_pushboolean(L, 1);
  return 1;
}

static int lua_v4l2_stream_off(lua_State *L) {
  v4l2_device *ud = lua_checkv4l2(L, 1);
  if (!ud->init) {
    lua_pushboolean(L, 0);
    lua_pushliteral(L, "Already stream_off");
    return 2;
  }
  if (v4l2_stream_off(ud) < 0) {
    lua_pushboolean(L, 0);
    lua_pushliteral(L, "Bad stream_off");
    return 2;
  }
  ud->init = 0;
  lua_pushboolean(L, 0);
  return 1;
}

static int lua_v4l2_fd(lua_State *L) {
  v4l2_device *ud = lua_checkv4l2(L, 1);
  if (ud->fd > 0) {
    lua_pushinteger(L, ud->fd);
    return 1;
  }
  return 0;
}

static int lua_v4l2_get_width(lua_State *L) {
  v4l2_device *ud = lua_checkv4l2(L, 1);
  if (ud->init) {
    lua_pushinteger(L, ud->width);
  } else {
    return 0;
  }
  return 1;
}

static int lua_v4l2_get_height(lua_State *L) {
  v4l2_device *ud = lua_checkv4l2(L, 1);
  if (ud->init) {
    lua_pushinteger(L, ud->height);
  } else {
    return 0;
  }
  return 1;
}

static int lua_v4l2_set_param(lua_State *L) {
  v4l2_device *ud = lua_checkv4l2(L, 1);
  const char *param = luaL_checkstring(L, 2);
  int value = luaL_checkinteger(L, 3);

  int ret = v4l2_set_ctrl(ud, param, value);
  if (ret == -1) {
    return 0;
  } else {
    lua_pushinteger(L, ret);
    return 1;
  }
}

static int lua_v4l2_get_param(lua_State *L) {
  v4l2_device *ud = lua_checkv4l2(L, 1);
  const char *param = luaL_checkstring(L, 2);
  int value;
  int ret = v4l2_get_ctrl(ud, param, &value);
  if (ret == -1) {
    return 0;
  } else {
    lua_pushinteger(L, value);
    return 1;
  }
}

static int lua_v4l2_get_raw(lua_State *L) {
  v4l2_device *ud = lua_checkv4l2(L, 1);
  int timeout = luaL_optint(L, 2, 0);
  if (timeout != 0) {
    struct pollfd pfd;
    pfd.fd = ud->fd;
    pfd.events = POLLIN;
    pfd.revents = 0;
    if (poll(&pfd, 1, timeout) < 0) {
      lua_pushboolean(L, 0);
      lua_pushliteral(L, "Bad poll");
      return 2;
    }
  }

  int buf_num = v4l2_read_frame(ud);
  if (buf_num < 0) {
    // TODO: perror?
    lua_pushboolean(L, 0);
    lua_pushliteral(L, "Bad frame grab.");
    return 2;
  }

  // Can give the string or the raw buffer
  if (lua_toboolean(L, 3)) {
    lua_pushlstring(L, ud->buffer[buf_num], ud->buf_used[buf_num]);
  } else {
    lua_pushlightuserdata(L, ud->buffer[buf_num]);
  }
  lua_pushinteger(L, ud->buf_used[buf_num]);
  return 2;
}

static int lua_v4l2_reset_resolution(lua_State *L) {
  v4l2_device *ud = lua_checkv4l2(L, 1);
  ud->width = luaL_checkinteger(L, 2);
  ud->height = luaL_checkinteger(L, 3);
  ud->pixelformat = luaL_optstring(L, 4, "yuyv");

  v4l2_stream_off(ud);
  v4l2_uninit_mmap(ud);
  v4l2_close_query(ud);

  /* TODO: already init'd, so this cannot work
     should be an ioctl */
  v4l2_init(ud);
  v4l2_stream_on(ud);
  return 1;
}

static const struct luaL_Reg v4l2_functions[] = {{"init", lua_v4l2_init},
                                                 {NULL, NULL}};

static const struct luaL_Reg v4l2_methods[] = {
    {"descriptor", lua_v4l2_fd},
    {"close", lua_v4l2_delete},
    {"get_width", lua_v4l2_get_width},
    {"get_height", lua_v4l2_get_height},
    {"reset", lua_v4l2_reset_resolution},
    {"set_param", lua_v4l2_set_param},
    {"get_param", lua_v4l2_get_param},
    {"get_image", lua_v4l2_get_raw},
    {"stream_on", lua_v4l2_stream_on},
    {"stream_off", lua_v4l2_stream_off},
    {"__index", lua_v4l2_index},
    {"__gc", lua_v4l2_delete},
    {NULL, NULL}};

#ifdef __cplusplus
extern "C"
#endif
    int
    luaopen_v4l2(lua_State *L) {
  /* create metatable for v4l2 module */
  luaL_newmetatable(L, MT_NAME);
#if LUA_VERSION_NUM == 501
  luaL_register(L, NULL, v4l2_methods);
#else
  luaL_setfuncs(L, v4l2_methods, 0);
#endif
  lua_pop(L, 1);

#if LUA_VERSION_NUM == 501
  luaL_register(L, "v4l2", v4l2_functions);
#else
  luaL_newlib(L, v4l2_functions);
#endif

  return 1;
}
