
package require ruff
package require fileutil
set docDir [file dirname [file normalize [info script]]]
set sourceDir "${docDir}/../"
source [file join $docDir startPage.ruff]
source [file join $docDir examples.ruff]
source [file join $sourceDir tclinterp.tcl]

set packageVersion [package versions tclinterp]
if {$packageVersion eq {}} {
    return -code error "Package version is empty"
}
set title "Tcl wrapper for C interpolation procedures"
set commonSphinx [list -title $title -sortnamespaces false -preamble $startPage -pagesplit namespace -recurse false\
                        -includesource false -pagesplit namespace -autopunctuate true -compact false\
                        -excludeprocs {^[A-Z].*} -includeprivate false -product tclinterp\
                        -diagrammer "ditaa --border-width 1" -version $packageVersion -copyright "George Yashin"\
                        {*}$::argv]
set commonNroff [list -title $title -sortnamespaces false -preamble $startPage -pagesplit namespace -recurse false\
                         -pagesplit namespace -autopunctuate true -compact false -includeprivate false\
                         -excludeprocs {^[A-Z].*} -product tclinterp -diagrammer "ditaa --border-width 1"\
                         -version $packageVersion -copyright "George Yashin" {*}$::argv]
set namespaces [list Examples ::tclinterp::approximation ::tclinterp::interpolation]

ruff::document $namespaces -format sphinx -outfile tclinterp.rst -outdir [file join $docDir sphinx] {*}$commonSphinx
ruff::document $namespaces -format nroff -outdir $docDir -outfile tclinterp.n {*}$commonNroff

::fileutil::appendToFile [file join $docDir sphinx conf.py] {html_theme = "classic"
extensions = [
    "sphinx.ext.githubpages",
]
from pygments.lexers.tcl import TclLexer
from pygments.token import Operator

class MyTclLexer(TclLexer):
    def get_tokens_unprocessed(self, text):
        for i, t, v in super().get_tokens_unprocessed(text):
            if v == "=":
                yield i, Operator, v   # or Name.Builtin
            else:
                yield i, t, v

def setup(app):
    from sphinx.highlighting import lexers
    lexers["tcl"] = MyTclLexer()
}
catch {exec sphinx-build -b html [file join $docDir sphinx] [file join $docDir]} errorStr
puts $errorStr

proc processContents {fileContents} {
    global path chartsMap
    dict for {mark file} $chartsMap {
        set fileData [fileutil::cat [file join $path $file]]
        set fileContents [string map [list $mark $fileData] $fileContents]
    }
    return $fileContents
}


set chartsMap [dict create !ticklechart_mark_linear_near_interpolation! linear_near_interpolation.html]
set path [file join $docDir .. examples html_charts]
fileutil::updateInPlace [file join $docDir tclinterp-Examples.html] processContents

# nroff pages names processing
foreach file [glob -directory $docDir *.n] {
    set old $file
    set tmp [file join $docDir __temp_rename__.n]
    set new [file join $docDir [string tolower [file tail $file]]]
    file rename $old $tmp
    file rename $tmp $new
}
set specialPages [list tclinterp-examples]
foreach namespacePath $namespaces {
    set tails [list]
    while {$namespacePath ne {}} {
        set tail [string tolower [namespace tail $namespacePath]]
        regsub -all {\s+} [string trim $tail] {-} tail
        set namespacePath [namespace qualifiers $namespacePath]
        lappend tails $tail
    }
    lappend tails [string tolower tclinterp]
    set manFileName [join [lreverse $tails] -]
    if {$manFileName ni $specialPages} {
        lappend manFilesLinks "${manFileName}(n)"
    }
}

set linksString ".SH SEE ALSO
tclinterp(n) - package's main page
.br
tclinterp-examples(n) - examples of usage with detailed explanations
.br
.sp 1
Public commands documentation:
.br
[join $manFilesLinks \n.br\n]"

proc addLinks2man {fileContents} {
    global linksString
    append fileContents "\n$linksString"
    return $fileContents
}

foreach file [glob -directory $docDir *.n] {
    fileutil::updateInPlace $file addLinks2man
}
