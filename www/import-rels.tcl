# /packages/intranet-csv-import/www/import-rels.tcl
#

ad_page_contract {
    Starts the analysis process for the file imported
    @author frank.bergmann@project-open.com

    @param mapping_name: Should we store the current mapping in the DB for future use?
    @param column: Name of the CSV column
    @param map: Name of the ]po[ object attribute
    @param parser: Converter for CSV data type -> ]po[ data type
} {
    { return_url "" }
    { upload_file "" }
    { import_filename "" }
    { mapping_name "" }
    { ns_write_p 1 }
    column:array
    map:array
    parser:array
    parser_args:array
}

# ---------------------------------------------------------------------
# Default & Security
# ---------------------------------------------------------------------

set current_user_id [auth::require_login]
set page_title [lang::message::lookup "" intranet-cvs-import.Upload_Objects "Upload Objects"]
set context_bar [im_context_bar "" $page_title]
set admin_p [im_is_user_site_wide_or_intranet_admin $current_user_id]
if {!$admin_p} {
    ad_return_complaint 1 "Only administrators have the right to import objects"
    ad_script_abort
}

# ---------------------------------------------------------------------
# Check and open the file
# ---------------------------------------------------------------------

if {![file readable $import_filename]} {
    ad_return_complaint 1 "Unable to read the file '$import_filename'. <br>
    Please check the file permissions or contact your system administrator.\n"
    ad_script_abort
}

set encoding "utf-8"
if {[catch {
    set fl [open $import_filename]
    fconfigure $fl -encoding $encoding
    set lines_content [read $fl]
    close $fl
} err]} {
    ad_return_complaint 1 "Unable to open file $import_filename:<br><pre>\n$err</pre>"
    ad_script_abort
}


# Extract the header line from the file
set lines [split $lines_content "\n"]
set separator [im_csv_guess_separator $lines]
set lines_len [llength $lines]
set header [lindex $lines 0]
set header_fields [im_csv_split $header $separator]
set header_len [llength $header_fields]
set values_list_of_lists [im_csv_get_values $lines_content $separator]

# ------------------------------------------------------------
# Get DynFields

# Determine the list of actually available fields.
set mapped_vars [list "''"]
foreach k [array names map] {
    lappend mapped_vars "'$map($k)'"
}

# ------------------------------------------------------------
# Render Result Header

if {$ns_write_p} {
    ad_return_top_of_page "
	[im_header]
	[im_navbar]
    "
    ns_write "<h1>Importing Relationships</h1>"
}

# ------------------------------------------------------------

set cnt 1
foreach csv_line_fields $values_list_of_lists {
    incr cnt

    if {$ns_write_p} { ns_write "</ul><hr><ul>\n" }
    if {$ns_write_p} { ns_write "<li>Starting to parse line $cnt\n" }

    # Preset values, defined by CSV sheet:
    set object_name_one		""
    set object_name_two		""
    set object_id_one		""
    set object_id_two		""    
    set rel_id			""
    set percentage		""

    # -------------------------------------------------------
    # Extract variables from the CSV file
    #
    set var_name_list [list]
    for {set j 0} {$j < $header_len} {incr j} {

	set var_name [string trim [lindex $header_fields $j]]
	if {"" == $var_name} {
	    # No variable name - probably an empty column
	    continue
	}
	set var_name [string tolower $var_name]
	set var_name [string map -nocase {" " "_" "\"" "" "'" "" "/" "_" "-" "_" "\[" "(" "\{" "(" "\}" ")" "\]" ")"} $var_name]
	lappend var_name_list $var_name
	ns_log notice "import-rels: varname([lindex $header_fields $j]) = $var_name"

	set var_value [string trim [lindex $csv_line_fields $j]]
	set var_value [string map -nocase {"\"" "'" "\[" "(" "\{" "(" "\}" ")" "\]" ")" "\$" "" "\\" ""} $var_value]
	if {"NULL" eq $var_value} { set var_value ""}

	# replace unicode characters by non-accented characters
	# Watch out! Does not work with Latin-1 characters
	set var_name [im_mangle_unicode_accents $var_name]

	set cmd "set $var_name \"$var_value\""
	ns_log Notice "import-rels: cmd=$cmd"
	set result [eval $cmd]
    }

    # -------------------------------------------------------
    # Transform the variables
    set i 0

    foreach varname $var_name_list {
	set p $parser($i)
	set p_args $parser_args($i)
	set target_varname $map($i)
	ns_log Notice "import-rels: Parser: $varname -> $target_varname"
	ns_log Notice "import-rels: Parser: p_args: $p_args"
	ns_log Notice "import-rels: Parser: target_varname: $target_varname"

	switch $p {
	    no_change { 
		set $target_varname [set $varname]
		ns_log Notice "import-rels: Parser: no change: varname: $varname, val: [set $varname]"
	    }
	    default {
		set proc_name "im_csv_import_parser_$p"
		if {[catch {
		    set val [set $varname]
		    ns_log Notice "import-rels: Parser: val: $val"
		    if {"" != $val} {
			    set result [$proc_name -parser_args $p_args $val]
			    set res [lindex $result 0]
			    set err [lindex $result 1]
			    ns_log Notice "import-rels: Parser: '$p -args $p_args $val' -> $target_varname=$res, err=$err"
			    if {"" != $err} {
				if {$ns_write_p} { 
				    ns_write "<li><font color=brown>Warning: Error parsing field='$target_varname' using parser '$p':<pre>$err</pre></font>\n" 
				}
			    }
			    set $target_varname $res
		    }
		} err_msg]} {
		    if {$ns_write_p} { 
			ns_write "<li><font color=brown>Warning: Error parsing field='$target_varname' using parser '$p':<pre>$err_msg</pre></font>" 
		    }
		}
	    }
	}

	incr i
	ns_log Notice "import-rels: -------------------------------------------"
    }
    
    # -------------------------------------------------------
    # Specific field transformations

    if { "person" == $object_type_one && "im_project" == $object_type_two} {

	if { "" eq $object_id_one || "" eq $object_id_two } {
	    if {$ns_write_p} {
		ns_write "<li><font color='red'>Error: Record not imported - person or project/task not found</font>\n"
		continue
	    }
	}
	if {[catch {
	    set rel_id [db_string create_im_biz_object_member "
		select im_biz_object_member__new (
                        null,
                        'im_biz_object_member',
                        :object_id_two,
                        :object_id_one,
                        :role_id,
                        :percentage::numeric,
                        null,
                        '0.0.0.0'
			);
    	    " ]
	    ns_write "<li><font color=green>Created relationship (id:$rel_id) btw. '$object_id_one' and '$object_id_two'</font>\n"
	} err_msg]} {
	    global errorInfo
	    if {$ns_write_p} {
		ns_write "<li><font color=red>Error: Error creating relationship:<pre>$errorInfo</pre></font>\n"
	    }
	    continue
	}
    } 

}

if {$ns_write_p} {
    ns_write "</ul>\n"
    ns_write "<p>\n"
    ns_write "<A HREF=$return_url>Return to Project Page</A>\n"
}

# ------------------------------------------------------------
# Render Report Footer

if {$ns_write_p} {
    ns_write [im_footer]
}



