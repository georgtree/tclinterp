%module tclinterp
%{
    #include "interp.h"
%}
%include carrays.i
%array_functions(double, doubleArray);
extern double *interp_linear (int m, int data_num, double t_data[], double p_data[], int interp_num,
                              double t_interp[]);
extern int r8vec_ascends_strictly (int n, double x[]);
extern double *interp_nearest (int m, int data_num, double t_data[], double p_data[], int interp_num,
                               double t_interp[]);
extern double *interp_lagrange (int m, int data_num, double t_data[], double p_data[], int interp_num,
                                double t_interp[]);
