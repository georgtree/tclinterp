![Static Badge](https://img.shields.io/badge/version-0.1-blue)

![Static Badge](https://img.shields.io/badge/license-GPL3-blue)

![Static Badge](https://img.shields.io/badge/Tcl_version-9.0-blue)

![Static Badge](https://img.shields.io/badge/Kubuntu_24.04-pass-green)

# Content

This package provides tcl wrapper for interpolation procedures.
The source of procedures is [Interpolation Routines](https://people.math.sc.edu/Burkardt/c_src/interp/interp.html).

# Installation and dependencies

To install this package just unzip code to folder and append `auto_path` variable with location.

For compile you need:
- [SWIG of version 4.3](https://www.swig.org/download.html)
- [gcc compiler](https://gcc.gnu.org/)
- Tcl9 stubs object file libtclstub.a - usually located at `/usr/local/lib/`, but location could differ on your
  system

For run you need:
- [Tcl9](https://www.tcl.tk/software/tcltk/9.0.html)
- [argparse](https://wiki.tcl-lang.org/page/argparse)
- [Tcllib](https://www.tcl.tk/software/tcllib/)

To compile, run `swig_gen.sh` to create SWIG wrapper file, and the run `make`. If you have stubs object file in
non-standard location or with different name, add it to `Makefile`:

```make
$(CC) -shared  $(BUILD)/tclinterp.o $(BUILD)/tclinterp_wrap.o /usr/local/lib/libtclstub.a -o $(BUILD)/tclinterp.so
```

Then the shared file will be located at `/build` folder, the remaining part is to add `tclinterp` to `auto_path`.

# Supported platforms

For now the only system I've tested it is Kubuntu 24.04 with Tcl9

# Documentation

You can find some documentation [here](https://georgtree.github.io/tclinterp)
