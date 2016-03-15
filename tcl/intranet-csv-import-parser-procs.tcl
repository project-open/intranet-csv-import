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
       im_security_alert -location "im_csv_import_parser_project_nr" -message $err -value $arg
       return [list $arg $err]
    }

    set sql "
        select  party_id
        from    parties p
        where   lower(p.email) = lower('$arg')
    "
    set party_id [db_string party_id_from_name $sql -default ""]
    set err ""
    if {"" == $party_id} { set err "Didn't find user with email ='$arg'" }
    return [list $party_id $err]
}


ad_proc -public im_csv_import_parser_company_name { 
    {-parser_args "" }
    arg 
} {
    Returns a company_id from im_companies
} {
    if {[regexp {'} $arg match]} { 
       set err "Found a company name ($arg) with single quote, consider removing single quotes from companies"
       im_security_alert -location "im_csv_import_parser_project_nr" -message $err -value $arg 
       return [list $arg $err]
    }

    set sql "
	select	min(c.company_id)
	from	im_companies c
	where	c.company_name = '$arg'
    "
    set company_id [db_string company_id_from_name $sql -default ""]
    set err ""
    if {"" == $company_id} { set err "Didn't find company with company_name ='$arg'" }
    return [list $company_id $err]
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
	where	p.project_nr = '$arg'
    "
    set project_id [db_string project_id_from_nr $sql -default ""]
    set err ""
    if {"" == $project_id} { set err "Didn't find project with project_nr='$arg'" }
    return [list $project_id $err]
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

ad_proc -public im_csv_import_parser_date_european_dashes { 
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
    return [list "" "Error parsing European date format '$arg': expected 'dd/mm/yyyy' ()"]
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

ad_proc -public im_csv_import_parser_hard_coded { 
    {-parser_args "" }
    arg 
} {
   Empty parser - returns the argument
} {
    return [list $arg ""]
}

