# /packages/intranet-cvs-import/tcl/intranet-cvs-import-procs.tcl
#
# Copyright (C) 2011 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

ad_library {
    @author frank.bergmann@project-open.com
}

# ---------------------------------------------------------------------
# Object type specific default mapping for built-in ]po[ attributes
# This list only contains the mappings of hard-coded fields etc.
# Each entry consists of:
# - attribute name / table column name
# - Pretty name
# - Parser
# - Parser arguments (important for im_category type)
# ---------------------------------------------------------------------

ad_proc -public im_csv_import_guess_im_project { } {} {
    set mapping {
	{parent_id "Parent Nrs" project_parent_nrs ""}
	{company_id "Customer Name" company_name ""}
	{start_date "Start Date" date ""}
	{end_date "end Date" date ""}
	{percent_completed "Percent Completed" number ""}
	{project_budget "Budget" number ""}
	{project_budget_hours "Budget Hours" number ""}
    }
    return $mapping
}

ad_proc -public im_csv_import_guess_im_risk { } {} {
    set mapping {
	{risk_name "Risk Name" no_change ""}
	{risk_project_id "Project" project_nr ""}
	{risk_status_id "Status" category "Intranet Risk Status"}
	{risk_type_id "Type" category "Intranet Risk Type"}
	{risk_description "Description" no_change ""}
	{risk_impact "Impact" number ""}
	{risk_probability_percent "Probability" number ""}
    }
    return $mapping
}

# ---------------------------------------------------------------------
# Available Parsers
# ---------------------------------------------------------------------

ad_proc -public im_csv_import_parsers {
    -object_type:required
} {
    Returns the list of available parsers
} {
    switch $object_type {
	im_project - im_company - im_conf_item - im_risk - im_timesheet_task - im_ticket - im_hour {
	    set parsers {
		no_change		"No Change"
		hard_coded		"Hard Coded Functionality"
		boolean		        "Boolean"
		date		        "Date (generic)"
		date_european		"Date European (DD.MM.YYYY)"
		date_european_dashes	"Date ISO (YYYY-MM-DD)"
		date_american		"Date US (MM/DD/YYYY)"
		number		        "Number (generic)"
		number_european		"Number European (20.000,00)"
		number_american		"Number US (20,000.00)"
		category		"Category ID from Category Name"
		cost_center		"Cost Center Parser"
		project_nr		"Project from Project Nr"
		project_name		"Project from Project Name"
		project_parent_nrs      "Project from Parent Nrs"
		company_name    	"Company ID from Company Name"
		user_name		"User ID from email, username or full name"
		conf_item_parent_nrs    "Conf Item Parent Nrs"
	    }
	}
	im_membership {
	    set parsers {
		no_change		"No Change"
		hard_coded		"Hard Coded Functionality"
		project_nr		"Project from Project Nr"
		project_name		"Project from Project Name"
		user_name		"User ID from user-email"
	    }
	}
	default {
	    ad_return_complaint 1 "im_csv_import_parsers: Unknown object type '$object_type'"
	    ad_script_abort
	}
    }
    return $parsers
}


# ---------------------------------------------------------------------
# Available Fields per Object Type
# ---------------------------------------------------------------------

ad_proc -public im_csv_import_object_fields {
    -object_type:required
} {
    Returns a list of database columns for the specified object type.
} {

    # Special case: im_hour is not an object
    if { "im_hour" == $object_type } {
	return "project_id project_nr project_nr_path user_id day hours"
    }

    # Special case: membership is not an object
    if { "im_membership" == $object_type } {
	return "project_id project_nr project_nr_path user_id role_id"
    }

    # Get the list of super-types for object_type, including object_type
    # and remove "acs_object" from the list
    set super_types [im_object_super_types -object_type $object_type]
    set s [list]
    foreach t $super_types {
	if {$t eq "acs_object"} { continue }
	lappend s $t
    }
    set super_types $s

    # ---------------------------------------------------------------
    # Get the list of tables associated with the object type and its super types

    set tables_sql "
	select	*
	from	(
		select	table_name, id_column, 1 as sort_order
		from	acs_object_types
		where	object_type in ('[join $super_types "', '"]')
	UNION
		select	table_name, id_column, 2 as sort_order
		from	acs_object_type_tables
		where	object_type in ('[join $super_types "', '"]')
		) t
	order by t.sort_order
    "

    set columns_sql "
	select	lower(column_name) as column_name
	from	user_tab_columns
	where	lower(table_name) = lower(:table_name)
    "

    set selected_columns {}
    set selected_tables {}
    set cnt 0
    db_foreach tables $tables_sql {
	if {[lsearch $selected_tables $table_name] >= 0} { 
	    ns_log Notice "im_csv_import_object_fields: found duplicate table: $table_name"
	    continue 
	}
	db_foreach columns $columns_sql {
	    if {[lsearch $selected_columns $column_name] >= 0} { 
		ns_log Notice "im_csv_import_object_fields: found ambiguous field: $table_name.$column_name"
		continue 
	    }
	    lappend selected_columns $column_name
	}

	lappend selected_tables $table_name
	incr cnt
    }
    return [lsort $selected_columns]
}






# ---------------------------------------------------------------------
# Guess the most probable object field (DynField) for a column
# ---------------------------------------------------------------------

ad_proc -public im_csv_import_guess_map {
    -object_type:required
    -field_name:required
    {-sample_values {}}
} {
    Returns the best guess for a DynField for the field.
    We check three options:
    <ul>
    <li>Manual override static mapping: Manually defined
    <li>Attribute Name: Table column name with underscores ("project_name")
    <li>Pretty Name: English pretty name of column ("Project Name")
    <li>
} {
    set field_name_lower [string tolower $field_name]
    ns_log Notice "im_csv_import_guess_map: trying to guess attribute_name for field_name=$field_name_lower"
    im_security_alert_check_alphanum -location "im_csv_import_guess_map: object_type" -value $object_type


    # Check for manual override static mapping
    set static_mapping_lol {}
    catch { set static_mapping_lol [im_csv_import_guess_$object_type] }
    ns_log Notice "im_csv_import_guess_map: static_mapping=$static_mapping_lol"
    foreach tuple $static_mapping_lol {
	set attribute_name [lindex $tuple 0]
	set pretty_name [lindex $tuple 1]
	set parser [lindex $tuple 2]
	set parser_args [lindex $tuple 3]
	if {$field_name_lower == [string tolower $pretty_name]} {
	    ns_log Notice "im_csv_import_guess_map: found statically encoded match with field_name=$field_name"
	    return $attribute_name
	}
    }


    set dynfield_sql "
	select  lower(aa.attribute_name) as attribute_name,
		lower(aa.pretty_name) as pretty_name,
		w.widget as tcl_widget,
		w.widget_name as dynfield_widget
	from	im_dynfield_attributes a,
		im_dynfield_widgets w,
		acs_attributes aa
	where	a.widget_name = w.widget_name and 
		a.acs_attribute_id = aa.attribute_id and
		aa.object_type = '$object_type'
	order by aa.sort_order, aa.attribute_id
    "

    # Check if the header name is the attribute_name of a DynField
    set dynfield_attribute_names [util_memoize [list db_list otype_dynfields "select attribute_name from ($dynfield_sql) t"]]
    ns_log Notice "im_csv_import_guess_map: attribute_names=$dynfield_attribute_names"
    if {[lsearch $dynfield_attribute_names $field_name_lower] >= 0} {
	ns_log Notice "im_csv_import_guess_map: found attribute_name match with field_name=$field_name"
	return $field_name_lower
    }

    # Check for a pretty_name of a DynField
    set dynfield_pretty_names [util_memoize [list db_list otype_dynfields "select pretty_name from ($dynfield_sql) t"]]
    ns_log Notice "im_csv_import_guess_map: pretty_names=$dynfield_pretty_names"
    set idx [lsearch $dynfield_pretty_names $field_name_lower]
    if {$idx >= 0} {
	ns_log Notice "im_csv_import_guess_map: found pretty_name match with field_name=$field_name"
	return [lindex $dynfield_attribute_names $idx]
    }

    ns_log Notice "im_csv_import_guess_map: Did not find any match with a DynField for field_name=$field_name"
    ns_log Notice "im_csv_import_guess_map:"
    return ""
}



# ---------------------------------------------------------------------
# Guess the most appropriate parser for a column
# ---------------------------------------------------------------------

ad_proc -public im_csv_import_guess_parser {
    {-sample_values {}}
    -object_type:required
    -field_name:required
} {
    Returns the best guess for a parser for the given field as
    a list with:
    <ul>
    <li>The parser name,
    <li>the parser args and
    <li>the field name to map to
    </ul>
} {
    # --------------------------------------------------------
    # Check for static mapping
    set field_name_lower [string tolower $field_name]
    set static_mapping_lol {}
    catch { set static_mapping_lol [im_csv_import_guess_$object_type] }


    ns_log Notice "im_csv_import_guess_parser: static_mapping=$static_mapping_lol"
    foreach tuple $static_mapping_lol {
	set attribute_name [lindex $tuple 0]
	set pretty_name [lindex $tuple 1]
	set parser [lindex $tuple 2]
	set parser_args [lindex $tuple 3]

	if {$field_name_lower eq [string tolower $pretty_name] || $field_name_lower eq [string tolower $attribute_name]} {
	    ns_log Notice "im_csv_import_guess_parser: found statically encoded match with field_name=$field_name"
	    return [list $parser $parser_args $attribute_name]
	}
    }

    # --------------------------------------------------------
    # Date parsers
    #
    # Abort if there are not enough values
    if {[llength $sample_values] >= 1} { 
	set date_european_p 1
	set date_american_p 1
	set number_plain_p 1
	set number_european_p 1
	set number_american_p 1
	
	# set the parserst to 0 if one of the values doesn't fit
	foreach val $sample_values { 
	    if {![regexp {^(.+)\.(.+)\.(....)$} $val match]} { set date_european_p 0 } 
	    if {![regexp {^(.+)\/(.+)\/(....)$} $val match]} { set date_american_p 0 } 
	    if {![regexp {^[0-9]+$} $val match]} { set number_plain 0 } 
	}
	
	if {$date_european_p} { return [list "date_european" "" ""] }
	if {$date_american_p} { return [list "date_american" "" ""]}
    }


    # --------------------------------------------------------
    # Get the list of super-types for object_type, including object_type
    # and remove "acs_object" from the list
    set super_types [im_object_super_types -object_type $object_type]
    set s [list]
    foreach t $super_types {
	if {$t eq "acs_object"} { continue }
	lappend s $t
    }
    set super_types $s

    ns_log Notice "im_csv_import_guess_parser: field_name=$field_name, super_types=$super_types"

    # --------------------------------------------------------
    # Parsing for DynFields
    #
    # There can be 0, 1 or multiple dynfields with the field_name,
    # unfortunately.
    set dynfield_sql "
	select	dw.widget as tcl_widget,
		dw.parameters as tcl_widget_parameters,
		substring(dw.parameters from 'category_type \"(.*)\"') as category_type,
		aa.attribute_name
	from	acs_attributes aa,
		im_dynfield_attributes da,
		im_dynfield_widgets dw
	where	aa.object_type in ('[join $super_types "','"]') and
		aa.attribute_id = da.acs_attribute_id and
		da.widget_name = dw.widget_name and
		(lower(aa.attribute_name) = lower(trim(:field_name)) OR
		lower(aa.attribute_name) = lower(trim(:field_name))||'_id'
		)
    "
    set result [list "" "" ""]
    set ttt_widget ""
    db_foreach dynfields $dynfield_sql {
	set ttt_widget $tcl_widget
	switch $tcl_widget {
	    "im_category_tree" {
		set result [list "category" $category_type $attribute_name]
	    }
	    "im_cost_center_tree" {
		set result [list "cost_center" "" $attribute_name]
	    }
	    "checkbox" {
		set result [list "boolean" "" $attribute_name]
	    }
	    "date" {
		set result [list "date" "" $attribute_name]
	    }
	    default {
		# Default: No specific parser
		# text, richtext, textare -> no change (ToDo: quoting?)
		# radio, select generic_sql -> custom
		set result [list "" "" $attribute_name]
	    }
	}
    }
    ns_log Notice "im_csv_import_guess_parser: field_name=$field_name, tcl_widget=$ttt_widget => $result"
    return $result
}



# ---------------------------------------------------------------------
# 
# ---------------------------------------------------------------------

ad_proc -public im_csv_import_check_list_of_lists {
    lol
} {
    Check that the parameter is a list of lists with all
    lines having the same length.
    Returns a HTML string of LI error messages or an emtpy
    string if there was no issue.
} {
    set length_list [list]
    set min_length 1000
    set max_length 0
    set result ""
    foreach line $lol {
	set length [llength $line]
	if {$length > $max_length} { set max_length $length }
	if {$length < $min_length} { set min_length $length }
	lappend length_list $length
    }

    set ctr 0
    foreach line $lol {
	set length [llength $line]
	if {$length < 4} { 
	    append result "<li>Line #$ctr: Found a (nearly) empty line with only $length columns.\n"
	}
	if {$length < $max_length} { 
	    append result "<li>Line #$ctr: Found a line with $length elements which doesn't match the $max_length width.\n"
	}
	incr ctr
    }

    return $result
}