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
    { ns_write_p 1 }
    { merge_p 1 }
    { test_run_p 1 }
    column:array
    map:array
    parser:array
    parser_args:array
}


# ---------------------------------------------------------------------
# Help proc to determine missing projects / user in target domain 
# ---------------------------------------------------------------------

# ---------------------------------------------------------------------
# Default & Security
# ---------------------------------------------------------------------
				
set current_user_id [auth::require_login]
set page_title [lang::message::lookup "" intranet-cvs-import.Upload_Objects "Upload Objects"]
set context_bar [im_context_bar "" $page_title]
set sync_cost_item_immediately_p [parameter::get_from_package_key -package_key intranet-timesheet2 -parameter "SyncHoursImmediatelyAfterEntryP" -default 1]

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
# Get DynFields

# Determine the list of actually available fields.
set mapped_vars [list "''"]
foreach k [array names map] {
    lappend mapped_vars "'$map($k)'"
}

set dynfield_sql "
	select distinct
		aa.attribute_name,
		aa.object_type,
		aa.table_name,
		w.parameters,
		w.widget as tcl_widget,
		substring(w.parameters from 'category_type \"(.*)\"') as category_type
	from	im_dynfield_widgets w,
		im_dynfield_attributes a,
		acs_attributes aa
	where	a.widget_name = w.widget_name and
		a.acs_attribute_id = aa.attribute_id and
		aa.object_type in ('im_hours') and
		(also_hard_coded_p is null OR also_hard_coded_p = 'f') and
		-- Only overwrite DynFields specified in the mapping
		aa.attribute_name in ([join $mapped_vars ","])
"

set attribute_names [db_list attribute_names "
	select	distinct
		attribute_name
	from	($dynfield_sql) t
	order by attribute_name
"]

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
set missing_project_list [list]

if { $ns_write_p && $test_run_p } { ns_write "<span style='color=red;font-size:14px'>TEST RUN - Nothing will be written to the database</span>" }

foreach csv_line_fields $values_list_of_lists {
    incr cnt

    if {$ns_write_p} { ns_write "</ul><hr>\n" }
    if {$ns_write_p} { ns_write "<ul><li>Starting to parse line $cnt\n" }

    if {[llength $csv_line_fields] < 4} {
	if {$ns_write_p} {
	    ns_write "<li><font color=red>Error: We found a row with only [llength $csv_line_fields] columns.<br>
	        This is probabily because of a multi-line field in the row before.<br>Please correct the CSV file.</font>\n"
	}
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

    foreach attribute_name $attribute_names {
	set $attribute_name	""
    }


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
		ns_log Notice "import-im_project: Parser: '$p -args $p_args $var_value' -> $target_var_name=$var_value, err=$err"
		if {"" != $err} {
		    if {$ns_write_p} { 
			ns_write "<li><font color=brown>Warning: Error parsing field='$target_var_name' using parser '$p':<pre>$err</pre></font>\n" 
		    }
		}
	    } err_msg]} {
		if {$ns_write_p} { 
		    ns_write "<li><font color=brown>Warning: Error parsing field='$target_var_name' using parser '$p':<pre>$err_msg</pre></font>" 
		}
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
        if {$ns_write_p} {
            ns_write "<li><font color=red>Error: We have found an empty 'day' in line $cnt.<br>
                Please correct the CSV file. 'day' is mandatory. Skipping line!</font></li>"
        }
        continue
    }

    # user_id is mandatory
    if {"" == $user_id} {
        if {$ns_write_p} {
            ns_write "<li><font color=red>Error: We have found an empty 'user_id' in line $cnt.<br>
                Please correct the CSV file. 'user_id' is mandatory. Skipping line!</font></li>"
        }
        continue
    }

    # either project_id, project_nr or project_path need to be provided 
    if {""eq $project_id && "" eq $project_nr_path && "" eq $project_nr } {
        if {$ns_write_p} {
            ns_write "<li><font color=red>Error: $cnt.<br>
                Please correct the CSV file. Import requires at least one of the following fields: 'project_id', 'project_nr' or 'project_nr_path'. Skipping line!</font></li>"
        }
        continue
    }

    # value for hours is mandatory
    if {"" == $hours } {
        if {$ns_write_p} {
            ns_write "<li><font color=red>Error: We have found an empty 'hours' in line $cnt.<br>
                Please correct the CSV file. 'hours' is mandatory. Skupping line!</font></li>"
        }
        continue
    }

    # Check permissions
    im_project_permissions $current_user_id $project_id view_p read_p write_p admin_p
    if {!$write_p} {
	if {$ns_write_p} {
	    ns_write "<li><font color=red>Error: You don't have write permissions for project #$project_id. Skipping line!</font></li>"
	}
	continue
    }

    # -------------------------------------------------------
    # Find project_id in target DB 
    #

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
	ns_write "<li><font color=red>Error: No matching project found for project: $project_nr_path / $project_nr / $project_name. Skipping line!</font></li>"

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
       ns_write "<li>Merging hours: <font color=red>Conf Object exists, skipping project_id: $target_project_id, user_id: $user_id, day: $day</font></li>"
       continue
    }

    # -------------------------------------------------------
    # Check if there are hours booked for that day 
    #
    set hours [db_string get_hours "
	select	coalesce(h.hours,0) as hours
	from	im_hours h
	where	 
 		h.day = :day and
		h.user_id = :user_id and
		h.project_id = :target_project_id		
    " -default ""]
		
    if { $hours > 0  && $merge_p } {
	# Update 
	ns_write "<li>Merging hours: project_id: $target_project_id, user_id: $user_id, day: $day</li>"
	if { !$test_run_p } { db_dml sql "update im_hours h set (hours, note) values (h.hours + :hours, h.note || ', ' || :note) where h.project_id = :target_project_id and h.user_id = :user_id and h.day = :day" }
    } elseif { $hours > 0 && !$merge_p } {
	# Overwrite 
	ns_write "<li>Overwrite hours: project_id: $target_project_id, user_id: $user_id, day: $day</li>"
	if { !$test_run_p } { db_dml sql "update im_hours h set (hours, note) values (:hours, :note) where h.project_id = :target_project_id and h.user_id = :user_id and h.day = :day" }
    } elseif { $hours == 0 } {
	# create im_hours record 
	if { !$test_run_p } {
	    if {[catch {
		db_dml insert_hour "insert into im_hours (user_id,project_id,day,hours,note) values (:user_id,:target_project_id,:day,:hours,:note)"
	    } err_msg]} {
		global errorInfo
		ns_log Error $errorInfo
		ns_write "<li>Merging hours: <font color=red>Conf Object exists, skipping project_id: $target_project_id, user_id: $user_id, day: $day</font></li>"
	    }
	}
	ns_write "<li>Merging hours: project_id: $target_project_id, user_id: $user_id, day: $day</li>"	
    } 

    # -------------------------------------------------------
    # Import DynFields    
    set im_hours_dynfield_updates ""
    set im_hours_updates {}
    array unset attributes_hash
    array set attributes_hash {}
    db_foreach store_dynfiels $dynfield_sql {
	ns_log Notice "import-im_hours: name=$attribute_name, otype=$object_type, table=$table_name"

	# Avoid storing attributes multipe times into the same table.
	# Sub-types can have the same attribute defined as the main type, so duplicate
	# DynField attributes are OK.
	set key "$attribute_name-$table_name"
	if {[info exists attributes_hash($key)]} {
	    ns_log Notice "import-im_hours: name=$attribute_name already exists."
	    continue
	}
	set attributes_hash($key) $table_name
	lappend im_hours_dynfield_updates "$attribute_name = :$attribute_name"
    }

    if {$ns_write_p} { ns_write "<li>Going to update im_hours DynFields.\n" }
    if {"" != $im_hours_dynfield_updates} {
	set hours_update_sql "
		update im_hours set
		[join $im_hours_dynfield_updates ",\n\t\t"]
		where 
	                h.day = :day and
        	        h.user_id = :user_id
                	h.project_id = :target_project_id

	"
	if {[catch {
	    db_dml hours_dynfield_update $hours_update_sql
	} err_msg]} {
	    if {$ns_write_p} { ns_write "<li><font color=brown>Warning: Error updating im_hours dynfields:<br><pre>$err_msg</pre></font>" }
	}
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


if {$ns_write_p} {
    ns_write "</ul>\n"
    ns_write "<p>\n"
    ns_write "<p>List of missing projects:<br/>$missing_project_list</p>"
    ns_write "<br/>"
    ns_write "<A HREF=$return_url>Return</A>\n"
}

# ------------------------------------------------------------
# Render Report Footer

if {$ns_write_p} {
    ns_write [im_footer]
}


