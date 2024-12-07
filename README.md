![Static Badge](https://img.shields.io/badge/version-0.1-blue)

![Static Badge](https://img.shields.io/badge/license-GPL3-blue)

![Static Badge](https://img.shields.io/badge/Tcl_version-9.0-blue)

![Static Badge](https://img.shields.io/badge/Kubuntu_24.04-pass-green)

# Content

This package provides tcl wrapper for interpolation procedures.
The source of procedures is [Interpolation Routines](https://people.math.sc.edu/Burkardt/c_src/interp/interp.html).

# Installation and dependencies

For building you need:
- [SWIG of version 4.3](https://www.swig.org/download.html)
- [gcc compiler](https://gcc.gnu.org/)

For run you need:
- [Tcl9](https://www.tcl.tk/software/tcltk/9.0.html)
- [argparse](https://wiki.tcl-lang.org/page/argparse)
- [Tcllib](https://www.tcl.tk/software/tcllib/)

To compile, run `swig_gen.sh` to create SWIG wrapper file, then run 
```bash
./configure
make
sudo make install
```

# Supported platforms

For now the only system I've tested it is Kubuntu 24.04 with Tcl9

# Documentation

You can find some documentation [here](https://georgtree.github.io/tclinterp)
