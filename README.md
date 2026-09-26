# Content

This package provides tcl wrapper for interpolation and approximation procedures.
The sources of procedures are:
- [Linear interpolation routines](https://people.math.sc.edu/Burkardt/c_src/interp/interp.html)
- [Spline interpolation and approximation routines](https://people.math.sc.edu/Burkardt/c_src/spline/spline.html)

# Installation and dependencies

For building you need:
- [Tcl9](https://www.tcl.tk/software/tcltk/9.0.html)
- [gcc compiler](https://gcc.gnu.org/)
- [make tool](https://www.gnu.org/software/make/)

For run you also need:
- [argparse](https://github.com/georgtree/argparse)
- [Tcllib](https://www.tcl.tk/software/tcllib/)

To build, run 
```bash
./configure
make
sudo make install
```
If you have different versions of Tcl on the same machine, you can set the path to this version with `-with-tcl=path`
flag to configure script.

For Windows build it is strongly recommended to use [MSYS64 UCRT64 environment](https://www.msys2.org/), the above
steps are identical if you run it from UCRT64 shell. 

There are prebuilt packages that contains .so/.dll files, tcl code and tests for Windows and Linux.

# Supported platforms

I've tested it on:
- Kubuntu 24.04 with Tcl 9
- Windows 11 in MSYS64 UCRT64 environment with Tcl9

# Documentation

You can find some documentation [here](https://georgtree.github.io/tclinterp)

# Interactive help

All public procedures has interactive help. To get information about procedure and its arguments call it with `-help`
switch:

```tcl
package require tclinterp
namespace import ::tclinterp::interpolation::*
near1d -help
```

```text
Performs nearest-neighbor one-dimensional interpolation. Returns: The
interpolated values yi, as a Tcl list by default or an RBC vector name with
-output vector. Can accepts unambiguous prefixes instead of switches names.
Accepts switches only before parameters.
    Switches:
        -x value - Required. Sample positions; at least one value.
        -y value - Required. Sample values; must have the same length as -x.
        -xi value - Required. Evaluation positions; must not be empty.
        -input value - Input representation for all array arguments: Tcl lists
            or real RBC vector names. Defaults to list. Default value is list. Value
            must be one of: list or vector.
        -output value - Output representation for every numeric result array:
            Tcl list or RBC vector name. Defaults to list; independent of -input.
            Default value is list. Value must be one of: list or vector.
        -name value - Destination vector name for yi; requires -output vector.
            Omit it or use #auto to create an automatically named vector.
        -names value - Dictionary mapping output fields to destination vector
            names; requires -output vector. Valid fields: yi. Type dict.
        -ifexists value - Policy for existing destination vectors; defaults to
            error. With replace, an existing real vector is resized and overwritten.
            Default value is error. Value must be one of: error or replace.
        -help - Help switch, when provided, forces ignoring all other switches
            and parameters, prints the help message to stdout, and returns up to 2
            levels above the current level.

```

Best to do it in interactive console, see [tkcon](https://github.com/bohagan1/TkCon)
