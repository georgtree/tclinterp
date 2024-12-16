%module tclinterp
%{
    #include "interp.h"
    #include "spline.h"
%}
%include carrays.i
%include cpointer.i
%array_functions(double, doubleArray);
%pointer_functions(double, doublep);
/* linear interpolation */
extern double *interp_linear (int m, int data_num, double t_data[], double p_data[], int interp_num,
                              double t_interp[]);
extern int r8vec_ascends_strictly (int n, double x[]);
extern double *interp_nearest (int m, int data_num, double t_data[], double p_data[], int interp_num,
                               double t_interp[]);
extern double *interp_lagrange (int m, int data_num, double t_data[], double p_data[], int interp_num,
                                double t_interp[]);
/* spline interpolation */
/* least square */
extern void least_set (int point_num, double x[], double f[], double w[], int nterms, double b[], double c[],
                       double d[]);
extern double least_val (int nterms, double b[], double c[], double d[], double x);
extern void least_val2 (int nterms, double b[], double c[], double d[], double x, double *px, double *pxp);
/* Bezier functions */
extern void bc_val (int n, double t, double xcon[], double ycon[], double *xval, double *yval);
extern double bez_val (int n, double x, double a, double b, double y[]);
/* Divided difference interpolation */
extern void data_to_dif (int ntab, double xtab[], double ytab[], double diftab[]);
extern double dif_val (int ntab, double xtab[], double diftab[], double xval);
/* cubic B spline approximation */
extern double spline_b_val (int ndata, double tdata[], double ydata[], double tval);
/* cubic beta spline approximation */
extern double spline_beta_val (double beta1, double beta2, int ndata, double tdata[], double ydata[], double tval);
/* piecewise cubic spline interpolation */
extern double *spline_cubic_set (int n, double t[], double y[], int ibcbeg, double ybcbeg, int ibcend, double ybcend);
extern double spline_cubic_val (int n, double t[], double y[], double ypp[], double tval, double *ypval, double *yppval);
