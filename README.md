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
If you have different versions of Tcl on the same machine, you can set the path to this version with `--with-tcl=path`
flag to configure script.

For Windows build it is strongly recommended to use [MSYS64 UCRT64 environment](https://www.msys2.org/), the above
steps are identical if you run it from UCRT64 shell. 

The install targets honor `--prefix`, `--exec-prefix`, the standard directory options, and `DESTDIR`.
The runtime library, Tcl interface and `pkgIndex.tcl` are installed in `lib/tclinterp0.15`;
headers in `include`; manpages in `share/man/mann`; and HTML documentation, images and the
license in `share/tclinterp0.15/doc`, relative to the configured prefix by default (runtime libraries use `exec_prefix`).
Set both `--prefix` and `--exec-prefix` when relocating the complete installation.
`make uninstall` removes these installed files. Use the same directory overrides and `DESTDIR`
for installation and uninstallation. `DOC_INSTALL_DIR` can override the documentation destination;
an explicit override should include the staging directory when using `DESTDIR`.

```bash
./configure --with-tcl=/path/to/tcl/lib --prefix=/desired/prefix --exec-prefix=/desired/prefix
make
make install DESTDIR=/temporary/staging
make uninstall DESTDIR=/temporary/staging
```

`make dist` creates `dist/tclinterp0.15.tar.gz` from a staged `make install`.
`make dist-zip` also creates `dist/tclinterp0.15.zip` with the same payload. Extract the archive
contents into the desired install prefix: the archive contains `lib`, `include`, and `share`
according to the configured directories. All installation directories must be under `prefix`
for these targets. These are installation archives; development tests and examples stay in the
source checkout. `DIST_ROOT` and `DIST_NAME` override the output directory and archive basename.
`make dist-clean` removes the staging tree and archives.

Documentation is generated explicitly with `make doc`; installation and distribution use the
existing files in `docs` and do not require documentation tools. To regenerate them, install
Ruff!, Tcllib, argparse and Sphinx (`sphinx-build` on `PATH`). Optional diagram generation also
requires ditaa. Set `TCLLIBPATH` to locate Tcl dependencies and use `DOCFLAGS` to pass Ruff options.
The generated HTML and manpages are written into the source `docs` directory, including when
building out of tree. A documentation-generation failure makes `make doc` fail.

```bash
make doc TCLLIBPATH="/path/to/ruff /path/to/tcllib /path/to/argparse"
./config.status --recheck && ./config.status
```

Re-run configure with `config.status --recheck` after generating documentation so the configured HTML/static-file list
includes any newly generated files before running `make install` or `make dist`.

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
