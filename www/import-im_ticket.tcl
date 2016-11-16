# /packages/intranet-csv-import/www/import-im_ticket.tcl
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
		aa.object_type in ('im_ticket') and
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
foreach csv_line_fields $values_list_of_lists {
    incr cnt

    if {$ns_write_p} { ns_write "</ul><hr><ul>\n" }
    if {$ns_write_p} { ns_write "<li>Starting to parse line $cnt\n" }

    # Preset values, defined by CSV sheet:
    set project_name		""
    set project_nr		""
    set customer_name		""
    set parent_nrs		""
    set parent_id		""
    set ticket_status		""
    set ticket_status_id	""
    set ticket_type		""
    set ticket_type_id	 	""
    set ticket_queue		""
    set ticket_queue_id	 	""
    set ticket_customer_contact_id ""
    set start_date		""
    set end_date		""
    set description		""
    set note			""
    set creation_user           ""
    set creation_date           ""

    foreach attribute_name $attribute_names { set $attribute_name "" }

    # -------------------------------------------------------
    # Extract variables from the CSV file
    #
    set var_name_list [list]
    for {set j 0} {$j < $header_len} {incr j} {

	set var_name [string trim [lindex $header_fields $j]]
	if {"" eq $var_name} {
	    # No variable name - probably an empty column
	    continue
	}

	set var_name [string tolower $var_name]
	set var_name [string map -nocase {" " "_" "\"" "" "'" "" "/" "_" "-" "_" "\[" "(" "\{" "(" "\}" ")" "\]" ")"} $var_name]
	lappend var_name_list $var_name
	ns_log notice "upload-companies-2: varname([lindex $header_fields $j]) = $var_name"

	set var_value [string trim [lindex $csv_line_fields $j]]
	set var_value [string map -nocase {"\"" "'" "\[" "(" "\{" "(" "\}" ")" "\]" ")" "\$" "" "\\" ""} $var_value]
	if {"NULL" eq $var_value} { set var_value ""}

	# replace unicode characters by non-accented characters
	# Watch out! Does not work with Latin-1 characters
	set var_name [im_mangle_unicode_accents $var_name]

	set cmd "set $var_name \"$var_value\""
	ns_log Notice "upload-companies-2: cmd=$cmd"
	set result [eval $cmd]
    }

    # -------------------------------------------------------
    # Transform the variables
    set i 0
    foreach varname $var_name_list {
	set p $parser($i)
	set p_args $parser_args($i)
	set target_varname $map($i)
	ns_log Notice "import-im_ticket: Parser: i=$i"
	ns_log Notice "import-im_ticket: Parser: varname=$varname -> target_varname=$target_varname"
	ns_log Notice "import-im_ticket: Parser: p_args=$p_args"
	ns_log Notice "import-im_ticket: Parser: target_varname=$target_varname"

	switch $p {
	    no_change { 
		set $target_varname [set $varname]
		ns_log Notice "import-im_ticket: Parser: no change: varname: $varname, val: [set $varname]"
	    }
	    default {
		set proc_name "im_csv_import_parser_$p"
		if {[catch {
		    set val [set $varname]
		    ns_log Notice "import-im_ticket: Parser: val: $val"
		    if {"" != $val} {
			    set result [$proc_name -parser_args $p_args $val]
			    set res [lindex $result 0]
			    set err [lindex $result 1]
			    ns_log Notice "import-im_ticket: Parser: '$p -args $p_args $val' -> $target_varname=$res, err=$err"
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
	ns_log Notice "import-im_ticket: -------------------------------------------"
    }

    # -------------------------------------------------------
    # Specific field transformations

    # ticket_name needs to be there
    if {"" eq $ticket_name} {
	if {$ns_write_p} {
	    ns_write "<li><font color=red>Error: We have found an empty 'Ticket Name' in line $cnt.<br>
	        Please correct the CSV file. Every tickets needs to have a unique Ticket Name.</font>\n"
	}
	continue
    }

    # ticket_nr needs to be there
    if {"" eq $ticket_nr} {
	set ticket_nr [im_ticket::next_ticket_nr]
    }

    # Try to determine parent_id. Tickets need to be part of a ticket container.
    if {"" eq $parent_id} {
	if {[catch {
	    set result [im_csv_import_parser_project_parent_nrs $parent_nrs]
	} err_msg]} {
	    if {$ns_write_p} { ns_write "<li><font color=red>Error: We have found an error parsing Parent Nrs '$parent_nrs'.<pre>\n$err_msg</pre>" }
	    continue
	}
	# ad_return_complaint 1 "parent_id=$parent_id, result=$result, parent_nrs=$parent_nrs"

	set parent_id [lindex $result 0]
	set err [lindex $result 1]
	if {"" != $err} {
	    if {$ns_write_p} { ns_write "<li><font color=red>Error: <pre>$err</pre></font>\n" }
	    continue
	}
    }
    if {"" eq $parent_id} {
	if {$ns_write_p} {
	    ns_write "<li><font color=red>Error: We have found an empty 'Ticket Container' in line $cnt.<br>
	        Please correct the CSV file. Every tickets needs to be part of a Ticket Container project.</font>\n"
	}
	continue
    }
    set parent_project_type_id [util_memoize [list db_string ppti "select project_type_id from im_projects where project_id = $parent_id" -default ""]]
    if {$parent_project_type_id != [im_project_type_sla]} {
	if {$ns_write_p} {
	    ns_write "<li><font color=red>Error: We have found an parent_project #$parent_id in line $cnt.<br>
	        However, the project is not a ticket container.</font>\n"
	}
	continue
    }

    set company_id [util_memoize [list db_string company_id "select company_id from im_projects where project_id = $parent_id"]]

    # Queue
    if {"" eq $ticket_queue_id && "" ne $ticket_queue} {
	set ticket_queue_id [db_string queue "select group_id from groups where lower(trim(group_name)) = lower(trim(:ticket_queue))" -default ""]
    }
    

    # Status is a required field
    if {"" eq $ticket_status_id} { set ticket_status_id [im_id_from_category $ticket_status "Intranet Ticket Status"]  }
    if {"" eq $ticket_status_id} {
	if {$ns_write_p} { ns_write "<li><font color=brown>Warning: Didn't find ticket status '$ticket_status', using default status 'Open'</font>\n" }
	set ticket_status_id [im_ticket_status_open]
    }

    # Type is a required field
    if {"" eq $ticket_type_id} { set ticket_type_id [im_id_from_category [list $ticket_type] "Intranet Ticket Type"] }
    if {"" eq $ticket_type_id} {
	if {$ns_write_p} { ns_write "<li><font color=brown>Warning: Didn't find ticket type '$ticket_type', using default type 'Other'</font>\n" }
	set ticket_type_id [im_ticket_type_other]
    }

    # start_date and end_date are required fields
    if {"" eq $start_date} {
	if {$ns_write_p} { ns_write "<li><font color=brown>Warning: Didn't find ticket start_date, using today.</font>\n" }
	set start_date [db_string today "select now()::date from dual"]
    }
    if {"" eq $end_date} {
	if {$ns_write_p} { ns_write "<li><font color=brown>Warning: Didn't find ticket end_date, using today.</font>\n" }
	set end_date [db_string today "select now()::date from dual"]
    }

    set customer_contact_id ""
    if {"" ne $customer_contact} {
	set customer_contact_tuple [im_csv_import_parser_user_name $customer_contact]
	set customer_contact_id [lindex $customer_contact_tuple 0]
	set customer_contact_error [lindex $customer_contact_tuple 1]
	if {"" eq $customer_contact_id && "" != $customer_contact} {
	    if {$ns_write_p} { ns_write "<li><font color=brown>Warning: Didn't find customer contact '$customer_contact'.</font>\n"	}
	}
	if {"" ne $customer_contact_error} {
	    if {$ns_write_p} { ns_write "<li><font color=brown>Warning: Error parsing customer contact '$customer_contact':<br>$customer_contact_error.</font>\n" }
	}
    }

    # -------------------------------------------------------
    # Check if the ticket already exists


    set ticket_id [db_string ticket_id "
	select	project_id
	from	im_projects p
	where	p.parent_id = :parent_id and
		lower(trim(project_nr)) = lower(trim(:ticket_nr))
    " -default ""]

    set ticket_id2 [db_string ticket_id "
	select	project_id
	from	im_projects p
	where	p.parent_id = :parent_id and
		lower(trim(project_name)) = lower(trim(:ticket_name))
    " -default ""]

    if {$ticket_id != $ticket_id2 && "" != $ticket_id && "" != $ticket_id2} {
	if {$ns_write_p} {
	    ns_write "<li><font color=red>Error: We have found two different tickets, one with
	    'Ticket Nr'=$ticket_nr and a second one with 'Ticket Name'='$ticket_name'.<br>
	    Please change one of the two tickets to avoid this ambiguity.
	    </font>\n"
	}
	continue
    }
    if {"" eq $ticket_id} { set ticket_id $ticket_id2 }

    # Create a new ticket if necessary
    if {"" eq $ticket_id} {

	if {$ns_write_p} { ns_write "<li>Going to create ticket: name='$ticket_name', nr='$ticket_nr'\n" }

	

	if {[catch {
		set ticket_id [im_ticket::new \
				   -ticket_name		$ticket_name \
				   -ticket_nr		$ticket_nr \
				   -ticket_sla_id	$parent_id \
				   -ticket_type_id	$ticket_type_id \
				   -ticket_status_id	$ticket_status_id \
				   -ticket_customer_contact_id $ticket_customer_contact_id \
				   -ticket_start_date	$start_date \
				   -ticket_end_date	$start_date \
				   -ticket_note		$note \
		 ]
	} err_msg]} {
	    if {$ns_write_p} { ns_write "<li><font color=red>Error: Creating new ticket:<br><pre>$err_msg</pre></font>\n" }
	    continue	    
	}
    } else {
	if {$ns_write_p} { ns_write "<li>Ticket already exists: name='$ticket_name', nr='$ticket_nr', id='$ticket_id'\n" }
    }

    if {$ns_write_p} { ns_write "<li>Going to update the ticket.\n" }
    if {[catch {
	db_dml update_projects "
		update im_projects set
			project_name		= :ticket_name,
			project_nr		= :ticket_nr,
			company_id		= :company_id,
			parent_id		= :parent_id,
			project_status_id	= [im_project_status_open],
			project_type_id		= [im_project_type_ticket],
			start_date		= :start_date,
			end_date		= :start_date,
			note			= :note,
			description		= :description
		where
			project_id = :ticket_id
	"

	db_dml update_ticket "
		update im_tickets set
			ticket_assignee_id	= :ticket_assignee_id,
			ticket_customer_contact_id = :ticket_customer_contact_id,
			ticket_dept_id		= :ticket_dept_id,
			ticket_description	= :description,
			ticket_note		= :note,
			ticket_prio_id		= :ticket_prio_id,
			ticket_queue_id		= :ticket_queue_id,
			ticket_status_id	= :ticket_status_id,
			ticket_type_id		= :ticket_type_id
		where
			ticket_id = :ticket_id
	"

    } err_msg]} {
	if {$ns_write_p} { ns_write "<li><font color=red>Error: Error updating ticket:<br><pre>$err_msg</pre></font>" }
	continue	    
    }

    # Add the ticket assignee to the list of ticket members
    if {"" != $ticket_assignee_id} {
	set role_id [im_biz_object_role_project_manager]
	im_biz_object_add_role $ticket_assignee_id $ticket_id $role_id
    }
    if {"" != $ticket_customer_contact_id} {
	set role_id [im_biz_object_role_full_member]
	im_biz_object_add_role $ticket_customer_contact_id $ticket_id $role_id
    }
    
    # -------------------------------------------------------
    # Import DynFields    
    set ticket_dynfield_updates {}
    set project_dynfield_updates {}
    array unset attributes_hash
    array set attributes_hash {}
    db_foreach store_dynfiels $dynfield_sql {
	ns_log Notice "import-im_ticket: name=$attribute_name, otype=$object_type, table=$table_name"

	# Avoid storing attributes multipe times into the same table.
	# Sub-types can have the same attribute defined as the main type, so duplicate
	# DynField attributes are OK.
	set key "$attribute_name-$table_name"
	if {[info exists attributes_hash($key)]} {
	    ns_log Notice "import-im_ticket: name=$attribute_name already exists."
	    continue
	}
	set attributes_hash($key) $table_name

	switch $table_name {
	    im_tickets {
		lappend ticket_dynfield_updates "$attribute_name = :$attribute_name"
	    }
	    im_projects {
		lappend project_dynfield_updates "$attribute_name = :$attribute_name"
	    }
	    default {
		ad_return_complaint 1 "<b>Dynfield Configuration Error</b>:<br>
		Attribute='$attribute_name' in table='$table_name' is not in im_tickets or im_projects."
	    }
	}
    }

    if {$ns_write_p} { ns_write "<li>Going to update im_ticket DynFields.\n" }
    if {"" != $ticket_dynfield_updates} {
	set ticket_update_sql "
		update im_tickets set
		[join $ticket_dynfield_updates ",\n\t\t"]
		where ticket_id = :ticket_id
	"
	if {[catch {
	    db_dml ticket_dynfield_update $ticket_update_sql
	} err_msg]} {
	    if {$ns_write_p} { ns_write "<li><font color=brown>Warning: Error updating im_ticket dynfields:<br><pre>$err_msg</pre></font>" }
	}
    }

    if {$ns_write_p} { ns_write "<li>Going to update im_projects DynFields.\n" }
    if {"" != $project_dynfield_updates} {
	set project_update_sql "
		update im_projects set
		[join $project_dynfield_updates ",\n\t\t"]
		where project_id = :ticket_id
	"
	if {[catch {
            db_dml project_dynfield_update $project_update_sql
	} err_msg]} {
	    if {$ns_write_p} { ns_write "<li><font color=brown>Warning: Error updating im_timesheet_task dynfields:<br><pre>$err_msg</pre></font>" }
	}

    }

    if {$ns_write_p} { ns_write "<li>Going to write audit log.\n" }
    im_audit -object_id $ticket_id

}

if {$ns_write_p} {
    ns_write "</ul>\n"
    ns_write "<p>\n"
    ns_write "<A HREF=$return_url>Return to Ticket Page</A>\n"
}

# ------------------------------------------------------------
# Render Report Footer

if {$ns_write_p} {
    ns_write [im_footer]
}



