# project_props.tcl - set_project_properties proc

proc set_project_properties {proj_dir proj_name fpga_part_name default_lib} {
    set obj [current_project]
    set_property -name "default_lib" -value $default_lib -objects $obj
    set_property -name "enable_resource_estimation" -value "0" -objects $obj
    set_property -name "target_language" -value "Verilog" -objects $obj
    # set_property -name "enable_vhdl_2008" -value "1" -objects $obj
    set_property -name "ip_cache_permissions" -value "read write" -objects $obj
    set_property -name "ip_output_repo" -value "$proj_dir/${proj_name}.cache/ip" -objects $obj
    set_property -name "part" -value $fpga_part_name -objects $obj
    set_property -name "revised_directory_structure" -value "1" -objects $obj
    set_property -name "mem.enable_memory_map_generation" -value "1" -objects $obj
    set_property -name "xpm_libraries" -value "XPM_CDC XPM_MEMORY" -objects $obj

    set_property -name "simulator_language" -value "Verilog" -objects $obj
    set_property -name "sim.central_dir" -value "$proj_dir/${proj_name}.ip_user_files" -objects $obj
    set_property -name "sim.ip.auto_export_scripts" -value "1" -objects $obj
    set_property -name "sim_compile_state" -value "1" -objects $obj
}