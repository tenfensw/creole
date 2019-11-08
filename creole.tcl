package require Tcl 8.5

namespace eval rovcreole {
    proc _lfront {listing itm} {
        set result [list $itm]
        foreach itm $listing {
            lappend result $itm
        }
        return $result
    }
    
    proc _anyof {listing itm} {
        foreach item $listing {
            if {$itm == $item} {
                return 1
            }
        }
        return 0
    }
    
    proc _nlast {listing} {
        set length [expr {[llength $listing] - 1}]
        set result {}
        for {set index 0} {$index < $length} {incr index} {
            lappend result [lindex $listing $index]
        }
        return $result
    }
    
    proc _tnlast {listing} {
        return [rovcreole::_nlast [rovcreole::_nlast $listing]]
    }
    
    proc _matchingXml {tn vl} {
        set result "<$tn>"
        if {! $vl} {
            set result "</$tn>"
        }
        return $result
    }
    
    proc _llast {listing count} {
        incr count
        set necessary 0
        set result {}
        for {set index [llength $listing]} {$index >= 0} {set index [expr {$index - 1}]} {
            lappend result [lindex $listing $index]
            incr necessary
            if {$necessary >= $count} {
                return $result
            }
        }
        return $result
    }
    
    proc _invert {vl} {
        if {$vl} {
            return 0
        } else {
            return 1
        }
    }
    
    proc parse {str} {
        set result {}
        set splitStr [split [string map [list "\r\n" "\n" "\\\\" "\n"] $str] "\n"]
        set globalTag p
        foreach ln $splitStr {
            set ln [string trim $ln]
            if {[string length $ln] >= 1} {
                set splitted [split $ln { }]
                set firstOne [lindex $splitted 0]
                set splitted [lreplace $splitted 0 0]
                switch -- $firstOne {
                    {=} {
                        set globalTag h1
                    }
                    {==} {
                        set globalTag h2
                    }
                    {===} {
                        set globalTag h3
                    }
                    {====} {
                        set globalTag h4
                    }
                    default {
                        set globalTag p
                        set splitted [rovcreole::_lfront $splitted $firstOne]
                    }
                }
                set splitted [join $splitted { }]
                set cached {}
                set contentsFiltered {}
                set italic 0
                set bold 0
                set controversialTag 0
                for {set index 0} {$index < [string length $splitted]} {incr index} {
                    set character [string index $splitted $index]
                    lappend cached $character
                    set dc [join [rovcreole::_llast $cached 2] {}]
                    if {$dc == {//} || $dc == {__}} {
                        set contentsFiltered [rovcreole::_nlast $contentsFiltered]
                        set italic [rovcreole::_invert $italic]
                        lappend contentsFiltered [rovcreole::_matchingXml em $italic]
                    } elseif {$dc == {**}} {
                        set contentsFiltered [rovcreole::_nlast $contentsFiltered]
                        set bold [rovcreole::_invert $bold]
                        lappend contentsFiltered [rovcreole::_matchingXml strong $bold]
                    } elseif {[rovcreole::_anyof [list "\{\{" "\[\["] $dc] && ! $controversialTag} {
                        set contentsFiltered [rovcreole::_nlast $contentsFiltered]
                        set controversialTag 1
                        set cached {}
                    } elseif {[rovcreole::_anyof [list "\}\}" "\]\]"] $dc] && $controversialTag} {
                        set controversialTag 0
                        set splitUrl [split [join [rovcreole::_tnlast $cached] {}] {|}]
                        set cached {}
                        if {[llength $splitUrl] == 1} {
                            lappend splitUrl {Image}
                        } elseif {[llength $splitUrl] < 1} {
                            lappend splitUrl {?}
                            lappend splitUrl {Invalid image URL.}
                        }
                        if {$dc == "\}\}"} {
                            lappend contentsFiltered "<img src='[lindex $splitUrl 0]' alt='[lindex $splitUrl 1]' />"
                        } else {
                            lappend contentsFiltered "<a href='[lindex $splitUrl 0]'>[lindex $splitUrl 1]</a>"
                        }
                    } elseif {! $controversialTag} {
                        lappend contentsFiltered $character
                    }
                }
                lappend result [dict create wrappingTag $globalTag contents [join $contentsFiltered {}]]
            }
        }
        return $result
    }
    
    proc toHtml {str} {
        set orig [rovcreole::parse $str]
        set result {}
        set line 0
        foreach tgBuilt $orig {
            incr line
            lappend result "<[dict get $tgBuilt wrappingTag] id=\"line-$line\">[dict get $tgBuilt contents]</[dict get $tgBuilt wrappingTag]>"
        }
        return [join $result "\n"]
    }
}
