# /packages/intranet-csv-import/www/import-im_expense_bundle.tcl
#
# ToDo:
# 	- provider_name not shown in expense_bundle 

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
    { overwrite_existing_expense_bundles_p 0 }
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

set default_currency [im_parameter -package_id [im_package_cost_id] "DefaultCurrency" "" "EUR"]

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
		aa.object_type in ('im_invoice') and
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
set old_cost_name ""
foreach csv_line_fields $values_list_of_lists {


    incr cnt

    if {$ns_write_p} { ns_write "</ul><hr><ul>\n" }
    if {$ns_write_p} { ns_write "<li>Starting to parse line $cnt\n" }

    # im_costs values
    set cost_name		""
    set cost_nr			""
    set effective_date          ""
    set expense_currency        ""
    set cost_type_id            ""
    set cost_type		""
    set cost_status_id		""
    set cost_status		""
    set amount			""
    set vat			""
    set customer_name		""
    set customer_id		""
    set provider_name		""
    set provider_id		""
    set project_id 		""
    set bundle_id_old 		""

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
	ns_log notice "import-im_invoice: varname([lindex $header_fields $j]) = $var_name"

	set var_value [string trim [lindex $csv_line_fields $j]]
	set var_value [string map -nocase {"\"" "'" "\[" "(" "\{" "(" "\}" ")" "\]" ")"} $var_value]
	if {"NULL" eq $var_value} { set var_value ""}

	# replace unicode characters by non-accented characters
	# Watch out! Does not work with Latin-1 characters
	set var_name [im_mangle_unicode_accents $var_name]

	set cmd "set $var_name \"$var_value\""
	ns_log Notice "import-im_invoice: cmd=$cmd"
	set result [eval $cmd]
    }

    # -------------------------------------------------------
    # Transform the variables
    set i 0
    foreach varname $var_name_list {
	set p $parser($i)
	set p_args $parser_args($i)
	set target_varname $map($i)
	ns_log Notice "import-im_invoice: Parser: $varname -> $target_varname"

	set proc_name "im_csv_import_parser_$p"
	if {[catch {
	    set val [set $varname]
	    if {"" != $val} {
		set result [$proc_name -parser_args $p_args $val]
		set res [lindex $result 0]
		set err [lindex $result 1]
		ns_log Notice "import-im_invoice: Parser: '$p -args $p_args $val' -> $target_varname=$res, err=$err"
		if {"" != $err} {
		    if {$ns_write_p} { 
			ns_write "<li><font color=brown>Warning: Error parsing field='$target_varname' using parser '$p':<pre>$err</pre></font>\n</li>" 
		    }
		}
		set $target_varname $res
	    }
	} err_msg]} {
	    if {$ns_write_p} { 
		ns_write "<li><font color=brown>Warning: Error parsing field='$target_varname' using parser '$p':<pre>$err_msg</pre></font></li>" 
	    }
	}
	incr i
    }

    # ################################################## 
    # Validation 
    # 

    if {$ns_write_p} { ns_write "<li>Now validating cost: $expense_name </li>\n" }

    # Check if the cost already exists
    set cost_id [db_string cost_id "select cost_id from im_costs where lower(trim(cost_name)) = lower(trim(:expense_name))" -default ""]
    if { "" ne $cost_id && !$overwrite_existing_expense_bundles_p } {
        if {$ns_write_p} {
            ns_write "<li><font color=red>Error: We have found an Expense Bundle named '$expense_name' and will not overwrite any of attributes.<br>Skipped record</font>\n</li>"
        }
        continue
    }

    # expense_name needs to be there
    if {"" == $expense_name} {
	if {$ns_write_p} {
	    ns_write "<li><font color=red>Error: We have found an empty 'Cost Name' in line $cnt.<br>
	        Skipped record. Please correct the CSV file. Every costs needs to have a unique Cost Name.</font>\n</li>"
	}
	continue
    }

    # We expect Expense Bundles only! 
    if { [im_cost_type_expense_bundle] != $cost_type_id } {
	if {$ns_write_p} {
	    ns_write "<li><font color=red>Error: We have found a cost type that is different from 3722 (Expense Bundles)<br>
	        Skipped record - please correct the CSV file.</font>\n</li>"
	}
	continue
    }

    # cost_nr needs to be there
    if {"" eq $cost_nr} {
	set cost_nr [regsub {[^a-z0-9_]} [string trim [string tolower $expense_name]] "_"]
    }

    # cost_type needs to be there
    if {"" == $cost_type_id} {
	if {$ns_write_p} { 
	    ns_write "<li><font color=red>Error: We have found an empty 'Cost Type' in line $cnt.<br>
	        Skipped record. Please correct the CSV file.</font>\n"
	}
	continue
    }

    # Status is optional
    if {"" == $cost_status_id} {
	if {$ns_write_p} { ns_write "<li><font color=brown>Warning: Didn't find cost status '$cost_status', using default status 'Created'</font>\n</li>" }
	set cost_status_id [im_cost_status_created]
    }

    # Amount 
    if {"" == $amount} {
	if {$ns_write_p} { ns_write "<li><font color=red>Error: Didn't find a value for expense amount. Skipping record.</font>\n</li>" }
	continue
    }    

    # VAT
    if { "" eq $vat } {
	if {$ns_write_p} { ns_write "<li><font color=brown>Warning: Didn't find a value for VAT, setting VAT to '0'</font>\n</li>" }
	set vat 0
    }
    
    # Customer and provider are required
    if {"" == $provider_id} {
	if {[im_category_is_a $cost_type_id [im_cost_type_customer_doc]]} { set provider_id [im_company_internal] }
    }
    if {"" == $customer_id} {
	if {[im_category_is_a $cost_type_id [im_cost_type_provider_doc]]} { set customer_id [im_company_internal] }
    }
    if {"" == $provider_id} {
	if {$ns_write_p} { 
	    ns_write "<li><font color=red>Error: We have found an empty 'Provider' in line $cnt.<br>
	        Skipped record. Please correct the CSV file.</font>\n"
	}
	continue
    }

    # Customer ID 
    if {"" == $customer_id} {
	if {$ns_write_p} { 
	    ns_write "<li><font color=red>Error: We have found an empty 'Customer' in line $cnt.<br>
	        Skipped record. Please correct the CSV file.</font>\n"
	}
	continue
    }

    # Currency 
    if {"" eq $expense_currency} { 
	if {$ns_write_p} { ns_write "<li><font color=brown>Warning: Didn't find currency, using default currency='$default_currency'</font>\n" }
	set expense_currency $default_currency
    }

    # -------------------------------------------------------
    # Create a new cost if necessary
    if {"" == $cost_id} {
	if {$ns_write_p} { ns_write "<li><font color=green>Going to create cost: name='$expense_name'</font></li>" }

	if {[catch {
	    set cost_id [db_string new_cost "
		select im_cost__new(
			null, 
			'im_expense_bundle', 
			now()::timestamptz,	
			:current_user_id::integer, 
			'[ad_conn peeraddr]', null,

			:expense_name,			-- ?Unique? name of cost
			null, 		    		-- parent_id (?)
			:project_id,			-- cost container project
			:customer_id,			-- who will receive the money?
			:provider_id,			-- who pays?
			:bundle_id_old,			-- investment_id (we use this column to map expense-bundles with expense_items

			:cost_status_id,		-- active or inactive or for WF stages
			:cost_type_id,			-- user defined type of cost. Determines WF.
			null,				-- template_id

			:effective_date,		-- 
			null,				--
			:amount,			--
			:expense_currency,			--
			:vat,				--
			null,				--

			'f',				-- variable_p
			'f',				-- needs_redistribution_p,
			'f',				-- redistributed_p,
			'f',				-- planning_p,
			null,				-- planning_type_id

			:note,				-- note
			''				-- description
		)
	    "]

	} err_msg]} {
	    if {$ns_write_p} { ns_write "<li><font color=red>Error: Creating new financial document:<br><pre>$err_msg</pre></font>\n" }
	    continue
	}

	# Write Audit Trail
	im_audit -object_id $cost_id -action after_create

    } else {
	if {$ns_write_p} { ns_write "<li>Cost already exists: name='$cost_name', nr='$cost_nr', id='$cost_id', overwriting with new attributes.</li>\n" }
	if {[catch {
	    db_dml update_cost "
		update im_costs set
			cost_name		= :expense_name,
			cost_nr			= :cost_nr,
			project_id		= :project_id,
			customer_id		= :customer_id,
			provider_id		= :provider_id,
			cost_status_id		= :cost_status_id,
			cost_type_id		= :cost_type_id,
			effective_date		= :effective_date,
			amount			= :amount,
			currency		= :expense_currency,
			vat			= :vat,
			note			= :note
		where
			cost_id = :cost_id
		"
	} err_msg]} {
	    if {$ns_write_p} { ns_write "<li><font color=red>Error: Error updating cost:<br><pre>$err_msg</pre></font>" }
	    continue	    
	}
    }

    # -------------------------------------------------------
    # Import DynFields    
    set cost_dynfield_updates {}
    set task_dynfield_updates {}
    array unset attributes_hash
    array set attributes_hash {}
    db_foreach store_dynfiels $dynfield_sql {
	ns_log Notice "import-im_invoice: name=$attribute_name, otype=$object_type, table=$table_name"

	# Avoid storing attributes multipe times into the same table.
	# Sub-types can have the same attribute defined as the main type, so duplicate
	# DynField attributes are OK.
	set key "$attribute_name-$table_name"
	if {[info exists attributes_hash($key)]} {
	    ns_log Notice "import-im_invoice: name=$attribute_name already exists."
	    continue
	}
	set attributes_hash($key) $table_name

	switch $table_name {
	    im_costs {
		lappend cost_dynfield_updates "$attribute_name = :$attribute_name"
	    }
	    default {
		ad_return_complaint 1 "<b>Dynfield Configuration Error</b>:<br>
		Attribute='$attribute_name' in table='$table_name' is not in im_costs."
	    }
	}
    }

    if {$ns_write_p} { ns_write "<li>Going to update im_cost DynFields.\n" }
    if {"" != $cost_dynfield_updates} {
	set cost_update_sql "
		update im_costs set
		[join $cost_dynfield_updates ",\n\t\t"]
		where cost_id = :cost_id
	"
	if {[catch {
	    db_dml cost_dynfield_update $cost_update_sql
	} err_msg]} {
	    if {$ns_write_p} { ns_write "<li><font color=brown>Warning: Error updating im_cost dynfields:<br><pre>$err_msg</pre></font>" }
	}
    }

    if {$ns_write_p} { ns_write "<li>Going to write audit log.\n" }
    im_audit -object_id $cost_id

}


if {$ns_write_p} {
    ns_write "</ul>\n"
    ns_write "<p>\n"
    ns_write "<A HREF=$return_url>Return to CSV Import page</A>\n"
}

# ------------------------------------------------------------
# Render Report Footer

if {$ns_write_p} {
    ns_write [im_footer]
}


