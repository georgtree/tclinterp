package require textutil::adjust

namespace eval ::tclinterpDoc {}

# Split a pipe row without splitting escaped pipes or pipes in inline code.
# Leading/trailing pipes are optional. Backtick runs must have matching lengths.
proc ::tclinterpDoc::TableCells {line} {
    set line [string trim $line]
    set cells {}
    set cell {}
    set code {}
    set first 1
    for {set i 0} {$i < [string length $line]} {incr i} {
        set ch [string index $line $i]
        if {$ch eq "\\" && $i + 1 < [string length $line]} {
            append cell $ch [string index $line [incr i]]
        } elseif {$ch eq "`"} {
            set run `
            while {[string index $line [expr {$i + 1}]] eq "`"} {
                append run `
                incr i
            }
            if {$code eq {}} {
                if {[string first $run $line [expr {$i + 1}]] >= 0} {set code $run}
            } elseif {$code eq $run} {
                set code {}
            }
            append cell $run
        } elseif {$ch eq "|" && $code eq {}} {
            if {!$first || [string trim $cell] ne {}} {
                lappend cells [string trim $cell]
            }
            set cell {}
        } else {
            append cell $ch
        }
        set first 0
    }
    if {$cell ne {} || [string index $line end] ne "|" || $code ne {}} {
        lappend cells [string trim $cell]
    }
    return $cells
}

# A delimiter row must contain a pipe and only Markdown alignment markers.
proc ::tclinterpDoc::TableSeparator {line} {
    if {[string first | $line] < 0} {return {}}
    set cells [TableCells $line]
    foreach cell $cells {
        if {![regexp {^:?-{3,}:?$} $cell]} {return {}}
    }
    return $cells
}

# Reused border construction from the original README table formatter.
proc ::tclinterpDoc::TableBorder {widths left middle right} {
    set parts {}
    foreach width $widths {
        lappend parts [string repeat ─ [expr {$width + 2}]]
    }
    return "$left[join $parts $middle]$right"
}

# Distribute the available width over any number of columns. Short columns
# stay compact; long descriptions receive the remaining space. Width includes
# borders and padding, but excludes the preamble's indentation.
proc ::tclinterpDoc::TableWidths {rows maxWidth} {
    set columns [llength [lindex $rows 0]]
    set budget [expr {$maxWidth - 3*$columns - 1}]
    if {$budget < $columns} {
        error "table has too many columns for width $maxWidth"
    }
    set wanted [lrepeat $columns 1]
    foreach row $rows {
        for {set c 0} {$c < $columns} {incr c} {
            lset wanted $c [expr {max([lindex $wanted $c], [string length [lindex $row $c]])}]
        }
    }
    set widths [lrepeat $columns 1]
    incr budget -$columns
    # First allocate a readable minimum to each column, then distribute the
    # remaining space to the column with the greatest unmet content width.
    for {set target 2} {$target <= 24 && $budget > 0} {incr target} {
        for {set c 0} {$c < $columns && $budget > 0} {incr c} {
            if {[lindex $wanted $c] >= $target} {
                lset widths $c $target
                incr budget -1
            }
        }
    }
    while {$budget > 0} {
        set best -1
        set need 0
        for {set c 0} {$c < $columns} {incr c} {
            set extra [expr {[lindex $wanted $c] - [lindex $widths $c]}]
            if {$extra > $need} {set best $c; set need $extra}
        }
        if {$best < 0} {break}
        lset widths $best [expr {[lindex $widths $best] + 1}]
        incr budget -1
    }
    return $widths
}

# Wrap cells and render the existing Unicode box style used by RBC man pages.
proc ::tclinterpDoc::RenderTable {rows maxWidth} {
    set plain {}
    foreach row $rows {
        lappend plain [lmap cell $row {string map [list {\|} | ` {}] $cell}]
    }
    set widths [TableWidths $plain $maxWidth]
    set result [list [TableBorder $widths ┌ ┬ ┐]]
    set rowIndex 0
    foreach row $plain {
        set columns {}
        set height 1
        foreach cell $row width $widths {
            set wrapped [split [::textutil::adjust::adjust $cell -length $width -strictlength 1 -justify left] \n]
            lappend columns $wrapped
            set height [expr {max($height, [llength $wrapped])}]
        }
        for {set n 0} {$n < $height} {incr n} {
            set rendered │
            foreach column $columns width $widths {
                append rendered " " [format "%-*s" $width [lindex $column $n]] " │"
            }
            lappend result $rendered
        }
        if {$rowIndex == 0} {lappend result [TableBorder $widths ├ ┼ ┤]}
        incr rowIndex
    }
    lappend result [TableBorder $widths └ ┴ ┘]
    return $result
}

# Expand each table into Markdown for other formatters and a literal box for
# nroff. Preserve indentation, fenced examples and the enclosing Ruff guard.
# Ruff's includedformats/excludedformats directives replace each other, rather
# than nesting. Restore the previous directive after every generated pair.
# Already processed text is unchanged on a second pass.
proc ::tclinterpDoc::TablesForRuff {markdown {maxWidth 120}} {
    if {![string is integer -strict $maxWidth] || $maxWidth < 5} {
        error "table width must be an integer of at least 5"
    }
    set lines [split $markdown \n]
    set result {}
    set fence {}
    set guard [list excludedformats {}]
    for {set i 0} {$i < [llength $lines]} {incr i} {
        set line [lindex $lines $i]
        if {$fence ne {}} {
            if {[regexp {^\s*(`{3,}|~{3,})\s*$} $line -> marker] &&
                [string index $marker 0] eq [string index $fence 0] &&
                [string length $marker] >= [string length $fence]} {set fence {}}
            lappend result $line
            continue
        }
        if {[regexp {^\s*(`{3,}|~{3,})} $line -> marker]} {
            set fence $marker
            lappend result $line
            continue
        }
        if {[regexp {^\s*#ruffopt\s+(.*)$} $line -> opts]} {
            # Let Ruff diagnose unknown directives; remember supported format
            # settings without evaluating documentation as Tcl script.
            if {![string is list $opts] || [llength $opts] % 2} {
                error "invalid #ruffopt directive: $line"
            }
            foreach {key value} $opts {
                if {$key in {includedformats excludedformats}} {
                    if {![string is list $value]} {error "invalid format list: $line"}
                    set guard [list $key $value]
                }
            }
            lappend result $line
            continue
        }
        set separator [TableSeparator [lindex $lines [expr {$i + 1}]]]
        if {$separator eq {} || [string first | $line] < 0} {
            lappend result $line
            continue
        }
        lassign $guard mode formats
        if {($mode eq "excludedformats" && "nroff" in $formats) ||
            ($mode eq "includedformats" && "nroff" ni $formats)} {
            lappend result $line
            continue
        }
        regexp {^(\s*)} $line -> indent
        set rows [list [TableCells $line]]
        set columns [llength $separator]
        if {[llength [lindex $rows 0]] != $columns} {
            error "table header column count does not match separator at line [expr {$i + 1}]"
        }
        set original [list $line [lindex $lines [incr i]]]
        while {$i + 1 < [llength $lines]} {
            set next [lindex $lines [expr {$i + 1}]]
            if {[string trim $next] eq {} || [string first | $next] < 0 ||
                [regexp {^\s*(#ruffopt|`{3,}|~{3,})} $next]} {break}
            set row [TableCells $next]
            if {[llength $row] != $columns} {
                error "table row column count does not match header at line [expr {$i + 2}]"
            }
            lappend rows $row
            lappend original $next
            incr i
        }
        if {$mode eq "excludedformats"} {
            set mdGuard [list $mode [concat $formats nroff]]
        } else {
            set mdGuard [list $mode [lsearch -all -inline -not -exact $formats nroff]]
        }
        lappend result {} "${indent}#ruffopt $mdGuard"
        lappend result {*}$original
        lappend result {} "${indent}#ruffopt includedformats nroff" "${indent}```"
        foreach rendered [RenderTable $rows $maxWidth] {lappend result $indent$rendered}
        lappend result "${indent}```" "${indent}#ruffopt $guard" {}
    }
    return [join $result \n]
}

# Process only the namespaces passed to Ruff. Compute every replacement before
# changing variables, so conversion errors cannot leave a half-processed set.
# The returned dictionary is a snapshot for RestorePreambles in a finally block.
proc ::tclinterpDoc::PreparePreambles {namespaces {maxWidth 120}} {
    set saved {}
    set prepared {}
    foreach ns $namespaces {
        set name ${ns}::_ruff_preamble
        if {[info exists $name]} {
            dict set saved $name [set $name]
            dict set prepared $name [TablesForRuff [set $name] $maxWidth]
        }
    }
    dict for {name value} $prepared {set $name $value}
    return $saved
}

proc ::tclinterpDoc::RestorePreambles {saved} {
    dict for {name value} $saved {set $name $value}
}
