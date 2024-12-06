package require argparse
package provide tclinterp 0.1
set script_path [file dirname [file normalize [info script]]]


namespace eval ::tclinterp {

    namespace import ::tcl::mathop::*
    namespace export interpLin1d interpNear1d interpLagr1d interpLeast1d interpLeast1dDer
    interp alias {} dget {} dict get
    interp alias {} @ {} lindex
    interp alias {} = {} expr
    interp alias {} dexist {} dict exists
    interp alias {} dcreate {} dict create
}

proc ::tclinterp::createArray {list} {
    # Create doubleArray from the list
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

proc ::tclinterp::array2list {array length} {
    # Converts doubleArray to the list
    #  array - array object
    #  length - number of elements in array
    # Returns: list
    for {set i 0} {$i<$length} {incr i} {
        lappend list [::tclinterp::doubleArray_getitem $array $i]
    }
    return $list
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
    set xArray [::tclinterp::createArray $x]
    if {[::tclinterp::r8vec_ascends_strictly $xLen $xArray]==0} {
        error "Independent variable array x not strictly increasing"
    }
    set yArray [::tclinterp::createArray $y]
    set xiArray [::tclinterp::createArray $xi]
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
    set xArray [::tclinterp::createArray $x]
    set yArray [::tclinterp::createArray $y]
    set xiArray [::tclinterp::createArray $xi]
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
    set xArray [::tclinterp::createArray $x]
    set yArray [::tclinterp::createArray $y]
    set xiArray [::tclinterp::createArray $xi]
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
        error "Number of terms -nterms '$nterms' must be of integer type"
    } elseif {$nterms<=0} {
        error "Number of terms -nterms must be more than zero"
    }
    set xArray [::tclinterp::createArray $x]
    set yArray [::tclinterp::createArray $y]
    set wArray [::tclinterp::createArray $w]
    set xiArray [::tclinterp::createArray $xi]
    set b [::tclinterp::new_doubleArray $nterms]
    set c [::tclinterp::new_doubleArray $nterms]
    set d [::tclinterp::new_doubleArray $nterms]
    # create polynomial coefficients for given data
    ::tclinterp::least_set $xLen $xArray $yArray $wArray $nterms $b $c $d
    # calculate polynomial value for each xi value
    for {set i 0} {$i<$xiLen} {incr i} {
        set iElem [::tclinterp::least_val $nterms $b $c $d [@ $xi $i]]
        lappend yiList $iElem
    }
    if {[info exists coeffs]} {
        set bList [::tclinterp::array2list $b $nterms]
        set cList [::tclinterp::array2list $c $nterms]
        set dList [::tclinterp::array2list $d $nterms]
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
        error "Number of terms -nterms '$nterms' must be of integer type"
    } elseif {$nterms<=0} {
        error "Number of terms -nterms must be more than zero"
    }
    set xArray [::tclinterp::createArray $x]
    set yArray [::tclinterp::createArray $y]
    set wArray [::tclinterp::createArray $w]
    set xiArray [::tclinterp::createArray $xi]
    set b [::tclinterp::new_doubleArray $nterms]
    set c [::tclinterp::new_doubleArray $nterms]
    set d [::tclinterp::new_doubleArray $nterms]
    set yiPnt [::tclinterp::new_doublep]
    set yiDerPnt [::tclinterp::new_doublep]
    # create polynomial coefficients for given data
    ::tclinterp::least_set $xLen $xArray $yArray $wArray $nterms $b $c $d
    # calculate polynomial value and derivative for each xi value
    for {set i 0} {$i<$xiLen} {incr i} {
        ::tclinterp::least_val2 $nterms $b $c $d [@ $xi $i] $yiPnt $yiDerPnt
        lappend yiList [::tclinterp::doublep_value $yiPnt]
        lappend yiDerList [::tclinterp::doublep_value $yiDerPnt]
    }
    if {[info exists coeffs]} {
        set bList [::tclinterp::array2list $b $nterms]
        set cList [::tclinterp::array2list $c $nterms]
        set dList [::tclinterp::array2list $d $nterms]
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
