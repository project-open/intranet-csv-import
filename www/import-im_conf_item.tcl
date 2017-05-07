# /packages/intranet-csv-import/www/import-im_conf_item.tcl
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
		aa.object_type in ('im_conf_item') and
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
    set conf_item_name		""
    set conf_item_nr		""
    set conf_item_code		""
    set conf_item_parent_nrs	""
    set conf_item_parent_id	""
    set conf_item_status	""
    set conf_item_status_id	""
    set conf_item_type		""
    set conf_item_type_id	""

    set conf_item_owner		""
    set conf_item_owner_id	""
    set conf_item_cost_center_code	""
    set conf_item_cost_center_id	""
    set conf_item_version	""
    set conf_item_project_id    ""

    set description		""
    set note			""
    set sort_order		""

    set ip_address		""


    foreach attribute_name $attribute_names {
	set $attribute_name	""
    }

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
	ns_log notice "upload-companies-2: varname([lindex $header_fields $j]) = $var_name"

	set var_value [string trim [lindex $csv_line_fields $j]]
	set var_value [string map -nocase {"\"" "'" "\[" "(" "\{" "(" "\}" ")" "\]" ")"} $var_value]
	if {"NULL" eq $var_value} { set var_value ""}

	# replace unicode characters by non-accented characters
	# Watch out! Does not work with Latin-1 characters
	set var_name [im_mangle_unicode_accents $var_name]

	set cmd "set $var_name \"$var_value\""
	ns_log Notice "import-im_conf_item: cmd=$cmd"
	set result [eval $cmd]
    }

    # -------------------------------------------------------
    # Transform the variables
    set i 0
    foreach varname $var_name_list {
	set p $parser($i)
	set p_args $parser_args($i)
	set target_varname $map($i)
	ns_log Notice "import-im_conf_item: Parser: $varname -> $target_varname"

	switch $p {
	    no_change { }
	    default {
		set proc_name "im_csv_import_parser_$p"
		if {[catch {
		    set val [set $varname]
		    if {"" != $val} {
			    set result [$proc_name -parser_args $p_args $val]
			    set res [lindex $result 0]
			    set err [lindex $result 1]
			    ns_log Notice "import-im_conf_item: Parser: '$p -args $p_args $val' -> $target_varname=$res, err=$err"
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
    }

    if {$ns_write_p} { ns_write "<li>Before conf_item_nr: name=$conf_item_name, code=$conf_item_code, nr=$conf_item_nr</font>\n" }


    

    # -------------------------------------------------------
    # Specific field transformations

    # conf_item_name needs to be there
    if {"" == $conf_item_name} {
	if {$ns_write_p} {
	    ns_write "<li><font color=red>Error: We have found an empty 'Conf_Item Name' in line $cnt.<br>
	        Please correct the CSV file. Every conf_items needs to have a unique Conf_Item Name.</font>\n"
	}
	continue
    }

    # conf_item_nr needs to be there
    if {"" eq $conf_item_nr} {
	set conf_item_nr [regsub {[^a-z0-9_]} [string trim [string tolower $conf_item_name]] "_"]
    }
    if {"" eq $conf_item_nr} {
	if {$ns_write_p} {
	    ns_write "<li><font color=red>Error: We have found an empty 'Conf_Item Nr' in line $cnt.<br>
	    Please correct the CSV file. Every conf_item needs to have a unique Conf_Item Nr.</font>\n"
	}
	continue
    }

    # Status is a required field
    set conf_item_status_id [im_id_from_category $conf_item_status "Intranet Conf Item Status"]
    if {"" == $conf_item_status_id} {
	if {$ns_write_p} { ns_write "<li><font color=brown>Warning: Didn't find conf_item status '$conf_item_status', using default status 'Open'</font>\n" }
	set conf_item_status_id [im_conf_item_status_active]
    }

    # Type is a required field
    set conf_item_type_id [im_id_from_category [list $conf_item_type] "Intranet Conf Item Type"]
    if {"" == $conf_item_type_id} {
	if {$ns_write_p} { ns_write "<li><font color=brown>Warning: Didn't find conf_item type '$conf_item_type', using default type 'Other'</font>\n" }
	set conf_item_type_id [im_conf_item_type_software]
    }

    # -------------------------------------------------------
    # Check if the conf_item already exists

    set conf_item_parent_id_sql "= $conf_item_parent_id"
    if {"" == $conf_item_parent_id} { 
	set conf_item_parent_id_sql "is null"
    }

    # Check if we find the same conf item by name with it's parent.
    set conf_item_id_name [db_string conf_item_id "
	select	conf_item_id
	from	im_conf_items
	where	conf_item_parent_id $conf_item_parent_id_sql and
		lower(trim(conf_item_name)) = lower(trim(:conf_item_name))
    " -default ""]

    set conf_item_id_nr [db_string conf_item_id "
		select	conf_item_id
		from	im_conf_items
		where	conf_item_parent_id $conf_item_parent_id_sql and
			lower(trim(conf_item_nr)) = lower(trim(:conf_item_nr))
    " -default ""]

    set conf_item_id_code [db_string conf_item_id "
		select	conf_item_id
		from	im_conf_items
		where	lower(trim(conf_item_code)) = lower(trim(:conf_item_code))
    " -default ""]

    set conf_item_id ""
    if {"" eq $conf_item_id} { set conf_item_id $conf_item_id_name }
    if {"" eq $conf_item_id} { set conf_item_id $conf_item_id_nr }
    if {"" eq $conf_item_id} { set conf_item_id $conf_item_id_code }

    set error_p 0
    if {$conf_item_id_name ne "" && $conf_item_id_name ne $conf_item_id} { set error_p 1 }
    if {$conf_item_id_nr ne "" && $conf_item_id_nr ne $conf_item_id} { set error_p 1 }
    if {$conf_item_id_code ne "" && $conf_item_id_code ne $conf_item_id} { set error_p 1 }

    if {$error_p} {
	if {$ns_write_p} {
	    ns_write "<li><font color=red>Warning: We have found two different conf_items, one with
	    'Conf_Item Nr'=$conf_item_nr and a second one with 'Conf_Item Name'='$conf_item_name'.<br>
	    Please change one of the two conf_items to avoid this ambiguity.
	    </font>\n"
	}
    }

    if {$ns_write_p} { ns_write "<li>id=$conf_item_id, parent_id=$conf_item_parent_id, name='$conf_item_name', nr='$conf_item_nr'\n" }


    # Create a new conf_item if necessary
    if {"" == $conf_item_id} {
	if {$ns_write_p} { ns_write "<li>Going to create conf_item: name='$conf_item_name', nr='$conf_item_nr'\n" }

	# Default code for conf item.
	# Conf item codes are unique system wide!
	if {"" == $conf_item_code} {
	    set conf_item_code [db_string code "select nextval('im_conf_item_code_seq') from dual"]
	}

	set var_hash(conf_item_name) $conf_item_name
	set var_hash(conf_item_nr) $conf_item_nr
	set var_hash(conf_item_code) $conf_item_code
	set var_hash(conf_item_parent_id) $conf_item_parent_id
	set var_hash(conf_item_type_id) $conf_item_type_id
	set var_hash(conf_item_status_id) $conf_item_status_id
	if {[catch {
	set conf_item_id [im_conf_item::new -var_hash [array get var_hash]]
	} err_msg]} {
	    if {$ns_write_p} { ns_write "<li><font color=red>Error: Creating new conf_item:<br><pre>$err_msg</pre></font>\n" }
	    continue	    
	}
    } else {
	if {$ns_write_p} { ns_write "<li>Conf_Item already exists: name='$conf_item_name', nr='$conf_item_nr', id='$conf_item_id'\n" }

	# Make sure to use the right code, which is unique system wide
	db_1row conf_item_info "
		select	conf_item_code
		from	im_conf_items
		where	conf_item_id = :conf_item_id       
	"
    }

    if {$ns_write_p} { ns_write "<li>Going to update the conf_item.\n" }
    if {[catch {
	db_dml update_conf_item "
		update im_conf_items set
			conf_item_name		= :conf_item_name,
			conf_item_nr		= :conf_item_nr,
			conf_item_code		= :conf_item_code,
			conf_item_parent_id	= :conf_item_parent_id,
			conf_item_status_id	= :conf_item_status_id,
			conf_item_type_id	= :conf_item_type_id,
			conf_item_owner_id	= :conf_item_owner_id,
			note			= :note,
			description		= :description
		where
			conf_item_id = :conf_item_id
	"
    } err_msg]} {
	if {$ns_write_p} { ns_write "<li><font color=red>Error: Error updating conf_item:<br><pre>$err_msg</pre></font>" }
	continue	    
    }

    # Add the conf_item lead to the list of conf_item members
    if {"" != $conf_item_owner_id} {
	set role_id [im_biz_object_role_full_member]
	im_biz_object_add_role $conf_item_owner_id $conf_item_id $role_id
    }


    if {"" != $conf_item_project_id} {
	if {$ns_write_p} { ns_write "<li>Adding to project #$conf_item_project_id.\n" }
	im_conf_item_new_project_rel -project_id $conf_item_project_id -conf_item_id $conf_item_id
    }
    

    # -------------------------------------------------------
    # Import DynFields    
    set conf_item_dynfield_updates {}
    set task_dynfield_updates {}
    array unset attributes_hash
    array set attributes_hash {}
    db_foreach store_dynfiels $dynfield_sql {
	ns_log Notice "import-im_conf_item: name=$attribute_name, otype=$object_type, table=$table_name"

	# Avoid storing attributes multipe times into the same table.
	# Sub-types can have the same attribute defined as the main type, so duplicate
	# DynField attributes are OK.
	set key "$attribute_name-$table_name"
	if {[info exists attributes_hash($key)]} {
	    ns_log Notice "import-im_conf_item: name=$attribute_name already exists."
	    continue
	}
	set attributes_hash($key) $table_name

	switch $table_name {
	    im_conf_items {
		lappend conf_item_dynfield_updates "$attribute_name = :$attribute_name"
	    }
	    default {
		ad_return_complaint 1 "<b>Dynfield Configuration Error</b>:<br>
		Attribute='$attribute_name' in table='$table_name' is not in im_conf_items."
	    }
	}
    }

    if {$ns_write_p} { ns_write "<li>Going to update im_conf_item DynFields.\n" }
    if {"" != $conf_item_dynfield_updates} {
	set conf_item_update_sql "
		update im_conf_items set
		[join $conf_item_dynfield_updates ",\n\t\t"]
		where conf_item_id = :conf_item_id
	"
	if {[catch {
	    db_dml conf_item_dynfield_update $conf_item_update_sql
	} err_msg]} {
	    if {$ns_write_p} { ns_write "<li><font color=brown>Warning: Error updating im_conf_item dynfields:<br><pre>$err_msg</pre></font>" }
	}
    }

    if {$ns_write_p} { ns_write "<li>Going to write audit log.\n" }
    im_audit -object_id $conf_item_id

}


if {$ns_write_p} {
    ns_write "</ul>\n"
    ns_write "<p>\n"
    ns_write "<A HREF=$return_url>Return to Conf_Item Page</A>\n"
}

# ------------------------------------------------------------
# Render Report Footer

if {$ns_write_p} {
    ns_write [im_footer]
}


