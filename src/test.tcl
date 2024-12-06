package require tcltest
namespace import ::tcltest::*

set script_path [file dirname [file normalize [info script]]]
lappend auto_path "$script_path/../"
package require tclinterp
namespace import ::tclinterp::*

puts [interpLin1d -x [list 1 2 3 4 5] -y [list 1 4 9 16 25] -xi [list 1.5 2.5 3.5 4.5]]

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

test interpLin1dProcTest-3 {test procedure of linear 1d interpolation with different non-double value of list element} -setup {
    set x [list 1 2 3 4 5i]
    set y [list 1 4 9 16 25]
    set xi [list 1.5 2.5 3.5 4.5]
} -body {
    catch {interpLin1d -x $x -y $y -xi $xi} errorStr
    return $errorStr
} -result "Element of list must be of type double" -cleanup {
    unset x y xi errorStr
}

cleanupTests
