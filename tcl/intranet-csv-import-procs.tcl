# /packages/intranet-cvs-import/tcl/intranet-cvs-import-procs.tcl
#
# Copyright (C) 2011-now ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

ad_library {
    @author frank.bergmann@project-open.com
    @autor  klaus.hofeditz@project-open.com
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

ad_proc -public im_csv_import_guess_im_expense { } {} {
    set mapping {
        {expense_name "Cost Name" no_change ""}
        {expense_date "Expense Date" date ""}
        {effective_date "Effective Date" date ""}
        {expence_currency "Expense Currency" no_change ""}
        {cost_type_id "Cost Type" category "Intranet Cost Type"}
        {cost_type "Cost Type" category "Intranet Cost Type"}
        {cost_status_id "Cost Status" category "Intranet Cost Status"}
        {project_nr "Project Nr" project_parent_nrs "" }
        {amount "Amount" number ""}
        {vat "VAT" percentage ""}
        {note "Note" no_change ""}
        {external_company_name "External Company Name" no_change "" }
        {external_company_vat_number "External Vat Nr." no_change "" }
        {receipt_reference  "Receipt Reference" no_change "" }        
        {expense_type_id "Expense Type" category "Intranet Expense Type" }        
        {billable_p "Billable?" boolean ""}
        {reimbursable "Reimbursable" number ""}
        {expense_payment_type_id "Expense Payment Type" category "Intranet Expense Payment Type" }        
        {customer_id "Customer" company_name ""}        
        {provider_id "Provider" user_name ""}        
        {bundle_id_old "Bundle Id Old" no_change ""}
    }
    return $mapping
}


ad_proc -public im_csv_import_guess_im_expense_bundle { } {} {
    set mapping {
        {expense_name "Cost Name" no_change ""}
        {expense_date "Expense Date" date ""}
        {effective_date "Effective Date" date ""}
        {expence_currency "Expense Currency" no_change ""}
        {project_nr "Project Nr" project_parent_nrs "" }
        {cost_type_id "Cost Type" category "Intranet Cost Type"}
        {cost_type "Cost Type" category "Intranet Cost Type"}
        {cost_status "Cost Status" category "Intranet Cost Status"}
        {cost_status_id "Cost Status" category "Intranet Cost Status"}
        {amount "Amount" number ""}
        {vat "VAT" percentage ""}
        {note "Note" no_change ""}
        {customer_id "Customer" company_name ""}
        {provider_id "Provider" user_name ""}
        {bundle_id_old "Bundle Id Old" no_change ""}  
    }
    return $mapping
}


ad_proc -public im_csv_import_guess_rels { } {} {
    set mapping {
        {object_type_one                  "Object Type One"             no_change                ""                             }
        {object_id_one                    "Object Id One"               user_name                ""                             }
        {object_type_two                  "Object Type Two"             no_change                ""                             }
        {object_id_two                    "Object Id Two"               project_parent_nrs       ""                             }
        {role_id                          "Role"                        category                 "Intranet Biz Object Role"     }
        {percentage                       "Percentage"                  percentage               ""                             }
    }
    return $mapping
}


ad_proc -public im_csv_import_guess_person { } {} {
    set mapping {
        {email                           "Email"                       no_change                "" }
        {first_names                     "First Names"                 no_change                "" }
        {last_name                       "Last Name"                   no_change                "" }
        {username                        "username"                    no_change                "" }
        {home_phone                      "Home Phone"                  no_change                "" }
        {work_phone                      "Work Phone"                  no_change                "" }
        {cell_phone                      "Cell Phone"                  no_change                "" }
        {pager                           "Pager"                       no_change                "" }
        {fax                             "Fax"                         no_change                "" }
        {aim_screen_name                 "AIM Screen Name"             no_change                "" }
        {icq_number                      "ICQ Number"                  no_change                "" }
        {ha_line1                        "Home Address Line1"          no_change                "" }
        {ha_line2                        "Home Address Line2"          no_change                "" }
        {ha_city                         "Home Address City"           no_change                "" }
        {ha_state                        "Home Address State"          no_change                "" }
        {ha_postal_code                  "Home Address Postal Code"    no_change                "" }
        {ha_country_code                 "Home Address Country Code"   no_change                "" }
        {ha_country                      "Home Address Country"        no_change                "" }
        {wa_line1                        "Work Address Line1"          no_change                "" }
        {wa_line2                        "Work Address Line2"          no_change                "" }
        {wa_city                         "Work Address City"           no_change                "" }
        {wa_state                        "Work Address State"          no_change                "" }
        {wa_postal_code                  "Work Addresspostal Code"     no_change                "" }
        {wa_country_code                 "Work Address Country Code"   no_change                "" }
        {wa_country                      "Work Address Country"        no_change                "" }
        {note                            "Note"                        no_change                "" }
        {supervisor_id                   "Supervisor"                  user_name                "" }        
        {supervisor_id                   "Supervisor Email"            user_name                "" }        
        {supervisor_id                   "Supervisor ID"               no_change                "" }
        {department_id                   "Department"                  no_change                "" }
        {availability                    "Availability"                percentage               "" }
        {personnel_number                "Personnel Number"            no_change                "" }
        {ss_number                       "Social Security Number"      no_change                "" }
        {hourly_cost                     "Hourly Cost"                 number                   "" }
        {salary                          "Salary"                      no_change                "" }
        {social_security                 "Social Security"             no_change                "" }
        {insurance                       "Insurance"                   no_change                "" }
        {other_costs                     "Other Costs"                 no_change                "" }
        {salary_payments_per_year        "Salary Payments per Year"    no_change                "" }
        {birthdate                       "Birthdate"                   date                     "" }
        {job_title                       "Job Title"                   no_change                "" }
        {job_description                 "Job Description"             no_change                "" }
        {voluntary_termination_p         "Voluntary Termination"       boolean                  "" }
        {termination_reason              "Termination Reason"          no_change                "" }
        {signed_nda_p                    "Signed NDA"                  boolean                  "" }
        {vacation_days_per_year          "Vacation Days per Year"      number                   "" }
        {vacation_balance                "Vacation Balance"            number                   "" }
        {profiles                        "Profiles"                    no_change                "" }
        {password                        "Password"                    no_change                "" }
   }
    return $mapping
}

ad_proc -public im_csv_import_guess_im_company { } {} {
    set mapping {
        {company_name                           "Company Name"              no_change ""}
        {company_path                           "Company Path"              no_change ""}
        {company_status_id                      "Company Status"            category "Intranet Company Status"}
        {company_status_id                      "company_status_id"         no_change ""}
        {company_type_id                        "Company Type"              category "Intranet Company Type"}
        {company_name                           "Name"                      no_change ""}
        {company_path                           "Path"                      no_change ""}
        {company_status_id                      "Status"                    category "Intranet Company Status"}
        {company_type_id                        "Type"                      category "Intranet Company Type"}
        {primary_contact_id                     "Primary Contact"           user_name ""}
        {accounting_contact_id                  "Accounting Contact"        user_name ""}
        {accounting_contact_id                  "Accounting"                user_name ""}        
        {billable_p                             "Billable"                  no_change ""}
        {vat_number                             "VAT"                       no_change ""}
        {phone                                  "Phone"                     no_change ""}
        {fax                                    "Fax"                       no_change ""}
        {address_line1                          "Addr1"                     no_change ""}
        {address_line2                          "Addr2"                     no_change ""}
        {address_city                           "City"                      no_change ""}
        {address_postal_code                    "ZIP"                       no_change ""}
        {address_country_code                   "Country"                   no_change ""}
        {company_contact_id                     "Contact"                   no_change ""}
        {referral_source                        "Referral"                  no_change ""}
        {annual_revenue_id                      "AnRev"                     category "Intranet Annual Revenue"}
        {note                                   "Note"                      no_change ""}
        {default_vat                            "Default VAT"               percentage ""}
        {default_po_template_id                 "Default PO Template"               category "Intranet Cost Template"}
        {default_payment_method_id              "Default Payment Method"            category "Intranet Invoice Payment Method"}
        {default_payment_days                   "Default Payment Days"              no_change ""}
        {default_invoice_template_id            "Default Invoice Template"          category "Intranet Cost Template"}
        {default_delnote_template_id            "Default Delivery Note Template"    category "Intranet Cost Template"}
        {default_bill_template_id               "Default Provider Bill Template"    category "Intranet Cost Template"}
        {default_pm_fee_perc                    "Default PM Fee Percentage"         no_change ""}
        {default_surcharge_perc_deref           "Default Surcharge Percentage"      no_change ""}
        {default_discount_perc_deref            "Default Discount Percentage"       no_change ""}
        {default_tax                            "Default TAX"                       percentage ""}
    }
    return $mapping
}

ad_proc -public im_csv_import_guess_im_invoice { } {} {
    set mapping {
        {project_id "Project Nr" project_parent_nrs ""}
        {project_id "Project Nrs" project_parent_nrs ""}
        {project_id "Cost Project Nrs" project_parent_nrs ""}
        {project "Cost Project Nrs" project_parent_nrs ""}
        {invoice_nr "Invoice Nr." no_change ""}        
        {cost_name "Name" no_change ""}
        {cost_name "Cost Name" no_change ""}
        {cost_nr "Nr" no_change ""}
        {cost_nr "Cost Nr" no_change ""}
        {cost_center_id "Cost Center" cost_center ""}
        {cost_center "Cost Center" cost_center ""}        
        {cost_status_id "Status" category "Intranet Cost Status"}
        {cost_status_id "Cost Status" category "Intranet Cost Status"}
        {cost_type_id "Type" category "Intranet Cost Type"}
        {cost_type_id "Cost Type" category "Intranet Cost Type"}
        {customer_id "Customer" company_name ""}
        {provider_id "Provider" company_name ""}
        {customer "Customer" company_name ""}
        {provider "Provider" company_name ""}        
        {effective_date "Effective Date" date ""}
        {amount "Amount" number ""}
        {currency "Currency" no_change ""}
        {payment_days "Payment Days" number ""}
        {paid_amount "Paid Amount" number ""}
        {parent_nrs "" number ""}
        {vat "VAT" percentage ""}
        {tax "TAX" percentage ""}
        {description "Description" no_change ""}
        {note "Note" no_change ""}
        {vat_type_id "VAT Type" category "Intranet VAT Type"}
        {company_contact_id "Customer Contact" user_name ""}
        {company_contact "Customer Contact" user_name ""}        
        {cause_object_id "Cause Object" user_name ""}
        {payment_method_id "Payment Method" category "Intranet Invoice Payment Method"}
        {template_id "Template" category "Intranet Cost Template"}
        {invoice_office_id "Invoice Office" office_name ""}
        {office "Invoice Office" office_name ""}        
        {item_name "Item Name" no_change ""}
        {sort_order "Item Sort Order" number ""}
        {item_units "Item Units" number ""}
        {price_per_unit "Item Price" number ""}
        {price_per_unit "Price Per Unit" number ""}
        {item_uom_id "Item UoM" category "Intranet UoM"}
        {item_uom "Item UoM" category "Intranet UoM"}        
        {item_material_id "Item Material" material ""}
        {item_material "Item Material" material ""}        
        {item_type_id "Item Type Id" no_change ""}
        {item_status_id "Item Status Id" no_change ""}
        {task "Task Id" project_parent_nrs ""}
        {task_id "Task Id" project_parent_nrs ""}
    }
    return $mapping
}


ad_proc -public im_csv_import_guess_im_project { } {} {
    set mapping {
        {parent_id "Parent Nrs" project_parent_nrs ""}
        {parent_nrs "Parent Nrs" project_parent_nrs ""}
        {project_nr "Project Nr." no_change ""}
        {project_name "Project Name" no_change ""}
        {project_status_id "Project Status" category "Intranet Project Status"}
        {project_type_id "Project Type" category "Intranet Project Type"}
        {company_id "Customer Name" company_name ""}
        {start_date "Start Date" date ""}
        {end_date "End Date" date ""}
        {project_name "Name" no_change ""}
        {percent_completed "Percent Completed" percentage ""}
        {project_lead_id "Project Manager" user_name ""}
        {project_budget "Budget" number ""}
        {project_budget_hours "Budget Hours" number ""}
        {sort_order "Sort Order" number ""}
        {note "Note" no_change ""}
        {note "Notes" no_change ""}
        {description "Description" no_change ""}
    }
    return $mapping
}


ad_proc -public im_csv_import_guess_im_timesheet_task { } {} {
    set mapping {
        {billable_units "Billable Units" number ""}
        {company_id "Customer Name" company_name ""}
        {cost_center_id "Cost Center" cost_center ""}
        {deadline_date "Deadline Date" date ""}        
        {description "Description" no_change ""}
        {effort_driven_p "Effort driven" no_change ""}
        {effort_driven_type_id "Scheduling Constraint Id" number ""}
        {end_date "End Date" date ""}
        {gantt_project_id "Gantt Project Id" number ""}
        {invoice_id "Invoice Id" number ""}
        {infrax_creation_date "Creation Date" date_european ""}
        {infrax_done_date "Done Date" date_european ""}
        {material_id "Material" material ""}
        {project_name "Name" no_change ""}
        {note "Note" no_change ""}
        {note "Notes" no_change ""}
        {parent_id "Parent Nrs" project_parent_nrs ""}
        {parent_nrs "Parent Nrs" project_parent_nrs ""}
        {percent_completed "Percent Completed" percentage ""}
        {percent_completed "% Completed" percentage ""}
        {percent_completed "% Complete" percentage ""}
        {planned_units "Planned Units" number ""}
        {planned_units "Work" number ""}
        {priority "Priority" number ""}
        {project_budget "Budget" number ""}
        {project_budget_hours "Budget Hours" number ""}
        {project_lead_id "Project Manager" user_name ""}
        {project_lead_id "Assignee" user_name ""}
        {project_name "Project Name" no_change ""}
        {project_nr "Project Nr." no_change ""}
        {project_status_id "Project Status" category "Intranet Project Status"}
        {project_type_id "Project Type" category "Intranet Project Type"}
        {scheduling_constraint_date "Scheduling Constraint Date" date ""}
        {scheduling_constraint_id "Scheduling Constraint Id" category "Intranet Gantt Task Scheduling Type"}
        {sort_order "Sort Order" number ""}
        {start_date "Start Date" date ""}
        {uom_id "Unit of measure" category "Intranet UoM"}        
    }
    return $mapping
}

ad_proc -public im_csv_import_guess_im_ticket { } {} {
    set mapping {
        {parent_id "Ticket Container" project_parent_nrs ""}
        {parent_id "Parent Nrs" project_parent_nrs ""}
        {parent_id "SLA" project_parent_nrs ""}
        {project_nr "Ticket Nr" no_change ""}
        {project_name "Ticket Name" no_change ""}
        {ticket_customer_contact_id "Customer Contact" user_name ""}
        {ticket_assignee_id "Assignee" user_name ""}
        {ticket_status_id "Ticket Status" category "Intranet Ticket Status"}
        {ticket_type_id "Ticket Type" category "Intranet Ticket Type"}
        {ticket_prio_id "Ticket Prio" category "Intranet Ticket Priority"}
        {start_date "Date" date ""}
        {ticket_dept_id "Department" cost_center ""}
        {ticket_creation_date "Creation Date" date ""}
        {creation_user "Creation User" user_name ""}
    }
    return $mapping
}

ad_proc -public im_csv_import_guess_im_conf_item { } {} {
    set mapping {
        {conf_item_name "Conf Item Name" no_change ""}
        {conf_item_nr "Conf Item Nr" no_change ""}
        {conf_item_code "Conf Item Code" no_change ""}
        {conf_item_parent_id "Parent Conf Item Nr" conf_item_parent_nrs ""}
        {conf_item_parent_id "Conf Item Parent Nrs" conf_item_parent_nrs ""}
        {conf_item_cost_center_id "Conf Item Cost Center Code" cost_center ""}
        {conf_item_status_id "Conf Item Status" category "Intranet Conf Item Status"}
        {conf_item_type_id "Conf Item Type" category "Intranet Conf Item Type"}
        {conf_item_owner_id "Conf Item Owner" user_name ""}
        {conf_item_owner_id "Conf Item Owner Email" user_name ""}
        {conf_item_project_id "Project" project_parent_nrs ""}
        {conf_item_project_id "Conf Item Project Parent Nrs" project_parent_nrs ""}
        {conf_item_version "Conf Item Version" no_change ""}
        {description "Description" no_change ""}
        {note "Note" no_change ""}
    }
    return $mapping
}

ad_proc -public im_csv_import_guess_im_budget_item { } {} {
    set mapping {
        {budget_item_parent_id "Parent Budget Item Nr" budget_item_parent_nrs ""}
        {budget_item_parent_id "Budget Item Parent Nrs" budget_item_parent_nrs ""}
        {budget_item_name "Budget Item Name" no_change ""}
        {budget_item_nr "Budget Item Nr" no_change ""}
        {budget_item_code "Budget Item Code" no_change ""}
        {budget_item_project_id "Budget Item Project" project_parent_nrs ""}
        {budget_item_status_id "Budget Item Status" category "Intranet Budget Item Status"}
        {budget_item_type_id "Budget Item Type" category "Intranet Budget Item Type"}
        {budget_item_owner_id "Budget Item Owner" user_name ""}
        {budget_item_owner_id "Budget Item Owner Email" user_name ""}
	{budget_item_max_value "Value" number ""}
	{budget_item_max_value "Maximum Amount" number ""}
	{budget_item_alarm_value "Alarm Value" number ""}
	{match_cost_type_id "Cost Type" category "Intranet Cost Type"}
	{match_expense_type_id "Expense Type" category "Intranet Expense Type"}
	{match_task_id "Project Phase" project_parent_nrs ""}
	{match_material_type_id "Material Type" category "Intranet Material Type"}
        {description "Description" no_change ""}
        {note "Note" no_change ""}
    }
    return $mapping
}

ad_proc -public im_csv_import_guess_im_hour { } {} {
    set mapping {
        {project_id "Project Nr Path " project_parent_nrs ""}        
        {project_id "Parent Nrs" project_parent_nrs ""}
        {project_id "Project Parent Nrs" project_parent_nrs ""}
        {user_id "User Email" user_name ""}
        {user_id "User Name" user_name ""}
        {user_id "User" user_name ""}
        {day "Day" date ""}
        {hours "Hours" number ""}
        {note "Note" no_change ""}
        {billing_rate "Billing Rate" number ""}
        {invoice_id "Invoice Id" no_change ""}
        {invoice_nr "Invoice Nr" hard_coded ""}        
        {days "Days" number ""}        
        {manually_updated_p "Manually Updated" boolean ""}        
    }
    return $mapping
}


ad_proc -public im_csv_import_guess_im_risk { } {} {
    set mapping {
        {risk_project_id "Risk Project Parent Nrs" project_parent_nrs ""}
        {risk_name "Risk Name" no_change ""}
        {risk_status_id "Status" category "Intranet Risk Status"}
        {risk_type_id "Type" category "Intranet Risk Type"}
        {risk_status_id "Risk Status" category "Intranet Risk Status"}
        {risk_type_id "Risk Type" category "Intranet Risk Type"}
        {risk_description "Description" no_change ""}
        {risk_description "Risk Description" no_change ""}
        {risk_impact "Impact" number ""}
        {risk_probability_percent "Probability" percentage ""}
        {risk_probability_percent "Risk Probability" percentage ""}
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
        im_project - im_company - im_budget_item - im_conf_item - im_cost - im_invoice - im_risk - im_timesheet_task - im_ticket - im_hour - person - im_expense_bundle - im_expense - rels {
            set parsers {
                no_change                       "No Change"
                budget_item_parent_nrs          "Budget Item Parent Nrs"
                boolean                         "Boolean"
                category                        "Category ID from Category Name"
                company_name                    "Company ID from Company Name or Company Path"
                conf_item_parent_nrs            "Conf Item Parent Nrs"
                cost_center                     "Cost Center"
                date                            "Date (generic)"
                date_european                   "Date European (DD.MM.YYYY)"
                date_american                   "Date US (MM/DD/YYYY)"
                date_european_dashes            "Date ISO (YYYY-MM-DD)"
                hard_coded                      "Hard Coded Functionality"
                material                        "Material"
                number                          "Number (generic)"
                number_american                 "Number US (20,000.00)"
                number_european                 "Number European (20.000,00)"
                percentage                      "Percentage (generic)"
                office_name                     "Office ID from Office Name"
                project_name                    "Project ID from Project Name"
                project_nr                      "Project ID from Project Nr"
                project_parent_nrs              "Project ID from Parent Nrs"
                user_name                       "User ID from email, username or full name"
            }
        }
        im_membership {
            set parsers {
                no_change                       "No Change"
                hard_coded                      "Hard Coded Functionality"
                project_nr                      "Project from Project Nr"
                project_name                    "Project from Project Name"
                user_name                       "User ID from user-email"
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
        return "project_id project_nr project_nr_path user_id day hours note billing_rate invoice_id days manually_updated_p invoice_nr"
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

    # special logic for some object types
    switch $object_type {
        im_company {
            lappend super_types "im_office"
        }
    }

    # ---------------------------------------------------------------
    # Get the list of tables associated with the object type and its super types
    #
    set tables_sql "
        select        *
        from        (
                select        table_name, id_column, 1 as sort_order
                from          acs_object_types
                where         object_type in ('[join $super_types "', '"]')
        UNION
                select        table_name, id_column, 2 as sort_order
                from          acs_object_type_tables
                where         object_type in ('[join $super_types "', '"]')
                ) t
        order by t.sort_order
    "

    set columns_sql "
        select      lower(column_name) as column_name
        from        user_tab_columns
        where       lower(table_name) = lower(:table_name)
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

    # Check for static mapping additions
    set static_mapping_lol {}
    catch { set static_mapping_lol [im_csv_import_guess_$object_type] }
    foreach static_mapping_tuple $static_mapping_lol {
        set field_name [lindex $static_mapping_tuple 0]
        if {[lsearch $selected_columns $field_name] < 0} {
            lappend selected_columns $field_name
        }
    }

    return [lsort $selected_columns]
}


# ---------------------------------------------------------------------
# Guess the most probable object field (DynField) for a column
# ---------------------------------------------------------------------

ad_proc -public csv_norm {
    field_name
} {
    Performs normalization including trim, tolower, 
    replace non-ascii with "_".
} {
    set field_name [string tolower [string trim $field_name]]
    regsub -all {[^a-zA-Z0-9]} $field_name "_" field_name
    return $field_name
}


ad_proc -public im_csv_import_guess_map {
    -object_type:required
    -field_name:required
    { -sample_values {} }
} {
    Returns the best guess for a DynField for the field.
    We check three options:
    <ul>
    <li>Manual override static mapping: Manually defined
    <li>Attribute Name: Table column name with underscores ("project_name")
    <li>Pretty Name: English pretty name of column ("Project Name")
    <li>
} {
    set field_name_lower [csv_norm $field_name]
    ns_log Notice "im_csv_import_guess_map: trying to guess attribute_name for field_name=$field_name_lower of object_type=$object_type"
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

        if {$field_name_lower eq [csv_norm $pretty_name]} {
            ns_log Notice "im_csv_import_guess_map: found statically encoded match with field_name=$field_name"
            return $attribute_name
        }
    }

    switch $object_type {
        im_company { lappend object_type "im_office" }
    }

    set dynfield_sql "
        select  lower(aa.attribute_name) as attribute_name,
                lower(aa.pretty_name) as pretty_name,
                w.widget as tcl_widget,
                w.widget_name as dynfield_widget
        from        im_dynfield_attributes a,
                im_dynfield_widgets w,
                acs_attributes aa
        where        a.widget_name = w.widget_name and 
                a.acs_attribute_id = aa.attribute_id and
                aa.object_type in ('[join $object_type "', '"]')
        order by aa.sort_order, aa.attribute_id
    "

    # Check if the header name is the attribute_name of a DynField
    set dynfield_attribute_names [util_memoize [list db_list otype_dynfields "select attribute_name from ($dynfield_sql) t"]]
    ns_log Notice "im_csv_import_guess_map: attribute_names=$dynfield_attribute_names"
    foreach field $dynfield_attribute_names {
        if {$field_name_lower eq [csv_norm $field]} {
            ns_log Notice "im_csv_import_guess_map: found attribute_name match with field_name=$field_name"
            return $field_name_lower
        }
    }

    # Check for a pretty_name of a DynField
    set dynfield_pretty_name_tuples [util_memoize [list db_list_of_lists otype_dynfields "select attribute_name, pretty_name from ($dynfield_sql) t"]]
    ns_log Notice "im_csv_import_guess_map: pretty_name_tuples=$dynfield_pretty_name_tuples"
    foreach tuple $dynfield_pretty_name_tuples {
        set attribute_name [lindex $tuple 0]
        set pretty_name [lindex $tuple 1]
        if {$field_name_lower eq [csv_norm $pretty_name]} {
            ns_log Notice "im_csv_import_guess_map: found pretty_name match with field_name=$field_name"
            return $attribute_name
        }
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
	select  dw.widget as tcl_widget,
		dw.parameters as tcl_widget_parameters,
		substring(dw.parameters from 'category_type \"(.*)\"') as category_type,
		aa.attribute_name,
		aa.datatype
	from    acs_attributes aa,
		im_dynfield_attributes da,
		im_dynfield_widgets dw
	where	aa.object_type in ('[join $super_types "','"]') and
		aa.attribute_id = da.acs_attribute_id and
		da.widget_name = dw.widget_name and
		(lower(aa.attribute_name) = lower(trim(:field_name)) OR lower(aa.attribute_name) = lower(trim(:field_name))||'_id')
    "

    # ad_return_complaint 1 [im_ad_hoc_query -format html $dynfield_sql]

    set result [list "" "" ""]
    set ttt_widget ""
    db_foreach dynfields $dynfield_sql {
        set ttt_widget $tcl_widget

	switch $datatype {
	    "float" {
		set result [list "number" "" $attribute_name]
	    }
	}

        switch $tcl_widget {
            "im_category_tree" {    set result [list "category" $category_type $attribute_name] }
            "im_cost_center_tree" { set result [list "cost_center" "" $attribute_name]          }
            "checkbox" {            set result [list "boolean" "" $attribute_name]              }
            "date" {                set result [list "date" "" $attribute_name]                 }
            default {
                # Default: No specific parser
                # text, richtext, textare -> no change (ToDo: quoting?)
                # radio, select generic_sql -> custom
		if {[list "" "" ""] eq $result} {
		    set result [list "" "" $attribute_name]
		}
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


# ----------------------------------------------------------------------
#
# ----------------------------------------------------------------------

ad_proc -public im_csv_import_label_from_object_type {
    -object_type:required
} {
    Returns the main navbar lable for the object_type
} {
    switch $object_type {
        im_company { return "companies" }
        im_project { return "projects" }
        im_ticket { return "helpdesk" }
        person { return "users" }
        default { return "" }
    }
}

