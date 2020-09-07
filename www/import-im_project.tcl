# /packages/intranet-csv-import/www/import-im_project.tcl
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
if {0 && !$admin_p} {
    ad_return_complaint 1 "Only administrators have the right to import objects"
    ad_script_abort
}

# By default, how many hours do an employee work per day?
set hours_per_day [parameter::get_from_package_key -package_key "intranet-timesheet2" -parameter "TimesheetHoursPerDay" -default 8]


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


# ---------------------------------------------------------------------
# Determine header_var_name
# ---------------------------------------------------------------------


set mapped_vars [list "''"]
set debug_rows "<tr><td colspan=2>header_len</td><td colspan=5>$header_len</td></tr>"
foreach i [array names column] {
    set header [string trim $column($i)]
    if {$header ne $column($i)} { set column($i) $header }
    set m $map($i)
    set p $parser($i)
    set args $parser_args($i)

    # Calculate var name from header 
    set var [string tolower $header]
    set var [im_mangle_unicode_accents $var]
    set var [string map -nocase {" " "_" "\"" "" "'" "" "/" "_" "-" "_" "\[" "(" "\{" "(" "\}" ")" "\]" ")"} $var]
    set header_var($i) $var

    # Determine the list of actually available fields for SQL statement
    lappend mapped_vars "'$map($i)'"

    append debug_rows "<tr><td>$i</td><td>$header</td><td>$var</td><td>$m</td><td>$p</td><td>$args</td><td></td></tr>\n"
}
set debug "<table border=1>$debug_rows</table>"


# ---------------------------------------------------------------------
# Get DynFields
# ---------------------------------------------------------------------

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
		aa.object_type in ('im_project', 'im_timesheet_task') and
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
     ns_write "<h1>Importing Projects/Tasks</h1>"
}

# ------------------------------------------------------------

set cnt 1
foreach csv_line_fields $values_list_of_lists {
    incr cnt

    if {$ns_write_p} { ns_write "</ul><hr><ul>\n" }
    if {$ns_write_p} { ns_write "<li>Starting to parse line $cnt\n" }

    # Reset values used in the rest of the loop
    set project_name		""
    set project_nr		""
    set project_path		""
    set customer_name		""
    set company_id		""
    set parent_nrs		""
    set parent_id		""

    set parent0 		""
    set parent1 		""
    set parent2 		""
    set parent3 		""

    set project_status		""
    set project_status_id	""
    set project_type		""
    set project_type_id	 	""

    set project_manager		""
    set project_lead_id	 	""
    set start_date		""
    set end_date		""
    set percent_completed	""
    set on_track_status 	""

    set project_budget		""
    set project_budget_hours	""

    set description		""
    set note			""

    set customer_contact	""
    set customer_contact_id	""
    set customer_project_nr	""
    set confirm_date		""
    set milestone_p		""
    set sort_order		""
    set template_p		""

    set cost_center		""
    set uom			""
    set material		""
    set planned_units		""
    set billable_units		""
    set priority		""

    # Reset DynFields
    foreach attribute_name $attribute_names { set $attribute_name "" }

    # -------------------------------------------------------
    # Set default values without parser from header names
    foreach j [array names parser] {
	set v $header_var($j)
	if {"" eq $v} { continue }
	set var_value [string trim [lindex $csv_line_fields $j]]
	set var_value [string map -nocase {"\"" "'" "\[" "(" "\{" "(" "\}" ")" "\]" ")" "\$" "" "\\" ""} $var_value]
	if {"NULL" eq $var_value} { set var_value ""}
	set cmd "set $v \"$var_value\""
	ns_log Notice "upload-companies-2: cmd=$cmd"
	set result [eval $cmd]
    }

    # -------------------------------------------------------
    # Transform the variables
    foreach i [array names parser] {
	set varname $header_var($i)
	set p $parser($i)
	set p_args $parser_args($i)
	set target_varname $map($i)
	ns_log Notice "import-im_project: i=$i: var=$varname -> target=$target_varname using parser=$p ($p_args)"

	set proc_name "im_csv_import_parser_$p"
	if {[catch {
	    set val [set $varname]
	    set $target_varname ""
	    if {"" != $val} {
		set result [$proc_name -parser_args $p_args $val]		
		set res [lindex $result 0]
		set err [lindex $result 1]
		ns_log Notice "import-im_project: var=$varname -> target=$target_varname using parser=$p ($p_args): '$val' -> '$res', err=$err"
		if {"" ne $err} {
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

	ns_log Notice "import-im_project: "
	ns_log Notice "import-im_project: -------------------------------------------"
	ns_log Notice "import-im_project: "
    }
    
    # -------------------------------------------------------
    # Specific field transformations
    # -------------------------------------------------------

    # project_name needs to be there
    if {"" == $project_name} {

        if {"" eq $project_nr && "" eq $parent_nrs} {
	    ns_write "<li>We have found an empty line $cnt.\n"
	    continue
        }

	if {$ns_write_p} {
	    ns_write "<li><font color=red>Error: We have found an empty 'Project Name' in line $cnt.<br>
	        Please correct the CSV file. Every projects needs to have a unique Project Name.</font>\n"
	}
	continue
    }

    # Parent0 - Parent1 - Parent2 - Parent3
    if {"" ne $parent0} {
	if {$ns_write_p} { ns_write "<li>Parent0: Looking for a main project with name=$parent0</font>\n" }
	set result [im_csv_import_parser_project_name -parent_id "" $parent0]
	set parent0_id [lindex $result 0]
	set err [lindex $result 1]
	if {"" ne $err} {
	    if {$ns_write_p} { ns_write "<li><font color=red>Error in parent0: <pre>$err</pre></font>\n" }
	    continue
	} else {
	    set parent_id $parent0_id
	    if {$ns_write_p} { ns_write "<li>Parent0: found: #$parent_id\n" }
	}
    }
    if {"" ne $parent1} { 
	if {"" eq $parent_id} {
	    if {$ns_write_p} { ns_write "<li><font color=red>Error in parent1: Did not find parent_id, which is required for parent1</font>\n" }
	    continue
	} else {
	    if {$ns_write_p} { ns_write "<li>Parent1: Looking for a project with parent_id=$parent_id and name=$parent1</font>\n" }
	}
	set result [im_csv_import_parser_project_name -parent_id $parent_id $parent1]
	set parent1_id [lindex $result 0]
	set err [lindex $result 1]
	if {"" ne $err} {
	    if {$ns_write_p} { ns_write "<li><font color=red>Error in parent1: <pre>$err</pre></font>\n" }
	    continue
	}
	if {"" ne $parent1_id} {
	    set parent_id $parent1_id
	    if {$ns_write_p} { ns_write "<li>Parent1: Found project_id=$parent_id\n" }
	} else {
	    if {$ns_write_p} { ns_write "<li><font color=red>Parent1: Didn't find project with name=$parent1</font>\n" }
	    continue
	}
    }
    if {"" ne $parent2} { 
	if {"" eq $parent_id} {
	    if {$ns_write_p} { ns_write "<li><font color=red>Error in parent2: Did not find parent_id, which is required for parent2</font>\n" }
	    continue
	} else {
	    if {$ns_write_p} { ns_write "<li>Parent2: Looking for a project with parent_id=$parent_id and name=$parent2</font>\n" }
	}
	set result [im_csv_import_parser_project_name -parent_id $parent_id $parent2]
	set parent2_id [lindex $result 0]
	set err [lindex $result 2]
	if {"" ne $err} {
	    if {$ns_write_p} { ns_write "<li><font color=red>Error in parent2: <pre>$err</pre></font>\n" }
	    continue
	}
	if {"" ne $parent2_id} {
	    set parent_id $parent2_id
	    if {$ns_write_p} { ns_write "<li>Parent2: Found project_id=$parent_id\n" }
	} else {
	    if {$ns_write_p} { ns_write "<li><font color=red>Parent2: Didn't find project with name=$parent2</font>\n" }
	    continue
	}
    }
    if {"" ne $parent3} { 
	if {"" eq $parent_id} {
	    if {$ns_write_p} { ns_write "<li><font color=red>Error in parent3: Did not find parent_id, which is required for parent3</font>\n" }
	    continue
	} else {
	    if {$ns_write_p} { ns_write "<li>Parent3: Looking for a project with parent_id=$parent_id and name=$parent3</font>\n" }
	}
	set result [im_csv_import_parser_project_name -parent_id $parent_id $parent3]
	set parent3_id [lindex $result 0]
	set err [lindex $result 3]
	if {"" ne $err} {
	    if {$ns_write_p} { ns_write "<li><font color=red>Error in parent3: <pre>$err</pre></font>\n" }
	    continue
	}
	if {"" ne $parent3_id} {
	    set parent_id $parent3_id
	    if {$ns_write_p} { ns_write "<li>Parent3: Found project_id=$parent_id\n" }
	} else {
	    if {$ns_write_p} { ns_write "<li><font color=red>Parent3: Didn't find project with name=$parent2</font>\n" }
	    continue
	}
    }



    # parent_nrs contains a space separated list
    if {"" ne $parent_nrs} {
	if {[catch {
	    set result [im_csv_import_parser_project_parent_nrs $parent_nrs]
	} err_msg]} {
	    if {$ns_write_p} { ns_write "<li><font color=red>Error: We have found an error parsing Parent NRs '$parent_nrs'.<pre>\n$err_msg</pre>" }
	    continue
	}
	set parent_id [lindex $result 0]
	set err [lindex $result 1]
	if {"" != $err} {
	    if {$ns_write_p} { ns_write "<li><font color=red>Error: <pre>$err</pre></font>\n" }
	    continue
	}
    }
  
    # Status is a required field
    if {"" eq $project_status_id} {
	set project_status_id [im_id_from_category $project_status "Intranet Project Status"]
	if {"" eq $project_status_id} {
	    if {$ns_write_p} { ns_write "<li><font color=brown>Warning: Didn't find project status '$project_status', using default status 'Open'</font>\n" }
	    set project_status_id [im_project_status_open]
	}
    }

    # Project type is optional: Main projects are assumed to be "Gantt Projects", while sub-project are assumed to be "Task"
    if {"" eq $project_type_id} {
	set project_type_id [im_id_from_category [list $project_type] "Intranet Project Type"]
	if {"" == $project_type_id} {
	    set project_type_id [im_project_type_gantt]
	    if {"" ne $parent_id} { set project_type_id [im_project_type_task] }
	    if {$ns_write_p} { ns_write "<li><font color=brown>Warning: Didn't find project type '$project_type', using default type '[im_category_from_id $project_type_id]'</font>\n" }
	}
    }

    # start_date and end_date are required fields for projects, not tasks
    if { $project_type_id != 100 } {
	if {"" == $start_date} {
	    if {$ns_write_p} { ns_write "<li><font color=brown>Warning: Didn't find project start_date, using today.</font>\n" }
	    set start_date [db_string today "select now()::date"]
	}
	if {"" == $end_date} {
	    if {$ns_write_p} { ns_write "<li><font color=brown>Warning: Didn't find project end_date, using start_date+1 or today.</font>\n" }

	    catch {
		set end_date [db_string today "select start_date::date + 1"]
	    } err_msg
	}
	
	if {"" == $end_date} {
	    if {$ns_write_p} { ns_write "<li><font color=brown>Warning: Didn't find project end_date, using today.</font>\n" }
	    set end_date [db_string today "select now()::date + 1"]
	}
    }

    # On track status can be NULL without problems
    set on_track_status_id [im_id_from_category [list $on_track_status] "Intranet Project On Track Status"]

    # company_id
    if {"" == $company_id } { 
	set company_id [db_string cust "select company_id from im_companies where lower(company_name) = trim(lower(:customer_name))" -default ""] 
    }
    if {"" == $company_id } { 
	set company_id [db_string cust "select company_id from im_companies where lower(company_path) = trim(lower(:customer_name))" -default ""] 
    }

    # For compatibility
    set company_id $company_id
    if {"" == $company_id } { 
	if { 100 == $project_type_id } {
	    # Get company_id from top_project 
	    set sql "
	    select company_id from im_projects where project_id in (
		select  parent.project_id
		from    im_projects parent,
		im_projects child
	    	where   child.project_id = :parent_id and
	                parent.tree_sortkey = tree_root_key(child.tree_sortkey)
		)
	    "
	    set company_id [db_string get_company_id $sql -default 0]
	} else {
	    set company_id [im_company_internal]
	    if {$ns_write_p} { ns_write "<li><font color=brown>Warning: Didn't find customer_name='$customer_name', using 'internal' customer</font>\n" }
	}
    }

    # project_nr is based on the parent
    if {"" == $project_nr} {
	set project_nr [im_next_project_nr -customer_id $company_id -parent_id $parent_id]

	#if {$ns_write_p} {
	#    ns_write "<li><font color=red>Error: We have found an empty 'Project Nr' in line $cnt.<br>
	#    Please correct the CSV file. Every project needs to have a unique Project Nr.</font>\n"
	#}
	#continue
    }


    # Project Lead / Project Manager
    if { "" eq $project_lead_id && 100 != $project_type_id } {
	if {$ns_write_p} { ns_write "<li><font color=brown>Warning: No project manager found. Will try to create project w/o PM. </font>\n" }
    }

    set customer_contact_id ""
    if {"" ne $customer_contact} {
	set customer_contact_tuple [im_csv_import_parser_user_name $customer_contact]
	set customer_contact_id [lindex $customer_contact_tuple 0]
	set customer_contact_error [lindex $customer_contact_tuple 1]
	if {"" == $customer_contact_id && "" != $customer_contact} {
	    if {$ns_write_p} { ns_write "<li><font color=brown>Warning: Didn't find customer contact '$customer_contact'.</font>\n"	}
	}
	if {"" ne $customer_contact_error} {
	    if {$ns_write_p} { ns_write "<li><font color=brown>Warning: Error parsing customer contact '$customer_contact':<br>$customer_contact_error.</font>\n" }
	}
    }

    # -------------------------------------------------------
    # Check if the project already exists

    set parent_id_sql "= $parent_id"
    if {"" == $parent_id} { 
	set parent_id_sql "is null"
    }

    set project_id [db_string project_id "
	select	project_id
	from	im_projects p
	where	p.parent_id $parent_id_sql and
		lower(trim(project_nr)) = lower(trim(:project_nr))
    " -default ""]

    set project_id2 [db_string project_id "
	select	project_id
	from	im_projects p
	where	p.parent_id $parent_id_sql and
		lower(trim(project_name)) = lower(trim(:project_name))
    " -default ""]

    if {$project_id != $project_id2 && "" != $project_id && "" != $project_id2} {
	if {$ns_write_p} {
	    ns_write "<li><font color=red>Error: We have found two different projects, one with
	    'Project Nr'=$project_nr and a second one with 'Project Name'='$project_name'.<br>
	    Please change one of the two projects to avoid this ambiguity.
	    </font>\n"
	}
	continue
    }
    if {"" == $project_id} { set project_id $project_id2 }


    # Check for problems with project_path
    set project_path_exists_p [db_string project_path_existis_p "
	select	count(*)
	from	im_projects p
	where	p.parent_id $parent_id_sql and
		p.project_id != :project_id and
		lower(trim(project_path)) = lower(trim(:project_path))
    "]
    if {$project_path_exists_p} {
	if {$ns_write_p} { ns_write "<li><font color=red>Error: project_path='$project_path' already exists with the parent '$parent_id'</font>" }
	continue
    }

    # Project Path is the same as the if not specified otherwise
    if {"" == $project_path} { set project_path $project_nr }

    # Create a new project if necessary
    if {"" == $project_id} {

	if {$ns_write_p} { ns_write "<li><font color='green'>Going to create project: name='$project_name', nr='$project_nr'</font></li>" }

	# Check if the user has the permission to create new top-level projects
	if {"" eq $parent_id} {
	    set add_projects_p [im_permission $current_user_id add_projects]
	    if {!$add_projects_p} {
		if {$ns_write_p} { ns_write "<li><font color=red>Error: The current user is not allowed to create new (top-level) projects.</font>" }
		continue
	    }
	} else {
	    # There is a parent. Check if the user can write to it.
	    im_project_permissions $current_user_id $parent_id view_parent_p read_parent_p write_parent_p admin_parent_p
	    if {!$write_parent_p} {
		set parent_name [db_string parent_name "select project_name from im_projects where project_id = :parent_id" -default "undefined"]
		if {$ns_write_p} { ns_write "<li><font color=red>Error: The current user is not allowed to create activities below the (top-level) project '$parent_name' with parent_nrs='$parent_nrs'.</font>" }
		continue
	    }
	}

	if {[catch {
		set project_id [im_project::new \
			    -project_name	$project_name \
			    -project_nr		$project_nr \
			    -project_path	$project_path \
			    -company_id		$company_id \
			    -parent_id		$parent_id \
			    -project_type_id	$project_type_id \
			    -project_status_id	$project_status_id \
			   ]

	    # Add current user as project admin
	    if {"" eq $parent_id && !$admin_p} {
		set role_id [im_biz_object_role_project_manager]
		im_biz_object_add_role $current_user_id $project_id $role_id
	    }

	} err_msg]} {
	    if {$ns_write_p} { ns_write "<li><font color=red>Error: Creating new project:<br><pre>$err_msg</pre></font>\n" }
	    continue
	}

    } else {
	if {$ns_write_p} { ns_write "<li>Project already exists: name='$project_name', nr='$project_nr', id='$project_id'\n" }
    }


    if {$ns_write_p} { ns_write "<li>Going to update the project.\n" }
    if {[catch {
	db_dml update_project "
		update im_projects set
			project_name		= :project_name,
			project_nr		= :project_nr,
			project_path		= :project_path,
			company_id		= :company_id,
			parent_id		= :parent_id,
			project_status_id	= :project_status_id,
			project_type_id		= :project_type_id,
			project_lead_id		= :project_lead_id,
			start_date		= :start_date,
			end_date		= :end_date,
			percent_completed	= :percent_completed,
			sort_order		= :sort_order,
			on_track_status_id	= :on_track_status_id,
			project_budget		= :project_budget,
			project_budget_hours	= :project_budget_hours,
			company_contact_id	= :customer_contact_id,
			company_project_nr	= :customer_project_nr,
			note			= :note,
			description		= :description
		where
			project_id = :project_id
	"
    } err_msg]} {
	if {$ns_write_p} { ns_write "<li><font color=red>Error: Error updating project:<br><pre>$err_msg</pre></font>" }
	continue	    
    }

    # -------------------------------------------------------
    # Make sure there is an entry in im_timesheet_tasks if the project is of type task
    if {$project_type_id == [im_project_type_task]} {

	set material_id ""
	if {"" != $material} {
	    set material_id [db_string material_lookup "
		select	min(material_id)
		from	im_materials
		where	(  lower(trim(material_nr)) = lower(trim(:material)) 
			OR lower(trim(material_name)) = lower(trim(:material))
			)
	    " -default ""]
	    if {"" == $material_id} {
		if {$ns_write_p} { 
		    ns_write "<li><font color=brown>Warning: Didn't find material '$material', using 'Default'.</font>\n" 
		}
	    }
	}
	if {"" == $material_id} {
	    set material_id [im_material_default_material_id]
	}
	
	# Task Cost Center
	set cost_center_id [db_string cost_center_lookup "
		select	min(cost_center_id)
		from	im_cost_centers
		where	(  lower(trim(cost_center_name)) = lower(trim(:cost_center)) 
			OR lower(trim(cost_center_label)) = lower(trim(:cost_center))
			OR lower(trim(cost_center_code)) = lower(trim(:cost_center))
			)
	" -default ""]
	if {"" == $cost_center_id && "" != $cost_center} {
	    if {$ns_write_p} { ns_write "<li><font color=brown>Warning: Didn't find cost_center '$cost_center'.</font>\n" }
	}

	# Task UoM
	if {"" eq $uom} { set uom "Hour" }
	set uom_id [im_id_from_category [list $uom] "Intranet UoM"]
	if {"" eq $uom_id} {
	    if {$ns_write_p} { ns_write "<li><font color=brown>Warning: Didn't find UoM '$uom', using default 'Hour'</font>\n" }
	    set uom_id [im_uom_hour]
	}
	switch $uom_id {
	    320 {
		# Hour - nothing to do
	    }
	    321 {
		# Day - multiply by 8
		if {"" ne $planned_units} { set planned_units [expr $planned_units * $hours_per_day] }
	    }
	    328 {
		# Week - multiply by 40
		if {"" ne $planned_units} { set planned_units [expr $planned_units * $hours_per_day * 5.0] }
	    }
	    default {
		if {$ns_write_p} { ns_write "<li><font color=brown>Warning: Found invalid UoM=[im_category_from_id $uom_id], using 'Hour' as a default</font>\n" }
		set uom_id [im_uom_hour]		
	    }
	}

	set task_exists_p [db_string task_exists_p "
		select	count(*)
		from	im_timesheet_tasks
		where	task_id = :project_id
	"]

	if {!$task_exists_p} {
	    if {$ns_write_p} { ns_write "<li>Going to create new im_timesheet_task entry with task_id=$project_id.\n" }
	    db_dml task_insert "
		insert into im_timesheet_tasks (
			task_id,
			material_id,
			uom_id
		) values (
			:project_id,
			:material_id,
			:uom_id
		)
	    "
	    db_dml make_project_to_task "
		update acs_objects
		set object_type = 'im_timesheet_task'
		where object_id = :project_id
	    "
	}

	if {$ns_write_p} { ns_write "<li>Going to update im_timesheet_task with task_id=$project_id.\n" }
	db_dml update_task "
		update im_timesheet_tasks set
			material_id	= :material_id,
			uom_id		= :uom_id,
			planned_units	= :planned_units,
			billable_units	= :billable_units,
			cost_center_id	= :cost_center_id
		where
			task_id = :project_id
	"

	# Add the project lead as a 100% resource to the task
	if {"" != $project_lead_id} {
	    set role_id [im_biz_object_role_full_member]
	    im_biz_object_add_role -percentage 100.0 $project_lead_id $project_id $role_id
	}
    } else {
	# Add the project lead as a PM to the list of project members
	if {"" != $project_lead_id} {
	    set role_id [im_biz_object_role_project_manager]
	    im_biz_object_add_role $project_lead_id $project_id $role_id
	}
    }

    # -------------------------------------------------------
    # Import DynFields    
    set project_dynfield_updates {}
    set task_dynfield_updates {}
    array unset attributes_hash
    array set attributes_hash {}
    db_foreach store_dynfiels $dynfield_sql {
	ns_log Notice "import-im_project: name=$attribute_name, otype=$object_type, table=$table_name"

	# Avoid storing attributes multipe times into the same table.
	# Sub-types can have the same attribute defined as the main type, so duplicate
	# DynField attributes are OK.
	set key "$attribute_name-$table_name"
	if {[info exists attributes_hash($key)]} {
	    ns_log Notice "import-im_project: name=$attribute_name already exists."
	    continue
	}
	set attributes_hash($key) $table_name

	switch $table_name {
	    im_projects {
		lappend project_dynfield_updates "$attribute_name = :$attribute_name"
	    }
	    im_timesheet_tasks {
		lappend task_dynfield_updates "$attribute_name = :$attribute_name"
	    }
	    default {
		if {$ns_write_p} { ns_write "<li><font=red><b>Dynfield Configuration Error</b>:
                	  Attribute='$attribute_name' in table='$table_name' is not in im_projects or im_timesheet_tasks.</font>\n" }
		ad_return_complaint 1 "<b>Dynfield Configuration Error</b>:<br>
		Attribute='$attribute_name' in table='$table_name' is not in im_projects or im_timesheet_tasks."
	    }
	}
    }

    if {$ns_write_p} { ns_write "<li>Going to update im_project DynFields.\n" }
    if {"" != $project_dynfield_updates} {
	set project_update_sql "
		update im_projects set
		[join $project_dynfield_updates ",\n\t\t"]
		where project_id = :project_id
	"
	if {[catch {
	    db_dml project_dynfield_update $project_update_sql
	} err_msg]} {
	    if {$ns_write_p} { ns_write "<li><font color=brown>Warning: Error updating im_project dynfields:<br><pre>$err_msg</pre></font>" }
	}
    }

    if {$ns_write_p} { ns_write "<li>Going to update im_timesheet_task DynFields.\n" }
    if {"" != $task_dynfield_updates} {
	set task_update_sql "
		update im_timesheet_tasks set
		[join $task_dynfield_updates ",\n\t\t"]
		where task_id = :project_id
	"
	if {[catch {
            db_dml task_dynfield_update $task_update_sql
	} err_msg]} {
	    if {$ns_write_p} { ns_write "<li><font color=brown>Warning: Error updating im_timesheet_task dynfields:<br><pre>$err_msg</pre></font>" }
	}

    }

    if {$ns_write_p} { ns_write "<li>Going to write audit log.\n" }
    im_audit -object_id $project_id

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



