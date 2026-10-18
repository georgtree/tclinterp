# docs-begin import-packages
package require tclinterp
package require rbc::graphtoolbar
package require ticklecharts
namespace import rbc::vector
namespace import rbc::graphtoolbar
namespace import ::tclinterp::*
namespace import ::tclinterp::interpolation::*
# docs-end import-packages

# create data to intepolate
# docs-begin generate-input-data
set xmin 0
set xmax 1
set step 0.05
set stepInterp 0.01
vector create x y xInterp yExact
x seq $xmin $xmax $step
y expr {sin(x*10)+1.1}
xInterp seq $xmin $xmax $stepInterp
yExact expr {sin(xInterp*10)+1.1}
# docs-end generate-input-data

# linear interpolation
# docs-begin linear-interpolation
lin1d -input vector -output vector -x x -y y -xi xInterp -name yInterpLin
# docs-end linear-interpolation

# nearest linear interpolation
# docs-begin nearest-interpolation
near1d -input vector -output vector -x x -y y -xi xInterp -name yInterpNear
# docs-end nearest-interpolation

# errors calculation
# docs-begin calculate-errors
vector expr -name interpErrorLin {(yExact-yInterpLin)/yExact}
vector expr -name interpErrorNear {(yExact-yInterpNear)/yExact}
# docs-end calculate-errors

# plot interpolated data and errors
# docs-begin plot-rbc
option add *Element.Pixels 3
option add *Element.LineWidth 2
option add *Legend.Position top
option add *Grid.Hide no
set graphInterp [graphtoolbar .g1 -width 800 -height 250 -type graph -controlmode context -zoom -crosshairs\
                         -crosshairsmode closest -crosshairsclosestopts {-interpolate no} -pan -zoomwheel -activelegend]
$graphInterp graph element create initial -label {Initial data} -x x -y y -color #5470c6
$graphInterp graph element create linear -label {Linear interpolation} -x xInterp -y yInterpLin -color #91cc75
$graphInterp graph element create nearest -label {Nearest interpolation} -x xInterp -y yInterpNear -color #fac858
set graphError [graphtoolbar .g2 -width 800 -height 250 -type graph -controlmode context -zoom -crosshairs\
                         -crosshairsmode closest -crosshairsclosestopts {-interpolate no} -pan -zoomwheel -activelegend]
$graphError graph axis configure y -title {Rel. error, %}
$graphError graph element create linear -label {Linear interpolation error} -x xInterp -y interpErrorLin -color #ee6666
$graphError graph element create nearest -label {Nearest interpolation error} -x xInterp -y interpErrorNear\
        -color #73c0de
grid $graphInterp -row 0 -column 0 -sticky nsew
grid $graphError -row 1 -column 0 -sticky nsew
grid columnconfigure . 0 -weight 1
grid rowconfigure . 0 -weight 1
grid rowconfigure . 1 -weight 1
set fbasename [file rootname [file tail [info script]]]
$graphInterp graph svg output [file normalize [file join .. docs assets images $fbasename.svg]]
$graphError graph svg output [file normalize [file join .. docs assets images ${fbasename}_error.svg]]
# docs-end plot-rbc

