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
# Parsers that convert a string into SQL format.
# ---------------------------------------------------------------------


ad_proc -public im_csv_import_parser_no_change { 
    {-parser_args "" }
    arg 
} {
    Dummy parser without transformation
} {
    return [list $arg ""]
}


ad_proc -public im_csv_import_parser_user_name {
    {-parser_args "" }
    arg
} {
    Returns a user_id from parties
} {
    if {[regexp {'} $arg match]} {
       set err "Found a email (email) with single quote, consider removing single quotes from emails"
       im_security_alert -location "im_csv_import_parser_user_name" -message $err -value $arg
       return [list $arg $err]
    }

    set user_id ""
    set err ""

    # Check by email
    if {"" eq $user_id} {
	set sql "
	        select  min(party_id)
	        from    parties p
	        where   lower(p.email) = lower('$arg')
	"
	set user_id [db_string user_id_from_email $sql -default ""]
    }

    # Check by (Windows) username 
    if {"" eq $user_id} {
	set user_id [db_string user_id_from_username "
		select	min(user_id)
		from	users
		where	lower(trim(username)) = lower(trim(:arg))
	" -default ""]
    }

    # Check by full first + last name
    if {"" == $user_id} {
	set user_id [db_string user_id_from_first_last_name "
		select	min(person_id)
		from	persons
		where	lower(trim(im_name_from_user_id(person_id))) = lower(trim(:arg))
	" -default ""]
    }

    if {"" == $user_id} { set err "Didn't find user with email, username or full name ='$arg'" }
    return [list $user_id $err]
}


ad_proc -public im_csv_import_parser_company_name { 
    {-parser_args "" }
    arg 
} {
    Returns a company_id from im_companies
} {
    if {[regexp {'} $arg match]} { 
       set err "Found a company name ($arg) with single quote, consider removing single quotes from companies"
       im_security_alert -location "im_csv_import_parser_company_name" -message $err -value $arg 
       return [list $arg $err]
    }

    set sql "
	select	min(c.company_id)
	from	im_companies c
	where	(c.company_name = '$arg' OR c.company_path = '$arg')
    "
    set company_id [db_string company_id_from_name $sql -default ""]
    set err ""
    if {"" == $company_id} { set err "Didn't find company with company_name ='$arg'" }
    return [list $company_id $err]
}

ad_proc -public im_csv_import_parser_office_name { 
    {-parser_args "" }
    arg 
} {
    Returns a office_id from im_companies
} {
    if {[regexp {'} $arg match]} { 
       set err "Found a office name ($arg) with single quote, consider removing single quotes from companies"
       im_security_alert -location "im_csv_import_parser_office_name" -message $err -value $arg 
       return [list $arg $err]
    }

    set sql "
	select	min(o.office_id)
	from	im_offices o
	where	(o.office_name = '$arg' OR o.office_path = '$arg')
    "
    set office_id [db_string office_id_from_name $sql -default ""]
    set err ""
    if {"" == $office_id} { set err "Didn't find office with office_name ='$arg'" }
    return [list $office_id $err]
}

ad_proc -public im_csv_import_parser_project_nr { 
    {-parser_args "" }
    arg 
} {
    Returns a project_id from project_nr
} {
    if {[regexp {'} $arg match]} { 
       set err "Found a Project Nr with single quote"
       im_security_alert -location "im_csv_import_parser_project_nr" -message $err -value $arg 
       return [list $arg $err]
    }

    set sql "
	select	min(p.project_id)
	from	im_projects p
	where	p.parent_id is null and
		p.project_nr = '$arg'
    "
    set project_id [db_string project_id_from_nr $sql -default ""]
    set err ""
    if {"" == $project_id} { set err "Didn't find project with project_nr='$arg'" }
    return [list $project_id $err]
}


ad_proc -public im_csv_import_parser_project_name { 
    {-parser_args "" }
    arg 
} {
    Returns a project_id from project_name
} {
    if {[regexp {'} $arg match]} { 
       set err "Found a Project Nr with single quote"
       im_security_alert -location "im_csv_import_parser_project_name" -message $err -value $arg 
       return [list $arg $err]
    }

    set sql "
	select	min(p.project_id)
	from	im_projects p
	where	p.parent_id is null and
		p.project_name = '$arg'
    "
    set project_id [db_string project_id_from_name $sql -default ""]
    set err ""
    if {"" == $project_id} { set err "Didn't find project with project_name='$arg'" }
    return [list $project_id $err]
}



ad_proc -public im_csv_import_parser_date { 
    {-parser_args "" }
    arg 
} {
    Generic date parser - front-end for all available date formats
} {
    set result [im_csv_import_parser_date_iso -parser_args $parser_args $arg]
    if {"" eq [lindex $result 1]} { return $result }

    set result [im_csv_import_parser_date_european -parser_args $parser_args $arg]
    if {"" eq [lindex $result 1]} { return $result }

    set result [im_csv_import_parser_date_european_slashes -parser_args $parser_args $arg]
    if {"" eq [lindex $result 1]} { return $result }

    set result [im_csv_import_parser_date_american -parser_args $parser_args $arg]
    if {"" eq [lindex $result 1]} { return $result }

    return [list "" "Could not figure out the format of this data field '$arg'"]
}

ad_proc -public im_csv_import_parser_boolean { 
    {-parser_args "" }
    arg 
} {
    Boolean - argument is mapped to SQL boolean: 't' or 'f'
} {
    set arg [string tolower [string trim $arg]]
    switch $arg {
	"" { return [list "" ""] }
	"t" - "1" { return [list "t" ""] }
	"f" - "0" { return [list "f" ""] }
    }
    return [list "" "Could not determine boolean value of arg='$arg'"]
}


ad_proc -public im_csv_import_parser_date_european { 
    {-parser_args "" }
    arg 
} {
    Parses a European date format like '08.06.2011' as the 8th of June, 2011
} {
    if {[regexp {^(.+)\.(.+)\.(....)$} $arg match dom month year]} { 
	if {1 == [string length $dom]} { set dom "0$dom" }
	if {1 == [string length $month]} { set dom "0$month" }
	return [list "$year-$month-$dom" ""] 
    }
    return [list "" "Error parsing European date format '$arg': expected 'dd.mm.yyyy'. If the error remains, try to import ANSI dates (2015-01-01) and set parser to 'No change'"]
}


ad_proc -public im_csv_import_parser_date_european_slashes { 
    {-parser_args "" }
    arg 
} {
    Parses a European date format like '08/06/2011' as the 8th of June, 2011
} {
    if {[regexp {^(.+)/(.+)/(....)$} $arg match dom month year]} { 
	if {1 == [string length $dom]} { set dom "0$dom" }
	if {1 == [string length $month]} { set dom "0$month" }
	return [list "$year-$month-$dom" ""] 
    }
    return [list "" "Error parsing European date format '$arg': expected 'dd/mm/yyyy'"]
}

ad_proc -public im_csv_import_parser_date_iso { 
    {-parser_args "" }
    arg 
} {
    Parses ISO date format like '2011-06-08' as the 8th of June, 2011
} {
    if {[regexp {^(....)\-(.+)\-(.+)$} $arg match year month dom]} { 
	if {1 == [string length $dom]} { set dom "0$dom" }
	if {1 == [string length $month]} { set dom "0$month" }
	return [list "$year-$month-$dom" ""] 
    }
    return [list "" "Error parsing ISO '$arg': expected 'yyyy-mm-dd'"]
}


ad_proc -public im_csv_import_parser_date_american { 
    {-parser_args "" }
    arg 
} {
    Parses a American date format like '12/31/2011' as the 31st of December, 2011
} {
    if {[regexp {^(.+)\/(.+)\/(....)$} $arg match month dom year]} { 
	if {1 == [string length $dom]} { set dom "0$dom" }
	if {1 == [string length $month]} { set dom "0$month" }
	return [list "$year-$month-$dom" ""] 
    }
    return [list "" "Error parsing American date format '$arg': expected 'dd.mm.yyyy'"]
}


ad_proc -public im_csv_import_parser_number {
    {-parser_args "" }
    arg 
} {
    Parses a generic number. 
    There may be ambiguities between American and European number formats
    with decimal and thousands separators
} {
    set divisor 1
    if {[regexp {^(.+)%$} $arg match number]} {
	set divisor 100
	set arg $number
    }

    if {[string is integer $arg]} { 
	return [list [expr $arg / $divisor] ""] 
    }
    # Now we know that there is a "." or a "," in the number

    # Check for a number with one or two decimal digits
    if {[regexp {^([0-9\.\,]*)([\.\,])([0-9]{1,2})$} $arg match main separator fraction]} {
	if {"." eq $separator} {
	    # American number format - remove "," from the main part of the number
	    set main [string map -nocase {"," ""} $main]
	    if {[string is integer $main]} { 
		return [list [expr "$main.$fraction" / $divisor] ""] 
	    }
	    # "$main" is not an integer - no idea what is is...
	} else {
	    # European number format - remove "." from the main part of the number
	    set main [string map -nocase {"." ""} $main]
	    if {[string is integer $main]} { 
		return [list [expr "$main.$fraction" / $divisor] ""] 
	    }
	    # "$main" is not an integer - no idea what is is...
	}
	return [list [expr "$main.$fraction" / $divisor] ""]
    }

    return [list 0 "Could not decide if this is a European or a US number - please use a specific parser"]
}

ad_proc -public im_csv_import_parser_number_european {
    {-parser_args "" }
    arg 
} {
    Parses a European number format like '20.000,00' as twenty thousand 
} {
    set result [string map -nocase {"." ""} $arg]
    set result [string map -nocase {"," "."} $result]
    return [list $result ""]
}


ad_proc -public im_csv_import_parser_number_american {
    {-parser_args "" }
    arg 
} {
    Parses a European number format like '20.000,00' as twenty thousand 
} {
    set result [string map -nocase {"," ""} $result]
    return [list $result ""]
}


ad_proc -public im_csv_import_parser_category { 
    {-parser_args "" }
    arg 
} {
    Parses a category into a category_id
} {
    # Empty input - empty output
    if {"" == $arg} { return [list "" ""] }

    # Parse the category
    set result [im_id_from_category $arg $parser_args]

    if {"" == $result} {
	return [list "" "Category parser: We did not find a value='$arg' in category type '$parser_args'."]
    } else {
	return [list $result ""]
    }
}

ad_proc -public im_csv_import_parser_cost_center { 
    {-parser_args "" }
    arg 
} {
    Parses a cost center into a cost_center_id
} {
    # Empty input - empty output
    if {"" == $arg} { return [list "" ""] }

    # Parse the category
    set arg [string trim [string tolower $arg]]
    set ccids [db_list ccid1 "
	select	cost_center_id
	from	im_cost_centers
	where	lower(cost_center_code) = :arg OR 
		lower(cost_center_label) = :arg OR 
		lower(cost_center_name) = :arg order by cost_center_id
    "]
    set result [lindex $ccids 0]
    if {"" == $result} {
	return [list "" "Cost Center parser: We did not find any cost center with label, code or name matching the value='$arg'."]
    } else {
	return [list $result ""]
    }
}


ad_proc -public im_csv_import_parser_material { 
    {-parser_args "" }
    arg 
} {
    Parses a material name or nr into a material_id
} {
    # Empty input - empty output
    if {"" == $arg} { return [list "" ""] }

    # Parse the category
    set arg [string trim [string tolower $arg]]
    set ccids [db_list ccid1 "
	select	material_id
	from	im_materials
	where	lower(material_nr) = :arg OR 
		lower(material_name) = :arg 
	order by material_id
    "]
    set result [lindex $ccids 0]
    if {"" == $result} {
	return [list "" "Material parser: We did not find any material nr or name matching the value='$arg'."]
    } else {
	return [list $result ""]
    }
}



ad_proc -public im_csv_import_parser_hard_coded { 
    {-parser_args "" }
    arg 
} {
   Empty parser - returns the argument
} {
    return [list $arg ""]
}


ad_proc -public im_csv_import_parser_project_parent_nrs { 
    {-parser_args "" }
    arg 
} {
    Returns a project_id from a list of project_nr's
} {
    set arg [string tolower [string trim $arg]]
    set parent_id ""

    # Loop through the list of parent_nrs
    foreach parent_nr $arg {

	set parent_sql "parent_id = $parent_id"
	if {"" eq $parent_id} { set parent_sql "parent_id is null" }
	set project_id [db_string pid "select project_id from im_projects where $parent_sql and lower(project_nr) = :parent_nr" -default ""]
	if {"" eq $project_id} {
	    return [list "" "Didn't find project with project_nr='$parent_nr' and parent_id='$parent_id'"]
	}
	set parent_id $project_id
    }
    return [list $parent_id ""]
}


ad_proc -public im_csv_import_parser_conf_item_parent_nrs { 
    {-parser_args "" }
    arg 
} {
    Returns a project_id from a list of project_nr's
} {
    set arg [string tolower [string trim $arg]]
    set parent_id ""

    # Loop through the list of parent_nrs
    foreach parent_nr $arg {

	set parent_sql "conf_item_parent_id = $parent_id"
	if {"" eq $parent_id} { set parent_sql "conf_item_parent_id is null" }
	set project_id [db_string pid "select conf_item_id from im_conf_items where $parent_sql and lower(conf_item_nr) = :parent_nr" -default ""]
	if {"" eq $project_id} {
	    return [list "" "Didn't find conf_item with conf_item_nr='$parent_nr' and parent_id='$parent_id'"]
	}
	set parent_id $project_id
    }
    return [list $parent_id ""]
}
