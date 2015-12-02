# /packages/intranet-csv-import/www/import-im_membership.tcl
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
# Render Result Header

if {$ns_write_p} {
    ad_return_top_of_page "
	[im_header]
	[im_navbar]
    "
}

# ------------------------------------------------------------

set cnt 1
foreach csv_line_fields $values_list_of_lists {
    incr cnt

    if {$ns_write_p} { ns_write "</ul><hr><ul>\n" }
    if {$ns_write_p} { ns_write "<li>Starting to parse line $cnt\n" }

    # Preset values, defined by CSV sheet:
    set project_name		""
    set project_nr		""
    set project_path		""
    set target_project_id	""
    set role_id			""

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
	ns_log notice "upload-membership: varname([lindex $header_fields $j]) = $var_name"

	set var_value [string trim [lindex $csv_line_fields $j]]
	set var_value [string map -nocase {"\"" "'" "\[" "(" "\{" "(" "\}" ")" "\]" ")"} $var_value]
	if {"NULL" eq $var_value} { set var_value ""}

	# replace unicode characters by non-accented characters
	# Watch out! Does not work with Latin-1 characters
	set var_name [im_mangle_unicode_accents $var_name]

	set cmd "set $var_name \"$var_value\""
	ns_log Notice "upload-membership-2: cmd=$cmd"
	set result [eval $cmd]
    }

    # -------------------------------------------------------
    # Transform the variables
    set i 0

    foreach varname $var_name_list {
	set p $parser($i)
	set p_args $parser_args($i)
	set target_varname $map($i)
	ns_log Notice "import-im_membership: Parser: $varname -> $target_varname"
	ns_log Notice "import-im_membership: Parser: p_args: $p_args"
	ns_log Notice "import-im_membership: Parser: target_varname: $target_varname"

	switch $p {
	    no_change { 
		set $target_varname [set $varname]
		ns_log Notice "import-im_membership: Parser: no change: varname: $varname, val: [set $varname]"
	    }
	    default {
		set proc_name "im_csv_import_parser_$p"
		if {[catch {
		    set val [set $varname]
		    ns_log Notice "import-im_membership: Parser: val: $val"
		    if {"" != $val} {
			    set result [$proc_name -parser_args $p_args $val]
			    set res [lindex $result 0]
			    set err [lindex $result 1]
			    ns_log Notice "import-im_membership: Parser: '$p -args $p_args $val' -> $target_varname=$res, err=$err"
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
	ns_log Notice "import-im_membership: -------------------------------------------"
    }
    
    # -------------------------------------------------------
    # Specific field transformations

    # either project_id, project_nr or project_path need to be provided
    if {""eq $project_id && "" eq $project_nr_path && "" eq $project_nr } {
        if {$ns_write_p} {
            ns_write "<li><font color=red>Error: $cnt.<br>
                Please correct the CSV file. Import requires at least one of the following fields: 'project_id', 'project_nr' or 'project_nr_path'. Skipping line!</font></li>"
        }
        continue
    }

    # Assignee is mandatory
    if {"" == $user_id} {
	if {$ns_write_p} { 
	    ns_write "<li><font color=red>Error: Asignee is a mandatory field</font>\n" 
	    continue
	}
    }

    # -------------------------------------------------------
    # Find project_id in target DB

    ns_write "<li>Matching projects: <ul>"

    # Find target_project_id based on project_nr_path
    ns_write "<li>Checking first for 'project_nr_path'</li>"
    if { "" ne $project_nr_path } {
        set sql "select project_id as target_project_id, project_name as target_project_name from im_projects where im_project_nr_parent_list(project_id) = '$project_nr_path'"
        db_0or1row get_target_project_id $sql
    } else {
        ns_write "<li>No project_nr_path found, now checking for 'project_nr'. We assume that hours to be imported come from the same \]po\[ instance.</li>"
    }

    # Check for project_nr
    if { "" eq $target_project_id } {
        ns_write "<li>No project found for project_nr_path: $project_nr_path, now checking for 'project_nr'."
        if { "" ne $project_nr  } {
            set sql "select project_id as target_project_id, project_name as target_project_name from im_projects where project_nr = '$project_nr'"
            db_0or1row get_target_project_id $sql
        } else {
            ns_write "<li>No project_nr found, now checking for project_id</li>"
        }

        # Check for project_id
        if { "" eq $target_project_id } {
            ns_write "<li>No project found for project_nr: $project_nr, now checking for 'project_id'."
            if { "" ne $project_id } {
                set sql "select project_id as target_project_id, project_name as target_project_name from im_projects where project_id = $project_id"
                db_0or1row get_target_project_id $sql
            } else {
                ns_write "<li>No project_id found.</li>"
            }
            if { "" eq $target_project_id } {
                ns_write "<li>No matching project found for project_id: $project_id.</li>"
            }
        } else {
            ns_write "<li><span style='color:green'>Found matching project_nr ($project_nr) for project: $project_name: $target_project_name ($target_project_id)</span></li>"
        }
    } else {
        ns_write "<li><span style='color:green'>Found matching project_nr_path ($project_nr_path) for project: $project_name: $target_project_name ($target_project_id)</span></li>"
    }

    ns_write "</li></ul>"

    if { "" eq $target_project_id } {
        ns_write "<li><font color=red>Error: No matching project found for project: $project_name. Skipping line!</font></li>"
        continue
    }

    # Setting role 
    if { "" eq $role_id } {
	ns_write "<li>No role_id found. Setting role_id: [im_biz_object_role_full_member] (Full Member)"
	set role_id [im_biz_object_role_full_member]
    }

    # ------------------------------
    # Assigning user 
    # -----------------------------

    if {$ns_write_p} { ns_write "<li>Assigning user: $user_id to project_id: $target_project_id\n" }

    # Check permission 
    set object_type [db_string acs_object_type "select object_type from acs_objects where object_id=:target_project_id"]
    set perm_cmd "${object_type}_permissions \$user_id \$target_project_id view read write admin"
    eval $perm_cmd

    if {!$write} {
	ns_write "<li><font color=red>Error: You do not have WRITE permissions on this project: $project_name. Skipping line!</font></li>"
	continue
    }

    # Callback 
    callback im_before_member_add -user_id $user_id -object_id $target_project_id

    # Assign 
    im_biz_object_add_role $user_id $target_project_id $role_id

    # Audit
    im_audit -object_id $target_project_id -action "after_update" -comment "After adding members"

    if {$ns_write_p} { ns_write "<li>Going to write audit log.\n" }
    im_audit -object_id $target_project_id

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



