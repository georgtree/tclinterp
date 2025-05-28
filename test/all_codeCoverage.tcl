package require tcltest
namespace import ::tcltest::*
set dir [file normalize [file dirname [info script]]]

load [file join $dir .. libtcl9tclinterp0.15.so]
source [file join $dir .. tclinterp.tcl]
source [file join $dir test.test]
