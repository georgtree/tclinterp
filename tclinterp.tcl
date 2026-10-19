package require argparse 0.65
package provide tclinterp 0.3

namespace eval ::tclinterp {
    namespace import ::tcl::mathop::*
    namespace eval interpolation {
        namespace export lin1d near1d lagr1d least1d least1dDer divDif1d cubicSpline1d hermiteSpline1d pchip1d
    }
    namespace eval approximation {
        namespace export genBezier bezier cubicBSpline1d cubicBetaSpline1d
    }
}

proc ::tclinterp::configure {args} {
    # Queries or changes package-wide representation and collision defaults in this Tcl interpreter.
    #  -input mode - Default input representation: list or vector; initially list.
    #  -output mode - Default output representation: list or vector; initially list.
    #  -ifexists policy - Default destination collision policy: error or replace; initially error.
    #
    # With no arguments, returns all settings as an option/value dictionary. With one option, returns its value.
    # With option/value pairs, validates all settings before applying them and returns the complete configuration.
    # Invalid options or values, or unavailable RBC support leave the configuration unchanged. Selecting
    # vector mode requires an RBC-enabled build and a loadable rbc::vector package; list queries/settings do not
    # load RBC. Defaults are independent in separate interpreters.
    #
    # Omitted -input, -output and -ifexists options use these defaults on each interpolation call. Explicit call options
    # take precedence. Input and output modes can be configured independently.
    # This public command is not namespace-exported; call it as ::tclinterp::configure.
    # The collision policy affects vector output only; it can be configured while using list mode or without RBC.
    # Replacement still requires a compatible, writable destination. Namespace selection and naming are unchanged.
    #
    # Example:
    # ```tcl
    # set saved [::tclinterp::configure]
    # ::tclinterp::configure -input vector -output vector -ifexists replace
    # ::tclinterp::configure -output
    # ::tclinterp::configure {*}$saved
    # ```
    #
    # Synopsis: ?option?
    # Synopsis: ?-input list|vector? ?-output list|vector? ?-ifexists error|replace?
    # Returns: selected option value for a single-option query; otherwise all settings as a dictionary.
    if {([llength $args]==1) && ([lindex $args 0] ne {-help})} {
        set arguments [argparse -inline -help {Query package defaults. With no arguments returns all settings.} {
            {-input -key query -value input -help {Query the default input representation}}
            {-output -key query -value output -help {Query the default output representation}}
            {-ifexists -key query -value ifexists -help {Query the default collision policy}}
        }]
        return [NativeConfigure [dict get $arguments query] {}]
    }
    set arguments [argparse -inline -help {Query or change package defaults atomically. Defaults are local to this\
                                                   interpreter.} {
        {-input= -enum {list vector} -help {Default input representation: list or vector}}
        {-output= -enum {list vector} -help {Default output representation: list or vector}}
        {-ifexists= -enum {error replace} -help {Default collision policy: error or replace}}
    }]
    return [NativeConfigure {} $arguments]
}

proc ::tclinterp::interpolation::lin1d {args} {
    # Performs linear one-dimensional interpolation.
    #  -x values - Strictly increasing sample positions; at least two values.
    #  -y values - Sample values; must have the same length as -x.
    #  -xi values - Evaluation positions; must not be empty.
    #  -input list|vector - Input representation for all array arguments: Tcl lists or real RBC vector names.
    #    Defaults to the package setting (initially list).
    #  -output list|vector - Output representation for every numeric result array: Tcl list or RBC vector name.
    #    Defaults to the package setting (initially list); independent of -input.
    #  -namespace name - Destination namespace for vector output; relative to the caller, created with missing parents.
    #  -name name - Destination vector name for yi; requires -output vector. Omit it or use #auto to create an
    #    automatically named vector.
    #  -names dictionary - Dictionary mapping output fields to destination vector names; requires -output
    #    vector. Valid fields: `yi`.
    #  -ifexists error|replace - Policy for existing destination vectors; uses the package default (initially error).
    #    With replace, an existing real vector is resized and overwritten.
    #
    # Every array argument marked `values` uses the representation selected by -input. Scalar options remain
    # ordinary Tcl numbers. Numeric inputs must be finite. RBC support must be enabled in the build to use
    # vectors.
    #
    # Omitted -input, -output and -ifexists use ::tclinterp::configure defaults at call time. Explicit options take
    # precedence.
    #
    # Input vector names resolve in the caller's namespace. Output names use -namespace, or the caller's namespace
    # when omitted. Empty namespace names are rejected; -namespace requires -output vector. Fully qualified output
    # names override this location; their parent namespace must already exist. Each unnamed output, including fields
    # omitted from -names, uses RBC's #auto mechanism in the selected namespace. A final #auto component also works
    # in qualified names; auto without # is an ordinary name. Returned vector names are fully qualified.
    #
    # Do not specify both -name and the `yi` entry of -names. Unknown output fields and duplicate destinations
    # are errors. The caller owns returned vectors and can release them with `::rbc::vector destroy
    # $vectorName`.
    #
    # Returns: The interpolated values `yi`, as a Tcl list with list output or an RBC vector name with `-output
    # vector`.
    #
    # Synopsis: -x values -y values -xi values ?-input list|vector? ?-output list|vector? ?-namespace name? ?-name name?
    # ?-names dictionary? ?-ifexists error|replace?
    set arguments [argparse -inline -help {Performs linear one-dimensional interpolation. Returns: The interpolated\
                                                   values yi, as a Tcl list with list output or an RBC vector name with\
                                                   -output vector} {
        {-x!= -help {Strictly increasing sample positions; at least two values}}
        {-y!= -help {Sample values; must have the same length as -x}}
        {-xi!= -help {Evaluation positions; must not be empty}}
        {-input= -enum {list vector} -help {Input representation for all array arguments: Tcl lists or real RBC vector\
                                                    names. Defaults to the package setting (initially list)}}
        {-output= -enum {list vector} -help {Output representation for every numeric result array: Tcl list or RBC\
                                                     vector name. Defaults to the package setting (initially list);\
                                                     independent of -input}}
        {-namespace= -help {Destination namespace for vector output; relative to the caller, created if missing}}
        {-name= -help {Destination vector name for yi; requires -output vector. Omit it or use #auto to create an\
                            automatically named vector}}
        {-names= -type dict -help {Dictionary mapping output fields to destination vector names; requires -output\
                                           vector. Valid fields: yi}}
        {-ifexists= -enum {error replace} -help {Policy for existing destination vectors; uses the package default\
                                                                        (initially error). With replace, an existing\
                                                                        real vector is resized and overwritten}}
    }]
    return [uplevel 1 [list ::tclinterp::native lin1d $arguments]]
}

proc ::tclinterp::interpolation::near1d {args} {
    # Performs nearest-neighbor one-dimensional interpolation.
    #  -x values - Sample positions; at least one value.
    #  -y values - Sample values; must have the same length as -x.
    #  -xi values - Evaluation positions; must not be empty.
    #  -input list|vector - Input representation for all array arguments: Tcl lists or real RBC vector names.
    #    Defaults to the package setting (initially list).
    #  -output list|vector - Output representation for every numeric result array: Tcl list or RBC vector name.
    #    Defaults to the package setting (initially list); independent of -input.
    #  -namespace name - Destination namespace for vector output; relative to the caller, created with missing parents.
    #  -name name - Destination vector name for yi; requires -output vector. Omit it or use #auto to create an
    #    automatically named vector.
    #  -names dictionary - Dictionary mapping output fields to destination vector names; requires -output
    #    vector. Valid fields: `yi`.
    #  -ifexists error|replace - Policy for existing destination vectors; uses the package default (initially error).
    #    With replace, an existing real vector is resized and overwritten.
    #
    # Every array argument marked `values` uses the representation selected by -input. Scalar options remain
    # ordinary Tcl numbers. Numeric inputs must be finite. RBC support must be enabled in the build to use
    # vectors.
    #
    # Omitted -input, -output and -ifexists use ::tclinterp::configure defaults at call time. Explicit options take
    # precedence.
    # Input vector names resolve in the caller's namespace. Output names use -namespace, or the caller's namespace
    # when omitted. Empty namespace names are rejected; -namespace requires -output vector. Fully qualified output
    # names override this location; their parent namespace must already exist. Each unnamed output, including fields
    # omitted from -names, uses RBC's #auto mechanism in the selected namespace. A final #auto component also works
    # in qualified names; auto without # is an ordinary name. Returned vector names are fully qualified.
    #
    # Do not specify both -name and the `yi` entry of -names. Unknown output fields and duplicate destinations
    # are errors. The caller owns returned vectors and can release them with `::rbc::vector destroy
    # $vectorName`.
    #
    # Returns: The interpolated values `yi`, as a Tcl list with list output or an RBC vector name with `-output
    # vector`.
    #
    # Synopsis: -x values -y values -xi values ?-input list|vector? ?-output list|vector? ?-namespace name? ?-name name?
    # ?-names dictionary? ?-ifexists error|replace?
    set arguments [argparse -inline -help {Performs nearest-neighbor one-dimensional interpolation. Returns: The\
                                                   interpolated values yi, as a Tcl list with list output or an RBC\
                                                   vector name with -output vector} {
        {-x= -required -help {Sample positions; at least one value}}
        {-y= -required -help {Sample values; must have the same length as -x}}
        {-xi= -required -help {Evaluation positions; must not be empty}}
        {-input= -enum {list vector} -help {Input representation for all array arguments: Tcl lists or real RBC vector\
                                                    names. Defaults to the package setting (initially list)}}
        {-output= -enum {list vector} -help {Output representation for every numeric result array: Tcl list or RBC\
                                                     vector name. Defaults to the package setting (initially list);\
                                                     independent of -input}}
        {-namespace= -help {Destination namespace for vector output; relative to the caller, created if missing}}
        {-name= -help {Destination vector name for yi; requires -output vector. Omit it or use #auto to create an\
                            automatically named vector}}
        {-names= -type dict -help {Dictionary mapping output fields to destination vector names; requires -output\
                                           vector. Valid fields: yi}}
        {-ifexists= -enum {error replace} -help {Policy for existing destination vectors; uses the package default\
                                                                        (initially error). With replace, an existing real vector is\
                                                                        resized and overwritten}}
    }]
    return [uplevel 1 [list ::tclinterp::native near1d $arguments]]
}

proc ::tclinterp::interpolation::lagr1d {args} {
    # Performs Lagrange polynomial one-dimensional interpolation.
    #  -x values - Distinct sample positions; at least one value.
    #  -y values - Sample values; must have the same length as -x.
    #  -xi values - Evaluation positions; must not be empty.
    #  -input list|vector - Input representation for all array arguments: Tcl lists or real RBC vector names.
    #    Defaults to the package setting (initially list).
    #  -output list|vector - Output representation for every numeric result array: Tcl list or RBC vector name.
    #    Defaults to the package setting (initially list); independent of -input.
    #  -namespace name - Destination namespace for vector output; relative to the caller, created with missing parents.
    #  -name name - Destination vector name for yi; requires -output vector. Omit it or use #auto to create an
    #    automatically named vector.
    #  -names dictionary - Dictionary mapping output fields to destination vector names; requires -output
    #    vector. Valid fields: `yi`.
    #  -ifexists error|replace - Policy for existing destination vectors; uses the package default (initially error).
    #    With replace, an existing real vector is resized and overwritten.
    #
    # Every array argument marked `values` uses the representation selected by -input. Scalar options remain
    # ordinary Tcl numbers. Numeric inputs must be finite. RBC support must be enabled in the build to use
    # vectors.
    #
    # Omitted -input, -output and -ifexists use ::tclinterp::configure defaults at call time. Explicit options take
    # precedence.
    #
    # Input vector names resolve in the caller's namespace. Output names use -namespace, or the caller's namespace
    # when omitted. Empty namespace names are rejected; -namespace requires -output vector. Fully qualified output
    # names override this location; their parent namespace must already exist. Each unnamed output, including fields
    # omitted from -names, uses RBC's #auto mechanism in the selected namespace. A final #auto component also works
    # in qualified names; auto without # is an ordinary name. Returned vector names are fully qualified.
    #
    # Do not specify both -name and the `yi` entry of -names. Unknown output fields and duplicate destinations
    # are errors. The caller owns returned vectors and can release them with `::rbc::vector destroy
    # $vectorName`.
    #
    # Returns: The interpolated values `yi`, as a Tcl list with list output or an RBC vector name with `-output
    # vector`.
    #
    # Synopsis: -x values -y values -xi values ?-input list|vector? ?-output list|vector? ?-namespace name? ?-name name?
    # ?-names dictionary? ?-ifexists error|replace?
    set arguments [argparse -inline -help {Performs Lagrange polynomial one-dimensional interpolation. Returns: The\
                                                   interpolated values yi, as a Tcl list with list output or an RBC\
                                                   vector name with -output vector} {
        {-x= -required -help {Distinct sample positions; at least one value}}
        {-y= -required -help {Sample values; must have the same length as -x}}
        {-xi= -required -help {Evaluation positions; must not be empty}}
        {-input= -enum {list vector} -help {Input representation for all array arguments: Tcl lists or real RBC vector\
                                                    names. Defaults to the package setting (initially list)}}
        {-output= -enum {list vector} -help {Output representation for every numeric result array: Tcl list or RBC\
                                                     vector name. Defaults to the package setting (initially list);\
                                                     independent of -input}}
        {-namespace= -help {Destination namespace for vector output; relative to the caller, created if missing}}
        {-name= -help {Destination vector name for yi; requires -output vector. Omit it or use #auto to create an\
                            automatically named vector}}
        {-names= -type dict -help {Dictionary mapping output fields to destination vector names; requires -output\
                                           vector. Valid fields: yi}}
        {-ifexists= -enum {error replace} -help {Policy for existing destination vectors; uses the package default\
                                                         (initially error). With replace, an existing real vector is\
                                                         resized and overwritten}}
    }]
    return [uplevel 1 [list ::tclinterp::native lagr1d $arguments]]
}

proc ::tclinterp::interpolation::least1d {args} {
    # Fits a least-squares polynomial.
    #  -x values - Sample positions; at least one value.
    #  -y values - Sample values; must have the same length as -x.
    #  -xi values - Evaluation positions; must not be empty.
    #  -w values - Optional positive weights; same length as -x. Defaults to all ones.
    #  -nterms integer - Number of polynomial terms; defaults to 3. Must be positive and no greater than the
    #    number of distinct sample positions.
    #  -coeffs - Include polynomial coefficient arrays in the result dictionary.
    #  -input list|vector - Input representation for all array arguments: Tcl lists or real RBC vector names.
    #    Defaults to the package setting (initially list).
    #  -output list|vector - Output representation for every numeric result array: Tcl list or RBC vector name.
    #    Defaults to the package setting (initially list); independent of -input.
    #  -namespace name - Destination namespace for vector output; relative to the caller, created with missing parents.
    #  -name name - Destination vector name for yi; requires -output vector. Omit it or use #auto to create an
    #    automatically named vector.
    #  -names dictionary - Dictionary mapping output fields to destination vector names; requires -output
    #    vector. Valid fields: `yi`, and, only with -coeffs, `coeffs.b`, `coeffs.c`, `coeffs.d`.
    #  -ifexists error|replace - Policy for existing destination vectors; uses the package default (initially error).
    #    With replace, an existing real vector is resized and overwritten.
    #
    # Every array argument marked `values` uses the representation selected by -input. Scalar options remain
    # ordinary Tcl numbers. Numeric inputs must be finite. RBC support must be enabled in the build to use
    # vectors.
    #
    # Omitted -input, -output and -ifexists use ::tclinterp::configure defaults at call time. Explicit options take
    # precedence.
    #
    # Input vector names resolve in the caller's namespace. Output names use -namespace, or the caller's namespace
    # when omitted. Empty namespace names are rejected; -namespace requires -output vector. Fully qualified output
    # names override this location; their parent namespace must already exist. Each unnamed output, including fields
    # omitted from -names, uses RBC's #auto mechanism in the selected namespace. A final #auto component also works
    # in qualified names; auto without # is an ordinary name. Returned vector names are fully qualified.
    #
    # Do not specify both -name and the `yi` entry of -names. Unknown output fields and duplicate destinations
    # are errors. The caller owns returned vectors and can release them with `::rbc::vector destroy
    # $vectorName`.
    #
    # Returns: The fitted values `yi`, or a dictionary containing `yi` when `-coeffs` is specified. With
    # `-coeffs`, the dictionary also contains `coeffs`, a nested dictionary with keys `b`, `c`, and `d`. Each
    # numeric array is a Tcl list with list output or an RBC vector name with `-output vector`.
    #
    # Synopsis: -x values -y values -xi values ?-w values? ?-nterms integer? ?-coeffs? ?-input list|vector?
    #   ?-output list|vector? ?-namespace name? ?-name name? ?-names dictionary? ?-ifexists error|replace?
    set arguments [argparse -inline -help {Fits a least-squares polynomial. Returns: The fitted values yi, or a\
                                                   dictionary containing yi when -coeffs is specified. With -coeffs,\
                                                   the dictionary also contains coeffs, a nested dictionary with keys\
                                                   b, c, and d. Each numeric array is a Tcl list with list output or an\
                                                   RBC vector name with -output vector} {
        {-x= -required -help {Sample positions; at least one value}}
        {-y= -required -help {Sample values; must have the same length as -x}}
        {-xi= -required -help {Evaluation positions; must not be empty}}
        {-w= -help {Optional positive weights; same length as -x. Defaults to all ones}}
        {-nterms= -default 3 -type integer -validate {$arg>0}\
                 -errormsg {Number of terms -nterms must be more than zero}\
                 -help {Number of polynomial terms; defaults to 3. Must be positive and no greater than the number of\
                                distinct sample positions}}
        {-coeffs -help {Include polynomial coefficient arrays in the result dictionary}}
        {-input= -enum {list vector} -help {Input representation for all array arguments: Tcl lists or real RBC vector\
                                                    names. Defaults to the package setting (initially list)}}
        {-output= -enum {list vector} -help {Output representation for every numeric result array: Tcl list or RBC\
                                                     vector name. Defaults to the package setting (initially list);\
                                                     independent of -input}}
        {-namespace= -help {Destination namespace for vector output; relative to the caller, created if missing}}
        {-name= -help {Destination vector name for yi; requires -output vector. Omit it or use #auto to create an\
                               automatically named vector}}
        {-names= -type dict -help {Dictionary mapping output fields to destination vector names; requires -output\
                                           vector. Valid fields: yi}}
        {-ifexists= -enum {error replace} -help {Policy for existing destination vectors; uses the package default\
                                                         (initially error). With replace, an existing real vector is\
                                                         resized and overwritten}}
    }]
    return [uplevel 1 [list ::tclinterp::native least1d $arguments]]
}

proc ::tclinterp::interpolation::least1dDer {args} {
    # Fits a least-squares polynomial and evaluates its first derivative.
    #  -x values - Sample positions; at least one value.
    #  -y values - Sample values; must have the same length as -x.
    #  -xi values - Evaluation positions; must not be empty.
    #  -w values - Optional positive weights; same length as -x. Defaults to all ones.
    #  -nterms integer - Number of polynomial terms; defaults to 3. Must be positive and no greater than the
    #    number of distinct sample positions.
    #  -coeffs - Include polynomial coefficient arrays in the result dictionary.
    #  -input list|vector - Input representation for all array arguments: Tcl lists or real RBC vector names.
    #    Defaults to the package setting (initially list).
    #  -output list|vector - Output representation for every numeric result array: Tcl list or RBC vector name.
    #    Defaults to the package setting (initially list); independent of -input.
    #  -namespace name - Destination namespace for vector output; relative to the caller, created with missing parents.
    #  -name name - Destination vector name for yi; requires -output vector. Omit it or use #auto to create an
    #    automatically named vector.
    #  -names dictionary - Dictionary mapping output fields to destination vector names; requires -output
    #    vector. Valid fields: `yi`, `yiDer`, and, only with -coeffs, `coeffs.b`, `coeffs.c`, `coeffs.d`.
    #  -ifexists error|replace - Policy for existing destination vectors; uses the package default (initially error).
    #    With replace, an existing real vector is resized and overwritten.
    #
    # Every array argument marked `values` uses the representation selected by -input. Scalar options remain
    # ordinary Tcl numbers. Numeric inputs must be finite. RBC support must be enabled in the build to use
    # vectors.
    #
    # Omitted -input, -output and -ifexists use ::tclinterp::configure defaults at call time. Explicit options take
    # precedence.
    #
    # Input vector names resolve in the caller's namespace. Output names use -namespace, or the caller's namespace
    # when omitted. Empty namespace names are rejected; -namespace requires -output vector. Fully qualified output
    # names override this location; their parent namespace must already exist. Each unnamed output, including fields
    # omitted from -names, uses RBC's #auto mechanism in the selected namespace. A final #auto component also works
    # in qualified names; auto without # is an ordinary name. Returned vector names are fully qualified.
    #
    # Do not specify both -name and the `yi` entry of -names. Unknown output fields and duplicate destinations
    # are errors. The caller owns returned vectors and can release them with `::rbc::vector destroy
    # $vectorName`.
    #
    # Returns: A dictionary with `yi` values and `yiDer` first derivatives. With `-coeffs`, the dictionary also
    # contains `coeffs`, a nested dictionary with keys `b`, `c`, and `d`. Each numeric array is a Tcl list with
    # list output or an RBC vector name with `-output vector`.
    #
    # Synopsis: -x values -y values -xi values ?-w values? ?-nterms integer? ?-coeffs? ?-input list|vector?
    #   ?-output list|vector? ?-namespace name? ?-name name? ?-names dictionary? ?-ifexists error|replace?
    set arguments [argparse -inline -help {Fits a least-squares polynomial and evaluates its first derivative. Returns:\
                                                   A dictionary with yi values and yiDer first derivatives. With\
                                                   -coeffs, the dictionary also contains coeffs, a nested dictionary\
                                                   with keys b, c, and d. Each numeric array is a Tcl list with list\
                                                   output or an RBC vector name with -output vector} {
        {-x= -required -help {Sample positions; at least one value}}
        {-y= -required -help {Sample values; must have the same length as -x}}
        {-xi= -required -help {Evaluation positions; must not be empty}}
        {-w= -help {Optional positive weights; same length as -x. Defaults to all ones}}
        {-nterms= -default 3 -type integer -validate {$arg>0}\
                 -errormsg {Number of terms -nterms must be more than zero}\
                 -help {Number of polynomial terms; defaults to 3. Must be positive and no greater than the number of\
                            distinct sample positions}}
        {-coeffs -help {Include polynomial coefficient arrays in the result dictionary}}
        {-input= -enum {list vector} -help {Input representation for all array arguments: Tcl lists or real RBC vector\
                                                    names. Defaults to the package setting (initially list)}}
        {-output= -enum {list vector} -help {Output representation for every numeric result array: Tcl list or RBC\
                                                     vector name. Defaults to the package setting (initially list);\
                                                     independent of -input}}
        {-namespace= -help {Destination namespace for vector output; relative to the caller, created if missing}}
        {-name= -help {Destination vector name for yi; requires -output vector. Omit it or use #auto to create an\
                            automatically named vector}}
        {-names= -type dict -help {Dictionary mapping output fields to destination vector names; requires -output\
                                           vector. Valid fields: yi}}
        {-ifexists= -enum {error replace} -help {Policy for existing destination vectors; uses the package default\
                                                         (initially error). With replace, an existing real vector is\
                                                         resized and overwritten}}
    }]
    return [uplevel 1 [list ::tclinterp::native least1dDer $arguments]]
}

proc ::tclinterp::approximation::genBezier {args} {
    # Evaluates a parametric Bezier curve.
    #  -n integer - Curve degree; must be zero or greater.
    #  -x values - X control coordinates; exactly n+1 values.
    #  -y values - Y control coordinates; exactly n+1 values.
    #  -t values - Nonempty evaluation parameters; normally between 0 and 1.
    #  -input list|vector - Input representation for all array arguments: Tcl lists or real RBC vector names.
    #    Defaults to the package setting (initially list).
    #  -output list|vector - Output representation for every numeric result array: Tcl list or RBC vector name.
    #    Defaults to the package setting (initially list); independent of -input.
    #  -namespace name - Destination namespace for vector output; relative to the caller, created with missing parents.
    #  -name name - Destination vector name for yi; requires -output vector. Omit it or use #auto to create an
    #    automatically named vector.
    #  -names dictionary - Dictionary mapping output fields to destination vector names; requires -output
    #    vector. Valid fields: `xi`, `yi`.
    #  -ifexists error|replace - Policy for existing destination vectors; uses the package default (initially error).
    #    With replace, an existing real vector is resized and overwritten.
    #
    # Every array argument marked `values` uses the representation selected by -input. Scalar options remain
    # ordinary Tcl numbers. Numeric inputs must be finite. RBC support must be enabled in the build to use
    # vectors.
    #
    # Omitted -input, -output and -ifexists use ::tclinterp::configure defaults at call time. Explicit options take
    # precedence.
    #
    # Input vector names resolve in the caller's namespace. Output names use -namespace, or the caller's namespace
    # when omitted. Empty namespace names are rejected; -namespace requires -output vector. Fully qualified output
    # names override this location; their parent namespace must already exist. Each unnamed output, including fields
    # omitted from -names, uses RBC's #auto mechanism in the selected namespace. A final #auto component also works
    # in qualified names; auto without # is an ordinary name. Returned vector names are fully qualified.
    #
    # Do not specify both -name and the `yi` entry of -names. Unknown output fields and duplicate destinations
    # are errors. The caller owns returned vectors and can release them with `::rbc::vector destroy
    # $vectorName`.
    #
    # Returns: A dictionary with `xi` and `yi` coordinates. Each numeric array is a Tcl list with list output or an
    # RBC vector name with `-output vector`.
    #
    # Synopsis: -n integer -x values -y values -t values ?-input list|vector? ?-output list|vector? ?-namespace name?
    # ?-name name?  ?-names dictionary? ?-ifexists error|replace?
    set arguments [argparse -inline -help {Evaluates a parametric Bezier curve. Returns: A dictionary with xi and yi\
                                                   coordinates. Each numeric array is a Tcl list with list output or an\
                                                   RBC vector name with -output vector} {
        {-n= -required -help {Curve degree; must be zero or greater} -type integer -validate {$arg>=0}\
                 -errormsg {Order of Bezier curve -n '$arg' must be more than or equal to zero}}
        {-x= -required -help {X control coordinates; exactly n+1 values}}
        {-y= -required -help {Y control coordinates; exactly n+1 values}}
        {-t= -required -help {Nonempty evaluation parameters; normally between 0 and 1}}
        {-input= -enum {list vector} -help {Input representation for all array arguments: Tcl lists or real RBC vector\
                                                    names. Defaults to the package setting (initially list)}}
        {-output= -enum {list vector} -help {Output representation for every numeric result array: Tcl list or RBC\
                                                     vector name. Defaults to the package setting (initially list);\
                                                     independent of -input}}
        {-namespace= -help {Destination namespace for vector output; relative to the caller, created if missing}}
        {-name= -help {Destination vector name for yi; requires -output vector. Omit it or use #auto to create an\
                               automatically named vector}}
        {-names= -type dict -help {Dictionary mapping output fields to destination vector names; requires -output\
                                           vector. Valid fields: yi}}
        {-ifexists= -enum {error replace} -help {Policy for existing destination vectors; uses the package default\
                                                         (initially error). With replace, an existing real vector is\
                                                         resized and overwritten}}
    }]
    return [uplevel 1 [list ::tclinterp::native genBezier $arguments]]
}

proc ::tclinterp::approximation::bezier {args} {
    # Evaluates a Bezier polynomial on an interval.
    #  -n integer - Polynomial degree; must be zero or greater.
    #  -a value - Start of the interval; must differ from -b.
    #  -b value - End of the interval; must differ from -a.
    #  -x values - Evaluation positions; must not be empty.
    #  -y values - Control values; exactly n+1 values.
    #  -input list|vector - Input representation for all array arguments: Tcl lists or real RBC vector names.
    #    Defaults to the package setting (initially list).
    #  -output list|vector - Output representation for every numeric result array: Tcl list or RBC vector name.
    #    Defaults to the package setting (initially list); independent of -input.
    #  -namespace name - Destination namespace for vector output; relative to the caller, created with missing parents.
    #  -name name - Destination vector name for yi; requires -output vector. Omit it or use #auto to create an
    #    automatically named vector.
    #  -names dictionary - Dictionary mapping output fields to destination vector names; requires -output
    #    vector. Valid fields: `yi`.
    #  -ifexists error|replace - Policy for existing destination vectors; uses the package default (initially error).
    #    With replace, an existing real vector is resized and overwritten.
    #
    # Every array argument marked `values` uses the representation selected by -input. Scalar options remain
    # ordinary Tcl numbers. Numeric inputs must be finite. RBC support must be enabled in the build to use
    # vectors.
    #
    # Omitted -input, -output and -ifexists use ::tclinterp::configure defaults at call time. Explicit options take
    # precedence.
    #
    # Input vector names resolve in the caller's namespace. Output names use -namespace, or the caller's namespace
    # when omitted. Empty namespace names are rejected; -namespace requires -output vector. Fully qualified output
    # names override this location; their parent namespace must already exist. Each unnamed output, including fields
    # omitted from -names, uses RBC's #auto mechanism in the selected namespace. A final #auto component also works
    # in qualified names; auto without # is an ordinary name. Returned vector names are fully qualified.
    #
    # Do not specify both -name and the `yi` entry of -names. Unknown output fields and duplicate destinations
    # are errors. The caller owns returned vectors and can release them with `::rbc::vector destroy
    # $vectorName`.
    #
    # Returns: The interpolated values `yi`, as a Tcl list with list output or an RBC vector name with `-output
    # vector`.
    #
    # Synopsis: -n integer -a value -b value -x values -y values ?-input list|vector? ?-output list|vector?
    # ?-namespace name? ?-name name? ?-names dictionary? ?-ifexists error|replace?
    set arguments [argparse -inline -help {Evaluates a Bezier polynomial on an interval. Returns: The interpolated\
                                                   values yi, as a Tcl list with list output or an RBC vector name with\
                                                   -output vector} {
        {-n= -required -help {Polynomial degree; must be zero or greater} -type integer -validate {$arg>=0}\
                 -errormsg {Order of Bezier curve -n '$arg' must be more than or equal to zero}}
        {-a= -required -help {Start of the interval; must differ from -b}}
        {-b= -required -help {End of the interval; must differ from -a}}
        {-x= -required -help {Evaluation positions; must not be empty}}
        {-y= -required -help {Control values; exactly n+1 values}}
        {-input= -enum {list vector} -help {Input representation for all array arguments: Tcl lists or real RBC vector\
                                                    names. Defaults to the package setting (initially list)}}
        {-output= -enum {list vector} -help {Output representation for every numeric result array: Tcl list or RBC\
                                                     vector name. Defaults to the package setting (initially list);\
                                                     independent of -input}}
        {-namespace= -help {Destination namespace for vector output; relative to the caller, created if missing}}
        {-name= -help {Destination vector name for yi; requires -output vector. Omit it or use #auto to create an\
                            automatically named vector}}
        {-names= -type dict -help {Dictionary mapping output fields to destination vector names; requires -output\
                                           vector. Valid fields: yi}}
        {-ifexists= -enum {error replace} -help {Policy for existing destination vectors; uses the package default\
                                                         (initially error). With replace, an existing real vector is\
                                                         resized and overwritten}}
    }]
    return [uplevel 1 [list ::tclinterp::native bezier $arguments]]
}

proc ::tclinterp::interpolation::divDif1d {args} {
    # Performs divided-difference polynomial interpolation.
    #  -x values - Distinct sample positions; at least one value.
    #  -y values - Sample values; must have the same length as -x.
    #  -xi values - Evaluation positions; must not be empty.
    #  -coeffs - Include the divided-difference coefficient array in the result dictionary.
    #  -input list|vector - Input representation for all array arguments: Tcl lists or real RBC vector names.
    #    Defaults to the package setting (initially list).
    #  -output list|vector - Output representation for every numeric result array: Tcl list or RBC vector name.
    #    Defaults to the package setting (initially list); independent of -input.
    #  -namespace name - Destination namespace for vector output; relative to the caller, created with missing parents.
    #  -name name - Destination vector name for yi; requires -output vector. Omit it or use #auto to create an
    #    automatically named vector.
    #  -names dictionary - Dictionary mapping output fields to destination vector names; requires -output
    #    vector. Valid fields: `yi` and, only with -coeffs, `coeffs`.
    #  -ifexists error|replace - Policy for existing destination vectors; uses the package default (initially error).
    #    With replace, an existing real vector is resized and overwritten.
    #
    # Every array argument marked `values` uses the representation selected by -input. Scalar options remain
    # ordinary Tcl numbers. Numeric inputs must be finite. RBC support must be enabled in the build to use
    # vectors.
    #
    # Omitted -input, -output and -ifexists use ::tclinterp::configure defaults at call time. Explicit options take
    # precedence.
    #
    # Input vector names resolve in the caller's namespace. Output names use -namespace, or the caller's namespace
    # when omitted. Empty namespace names are rejected; -namespace requires -output vector. Fully qualified output
    # names override this location; their parent namespace must already exist. Each unnamed output, including fields
    # omitted from -names, uses RBC's #auto mechanism in the selected namespace. A final #auto component also works
    # in qualified names; auto without # is an ordinary name. Returned vector names are fully qualified.
    #
    # Do not specify both -name and the `yi` entry of -names. Unknown output fields and duplicate destinations
    # are errors. The caller owns returned vectors and can release them with `::rbc::vector destroy
    # $vectorName`.
    #
    # Returns: The interpolated values `yi`. With `-coeffs`, returns a dictionary with `yi` and `coeffs` arrays.
    # Each numeric array is a Tcl list with list output or an RBC vector name with `-output vector`.
    #
    # Synopsis: -x values -y values -xi values ?-coeffs? ?-input list|vector? ?-output list|vector? ?-namespace name?
    # ?-name name?  ?-names dictionary? ?-ifexists error|replace?
    set arguments [argparse -inline -help {Performs divided-difference polynomial interpolation. Returns: The\
                                                   interpolated values yi.  With -coeffs, returns a dictionary with yi\
                                                   and coeffs arrays. Each numeric array is a Tcl list with list output\
                                                   or an RBC vector name with -output vector} {
        {-x= -required -help {Distinct sample positions; at least one value}}
        {-y= -required -help {Sample values; must have the same length as -x}}
        {-xi= -required -help {Evaluation positions; must not be empty}}
        {-coeffs -help {Include the divided-difference coefficient array in the result dictionary}}
        {-input= -enum {list vector} -help {Input representation for all array arguments: Tcl lists or real RBC vector\
                                                    names. Defaults to the package setting (initially list)}}
        {-output= -enum {list vector} -help {Output representation for every numeric result array: Tcl list or RBC\
                                                     vector name. Defaults to the package setting (initially list);\
                                                     independent of -input}}
        {-namespace= -help {Destination namespace for vector output; relative to the caller, created if missing}}
        {-name= -help {Destination vector name for yi; requires -output vector. Omit it or use #auto to create an\
                               automatically named vector}}
        {-names= -type dict -help {Dictionary mapping output fields to destination vector names; requires -output\
                                           vector. Valid fields: yi}}
        {-ifexists= -enum {error replace} -help {Policy for existing destination vectors; uses the package default\
                                                         (initially error). With replace, an existing real vector is\
                                                         resized and overwritten}}
    }]
    return [uplevel 1 [list ::tclinterp::native divDif1d $arguments]]
}

proc ::tclinterp::approximation::cubicBSpline1d {args} {
    # Evaluates a cubic B-spline approximant.
    #  -t values - Strictly increasing sample positions; at least two values. Alias: -x.
    #  -y values - Sample values; must have the same length as -t.
    #  -ti values - Evaluation positions; must not be empty. Alias: -xi.
    #  -input list|vector - Input representation for all array arguments: Tcl lists or real RBC vector names.
    #    Defaults to the package setting (initially list).
    #  -output list|vector - Output representation for every numeric result array: Tcl list or RBC vector name.
    #    Defaults to the package setting (initially list); independent of -input.
    #  -namespace name - Destination namespace for vector output; relative to the caller, created with missing parents.
    #  -name name - Destination vector name for yi; requires -output vector. Omit it or use #auto to create an
    #    automatically named vector.
    #  -names dictionary - Dictionary mapping output fields to destination vector names; requires -output
    #    vector. Valid fields: `yi`.
    #  -ifexists error|replace - Policy for existing destination vectors; uses the package default (initially error).
    #    With replace, an existing real vector is resized and overwritten.
    #
    # Every array argument marked `values` uses the representation selected by -input. Scalar options remain
    # ordinary Tcl numbers. Numeric inputs must be finite. RBC support must be enabled in the build to use
    # vectors.
    #
    # Omitted -input, -output and -ifexists use ::tclinterp::configure defaults at call time. Explicit options take
    # precedence.
    #
    # Input vector names resolve in the caller's namespace. Output names use -namespace, or the caller's namespace
    # when omitted. Empty namespace names are rejected; -namespace requires -output vector. Fully qualified output
    # names override this location; their parent namespace must already exist. Each unnamed output, including fields
    # omitted from -names, uses RBC's #auto mechanism in the selected namespace. A final #auto component also works
    # in qualified names; auto without # is an ordinary name. Returned vector names are fully qualified.
    #
    # Do not specify both -name and the `yi` entry of -names. Unknown output fields and duplicate destinations
    # are errors. The caller owns returned vectors and can release them with `::rbc::vector destroy
    # $vectorName`.
    #
    # Returns: The approximated values `yi`, as a Tcl list with list output or an RBC vector name with `-output
    # vector`.
    #
    # Synopsis: -t values -y values -ti values ?-input list|vector? ?-output list|vector? ?-namespace name? ?-name name?
    # ?-names dictionary? ?-ifexists error|replace?
    set arguments [argparse -inline -help {Evaluates a cubic B-spline approximant. Returns: The approximated values yi,\
                                                   as a Tcl list with list output or an RBC vector name with -output\
                                                   vector} {
        {-t= -required -alias x -help {Strictly increasing sample positions; at least two values. Alias: -x}}
        {-y= -required -help {Sample values; must have the same length as -t}}
        {-ti= -required -alias xi -help {Evaluation positions; must not be empty. Alias: -xi}}
        {-input= -enum {list vector} -help {Input representation for all array arguments: Tcl lists or real RBC vector\
                                                    names. Defaults to the package setting (initially list)}}
        {-output= -enum {list vector} -help {Output representation for every numeric result array: Tcl list or RBC\
                                                     vector name. Defaults to the package setting (initially list);\
                                                     independent of -input}}
        {-namespace= -help {Destination namespace for vector output; relative to the caller, created if missing}}
        {-name= -help {Destination vector name for yi; requires -output vector. Omit it or use #auto to create an\
                               automatically named vector}}
        {-names= -type dict -help {Dictionary mapping output fields to destination vector names; requires -output\
                                           vector. Valid fields: yi}}
        {-ifexists= -enum {error replace} -help {Policy for existing destination vectors; uses the package default\
                                                         (initially error). With replace, an existing real vector is\
                                                         resized and overwritten}}
    }]
    return [uplevel 1 [list ::tclinterp::native cubicBSpline1d $arguments]]
}

proc ::tclinterp::approximation::cubicBetaSpline1d {args} {
    # Evaluates a cubic beta-spline approximant.
    #  -beta1 value - Required skew or bias parameter; 1 means no skew or bias.
    #  -beta2 value - Required tension parameter; 0 means no tension.
    #  -t values - Strictly increasing sample positions; at least two values. Alias: -x.
    #  -y values - Sample values; must have the same length as -t.
    #  -ti values - Evaluation positions; must not be empty. Alias: -xi.
    #  -input list|vector - Input representation for all array arguments: Tcl lists or real RBC vector names.
    #    Defaults to the package setting (initially list).
    #  -output list|vector - Output representation for every numeric result array: Tcl list or RBC vector name.
    #    Defaults to the package setting (initially list); independent of -input.
    #  -namespace name - Destination namespace for vector output; relative to the caller, created with missing parents.
    #  -name name - Destination vector name for yi; requires -output vector. Omit it or use #auto to create an
    #    automatically named vector.
    #  -names dictionary - Dictionary mapping output fields to destination vector names; requires -output
    #    vector. Valid fields: `yi`.
    #  -ifexists error|replace - Policy for existing destination vectors; uses the package default (initially error).
    #    With replace, an existing real vector is resized and overwritten.
    #
    # Every array argument marked `values` uses the representation selected by -input. Scalar options remain
    # ordinary Tcl numbers. Numeric inputs must be finite. RBC support must be enabled in the build to use
    # vectors.
    #
    # Omitted -input, -output and -ifexists use ::tclinterp::configure defaults at call time. Explicit options take
    # precedence.
    #
    # Input vector names resolve in the caller's namespace. Output names use -namespace, or the caller's namespace
    # when omitted. Empty namespace names are rejected; -namespace requires -output vector. Fully qualified output
    # names override this location; their parent namespace must already exist. Each unnamed output, including fields
    # omitted from -names, uses RBC's #auto mechanism in the selected namespace. A final #auto component also works
    # in qualified names; auto without # is an ordinary name. Returned vector names are fully qualified.
    #
    # Do not specify both -name and the `yi` entry of -names. Unknown output fields and duplicate destinations
    # are errors. The caller owns returned vectors and can release them with `::rbc::vector destroy
    # $vectorName`.
    #
    # The parameters must produce a finite, nonzero beta-spline normalization.
    #
    # Returns: The approximated values `yi`, as a Tcl list with list output or an RBC vector name with `-output
    # vector`.
    #
    # Synopsis: -beta1 value -beta2 value -t values -y values -ti values ?-input list|vector? ?-output
    # list|vector? ?-namespace name? ?-name name? ?-names dictionary? ?-ifexists error|replace?
    set arguments [argparse -inline -help {Evaluates a cubic beta-spline approximant. Returns: The approximated values\
                                                   yi, as a Tcl list with list output or an RBC vector name with\
                                                   -output vector} {
        {-beta1= -required -type double -help {Required skew or bias parameter; 1 means no skew or bias}}
        {-beta2= -required -type double -help {Required tension parameter; 0 means no tension}}
        {-t= -required -alias x -help {Strictly increasing sample positions; at least two values. Alias: -x}}
        {-y= -required -help {Sample values; must have the same length as -t}}
        {-ti= -required -alias xi -help {Evaluation positions; must not be empty. Alias: -xi}}
        {-input= -enum {list vector} -help {Input representation for all array arguments: Tcl lists or real RBC vector\
                                                    names. Defaults to the package setting (initially list)}}
        {-output= -enum {list vector} -help {Output representation for every numeric result array: Tcl list or RBC\
                                                     vector name. Defaults to the package setting (initially list);\
                                                     independent of -input}}
        {-namespace= -help {Destination namespace for vector output; relative to the caller, created if missing}}
        {-name= -help {Destination vector name for yi; requires -output vector. Omit it or use #auto to create an\
                               automatically named vector}}
        {-names= -type dict -help {Dictionary mapping output fields to destination vector names; requires -output\
                                           vector. Valid fields: yi}}
        {-ifexists= -enum {error replace} -help {Policy for existing destination vectors; uses the package default\
                                                         (initially error). With replace, an existing real vector is\
                                                         resized and overwritten}}
    }]
    return [uplevel 1 [list ::tclinterp::native cubicBetaSpline1d $arguments]]
}

proc ::tclinterp::interpolation::cubicSpline1d {args} {
    # Performs piecewise cubic spline interpolation.
    #  -t values - Strictly increasing sample positions; at least two values. Alias: -x.
    #  -y values - Sample values; must have the same length as -t.
    #  -ti values - Evaluation positions; must not be empty. Alias: -xi.
    #  -ibcbeg condition - Left boundary condition: quad, der1, der2, or notaknot; defaults to quad. Alias:
    #    -begflag.
    #  -ibcend condition - Right boundary condition: quad, der1, der2, or notaknot; defaults to quad. Alias:
    #    -endflag.
    #  -ybcbeg value - Prescribed left endpoint derivative for der1 or der2; defaults to 0.0.
    #  -ybcend value - Prescribed right endpoint derivative for der1 or der2; defaults to 0.0.
    #  -deriv - Include first and second derivatives in the result dictionary.
    #  -input list|vector - Input representation for all array arguments: Tcl lists or real RBC vector names.
    #    Defaults to the package setting (initially list).
    #  -output list|vector - Output representation for every numeric result array: Tcl list or RBC vector name.
    #    Defaults to the package setting (initially list); independent of -input.
    #  -namespace name - Destination namespace for vector output; relative to the caller, created with missing parents.
    #  -name name - Destination vector name for yi; requires -output vector. Omit it or use #auto to create an
    #    automatically named vector.
    #  -names dictionary - Dictionary mapping output fields to destination vector names; requires -output
    #    vector. Valid fields: `yi` and, only with -deriv, `yder1`, `yder2`.
    #  -ifexists error|replace - Policy for existing destination vectors; uses the package default (initially error).
    #    With replace, an existing real vector is resized and overwritten.
    #
    # Every array argument marked `values` uses the representation selected by -input. Scalar options remain
    # ordinary Tcl numbers. Numeric inputs must be finite. RBC support must be enabled in the build to use
    # vectors.
    #
    # Omitted -input, -output and -ifexists use ::tclinterp::configure defaults at call time. Explicit options take
    # precedence.
    #
    # Input vector names resolve in the caller's namespace. Output names use -namespace, or the caller's namespace
    # when omitted. Empty namespace names are rejected; -namespace requires -output vector. Fully qualified output
    # names override this location; their parent namespace must already exist. Each unnamed output, including fields
    # omitted from -names, uses RBC's #auto mechanism in the selected namespace. A final #auto component also works
    # in qualified names; auto without # is an ordinary name. Returned vector names are fully qualified.
    #
    # Do not specify both -name and the `yi` entry of -names. Unknown output fields and duplicate destinations
    # are errors. The caller owns returned vectors and can release them with `::rbc::vector destroy
    # $vectorName`.
    #
    # The boundary condition `quad` makes the first or last interval quadratic. The conditions `der1` and `der2`
    # prescribe the first or second endpoint derivative using -ybcbeg or -ybcend, respectively for the left or
    # right endpoint. The condition `notaknot` makes the third derivative continuous at the first or last
    # interior knot and requires at least four samples.
    #
    # Returns: The interpolated values `yi`. With `-deriv`, returns a dictionary with `yi`, first derivatives
    # `yder1`, and second derivatives `yder2`. Each numeric array is a Tcl list with list output or an RBC vector name
    # with `-output vector`.
    #
    # Synopsis: -t values -y values -ti values ?-ibcbeg condition? ?-ibcend condition? ?-ybcbeg value? ?-ybcend value?
    # ?-deriv? ?-input list|vector? ?-output list|vector? ?-namespace name? ?-name name? ?-names dictionary? ?-ifexists
    # error|replace?
    set arguments [argparse -inline -help {Performs piecewise cubic spline interpolation. Returns: The interpolated\
                                                   values yi. With -deriv, returns a dictionary with yi, first\
                                                   derivatives yder1, and second derivatives yder2.  Each numeric array\
                                                   is a Tcl list with list output or an RBC vector name with -output\
                                                   vector} {
        {-ibcbeg= -default quad -enum {quad der1 der2 notaknot} -alias begflag\
                 -help {Left boundary condition: quad, der1, der2, or notaknot; defaults to quad. Alias: -begflag}}
        {-ibcend= -default quad -enum {quad der1 der2 notaknot} -alias endflag\
                 -help {Right boundary condition: quad, der1, der2, or notaknot; defaults to quad. Alias: -endflag}}
        {-ybcbeg= -default 0.0 -help {Prescribed left endpoint derivative for der1 or der2; defaults to 0.0}}
        {-ybcend= -default 0.0 -help {Prescribed right endpoint derivative for der1 or der2; defaults to 0.0}}
        {-t= -required -alias x -help {Strictly increasing sample positions; at least two values. Alias: -x}}
        {-y= -required -help {Sample values; must have the same length as -t}}
        {-ti= -required -alias xi -help {Evaluation positions; must not be empty. Alias: -xi}}
        {-deriv -help {Include first and second derivatives in the result dictionary}}
        {-input= -enum {list vector} -help {Input representation for all array arguments: Tcl lists or real RBC vector\
                                                    names. Defaults to the package setting (initially list)}}
        {-output= -enum {list vector} -help {Output representation for every numeric result array: Tcl list or RBC\
                                                     vector name. Defaults to the package setting (initially list);\
                                                     independent of -input}}
        {-namespace= -help {Destination namespace for vector output; relative to the caller, created if missing}}
        {-name= -help {Destination vector name for yi; requires -output vector. Omit it or use #auto to create an\
                               automatically named vector}}
        {-names= -type dict -help {Dictionary mapping output fields to destination vector names; requires -output\
                                           vector. Valid fields: yi}}
        {-ifexists= -enum {error replace} -help {Policy for existing destination vectors; uses the package default\
                                                         (initially error). With replace, an existing real vector is\
                                                         resized and overwritten}}
    }]
    return [uplevel 1 [list ::tclinterp::native cubicSpline1d $arguments]]
}

proc ::tclinterp::interpolation::hermiteSpline1d {args} {
    # Performs cubic Hermite spline interpolation.
    #  -t values - Strictly increasing sample positions; at least two values. Alias: -x.
    #  -y values - Sample values; must have the same length as -t.
    #  -yp values - First derivatives at the sample positions; same length as -t.
    #  -ti values - Evaluation positions; must not be empty. Alias: -xi.
    #  -deriv - Include first derivatives in the result dictionary.
    #  -input list|vector - Input representation for all array arguments: Tcl lists or real RBC vector names.
    #    Defaults to the package setting (initially list).
    #  -output list|vector - Output representation for every numeric result array: Tcl list or RBC vector name.
    #    Defaults to the package setting (initially list); independent of -input.
    #  -namespace name - Destination namespace for vector output; relative to the caller, created with missing parents.
    #  -name name - Destination vector name for yi; requires -output vector. Omit it or use #auto to create an
    #    automatically named vector.
    #  -names dictionary - Dictionary mapping output fields to destination vector names; requires -output
    #    vector. Valid fields: `yi` and, only with -deriv, `yder1`.
    #  -ifexists error|replace - Policy for existing destination vectors; uses the package default (initially error).
    #    With replace, an existing real vector is resized and overwritten.
    #
    # Every array argument marked `values` uses the representation selected by -input. Scalar options remain
    # ordinary Tcl numbers. Numeric inputs must be finite. RBC support must be enabled in the build to use
    # vectors.
    #
    # Omitted -input, -output and -ifexists use ::tclinterp::configure defaults at call time. Explicit options take
    # precedence.
    #
    # Input vector names resolve in the caller's namespace. Output names use -namespace, or the caller's namespace
    # when omitted. Empty namespace names are rejected; -namespace requires -output vector. Fully qualified output
    # names override this location; their parent namespace must already exist. Each unnamed output, including fields
    # omitted from -names, uses RBC's #auto mechanism in the selected namespace. A final #auto component also works
    # in qualified names; auto without # is an ordinary name. Returned vector names are fully qualified.
    #
    # Do not specify both -name and the `yi` entry of -names. Unknown output fields and duplicate destinations
    # are errors. The caller owns returned vectors and can release them with `::rbc::vector destroy
    # $vectorName`.
    #
    # Returns: The interpolated values `yi`. With `-deriv`, returns a dictionary with `yi` and first derivatives
    # `yder1`. Each numeric array is a Tcl list with list output or an RBC vector name with `-output vector`.
    #
    # Synopsis: -t values -y values -yp values -ti values ?-deriv? ?-input list|vector? ?-output list|vector?
    # ?-namespace name? ?-name name? ?-names dictionary? ?-ifexists error|replace?
    set arguments [argparse -inline -help {Performs cubic Hermite spline interpolation. Returns: The interpolated\
                                                   values yi. With -deriv, returns a dictionary with yi and first\
                                                   derivatives yder1. Each numeric array is a Tcl list with list output\
                                                   or an RBC vector name with -output vector} {
        {-t= -required -alias x -help {Strictly increasing sample positions; at least two values. Alias: -x}}
        {-y= -required -help {Sample values; must have the same length as -t}}
        {-yp= -required -help {First derivatives at the sample positions; same length as -t}}
        {-ti= -required -alias xi -help {Evaluation positions; must not be empty. Alias: -xi}}
        {-deriv -help {Include first derivatives in the result dictionary}}
        {-input= -enum {list vector} -help {Input representation for all array arguments: Tcl lists or real RBC vector\
                                                    names. Defaults to the package setting (initially list)}}
        {-output= -enum {list vector} -help {Output representation for every numeric result array: Tcl list or RBC\
                                                     vector name. Defaults to the package setting (initially list);\
                                                     independent of -input}}
        {-namespace= -help {Destination namespace for vector output; relative to the caller, created if missing}}
        {-name= -help {Destination vector name for yi; requires -output vector. Omit it or use #auto to create an\
                               automatically named vector}}
        {-names= -type dict -help {Dictionary mapping output fields to destination vector names; requires -output\
                                           vector. Valid fields: yi}}
        {-ifexists= -enum {error replace} -help {Policy for existing destination vectors; uses the package default\
                                                         (initially error). With replace, an existing real vector is\
                                                         resized and overwritten}}
    }]
    return [uplevel 1 [list ::tclinterp::native hermiteSpline1d $arguments]]
}

proc ::tclinterp::interpolation::pchip1d {args} {
    # Performs piecewise cubic Hermite interpolation (PCHIP).
    #  -x values - Strictly increasing sample positions; at least two values.
    #  -f values - Sample values; same length as -x. Alias: -y.
    #  -xe values - Evaluation positions; must not be empty. Alias: -xi.
    #  -input list|vector - Input representation for all array arguments: Tcl lists or real RBC vector names.
    #    Defaults to the package setting (initially list).
    #  -output list|vector - Output representation for every numeric result array: Tcl list or RBC vector name.
    #    Defaults to the package setting (initially list); independent of -input.
    #  -namespace name - Destination namespace for vector output; relative to the caller, created with missing parents.
    #  -name name - Destination vector name for yi; requires -output vector. Omit it or use #auto to create an
    #    automatically named vector.
    #  -names dictionary - Dictionary mapping output fields to destination vector names; requires -output
    #    vector. Valid fields: `yi`.
    #  -ifexists error|replace - Policy for existing destination vectors; uses the package default (initially error).
    #    With replace, an existing real vector is resized and overwritten.
    #
    # Every array argument marked `values` uses the representation selected by -input. Scalar options remain
    # ordinary Tcl numbers. Numeric inputs must be finite. RBC support must be enabled in the build to use
    # vectors.
    #
    # Omitted -input, -output and -ifexists use ::tclinterp::configure defaults at call time. Explicit options take
    # precedence.
    #
    # Input vector names resolve in the caller's namespace. Output names use -namespace, or the caller's namespace
    # when omitted. Empty namespace names are rejected; -namespace requires -output vector. Fully qualified output
    # names override this location; their parent namespace must already exist. Each unnamed output, including fields
    # omitted from -names, uses RBC's #auto mechanism in the selected namespace. A final #auto component also works
    # in qualified names; auto without # is an ordinary name. Returned vector names are fully qualified.
    #
    # Do not specify both -name and the `yi` entry of -names. Unknown output fields and duplicate destinations
    # are errors. The caller owns returned vectors and can release them with `::rbc::vector destroy
    # $vectorName`.
    #
    # Returns: The interpolated values `yi`, as a Tcl list with list output or an RBC vector name with `-output
    # vector`.
    #
    # Synopsis: -x values -f values -xe values ?-input list|vector? ?-output list|vector? ?-namespace name? ?-name name?
    # ?-names dictionary? ?-ifexists error|replace?
    set arguments [argparse -inline -help {Performs piecewise cubic Hermite interpolation (PCHIP). Returns: The\
                                                   interpolated values yi, as a Tcl list with list output or an RBC\
                                                   vector name with -output vector} {
        {-x= -required -help {Strictly increasing sample positions; at least two values}}
        {-f= -required -alias y -help {Sample values; same length as -x. Alias: -y}}
        {-xe= -required -alias xi -help {Evaluation positions; must not be empty. Alias: -xi}}
        {-input= -enum {list vector} -help {Input representation for all array arguments: Tcl lists or real RBC vector\
                                                    names. Defaults to the package setting (initially list)}}
        {-output= -enum {list vector} -help {Output representation for every numeric result array: Tcl list or RBC\
                                                     vector name. Defaults to the package setting (initially list);\
                                                     independent of -input}}
        {-namespace= -help {Destination namespace for vector output; relative to the caller, created if missing}}
        {-name= -help {Destination vector name for yi; requires -output vector. Omit it or use #auto to create an\
                               automatically named vector}}
        {-names= -type dict -help {Dictionary mapping output fields to destination vector names; requires -output\
                                           vector. Valid fields: yi}}
        {-ifexists= -enum {error replace} -help {Policy for existing destination vectors; uses the package default\
                                                         (initially error). With replace, an existing real vector is\
                                                         resized and overwritten}}
    }]
    return [uplevel 1 [list ::tclinterp::native pchip1d $arguments]]
}
