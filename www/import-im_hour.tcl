# /packages/intranet-csv-import/www/import-im_hours.tcl
#

ad_page_contract {

    @author frank.bergmann@project-open.com
    @author klaus.hofeditz@project-open.com

    @param mapping_name: Should we store the current mapping in the DB for future use?
    @param column: Name of the CSV column
    @param map: Name of the ]po[ object attribute
    @param parser: Converter for CSV data type -> ]po[ data type
} {
    { return_url "" }
    { upload_file "" }
    { import_filename "" }
    { mapping_name "" }
    { ns_write_p "" }
    { write_log_p 1 } 
    { merge_p 1 }
    { test_run_p 0 }
    { output_device_log "screen"}
    column:array
    map:array
    parser:array
    parser_args:array
}


ad_proc -private im_write_log {
    output_device_log 
    write_log_p
    msg
} {
    Writes log message to either screen or textfile 
} {

    if { !$write_log_p } { return }

    set path_tmp  [parameter::get -package_id [apm_package_id_from_key intranet-filestorage] -parameter "TmpPathUnix" -default 60]
    if { "screen" == $output_device_log } {
	ns_write $msg
    } else {
	if {[catch {
	    set fp [open "$path_tmp/import-im-hour-log.txt" a+]
	    puts $fp $msg
	    close $fp
	} err_msg]} {
	    global errorInfo
	    ns_log Error "Error writing to log file: $errorInfo"
	}
    }
}


# ---------------------------------------------------------------------
# Compatibility 
# ---------------------------------------------------------------------

if { "" ne $ns_write_p } { set write_log_p $ns_write_p } 

# ad_return_complaint xx "ns_write_p: $ns_write_p, write_log_p: $write_log_p, output_device_log: $output_device_log"

# ---------------------------------------------------------------------
# Default & Security
# ---------------------------------------------------------------------
				
set current_user_id [auth::require_login]
set page_title [lang::message::lookup "" intranet-cvs-import.Upload_Objects "Upload Objects"]
set context_bar [im_context_bar "" $page_title]
set sync_cost_item_immediately_p [parameter::get_from_package_key -package_key intranet-timesheet2 -parameter "SyncHoursImmediatelyAfterEntryP" -default 1]
set path_tmp "[parameter::get -package_id [apm_package_id_from_key intranet-filestorage] -parameter "TmpPathUnix" -default 60]/import-im-hour-log.txt"

# ---------------------------------------------------------------------
# Remove old log file 
# ---------------------------------------------------------------------

if {[catch {
    file delete $path_tmp
} err_msg]} {
    global errorInfo
    ns_log Error "Error deleting old logfile: " $errorInfo
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

# ad_return_complaint 1 "<pre>[array get column]<br>[array get map]<br>[array get parser]<br>[array get parser_args]<br>$header_fields</pre>"

# ------------------------------------------------------------
# Render Result Header

if { "screen" == $output_device_log && $write_log_p } {
    ad_return_top_of_page "
	[im_header]
	[im_navbar]
    "
}

# ------------------------------------------------------------

set cnt 1
set missing_project_list [list]

if { $test_run_p } { im_write_log $output_device_log $write_log_p "<span style='color=red;font-size:14px'>TEST RUN - Nothing will be written to the database</span>" }

foreach csv_line_fields $values_list_of_lists {
    incr cnt

    im_write_log $output_device_log $write_log_p "</ul><hr>\n" 
    im_write_log $output_device_log $write_log_p "<ul><li>Starting to parse line $cnt</li>\n" 

    if {[llength $csv_line_fields] < 4} {
	    im_write_log $output_device_log $write_log_p"<li><font color=red>Error: We found a row with only [llength $csv_line_fields] columns.<br>
	        This is probabily because of a multi-line field in the row before.<br>Please correct the CSV file.</font>\n"
	continue
    }

    # Preset values, defined by CSV sheet:
    set user_id          	""
    set project_id       	""
    set target_project_id 	""
    set project_nr       	""
    set project_nr_path  	""
    set project_name	 	""
    set target_project_name     ""
    set day              ""
    set hours            ""
    set billing_rate     ""
    set billing_currency ""
    set note             ""
    set cost_id          ""
    set invoice_id       ""
    set internal_note    ""
    set material_id      ""
    set days             ""
    set hour_id          ""
    set conf_object_id   ""


    foreach j [array names column] {

	# Extract values
	set pretty_var_name $column($j)
	set target_var_name $map($j)
	set p $parser($j)
	set p_args $parser_args($j)

	# Extract the value from the CSV line
	set var_value [string trim [lindex $csv_line_fields $j]]

	# There is a im_csv_import_parser_* proc for every parser.
	set proc_name "im_csv_import_parser_$p"
	if {"" != $var_value} {
	    if {[catch {
		set result [$proc_name -parser_args $p_args $var_value]
		set var_value [lindex $result 0]
		set err [lindex $result 1]
		ns_log Notice "import-im_hour: Parser: '$p -args $p_args $var_value' -> $target_var_name=$var_value, err=$err"
		if {"" != $err} {
		    im_write_log $output_device_log $write_log_p  "<li><font color=brown>Warning: Error parsing field='$target_var_name' using parser '$p':<pre>$err</pre></font></li>\n" 
		}
	    } err_msg]} {
		im_write_log $output_device_log $write_log_p  "<li><font color=brown>Warning: Error parsing field='$target_var_name' using parser '$p':<pre>$err_msg</pre></font></li>\n\n" 
	    }
	}
	set $target_var_name $var_value
    }

    # Get project name for logging 
    if { ![info exists project_name] } {
	set [db_string get_project_name "select project_name from im_projects where project_id = :project_id" -default ""]
    }
    
    # -------------------------------------------------------
    # Specific field transformations

    # Check if day, user_id, project_id, hours 

    # day is mandatory
    if {"" == $day} {
            im_write_log $output_device_log $write_log_p  "<li><font color=red>Error: We have found an empty 'day' in line $cnt.<br>
                Please correct the CSV file. 'day' is mandatory. Skipping line!</font></li>\n"
        continue
    }

    # user_id is mandatory
    if {"" == $user_id} {
            im_write_log $output_device_log $write_log_p  "<li><font color=red>Error: We have found an empty 'user_id' in line $cnt.<br>
                Please correct the CSV file. 'user_id' is mandatory. Skipping line!</font></li>\n"
        continue
    }

    # either project_id, project_nr or project_path need to be provided 
    if {""eq $project_id && "" eq $project_nr_path && "" eq $project_nr } {
            im_write_log $output_device_log $write_log_p  "<li><font color=red>Error: $cnt.<br>
                Please correct the CSV file. Import requires at least one of the following fields: 'project_id', 'project_nr' or 'project_nr_path'. Skipping line!</font></li>\n"
        continue
    }

    # value for hours is mandatory
    if {"" == $hours } {
            im_write_log $output_device_log $write_log_p  "<li><font color=red>Error: We have found an empty 'hours' in line $cnt.<br>
                Please correct the CSV file. 'hours' is mandatory. Skupping line!</font></li>\n"
        continue
    }

    # Check permissions
    im_project_permissions $current_user_id $project_id view_p read_p write_p admin_p
    if {!$write_p} {
	im_write_log $output_device_log $write_log_p "<li><font color=red>Error: You don't have write permissions for project #$project_id. Skipping line!</font></li>\n"
        continue
    }

    # -------------------------------------------------------
    # Find project_id in target DB 
    #

    im_write_log $output_device_log $write_log_p  "<li>Matching projects:</li>\n"

    # Find target_project_id based on project_nr_path 
    im_write_log $output_device_log $write_log_p  "<li>Checking first for 'project_nr_path'</li>\n"
    if { "" ne $project_nr_path } {
	set sql "select project_id as target_project_id, project_name as target_project_name from im_projects where im_project_nr_parent_list(project_id) = '$project_nr_path'"
	db_0or1row get_target_project_id $sql
    } else {
	im_write_log $output_device_log $write_log_p  "<li>No project_nr_path found, now checking for 'project_nr'. We assume that hours to be imported come from the same \]po\[ instance.</li>\n"
    }

    # Check for project_nr
    if { "" eq $target_project_id } {
	im_write_log $output_device_log $write_log_p  "<li>No project found for project_nr_path: $project_nr_path, now checking for 'project_nr'.</li>\n"
	if { "" ne $project_nr  } {
	    set sql "select project_id as target_project_id, project_name as target_project_name from im_projects where project_nr = '$project_nr'"
	    db_0or1row get_target_project_id $sql
	} else {
	    im_write_log $output_device_log $write_log_p  "<li>No project_nr found, now checking for project_id</li>\n"
	}

	# Check for project_id
	if { "" eq $target_project_id } {
	    im_write_log $output_device_log $write_log_p  "<li>No project found for project_nr: $project_nr, now checking for 'project_id'.</li>\n"
	    if { "" ne $project_id } {
		set sql "select project_id as target_project_id, project_name as target_project_name from im_projects where project_id = $project_id"
		db_0or1row get_target_project_id $sql
	    } else {
		im_write_log $output_device_log $write_log_p  "<li>No project_id found.</li>\n"
	    }
	    if { "" eq $target_project_id } {
		im_write_log $output_device_log $write_log_p  "<li>No matching project found for project_id: $project_id.</li>\n"
	    } else {
		im_write_log $output_device_log $write_log_p  "<li><span style='color:green'>Found matching project_id ($project_id) for project: $project_name: $target_project_name ($target_project_id)</span></li>\n"
	    }
	} else {
	    im_write_log $output_device_log $write_log_p  "<li><span style='color:green'>Found matching project_nr ($project_nr) for project: $project_name: $target_project_name ($target_project_id)</span></li>\n"
	}
    } else {
	im_write_log $output_device_log $write_log_p  "<li><span style='color:green'>Found matching project_nr_path ($project_nr_path) for project: $project_name: $target_project_name ($target_project_id)</span></li>\n"
    }

    if { "" eq $target_project_id } {
	im_write_log $output_device_log $write_log_p  "<li><font color=red>Error: No matching project found for project: $project_nr_path / $project_nr / $project_name. Skipping line!</font></li>\n"

	if { "" eq $project_nr_path } { set project_nr_path * }
	if { "" eq $project_nr } { set project_nr * }
	if { "" eq $project_name } { set project_name * }

	if { "-1" eq [lsearch -exact $missing_project_list "project_nr_path / $project_nr / $project_name" ] } {
	    lappend missing_project_list "$project_nr_path / $project_nr / $project_name"	    
	}
	continue
    }

    # -------------------------------------------------------
    # Check if there is a conf object 
    #
    set conf_object_id_exist_p [db_string get_conf_object_id "
        select  conf_object_id
        from    im_hours h
        where
                h.day = :day and
                h.user_id = :user_id and
                h.project_id = :target_project_id
    " -default 0]

    if { $conf_object_id_exist_p } {
       im_write_log $output_device_log $write_log_p  "<li>Merging hours: <font color=red>Conf Object exists, skipping project_id: $target_project_id, user_id: $user_id, day: $day</font></li>\n"
       continue
    }

    # -------------------------------------------------------
    # Check if there are hours booked for that day 
    #
    set hours_before [db_string get_hours "
	select	coalesce(h.hours,0) as hours
	from	im_hours h
	where	 
 		h.day = :day and
		h.user_id = :user_id and
		h.project_id = :target_project_id		
    " -default ""]
		
    if { $hours_before > 0  && $merge_p } {
	# Update 
	im_write_log $output_device_log $write_log_p  "<li>Merging hours: project_id: $target_project_id, user_id: $user_id, day: $day</li>\n"
	if { !$test_run_p } { 
	    im_write_log $output_device_log $write_log_p  "<li>Updating ...</li>\n"
	    db_dml sql "update im_hours h set (hours, note) values (h.hours + :hours_before, h.note || ', ' || :note) where h.project_id = :target_project_id and h.user_id = :user_id and h.day = :day" 
	}
    } elseif { $hours_before > 0 && !$merge_p } {
	# Overwrite 
	im_write_log $output_device_log $write_log_p  "<li>Overwrite hours: project_id: $target_project_id, user_id: $user_id, day: $day</li>\n"
	if { !$test_run_p } { 
	    im_write_log $output_device_log $write_log_p  "<li>Updating ...</li>\n"
	    db_dml sql "update im_hours h set (hours, note) values (:hours, :note) where h.project_id = :target_project_id and h.user_id = :user_id and h.day = :day" 
	}
    } elseif { $hours_before == 0 } {
	# create im_hours record 
	if { !$test_run_p } {
	    if {[catch {
		im_write_log $output_device_log $write_log_p "<li>Create new hour record: project_id: $target_project_id, user_id: $user_id, day: $day</li>\n"	
		db_dml insert_hour "insert into im_hours (user_id,project_id,day,hours,note) values (:user_id,:target_project_id,:day,:hours,:note)"
	    } err_msg]} {
		global errorInfo
		ns_log Error $errorInfo
		im_write_log $output_device_log $write_log_p  "<li>Create hour record: <font color=red>Error: insert failed for $target_project_id, user_id: $user_id, day: $day - $errorInfo</font></li>\n"
	    }
	}
    } else {
	im_write_log $output_device_log $write_log_p  "<li><font color=red>Error: not writing anything for: $target_project_id, user_id: $user_id, day: $day</font></li>\n"
    } 


    if {$sync_cost_item_immediately_p} {
	# Update the affected project's cost_hours_cache and cost_days_cache fields,
	# so that the numbers will appear correctly in the TaskListPage
	foreach project_id [array names modified_projects_hash] {
	    # Update sum(hours) and percent_completed for all modified projects
	    im_timesheet_update_timesheet_cache -project_id $project_id
	    # Create timesheet cost_items for all modified projects
	    im_timesheet2_sync_timesheet_costs -project_id $project_id
	}
	
	# The cost updates don't get promoted to the main project
	im_cost_cache_sweeper
    }
}

im_write_log $output_device_log $write_log_p "</ul>\n"
im_write_log $output_device_log $write_log_p "<p>\n"
im_write_log $output_device_log $write_log_p "<p>List of missing projects:<br/>$missing_project_list</p>"
im_write_log $output_device_log $write_log_p "<br/>"
im_write_log $output_device_log $write_log_p "<A HREF=$return_url>Return</A>\n"

# ------------------------------------------------------------
# Render Report Footer
if { "screen" == $output_device_log && $write_log_p } {
    im_write_log $output_device_log $write_log_p [im_footer]
} elseif {"screen" != $output_device_log && $write_log_p } {
    ad_return_top_of_page "
        [im_header]
        [im_navbar]
    "
    ns_write "Files imported. Logfile is located at: $path_tmp <br/>"

    set fp [open $path_tmp r]
    set file_data [read $fp]
    close $fp

    ns_write $file_data
    
} else {

    ad_return_top_of_page "
        [im_header]
        [im_navbar]
    "
    ns_write "Import finished."

}
