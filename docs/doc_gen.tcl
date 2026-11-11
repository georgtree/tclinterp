package require ruff
package require fileutil
set docDir [file dirname [file normalize [info script]]]
set projectRoot [file normalize [file join $docDir ..]]
set sourceDir "${docDir}/../"
source [file join $docDir doc_include.tcl]
source [file join $docDir startPage.ruff]
source [file join $docDir rbcBindings.ruff]
source [file join $docDir examples.ruff]
source [file join $sourceDir tclinterp.tcl]

set packageVersion [package provide tclinterp]
if {$packageVersion eq {}} {
    return -code error "Package version is empty"
}
set title "Tcl wrapper for C interpolation procedures"
set commonSphinx [list -title $title -sortnamespaces false -preamble $startPage -pagesplit namespace\
                          -recurse false -includesource false -pagesplit namespace -autopunctuate true -compact false\
                          -excludeprocs {^[A-Z].*} -includeprivate false -product tclinterp -diagrammer "ditaa
                          --border-width 1" -version $packageVersion -copyright "George Yashin" {*}$::argv]
set commonNroff [list -title $title -sortnamespaces false -preamble $startPage -pagesplit namespace -recurse false\
                         -pagesplit namespace -autopunctuate true -compact false -includeprivate false\
                         -excludeprocs {^[A-Z].*} -product tclinterp -diagrammer "ditaa --border-width 1"\
                         -version $packageVersion -copyright "George Yashin" {*}$::argv]
set namespaces [list rbcBindings Examples ::tclinterp ::tclinterp::approximation ::tclinterp::interpolation]

foreach ns $namespaces {
    set preambleVar "${ns}::_ruff_preamble"
    if {[info exists $preambleVar]} {
        set $preambleVar [::docgen::expandIncludes [set $preambleVar] $projectRoot]
    }
}

ruff::document $namespaces -format sphinx -outfile tclinterp.rst -outdir [file join $docDir sphinx] {*}$commonSphinx
ruff::document $namespaces -format nroff -outdir $docDir -outfile tclinterp.n {*}$commonNroff

::fileutil::appendToFile [file join $docDir sphinx conf.py] {
extensions = list(dict.fromkeys(globals().get("extensions", []) + [
    "sphinx_rtd_theme",
    "sphinx.ext.githubpages",
    "sphinx.ext.mathjax",
]))
html_theme = "sphinx_rtd_theme"
html_theme_options = {
    "collapse_navigation": False,
    "sticky_navigation": True,
    "navigation_depth": 4,
    "includehidden": True,
    "titles_only": False,
}
# manual.css is maintained directly in the published _static directory.
# Do not ask Sphinx to copy that directory onto itself.
html_static_path = []
html_css_files = list(globals().get("html_css_files", [])) + ["manual.css"]
from pygments.lexers.tcl import TclLexer
from pygments.token import Operator

class MyTclLexer(TclLexer):
    def get_tokens_unprocessed(self, text):
        for i, t, v in super().get_tokens_unprocessed(text):
            if v == "=":
                yield i, Operator, v   # or Name.Builtin
            elif v == "$":
                yield i, Operator, v   # or Name.Builtin
            elif v == "\\":
                yield i, Operator, v   # or Name.Builtin
            elif v == "%":
                yield i, Operator, v   # or Name.Builtin
            elif v == "'":
                yield i, Operator, v   # or Name.Builtin
            else:
                yield i, t, v

def setup(app):
    from sphinx.highlighting import lexers
    lexers["tcl"] = MyTclLexer()
}
# Use one Python environment for Sphinx and the RTD theme; propagate failures.
set python python
if {[info exists ::env(DOC_PYTHON)] && $::env(DOC_PYTHON) ne {}} {
    set python $::env(DOC_PYTHON)
}
if {![file readable [file join $docDir _static manual.css]]} {
    error "missing documentation stylesheet: [file join $docDir _static manual.css]"
}
exec -- $python -m sphinx -E -a -b html [file join $docDir sphinx] $docDir >@stdout 2>@stderr

# Embed the chart already written by its example into docs/assets/charts.
# relativePath is relative to docs, including the simulator subdirectory if any.
# Keep the responsive addition idempotent; never copy the chart to another file.
proc chartFrame {relativePath} {
    global docDir
    set filename [file join $docDir $relativePath]
    set html [::fileutil::cat $filename]
    set height 0
    foreach {match pixels} [regexp -all -inline {height:\s*([0-9]+)px} $html] {
        set height [expr {max($height, $pixels)}]
    }
    if {$height == 0} {set height 500}
    # Keep ECharts' coordinate system in sync with the available RTD width.
    set responsive {
<style>
html, body { margin: 0; padding: 0; }
.chart-container { max-width: 100%; }
</style>
<script>
window.addEventListener("load", function () {
    document.querySelectorAll(".chart-container").forEach(function (element) {
        function resize() {
            const chart = window.echarts && echarts.getInstanceByDom(element);
            if (chart) chart.resize();
        }
        resize();
        if (window.ResizeObserver) new ResizeObserver(resize).observe(element);
        else window.addEventListener("resize", resize);
    });
});
</script>
}
    if {[string first $responsive $html] < 0} {
        set html [string map [list </head> "$responsive</head>"] $html]
        ::fileutil::writeFile $filename $html
    }
    set name [file tail $filename]
    set title [string map [list & &amp\; \" &quot\; < &lt\; > &gt\;] [file rootname $name]]
    return "<iframe class=\"doc-chart\" src=\"$relativePath\" title=\"$title\" height=\"$height\" loading=\"lazy\"></iframe>"
}

proc processContents {fileContents} {
    global path chartsMap
    dict for {mark file} $chartsMap {
        set fileData [chartFrame [file join $path $file]]
        set fileContents [string map [list "<p>$mark</p>" $fileData $mark $fileData] $fileContents]
    }
    return $fileContents
}


set chartsMap [dict create !ticklechart_mark_linear_near_interpolation! linear_near_interpolation.html]
set path assets/charts
fileutil::updateInPlace [file join $docDir tclinterp-Examples.html] processContents

# nroff pages names processing
foreach file [glob -directory $docDir *.n] {
    set old $file
    set tmp [file join $docDir __temp_rename__.n]
    set new [file join $docDir [string tolower [file tail $file]]]
    if {$old eq $new} {
        continue
    }
    file rename -force $old $tmp
    file rename -force $tmp $new
}
set specialPages [list tclinterp-examples tclinterp-rbcbindings]
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
tclinterp-rbcbindings(n) - description of RBC vectors support
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
