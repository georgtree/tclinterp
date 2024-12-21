package require argparse
package provide tclinterp

interp alias {} dget {} dict get
interp alias {} @ {} lindex
interp alias {} = {} expr
interp alias {} dexist {} dict exists
interp alias {} dcreate {} dict create

namespace eval ::tclinterp {
    namespace import ::tcl::mathop::*
    namespace eval interpolation {
        namespace export lin1d near1d lagr1d least1d least1dDer divDif1d cubicSpline1d hermiteSpline1d
    }
    namespace eval approximation {
        namespace export genBezier bezier cubicBSpline1d cubicBetaSpline1d
    }
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

proc ::tclinterp::duplListCheck {list} {
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


### Linear interpolations

proc ::tclinterp::interpolation::lin1d {args} {
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
        error "Length of -y '$yLen' must be equal to length of -x '$xLen'"
    } elseif {$xiLen==0} {
        error "Length of interpolation points list -xi must be more than zero"
    }
    ::tclinterp::lists2arrays [list xArray yArray xiArray] [list $x $y $xi]
    if {[::tclinterp::r8vec_ascends_strictly $xLen $xArray]==0} {
        error "Independent variable array -x is not strictly increasing"
    }
    set yiArray [::tclinterp::interp_linear 1 $xLen $xArray $yArray $xiLen $xiArray]
    set yiList [::tclinterp::array2list $yiArray $xiLen]
    ::tclinterp::deleteArrays $xArray $yArray $xiArray $yiArray
    return $yiList
}

proc ::tclinterp::interpolation::near1d {args} {
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
        error "Length of -y '$yLen' must be equal to length of -x '$xLen'"
    } elseif {$xiLen==0} {
        error "Length of interpolation points list -xi must be more than zero"
    }
    ::tclinterp::lists2arrays [list xArray yArray xiArray] [list $x $y $xi]
    set yiArray [::tclinterp::interp_nearest 1 $xLen $xArray $yArray $xiLen $xiArray]
    set yiList [::tclinterp::array2list $yiArray $xiLen]
    ::tclinterp::deleteArrays $xArray $yArray $xiArray $yiArray
    return $yiList
}

proc ::tclinterp::interpolation::lagr1d {args} {
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
        error "Length of -y '$yLen' must be equal to length of -x '$xLen'"
    } elseif {$xiLen==0} {
        error "Length of interpolation points list -xi must be more than zero"
    }
    ::tclinterp::lists2arrays [list xArray yArray xiArray] [list $x $y $xi]
    set yiArray [::tclinterp::interp_lagrange 1 $xLen $xArray $yArray $xiLen $xiArray]
    set yiList [::tclinterp::array2list $yiArray $xiLen]
    ::tclinterp::deleteArrays $xArray $yArray $xiArray $yiArray
    return $yiList
}

### Spline interpolation

#### Least squares polynomial interpolation

proc ::tclinterp::interpolation::least1d {args} {
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
        return -code error "Length of -y '$yLen' must be equal to length of -x '$xLen'"
    } elseif {$xLen!=$wLen} {
        return -code error "Length of -w '$wLen' must be equal to length of -x '$xLen'"
    } elseif {$xiLen==0} {
        return -code error "Length of interpolation points list -xi must be more than zero"
    } elseif {[string is integer -strict $nterms]==0} {
        return -code error "Number of terms -nterms '$nterms' must be of integer type"
    } elseif {$nterms<=0} {
        return -code error "Number of terms -nterms must be more than zero"
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

proc ::tclinterp::interpolation::least1dDer {args} {
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
        return -code error "Length of -y '$yLen' must be equal to length of -x '$xLen'"
    } elseif {$xLen!=$wLen} {
        return -code error "Length of -w '$wLen' must be equal to length of -x '$xLen'"
    } elseif {$xiLen==0} {
        return -code error "Length of interpolation points list -xi must be more than zero"
    } elseif {[string is integer -strict $nterms]==0} {
        return -code error "Number of terms -nterms '$nterms' must be of integer type"
    } elseif {$nterms<=0} {
        return -code error "Number of terms -nterms must be more than zero"
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

#### Bezier functions approximation

proc ::tclinterp::approximation::genBezier {args} {
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
        return -code error "Order of Bezier curve -n '$n' must be of integer type"
    } elseif {$n<0} {
        return -code error "Order of Bezier curve -n '$n' must be more than or equal to zero"
    }
    set xLen [llength $x]
    set yLen [llength $y]
    set tLen [llength $t]
    if {$xLen!=[= {$n+1}]} {
        return -code error "Length of -x '$xLen' must be equal to n+1=[= {$n+1}]"
    } elseif {$yLen!=[= {$n+1}]} {
        return -code error "Length of -y '$yLen' must be equal to n+1=[= {$n+1}]"
    } elseif {$tLen==0} {
        return -code error "Length of points list -t must be more than zero"
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

proc ::tclinterp::approximation::bezier {args} {
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
        return -code error "Order of Bezier curve -n '$n' must be of integer type"
    } elseif {$n<0} {
        return -code error "Order of Bezier curve -n '$n' must be more than or equal to zero"
    } elseif {$a==$b} {
        return -code error "Start -a '$a' and end -b '$b' values of interval must not be equal"
    }
    set xLen [llength $x]
    set yLen [llength $y]
    if {$yLen!=[= {$n+1}]} {
        return -code error "Length of -y '$yLen' must be equal to n+1=[= {$n+1}]"
    } elseif {$xLen==0} {
        return -code error "Length of points list -x must be more than zero"
    }
    ::tclinterp::lists2arrays [list yArray] [list $y]
    for {set i 0} {$i<$xLen} {incr i} {
        lappend yiList [::tclinterp::bez_val $n [@ $x $i] $a $b $yArray]
    }
    ::tclinterp::deleteArrays $yArray
    return $yiList
}

#### Divided difference interpolation

proc ::tclinterp::interpolation::divDif1d {args} {
    # Does divided difference one-dimensional interpolation.
    #  -x - list of independent variable (x) values
    #  -y - list of dependent variable (y) values
    #  -xi - list of independent variable interpolation (xi) values
    #  -coeffs - select the alternative output option
    # Returns: list of interpolated dependent variable values, `yi`, at `xi`. If `-coeffs` switch is in args, the output
    # is dictionary that contains `yi` values under `yi` key, and the values of difference table under the key `coeffs`.
    set arguments [argparse {
        {-x= -required}
        {-y= -required}
        {-xi= -required}
        -coeffs
    }]
    set xLen [llength $x]
    set yLen [llength $y]
    set xiLen [llength $xi]
    if {$xLen!=$yLen} {
        return -code error "Length of -y '$yLen' must be equal to length of -x '$xLen'"
    } elseif {$xiLen==0} {
        return -code error "Length of interpolation points list -xi must be more than zero"
    }
    if {[::tclinterp::duplListCheck $x]=="true"} {
        return -code error "List of -x values must not contain duplicated elements"
    }
    ::tclinterp::lists2arrays [list xArray yArray] [list $x $y]
    ::tclinterp::newArrays [list difTab] [list $xLen]
    # create difference table for given data
    ::tclinterp::data_to_dif $xLen $xArray $yArray $difTab
    # calculate polynomial value for each xi value
    for {set i 0} {$i<$xiLen} {incr i} {
        set iElem [::tclinterp::dif_val $xLen $xArray $difTab [@ $xi $i]]
        lappend yiList $iElem
    }
    if {[info exists coeffs]} {
        ::tclinterp::arrays2lists [list difTabList] [list $difTab] [list $xLen]
        ::tclinterp::deleteArrays $difTab $xArray $yArray
        return [dcreate yi $yiList coeffs $difTabList]
    } else {
        ::tclinterp::deleteArrays $difTab $xArray $yArray
        return $yiList
    }
    return
}

#### Cubic B spline approximation

proc ::tclinterp::approximation::cubicBSpline1d {args} {
    # Evaluates a cubic B spline approximant.
    #  -t - list of independent variable (t) values
    #  -y - list of dependent variable (y) values
    #  -ti - list of independent variable interpolation (ti) values
    # Returns: list of approximation values yi at ti points.
    set arguments [argparse {
        {-t= -required}
        {-y= -required}
        {-ti= -required}
    }]
    set tLen [llength $t]
    set yLen [llength $y]
    set tiLen [llength $ti]
    if {$tLen!=$yLen} {
        return -code error "Length of -y '$yLen' must be equal to length of -t '$tLen'"
    } elseif {$tiLen==0} {
        return -code error "Length of interpolation points list -ti must be more than zero"
    }
    ::tclinterp::lists2arrays [list tArray yArray] [list $t $y]
    for {set i 0} {$i<$tiLen} {incr i} {
        set iElem [::tclinterp::spline_b_val $tLen $tArray $yArray [@ $ti $i]]
        lappend yiList $iElem
    }
    ::tclinterp::deleteArrays $tArray $yArray
    return $yiList
}

#### Cubic beta spline approximation

proc ::tclinterp::approximation::cubicBetaSpline1d {args} {
    # Evaluates a cubic beta spline approximant.
    #  -beta1 - the skew or bias parameter, beta1 = 1 for no skew or bias
    #  -beta2 - the tension parameter, beta2 = 0 for no tension
    #  -t - list of independent variable (t) values
    #  -y - list of dependent variable (y) values
    #  -ti - list of independent variable interpolation (ti) values
    # Returns: list of approximation values yi at ti points.
    set arguments [argparse {
        {-beta1= -required}
        {-beta2= -required}
        {-t= -required}
        {-y= -required}
        {-ti= -required}
    }]
    set tLen [llength $t]
    set yLen [llength $y]
    set tiLen [llength $ti]
    if {$tLen!=$yLen} {
        return -code error "Length of -y '$yLen' must be equal to length of -t '$tLen'"
    } elseif {$tiLen==0} {
        return -code error "Length of interpolation points list -ti must be more than zero"
    } elseif {[string is double -strict $beta1]==0} {
        return -code error "-beta1 '$beta1' must be of double type"
    } elseif {[string is double -strict $beta2]==0} {
        return -code error "-beta1 '$beta2' must be of double type"
    }
    ::tclinterp::lists2arrays [list tArray yArray] [list $t $y]
    for {set i 0} {$i<$tiLen} {incr i} {
        set iElem [::tclinterp::spline_beta_val $beta1 $beta2 $tLen $tArray $yArray [@ $ti $i]]
        lappend yiList $iElem
    }
    ::tclinterp::deleteArrays $tArray $yArray
    return $yiList
}

#### Piecewise cubic spline interpolation

proc ::tclinterp::interpolation::cubicSpline1d {args} {
    # Does piecewise cubic spline interpolation.
    #  -ibcbeg - left boundary condition flag. Possible values:
    #   **quad**, the cubic spline should be a quadratic over the first interval;
    #   **der1**, the first derivative at the left endpoint should be YBCBEG;
    #   **der2**, the second derivative at the left endpoint should be YBCBEG;
    #   **notaknot**, not-a-knot, the third derivative is continuous at T(2).
    #  -ibcend - right boundary condition flag. Possible values:
    #   **quad**, the cubic spline should be a quadratic over the last interval;
    #   **der1**, the first derivative at the right endpoint should be YBCBEG;
    #   **der2**, the second derivative at the right endpoint should be YBCBEG;
    #   **notaknot**, not-a-knot, the third derivative is continuous at T(2).
    #  -ybcbeg - the values to be used in the boundary conditions if ibcbeg is equal to der1 or der2, default is 0.0
    #  -ybcend - the values to be used in the boundary conditions if ibcend is equal to der1 or der2, default is 0.0
    #  -t - list of independent variable (t) values
    #  -y - list of dependent variable (y) values
    #  -ti - list of independent variable interpolation (ti) values
    #  -deriv - select the alternative output option
    # Returns: list of interpolated dependent variable values under. If `-deriv` switch is in args, the output is
    # dictionary that contains `yi` values under `yi` key, `yi` derivative under `yder1` key, and `yi` second derivative
    # under `yder2` key.
    set arguments [argparse {
        {-ibcbeg= -default quad -enum {quad der1 der2 notaknot}}
        {-ibcend= -default quad -enum {quad der1 der2 notaknot}}
        {-ybcbeg= -default 0.0}
        {-ybcend= -default 0.0}
        {-t= -required}
        {-y= -required}
        {-ti= -required}
        -deriv
    }]
    set keyMap [dcreate quad 0 der1 1 der2 2 notaknot 3]
    set tLen [llength $t]
    set yLen [llength $y]
    set tiLen [llength $ti]
    if {$tLen!=$yLen} {
        return -code error "Length of -y '$yLen' must be equal to length of -t '$tLen'"
    } elseif {$tiLen==0} {
        return -code error "Length of interpolation points list -ti must be more than zero"
    }
    ::tclinterp::lists2arrays [list tArray yArray] [list $t $y]
    ::tclinterp::newArrays [list yppArray] [list $tLen]
    ::tclinterp::newDoubleps [list ypPnt yppPnt]
    set yppArray [::tclinterp::spline_cubic_set $tLen $tArray $yArray [dget $keyMap $ibcbeg] $ybcbeg\
                          [dget $keyMap $ibcend] $ybcend]
    for {set i 0} {$i<$tiLen} {incr i} {
        set iElem [::tclinterp::spline_cubic_val $tLen $tArray $yArray $yppArray [@ $ti $i] $ypPnt $yppPnt]
        lappend yiList $iElem
        lappend ypList [::tclinterp::doublep_value $ypPnt]
        lappend yppList [::tclinterp::doublep_value $yppPnt]
    }
    ::tclinterp::deleteArrays $tArray $yArray $yppArray
    ::tclinterp::deleteDoubleps $ypPnt $yppPnt
    if {[info exists deriv]} {
        return [dict create yi $yiList yder1 $ypList yder2 $yppList]
    } else {
        return $yiList
    }
}

#### Hermite polynomial spline interpolation

proc ::tclinterp::interpolation::hermiteSpline1d {args} {
    # Does Hermite polynomial spline interpolation.
    #  -t - list of independent variable (t) values
    #  -y - list of dependent variable (y) values
    #  -yp - list of dependent variable (y) derivative values
    #  -ti - list of independent variable interpolation (ti) values
    #  -deriv - select the alternative output option
    # Returns: list of interpolated dependent variable values under. If `-deriv` switch is in args, the output is
    # dictionary that contains `yi` values under `yi` key, `yi` derivative under `yder1` key.
    set arguments [argparse {
        {-t= -required}
        {-y= -required}
        {-yp= -required}
        {-ti= -required}
        -deriv
    }]
    set tLen [llength $t]
    set yLen [llength $y]
    set ypLen [llength $yp]
    set tiLen [llength $ti]
    if {$tLen!=$yLen} {
        return -code error "Length of -y '$yLen' must be equal to length of -t '$tLen'"
    } elseif {$tLen!=$ypLen} {
        return -code error "Length of -yp '$ypLen' must be equal to length of -t '$tLen'"
    } elseif {$tiLen==0} {
        return -code error "Length of interpolation points list -ti must be more than zero"
    }
    ::tclinterp::lists2arrays [list tArray yArray ypArray] [list $t $y $yp]
    if {[::tclinterp::r8vec_ascends_strictly $tLen $tArray]==0} {
        error "Independent variable array -t is not strictly increasing"
    }
    ::tclinterp::newArrays [list cArray] [list [= {$tLen*4}]]
    ::tclinterp::newDoubleps [list yiPnt yipPnt]
    set cArray [::tclinterp::spline_hermite_set $tLen $tArray $yArray $ypArray]
    for {set i 0} {$i<$tiLen} {incr i} {
        ::tclinterp::spline_hermite_val $tLen $tArray $cArray [@ $ti $i] $yiPnt $yipPnt
        lappend yiList [::tclinterp::doublep_value $yiPnt]
        lappend yipList [::tclinterp::doublep_value $yipPnt]
    }
    ::tclinterp::deleteArrays $tArray $yArray $cArray $ypArray
    ::tclinterp::deleteDoubleps $yiPnt $yipPnt
    if {[info exists deriv]} {
        return [dict create yi $yiList yder1 $yipList]
    } else {
        return $yiList
    }
}
