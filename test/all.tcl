package require tcltest
namespace import ::tcltest::*
set dir [file normalize [file dirname [info script]]]

package require tclinterp
configure {*}$argv -testdir $dir
runAllTests
