/* Native Tcl binding. Numerical kernels remain in interp.c and spline.c.
 * Copyright (c) 2026 George Yashin. Same license as tclinterp.
 */
#include <tcl.h>
#include <limits.h>
#include <stdint.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>
#include "interp.h"
#include "spline.h"
#ifdef HAVE_RBC
#include <rbcVector.h>
#include <rbcDecls.h>
#include <rbcStubLib.c>
#endif

/* Borrowed vectors are used only during computation: no Tcl evaluation occurs
 * between opening inputs and finishing every numerical result. */
typedef struct {
    int n;
    double *v;
    double *owned;
} Input;

typedef struct {
    const char *key;
    int n;
    double *v;
    Tcl_Obj *name;
    Tcl_Command created;
} Output;

typedef struct {
    Tcl_Interp *ip;
    Tcl_Obj *args;
} Context;

static int Error(Tcl_Interp *ip, const char *s) {
    Tcl_SetObjResult(ip, Tcl_NewStringObj(s, -1));
    return TCL_ERROR;
}

static Tcl_Obj *Option(Context *c, const char *key) {
    Tcl_Obj *value = NULL, *k = Tcl_NewStringObj(key, -1);
    Tcl_IncrRefCount(k);
    Tcl_DictObjGet(c->ip, c->args, k, &value);
    Tcl_DecrRefCount(k);
    return value;
}

static const char *StringOption(Context *c, const char *key, const char *fallback) {
    Tcl_Obj *o = Option(c, key);
    return o ? Tcl_GetString(o) : fallback;
}

static int Integer(Context *c, const char *key, int fallback, int *v) {
    Tcl_Obj *o = Option(c, key);
    *v = fallback;
    return o ? Tcl_GetIntFromObj(c->ip, o, v) : TCL_OK;
}

static int Number(Context *c, const char *key, double fallback, double *v) {
    Tcl_Obj *o = Option(c, key);
    *v = fallback;
    if (o && Tcl_GetDoubleFromObj(c->ip, o, v) != TCL_OK) {
        return TCL_ERROR;
    }        
    if (!isfinite(*v)) {
        return Error(c->ip, "scalar parameters must be finite");
    }        
    return TCL_OK;
}

static double *Allocate(Tcl_Interp *ip, int n) {
    double *p;
    if (n < 0 || (size_t)n > SIZE_MAX / sizeof(double)) {
        Error(ip, "array size overflow");
        return NULL;
    }
    p = malloc((n ? (size_t)n : 1) * sizeof(double));
    if (!p) {
        Error(ip, "cannot allocate interpolation buffer");
    }        
    return p;
}

static int InitVectors(Tcl_Interp *ip) {
#ifdef HAVE_RBC
    return Rbc_VectorInitStubs(ip, "0.8.0", 0) ? TCL_OK : TCL_ERROR;
#else
    return Error(ip, "tclinterp was built without RBC vector support; rebuild with --with-rbc=DIR");
#endif
}

static int OpenInput(Context *c, const char *key, int vectors, Input *a) {
    Tcl_Obj *o = Option(c, key), **elems = NULL;
    Tcl_Size n;
    if (!o) {
        Tcl_SetObjResult(c->ip, Tcl_ObjPrintf("missing input -%s", key));
        return TCL_ERROR;
    }
    if (vectors) {
#ifdef HAVE_RBC
        Rbc_Vector *v;
        if (Rbc_GetVector(c->ip, Tcl_GetString(o), &v) != TCL_OK) {
            return TCL_ERROR;
        }            
        if (Rbc_VectorGetType(v) != RBC_VECTOR_REAL) {
            return Error(c->ip, "input vectors must contain real values");
        }            
        n = Rbc_VectorLength(v);
        a->v = Rbc_VectorData(v);
#else
        return InitVectors(c->ip);
#endif
    } else {
        if (Tcl_ListObjGetElements(c->ip, o, &n, &elems) != TCL_OK) {
            return TCL_ERROR;
        }            
    }
    /* Kernel indexing includes 4*n for Hermite coefficients. */
    if (n > INT_MAX / 4 || (size_t)n > SIZE_MAX / (4 * sizeof(double))) {
        return Error(c->ip, "input exceeds numerical kernel size limit");
    }
    a->n = (int)n;
    if (!vectors) {
        a->owned = a->v = Allocate(c->ip, a->n);
        if (!a->v) {
            return TCL_ERROR;
        }            
        for (int i = 0; i < a->n; i++) {
            if (Tcl_GetDoubleFromObj(c->ip, elems[i], &a->v[i]) != TCL_OK) {
                Tcl_SetObjResult(c->ip, Tcl_ObjPrintf("List must contains only double elements, but get '%s'",
                                                      Tcl_GetString(elems[i])));
                return TCL_ERROR;
            }
        }
    }
    for (int i = 0; i < a->n; i++) {
        if (!isfinite(a->v[i])) {
            return Error(c->ip, "input samples must be finite real numbers");
        }            
    }
    return TCL_OK;
}

static int EqualLength(Context *c, Input *a, const char *ak, Input *b, const char *bk) {
    if (a->n == b->n) {
        return TCL_OK;
    }        
    Tcl_SetObjResult(c->ip,
                     Tcl_ObjPrintf("Length of -%s '%d' must be equal to length of -%s '%d'", bk, b->n, ak, a->n));
    return TCL_ERROR;
}

static int Increasing(Context *c, Input *x, const char *key) {
    for (int i = 1; i < x->n; i++)
        if (!(x->v[i] > x->v[i - 1])) {
            Tcl_SetObjResult(c->ip, Tcl_ObjPrintf("Independent variable array -%s is not strictly increasing", key));
            return TCL_ERROR;
        }
    return TCL_OK;
}

static int CompareDouble(const void *a, const void *b) {
    double x = *(const double *)a, y = *(const double *)b;
    return (x > y) - (x < y);
}

static int Distinct(Context *c, Input *a) {
    double *copy = Allocate(c->ip, a->n);
    int count = 0;
    if (!copy) {
        return -1;
    }        
    memcpy(copy, a->v, (size_t)a->n * sizeof(double));
    qsort(copy, a->n, sizeof(double), CompareDouble);
    for (int i = 0; i < a->n; i++) {
        if (!i || copy[i] != copy[i - 1]) {
            count++;
        }            
    }        
    free(copy);
    return count;
}

static Tcl_Obj *ListResult(Output *o) {
    Tcl_Obj *list = Tcl_NewListObj(0, NULL);
    for (int i = 0; i < o->n; i++) {
        Tcl_ListObjAppendElement(NULL, list, Tcl_NewDoubleObj(o->v[i]));
    }        
    return list;
}

#ifdef HAVE_RBC
/* Output names resolve where the native command runs (the public caller).
 * A generated name is obtained from RBC's actual create #auto command. */
static Tcl_Obj *Qualified(Tcl_Interp *ip, const char *s) {
    if (s[0] == ':' && s[1] == ':') {
        return Tcl_NewStringObj(s, -1);
    }        
    const char *ns = Tcl_GetCurrentNamespace(ip)->fullName;
    return Tcl_ObjPrintf("%s%s%s", ns, strcmp(ns, "::") ? "::" : "", s);
}

static int CheckDestination(Tcl_Interp *ip, Tcl_Obj *name, int replace) {
    const char *s = Tcl_GetString(name);
    Tcl_CmdInfo info;
    int command = Tcl_GetCommandInfo(ip, s, &info);
    if (Rbc_VectorExists2(ip, s)) {
        Rbc_Vector *v;
        if (!replace) {
            Tcl_SetObjResult(ip, Tcl_ObjPrintf("vector \"%s\" already exists", s));
            return TCL_ERROR;
        }
        if (Rbc_GetVector(ip, s, &v) != TCL_OK) {
            return TCL_ERROR;
        }            
        if (!command || info.isNativeObjectProc != 2 || info.objClientData2 != (void *)v) {
            return Error(ip, "destination is not the vector's instance command");
        }            
        if (Rbc_VectorGetType(v) != RBC_VECTOR_REAL) {
            return Error(ip, "destination vector must be real");
        }            
    } else if (command) {
        Tcl_SetObjResult(ip, Tcl_ObjPrintf("command \"%s\" already exists", s));
        return TCL_ERROR;
    }
    return TCL_OK;
}

static int CreateDestination(Tcl_Interp *ip, Output *o) {
    Tcl_Obj *args[7] = {Tcl_NewStringObj("::rbc::vector", -1),
                        Tcl_NewStringObj("create", -1),
                        o->name ? o->name : Tcl_NewStringObj("#auto", -1),
                        Tcl_NewStringObj("-variable", -1),
                        Tcl_NewObj(),
                        Tcl_NewStringObj("-literal", -1),
                        Tcl_NewBooleanObj(o->name != NULL)};
    for (int j = 0; j < 7; j++) {
        Tcl_IncrRefCount(args[j]);
    }        
    int code = Tcl_EvalObjv(ip, 7, args, TCL_EVAL_DIRECT);
    for (int j = 0; j < 7; j++) {
        Tcl_DecrRefCount(args[j]);
    }        
    if (code != TCL_OK) {
        return code;
    }        
    if (!o->name) {
        Tcl_Obj *first;
        if (Tcl_ListObjIndex(ip, Tcl_GetObjResult(ip), 0, &first) != TCL_OK || !first) {
            return Error(ip, "RBC did not return a created vector name");
        }            
        o->name = Qualified(ip, Tcl_GetString(first));
        Tcl_IncrRefCount(o->name);
    }
    o->created = Tcl_FindCommand(ip, Tcl_GetString(o->name), NULL, TCL_GLOBAL_ONLY);
    if (!o->created) {
        return Error(ip, "RBC did not create the destination command");
    }        
    return TCL_OK;
}
#endif

/* All numeric arrays are ready before publication, so output/input aliasing is
 * safe. Preflight every explicit name; remove new commands on a later error.
 * Replacement is not transactional against application notification callbacks. */
static int Publish(Context *c, Output *out, int count, int dictionary, int vectors) {
    Tcl_Interp *ip = c->ip;
    int code = TCL_ERROR;
    Tcl_Obj *result = Tcl_NewDictObj(), *coeffs = Tcl_NewDictObj();
    Tcl_IncrRefCount(result);
    Tcl_IncrRefCount(coeffs);
    if (vectors) {
#ifdef HAVE_RBC
        Tcl_Obj *names = Option(c, "names"), *primary = Option(c, "name");
        int replace = !strcmp(StringOption(c, "ifexists", "error"), "replace");
        if (names) {
            Tcl_DictSearch search;
            Tcl_Obj *key, *value;
            int done;
            if (Tcl_DictObjFirst(ip, names, &search, &key, &value, &done) != TCL_OK) {
                goto done;
            }                
            for (; !done; Tcl_DictObjNext(&search, &key, &value, &done)) {
                int found = 0;
                for (int i = 0; i < count; i++) {
                    if (!strcmp(Tcl_GetString(key), out[i].key)) {
                        found = 1;
                    }                        
                }                    
                if (!found) {
                    Tcl_SetObjResult(ip, Tcl_ObjPrintf("unknown output field \"%s\"", Tcl_GetString(key)));
                    Tcl_DictObjDone(&search);
                    goto done;
                }
            }
            Tcl_DictObjDone(&search);
        }
        for (int i = 0; i < count; i++) {
            Tcl_Obj *name = NULL;
            if (names) {
                Tcl_Obj *key = Tcl_NewStringObj(out[i].key, -1);
                Tcl_IncrRefCount(key);
                Tcl_DictObjGet(ip, names, key, &name);
                Tcl_DecrRefCount(key);
            }
            if (!strcmp(out[i].key, "yi") && primary) {
                if (name) {
                    Error(ip, "use either -name or -names yi, not both");
                    goto done;
                }
                name = primary;
            }
            if (name && strcmp(Tcl_GetString(name), "#auto")) {
                if (!Tcl_GetCharLength(name)) {
                    Error(ip, "output name must not be empty");
                    goto done;
                }
                out[i].name = Qualified(ip, Tcl_GetString(name));
                Tcl_IncrRefCount(out[i].name);
                for (int j = 0; j < i; j++) {
                    if (out[j].name && !strcmp(Tcl_GetString(out[j].name), Tcl_GetString(out[i].name))) {
                        Error(ip, "output vector names must be distinct");
                        goto done;
                    }
                }                    
                if (CheckDestination(ip, out[i].name, replace) != TCL_OK) {
                    goto done;
                }                    
            }
        }
        /* Reserve explicit names first so #auto cannot take one of them. */
        for (int pass = 0; pass < 2; pass++) {
            for (int i = 0; i < count; i++) {
                if ((pass == 0 && !out[i].name) || (pass == 1 && out[i].name)) {
                    continue;
                }                    
                if (out[i].name && CheckDestination(ip, out[i].name, replace) != TCL_OK) {
                    goto done;
                }                    
                if (!out[i].name || !Rbc_VectorExists2(ip, Tcl_GetString(out[i].name))) {
                    if (CreateDestination(ip, &out[i]) != TCL_OK) {
                        goto done;
                    }                        
                }
            }
        }            
        /* Different spellings may resolve to the same command. */
        for (int i = 0; i < count; i++) {
            Tcl_Command token = Tcl_FindCommand(ip, Tcl_GetString(out[i].name), NULL, TCL_GLOBAL_ONLY);
            for (int j = 0; j < i; j++) {
                if (token && token == Tcl_FindCommand(ip, Tcl_GetString(out[j].name), NULL, TCL_GLOBAL_ONLY)) {
                    Error(ip, "output vector names must be distinct");
                    goto done;
                }
            }
        }
        for (int i = 0; i < count; i++) {
            Rbc_Vector *v;
            if (CheckDestination(ip, out[i].name, 1) != TCL_OK ||
                Rbc_GetVector(ip, Tcl_GetString(out[i].name), &v) != TCL_OK) {
                goto done;
            }
            if (Rbc_ResetVector(v, out[i].v, out[i].n, out[i].n, TCL_VOLATILE) != TCL_OK) {
                goto done;
            }                
        }
        for (int i = 0; i < count; i++) {
            if (!Rbc_VectorExists2(ip, Tcl_GetString(out[i].name)) || CheckDestination(ip, out[i].name, 1) != TCL_OK) {
                Error(ip, "output vector removed or replaced during notification");
                goto done;
            }
        }
#else
        InitVectors(ip);
        goto done;
#endif
    }
    for (int i = 0; i < count; i++) {
        Tcl_Obj *value = vectors ? out[i].name : ListResult(&out[i]);
        if (!dictionary) {
            Tcl_SetObjResult(ip, value);
            code = TCL_OK;
            goto done;
        }
        if (!strncmp(out[i].key, "coeffs.", 7)) {
            Tcl_DictObjPut(ip, coeffs, Tcl_NewStringObj(out[i].key + 7, -1), value);
        } else {
            Tcl_DictObjPut(ip, result, Tcl_NewStringObj(out[i].key, -1), value);
        }            
    }
    Tcl_Size coeffCount;
    Tcl_DictObjSize(ip, coeffs, &coeffCount);
    if (coeffCount) {
        Tcl_DictObjPut(ip, result, Tcl_NewStringObj("coeffs", -1), coeffs);
    }        
    Tcl_SetObjResult(ip, result);
    code = TCL_OK;
done:
#ifdef HAVE_RBC
    if (code != TCL_OK) {
        Tcl_InterpState state = Tcl_SaveInterpState(ip, code);
        for (int i = 0; i < count; i++) {
            if (out[i].created &&
                Tcl_FindCommand(ip, Tcl_GetString(out[i].name), NULL, TCL_GLOBAL_ONLY) == out[i].created) {
                Tcl_DeleteCommandFromToken(ip, out[i].created);
            }                
        }            
        Tcl_RestoreInterpState(ip, state);
    }
#endif
    Tcl_DecrRefCount(coeffs);
    Tcl_DecrRefCount(result);
    return code;
}

enum {
    LINEAR,
    NEAREST,
    LAGRANGE,
    LEAST,
    LEASTDER,
    GENBEZIER,
    BEZIER,
    DIVDIF,
    BSPLINE,
    BETASPLINE,
    CUBIC,
    HERMITE,
    PCHIP
};

static int NativeCmd(void *unused, Tcl_Interp *ip, Tcl_Size objc, Tcl_Obj *const objv[]) {
    static const char *ops[] = {
        "lin1d",   "near1d",   "lagr1d",         "least1d",           "least1dDer",    "genBezier",
        "bezier",  "divDif1d", "cubicBSpline1d", "cubicBetaSpline1d", "cubicSpline1d", "hermiteSpline1d",
        "pchip1d", NULL};
    Context ctx = {ip, NULL}, *c = &ctx;
    Input x = {0}, y = {0}, q = {0}, extra = {0};
    Output out[6] = {{0}};
    int count = 0, op, status = TCL_ERROR, vi, vo, dictionary = 0, nterms = 3, degree = 0;
    double *temp = NULL, *b = NULL, *cc = NULL, *d = NULL;
    const char *xkey = "x", *ykey = "y", *qkey = "xi";
    (void)unused;
    if (objc != 3) {
        Tcl_WrongNumArgs(ip, 1, objv, "operation optionsDict");
        return TCL_ERROR;
    }
    if (Tcl_GetIndexFromObj(ip, objv[1], ops, "operation", TCL_EXACT, &op) != TCL_OK) {
        return TCL_ERROR;
    }        
    Tcl_Size dictSize;
    if (Tcl_DictObjSize(ip, objv[2], &dictSize) != TCL_OK) {
        return TCL_ERROR;
    }        
    ctx.args = objv[2];
    const char *im = StringOption(c, "input", "list"), *om = StringOption(c, "output", "list");
    if ((strcmp(im, "list") && strcmp(im, "vector")) || (strcmp(om, "list") && strcmp(om, "vector"))) {
        return Error(ip, "input and output must be list or vector");
    }        
    vi = !strcmp(im, "vector");
    vo = !strcmp(om, "vector");
    if (!vo && (Option(c, "name") || Option(c, "names"))) {
        return Error(ip, "-name and -names require -output vector");
    }
    if (strcmp(StringOption(c, "ifexists", "error"), "error") &&
        strcmp(StringOption(c, "ifexists", "error"), "replace")) {
        return Error(ip, "-ifexists must be error or replace");
    }
    if ((vi || vo) && InitVectors(ip) != TCL_OK) {
        return TCL_ERROR;
    }        
    if (op >= BSPLINE && op <= HERMITE) {
        xkey = "t";
        qkey = "ti";
    }
    if (op == PCHIP) {
        ykey = "f";
        qkey = "xe";
    }
    if (op == GENBEZIER)
        qkey = "t";
    if (OpenInput(c, xkey, vi, &x) != TCL_OK || OpenInput(c, ykey, vi, &y) != TCL_OK) {
        goto done;
    }        
    if (op != BEZIER && OpenInput(c, qkey, vi, &q) != TCL_OK) {
        goto done;
    }        
    int nq = op == BEZIER ? x.n : q.n;
    if (op != BEZIER && op != GENBEZIER && EqualLength(c, &x, xkey, &y, ykey) != TCL_OK) {
        goto done;
    }        
    if (!nq) {
        Tcl_SetObjResult(ip, Tcl_ObjPrintf("Length of %spoints list -%s must be more than zero",
                                           op == GENBEZIER || op == BEZIER ? "" : "interpolation ",
                                           op == BEZIER ? "x" : qkey));
        goto done;
    }
    if (op == HERMITE &&
        (OpenInput(c, "yp", vi, &extra) != TCL_OK || EqualLength(c, &x, "t", &extra, "yp") != TCL_OK)) {
        goto done;
    }
    if (op == GENBEZIER || op == BEZIER) {
        if (Integer(c, "n", 0, &degree) != TCL_OK) {
            goto done;
        }            
        if (degree < 0 || degree >= INT_MAX / 4) {
            Error(ip, "Bezier degree must be nonnegative and within the kernel size limit");
            goto done;
        }
        if ((op == GENBEZIER && x.n != degree + 1) || y.n != degree + 1) {
            const char *key = (op == GENBEZIER && x.n != degree + 1) ? "x" : "y";
            Tcl_SetObjResult(ip, Tcl_ObjPrintf("Length of -%s '%d' must be equal to n+1=%d", key,
                                               *key == 'x' ? x.n : y.n, degree + 1));
            goto done;
        }
    } else {
        int minimum = (op == LAGRANGE || op == DIVDIF || op == LEAST || op == LEASTDER || op == NEAREST) ? 1 : 2;
        if (x.n < minimum) {
            Error(ip, "not enough input samples for this operation");
            goto done;
        }
        if ((op == LINEAR || op >= BSPLINE) && Increasing(c, &x, xkey) != TCL_OK) {
            goto done;
        }            
        if (op == LAGRANGE || op == DIVDIF) {
            int unique = Distinct(c, &x);
            if (unique < 0) {
                goto done;
            }                
            if (unique != x.n) {
                Error(ip, "List of -x values must not contain duplicated elements");
                goto done;
            }
        }
    }
#define ADD(KEY, N)                                                                                                    \
    do {                                                                                                               \
        out[count].key = (KEY);                                                                                        \
        out[count].n = (N);                                                                                            \
        out[count].v = Allocate(ip, (N));                                                                              \
        if (!out[count].v) {                                                                                           \
            goto done;                                                                                                 \
        }                                                                                                              \
        count++;                                                                                                       \
    } while (0)
    ADD("yi", nq);
    
    if (op == LINEAR || op == NEAREST || op == LAGRANGE) {
        if (op == LINEAR) {
            temp = interp_linear(1, x.n, x.v, y.v, q.n, q.v);
        }            
        else if (op == NEAREST) {
            temp = interp_nearest(1, x.n, x.v, y.v, q.n, q.v);
        }            
        else {
            if ((size_t)x.n * (size_t)q.n > INT_MAX) {
                Error(ip, "Lagrange workspace exceeds kernel size limit");
                goto done;
            }
            temp = interp_lagrange(1, x.n, x.v, y.v, q.n, q.v);
        }
        if (!temp) {
            Error(ip, "interpolation failed");
            goto done;
        }
        memcpy(out[0].v, temp, (size_t)nq * sizeof(double));
    } else if (op == LEAST || op == LEASTDER) {
        if (Integer(c, "nterms", 3, &nterms) != TCL_OK) {
            goto done;
        }            
        int unique = Distinct(c, &x);
        if (unique < 0) {
            goto done;
        }            
        if (nterms < 1 || nterms > unique) {
            Error(ip, "-nterms must be positive and no greater than the number of distinct x values");
            goto done;
        }
        if (Option(c, "w")) {
            if (OpenInput(c, "w", vi, &extra) != TCL_OK || EqualLength(c, &x, "x", &extra, "w") != TCL_OK)
                goto done;
        } else {
            extra.n = x.n;
            extra.owned = extra.v = Allocate(ip, x.n);
            if (!extra.v) {
                goto done;
            }                
            for (int i = 0; i < x.n; i++) {
                extra.v[i] = 1.0;
            }                
        }
        for (int i = 0; i < x.n; i++)
            if (!(extra.v[i] > 0)) {
                Error(ip, "weights must be positive");
                goto done;
            }
        b = Allocate(ip, nterms);
        cc = Allocate(ip, nterms);
        d = Allocate(ip, nterms);
        if (!b || !cc || !d) {
            goto done;
        }            
        least_set(x.n, x.v, y.v, extra.v, nterms, b, cc, d);
        if (op == LEASTDER) {
            ADD("yiDer", nq);
            dictionary = 1;
        }
        for (int i = 0; i < nq; i++) {
            if (op == LEASTDER) {
                least_val2(nterms, b, cc, d, q.v[i], &out[0].v[i], &out[1].v[i]);
            } else {
                out[0].v[i] = least_val(nterms, b, cc, d, q.v[i]);
            }                
        }
        if (Option(c, "coeffs")) {
            dictionary = 1;
            ADD("coeffs.b", nterms);
            memcpy(out[count - 1].v, b, nterms * sizeof(double));
            ADD("coeffs.c", nterms);
            memcpy(out[count - 1].v, cc, nterms * sizeof(double));
            ADD("coeffs.d", nterms);
            memcpy(out[count - 1].v, d, nterms * sizeof(double));
        }
    } else if (op == GENBEZIER) {
        /* Preserve the historical xi, yi dictionary order. */
        out[0].key = "xi";
        ADD("yi", nq);
        dictionary = 1;
        for (int i = 0; i < nq; i++) {
            bc_val(degree, q.v[i], x.v, y.v, &out[0].v[i], &out[1].v[i]);
        }            
    } else if (op == BEZIER) {
        double a, z;
        if (Number(c, "a", 0, &a) != TCL_OK || Number(c, "b", 1, &z) != TCL_OK) {
            goto done;
        }            
        if (a == z) {
            Tcl_SetObjResult(ip, Tcl_ObjPrintf("Start -a '%s' and end -b '%s' values of interval must not be equal",
                                               StringOption(c, "a", "0"), StringOption(c, "b", "1")));
            goto done;
        }
        for (int i = 0; i < nq; i++) {
            out[0].v[i] = bez_val(degree, x.v[i], a, z, y.v);
        }            
    } else if (op == DIVDIF) {
        temp = Allocate(ip, x.n);
        if (!temp) {
            goto done;
        }            
        data_to_dif(x.n, x.v, y.v, temp);
        for (int i = 0; i < nq; i++) {
            out[0].v[i] = dif_val(x.n, x.v, temp, q.v[i]);
        }            
        if (Option(c, "coeffs")) {
            dictionary = 1;
            ADD("coeffs", x.n);
            memcpy(out[1].v, temp, x.n * sizeof(double));
        }
    } else if (op == BSPLINE || op == BETASPLINE) {
        double beta1 = 1, beta2 = 0;
        if (op == BETASPLINE) {
            if (Number(c, "beta1", 1, &beta1) != TCL_OK || Number(c, "beta2", 0, &beta2) != TCL_OK) {
                goto done;
            }                
            double den = ((2 * beta1 + 4) * beta1 + 4) * beta1 + 2 + beta2;
            if (!isfinite(den) || den == 0) {
                Error(ip, "invalid beta spline normalization");
                goto done;
            }
        }
        for (int i = 0; i < nq; i++) {
            out[0].v[i] = op == BSPLINE ? spline_b_val(x.n, x.v, y.v, q.v[i])
                                        : spline_beta_val(beta1, beta2, x.n, x.v, y.v, q.v[i]);
        }            
    } else if (op == CUBIC) {
        static const char *flags[] = {"quad", "der1", "der2", "notaknot", NULL};
        int beg = 0, end = 0;
        double bv, ev;
        Tcl_Obj *o = Option(c, "ibcbeg");
        if (o && Tcl_GetIndexFromObj(ip, o, flags, "boundary", TCL_EXACT, &beg) != TCL_OK) {
            goto done;
        }            
        o = Option(c, "ibcend");
        if (o && Tcl_GetIndexFromObj(ip, o, flags, "boundary", TCL_EXACT, &end) != TCL_OK) {
            goto done;
        }            
        if (Number(c, "ybcbeg", 0, &bv) != TCL_OK || Number(c, "ybcend", 0, &ev) != TCL_OK) {
            goto done;
        }            
        if ((beg == 3 || end == 3) && x.n < 4) {
            Error(ip, "notaknot boundaries require at least four samples");
            goto done;
        }
        temp = spline_cubic_set(x.n, x.v, y.v, beg, bv, end, ev);
        if (!temp) {
            Error(ip, "cubic spline construction failed");
            goto done;
        }
        if (Option(c, "deriv")) {
            dictionary = 1;
            ADD("yder1", nq);
            ADD("yder2", nq);
        }
        for (int i = 0; i < nq; i++) {
            double yp, ypp;
            out[0].v[i] = spline_cubic_val(x.n, x.v, y.v, temp, q.v[i], &yp, &ypp);
            if (dictionary) {
                out[1].v[i] = yp;
                out[2].v[i] = ypp;
            }
        }
    } else if (op == HERMITE) {
        temp = spline_hermite_set(x.n, x.v, y.v, extra.v);
        if (!temp) {
            Error(ip, "Hermite spline construction failed");
            goto done;
        }
        if (Option(c, "deriv")) {
            dictionary = 1;
            ADD("yder1", nq);
        }
        for (int i = 0; i < nq; i++) {
            double yp;
            spline_hermite_val(x.n, x.v, temp, q.v[i], &out[0].v[i], &yp);
            if (dictionary) {
                out[1].v[i] = yp;
            }                
        }
    } else if (op == PCHIP) {
        temp = Allocate(ip, x.n);
        if (!temp) {
            goto done;
        }            
        spline_pchip_set(x.n, x.v, y.v, temp);
        spline_pchip_val(x.n, x.v, y.v, temp, q.n, q.v, out[0].v);
    }
    status = Publish(c, out, count, dictionary, vo);
done:
    free(x.owned);
    free(y.owned);
    free(q.owned);
    free(extra.owned);
    free(temp);
    free(b);
    free(cc);
    free(d);
    for (int i = 0; i < 6; i++) {
        free(out[i].v);
        if (out[i].name) {
            Tcl_DecrRefCount(out[i].name);
        }            
    }
    return status;
#undef ADD
}

#ifdef _WIN32
__declspec(dllexport)
#endif
int Tclinterp_Init(Tcl_Interp *ip) {
    if (!Tcl_InitStubs(ip, "9.0", 0)) {
        return TCL_ERROR;
    }
    if (!Tcl_FindNamespace(ip, "::tclinterp", NULL, TCL_GLOBAL_ONLY) &&
        !Tcl_CreateNamespace(ip, "::tclinterp", NULL, NULL)) {
        return TCL_ERROR;
    }
    Tcl_CreateObjCommand2(ip, "::tclinterp::native", NativeCmd, NULL, NULL);
    return Tcl_PkgProvide(ip, "tclinterp", PACKAGE_VERSION);
}
