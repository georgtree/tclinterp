package require argparse
package provide tclinterp 0.1
load ./build/tclinterp.so

namespace eval ::tclinterp {

    namespace import ::tcl::mathop::*
    namespace export interpLin1d
    interp alias {} dget {} dict get
    interp alias {} @ {} lindex
    interp alias {} = {} expr
    interp alias {} dexist {} dict exists
}

proc ::tclinterp::createArray {list} {
    set length [llength $list]
    set a [::tclinterp::new_doubleArray $length]
    for {set i 0} {$i<$length} {incr i} {
        set iElem [@ $list $i]
        try {
            ::tclinterp::doubleArray_setitem $a $i $iElem
        } on error {errmsg erropts} {
            if {[dict get $erropts -errorcode]=="SWIG TypeError"} {
                error "List must contains only double elements, but get '$iElem'"
            } else {
                error "Array creation failed with message '$errmsg' and opts '$erropts'"
            }
        }    
    }
    return $a
}

proc ::tclinterp::array2list {array length} {
    for {set i 0} {$i<$length} {incr i} {
        lappend list [::tclinterp::doubleArray_getitem $array $i]
    }
    return $list
}

proc ::tclinterp::interpLin1d {args} {
    set arguments [argparse {
        {-x= -required}
        {-y= -required}
        {-xi -required}
    }]
    set xLen [llength $x]
    set yLen [llength $y]
    set xiLen [llength $xi]
    if {$xLen!=$yLen} {
        error "Length of x '$xLen' must be equal to y '$yLen'"
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
    ::tclinterp::delete_doubleArray $xArray
    ::tclinterp::delete_doubleArray $yArray
    ::tclinterp::delete_doubleArray $xiArray
    ::tclinterp::delete_doubleArray $yiArray
    return $yiList
}
