package require tclinterp
package require ticklecharts
namespace import ::tclinterp::*
namespace import ::tclinterp::interpolation::*
namespace import ::tclinterp::approximation::*

proc sinFunc {x} {
    return [= {sin($x*10)+1.1}]
}
proc relError {ref act} {
    return [= {($ref-$act)*100/$ref}]
}

proc genSeq {xmin xmax step func} {
    for {set i 0} {$i<=[= {($xmax-$xmin)/$step}]} {incr i} {
        set xval [= {$xmin+$i*$step}]
        lappend x $xval
        lappend y [$func $xval]
    }
    return [list $x $y]
}

# create data to intepolate
set xmin 0
set xmax 1
set step 0.05
set stepInterp 0.01
lassign [genSeq $xmin $xmax $step sinFunc] x y
lassign [genSeq $xmin $xmax $stepInterp sinFunc] xInterp yExact

# input data
set xydata [lmap xi $x yi $y {list $xi $yi}]
# linear interpolation
set yInterpLin [lin1d -x $x -y $y -xi $xInterp]
set xydataInterpLin [lmap xi $xInterp yi $yInterpLin {list $xi $yi}]
# nearest linear interpolation
set yInterpNear [near1d -x $x -y $y -xi $xInterp]
set xydataInterpNear [lmap xi $xInterp yi $yInterpNear {list $xi $yi}]
# exact data at interpolation points
set xydataExact [lmap xi $xInterp yi $yExact {list $xi $yi}]
# errors calculation
set interpErrorLin [lmap xi $xInterp yiExact $yExact yiInterpLin $yInterpLin {list $xi [relError $yiExact $yiInterpLin]}]
set interpErrorNear [lmap xi $xInterp yiExact $yExact yiInterpNear $yInterpNear\
                             {list $xi [relError $yiExact $yiInterpNear]}]

# plot interpolated data and errors
set chart [ticklecharts::chart new]
$chart Xaxis -name "x" -minorTick {show "True"} -min 0 -max 1 -type "value" -splitLine {show "True"}
$chart Yaxis -name "y" -minorTick {show "True"} -min 0 -max 2.5 -type "value" -splitLine {show "True"}
$chart SetOptions -title {} -legend {top "0%" left "20%"} -tooltip {trigger "axis"} -animation "False"\
        -toolbox {feature {dataZoom {yAxisIndex "none"}}}
$chart Add "lineSeries" -data $xydata -showAllSymbol "nothing" -name "Initial data"
$chart Add "lineSeries" -data $xydataInterpLin -showAllSymbol "nothing" -name "Linear interpolation"
$chart Add "lineSeries" -data $xydataInterpNear -showAllSymbol "nothing" -name "Nearest interpolation"
$chart Add "lineSeries" -data $xydataExact -showAllSymbol "nothing" -name "Exact data"

set chartError [ticklecharts::chart new]
$chartError Xaxis -name "x" -minorTick {show "True"} -min 0 -max 1 -type "value" -splitLine {show "True"}
$chartError Yaxis -name "Rel. error, %" -minorTick {show "True"} -type "value" -splitLine {show "True"}
$chartError SetOptions -title {} -legend {top "50%" left "30%"} -tooltip {} -animation "False"\
        -toolbox {feature {dataZoom {yAxisIndex "none"}}}
$chartError Add "lineSeries" -data $interpErrorLin -showAllSymbol "nothing" -name "Linear interpolation error"
$chartError Add "lineSeries" -data $interpErrorNear -showAllSymbol "nothing" -name "Nearest interpolation error"

# create multiplot
set layout [ticklecharts::Gridlayout new]
$layout Add $chart -bottom "55%" -height "40%" -width "80%"
$layout Add $chartError -bottom "5%" -height "40%" -width "80%"

# save to file
set fbasename [file rootname [file tail [info script]]]
$layout Render -outfile [file normalize [file join html_charts $fbasename.html]] -height 800px
