# /packages/intranet-csv-import/www/import-im_invoice.tcl
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
    # if {$cnt > 50} { break }

    if {$ns_write_p} { ns_write "</ul><hr><ul>\n" }
    if {$ns_write_p} { ns_write "<li>Starting to parse line $cnt\n" }

    # im_costs values
    set cost_name		""
    set cost_nr			""
    set project_nrs		""
    set project_id		""
    set cost_status		""
    set cost_status_id		""
    set cost_type		""
    set cost_type_id		""
    set cost_center_code	""
    set cost_center_id  	""

    set description		""
    set note			""
    set ip_address		""

    set customer_name		""
    set customer_id		""
    set provider_name		""
    set provider_id		""

    set effective_date		""
    set payment_days		""

    set amount			""
    set paid_amount		""
    set currency		""

    set vat			""
    set tax			""
    set vat_type_id		""
    set cause_object_id		""
    set template_id		""

    # im_invoices values
    set customer_contact	""
    set customer_contact_id	""
    set payment_method		""
    set payment_method_id	""
    set invoice_office          ""
    set invoice_office_id       ""

    # im_invoice_items
    set sort_order              ""
    set item_name               ""
    set item_units              ""
    set item_uom_id             ""
    set price_per_unit          ""
    set item_material_id        ""

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
	
	incr i
    }

    if {$ns_write_p} { ns_write "<li>Before cost_nr: name=$cost_name, nr=$cost_nr</font>\n" }


    # Use the current cost_name in the next line.
    # That's useful for invoice_items right after the respective Financial Document
    if {"" ne $cost_name} { set old_cost_name $cost_name }


    # -------------------------------------------------------
    # Check if the cost already exists

    # Check if we find the same cost by name with it's project.
    set cost_id [db_string cost_id "select cost_id from im_costs where lower(trim(cost_nr)) = lower(trim(:cost_nr))" -default ""]
    if {"" eq $cost_id} {
	set cost_id [db_string cost_id "select cost_id from im_costs where lower(trim(cost_name)) = lower(trim(:cost_name))" -default ""]
    }
    if {$ns_write_p} { ns_write "<li>id=$cost_id, name='$cost_name', nr='$cost_nr'\n" }



    # -------------------------------------------------------
    # Check if we've got an invoice item
    set item_field_count 0
    if {"" ne $item_name} { incr item_field_count }
    if {"" ne $item_units} { incr item_field_count }
    if {"" ne $item_uom_id} { incr item_field_count }
    if {"" ne $price_per_unit} { incr item_field_count }
    # We should get either 1 (cost item) or 5 (line). 
    # Everything else is something incomplete
    if {$item_field_count > 0} {

	# Check for an incomplete line
	if {$item_field_count < 4} {
	    if {$ns_write_p} {
		ns_write "<li><font color=red>Error: We have found line $cnt with data from an invoice line<br>
		including Cost Name, Item name, Item Units, Item UoM and Price per Unit.<br>
		However, some of these required fields are missing. Please complete the line.</font>\n"
	    }
	    continue
	}
	
	# Special logic for invoice_items:
	# If no cost_name was specified, just use the cost_name from the last lin
	if {"" eq $cost_name} { 
	    set cost_name $old_cost_name 
	    set cost_id [db_string cost_id "select cost_id from im_costs where lower(trim(cost_name)) = lower(trim(:cost_name))" -default ""]
	}

	# We've got a complete invoice_item.
	# Check for identity
	if {"" eq $cost_id} {
	    if {$ns_write_p} {
		ns_write "<li><font color=red>Error: We didn't find a financial document to reference</font>\n"
	    }
	    continue
	}

	set item_id [db_string item_id "select min(item_id) from im_invoice_items where invoice_id = :cost_id and item_name = :item_name" -default ""]
	if {"" eq $currency} { set currency [db_string cur "select currency from im_costs where cost_id = :cost_id" -default $default_currency] }
	if {"" eq $sort_order} {
	    # Create a new sort order based on the existing number of invoice_items
	    set sort_order [db_string sort_order "select 1+count(*) from im_invoice_items where invoice_id = :cost_id"]
	}
	if {"" eq $item_id} {
	    # Item doesn't exist yet - insert
	    if {$ns_write_p} { ns_write "<li>Going to create line: cost_name='$cost_name', item_name='$item_name'\n" }
	    db_dml insert_item "
		insert into im_invoice_items (
			item_id,
			invoice_id, sort_order, item_name, item_units, item_uom_id, price_per_unit, item_material_id, currency
		) values (
			nextval('im_invoice_items_seq'),
			:cost_id, :sort_order, :item_name, :item_units, :item_uom_id, :price_per_unit, :item_material_id, :currency
		)
	    "
	} else {
	    # Item already exists - update
	    if {$ns_write_p} { ns_write "<li>Going to update line: cost_name='$cost_name', item_name='$item_name'\n" }
	    db_dml update_item "
		update im_invoice_items set
			invoice_id = :cost_id, 
			sort_order = :sort_order, 
			item_name = :item_name, 
			item_units = :item_units, 
			item_uom_id = :item_uom_id, 
			price_per_unit = :price_per_unit, 
			item_material_id = :item_material_id, 
			currency = :currency
		where
			item_id = :item_id;
	    "
	}

	# Skip the rest of the code dealing with im_invoices
	continue
    }


    # ------------------------------------------------------------------------
    # We have found a line with a normal invoice (quote, invoice, purchase order, ...)
    #


    # -------------------------------------------------------
    # Specific field transformations

    # cost_name needs to be there
    if {"" == $cost_name} {
	if {$ns_write_p} {
	    ns_write "<li><font color=red>Error: We have found an empty 'Cost Name' in line $cnt.<br>
	        Please correct the CSV file. Every costs needs to have a unique Cost Name.</font>\n"
	}
	continue
    }

    # cost_nr needs to be there
    if {"" eq $cost_nr} {
	set cost_nr [regsub {[^a-z0-9_]} [string trim [string tolower $cost_name]] "_"]
    }

    if {"" == $cost_type_id} {
	if {$ns_write_p} { 
	    ns_write "<li><font color=red>Error: We have found an empty 'Cost Type' in line $cnt.<br>
	        Please correct the CSV file.</font>\n"
	}
	continue
    }

    # Status is optional
    if {"" == $cost_status_id} {
	if {$ns_write_p} { ns_write "<li><font color=brown>Warning: Didn't find cost status '$cost_status', using default status 'Created'</font>\n" }
	set cost_status_id [im_cost_status_created]
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
	        Please correct the CSV file.</font>\n"
	}
	continue
    }
    if {"" == $customer_id} {
	if {$ns_write_p} { 
	    ns_write "<li><font color=red>Error: We have found an empty 'Customer' in line $cnt.<br>
	        Please correct the CSV file.</font>\n"
	}
	continue
    }

    if {"" eq $currency} { 
	if {$ns_write_p} { ns_write "<li><font color=brown>Warning: Didn't find currency, using default currency='$default_currency'</font>\n" }
	set currency $default_currency
    }

    # -------------------------------------------------------
    # Create a new cost if necessary
    if {"" == $cost_id} {
	if {$ns_write_p} { ns_write "<li>Going to create cost: name='$cost_name', nr='$cost_nr'\n" }

	switch $cost_type_id {
	    3700 { set object_type "im_invoice" }
	    3702 { set object_type "im_invoice" }
	    3704 { set object_type "im_invoice" }
	    3706 { set object_type "im_invoice" }
	    3724 { set object_type "im_invoice" }
	    3730 { set object_type "im_invoice" }
	    3732 { set object_type "im_invoice" }
	    3734 { set object_type "im_invoice" }
	    3718 { set object_type "im_cost" }
	    3736 { set object_type "im_cost" }
	    3720 { set object_type "im_expense_item" }
	    3722 { set object_type "im_expense_bundle" }
	    default { 
		if {$ns_write_p} { ns_write "<li><font=red>Unsupported cost_type='$cost_type' - skipping</font></li>\n" }
		continue
	    }
	}

	if {[catch {
	    set cost_id [db_string new_cost "
		select im_cost__new(
			null, :object_type, now()::timestamptz,	:current_user_id::integer, '[ad_conn peeraddr]', null,

			:cost_name,			-- Unique name of cost
			null, 		    		-- parent_id (?)
			:project_id,			-- cost container project
			:customer_id,			-- who will receive the money?
			:provider_id,			-- who pays?
			null,				-- investment_id (not supported)

			:cost_status_id,		-- active or inactive or for WF stages
			:cost_type_id,			-- user defined type of cost. Determines WF.
			:template_id,			-- template_id

			:effective_date,		-- 
			:payment_days,			--
			:amount,			--
			:currency,			--
			:vat,				--
			:tax,				--

			'f',				-- variable_p
			'f',				-- needs_redistribution_p,
			'f',				-- redistributed_p,
			'f',				-- planning_p,
			null,				-- planning_type_id

			:note,				--
			:description			--
		)
	    "]
	    db_dml insert_invoices "
		insert into im_invoices (
			invoice_id, invoice_nr,
			company_contact_id,
			payment_method_id,
			invoice_office_id
		) values (
			:cost_id, :cost_name,
			:customer_contact_id,
			:payment_method_id,
			:invoice_office_id
		)
	    "
	} err_msg]} {
	    if {$ns_write_p} { ns_write "<li><font color=red>Error: Creating new financial document:<br><pre>$err_msg</pre></font>\n" }
	    continue
	}

	# Write Audit Trail
	im_audit -object_id $cost_id -action after_create

    } else {
	if {$ns_write_p} { ns_write "<li>Cost already exists: name='$cost_name', nr='$cost_nr', id='$cost_id'\n" }
    }


    if {$ns_write_p} { ns_write "<li>Going to update the cost.\n" }
    if {[catch {
	db_dml update_cost "
		update im_costs set
			cost_name		= :cost_name,
			cost_nr			= :cost_nr,
			project_id		= :project_id,

			customer_id		= :customer_id,
			provider_id		= :provider_id,

			cost_status_id		= :cost_status_id,
			cost_type_id		= :cost_type_id,

			effective_date		= :effective_date,
			amount			= :amount,
			currency		= :currency,
			vat			= :vat,
			tax			= :tax,

			payment_days		= :payment_days,
			paid_amount		= :paid_amount,

			cost_center_id		= :cost_center_id,
			cause_object_id		= :cause_object_id,
			vat_type_id		= :vat_type_id,
			template_id		= :template_id,

			note			= :note,
			description		= :description
		where
			cost_id = :cost_id
	"

	db_dml update_invoice "
		update im_invoices set
			invoice_nr		= :cost_name,
			company_contact_id	= :customer_contact_id,
			payment_method_id	= :payment_method_id,
			invoice_office_id	= :invoice_office_id
		where
			invoice_id = :cost_id
	"
    } err_msg]} {
	if {$ns_write_p} { ns_write "<li><font color=red>Error: Error updating cost:<br><pre>$err_msg</pre></font>" }
	continue	    
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
    ns_write "<A HREF=$return_url>Return to Cost Page</A>\n"
}

# ------------------------------------------------------------
# Render Report Footer

if {$ns_write_p} {
    ns_write [im_footer]
}


