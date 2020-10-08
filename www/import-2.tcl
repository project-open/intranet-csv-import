# /packages/intranet-csv-import/www/import-2.tcl
#
ad_page_contract {
    Starts the analysis process for the file imported
    @author frank.bergmann@project-open.com
} {
    { return_url "/intranet/" }
    { main_navbar_label "" }
    object_type
    upload_file
    object_type
}

# ---------------------------------------------------------------------
# Default & Security
# ---------------------------------------------------------------------

set page_title [lang::message::lookup "" intranet-cvs-import.Upload_Objects "Upload Objects"]
set context_bar [im_context_bar "" $page_title]
set current_user_id [auth::require_login]
# fraber 130225: Permissions are now handled by the import-* files

# Get the file from the user. number_of_bytes is the upper-limit
set max_n_bytes [parameter::get -package_id [apm_package_id_from_key im_package_filestorage_id] -parameter "MaxNumberOfBytes" -default 0]
set tmp_filename [ns_queryget upload_file.tmpfile]
im_security_alert_check_tmpnam -location "import-2.tcl" -value $tmp_filename

if {$max_n_bytes && ([file size $tmp_filename] > $max_n_bytes)} {
    ad_return_complaint 1 "Your file is larger than the maximum permissible upload size:  
    [util_commify_number $max_n_bytes] bytes"
    ad_script_abort
}

# strip off the C:\directories... crud and just get the file name
if {![regexp {([^//\\]+)$} $upload_file match filename]} {
    # couldn't find a match
    set filename $upload_file
}

if {[regexp {\.\.} $filename]} {
    set error "Filename contains forbidden characters"
    ad_returnredirect [export_vars -base /error.tcl {error}]
}

if {![file readable $tmp_filename]} {
    ad_return_complaint 1 "Unable to read the file '$tmp_filename'. <br>
    Please check the file permissions or contact your system administrator.\n"
    ad_script_abort
}

set import_filename "${tmp_filename}_copy"

catch {
    file copy -force -- $tmp_filename $import_filename
}

# ---------------------------------------------------------------------
# Open and parse the file
# ---------------------------------------------------------------------

set encoding "utf-8"
if {[catch {
    set fl [open $tmp_filename]
    fconfigure $fl -encoding $encoding
    set lines_content [read $fl]
    close $fl
} err]} {
    ad_return_complaint 1 "Unable to open file $tmp_filename:<br><pre>\n$err</pre>"
    ad_script_abort
}


# Extract the header line from the file
set lines [split $lines_content "\n"]
if {"" == $lines} { ad_return_complaint 1 "<b>You didn't select a file in the screen before.</b>" }
set separator [im_csv_guess_separator $lines]
# ad_return_complaint 1 $separator
set lines_len [llength $lines]
set header [lindex $lines 0]
set headers [im_csv_split $header $separator]
set header_len [llength $headers]
set values_lol [im_csv_get_values $lines_content $separator]




# ---------------------------------------------------------------------
# Code set check - detects wrong unicode chars or the beginning of an Excel file...
# ---------------------------------------------------------------------

set max_char 0
set hex_chars {}
foreach char [split $header ""] {
    set c [scan $char %c]
    if {$c > $max_char} { set max_char $c }
    lappend hex_chars [format "%X" $c]
}
# ad_return_complaint 1 "sep='$separator',<br>header=$header,<br>headers=$headers,<br>max_char=$max_char,<br>hex=$hex_chars "
if {"FEFF" eq [lindex $hex_chars 0]} {
    ad_return_complaint 1 "<b>Something is wrong with your CSV file.<br>We found 'FEFF' as the first (invisible) character in your file</b>:<br>
    &nbsp;<br>
    Some text editors add a FEFF 'byte order mark' (BOM) in front of the text.<br>
    This format is not supported by \]po\[.<br>
    Please use a correctly formatted CSV in UTF-8 format without BOM.
    "
    ad_script_abort
}



# ---------------------------------------------------------------------
# Continue parsing the header
# ---------------------------------------------------------------------



# Check if there are lines with less then 4 elements
# fraber 160315: Exporting from Excel, the last columns may be shorter
# set error [im_csv_import_check_list_of_lists $values_lol]
# if {"" != $error} { ad_return_complaint 1 $error }

# Take a sample of max_row rows from the file and show
set max_row 10
for {set i 1} {$i <= $max_row} {incr i} {
   set row_$i [im_csv_split [lindex $lines $i] $separator]
}

# Get the list of all available fields for the object_type
set object_fields [im_csv_import_object_fields -object_type $object_type]

# Determine the list of parsers for the object_type
set parser_pairs [im_csv_import_parsers -object_type $object_type]

# ---------------------------------------------------------------------
# Create and fill the multirow
# ---------------------------------------------------------------------

# Setup the multirow with some sample rows
multirow create mapping field_name column map parser parser_args
for {set i 1} {$i < $max_row} {incr i} {
    multirow extend mapping "row_$i"
}

set object_type_pairs [list "" ""]
foreach field $object_fields { lappend object_type_pairs [string tolower $field] [string tolower $field] }
lappend object_type_pairs "hard_coded" "Hard Coded Functionality"

# --------------------------------------------------
# Main Loop
# Try to guess the mapping and the parser for each field
# --------------------------------------------------

set cnt 0
foreach header_name $headers {
    ns_log Notice "import-2: header_name=$header_name: --------------------------------"

    # Column - Name of the CSV colum
    set column "<input type=hidden name=column.$cnt value=\"$header_name\">"

    # Parser - convert the value from CSV values to ]po[ values
    set parser_sample_values [list]
    for {set i 1} {$i <= $max_row} {incr i} {
	set row_name "row_$i"
	set val [lindex [set $row_name] $cnt]
	if {"" != $val} { lappend parser_sample_values $val }
    }

    # Guess the object's field to which to map.
    set object_field_best_guess [im_csv_import_guess_map -object_type $object_type -field_name $header_name -sample_values $parser_sample_values ]
    ns_log Notice "import-2: im_csv_import_guess_map -object_type $object_type -field_name $header_name -sample_values {$parser_sample_values}"
    ns_log Notice "import-2: header_name=$header_name: guess_map => $object_field_best_guess"
    set guess_parser_field_name $header_name
    if {"" != $object_field_best_guess} { 
	set guess_parser_field_name $object_field_best_guess 
    } 

    # Guess the parser how to convert the field values
    set defs [im_csv_import_guess_parser -object_type $object_type -field_name $guess_parser_field_name -sample_values $parser_sample_values]
    ns_log Notice "import-2: im_csv_import_guess_parser -object_type $object_type -field_name $guess_parser_field_name -sample_values {$parser_sample_values}"
    ns_log Notice "import-2: header_name=$header_name: guess_parser => $defs"
    set default_parser [lindex $defs 0]
    set default_parser_args [lindex $defs 1]
    set override_map [lindex $defs 2]

    set parser [im_select parser.$cnt $parser_pairs $default_parser]
    set args "<input type=text name=parser_args.$cnt value=\"$default_parser_args\" size=\"40\">\n"

    # Mapping - Map to which object field?
    set default_map $object_field_best_guess
    if {"" != $override_map} { set default_map $override_map }
    set map [im_select map.$cnt $object_type_pairs $default_map]


    ns_log Notice "import-2: header_name=$header_name, default_map=$default_map, override_map=$override_map, map=$map"

    if {"hard_coded" == $default_parser} { set map [im_select map.$cnt $object_type_pairs "hard_coded"] }

#    ad_return_complaint 1 "'$column'"
    multirow append mapping $header_name $column $map $parser $args \
	[lindex $row_1 $cnt] [lindex $row_2 $cnt] [lindex $row_3 $cnt] [lindex $row_4 $cnt] [lindex $row_5 $cnt]

    incr cnt
}


# Redirect to a specific page for the import
switch $object_type {
    im_timesheet_task {
	set redirect_object_type "im_project" 
    }
    default {
	set redirect_object_type $object_type
    }
}

