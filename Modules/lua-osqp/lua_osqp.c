/*
Author: Stephen McGill <stephen.mcgill@tri.global> 2018
*/
#include <lauxlib.h>
#include <lua.h>
#include <lualib.h>

#include <osqp/osqp.h>
#include <osqp/types.h>

#define MT_NAME "osqp_mt"

struct osqp_ud {
  OSQPSettings *settings;
  OSQPData *data;
  OSQPWorkspace *work;
  c_float *P_values;
  c_int *P_indices;
  c_int *P_icol;
  c_float *A_values;
  c_int *A_indices;
  c_int *A_icol;
};

struct osqp_ud *lua_checkosqp(lua_State *L, int narg) {
  void *ud = luaL_checkudata(L, narg, MT_NAME);
  luaL_argcheck(L, ud != NULL, narg, "Invalid osqp userdata");
  return ud;
}

static int lua_osqp_index(lua_State *L) {
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

static int lua_osqp_new(lua_State *L) {
  // Problem settings and structures
  OSQPSettings *settings = (OSQPSettings *)c_malloc(sizeof(OSQPSettings));
  if (!settings) {
    lua_pushboolean(L, 0);
    lua_pushliteral(L, "Bad settings allocation");
    return 2;
  }
  osqp_set_default_settings(settings);

  // Make sure to zero everything here, via c_alloc
  OSQPData *data = (OSQPData *)c_calloc(1, sizeof(OSQPData));
  if (!data) {
    c_free(settings);
    lua_pushboolean(L, 0);
    lua_pushliteral(L, "Bad data allocation");
    return 2;
  }
  OSQPWorkspace *work = NULL;

  // Make accessible to lua
  struct osqp_ud *ud = lua_newuserdata(L, sizeof(struct osqp_ud));
  // Ensure we zero everything for pointer freeing
  bzero(ud, sizeof(struct osqp_ud));
  ud->settings = settings;
  ud->data = data;
  ud->work = work;

  luaL_getmetatable(L, MT_NAME);
  lua_setmetatable(L, -2);
  return 1;
}

static int lua_osqp_free(lua_State *L) {
  struct osqp_ud *ud = lua_checkosqp(L, 1);
#ifdef DEBUG
  fprintf(stderr, "Cleanup [%p]\n", ud->work);
#endif
  osqp_cleanup(ud->work);
#ifdef DEBUG
  fprintf(stderr, "Free P_values [%p]\n", ud->P_values);
#endif
  if (ud->P_values) {
    free(ud->P_values);
  }
#ifdef DEBUG
  fprintf(stderr, "Free P_indices [%p]\n", ud->P_indices);
#endif
  if (ud->P_indices) {
    free(ud->P_indices);
  }
#ifdef DEBUG
  fprintf(stderr, "Free P_icol [%p]\n", ud->P_icol);
#endif
  if (ud->P_icol) {
    free(ud->P_icol);
  }
#ifdef DEBUG
  fprintf(stderr, "Free A_values [%p]\n", ud->A_values);
#endif
  if (ud->A_values) {
    free(ud->A_values);
  }
#ifdef DEBUG
  fprintf(stderr, "Free A_indices [%p]\n", ud->A_indices);
#endif
  if (ud->A_indices) {
    free(ud->A_indices);
  }
#ifdef DEBUG
  fprintf(stderr, "Free A_icol [%p]\n", ud->A_icol);
#endif
  if (ud->A_icol) {
    free(ud->A_icol);
  }
#ifdef DEBUG
  fprintf(stderr, "Free data->q [%p]\n", ud->data->q);
#endif
  if (ud->data->q) {
    free(ud->data->q);
  }
#ifdef DEBUG
  fprintf(stderr, "Free data->l [%p]\n", ud->data->l);
#endif
  if (ud->data->l) {
    free(ud->data->l);
  }
#ifdef DEBUG
  fprintf(stderr, "Free data->u [%p]\n", ud->data->u);
#endif
  if (ud->data->u) {
    free(ud->data->u);
  }
#ifdef DEBUG
  fprintf(stderr, "Free data->P [%p]\n", ud->data->P);
#endif
  c_free(ud->data->P);
#ifdef DEBUG
  fprintf(stderr, "Free data->A [%p]\n", ud->data->A);
#endif
  c_free(ud->data->A);
#ifdef DEBUG
  fprintf(stderr, "Free data [%p]\n", ud->data);
#endif
  c_free(ud->data);
#ifdef DEBUG
  fprintf(stderr, "Free settings [%p]\n", ud->settings);
#endif
  c_free(ud->settings);
  return 0;
}

// Must return nothing on the Lua stack (return 0)?
// TODO: Maybe, return whether updated or not... as a boolean
// Simply sets the number of variables
static int lua_osqp_set_n(lua_State *L) {
  struct osqp_ud *ud = lua_checkosqp(L, 1);
  OSQPData *data = ud->data;
  int n_updated = 0;
  lua_getfield(L, 2, "n");
  if (!lua_isnumber(L, -1)) {
    lua_pop(L, 1);
    return 0;
  }
  c_int n = luaL_checkinteger(L, -1);
  if (data->n != n) {
    data->n = n;
    n_updated = 1;
  }
  lua_pop(L, 1);
  return 0;
}

// Must return nothing on the Lua stack (return 0)?
// TODO: Maybe, return whether updated or not... as a boolean
// Simply sets the number of constraints
static int lua_osqp_set_m(lua_State *L) {
  struct osqp_ud *ud = lua_checkosqp(L, 1);
  OSQPData *data = ud->data;
  int m_updated = 0;
  lua_getfield(L, 2, "m");
  if (!lua_isnumber(L, -1)) {
    lua_pop(L, 1);
    return 0;
  }
  c_int m = luaL_checkinteger(L, -1);
  if (data->m != m) {
    data->m = m;
    m_updated = 1;
  }
  lua_pop(L, 1);
  return 0;
}

// General matrix non-zero of flattened matrix
static int lua_osqp_get_n_nonzero(lua_State *L) {
  c_int nnz = 0;
  // If not a table, then badness
  if (!lua_istable(L, -1)) {
    lua_pop(L, 1);
    return 0;
  }
  // Iterate through the table
  for (lua_pushnil(L); lua_next(L, -2); lua_pop(L, 1)) {
#ifdef DEBUG
    fprintf(stderr, "key %s - val %s\n", lua_typename(L, lua_type(L, -2)),
            lua_typename(L, lua_type(L, -1)));
#endif
    if (lua_tonumber(L, -1) != 0) {
      nnz++;
    }
  }
  // Give the result
#ifdef DEBUG
  fprintf(stderr, "Found [%lld] non-zeros\n", nnz);
#endif
  lua_pushinteger(L, nnz);
  return 1;
}

int lua_osqp_prepare_csc(lua_State *L, csc *ccs) {
  // Find the number of zeros
  lua_osqp_get_n_nonzero(L);
  ccs->nzmax = lua_tointeger(L, -1);
  lua_pop(L, 1);
  // Non zero values
  c_float *values = realloc(ccs->x, ccs->nzmax * sizeof(c_float));
  if (values) {
    ccs->x = values;
  } else {
    if (ccs->x) {
      free(ccs->x);
      ccs->x = NULL;
    }
    lua_pushboolean(L, 0);
    lua_pushliteral(L, "Bad realloc of values");
    fprintf(stderr, "Bad realloc of values");
    return 2;
  }

  // Non zero indices
  c_int *indices = realloc(ccs->i, ccs->nzmax * sizeof(c_int));
  if (indices) {
    ccs->i = indices;
  } else {
    if (ccs->i) {
      free(ccs->i);
      ccs->i = NULL;
    }
    lua_pushboolean(L, 0);
    lua_pushliteral(L, "Bad realloc of indices");
    fprintf(stderr, "Bad realloc of indices");
    return 2;
  }

  // Column indices
  c_int *indices_col = realloc(ccs->p, (ccs->n + 1) * sizeof(c_int));
  if (indices_col) {
    ccs->p = indices_col;
  } else {
    if (ccs->p) {
      free(ccs->p);
      ccs->p = NULL;
    }
    lua_pushboolean(L, 0);
    lua_pushliteral(L, "Bad realloc of column indices");
    fprintf(stderr, "Bad realloc of column indices");
    return 2;
  }
  return 0;
}

void *lua_osqp_table_to_csc(lua_State *L, c_int m, c_int n, csc *ccs) {

  // Assume that the arrays have the proper size
#ifdef DEBUG
  fprintf(stderr, "Populating | values: [%p] indices: [%p]\n", ccs->x, ccs->i);
#endif
  // m is nrow, n is ncol
  // i, for row major storage, is i = ic * nr + ir
  // for col major, then,
  c_int i_row, i_col;
  ccs->p[0] = 0;
  // Run via column major, access via row major
  for (i_col = 0; i_col < n; i_col++) {
    int n_set = 0;
    for (i_row = 0; i_row < m; i_row++) {
      int i_el_rowmaj = i_row * n + i_col;
      int i_el_colmaj = i_col * m + i_row;
      lua_rawgeti(L, -1, i_el_rowmaj + 1);
      double v = lua_tonumber(L, -1);
      lua_pop(L, 1);
      if (v != 0) {
#ifdef DEBUG
        fprintf(stderr, "Idx [%d] (%lld, %lld) = %f\n", i_el_rowmaj, i_row,
                i_col, v);
#endif
        *ccs->x++ = v;
        *ccs->i++ = i_row;
        n_set++;
      }
    }
#ifdef DEBUG
    fprintf(stderr, "nSet (i_col %lld) = %d\n", i_col, n_set);
#endif
    ccs->p[i_col + 1] = n_set + ccs->p[i_col];
  }

#ifdef DEBUG
  if (ccs->p[n] != ccs->nzmax) {
    fprintf(stderr, "Bad CSC conversion!\n");
  }
  // fprintf(stderr, "indices_col = ");
  // for (int i = 0; i <= data->n; i++) {
  //   fprintf(stderr, "[%lld] ", ccs->indices_col[i]);
  // }
  fprintf(stderr, "\n");
  //
  fprintf(stderr, "indices = ");
  for (int i = 0; i < ccs->nzmax; i++) {
    fprintf(stderr, "[%lld] ", ccs->i[i]);
  }
  fprintf(stderr, "\n");
#endif
  // Done
  return 0;
}

// Quadratic State costs
static int lua_osqp_set_P(lua_State *L) {
  struct osqp_ud *ud = lua_checkosqp(L, 1);
  OSQPData *data = ud->data;
  int P_updated = 0;
  //
  lua_getfield(L, 2, "P");
  if (!lua_istable(L, -1)) {
    lua_pop(L, 1);
    return 0;
  }

  // csc *csc_P = malloc(sizeof(csc));
  // bzero(csc_P, sizeof(csc));
  // if (lua_osqp_prepare_csc(L, csc_P) > 0) {
  //   fprintf(stderr, "Badness\n");
  // };
  // lua_osqp_table_to_csc(L, data->m, data->n, csc_P);
  // c_free(data->P);
  // data->P =
  //     csc_matrix(data->n, data->n, csc_P->nzmax, csc_P->x, csc_P->i,
  //     csc_P->p);
  // free(csc_P);
  // Find the number of zeros
  lua_osqp_get_n_nonzero(L);
  c_int P_nnz = lua_tointeger(L, -1);
  lua_pop(L, 1);

  if (P_nnz == 0) {
    // Pop off the table
    lua_pop(L, 1);
    return 0;
  }

  // Prepare: Check if we need to update sizes
#ifdef DEBUG
  fprintf(stderr, "P_values: [%p] P: [%p]\n", ud->P_values, data->P);
#endif
  // Non zero values
  c_float *Pv;
  Pv = realloc(ud->P_values, P_nnz * sizeof(c_float));
  if (!Pv) {
    if (ud->P_values) {
      free(ud->P_values);
      ud->P_values = NULL;
    }
    lua_pushboolean(L, 0);
    lua_pushliteral(L, "Bad realloc of P");
    return 2;
  }
  ud->P_values = Pv;
  // Non zero indices
  c_int *Pi;
  Pi = realloc(ud->P_indices, P_nnz * sizeof(c_int));
  if (!Pi) {
    if (ud->P_indices) {
      free(ud->P_indices);
      ud->P_indices = NULL;
    }
    lua_pushboolean(L, 0);
    return 1;
  }
  ud->P_indices = Pi;
  // Column indices
  c_int *Pp;
  Pp = realloc(ud->P_icol, (data->n + 1) * sizeof(c_int));
  if (!Pp) {
    if (ud->P_icol) {
      free(ud->P_icol);
      ud->P_icol = NULL;
    }
    lua_pushboolean(L, 0);
    return 1;
  }
  ud->P_icol = Pp;
  // Now, populate
  Pv = ud->P_values;
  Pi = ud->P_indices;
  Pp = ud->P_icol;
#ifdef DEBUG
  fprintf(stderr, "Populating [%p] [%p]\n", Pv, Pi);
#endif
  // m is nrow, n is ncol
  // i, for row major storage, is i = ic * nr + ir
  // for col major, then,
  int i_row, i_col;
  Pp[0] = 0;
  // Run via column major, access via row major
  for (i_col = 0; i_col < data->n; i_col++) {
    int n_set = 0;
    for (i_row = 0; i_row < data->m; i_row++) {
      int i_el_rowmaj = i_row * data->n + i_col;
      int i_el_colmaj = i_col * data->m + i_row;
      lua_rawgeti(L, -1, i_el_rowmaj + 1);
      double v = lua_tonumber(L, -1);
      lua_pop(L, 1);
      if (v != 0) {
#ifdef DEBUG
        fprintf(stderr, "Idx [%d] (%d, %d) = %f\n", i_el_rowmaj, i_row, i_col,
                v);
#endif
        *Pv++ = v;
        *Pi++ = i_row;
        n_set++;
      }
    }
#ifdef DEBUG
    fprintf(stderr, "nSet (i_col %d) = %d\n", i_col, n_set);
#endif
    Pp[i_col + 1] = n_set + Pp[i_col];
  }
  if (Pp[data->n] != P_nnz) {
    fprintf(stderr, "Bad CCS conversion!\n");
  }
#ifdef DEBUG
  Pp = ud->P_icol;
  fprintf(stderr, "Pp = ");
  for (int i = 0; i <= data->n; i++)
    fprintf(stderr, "[%lld] ", Pp[i]);
  fprintf(stderr, "\n");
  //
  Pi = ud->P_indices;
  fprintf(stderr, "Pi = ");
  for (int i = 0; i < P_nnz; i++)
    fprintf(stderr, "[%lld] ", Pi[i]);
  fprintf(stderr, "\n");
#endif
  c_free(data->P);
  data->P = csc_matrix(data->n, data->n, P_nnz, ud->P_values, ud->P_indices,
                       ud->P_icol);
  lua_pop(L, 1);
  return 0;
}

// Quadratic State costs
static int lua_osqp_set_A(lua_State *L) {
  struct osqp_ud *ud = lua_checkosqp(L, 1);
  OSQPData *data = ud->data;
  int A_updated = 0;
  //
  lua_getfield(L, 2, "A");
  if (!lua_istable(L, -1)) {
    lua_pop(L, 1);
    return 0;
  }

  // Find the number of zeros
  lua_osqp_get_n_nonzero(L);
  c_int A_nnz = lua_tointeger(L, -1);
  lua_pop(L, 1);

  if (A_nnz == 0) {
    // Pop off the A table
    lua_pop(L, 1);
    return 0;
  }

  for (int i = 0; i < data->m * data->n; i++) {
#ifdef DEBUG
    fprintf(stderr, "Inspect [%d]\n", i);
#endif
    lua_rawgeti(L, -1, i + 1);
    if (lua_tonumber(L, -1) != 0) {
      A_nnz++;
    }
    lua_pop(L, 1);
  }
#ifdef DEBUG
  fprintf(stderr, "Found [%lld] non-zeros\n", A_nnz);
#endif
  // Check if we need to update
  c_float *Av;
  c_int *Ai;
  c_int *Ap;
#ifdef DEBUG
  fprintf(stderr, "A_values: [%p] A: [%p]\n", ud->A_values, data->A);
#endif
  Av = realloc(ud->A_values, A_nnz * sizeof(c_float));
  if (!Av) {
    if (ud->A_values) {
      free(ud->A_values);
      ud->A_values = NULL;
    }
    lua_pushboolean(L, 0);
    return 1;
  }
  ud->A_values = Av;
  Ai = realloc(ud->A_indices, A_nnz * sizeof(c_int));
  if (!Ai) {
    if (ud->A_indices) {
      free(ud->A_indices);
      ud->A_indices = NULL;
    }
    lua_pushboolean(L, 0);
    return 1;
  }
  ud->A_indices = Ai;
  //
  Ap = realloc(ud->A_icol, (data->m + 1) * sizeof(c_int));
  if (!Ap) {
    if (ud->A_icol) {
      free(ud->A_icol);
      ud->A_icol = NULL;
    }
    lua_pushboolean(L, 0);
    return 1;
  }
  ud->A_icol = Ap;
  // Now, populate
  Av = ud->A_values;
  Ai = ud->A_indices;
  Ap = ud->A_icol;
#ifdef DEBUG
  fprintf(stderr, "Populating [%p] [%p]\n", Av, Ai);
#endif
  int i_row, i_col;
  Ap[0] = 0;
  // Run via column major, access via row major
  for (i_col = 0; i_col < data->n; i_col++) {
    int n_set = 0;
    for (i_row = 0; i_row < data->m; i_row++) {
      int i_el_rowmaj = i_row * data->n + i_col;
      int i_el_colmaj = i_col * data->m + i_row;
      lua_rawgeti(L, -1, i_el_rowmaj + 1);
      double v = lua_tonumber(L, -1);
      lua_pop(L, 1);
      if (v != 0) {
        *Av++ = v;
        *Ai++ = i_row;
        n_set++;
      }
    }
    Ap[i_col + 1] = Ap[i_col] + n_set;
  }

#ifdef DEBUG
  Ai = ud->A_indices;
  fprintf(stderr, "Ai = ");
  for (int i = 0; i < A_nnz; i++)
    fprintf(stderr, "[%lld] ", Ai[i]);
  fprintf(stderr, "\n");
  //
  Ap = ud->A_icol;
  fprintf(stderr, "Ap = ");
  for (int i = 0; i <= data->n; i++)
    fprintf(stderr, "[%lld] ", Ap[i]);
  fprintf(stderr, "\n");
#endif
  c_free(data->A);
  data->A = csc_matrix(data->m, data->n, A_nnz, ud->A_values, ud->A_indices,
                       ud->A_icol);
  lua_pop(L, 1);
  return 0;
}

void *lua_osqp_table_to_array(lua_State *L, c_float *dst, int n) {
  // A table must be on the stack
  if (!lua_istable(L, -1)) {
    return NULL;
  }

  // Must have the same number of elements
#if LUA_VERSION_NUM == 501
  if (lua_objlen(L, -1) != (size_t)n)
#else
  if (lua_rawlen(L, -1) != (size_t)n)
#endif
  {
    return NULL;
  }

  // Make the array have the correct size
  c_float *dst2 = realloc(dst, n * sizeof(c_float));
  if (!dst2) {
    if (dst) {
      free(dst);
    }
    // No copy performed... we free'd since an error :(
    return NULL;
  }
  for (int i = 0; i < n; i++) {
#ifdef DEBUG
    fprintf(stderr, "Inspect array [%d]\n", i);
#endif
    lua_rawgeti(L, -1, i + 1);
    dst2[i] = lua_tonumber(L, -1);
    lua_pop(L, 1);
  }
  return dst2;
}

static int lua_osqp_set_l(lua_State *L) {
  struct osqp_ud *ud = lua_checkosqp(L, 1);
  OSQPData *data = ud->data;
  int l_updated = 0;
  //
  lua_getfield(L, 2, "l");
  if (!lua_istable(L, -1)) {
    lua_pop(L, 1);
    return 0;
  }
  // Check if we could not set the data
  if ((data->l = lua_osqp_table_to_array(L, data->l, data->m)) == NULL) {
    lua_pop(L, 1);
    return 0;
  }
  // Pop off the table of vector l
  lua_pop(L, 1);
  return 0;
}

static int lua_osqp_set_u(lua_State *L) {
  struct osqp_ud *ud = lua_checkosqp(L, 1);
  OSQPData *data = ud->data;
  int u_updated = 0;
  //
  lua_getfield(L, 2, "u");
  if (!lua_istable(L, -1)) {
    lua_pop(L, 1);
    return 0;
  }
  // Check if we could not set the data
  if ((data->u = lua_osqp_table_to_array(L, data->u, data->m)) == NULL) {
    lua_pop(L, 1);
    return 0;
  }
  // Pop off the table of vector u
  lua_pop(L, 1);
  return 0;
}

static int lua_osqp_set_q(lua_State *L) {
  struct osqp_ud *ud = lua_checkosqp(L, 1);
  OSQPData *data = ud->data;
  int q_updated = 0;
  //
  lua_getfield(L, 2, "q");
  if (!lua_istable(L, -1)) {
    lua_pop(L, 1);
    return 0;
  }
  // Check if we could not set the data
  if ((data->q = lua_osqp_table_to_array(L, data->q, data->n)) == NULL) {
    lua_pop(L, 1);
    return 0;
  }
  // Pop off the table of vector q
  lua_pop(L, 1);
  return 0;
}

// https://arxiv.org/pdf/1711.08013.pdf
// P is n by n
// q is n by 1
// A is m by n
// l is n by 1
// u is n by 1
// min 0.5 xT P x + qT x
// s.t. l <= A x <= u
static int lua_osqp_setproblem(lua_State *L) {
  // struct osqp_ud *ud = lua_checkosqp(L, 1);
  // OSQPData *data = ud->data;
  // Now, utilize the table of params
  lua_osqp_set_n(L);
  lua_osqp_set_m(L);
  // Quadratic State costs
  lua_osqp_set_P(L);
  // Control limits
  lua_osqp_set_A(L);
  // Lower control limit
  lua_osqp_set_l(L);
  // Upper control limit
  lua_osqp_set_u(L);
  // Linear State costs
  lua_osqp_set_q(L);
  // Return true, for now
  lua_pushboolean(L, 1);
  return 1;
}

static int lua_osqp_solve(lua_State *L) {
  struct osqp_ud *ud = lua_checkosqp(L, 1);

  // Run the solver
  ud->work = osqp_setup(ud->data, ud->settings);
  c_int res = osqp_solve(ud->work);
  if (res != 0) {
    lua_pushboolean(L, 0);
    lua_pushliteral(L, "Cannot solve!");
    return 2;
  }
  // Grab the solution
  OSQPSolution *sol = ud->work->solution;
  c_float *primal = sol->x;
  // Iterate
  lua_createtable(L, ud->data->n, 0);
  for (int i = 0; i < ud->data->n; i++) {
    lua_pushnumber(L, primal[i]);
    lua_rawseti(L, -2, i + 1);
  }
  // c_float* lagrangemultipliers = sol->y;
  // Grab the information
  OSQPInfo *info = ud->work->info;
  //
  lua_pushliteral(L, "nIter");
  lua_pushinteger(L, info->iter);
  lua_settable(L, -3);
  //
  lua_pushliteral(L, "status");
  lua_pushstring(L, info->status);
  lua_settable(L, -3);
  //
  lua_pushliteral(L, "cost");
  lua_pushnumber(L, info->obj_val);
  lua_settable(L, -3);
  //
  return 1;
}

static int lua_osqp_tostring(lua_State *L) {
  struct osqp_ud *ud = lua_checkosqp(L, 1);
  lua_pushfstring(L, "Solver: %d variables | %d constraints", ud->data->n,
                  ud->data->m);
  return 1;
}

static const struct luaL_Reg osqp_lib[] = {{"new", lua_osqp_new}, {NULL, NULL}};

static const struct luaL_Reg osqp_methods[] = {
    {"__index", lua_osqp_index},
    {"__gc", lua_osqp_free},
    {"__tostring", lua_osqp_tostring},
    {"set_problem", lua_osqp_setproblem},
    {"set_lower", lua_osqp_set_l},
    {"set_upper", lua_osqp_set_u},
    {"set_q", lua_osqp_set_q},
    {"solve", lua_osqp_solve},
    {NULL, NULL}};

#ifdef __cplusplus
extern "C"
#endif
    int
    luaopen_osqp(lua_State *L) {
  luaL_newmetatable(L, MT_NAME);
#if LUA_VERSION_NUM == 501
  luaL_register(L, NULL, osqp_methods);
  luaL_register(L, "osqp", osqp_lib);
#else
  luaL_setfuncs(L, osqp_methods, 0);
  luaL_newlib(L, osqp_lib);
#endif
  return 1;
}
