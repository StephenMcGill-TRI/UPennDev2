/*
  Lua module to set termios characteristics
*/

#include <lauxlib.h>
#include <lua.h>
#include <lualib.h>

#include <stdio.h>
#include <string.h>

#include <errno.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <termios.h>
#include <unistd.h>

#ifdef __APPLE__
#include <IOKit/serial/ioss.h>
#else
#include <linux/serial.h>
#endif

// static int pushresult (lua_State *L, int i, const char *name) {
//   int en = errno;
//   if (i) {
//     lua_pushboolean(L, 1);
//     return 1;
//   } else {
//     lua_pushnil(L);
//     if (name){
//       lua_pushfstring(L, "%s:%s", name, strerror(en));
//     }
//     else{
//       lua_pushfstring(L, "%s", strerror(en));
//     }
//     lua_pushinteger(L, en);
//     lua_pushinteger(L, i);
//     return 4;
//   }
// }

int lua_tofd(lua_State *L, int narg) {
  int ftype = lua_type(L, narg);
  FILE **fp;
  switch (ftype) {
  case LUA_TNUMBER:
    return luaL_checkinteger(L, narg);
  case LUA_TUSERDATA:
    fp = (FILE **)luaL_checkudata(L, narg, LUA_FILEHANDLE);
    if (*fp != NULL) {
      return fileno(*fp);
    }
    break;
  }
  return -1;
}

static int lua_stty_raw(lua_State *L) {
  int fd = lua_tofd(L, 1);

  struct termios tio;
  if (tcgetattr(fd, &tio) != 0) {
    return luaL_error(L, "Could not get termios");
  }
  cfmakeraw(&tio);

  if (tcsetattr(fd, TCSANOW, &tio) != 0) {
    return luaL_error(L, "Could not set termios");
  }
  return 0;

  // int ret = tcsetattr(fd, TCSANOW, &tio);
  // return pushresult(L, ret, NULL);
}

static int lua_stty_sane(lua_State *L) {
  int fd = lua_tofd(L, 1);

  struct termios tio;
  bzero(&tio, sizeof(tio));
  tio.c_cflag = CS8 | CREAD | HUPCL;
  tio.c_iflag = ICRNL | IXON | IXANY | IMAXBEL | BRKINT;
  tio.c_oflag = OPOST | ONLCR;
  tio.c_lflag = ICANON | ISIG | IEXTEN | ECHO | ECHOE | ECHOKE | ECHOCTL;
  tio.c_cc[VEOF] = 4;  // ctrl-d
  tio.c_cc[VINTR] = 3; // ctrl-c
  tio.c_cc[VMIN] = 1;  // Min number of characters
  tio.c_cc[VTIME] = 0; // TIME*0.1s

  cfsetispeed(&tio, B9600);
  cfsetospeed(&tio, B9600);

  if (tcsetattr(fd, TCSANOW, &tio) != 0) {
    return luaL_error(L, "Could not set termios");
  }

  return 0;
}

static int lua_stty_serial(lua_State *L) {
  int fd = lua_tofd(L, 1);

  struct termios tio;
  if (tcgetattr(fd, &tio) != 0) {
    return luaL_error(L, "Could not get termios attributes");
  }

  // 8N1
  // http://www.comptechdoc.org/os/linux/programming/c/linux_pgcserial.html
  // http://tldp.org/HOWTO/Serial-Programming-HOWTO/x115.html
  tio.c_cflag = B57600 | CS8 | CLOCAL | CREAD;
  tio.c_iflag = IGNPAR;
  tio.c_oflag = 0;
  tio.c_iflag = 0;
  tio.c_cc[VTIME] = 0;
  tio.c_cc[VMIN] = 0;
  // Try adding this...
  tio.c_lflag = 0;

  /*
     if (cfsetspeed(&tio, B57600) != 0) {
     return luaL_error(L, "Could not set speed");
     }
   */

  if (tcflush(fd, TCIFLUSH) != 0) {
    return luaL_error(L, "Could not flush termios");
  } else if (tcsetattr(fd, TCSANOW, &tio) != 0) {
    return luaL_error(L, "Could not set termios");
  }

  return 0;
}

static int lua_stty_speed(lua_State *L) {
  int fd = lua_tofd(L, 1);
  speed_t speed = luaL_checkinteger(L, 2);

#ifdef __APPLE__
  if (ioctl(fd, IOSSIOSPEED, &speed) == -1) {
    // fprintf( stdout, "Error %d calling ioctl. %d\n", errno, speed);
    // fflush(stdout);
    return luaL_error(L, "Could not set apple speed.");
  }
#else
  // Default termios interface
  struct termios tio;
  if (tcgetattr(fd, &tio) != 0) {
    return luaL_error(L, "Could not get termios");
  }
  if (cfsetspeed(&tio, speed) != 0) {
    // Try a custom divisor
    struct serial_struct serinfo;
    if (ioctl(fd, TIOCGSERIAL, &serinfo) != 0) {
      return luaL_error(L, "Could not get serial info for custom divisor.");
    }
    serinfo.flags &= ~ASYNC_SPD_MASK;
    serinfo.flags |= ASYNC_SPD_CUST;
    serinfo.flags |= ASYNC_LOW_LATENCY; // ftdi latency

    serinfo.custom_divisor = serinfo.baud_base / ((float)speed);
    fprintf(stdout, "CUST | BASE: %d, DIVISOR: %d\n", serinfo.baud_base,
            serinfo.custom_divisor);
    if (ioctl(fd, TIOCSSERIAL, &serinfo) < 0) {
      fprintf(stdout, "BAD STTY: %d\n", errno);
      return luaL_error(L, "Could not set termios speed");
    }
  }
  if (tcsetattr(fd, TCSANOW, &tio) != 0) {
    return luaL_error(L, "Could not set termios");
  }

/*
// robotis code
//
http://stackoverflow.com/questions/4968529/how-to-set-baud-rate-to-307200-on-linux
ss.custom_divisor = (ss.baud_base + (speed / 2)) / speed;
int closest_speed = ss.baud_base / ss.custom_divisor;

if(closest_speed < speed * 98 / 100 || closest_speed > speed * 102 / 100)
{
  if(DEBUG_PRINT == true)
    printf(" Cannot set speed to %d, closest is %d \n", speed, closest_speed);
  return false;
}

if(ioctl(SocketFD, TIOCSSERIAL, &ss) < 0)
{
  if(DEBUG_PRINT == true)
    printf(" TIOCSSERIAL failed!\n");
  return false;
}
*/
#endif

  return 0;
}

static int lua_stty_min(lua_State *L) {
  int fd = lua_tofd(L, 1);
  int min = luaL_checkinteger(L, 2);

  struct termios tio;
  if (tcgetattr(fd, &tio) != 0) {
    return luaL_error(L, "Could not get termios");
  }

  tio.c_cc[VMIN] = min; // Min number of characters

  if (tcsetattr(fd, TCSANOW, &tio) != 0) {
    return luaL_error(L, "Could not set termios");
  }
  return 0;
}

static int lua_stty_time(lua_State *L) {
  int fd = lua_tofd(L, 1);
  int time = luaL_checkinteger(L, 2);

  struct termios tio;
  if (tcgetattr(fd, &tio) != 0) {
    return luaL_error(L, "Could not get termios");
  }

  tio.c_cc[VTIME] = time; // Max time in 0.1 sec

  if (tcsetattr(fd, TCSANOW, &tio) != 0) {
    return luaL_error(L, "Could not set termios");
  }
  return 0;
}

static int lua_stty_echo(lua_State *L) {
  int fd = lua_tofd(L, 1);
  int flag = lua_toboolean(L, 2);

  struct termios tio;
  if (tcgetattr(fd, &tio) != 0) {
    return luaL_error(L, "Could not get termios");
  }

  if (flag) {
    tio.c_lflag |= ECHO;
  } else {
    tio.c_lflag &= ~ECHO;
  }

  if (tcsetattr(fd, TCSANOW, &tio) != 0) {
    return luaL_error(L, "Could not set termios");
  }
  return 0;
}

static int lua_stty_clocal(lua_State *L) {
  int fd = lua_tofd(L, 1);
  int flag = lua_toboolean(L, 2);

  struct termios tio;
  if (tcgetattr(fd, &tio) != 0) {
    return luaL_error(L, "Could not get termios");
  }

  if (flag) {
    tio.c_cflag |= CLOCAL;
  } else {
    tio.c_cflag &= ~CLOCAL;
  }

  if (tcsetattr(fd, TCSANOW, &tio) != 0) {
    return luaL_error(L, "Could not set termios");
  }
  return 0;
}

// just flush the output
static int lua_stty_flush(lua_State *L) {
  int fd = lua_tofd(L, 1);
  lua_pushinteger(L, tcflush(fd, TCIOFLUSH));
  return 1;
}

// wait until the write has finished
static int lua_stty_drain(lua_State *L) {
  int fd = lua_tofd(L, 1);
  lua_pushinteger(L, tcdrain(fd));
  return 1;
}

static const struct luaL_Reg stty_lib[] = {{"raw", lua_stty_raw},
                                           {"sane", lua_stty_sane},
                                           {"serial", lua_stty_serial},
                                           {"speed", lua_stty_speed},
                                           {"min", lua_stty_min},
                                           {"time", lua_stty_time},
                                           {"echo", lua_stty_echo},
                                           {"clocal", lua_stty_clocal},
                                           {"flush", lua_stty_flush},
                                           {"drain", lua_stty_drain},
                                           {NULL, NULL}};

#ifdef __cplusplus
extern "C"
#endif
    int
    luaopen_stty(lua_State *L) {
#if LUA_VERSION_NUM == 501
  luaL_register(L, "stty", stty_lib);
#else
  luaL_newlib(L, stty_lib);
#endif
  return 1;
}
