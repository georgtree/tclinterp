package require tclinterp
package require rbc::vector
::rbc::vector create x y xi -variable {}
x set {0 1}
y set {0 2}
xi set {0.25 0.75}
set yi [::tclinterp::interpolation::lin1d -x x -y y -xi xi -input vector -output vector]
if {[$yi index :] ne {0.5 1.5}} {
    error "Unexpected linear interpolation result: [$yi index :]"
}
