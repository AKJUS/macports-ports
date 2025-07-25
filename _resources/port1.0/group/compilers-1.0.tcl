# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4
#
# This PortGroup sets up default variants for projects that want multiple
# compilers for providing options for, example, different optimizations. More
# importantly, this port group provides the ability to interact with packages
# that need MPI since MPI is just a wrapper around a compiler.
#
# Usage:
#
#   PortGroup               compilers 1.0
#
# Available procedures:
# compilers.choose {args}
#   Possible arguments: cc cxx cpp objc fc f77 f90
#   A list of which of these compilers you want to be set by the variants (e.g. ${configure.cc}).
#   The default is all of them. Must come before compilers.setup in the Portfile to have an effect.
# compilers.set_variants_conflict {args}
#   Add specified variants to the conflicts list of all variants created by this PortGroup.
#   Useful if another compiler variant is created explicitly in the Portfile. Must come before compilers.setup.
# compilers.setup {args}
#   Possible arguments: any compiler variant name with a minus removes it from the list of variants, e.g. -clang.
#   -gcc, -clang remove all compilers of that category. -fortran removes gfortran and g95.
#   Blacklisted compilers are automatically removed, as are ones that do not support the compilers in compilers.choose:
#   e.g. if choose is just f90, clang variants will not be added.
#   List "default_fortran" to make a Fortran variant be selected by default.
#   This procedure must be in the Portfile to create all the compiler variants and set the default.
#   Appropriate conflicts, dependencies, etc. are created too.
#   If a variant is declared already in the Portfile before this line, it will not be redefined.
# c_active_variant_name {depspec}: which C variant a dependency has set
# c_variant_name {}: which C variant is set
# c_variant_isset {}: is a C variant set
# fortran_active_variant_name {depspec}: which Fortran variant a dependency has set
# fortran_variant_name {}: which Fortran variant is set
# fortran_depends_port_name {arg}: gets the compiler port name for the given fortran variant
# fortran_variant_depends {}: gets the depspec to use to depend on the compiler for the active fortran variant
# fortran_compiler_name {arg}:  converts gfortran into the actual Fortran compiler name; otherwise returns arg
# clang_variant_isset {}: is a clang variant set
# clang_variant_name {}: which clang variant is set
# gcc_variant_isset {}: is a GCC variant set
# gcc_variant_name {}: which GCC variant is set
# avx_compiler_isset {}: is a C compiler supporting AVX set
# fortran_variant_isset {}: is a Fortran variant set
# compilers.enforce_c {args}: enforce that a dependency has the same C variant as is set here
# compilers.enforce_fortran {args}: enforce that a dependency has the same Fortran variant as is set here
# compilers.enforce_some_fortran {args}: enforce that a dependency has some Fortran variant set
#
# Options:
# compilers.clear_archflags: disable archflags ("-arch x86_64", -m64, etc.)
# compilers.allow_arguments_mismatch:
#   ensure Fortran code accepts "calls to external procedures with mismatches between the calls and the procedure definition"
#   the use of this option is "strongly discouraged" as the code should be made to be "standard-conforming"
#   see https://gcc.gnu.org/onlinedocs/gfortran/Fortran-Dialect-Options.html
# compilers.add_gcc_rpath_support: enforce adding -rpath,${prefix}/lib/libgcc
#
# The compilers.gcc_default variable may be useful for setting a default compiler variant
# even in ports that do not use this PortGroup's automatic creation of variants.
# compilers.libfortran is for use in linking Fortran code with the C or C++ compiler.

PortGroup active_variants 1.1

options compilers.variants compilers.gcc_variants compilers.clear_archflags
default compilers.variants {}
default compilers.my_fortran_variants {}
default compilers.all_fortran_variants {}
default compilers.gcc_variants {}
default compilers.clang_variants {}
default compilers.require_fortran 0
default compilers.default_fortran 0
default compilers.setup_done 0
default compilers.required_c {}
default compilers.required_f {}
default compilers.required_some_f {}
default compilers.variants_conflict {}
default compilers.libfortran {}
default compilers.clear_archflags no

options compilers.allow_arguments_mismatch
default compilers.allow_arguments_mismatch no

options compilers.add_gcc_rpath_support
default compilers.add_gcc_rpath_support yes

# Set a default gcc version
set compilers.gcc_default gcc14

set compilers.list {cc cxx cpp objc fc f77 f90}

# build database of gcc compiler attributes
# Should match those in compilers/gcc_compilers.tcl
if { ${os.arch} eq "arm" || ${os.platform} ne "darwin" } {
    set gcc_versions [list]
    if { [vercmp ${xcodeversion} < 16.0] && [vercmp ${xcodecltversion} < 16.0] } {
        lappend gcc_versions 10 11 12 13
    }
    lappend gcc_versions 14 devel
} else {
    set gcc_versions [list]
    if { ${os.major} < 15 } {
        lappend gcc_versions 5 6 7 8 9
    }
    if { ${os.major} >= 10 } {
        if { [vercmp ${xcodeversion} < 16.0] && [vercmp ${xcodecltversion} < 16.0] } {
            lappend gcc_versions 10 11 12 13
        }
    }
    lappend gcc_versions 14 devel
}

# GCC version providing the primary runtime
# Note settings here *must* match those in the lang/libgcc port.
set gcc_main_version 14

ui_debug "GCC versions for Darwin ${os.major} ${os.arch} - ${gcc_versions}"
foreach ver ${gcc_versions} {
    # Remove dot from version if present
    set ver_nodot [string map {. {}} ${ver}]
    lappend compilers.gcc_variants gcc$ver_nodot
    set cdb(gcc$ver_nodot,variant)  gcc$ver_nodot
    set cdb(gcc$ver_nodot,compiler) macports-gcc-$ver
    set cdb(gcc$ver_nodot,descrip)  "MacPorts gcc $ver"
    if { $ver eq "devel" } {
        set cdb(gcc$ver_nodot,depends)  port:gcc-devel
        set cdb(gcc$ver_nodot,dependsl) "port:libgcc-devel"
        set cdb(gcc$ver_nodot,dependsa) gcc-devel
    } else {
        set cdb(gcc$ver_nodot,depends)  port:gcc$ver_nodot
        if {[vercmp ${ver} < 4.6]} {
            set cdb(gcc$ver_nodot,dependsl) "path:share/doc/libgcc/README:libgcc port:libgcc45"
        } elseif {[vercmp ${ver} < 7]} {
            set cdb(gcc$ver_nodot,dependsl) "path:share/doc/libgcc/README:libgcc port:libgcc6"
        } elseif {[vercmp ${ver} < ${gcc_main_version}]}  {
            set cdb(gcc$ver_nodot,dependsl) "path:share/doc/libgcc/README:libgcc port:libgcc${ver_nodot}"
        } else {
            # Do not depend directly on primary runtime port, as implied by libgcc
            # and doing so prevents libgcc-devel being used as an alternative.
            set cdb(gcc$ver_nodot,dependsl) "path:share/doc/libgcc/README:libgcc"
        }
        set cdb(gcc$ver_nodot,dependsa) gcc$ver_nodot
    }
    set cdb(gcc$ver_nodot,libfortran) ${prefix}/lib/gcc$ver_nodot/libgfortran.dylib
    # note: above is ultimately a symlink to ${prefix}/lib/libgcc/libgfortran.3.dylib
    set cdb(gcc$ver_nodot,dependsd) port:g95
    set cdb(gcc$ver_nodot,conflict) "gfortran g95"
    set cdb(gcc$ver_nodot,cc)       ${prefix}/bin/gcc-mp-$ver
    set cdb(gcc$ver_nodot,cxx)      ${prefix}/bin/g++-mp-$ver
    set cdb(gcc$ver_nodot,cpp)      ${prefix}/bin/cpp-mp-$ver
    set cdb(gcc$ver_nodot,objc)     ${prefix}/bin/gcc-mp-$ver
    set cdb(gcc$ver_nodot,fc)       ${prefix}/bin/gfortran-mp-$ver
    set cdb(gcc$ver_nodot,f77)      ${prefix}/bin/gfortran-mp-$ver
    set cdb(gcc$ver_nodot,f90)      ${prefix}/bin/gfortran-mp-$ver
    # The devel port, and starting with version 10, GCC will support using -stdlib=libc++,
    # so use it for improved compatibility with clang builds
    if { ${build_arch} ni [list ppc ppc64] } {
        if { $ver eq "devel" || [vercmp ${ver} >= 10]} {
            set cdb(gcc$ver_nodot,cxx_stdlib) libc++
        } else {
            set cdb(gcc$ver_nodot,cxx_stdlib) libstdc++
        }
    } else {
        set cdb(gcc$ver_nodot,cxx_stdlib) libstdc++
    }
}

# build database of clang compiler attributes
# Should match those in compilers/clang_compilers.tcl
# Also do not forget to add support of new llvm into cctools
set clang_versions [list]
if { ${os.arch} ne "arm" && ${os.platform} eq "darwin" } {
    if {${os.major} < 16} {
        lappend clang_versions 3.4 3.7
    }
    if { ${os.major} < 20 } {
        lappend clang_versions 5.0 6.0 7.0 8.0
    }
    if { ${os.major} < 23 } {
        lappend clang_versions 9.0 10
    }
}
if { ${os.major} <= 23 || ${os.platform} ne "darwin"} {
    lappend clang_versions 11
    if { ${os.major} >= 11 || ${os.platform} ne "darwin"} {
        lappend clang_versions 12
    }
}
if { ${os.major} >= 11 || ${os.platform} ne "darwin"} {
    lappend clang_versions 13 14 15 16 17 18
}
if { ${os.major} >= 15 || ${os.platform} ne "darwin"} {
    lappend clang_versions 19 20 devel
}
ui_debug "Clang versions for Darwin ${os.major} ${os.arch} - ${clang_versions}"
foreach ver ${clang_versions} {
    # Remove dot from version if present
    set ver_nodot [string map {. {}} ${ver}]
    lappend compilers.clang_variants    clang$ver_nodot
    set cdb(clang$ver_nodot,variant)    clang$ver_nodot
    set cdb(clang$ver_nodot,compiler)   macports-clang-$ver
    set cdb(clang$ver_nodot,descrip)    "MacPorts clang $ver"
    set cdb(clang$ver_nodot,depends)    port:clang-$ver
    set cdb(clang$ver_nodot,dependsl)   ""
    set cdb(clang$ver_nodot,libfortran) ""
    set cdb(clang$ver_nodot,dependsd)   ""
    set cdb(clang$ver_nodot,dependsa)   clang-$ver
    set cdb(clang$ver_nodot,conflict)   ""
    set cdb(clang$ver_nodot,cc)         ${prefix}/bin/clang-mp-$ver
    set cdb(clang$ver_nodot,cxx)        ${prefix}/bin/clang++-mp-$ver
    set cdb(clang$ver_nodot,cpp)        "${prefix}/bin/clang-mp-$ver -E"
    set cdb(clang$ver_nodot,objc)       ""
    set cdb(clang$ver_nodot,fc)         ""
    set cdb(clang$ver_nodot,f77)        ""
    set cdb(clang$ver_nodot,f90)        ""
    set cdb(clang$ver_nodot,cxx_stdlib) ""
}

# and lastly we add a gfortran and g95 variant for use with clang*; note that
# we don't need gfortran when we are in an "only-fortran" mode
set cdb(gfortran,variant)  gfortran
set cdb(gfortran,compiler) gfortran
set cdb(gfortran,descrip)  "$cdb(${compilers.gcc_default},descrip) Fortran"
set cdb(gfortran,depends)  $cdb(${compilers.gcc_default},depends)
set cdb(gfortran,dependsl) $cdb(${compilers.gcc_default},dependsl)
set cdb(gfortran,libfortran) $cdb(${compilers.gcc_default},libfortran)
set cdb(gfortran,dependsd) $cdb(${compilers.gcc_default},dependsd)
set cdb(gfortran,dependsa) $cdb(${compilers.gcc_default},dependsa)
set cdb(gfortran,conflict) g95
set cdb(gfortran,cc)       ""
set cdb(gfortran,cxx)      ""
set cdb(gfortran,cpp)      ""
set cdb(gfortran,objc)     ""
set cdb(gfortran,fc)       $cdb(${compilers.gcc_default},fc)
set cdb(gfortran,f77)      $cdb(${compilers.gcc_default},f77)
set cdb(gfortran,f90)      $cdb(${compilers.gcc_default},f90)
set cdb(gfortran,cxx_stdlib) ""

set cdb(g95,variant)  g95
set cdb(g95,compiler) g95
set cdb(g95,descrip)  "g95 Fortran"
set cdb(g95,depends)  port:g95
set cdb(g95,dependsl) ""
set cdb(g95,libfortran) ${prefix}/lib/g95/x86_64-apple-darwin14/4.2.4/libf95.a
set cdb(g95,dependsd) ""
set cdb(g95,dependsa) g95
set cdb(g95,conflict) ""
set cdb(g95,cc)       ""
set cdb(g95,cxx)      ""
set cdb(g95,cpp)      ""
set cdb(g95,objc)     ""
set cdb(g95,fc)       ${prefix}/bin/g95
set cdb(g95,f77)      ${prefix}/bin/g95
set cdb(g95,f90)      ${prefix}/bin/g95
set cdb(g95,cxx_stdlib) ""

foreach cname [array names cdb *,variant] {
    lappend compilers.variants $cdb($cname)
}

foreach variant ${compilers.variants} {
    if {$cdb($variant,f77) ne ""} {
        lappend compilers.all_fortran_variants $variant
        lappend compilers.my_fortran_variants $variant
    }
}

proc compilers.set_variants_conflict {args} {
    global compilers.variants_conflict

    lappend compilers.variants_conflict {*}$args
}

proc compilers.setup_variants {variants} {
    global cdb compilers.variants compilers.clang_variants compilers.gcc_variants
    global compilers.my_fortran_variants compilers.list
    global compilers.variants_conflict
    global compilers.clear_archflags
    global build_arch

    set compilers.my_fortran_variants [list]
    foreach variant $variants {
        if {$cdb($variant,f77) ne ""} {
            lappend compilers.my_fortran_variants $variant
        }

        if {[variant_exists $variant]} {
            ui_debug "$variant variant already exists, so not adding the default one"
        } else {
            set i [lsearch -exact ${compilers.variants} $variant]
            set c [lreplace ${compilers.variants} $i $i]

            # Fortran compilers do not conflict with C compilers.
            # thus clang does not conflict with g95 and gfortran
            if {$variant eq "gfortran" || $variant eq "g95"} {
                foreach clangcomp ${compilers.clang_variants} {
                    set i [lsearch -exact $c $clangcomp]
                    set c [lreplace $c $i $i]
                }
            } elseif {[string match clang* $variant]} {
                set i [lsearch -exact $c gfortran]
                set c [lreplace $c $i $i]
                set i [lsearch -exact $c g95]
                set c [lreplace $c $i $i]
            }

            # only add conflicts from the compiler database (set above) if we
            # actually have the compiler in the list of allowed variants
            foreach j $cdb($variant,conflict) {
                if {$j in ${compilers.variants}} {
                    lappend c $j
                }
            }

            set body "
                depends_build-append   $cdb($variant,depends)
                depends_lib-append     $cdb($variant,dependsl)
                depends_lib-delete     $cdb($variant,dependsd)
                depends_skip_archcheck $cdb($variant,dependsa)

                set compilers.libfortran $cdb($variant,libfortran)
            "
            # TODO: all the compilers are in portconfigure now, so see if below
            # is even needed now;
            # for each compiler, set the value if not empty; we can't use
            # configure.compiler because of dragonegg and possibly other new
            # compilers that aren't in macports portconfigure.tcl
            foreach compiler ${compilers.list} {
                if {$cdb($variant,$compiler) ne ""} {
                    append body "
                        configure.$compiler $cdb($variant,$compiler)

                        # disable archflags
                        if {\${compilers.clear_archflags} && \[info commands configure.${compiler}_archflags\] ne {}} {
                            configure.${compiler}_archflags
                            configure.ld_archflags
                        }
                    "
                }
            }

            # see https://trac.macports.org/ticket/59199 for setting configure.cxx_stdlib
            # see https://trac.macports.org/ticket/59329 for compilers.is_fortran_only
            if {![compilers.is_fortran_only] && $cdb($variant,cxx_stdlib) ne ""} {
                set mystdlib $cdb($variant,cxx_stdlib)
                append body "
                    configure.cxx_stdlib ${mystdlib}
                "
                set set_stdlib no
                if { ${build_arch} ni [list ppc ppc64] } {
                    # If variant is gcc10+ pass -stdlib option to correctly handle libc++ versus libstdc++
                    if {[string match gcc* $variant]} {
                        if { [regexp {gcc(.*)} ${variant} -> gcc_v] } {
                            if { ${gcc_v} >= 10 || ${gcc_v} == "devel" } {
                                set set_stdlib yes
                            }
                        }
                    }
                    # Always set with clang
                    if {[string match clang* $variant]} {
                        set set_stdlib yes
                    }
                }
                if { ${set_stdlib} eq "yes" } {
                    append body "
                        configure.cxxflags-append -stdlib=${mystdlib}
                        configure.ldflags-append  -stdlib=${mystdlib}
                    "
                }
            }

            variant ${variant} description \
                "Build using the $cdb($variant,descrip) compiler" \
                conflicts {*}$c {*}${compilers.variants_conflict} \
                ${body}
        }
    }
}

foreach variant ${compilers.gcc_variants} {
    # we need to check the default_variants so we can't use variant_isset
    if {[info exists variations($variant)] && $variations($variant) eq "+"} {
        depends_lib-delete      port:g95
        break
    }
}

proc c_active_variant_name {depspec} {
    global compilers.variants
    set c_list [remove_from_list ${compilers.variants} {gfortran g95}]

    foreach c $c_list {
        if {![catch {set result [active_variants $depspec $c ""]}]} {
            if {$result} {
                return $c
            }
        } else {
            ui_warn "c_active_variant_name: \[active_variants $depspec $fc \"\"\] fails."
        }
    }

    return ""
}

proc c_variant_name {} {
    global compilers.variants
    set c_list [remove_from_list ${compilers.variants} {gfortran g95}]

    foreach cc $c_list {
        if {[variant_isset $cc]} {
            return $cc
        }
    }

    return ""
}

proc c_variant_isset {} {
    return [expr {[c_variant_name] ne ""}]
}

proc fortran_active_variant_name {depspec} {
#note: this list of variants is NOT reduced by an characteristics of the current port
#(unlike compilers.my_fortran_variants), since it needs to apply to another port.
    global compilers.all_fortran_variants

    foreach fc ${compilers.all_fortran_variants} {
        if {![catch {set result [active_variants $depspec $fc ""]}]} {
            if {$result} {
                return $fc
            }
        } else {
            ui_warn "fortran_active_variant_name: \[active_variants $depspec $fc \"\"\] fails."
        }
    }

    return ""
}

proc fortran_compiler_name {variant} {
    global compilers.gcc_default

    if {$variant eq "gfortran"} {
        return ${compilers.gcc_default}
    } else {
        return $variant
    }
}

proc fortran_variant_name {} {
    global compilers.my_fortran_variants variations

    foreach fc ${compilers.my_fortran_variants} {
        # we need to check the default_variants so we can't use variant_isset
        if {[info exists variations($fc)] && $variations($fc) eq "+"} {
            return $fc
        }
    }

    return ""
}

proc fortran_depends_port_name {var} {
    global cdb
    if { ${var} ne "" } {
        return $cdb(${var},dependsa)
    } else {
        return ""
    }
}

proc fortran_variant_depends {} {
    global cdb
    set var_name [fortran_variant_name]
    if { ${var_name} ne "" } {
        return $cdb(${var_name},depends)
    } else {
        return ""
    }
}

proc clang_variant_name {} {
    global compilers.clang_variants variations

    foreach c ${compilers.clang_variants} {
        # we need to check the default_variants so we can't use variant_isset
        if {[info exists variations($c)] && $variations($c) eq "+"} {
            return $c
        }
    }

    return ""
}

proc clang_variant_isset {} {
    return [expr {[clang_variant_name] ne ""}]
}

proc gcc_variant_name {} {
    global compilers.gcc_variants variations

    foreach c ${compilers.gcc_variants} {
        # we need to check the default_variants so we can't use variant_isset
        if {[info exists variations($c)] && $variations($c) eq "+"} {
            return $c
        }
    }

    return ""
}

proc gcc_variant_isset {} {
    return [expr {[gcc_variant_name] ne ""}]
}

proc avx_compiler_isset {} {
    global configure.cc

    set cc ${configure.cc}

    # check for mpi
    if {[string match *mpi* $cc]} {
        set cc [exec ${configure.cc} -show]
    }

    if {[string match *clang* $cc]} {
        return 1
    }

    return 0
}

proc fortran_variant_isset {} {
    return [expr {[fortran_variant_name] ne ""}]
}

# remove all elements in R from L
proc remove_from_list {L R} {
    foreach e $R {
        set idx [lsearch -exact $L $e]
        set L [lreplace $L $idx $idx]
    }
    return $L
}

# add all elements in R from L
proc add_from_list {L A} {
    return [concat $L $A]
}

proc compilers.choose {args} {
    global compilers.list compilers.setup_done

    if {${compilers.setup_done}} {
        ui_warn "compilers.choose has an effect only before compilers.setup."
    }

    # zero out the variable before and append args
    set compilers.list [list]
    foreach v $args {
        lappend compilers.list $v
    }
}

proc compilers.is_fortran_only {} {
    global compilers.list

    foreach c {cc cxx cpp objc} {
        if {$c in ${compilers.list}} {
            return 0
        }
    }

    return 1
}

proc compilers.is_c_only {} {
    global compilers.list

    foreach c {f77 f90 fc} {
        if {$c in ${compilers.list}} {
            return 0
        }
    }

    return 1
}

proc compilers.enforce_c {args} {
    global compilers.required_c
    lappend compilers.required_c {*}$args
}

proc compilers.action_enforce_c {ports} {
    ui_debug "compilers.enforce_c list: ${ports}"
    foreach portname $ports {
        if {![catch {set result [active_variants $portname "" ""]}]} {
            set otcomp  [c_active_variant_name $portname]
            set mycomp  [c_variant_name]

            if {$otcomp ne "" && $mycomp eq ""} {
                default_variants +$otcomp
            } elseif {$otcomp ne $mycomp} {
                ui_error "Install $portname +$mycomp"
                return -code error "$portname +$mycomp not installed"
            }
        } else {
            ui_error "Internal error: compilers.enforce_c: '$portname' is not an installed port."
            return -code error "Internal error: compilers.enforce_c: '$portname' is not an installed port."
        }
    }
}

proc compilers.enforce_fortran {args} {
    global compilers.required_f
    lappend compilers.required_f {*}$args
}

proc compilers.enforce_some_fortran {args} {
    global compilers.required_some_f
    lappend compilers.required_some_f {*}$args
}

proc compilers.action_enforce_f {ports} {
    ui_debug "compilers.enforce_fortran list: ${ports}"
    foreach portname $ports {
        if {![catch {set result [active_variants $portname "" ""]}]} {
            set otf  [fortran_active_variant_name $portname]
            set myf  [fortran_variant_name]
            set myf_compiler [fortran_compiler_name $myf]

            if {$otf ne "" && $myf eq ""} {
                default_variants +$otf
            } elseif {[fortran_compiler_name $otf] ne $myf_compiler} {
                # what if $portname does not have that variant? e.g. maybe it has only gcc5 and we are asking for gfortran.
                ui_error "Install $portname +$myf_compiler"
                return -code error "$portname +$myf_compiler not installed"
            }
        } else {
            ui_error "Internal error: compilers.enforce_fortran: '$portname' is not an installed port."
            return -code error "Internal error: compilers.enforce_fortran: '$portname' is not an installed port."
        }
    }
}

proc compilers.action_enforce_some_f {ports} {
    ui_debug "compilers.enforce_some_fortran list: ${ports}"
    foreach portname $ports {
        if {![catch {set result [active_variants $portname "" ""]}]} {
            if {[fortran_active_variant_name $portname] eq ""} {
                ui_error "Install $portname with a Fortran variant (e.g. +gfortran, +gccX, +g95)"
                return -code error "$portname not installed with a Fortran variant"
            }
        } else {
            ui_error "Internal error: compilers.enforce_some_fortran: '$portname' is not an installed port."
            return -code error "Internal error: compilers.enforce_some_fortran: '$portname' is not an installed port."
        }
    }
}

proc compilers.setup {args} {
    global cdb compilers.variants compilers.clang_variants compilers.gcc_variants \
        compilers.my_fortran_variants compilers.require_fortran compilers.default_fortran \
        compilers.setup_done compilers.list compilers.gcc_default compiler.blacklist \
        os.major os.arch

    if {!${compilers.setup_done}} {
        set add_list [list]
        set remove_list ${compilers.variants}

        # if we are only setting fortran compilers, then we are in "only
        # fortran mode", i.e. we just need +gccXY for the fortran compilers so
        # we remove +clangXY
        if {[compilers.is_fortran_only]} {
            # remove gfortran since that only exists to "complete" clang/llvm
            set remove_list [remove_from_list ${compilers.my_fortran_variants} gfortran]
        } elseif {[compilers.is_c_only]} {
            # remove gfortran and g95 since those are purely for fortran
            set remove_list [remove_from_list ${compilers.variants} {gfortran g95}]
        }

        foreach v $args {
            # if any negated compiler (e.g. -gcc47) is specified then we are
            # removing from the default, complete list
            set mode add
            if {[string first - $v] == 0} {
                set mode remove

                #strip the beginning '-' character
                set v [string range $v 1 end]
            }

            # handle special cases, such as 'gcc' -> all gcc variants
            switch -exact $v {
                gcc {
                    set ${mode}_list [${mode}_from_list [set ${mode}_list] ${compilers.gcc_variants}]
                }
                fortran {
                    # here we just check gfortran and g95, not every fortran
                    # compatible variant since it makes more sense to specify
                    # 'fortran' to mean add just the +gfortran and +g95 variants
                    set ${mode}_list [${mode}_from_list [set ${mode}_list] {gfortran g95}]

                }
                clang {
                    set ${mode}_list [${mode}_from_list [set ${mode}_list] ${compilers.clang_variants}]
                }
                require_fortran {
                    # this signals that fortran is required and not optional
                    set compilers.require_fortran 1
                    set compilers.default_fortran 1
                }
                default_fortran {
                    set compilers.default_fortran 1
                }
                default {
                    if {[info exists cdb($v,variant)] == 0} {
                        # If removing an already not available compiler just warn, otherwise hard error
                        if { ${mode} eq "add" } {
                            return -code error "Compiler ${v} not available for Darwin${os.major} ${os.arch}"
                        } else {
                            ui_debug "Compiler ${v} not available for Darwin${os.major} ${os.arch}"
                        }
                    } else {
                        set ${mode}_list [${mode}_from_list [set ${mode}_list] $cdb($v,variant)]
                    }
                }
            }
        }

        # also remove compilers blacklisted
        foreach compiler ${compiler.blacklist} {
            set matched no
            foreach variant ${compilers.variants} {
                if {[string match $compiler $cdb($variant,compiler)]} {
                    set matched yes
                    set remove_list [remove_from_list $remove_list $cdb($variant,variant)]
                }
            }

            if {!$matched} {
                ui_debug "Unmatched blacklisted compiler: $compiler"
            }
        }

        # remove duplicates
        set duplicates [list]
        foreach foo $remove_list {
            if {$foo in $add_list} {
                lappend duplicates $foo
            }
        }

        set compilers.variants [lsort [concat [remove_from_list $remove_list $duplicates] $add_list]]
        compilers.setup_variants ${compilers.variants}

        # reverse the gcc list so that the higher numbered ones are default
        set ordered_variants {gfortran}
        set seen 0
        for {set i [llength ${compilers.gcc_variants}]} {[incr i -1] >= 0} {} {
            # only add entries after the default gcc (the ones before are
            # considered beta)
            set v [lindex ${compilers.gcc_variants} $i]
            if {${compilers.gcc_default} eq $v} {
                set seen 1
            }

            if {$seen} {
                lappend ordered_variants $v
            }
        }
        lappend ordered_variants {g95}

        if {${compilers.default_fortran} && ![fortran_variant_isset]} {
            foreach fv $ordered_variants {
                # if the variant exists, then make it default
                if {$fv in ${compilers.variants}} {
                    default_variants-append +$fv
                    break
                }
            }
        }

        set compilers.setup_done 1
    }
}

pre-fetch {
    if {${compilers.require_fortran} && [fortran_variant_name] eq ""} {
        return -code error "must set at least one Fortran variant (${compilers.my_fortran_variants})"
    }
}

pre-archivefetch {
    # this can only be flagged if the archive on the server is actually wrong
    if {${compilers.require_fortran} && [fortran_variant_name] eq ""} {
        return -code error "must set at least one Fortran variant (${compilers.my_fortran_variants})"
    }
}

# at this point, dependencies are guaranteed to be present. otherwise, an error may occur.
# enforcing these in archivefetch doesn't seem necessary, as they would matter only at compile time.
pre-configure {
    compilers.action_enforce_c ${compilers.required_c}
    compilers.action_enforce_f ${compilers.required_f}
    compilers.action_enforce_some_f ${compilers.required_some_f}
    if {${compilers.add_gcc_rpath_support}} {
        compilers::add_gcc_rpath_support
    }
}

namespace eval compilers {
}

proc compilers::get_current_gcc_version {} {
    global compilers.gcc_default
    if {[fortran_variant_name] eq "gfortran"} {
        set fortran_compiler    ${compilers.gcc_default}
    } else {
        set fortran_compiler    [fortran_variant_name]
    }
    if { [regexp {gcc(.*)} ${fortran_compiler} -> gcc_v] } {
        return ${gcc_v}
    }
    ui_debug "compilers PG: GCC version reports being UNKNOWN to MacPorts"
    return UNKNOWN
}

proc compilers::add_fortran_legacy_support {} {
    global compilers.allow_arguments_mismatch
    if {${compilers.allow_arguments_mismatch}} {
        set gcc_v [compilers::get_current_gcc_version]
        if { ${gcc_v} >= 10 || ${gcc_v} == "devel" } {
            configure.fflags-delete     -fallow-argument-mismatch
            configure.fcflags-delete    -fallow-argument-mismatch
            configure.f90flags-delete   -fallow-argument-mismatch
            configure.fflags-append     -fallow-argument-mismatch
            configure.fcflags-append    -fallow-argument-mismatch
            configure.f90flags-append   -fallow-argument-mismatch
        }
    }
}

port::register_callback compilers::add_fortran_legacy_support

proc compilers::add_gcc_rpath_support {} {
    global prefix os.platform os.major
    set gcc_v [compilers::get_current_gcc_version]
    if { ${gcc_v} >= 10 || ${gcc_v} == "devel" } {
        if {${os.platform} eq "darwin"} {
            ui_debug "compilers PG: RPATH added to ldflags as GCC version is ${gcc_v}"
            configure.ldflags-delete  -Wl,-rpath,${prefix}/lib/libgcc
            configure.ldflags-append  -Wl,-rpath,${prefix}/lib/libgcc
        }
    }
}

proc compilers::fortran_legacy_support_proc {option action args} {
    if {$action ne  "set"} return
    compilers::add_fortran_legacy_support
}

option_proc compilers.allow_arguments_mismatch compilers::fortran_legacy_support_proc
