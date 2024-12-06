package require tcltest
namespace import ::tcltest::*

set script_path [file dirname [file normalize [info script]]]
lappend auto_path "$script_path/../"
package require tclinterp
namespace import ::tclinterp::*

set epsilon 1e-6
proc matchList {expected actual} {
    variable epsilon
    set match true
    set len [llength $expected]
    for {set i 0} {$i<$len} {incr i} {
        set exp [lindex $expected $i]
        set act [lindex $actual $i]
        if {(abs($act-$exp) > $epsilon) || (abs($act-$exp) > $epsilon)} {
            set match false
            break
        }
    }
    return $match
}
customMatch mtchLst matchList

test interpLin1dProcTest-1 {test procedure of linear 1d interpolation} -setup {
    set x [list 1 2 3 4 5]
    set y [list 1 4 9 16 25]
    set xi [list 1.5 2.5 3.5 4.5]
} -body {
    interpLin1d -x $x -y $y -xi $xi
} -result [list 2.5 6.5 12.5 20.5] -cleanup {
    unset x y xi
}

test interpLin1dProcTest-2 {test procedure of linear 1d interpolation with different lengths of lists} -setup {
    set x [list 1 2 3 4 5 6]
    set y [list 1 4 9 16 25]
    set xi [list 1.5 2.5 3.5 4.5]
} -body {
    catch {interpLin1d -x $x -y $y -xi $xi} errorStr
    return $errorStr
} -result "Length of x '6' must be equal to y '5'" -cleanup {
    unset x y xi errorStr
}

test interpLin1dProcTest-3 {test procedure of linear 1d interpolation with zero length of xi} -setup {
    set x [list 1 2 3 4 5]
    set y [list 1 4 9 16 25]
    set xi {}
} -body {
    catch {interpLin1d -x $x -y $y -xi $xi} errorStr
    return $errorStr
} -result "Length of interpolation points list xi must be more than zero" -cleanup {
    unset x y xi errorStr
}

test interpLin1dProcTest-4 {test procedure of linear 1d interpolation with different non-double value of list element} -setup {
    set x [list 1 2 3 4 5i]
    set y [list 1 4 9 16 25]
    set xi [list 1.5 2.5 3.5 4.5]
} -body {
    catch {interpLin1d -x $x -y $y -xi $xi} errorStr
    return $errorStr
} -result "List must contains only double elements, but get '5i'" -cleanup {
    unset x y xi errorStr
}

test interpLin1dProcTest-5 {test procedure of linear 1d interpolation with non-monotonic x} -setup {
    set x [list 1 2 3 5 4]
    set y [list 1 4 9 16 25]
    set xi [list 1.5 2.5 3.5 4.5]
} -body {
    catch {interpLin1d -x $x -y $y -xi $xi} errorStr
    return $errorStr
} -result "Independent variable array x not strictly increasing" -cleanup {
    unset x y xi errorStr
}

test interpLin1dProcTest-6 {test procedure of linear 1d interpolation} -match mtchLst -setup {
    set x [list -1 -0.8 -0.6 -0.4 -0.2 0 0.2 0.4 0.6 0.8 1]
    set y [list 0.0384615 0.0588235 0.1 0.2 0.5 1 0.5 0.2 0.1 0.0588235 0.0384615]
    set xi [list -1.2000 -1.1500 -1.1000 -1.0500 -1.0000 -0.9500 -0.9000 -0.8500 -1.0000 -0.7500 -0.7000 -0.6500\
                    -1.0000 -0.5500 -0.5000 -0.4500 -1.0000 -0.3500 -0.3000 -0.2500 -1.0000 -0.1500 -0.1000 -0.0500\
                    -1.0000 0.0500 0.1000 0.1500 -1.0000 0.2500 0.3000 0.3500 -1.0000 0.4500 0.5000 0.5500\
                    -1.0000 0.6500 0.7000 0.7500 -1.0000 0.8500 0.9000 0.9500 1.0000 1.0500 1.1000]
} -body {
    return [interpLin1d -x $x -y $y -xi $xi]
} -result [list 0.0180995 0.02319 0.0282805 0.033371 0.0384615 0.043552 0.0486425 0.053733 0.0384615 0.0691176\
                   0.0794118 0.0897059 0.0384615 0.125 0.15 0.175 0.0384615 0.275 0.35 0.425 0.0384615 0.625 0.75\
                   0.875 0.0384615 0.875 0.75 0.625 0.0384615 0.425 0.35 0.275 0.0384615 0.175 0.15 0.125 0.0384615\
                   0.0897059 0.0794118 0.0691176 0.0384615 0.053733 0.0486425 0.043552 0.0384615 0.033371\
                   0.0282805] -cleanup {
    unset x y xi
}

cleanupTests
