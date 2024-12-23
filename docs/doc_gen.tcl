
set path_to_hl_tcl "/home/georgtree/tcl/hl_tcl"
package require ruff
package require fileutil
package require hl_tcl
set dir [file dirname [file normalize [info script]]]
set sourceDir "${dir}/../"
source [file join $dir startPage.ruff]
source [file join $sourceDir tclinterp.tcl]

set packageVersion [package versions tclinterp]
set title "Tcl wrapper for C interpolation procedures"
puts $packageVersion
set commonHtml [list -title $title -sortnamespaces false -preamble $startPage -pagesplit namespace -recurse false\
                        -includesource true -pagesplit namespace -autopunctuate true -compact false\
                        -includeprivate true -product tcl_tools -diagrammer "ditaa --border-width 1"\
                        -version $packageVersion -copyright "George Yashin" {*}$::argv]
set commonNroff [list -title $title -sortnamespaces false -preamble $startPage -pagesplit namespace -recurse false\
                         -pagesplit namespace -autopunctuate true -compact false -includeprivate true\
                         -product tcl_tools -diagrammer "ditaa --border-width 1" -version $packageVersion\
                         -copyright "George Yashin" {*}$::argv]
set namespaces [list ::tclinterp ::tclinterp::approximation ::tclinterp::interpolation]

if {[llength $argv] == 0 || "html" in $argv} {
    ruff::document $namespaces -format html -outdir $dir -outfile index.html {*}$commonHtml
    ruff::document $namespaces -format nroff -outdir $dir -outfile tclinterp.n {*}$commonNroff
}

foreach file [glob *.html] {
    exec tclsh "${path_to_hl_tcl}/tcl_html.tcl" "./$file"
}

proc processContents {fileContents} {
    # Search: AA, replace: aa
    return [string map {max-width:60rem max-width:100rem} $fileContents]
}

fileutil::updateInPlace ./assets/ruff-min.css processContents
