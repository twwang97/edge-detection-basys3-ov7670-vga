# fileset.tcl

proc ensure_fileset {name kind} {
    if {[string equal [get_filesets -quiet $name] ""]} {
        if {$kind eq ""} {
            create_fileset $name
        } else {
            create_fileset $kind $name
        }
    }
    return [get_filesets $name]
}

proc safe_set_property {prop value objects} {
    if {[llength $objects] > 0} {
        set_property -name $prop -value $value -objects $objects
    } else {
        puts "Warning: no objects found for property $prop"
    }
}

proc import_files_into_fileset {fileset filelist} {
    set imported {}
    foreach f $filelist {
        if {[file exists $f]} {
            lappend imported [import_files -fileset $fileset $f]
        } else {
            puts "Warning: file not found $f"
        }
    }
    return $imported
}

proc set_rtl_files_filetype {fileset relpath filetype} {
    # relpath example "imports/addr_gen.vhd" or "official_bram/official_bram.xci"
    set pattern "*$relpath"
    set file_objs [get_files -of_objects $fileset [list $pattern]]
    safe_set_property "file_type" $filetype $file_objs
}

proc set_sim_files_filetype {fileset relpath filetype} {
    set pattern "*$relpath"
    set file_objs [get_files -of_objects $fileset [list $pattern]]
    safe_set_property "file_type" $filetype $file_objs
    safe_set_property "used_in" "simulation" $file_objs
    safe_set_property "used_in_synthesis" "0" $file_objs
}

proc ensure_and_import_fileset_core {name type rel_files {per_file_callback ""}} {
    # name like sources_1, type -srcset/-constrset/-simset

    set fs [ensure_fileset $name $type]

    # Normalize paths
    set normalized {}
    foreach f $rel_files {
        lappend normalized [file normalize $f]
    }

    # Import all files at once
    set imported [import_files_into_fileset $fs $normalized]

    # Optional per-file callback: called with (fileset relpath)
    if {$per_file_callback ne ""} {
        foreach rel $rel_files {
            uplevel 1 [list $per_file_callback $fs $rel]
        }
    }

    return $fs
}

proc ensure_and_import_fileset {name type rel_files} {
    return [ensure_and_import_fileset_core $name $type $rel_files]
}

# set VHDL-2008 filetype after import
proc ensure_and_import_vhdl2008_fileset {name type rel_files} {
    # name like sources_1, type -srcset/-constrset/-simset
    if {$type == "-simset"} {
        # callback to set filetype
        set cb {set_sim_files_filetype}
        # proc _set_sim_vhdl2008 {fs rel} {
        #     set_sim_files_filetype $fs $rel "VHDL 2008"
        # }
        return [ensure_and_import_fileset_core $name $type $rel_files]
	# _set_sim_vhdl2008]
    } else {
        # callback to set filetype
        set cb {set_rtl_files_filetype}
        # wrap callback so it receives (fileset relpath) and the fixed type
        proc _set_vhdl2008 {fs rel} {
            set_rtl_files_filetype $fs $rel "VHDL 2008"
        }
        return [ensure_and_import_fileset_core $name $type $rel_files]
       # 	_set_vhdl2008]
    }
}

proc import_ip_into_sources {fs ip_relpath} {
    set ip_file [file normalize $ip_relpath]
    set imported [import_files_into_fileset $fs [list $ip_file]]
    set ip_obj [get_files -of_objects $fs [list "*[file rootname $ip_relpath]/[file tail $ip_relpath]"]]
    safe_set_property "generate_files_for_reference" "0" $ip_obj
    safe_set_property "registered_with_manager" "1" $ip_obj
    safe_set_property "synth_checkpoint_mode" "Singular" $ip_obj
    return $ip_obj
}