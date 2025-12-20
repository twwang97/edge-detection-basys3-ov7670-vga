# help.tcl - print_help proc and help text
proc print_help {} {
    puts "\nDescription:"
    puts "Recreate a Vivado project from this script..."
    puts "Syntax:"
    puts "$<your_file_name.tcl> -tclargs [--origin_dir <path>] [--project_name <name>] [--help]\n"
    exit 0
}