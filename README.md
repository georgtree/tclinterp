![Static Badge](https://img.shields.io/badge/version-0.15-blue)

![Static Badge](https://img.shields.io/badge/license-LGPL2.1-blue)

![Static Badge](https://img.shields.io/badge/Tcl_version-9.0-blue)
![Static Badge](https://img.shields.io/badge/Tcl_version-8.6.15-blue)

![Static Badge](https://img.shields.io/badge/Kubuntu_24.04-pass-green)

![Static Badge](https://img.shields.io/badge/Windows_11-pass-green)

![Static Badge](https://img.shields.io/badge/Tcl_coverage-99.3%25-green)

# Content

This package provides tcl wrapper for interpolation and approximation procedures.
The sources of procedures are:
- [Linear interpolation routines](https://people.math.sc.edu/Burkardt/c_src/interp/interp.html)
- [Spline interpolation and approximation routines](https://people.math.sc.edu/Burkardt/c_src/spline/spline.html)

# Installation and dependencies

For building you need:
- [SWIG of version 4.3](https://www.swig.org/download.html)
- [Tcl9](https://www.tcl.tk/software/tcltk/9.0.html) or [Tcl8.6.15](https://www.tcl.tk/software/tcltk/8.6.html)
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
- Kubuntu 24.04 with Tcl 9 and Tcl 8.6.15
- Windows 11 in MSYS64 UCRT64 environment with Tcl9

# Documentation

You can find some documentation [here](https://georgtree.github.io/tclinterp)

# Interactive help

All public procedures has interactive help. To get information about procedure and its arguments call it with `-help`
switch:

``` tcl
package require tclinterp
namespace import ::tclinterp::interpolation::*
near1d -help
```

``` text
Does nearest one-dimensional interpolation. Returns: list of interpolated
dependent variable values, 'yi', at 'xi'. Can accepts unambiguous prefixes
instead of switches names. Accepts switches only before parameters.
    Switches:
        -x - Required, expects argument. List of independent variable (x)
            values, must be strictly increasing.
        -y - Required, expects argument. List of dependent variable (y) values.
        -xi - Required, expects argument. list of independent variable
            interpolation (xi) values.
```

Best to do it in interactive console, see [tkcon](https://github.com/bohagan1/TkCon)
