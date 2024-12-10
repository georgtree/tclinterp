package require argparse
package provide tclinterp 0.1
set script_path [file dirname [file normalize [info script]]]


namespace eval ::tclinterp {

    namespace import ::tcl::mathop::*
    namespace export interpLin1d interpNear1d interpLagr1d interpLeast1d interpLeast1dDer genBezier bezier
    interp alias {} dget {} dict get
    interp alias {} @ {} lindex
    interp alias {} = {} expr
    interp alias {} dexist {} dict exists
    interp alias {} dcreate {} dict create
}

proc ::tclinterp::list2array {list} {
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
            if {[dget $erropts -errorcode]=="SWIG TypeError"} {
                error "List must contains only double elements, but get '$iElem'"
            } else {
                error "Array creation failed with message '$errmsg' and opts '$erropts'"
            }
        }    
    }
    return $a
}

proc ::tclinterp::lists2arrays {varNames lists} {
    # Create and initialize doubleArray objects from lists, and set these objects to variables
    #  varNames - list of variables names
    #  lists - list of lists
    # Returns: variables with doubleArray objects are set in caller's scope
    if {[llength $varNames]!=[llength $lists]} {
        error "Length of varName list '[llength $varNames]' must be equal to length of lists list '[llength $lists]'"
    }
    foreach varName $varNames list $lists {
        uplevel 1 [list set $varName [::tclinterp::list2array $list]]
    }
    return
}

proc ::tclinterp::array2list {array length} {
    # Create list from doubleArray object
    #  array - doubleArray object
    #  length - number of elements in doubleArray
    # Returns: list
    for {set i 0} {$i<$length} {incr i} {
        lappend list [::tclinterp::doubleArray_getitem $array $i]
    }
    return $list
}

proc ::tclinterp::arrays2lists {varNames arrays lengths} {
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
        uplevel 1 [list set $varName [::tclinterp::array2list $array $length]]
    }
    return
}

proc ::tclinterp::newArrays {varNames lengths} {
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

proc ::tclinterp::newDoubleps {varNames} {
    # Creates doubleps objects, and set these objects to variables
    #  varNames - list of variables names
    # Returns: variables with doubleps objects are set in caller's scope
    foreach varName $varNames {
        uplevel 1 [list set $varName [::tclinterp::new_doublep]]
    }
    return
}


proc ::tclinterp::deleteArrays {args} {
    # Deletes doubleArray objects
    #  args - list of arrays objects
    foreach arg $args {
        ::tclinterp::delete_doubleArray $arg
    }
    return
}

proc ::tclinterp::deleteDoubleps {args} {
    # Deletes doublep objects
    #  args - list of doublep objects
    foreach arg $args {
        ::tclinterp::delete_doublep $arg
    }
    return
}

proc ::tclinterp::interpLin1d {args} {
    # Does linear one-dimensional interpolation.
    #  -x - list of independent variable (x) values, must be strictly increasing
    #  -y - list of dependent variable (y) values
    #  -xi - list of independent variable interpolation (xi) values
    # Returns: list of interpolated dependent variable values, `yi`, at `xi`
    set arguments [argparse {
        {-x= -required}
        {-y= -required}
        {-xi= -required}
    }]
    set xLen [llength $x]
    set yLen [llength $y]
    set xiLen [llength $xi]
    if {$xLen!=$yLen} {
        error "Length of y '$yLen' must be equal to x '$xLen'"
    } elseif {$xiLen==0} {
        error "Length of interpolation points list xi must be more than zero"
    }
    ::tclinterp::lists2arrays [list xArray yArray xiArray] [list $x $y $xi]
    if {[::tclinterp::r8vec_ascends_strictly $xLen $xArray]==0} {
        error "Independent variable array x not strictly increasing"
    }
    set yiArray [::tclinterp::interp_linear 1 $xLen $xArray $yArray $xiLen $xiArray]
    set yiList [::tclinterp::array2list $yiArray $xiLen]
    ::tclinterp::deleteArrays $xArray $yArray $xiArray $yiArray
    return $yiList
}

proc ::tclinterp::interpNear1d {args} {
    # Does nearest one-dimensional interpolation.
    #  -x - list of independent variable (x) values
    #  -y - list of dependent variable (y) values
    #  -xi - list of independent variable interpolation (xi) values
    # Returns: list of interpolated dependent variable values, `yi`, at `xi`
    set arguments [argparse {
        {-x= -required}
        {-y= -required}
        {-xi= -required}
    }]
    set xLen [llength $x]
    set yLen [llength $y]
    set xiLen [llength $xi]
    if {$xLen!=$yLen} {
        error "Length of y '$yLen' must be equal to x '$xLen'"
    } elseif {$xiLen==0} {
        error "Length of interpolation points list xi must be more than zero"
    }
    ::tclinterp::lists2arrays [list xArray yArray xiArray] [list $x $y $xi]
    set yiArray [::tclinterp::interp_nearest 1 $xLen $xArray $yArray $xiLen $xiArray]
    set yiList [::tclinterp::array2list $yiArray $xiLen]
    ::tclinterp::deleteArrays $xArray $yArray $xiArray $yiArray
    return $yiList
}

proc ::tclinterp::interpLagr1d {args} {
    # Does Lagrange polynomial one-dimensional interpolation.
    #  -x - list of independent variable (x) values
    #  -y - list of dependent variable (y) values
    #  -xi - list of independent variable interpolation (xi) values
    # Returns: list of interpolated dependent variable values, `yi`, at `xi`
    set arguments [argparse {
        {-x= -required}
        {-y= -required}
        {-xi= -required}
    }]
    set xLen [llength $x]
    set yLen [llength $y]
    set xiLen [llength $xi]
    if {$xLen!=$yLen} {
        error "Length of y '$yLen' must be equal to x '$xLen'"
    } elseif {$xiLen==0} {
        error "Length of interpolation points list xi must be more than zero"
    }
    ::tclinterp::lists2arrays [list xArray yArray xiArray] [list $x $y $xi]
    set yiArray [::tclinterp::interp_lagrange 1 $xLen $xArray $yArray $xiLen $xiArray]
    set yiList [::tclinterp::array2list $yiArray $xiLen]
    ::tclinterp::deleteArrays $xArray $yArray $xiArray $yiArray
    return $yiList
}

proc ::tclinterp::interpLeast1d {args} {
    # Does least squares polynomial one-dimensional interpolation.
    #  -x - list of independent variable (x) values
    #  -y - list of dependent variable (y) values
    #  -xi - list of independent variable interpolation (xi) values
    #  -w - list of weights, optional
    #  -nterms - number of terms of interpolation polynom, default is 3
    #  -coeffs - select the alternative output option
    # Returns: list of interpolated dependent variable values, `yi`, at `xi`. If `-coeffs` switch is in args, the output
    # is dictionary that contains `yi` values under `yi` key, and the values of interpolation polynom coefficients under
    # the keys `b`, `c` and `d`.
    set arguments [argparse {
        {-x= -required}
        {-y= -required}
        {-xi= -required}
        -w=
        {-nterms= -default 3}
        -coeffs
    }]
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
        error "Length of y '$yLen' must be equal to x '$xLen'"
    } elseif {$xLen!=$wLen} {
        error "Length of w '$wLen' must be equal to x '$xLen'"
    } elseif {$xiLen==0} {
        error "Length of interpolation points list xi must be more than zero"
    } elseif {[string is integer -strict $nterms]==0} {
        error "Number of terms nterms '$nterms' must be of integer type"
    } elseif {$nterms<=0} {
        error "Number of terms nterms must be more than zero"
    }
    ::tclinterp::lists2arrays [list xArray yArray wArray xiArray] [list $x $y $w $xi]
    ::tclinterp::newArrays [list b c d] [list $nterms $nterms $nterms]
    # create polynomial coefficients for given data
    ::tclinterp::least_set $xLen $xArray $yArray $wArray $nterms $b $c $d
    # calculate polynomial value for each xi value
    for {set i 0} {$i<$xiLen} {incr i} {
        set iElem [::tclinterp::least_val $nterms $b $c $d [@ $xi $i]]
        lappend yiList $iElem
    }
    if {[info exists coeffs]} {
        ::tclinterp::arrays2lists [list bList cList dList] [list $b $c $d] [list $nterms $nterms $nterms]
        ::tclinterp::deleteArrays $b $c $d $xArray $yArray $xiArray
        return [dcreate yi $yiList coeffs [dcreate b $bList c $cList d $dList]]
    } else {
        ::tclinterp::deleteArrays $b $c $d $xArray $yArray $xiArray
        return $yiList
    }
    return
}

proc ::tclinterp::interpLeast1dDer {args} {
    # Does least squares polynomial one-dimensional interpolation with calculation of its derivative.
    #  -x - list of independent variable (x) values
    #  -y - list of dependent variable (y) values
    #  -xi - list of independent variable interpolation (xi) values
    #  -w - list of weights, optional
    #  -nterms - number of terms of interpolation polynom, default is 3
    #  -coeffs - select the alternative output option
    # Returns: dict of interpolated dependent variable values and its derivatives under `yi` and `yiDer` keys. If
    # `-coeffs` switch is in args, the output is dictionary that contains `yi` values under `yi` key, `yi` derivatives
    # under `yiDer` key, and the values of interpolation polynom coefficients under the keys `b`, `c` and `d`.
    set arguments [argparse {
        {-x= -required}
        {-y= -required}
        {-xi= -required}
        -w=
        {-nterms= -default 3}
        -coeffs
    }]
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
        error "Length of y '$yLen' must be equal to x '$xLen'"
    } elseif {$xLen!=$wLen} {
        error "Length of w '$wLen' must be equal to x '$xLen'"
    } elseif {$xiLen==0} {
        error "Length of interpolation points list xi must be more than zero"
    } elseif {[string is integer -strict $nterms]==0} {
        error "Number of terms nterms '$nterms' must be of integer type"
    } elseif {$nterms<=0} {
        error "Number of terms nterms must be more than zero"
    }
    ::tclinterp::lists2arrays [list xArray yArray wArray xiArray] [list $x $y $w $xi]
    ::tclinterp::newArrays [list b c d] [list $nterms $nterms $nterms]
    ::tclinterp::newDoubleps [list yiPnt yiDerPnt]
    # create polynomial coefficients for given data
    ::tclinterp::least_set $xLen $xArray $yArray $wArray $nterms $b $c $d
    # calculate polynomial value and derivative for each xi value
    for {set i 0} {$i<$xiLen} {incr i} {
        ::tclinterp::least_val2 $nterms $b $c $d [@ $xi $i] $yiPnt $yiDerPnt
        lappend yiList [::tclinterp::doublep_value $yiPnt]
        lappend yiDerList [::tclinterp::doublep_value $yiDerPnt]
    }
    if {[info exists coeffs]} {
        ::tclinterp::arrays2lists [list bList cList dList] [list $b $c $d] [list $nterms $nterms $nterms]
        ::tclinterp::deleteArrays $b $c $d $xArray $yArray $xiArray
        ::tclinterp::deleteDoubleps $yiPnt $yiDerPnt
        return [dcreate yi $yiList yiDer $yiDerList coeffs [dcreate b $bList c $cList d $dList]]
    } else {
        ::tclinterp::deleteArrays $b $c $d $xArray $yArray $xiArray
        ::tclinterp::deleteDoubleps $yiPnt $yiDerPnt
        return [dcreate yi $yiList yiDer $yiDerList]
    }
    return
}

proc ::tclinterp::genBezier {args} {
    # Finds values of general Bezier function at specified t points.
    #  -n - order of Bezier function, must be zero or more
    #  -x - list of x control points values of size n+1
    #  -y - list of y control points values of size n+1
    #  -t - list of t points at which we want to evaluate Bezier function, best results are obtained within the interval
    #   [0,1]
    # Returns: dict with lists of xi and yi points at specified t points
    set arguments [argparse {
        {-n= -required}
        {-x= -required}
        {-y= -required}
        {-t= -required}
    }]
    if {[string is integer -strict $n]==0} {
        error "Order of Bezier curve n '$n' must be of integer type"
    } elseif {$n<0} {
        error "Order of Bezier curve n '$n' must be more than or equal to zero"
    }
    set xLen [llength $x]
    set yLen [llength $y]
    set tLen [llength $t]
    if {$xLen!=[= {$n+1}]} {
        error "Length of x '$xLen' must be equal to n+1=[= {$n+1}]"
    } elseif {$yLen!=[= {$n+1}]} {
        error "Length of y '$yLen' must be equal to n+1=[= {$n+1}]"
    } elseif {$tLen==0} {
        error "Length of points list t must be more than zero"
    }
    ::tclinterp::lists2arrays [list xArray yArray] [list $x $y]
    ::tclinterp::newDoubleps [list xiPnt yiPnt]
    for {set i 0} {$i<$tLen} {incr i} {
        ::tclinterp::bc_val $n [@ $t $i] $xArray $yArray $xiPnt $yiPnt
        lappend xiList [::tclinterp::doublep_value $xiPnt]
        lappend yiList [::tclinterp::doublep_value $yiPnt]
    }
    ::tclinterp::deleteArrays $xArray $yArray
    ::tclinterp::deleteDoubleps $xiPnt $yiPnt
    return [dcreate xi $xiList yi $yiList]
}

proc ::tclinterp::bezier {args} {
    # Finds values of Bezier function at x points.
    #  -n - order of Bezier function, must be zero or more
    #  -a - start of the interval
    #  -b - end of interval
    #  -x - list of x values
    #  -y - list of y control points values of size n+1
    # Returns: yi values of Bezier function at x points
    set arguments [argparse {
        {-n= -required}
        {-a= -required}
        {-b= -required}
        {-x= -required}
        {-y= -required}
    }]
    if {[string is integer -strict $n]==0} {
        error "Order of Bezier curve n '$n' must be of integer type"
    } elseif {$n<0} {
        error "Order of Bezier curve n '$n' must be more than or equal to zero"
    } elseif {$a==$b} {
        error "Start a '$a' and end b '$b' interval values must not be equal"
    }
    set xLen [llength $x]
    set yLen [llength $y]
    if {$yLen!=[= {$n+1}]} {
        error "Length of y '$yLen' must be equal to n+1=[= {$n+1}]"
    } elseif {$xLen==0} {
        error "Length of points list x must be more than zero"
    }
    ::tclinterp::lists2arrays [list yArray] [list $y]
    for {set i 0} {$i<$xLen} {incr i} {
        lappend yiList [::tclinterp::bez_val $n [@ $x $i] $a $b $yArray]
    }
    ::tclinterp::deleteArrays $yArray
    return $yiList
}
