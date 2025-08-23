package require argparse 0.58
package provide tclinterp 0.15

interp alias {} dget {} dict get
interp alias {} @ {} lindex
interp alias {} = {} expr
interp alias {} dexist {} dict exists
interp alias {} dcreate {} dict create

namespace eval ::tclinterp {
    namespace import ::tcl::mathop::*
    namespace eval interpolation {
        namespace export lin1d near1d lagr1d least1d least1dDer divDif1d cubicSpline1d hermiteSpline1d pchip1d
    }
    namespace eval approximation {
        namespace export genBezier bezier cubicBSpline1d cubicBetaSpline1d
    }
}

proc ::tclinterp::List2array {list} {
    # Create and initialize doubleArray object from the list
    #  list - list of values
    # Returns: array object
    set length [llength $list]
    set a [::tclinterp::new_doubleArray $length]
    for {set i 0} {$i<$length} {incr i} {
        set iElem [@ $list $i]
        try {
            ::tclinterp::doubleArray_setitem $a $i $iElem
        } on error {errmsg erropts} {
            if {[dget $erropts -errorcode] eq {SWIG TypeError}} {
                error "List must contains only double elements, but get '$iElem'"
            } else {
                error "Array creation failed with message '$errmsg' and opts '$erropts'"
            }
        }    
    }
    return $a
}

proc ::tclinterp::Lists2arrays {varNames lists} {
    # Create and initialize doubleArray objects from lists, and set these objects to variables
    #  varNames - list of variables names
    #  lists - list of lists
    # Returns: variables with doubleArray objects are set in caller's scope
    if {[llength $varNames]!=[llength $lists]} {
        error "Length of varName list '[llength $varNames]' must be equal to length of lists list '[llength $lists]'"
    }
    foreach varName $varNames list $lists {
        uplevel 1 [list set $varName [::tclinterp::List2array $list]]
    }
    return
}

proc ::tclinterp::Array2list {array length} {
    # Create list from doubleArray object
    #  array - doubleArray object
    #  length - number of elements in doubleArray
    # Returns: list
    for {set i 0} {$i<$length} {incr i} {
        lappend list [::tclinterp::doubleArray_getitem $array $i]
    }
    return $list
}

proc ::tclinterp::Arrays2lists {varNames arrays lengths} {
    # Create lists from doubleArray objects, and set these lists to variables
    #  varNames - list of variables names
    #  arrays - list of doubleArray
    #  lengths - list of doubleArray lengths
    # Returns: variables with lists are set in caller's scope
    if {[llength $varNames]!=[llength $arrays]} {
        error "Length of varName list '[llength $varNames]' must be equal to length of array list '[llength $arrays]'"
    } elseif {[llength $varNames]!=[llength $lengths]} {
        error "Length of varName list '[llength $varNames]' must be equal to length of lengths list\
                '[llength $lengths]'"
    }
    foreach varName $varNames array $arrays length $lengths {
        uplevel 1 [list set $varName [::tclinterp::Array2list $array $length]]
    }
    return
}

proc ::tclinterp::NewArrays {varNames lengths} {
    # Creates doubleArray objects, and set these objects to variables
    #  varNames - list of variables names
    #  lengths - list of doubleArray's lengths
    # Returns: variables with doubleArray objects are set in caller's scope
    if {[llength $varNames]!=[llength $lengths]} {
        error "Length of varName list '[llength $varNames]' must be equal to length of lengths list\
                '[llength $lengths]'"
    }
    foreach varName $varNames length $lengths {
        uplevel 1 [list set $varName [::tclinterp::new_doubleArray $length]]
    }
    return
}

proc ::tclinterp::NewDoubleps {varNames} {
    # Creates doubleps objects, and set these objects to variables
    #  varNames - list of variables names
    # Returns: variables with doubleps objects are set in caller's scope
    foreach varName $varNames {
        uplevel 1 [list set $varName [::tclinterp::new_doublep]]
    }
    return
}


proc ::tclinterp::DeleteArrays {args} {
    # Deletes doubleArray objects
    #  args - list of arrays objects
    foreach arg $args {
        ::tclinterp::delete_doubleArray $arg
    }
    return
}

proc ::tclinterp::DeleteDoubleps {args} {
    # Deletes doublep objects
    #  args - list of doublep objects
    foreach arg $args {
        ::tclinterp::delete_doublep $arg
    }
    return
}

proc ::tclinterp::DuplListCheck {list} {
    # Checks if list contains duplicates.
    #  list - list to check
    # Returns: false if there are no duplicates and true if there are.
    set flag false
    set new {}
    foreach item $list {
        if {[lsearch $new $item] < 0} {
            lappend new $item
        } else {
            set flag true
            break
        }
    }
    return $flag
}

proc ::tclinterp::interpolation::lin1d {args} {
    # Does linear one-dimensional interpolation.
    #  -x list - list of independent variable (x) values, must be strictly increasing
    #  -y list - list of dependent variable (y) values
    #  -xi list - list of independent variable interpolation (xi) values
    # Returns: list of interpolated dependent variable values, `yi`, at `xi`
    # Synopsis: -x list -y list -xi list
    argparse -help {Does linear one-dimensional interpolation. Returns: list of interpolated dependent variable values,\
                            'yi', at 'xi'} {
        {-x!= -help {List of independent variable (x) values, must be strictly increasing}}
        {-y!= -help {List of dependent variable (y) values}}
        {-xi!= -help {list of independent variable interpolation (xi) values}}
    }
    set xLen [llength $x]
    set yLen [llength $y]
    set xiLen [llength $xi]
    if {$xLen!=$yLen} {
        return -code error "Length of -y '$yLen' must be equal to length of -x '$xLen'"
    } elseif {$xiLen==0} {
        return -code error {Length of interpolation points list -xi must be more than zero}
    }
    ::tclinterp::Lists2arrays {xArray yArray xiArray} [list $x $y $xi]
    if {![::tclinterp::r8vec_ascends_strictly $xLen $xArray]} {
        return -code error {Independent variable array -x is not strictly increasing}
    }
    set yiArray [::tclinterp::interp_linear 1 $xLen $xArray $yArray $xiLen $xiArray]
    set yiList [::tclinterp::Array2list $yiArray $xiLen]
    ::tclinterp::DeleteArrays $xArray $yArray $xiArray $yiArray
    return $yiList
}

proc ::tclinterp::interpolation::near1d {args} {
    # Does nearest one-dimensional interpolation.
    #  -x list - list of independent variable (x) values
    #  -y list - list of dependent variable (y) values
    #  -xi list - list of independent variable interpolation (xi) values
    # Returns: list of interpolated dependent variable values, `yi`, at `xi`
    # Synopsis: -x list -y list -xi list
    argparse -help {Does nearest one-dimensional interpolation. Returns: list of interpolated dependent variable\
                            values, 'yi', at 'xi'} {
        {-x= -required -help {List of independent variable (x) values, must be strictly increasing}}
        {-y= -required -help {List of dependent variable (y) values}}
        {-xi= -required -help {list of independent variable interpolation (xi) values}}
    }
    set xLen [llength $x]
    set yLen [llength $y]
    set xiLen [llength $xi]
    if {$xLen!=$yLen} {
        return -code error "Length of -y '$yLen' must be equal to length of -x '$xLen'"
    } elseif {$xiLen==0} {
        return -code error {Length of interpolation points list -xi must be more than zero}
    }
    ::tclinterp::Lists2arrays {xArray yArray xiArray} [list $x $y $xi]
    set yiArray [::tclinterp::interp_nearest 1 $xLen $xArray $yArray $xiLen $xiArray]
    set yiList [::tclinterp::Array2list $yiArray $xiLen]
    ::tclinterp::DeleteArrays $xArray $yArray $xiArray $yiArray
    return $yiList
}

proc ::tclinterp::interpolation::lagr1d {args} {
    # Does Lagrange polynomial one-dimensional interpolation.
    #  -x list - list of independent variable (x) values
    #  -y list - list of dependent variable (y) values
    #  -xi list - list of independent variable interpolation (xi) values
    # Returns: list of interpolated dependent variable values, `yi`, at `xi`
    # Synopsis: -x list -y list -xi list
    argparse -help {Does Lagrange polynomial one-dimensional interpolation. Returns: list of interpolated dependent\
                            variable values, 'yi', at 'xi'} {
        {-x= -required -help {List of independent variable (x) values, must be strictly increasing}}
        {-y= -required -help {List of dependent variable (y) values}}
        {-xi= -required -help {list of independent variable interpolation (xi) values}}
    }
    set xLen [llength $x]
    set yLen [llength $y]
    set xiLen [llength $xi]
    if {$xLen!=$yLen} {
        return -code error "Length of -y '$yLen' must be equal to length of -x '$xLen'"
    } elseif {$xiLen==0} {
        return -code error {Length of interpolation points list -xi must be more than zero}
    }
    ::tclinterp::Lists2arrays {xArray yArray xiArray} [list $x $y $xi]
    set yiArray [::tclinterp::interp_lagrange 1 $xLen $xArray $yArray $xiLen $xiArray]
    set yiList [::tclinterp::Array2list $yiArray $xiLen]
    ::tclinterp::DeleteArrays $xArray $yArray $xiArray $yiArray
    return $yiList
}

proc ::tclinterp::interpolation::least1d {args} {
    # Does least squares polynomial one-dimensional interpolation.
    #  -x list - list of independent variable (x) values
    #  -y list - list of dependent variable (y) values
    #  -xi list - list of independent variable interpolation (xi) values
    #  -w list - list of weights, optional
    #  -nterms value - number of terms of interpolation polynom, default is 3
    #  -coeffs - selects the alternative output option
    # Returns: list of interpolated dependent variable values, `yi`, at `xi`. If `-coeffs` switch is in args, the output
    # is dictionary that contains `yi` values under `yi` key, and the values of interpolation polynom coefficients under
    # the keys `b`, `c` and `d`.
    # Synopsis: -x list -y list -xi list ?-w list? ?-nterms value? ?-coeffs?
    argparse -help {Does least squares polynomial one-dimensional interpolation. Returns: list of interpolated\
                            dependent variable values, 'yi', at 'xi'. If '-coeffs' switch is in args, the output is\
                            dictionary that contains 'yi' values under 'yi' key, and the values of interpolation\
                            polynom coefficients under the keys 'b', 'c' and 'd'} {
        {-x= -required -help {List of independent variable (x) values}}
        {-y= -required -help {List of dependent variable (y) values}}
        {-xi= -required -help {List of independent variable interpolation (xi) values}}
        {-w= -help {List of weights}}
        {-nterms= -default 3 -type integer -validate {$arg>0}\
                 -errormsg {Number of terms -nterms must be more than zero}\
                 -help {Number of terms of interpolation polynom}}
        {-coeffs -help {Selects the alternative output option}}
    }
    set xLen [llength $x]
    set yLen [llength $y]
    if {[info exists w]} {
        set wLen [llength $w]
    } else {
        set wLen [llength $x]
        set w [lrepeat $wLen 1]
    }
    set xiLen [llength $xi]
    if {$xLen!=$yLen} {
        return -code error "Length of -y '$yLen' must be equal to length of -x '$xLen'"
    } elseif {$xLen!=$wLen} {
        return -code error "Length of -w '$wLen' must be equal to length of -x '$xLen'"
    } elseif {$xiLen==0} {
        return -code error {Length of interpolation points list -xi must be more than zero}
    }
    ::tclinterp::Lists2arrays {xArray yArray wArray xiArray} [list $x $y $w $xi]
    ::tclinterp::NewArrays {b c d} [list $nterms $nterms $nterms]
    # create polynomial coefficients for given data
    ::tclinterp::least_set $xLen $xArray $yArray $wArray $nterms $b $c $d
    # calculate polynomial value for each xi value
    for {set i 0} {$i<$xiLen} {incr i} {
        set iElem [::tclinterp::least_val $nterms $b $c $d [@ $xi $i]]
        lappend yiList $iElem
    }
    if {[info exists coeffs]} {
        ::tclinterp::Arrays2lists {bList cList dList} [list $b $c $d] [list $nterms $nterms $nterms]
        ::tclinterp::DeleteArrays $b $c $d $xArray $yArray $xiArray
        return [dcreate yi $yiList coeffs [dcreate b $bList c $cList d $dList]]
    } else {
        ::tclinterp::DeleteArrays $b $c $d $xArray $yArray $xiArray
        return $yiList
    }
    return
}

proc ::tclinterp::interpolation::least1dDer {args} {
    # Does least squares polynomial one-dimensional interpolation with calculation of its derivative.
    #  -x list - list of independent variable (x) values
    #  -y list - list of dependent variable (y) values
    #  -xi list - list of independent variable interpolation (xi) values
    #  -w list - list of weights, optional
    #  -nterms value - number of terms of interpolation polynom, default is 3
    #  -coeffs - selects the alternative output option
    # Returns: dict of interpolated dependent variable values and its derivatives under `yi` and `yiDer` keys. If
    # `-coeffs` switch is in args, the output is dictionary that contains `yi` values under `yi` key, `yi` derivatives
    # under `yiDer` key, and the values of interpolation polynom coefficients under the keys `b`, `c` and `d`.
    # Synopsis: -x list -y list -xi list ?-w list? ?-nterms value? ?-coeffs?
    argparse -help {Does least squares polynomial one-dimensional interpolation with calculation of its derivative.\
                            Returns: dict of interpolated dependent variable values and its derivatives under 'yi' and\
                            'yiDer' keys. If '-coeffs' switch is in args, the output is dictionary that contains 'yi'\
                            values under 'yi' key, 'yi' derivatives under 'yiDer' key, and the values of interpolation\
                            polynom coefficients under the keys 'b', 'c' and 'd'} {
        {-x= -required -help {List of independent variable (x) values}}
        {-y= -required -help {List of dependent variable (y) values}}
        {-xi= -required -help {List of independent variable interpolation (xi) values}}
        {-w= -help {List of weights}}
        {-nterms= -default 3 -type integer -validate {$arg>0}\
                 -errormsg {Number of terms -nterms must be more than zero}\
                 -help {Number of terms of interpolation polynom}}
        {-coeffs -help {Selects the alternative output option}}
    }
    set xLen [llength $x]
    set yLen [llength $y]
    if {[info exists w]} {
        set wLen [llength $w]
    } else {
        set wLen [llength $x]
        set w [lrepeat $wLen 1]
    }
    set xiLen [llength $xi]
    if {$xLen!=$yLen} {
        return -code error "Length of -y '$yLen' must be equal to length of -x '$xLen'"
    } elseif {$xLen!=$wLen} {
        return -code error "Length of -w '$wLen' must be equal to length of -x '$xLen'"
    } elseif {$xiLen==0} {
        return -code error {Length of interpolation points list -xi must be more than zero}
    }
    ::tclinterp::Lists2arrays {xArray yArray wArray xiArray} [list $x $y $w $xi]
    ::tclinterp::NewArrays {b c d} [list $nterms $nterms $nterms]
    ::tclinterp::NewDoubleps {yiPnt yiDerPnt}
    # create polynomial coefficients for given data
    ::tclinterp::least_set $xLen $xArray $yArray $wArray $nterms $b $c $d
    # calculate polynomial value and derivative for each xi value
    for {set i 0} {$i<$xiLen} {incr i} {
        ::tclinterp::least_val2 $nterms $b $c $d [@ $xi $i] $yiPnt $yiDerPnt
        lappend yiList [::tclinterp::doublep_value $yiPnt]
        lappend yiDerList [::tclinterp::doublep_value $yiDerPnt]
    }
    if {[info exists coeffs]} {
        ::tclinterp::Arrays2lists {bList cList dList} [list $b $c $d] [list $nterms $nterms $nterms]
        ::tclinterp::DeleteArrays $b $c $d $xArray $yArray $xiArray
        ::tclinterp::DeleteDoubleps $yiPnt $yiDerPnt
        return [dcreate yi $yiList yiDer $yiDerList coeffs [dcreate b $bList c $cList d $dList]]
    } else {
        ::tclinterp::DeleteArrays $b $c $d $xArray $yArray $xiArray
        ::tclinterp::DeleteDoubleps $yiPnt $yiDerPnt
        return [dcreate yi $yiList yiDer $yiDerList]
    }
    return
}

proc ::tclinterp::approximation::genBezier {args} {
    # Finds values of general Bezier function at specified t points.
    #  -n value - order of Bezier function, must be zero or more
    #  -x list - list of x control points values of size n+1
    #  -y list - list of y control points values of size n+1
    #  -t list - list of t points at which we want to evaluate Bezier function, best results are obtained within the interval
    #   [0,1]
    # Returns: dict with lists of xi and yi points at specified t points
    # Synopsis: -n value -x list -y list -t list
    argparse -help {Finds values of general Bezier function at specified t points. Returns: dict with lists of xi and\
                            yi points at specified t points} {
        {-n= -required -help {Order of Bezier function, must be zero or more} -type integer -validate {$arg>0}\
                 -errormsg {Order of Bezier curve -n '$arg' must be more than or equal to zero}}
        {-x= -required -help {List of x control points values of size n+1}}
        {-y= -required -help {List of y control points values of size n+1}}
        {-t= -required -help {List of t points at which we want to evaluate Bezier function, best results are obtained\
                                      within the interval [0,1]}}
    }
    set xLen [llength $x]
    set yLen [llength $y]
    set tLen [llength $t]
    if {$xLen!=[= {$n+1}]} {
        return -code error "Length of -x '$xLen' must be equal to n+1=[= {$n+1}]"
    } elseif {$yLen!=[= {$n+1}]} {
        return -code error "Length of -y '$yLen' must be equal to n+1=[= {$n+1}]"
    } elseif {$tLen==0} {
        return -code error {Length of points list -t must be more than zero}
    }
    ::tclinterp::Lists2arrays {xArray yArray} [list $x $y]
    ::tclinterp::NewDoubleps {xiPnt yiPnt}
    for {set i 0} {$i<$tLen} {incr i} {
        ::tclinterp::bc_val $n [@ $t $i] $xArray $yArray $xiPnt $yiPnt
        lappend xiList [::tclinterp::doublep_value $xiPnt]
        lappend yiList [::tclinterp::doublep_value $yiPnt]
    }
    ::tclinterp::DeleteArrays $xArray $yArray
    ::tclinterp::DeleteDoubleps $xiPnt $yiPnt
    return [dcreate xi $xiList yi $yiList]
}

proc ::tclinterp::approximation::bezier {args} {
    # Finds values of Bezier function at x points.
    #  -n value - order of Bezier function, must be zero or more
    #  -a value - start of the interval
    #  -b value - end of interval
    #  -x list - list of x values
    #  -y list - list of y control points values of size n+1
    # Returns: yi values of Bezier function at x points
    # Synopsis: -n value -a value -b value -x list -y list
    argparse -help {Finds values of Bezier function at x points. Returns: yi values of Bezier function at x points} {
        {-n= -required -help {Order of Bezier function, must be zero or more} -type integer -validate {$arg>0}\
                 -errormsg {Order of Bezier curve -n '$arg' must be more than or equal to zero}}
        {-a= -required -help {Start of the interval}}
        {-b= -required -help {End of interval}}
        {-x= -required -help {List of x values}}
        {-y= -required -help {List of y control points values of size n+1}}
    }
    if {$a==$b} {
        return -code error "Start -a '$a' and end -b '$b' values of interval must not be equal"
    }
    set xLen [llength $x]
    set yLen [llength $y]
    if {$yLen!=[= {$n+1}]} {
        return -code error "Length of -y '$yLen' must be equal to n+1=[= {$n+1}]"
    } elseif {$xLen==0} {
        return -code error {Length of points list -x must be more than zero}
    }
    ::tclinterp::Lists2arrays yArray [list $y]
    for {set i 0} {$i<$xLen} {incr i} {
        lappend yiList [::tclinterp::bez_val $n [@ $x $i] $a $b $yArray]
    }
    ::tclinterp::DeleteArrays $yArray
    return $yiList
}

proc ::tclinterp::interpolation::divDif1d {args} {
    # Does divided difference one-dimensional interpolation.
    #  -x list - list of independent variable (x) values
    #  -y list - list of dependent variable (y) values
    #  -xi list - list of independent variable interpolation (xi) values
    #  -coeffs - selects the alternative output option
    # Returns: list of interpolated dependent variable values, `yi`, at `xi`. If `-coeffs` switch is in args, the output
    # is dictionary that contains `yi` values under `yi` key, and the values of difference table under the key `coeffs`.
    # Synopsis: -x list -y list -xi list ?-coeffs?
    argparse -help {Does divided difference one-dimensional interpolation. Returns: list of interpolated dependent\
                            variable values, 'yi', at 'xi'. If '-coeffs' switch is in args, the output is dictionary\
                            that contains 'yi' values under 'yi' key, and the values of difference table under the key\
                            'coeffs'} {
        {-x= -required -help {List of independent variable (x) values}}
        {-y= -required -help {List of dependent variable (y) values}}
        {-xi= -required -help {List of independent variable interpolation (xi) values}}
        {-coeffs -help {Selects the alternative output option}}
    }
    set xLen [llength $x]
    set yLen [llength $y]
    set xiLen [llength $xi]
    if {$xLen!=$yLen} {
        return -code error "Length of -y '$yLen' must be equal to length of -x '$xLen'"
    } elseif {$xiLen==0} {
        return -code error {Length of interpolation points list -xi must be more than zero}
    }
    if {[::tclinterp::DuplListCheck $x]} {
        return -code error {List of -x values must not contain duplicated elements}
    }
    ::tclinterp::Lists2arrays {xArray yArray} [list $x $y]
    ::tclinterp::NewArrays difTab $xLen
    # create difference table for given data
    ::tclinterp::data_to_dif $xLen $xArray $yArray $difTab
    # calculate polynomial value for each xi value
    for {set i 0} {$i<$xiLen} {incr i} {
        set iElem [::tclinterp::dif_val $xLen $xArray $difTab [@ $xi $i]]
        lappend yiList $iElem
    }
    if {[info exists coeffs]} {
        ::tclinterp::Arrays2lists difTabList $difTab $xLen
        ::tclinterp::DeleteArrays $difTab $xArray $yArray
        return [dcreate yi $yiList coeffs $difTabList]
    } else {
        ::tclinterp::DeleteArrays $difTab $xArray $yArray
        return $yiList
    }
    return
}

proc ::tclinterp::approximation::cubicBSpline1d {args} {
    # Evaluates a cubic B spline approximant.
    #  -t list - list of independent variable (t) values, -x is an alias
    #  -y list - list of dependent variable (y) values
    #  -ti list - list of independent variable interpolation (ti) values, -xi is an alias
    # Returns: list of approximation values yi at ti points.
    # Synopsis: -t|x list -y list -ti|xi list
    argparse -help {Evaluates a cubic B spline approximant. Returns: list of approximation values yi at ti points} {
        {-t= -required -alias x -help {List of independent variable (t) values}}
        {-y= -required -help {List of dependent variable (y) values}}
        {-ti= -required -alias xi -help {List of independent variable interpolation (ti) values}}
    }
    set tLen [llength $t]
    set yLen [llength $y]
    set tiLen [llength $ti]
    if {$tLen!=$yLen} {
        return -code error "Length of -y '$yLen' must be equal to length of -t '$tLen'"
    } elseif {$tiLen==0} {
        return -code error {Length of interpolation points list -ti must be more than zero}
    }
    ::tclinterp::Lists2arrays {tArray yArray} [list $t $y]
    for {set i 0} {$i<$tiLen} {incr i} {
        set iElem [::tclinterp::spline_b_val $tLen $tArray $yArray [@ $ti $i]]
        lappend yiList $iElem
    }
    ::tclinterp::DeleteArrays $tArray $yArray
    return $yiList
}

proc ::tclinterp::approximation::cubicBetaSpline1d {args} {
    # Evaluates a cubic beta spline approximant.
    #  -beta1 value - the skew or bias parameter, beta1 = 1 for no skew or bias
    #  -beta2 value - the tension parameter, beta2 = 0 for no tension
    #  -t list - list of independent variable (t) values, -x is an alias
    #  -y list - list of dependent variable (y) values
    #  -ti list - list of independent variable interpolation (ti) values, -xi is an alias
    # Returns: list of approximation values yi at ti points.
    # Synopsis: -beta1 value -beta2 value -t|x list -y list -ti|xi list
    argparse -help {Evaluates a cubic beta spline approximant. Returns: list of approximation values yi at ti points} {
        {-beta1= -required -type double -help {The skew or bias parameter, beta1 = 1 for no skew or bias}}
        {-beta2= -required -type double -help {The tension parameter, beta2 = 0 for no tension}}
        {-t= -required -alias x -help {List of independent variable (t) values}}
        {-y= -required -help {List of dependent variable (y) values}}
        {-ti= -required -alias xi -help {List of independent variable interpolation (ti) values}}
    }
    set tLen [llength $t]
    set yLen [llength $y]
    set tiLen [llength $ti]
    if {$tLen!=$yLen} {
        return -code error "Length of -y '$yLen' must be equal to length of -t '$tLen'"
    } elseif {$tiLen==0} {
        return -code error {Length of interpolation points list -ti must be more than zero}
    }
    ::tclinterp::Lists2arrays {tArray yArray} [list $t $y]
    for {set i 0} {$i<$tiLen} {incr i} {
        set iElem [::tclinterp::spline_beta_val $beta1 $beta2 $tLen $tArray $yArray [@ $ti $i]]
        lappend yiList $iElem
    }
    ::tclinterp::DeleteArrays $tArray $yArray
    return $yiList
}

proc ::tclinterp::interpolation::cubicSpline1d {args} {
    # Does piecewise cubic spline interpolation.
    #  -ibcbeg value - left boundary condition flag, -begflag is an alias. Possible values:
    #   **quad**, the cubic spline should be a quadratic over the first interval;
    #   **der1**, the first derivative at the left endpoint should be YBCBEG;
    #   **der2**, the second derivative at the left endpoint should be YBCBEG;
    #   **notaknot**, not-a-knot, the third derivative is continuous at T(2).
    #  -ibcend value - right boundary condition flag, -endflag is an alias. Possible values:
    #   **quad**, the cubic spline should be a quadratic over the last interval;
    #   **der1**, the first derivative at the right endpoint should be YBCBEG;
    #   **der2**, the second derivative at the right endpoint should be YBCBEG;
    #   **notaknot**, not-a-knot, the third derivative is continuous at T(2).
    #  -ybcbeg value - the values to be used in the boundary conditions if ibcbeg is equal to der1 or der2, default is
    #    0.0
    #  -ybcend value - the values to be used in the boundary conditions if ibcend is equal to der1 or der2, default is
    #    0.0
    #  -t list - list of independent variable (t) values, -x is an alias
    #  -y list - list of dependent variable (y) values
    #  -ti list - list of independent variable interpolation (ti) values, -xi is an alias
    #  -deriv - select the alternative output option
    # Returns: list of interpolated dependent variable values under. If `-deriv` switch is in args, the output is
    # dictionary that contains `yi` values under `yi` key, `yi` derivative under `yder1` key, and `yi` second derivative
    # under `yder2` key.
    # Synopsis: -t|x list -y list -ti|xi list ?-ibcbeg|begflag value -ybcbeg value? ?-ibcend|endflag value -ybcend
    #   value?  ?-deriv?
    argparse -help {Does piecewise cubic spline interpolation. Returns: list of interpolated dependent variable values\
                            under. If '-deriv' switch is in args, the output is dictionary that contains 'yi' values\
                            under 'yi' key, 'yi' derivative under 'yder1' key, and 'yi' second derivative under 'yder2'\
                            key} {
        {-ibcbeg= -default quad -enum {quad der1 der2 notaknot} -alias begflag\
                 -help {Left boundary condition flag. Possible values: quad, the cubic spline should be a quadratic\
                                over the first interval; der1, the first derivative at the left endpoint should be\
                                YBCBEG; der2, the second derivative at the left endpoint should be YBCBEG; notaknot,\
                                not-a-knot, the third derivative is continuous at T(2)}}
        {-ibcend= -default quad -enum {quad der1 der2 notaknot} -alias endflag\
                 -help {Right boundary condition flag, -endflag is an alias. Possible values: quad, the cubic spline\
                                should be a quadratic over the last interval; der1, the first derivative at the right\
                                endpoint should be YBCBEG; der2, the second derivative at the right endpoint should be\
                                YBCBEG; notaknot, not-a-knot, the third derivative is continuous at T(2)}}
        {-ybcbeg= -default 0.0 -help {The values to be used in the boundary conditions if ibcbeg is equal to der1 or\
                                              der2}}
        {-ybcend= -default 0.0 -help {The values to be used in the boundary conditions if ibcend is equal to der1 or\
                                              der2}}
        {-t= -required -alias x -help {List of independent variable (t) values}}
        {-y= -required -help {List of dependent variable (y) values}}
        {-ti= -required -alias xi -help {List of independent variable interpolation (ti) values}}
        {-deriv -help {Select the alternative output option}}
    }
    set keyMap [dcreate quad 0 der1 1 der2 2 notaknot 3]
    set tLen [llength $t]
    set yLen [llength $y]
    set tiLen [llength $ti]
    if {$tLen!=$yLen} {
        return -code error "Length of -y '$yLen' must be equal to length of -t '$tLen'"
    } elseif {$tiLen==0} {
        return -code error {Length of interpolation points list -ti must be more than zero}
    }
    ::tclinterp::Lists2arrays {tArray yArray} [list $t $y]
    ::tclinterp::NewArrays yppArray $tLen
    ::tclinterp::NewDoubleps {ypPnt yppPnt}
    set yppArray [::tclinterp::spline_cubic_set $tLen $tArray $yArray [dget $keyMap $ibcbeg] $ybcbeg\
                          [dget $keyMap $ibcend] $ybcend]
    for {set i 0} {$i<$tiLen} {incr i} {
        set iElem [::tclinterp::spline_cubic_val $tLen $tArray $yArray $yppArray [@ $ti $i] $ypPnt $yppPnt]
        lappend yiList $iElem
        lappend ypList [::tclinterp::doublep_value $ypPnt]
        lappend yppList [::tclinterp::doublep_value $yppPnt]
    }
    ::tclinterp::DeleteArrays $tArray $yArray $yppArray
    ::tclinterp::DeleteDoubleps $ypPnt $yppPnt
    if {[info exists deriv]} {
        return [dict create yi $yiList yder1 $ypList yder2 $yppList]
    } else {
        return $yiList
    }
}

proc ::tclinterp::interpolation::hermiteSpline1d {args} {
    # Does Hermite polynomial spline interpolation.
    #  -t list - list of independent variable (t) values, must be strictly increasing, -x is an alias
    #  -y list - list of dependent variable (y) values
    #  -yp list - list of dependent variable (y) derivative values
    #  -ti list - list of independent variable interpolation (ti) values, -xi is an alias
    #  -deriv - select the alternative output option
    # Returns: list of interpolated dependent variable values. If `-deriv` switch is in args, the output is
    # dictionary that contains `yi` values under `yi` key, `yi` derivative under `yder1` key.
    # Synopsis: -t|x list -y list -yp list -ti|xi list ?-deriv?
    argparse -help {Does Hermite polynomial spline interpolation. Returns: list of interpolated dependent variable\
                            values. If '-deriv' switch is in args, the output is dictionary that contains 'yi' values\
                            under 'yi' key, 'yi' derivative under 'yder1' key} {
        {-t= -required -alias x -help {List of independent variable (t) values, must be strictly increasing}}
        {-y= -required -help {List of dependent variable (y) values}}
        {-yp= -required -help {List of dependent variable (y) derivative values}}
        {-ti= -required -alias xi -help {List of independent variable interpolation (ti) values}}
        {-deriv -help {Select the alternative output option}}
    }
    set tLen [llength $t]
    set yLen [llength $y]
    set ypLen [llength $yp]
    set tiLen [llength $ti]
    if {$tLen!=$yLen} {
        return -code error "Length of -y '$yLen' must be equal to length of -t '$tLen'"
    } elseif {$tLen!=$ypLen} {
        return -code error "Length of -yp '$ypLen' must be equal to length of -t '$tLen'"
    } elseif {$tiLen==0} {
        return -code error {Length of interpolation points list -ti must be more than zero}
    }
    ::tclinterp::Lists2arrays {tArray yArray ypArray} [list $t $y $yp]
    if {[::tclinterp::r8vec_ascends_strictly $tLen $tArray]==0} {
        return -code error {Independent variable array -t is not strictly increasing}
    }
    ::tclinterp::NewArrays cArray [= {$tLen*4}]
    ::tclinterp::NewDoubleps {yiPnt yipPnt}
    set cArray [::tclinterp::spline_hermite_set $tLen $tArray $yArray $ypArray]
    for {set i 0} {$i<$tiLen} {incr i} {
        ::tclinterp::spline_hermite_val $tLen $tArray $cArray [@ $ti $i] $yiPnt $yipPnt
        lappend yiList [::tclinterp::doublep_value $yiPnt]
        lappend yipList [::tclinterp::doublep_value $yipPnt]
    }
    ::tclinterp::DeleteArrays $tArray $yArray $cArray $ypArray
    ::tclinterp::DeleteDoubleps $yiPnt $yipPnt
    if {[info exists deriv]} {
        return [dict create yi $yiList yder1 $yipList]
    } else {
        return $yiList
    }
}

proc ::tclinterp::interpolation::pchip1d {args} {
    # Does piecewise cubic Hermite interpolation (PCHIP).
    #  -x list - list of independent variable (x) values, must be strictly increasing
    #  -f list - list of dependent variable (f) values, -y is an alias
    #  -xe list - list of independent variable interpolation (xe) values, -xi is an alias
    # Returns: list of interpolated dependent variable values.
    # Synopsis: -x list -f|y list -xe|xi list
    argparse -help {Does piecewise cubic Hermite interpolation (PCHIP). Returns: list of interpolated dependent\
                            variable values} {
        {-x= -required -help {List of independent variable (x) values, must be strictly increasing}}
        {-f= -required -alias y -help {List of dependent variable (f) values}}
        {-xe= -required -alias xi -help {List of independent variable interpolation (xe) values}}
    }
    set xLen [llength $x]
    set fLen [llength $f]
    set xeLen [llength $xe]
    if {$xLen!=$fLen} {
        return -code error "Length of -f '$fLen' must be equal to length of -x '$xLen'"
    } elseif {$xeLen==0} {
        return -code error {Length of interpolation points list -xe must be more than zero}
    }
    ::tclinterp::Lists2arrays {xArray fArray xeArray} [list $x $f $xe]
    if {[::tclinterp::r8vec_ascends_strictly $xLen $xArray]==0} {
        return -code error {Independent variable array -x is not strictly increasing}
    }
    ::tclinterp::NewArrays {dArray feArray} [list $xLen $xeLen]
    ::tclinterp::spline_pchip_set $xLen $xArray $fArray $dArray
    ::tclinterp::spline_pchip_val $xLen $xArray $fArray $dArray $xeLen $xeArray $feArray
    set feList [::tclinterp::Array2list $feArray $xeLen]
    ::tclinterp::DeleteArrays $xArray $fArray $dArray $xeArray $feArray
    return $feList
}
