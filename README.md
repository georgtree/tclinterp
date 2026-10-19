# tclinterp - interpolation and approximation with Tcl

`tclinterp` provides Tcl commands for interpolation and approximation using John Burkardt's
[interpolation](https://people.math.sc.edu/Burkardt/c_src/interp/interp.html) and
[spline](https://people.math.sc.edu/Burkardt/c_src/spline/spline.html) routines.

A thin Tcl interface provides argument parsing and interactive help; native Tcl C bindings handle numeric conversion,
allocation, evaluation and cleanup. SWIG is not required.

## What it gives you (at a glance)

- Linear, nearest-neighbor, Lagrange, least-squares and divided-difference interpolation.
- Cubic, Hermite and PCHIP interpolation, plus Bezier, B-spline and beta-spline approximation.
- Tcl list input and output by default, with optional real RBC vector input and output.
- Named or automatically created output vectors, including multiple-result dictionaries.
- Interactive `-help` for every public procedure.

Interpolation commands are in `::tclinterp::interpolation`; approximation commands are in `::tclinterp::approximation`.

## Building & requirements

For building, you need Tcl 9 development files, a C compiler and make. At runtime, install
[argparse](https://github.com/georgtree/argparse) 0.65 or later and [Tcllib](https://www.tcl.tk/software/tcllib/). RBC
is optional; see below for vector support.

```sh
./configure
make
make test
sudo make install
```

Use `--with-tcl=/path/to/tcl/lib` to select the directory containing the desired `tclConfig.sh`.  Ensure Tcl
dependencies are discoverable through `auto_path` or `TCLLIBPATH`.

For Windows, use the [MSYS2 UCRT64 environment](https://www.msys2.org/) and run the same build commands from its
shell. The package has been tested on Kubuntu 24.04 and Windows 11 (UCRT64) with Tcl 9.

## Documentation

The [online documentation](https://georgtree.github.io/tclinterp) describes each command, its arguments and return
values. Interactive help is also available:

```tcl
package require tclinterp
::tclinterp::interpolation::lin1d -help
```

## Quick start

```tcl
package require tclinterp
namespace import ::tclinterp::interpolation::*

set yi [lin1d -x {0 1 2} -y {0 2 4} -xi {0.5 1.5}]
puts $yi
# 1.0 3.0
```

List calls retain the existing public interface and do not load RBC or Tk.

## Optional direct RBC vector input and output

Build with RBC 0.8.1 or later headers to enable vectors:

```sh
./configure --with-tcl=/path/to/tcl/lib --with-rbc=/path/to/rbc
make
make test
make install
```

`--with-rbc` accepts an RBC source root, an include directory, or an installation prefix.  The selected location must
provide `rbcVector.h`, `rbcDecls.h` and `rbcStubLib.c`.  The extension uses RBC stubs; vector operations require the
`rbc::vector` package, version 0.8.1 or later, at runtime. Without `--with-rbc`, list operations work normally and
vector requests report that support is unavailable.

Input and output representations are independent:

| Option              | Meaning                                                                                                   |
|---------------------|-----------------------------------------------------------------------------------------------------------|
| `-input list`       | All numeric array inputs are Tcl lists (default).                                                         |
| `-input vector`     | All numeric array inputs are real RBC vector names. Scalar arguments are unchanged.                       |
| `-output list`      | Return numeric arrays as Tcl lists (default).                                                             |
| `-output vector`    | Return fully qualified vector names in place of numeric arrays; dictionary structure is preserved.        |
| `-namespace name` | Destination namespace for vector output; created with missing parents, relative to the caller. |
| `-name name`        | Name the primary `yi` output vector. Omit it or use `#auto` for automatic naming.                         |
| `-names dictionary` | Map output fields to destination names. Each omitted field or `#auto` destination is automatically named. |
| `-ifexists error`   | Reject existing destination vectors (initial default).                                                            |
| `-ifexists replace` | Resize and overwrite existing writable real destination vectors.                                          |

The naming and replacement options require `-output vector`. Valid output fields depend on the command; consult its
help. Do not combine `-name` with a `yi` entry in `-names`. Unknown fields and duplicate destinations are errors.

```tcl
package require tclinterp
package require rbc::vector 0.8.1

namespace eval ::demo {}
::rbc::vector create ::demo::x ::demo::y ::demo::xi -variable {}
::demo::x set {0 1 2}
::demo::y set {0 2 4}
::demo::xi set {0.5 1.5}

set result [::tclinterp::interpolation::lin1d -input vector -x ::demo::x -y ::demo::y -xi ::demo::xi\
                   -output vector -name #auto]
puts [$result index :]

# The caller owns the returned vector.
::rbc::vector destroy $result ::demo::x ::demo::y ::demo::xi
```

Input names resolve in the caller's namespace. Output names use `-namespace`, or the caller's namespace when omitted.
Relative namespace options resolve against the caller and create missing parents; empty namespaces are rejected.
Fully qualified output names override the selected namespace, but their parent must already exist. Omitted names and
a final `#auto` component use RBC's automatic naming in the selected namespace; `auto` is an ordinary name.
Returned names are fully qualified.  The caller must destroy output vectors when
they are no longer needed. Use `-name` or `-names` with `-ifexists replace` to reuse destinations across repeated calls.

Only real vectors are supported, and numeric inputs must be finite. Read-only vectors are valid inputs, but locked
destinations cannot be overwritten, even with `-ifexists replace`.  New output vectors are writable.

The Tcl test suite runs with `make test`. Vector tests require both an RBC-enabled build and a loadable `rbc::vector`
package; otherwise those tests are skipped. Set `TCLLIBPATH` as needed.  The vector interface does not require loading
Tk or opening a display.

## Installation layout and removal

The install targets honor `--prefix`, `--exec-prefix`, standard directory options and `DESTDIR`.
The default layout is:

| Files                                             | Destination                                  |
|---------------------------------------------------|----------------------------------------------|
| Runtime library, Tcl interface and `pkgIndex.tcl` | `$(libdir)/tclinterp$(PACKAGE_VERSION)`      |
| Public C headers                                  | `$(includedir)`                              |
| Manpages                                          | `$(mandir)/mann`                             |
| HTML documentation, assets and license            | `$(datadir)/tclinterp$(PACKAGE_VERSION)/doc` |

For version 0.3, the default package directory name is `tclinterp0.3`. Set both `--prefix` and `--exec-prefix` when
relocating the complete installation:

```sh
./configure --with-tcl=/path/to/tcl/lib \
    --prefix=/desired/prefix --exec-prefix=/desired/prefix
make
make install DESTDIR=/temporary/staging
make uninstall DESTDIR=/temporary/staging
```

`make uninstall` removes the package runtime directory and its installed headers, manpages and documentation. Keep the
corresponding source and configured build directory, and use the same directory overrides and `DESTDIR` for installation
and removal. Unrelated documentation files are preserved.

`DOC_INSTALL_DIR` overrides the documentation destination. Its default includes `DESTDIR`; an explicit override must
include the staging directory when staging an installation.

## Installation archives

`make dist` stages `make install` and creates `dist/tclinterp0.3.tar.gz` in the build directory.  `make dist-zip` also
creates `dist/tclinterp0.3.zip` with the same payload.  These are platform-specific installation archives, not source
archives; development tests and examples remain in the source checkout.

Extract an archive into the desired installation prefix. Its contents use the configured `lib`, `include` and `share`
layout without an enclosing package directory. All configured installation directories must be beneath `prefix` for
these targets. `DESTDIR` is not included in archive paths.

`DIST_ROOT` overrides the staging/output directory; `DIST_NAME` overrides the archive basename and must be a single
directory name. `make dist-clean` removes the staging tree and archives.  Do not run `dist-clean` concurrently with
archive creation.

## Regenerating documentation

`make doc` generates documentation explicitly. Installation and archive targets use the files already in `docs` and do
not require documentation tools.

To regenerate them, install Ruff!, Tcllib, argparse and Sphinx (`sphinx-build` on `PATH`).  Optional diagram generation
also requires ditaa. Use `TCLLIBPATH` to locate Tcl dependencies and `DOCFLAGS` to pass Ruff options:

```sh
make doc TCLLIBPATH="/path/to/ruff /path/to/tcllib /path/to/argparse"
./config.status --recheck && ./config.status
```

Generated HTML and manpages are written into the source `docs` directory, including for out-of-tree
builds. Documentation-generation errors make `make doc` fail. Re-run configuration after generation, as shown above, so
newly generated HTML and static assets are included in the configured file list before `make install` or `make dist`.

