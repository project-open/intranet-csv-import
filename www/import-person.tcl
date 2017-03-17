# /packages/intranet-csv-import/www/import-person.tcl

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
    { overwrite_existing_user_attributes_p "0" }
    column:array
    map:array
    parser:array
    parser_args:array
}

# ---------------------------------------------------------------------
# ToDo: 
# ---------------------------------------------------------------------
#  
# 
# ---------------------------------------------------------------------
# Default & Security
# ---------------------------------------------------------------------

set current_user_id [auth::require_login]
set page_title [lang::message::lookup "" intranet-cvs-import.Upload_Objects "Upload Objects"]
set context_bar [im_context_bar "" $page_title]

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
		aa.object_type in ('person') and
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
    ns_write "<h1>Importing PERSONS</h1>\n"
}

# ------------------------------------------------------------

set cnt 1
foreach csv_line_fields $values_list_of_lists {

    set new_user_p 0

    incr cnt

    if {$ns_write_p} { ns_write "</ul><hr><ul>\n" }
    if {$ns_write_p} { ns_write "<li>Starting to parse line $cnt\n" }

    if {[llength $csv_line_fields] < 4} {
	if {$ns_write_p} {
	    ns_write "<li><font color=red>Error: We found a row with only [llength $csv_line_fields] columns.<br>
	        This is probabily because of a multi-line field in the row before.<br>Please correct the CSV file.</font>\n"
	}
	continue
    }

    set email                                   ""
    set username                                ""
    set first_names                             ""
    set last_name                               ""
    set email                                   ""
    set title                                   ""
    set portrait_file                           ""

    # Address data
    set home_phone                              ""
    set work_phone                              ""
    set cell_phone                              ""
    set pager                                   ""
    set fax                                     ""
    set aim_screen_name                         ""
    set icq_number                              ""
    set ha_line1                                ""
    set ha_line2                                ""
    set ha_city                                 ""
    set ha_state                                ""
    set ha_postal_code                          ""
    set ha_country_code                         ""
    set ha_country                              ""
    set wa_line1                                ""
    set wa_line2                                ""
    set wa_city                                 ""
    set wa_state                                ""
    set wa_postal_code                          ""
    set wa_country_code                         ""
    set wa_country                              ""
    set note                                    ""

    # Employee data
    set department_id                           ""
    set department				""
    set supervisor_id                           ""
    set supervisor				""
    set availability                            ""
    set personnel_number                        ""
    set ss_number                               ""
    set currency                                ""
    set hourly_cost                             ""
    set salary                                  ""
    set social_security                         ""
    set insurance                               ""
    set other_costs                             ""
    set salary_payments_per_year                ""
    set birthdate                               ""
    set job_title                               ""
    set job_description                         ""
    set start_date                              ""
    set end_date                                ""
    set voluntary_termination_p                 ""
    set termination_reason                      ""
    set signed_nda_p                            ""
    set vacation_days_per_year                  ""
    set vacation_balance                        ""

    # Group memberships
    set profiles                                ""

    # To Do:
    # group_name_1                            ""
    # group_name_2                            ""
    # group_name_3                            ""
    # group_name_4                            ""
    # group_name_5                            ""
    # group_name_6                            ""
    # group_name_7                            ""
    
    # Generic attributes
    foreach attribute_name $attribute_names {
	set $attribute_name ""
    }
  
    # Get all profiles in the system and store them in an array  
    foreach profile_tuple [im_profile::profile_options_all] {
	set profile_name [lindex $profile_tuple 0]
	regsub -all {\[} $profile_name {} profile_name
	regsub -all {\]} $profile_name {} profile_name
	set profile_arr($profile_name) [lindex $profile_tuple 1] 
    }

    # Get all Departments 
    set sql "select cost_center_id, cost_center_name from im_cost_centers where department_p = 't'"
    db_foreach r $sql {
	set department_arr($cost_center_name) $cost_center_id
    }

    # -------------------------------------------------------
    # Extract variables from the CSV file and write them to local variables
    #
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
		ns_log Notice "import-person: Parser: '$p -args $p_args $var_value' -> $target_var_name=$var_value, err=$err"
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

   
    # -------------------------------------------------------
    # Specific field transformations

    # username
    if {"" == $username} { set username $email}

    # email
    if {"" == $email} {
	if {$ns_write_p} {
	    ns_write "<li><font color=red>Error: We have found an empty 'email' in line $cnt.<br>
	        Please correct the CSV file. For every person to be imported an email is required.</font>\n"
	}
	continue
    }

    # First names
    if {"" == $first_names} {
	if {$ns_write_p} {
	    ns_write "<li><font color=red>Error: We have found an empty 'First name' in line $cnt.<br>
	        Please correct the CSV file. For every person to be imported a first name is required.</font>\n"
	}
	continue
    }

    # Last name 
    if {"" == $last_name} {
	if {$ns_write_p} {
	    ns_write "<li><font color=red>Error: We have found an empty 'Last name' in line $cnt.<br>
	        Please correct the CSV file. For every person to be imported a last name is required.</font>\n"
	}
	continue
    }

    # Supervisor
    if { "" != $supervisor_id && "" != $supervisor } {
	if {$ns_write_p} {
	    ns_write "<li><font color=red>Error: Please provide either supervisor or supervisor_id. Record will not be imported, please correct the CSV file.</font>\n"
	}
	continue
    }

    # Department
    if { "" != $department && "" != $department_id } {
	if {$ns_write_p} {
	    ns_write "<li><font color=red>Error: Please provide either department or department_id. Record will not be imported, please correct the CSV file.</font>\n"
	}
	continue
    }

    if { "" != $department } {
	if { [info exists department_arr($department)] } {
	    set department_id $department_arr($department)
	} else {
	    if {$ns_write_p} {
		ns_write "<li><font color='red'>Error: We have not found a department named: '$department' </font>\n"
	    }
	    continue
        }
    }

    # -------------------------------------------------------
    # Check if the User already exists
    #
    set user_id [db_string party_id "
	select	party_id
	from	parties
	where	email = :email
    " -default ""]

    # Create a new user if necessary
    if {"" == $user_id} {
	if {$ns_write_p} { ns_write "<li>import-person: Trying to create user: $first_names $last_name ($email)\n" }

	set new_user_p 1
	
	if {[catch {
	    set user_id [db_nextval acs_object_id_seq]    
	    # Generate random PW
	    set password [ad_generate_random_string]
	    set password_confirm $password

            array set creation_info [auth::create_user \
                                         -user_id $user_id \
                                         -verify_password_confirm \
                                         -username $username \
                                         -email $email \
                                         -first_names $first_names \
                                         -last_name $last_name \
                                         -screen_name "" \
                                         -password $password \
                                         -password_confirm $password_confirm \
                                         -url "" \
                                         -secret_question "" \
                                         -secret_answer ""]


	    switch $creation_info(creation_status) {
		ok {
		    # Continue below
		}
		default {
		    if { [llength $creation_info(element_messages)] == 0 } {
			array set reg_elms [auth::get_registration_elements]
			set first_elm [lindex [concat $reg_elms(required) $reg_elms(optional)] 0]
			ns_write "<li><font color=red>Error - User not created: $first_elm $creation_info(creation_message)</font>\n"
		    }
		    # Element messages
		    foreach { elm_name elm_error } $creation_info(element_messages) {
                        ns_write "<li><font color=red>Error - User not created:  attribute: $elm_name, message: $elm_error\n"
		    }
		    continue
		}
	    }

	    switch $creation_info(account_status) {
		ok {
		    # Continue below
		}
		default {
		    # Display the message on a separate page
		    ns_write "<li><font color=red>Error - User not created: $creation_info(account_message)</font>\n"
		    continue
		}
	    }

	} err_msg]} {
	    if {$ns_write_p} { ns_write "<li><font color=red>Error creating new user<br><pre>$err_msg</pre></font>\n" }
	    continue	   
	}

	if {$ns_write_p} { ns_write "<li>import-person: Createe user: <a href=\"/intranet/users/view?user_id=$user_id\">$first_names $last_name ($email)</a></li></li>\n" }	
	
	# Write Audit Trail
	im_audit -object_id $user_id -action after_create
	
    } else {
	if {$ns_write_p} { ns_write "<li>User already exists: $first_names $last_name email='$email'\n" }
    }

    if { $overwrite_existing_user_attributes_p || $new_user_p } {
	if {$ns_write_p} { ns_write "<li>Going to update the user's contact data\n" }

	if {[catch {
	    # Updating contact data 
	    set sql "
		update users_contact set 
                    home_phone      = :home_phone           ,
                    work_phone      = :work_phone           ,
                    cell_phone      = :cell_phone           ,
                    pager           = :pager                ,
                    fax             = :fax                  ,
                    aim_screen_name = :aim_screen_name      ,
                    icq_number      = :icq_number           ,
                    ha_line1        = :ha_line1             ,
                    ha_line2        = :ha_line2             ,
                    ha_city         = :ha_city              ,
                    ha_state        = :ha_state             ,
                    ha_postal_code  = :ha_postal_code       ,
                    ha_country_code = :ha_country_code      ,
                    wa_line1        = :wa_line1             ,
                    wa_line2        = :wa_line2             ,
                    wa_city         = :wa_city              ,
                    wa_state        = :wa_state             ,
                    wa_postal_code  = :wa_postal_code       ,
                    wa_country_code = :wa_country_code      ,
                    note            = :note                 
		where user_id = :user_id
	"
	    db_dml sql $sql

	    if {$ns_write_p} { ns_write "<li>Going to update the user's employee data\n" }


	    ###
	    # Assign users to profiles
	    #
	    if {$ns_write_p} { ns_write "<li>Trying to match profiles found ([split $profiles ","]) to one or more of the following profiles: [array names profile_arr]</li>"}
	    foreach profile [split $profiles ","] {
		# remove brackets 
		regsub -all {\[} $profile {} profile
		regsub -all {\]} $profile {} profile
		set profile [string trim $profile]

		# Backwards compatibility
		if { "P/O Admins" eq $profile } { set profile "po Admins" }

		if { [info exists profile_arr($profile)] } {

		    if {$ns_write_p} { ns_write "<li>Adding user to profile: $profile_arr($profile) </li>"}
		    im_profile::add_member -profile_id $profile_arr($profile) -user_id $user_id
		    
		    if { "Employees" eq $profile } {
			# Simply add the record to all users, even it they are not employees...
			set im_employees_exists_p [db_string im_employees_exists_p "select count(*) from im_employees where employee_id = :user_id"]
			if {!$im_employees_exists_p} { db_dml add_im_employees "insert into im_employees (employee_id) values (:user_id)" }
			
			# Update employee data
			db_dml update_employees "
		                update im_employees set
                		department_id                   = :department_id           ,
		                availability                    = :availability            ,
                    		personnel_number                = :personnel_number        ,
                    		ss_number                       = :ss_number               ,
                    		hourly_cost                     = :hourly_cost             ,
                    		salary                          = :salary                  ,
                    		social_security                 = :social_security         ,
                    		insurance                       = :insurance               ,
                    		other_costs                     = :other_costs             ,
                    		salary_payments_per_year        = :salary_payments_per_year,
                    		birthdate                       = :birthdate               ,
                    		job_title                       = :job_title               ,
                    		job_description                 = :job_description         ,
                    		voluntary_termination_p         = :voluntary_termination_p ,
                    		termination_reason              = :termination_reason      ,
                    		signed_nda_p                    = :signed_nda_p            ,
                    		vacation_days_per_year          = :vacation_days_per_year  ,
                    		vacation_balance                = :vacation_balance
                		where employee_id = :user_id
        		"

			###
			# Set supervisor
			#
			if { "" != $supervisor && [string is double -strict $supervisor]} {
			    ns_write "<li>Found supervisor: $supervisor, updating now.</li>"
			    db_dml update_supervisor "update im_employees set supervisor_id = :supervisor where employee_id = :user_id"
			}
		    }

		} else {
		    if {$ns_write_p} { ns_write "<li><font color=red>Error: Error adding user to profile: >>${profile}<< - Profile not found</font></li>" }
		}
	    }
	    
	} err_msg]} {
	    if {$ns_write_p} { ns_write "<li><font color=red>Error: Error updating user:<br><pre>$err_msg</pre></font></li>" }
	    continue	   
	}
	
	
	# -------------------------------------------------------
	# Import DynFields   
	set person_dynfield_updates {}
	array unset attributes_hash
	array set attributes_hash {}
	db_foreach store_dynfiels $dynfield_sql {
	    ns_log Notice "import-person: name=$attribute_name, otype=$object_type, table=$table_name"
	    
	    # Avoid storing attributes multipe times into the same table.
	    # Sub-types can have the same attribute defined as the main type, so duplicate
	    # DynField attributes are OK.
	    set key "$attribute_name-$table_name"
	    if {[info exists attributes_hash($key)]} {
		ns_log Notice "import-person: name=$attribute_name already exists."
		continue
	    }
	    set attributes_hash($key) $table_name
	    lappend person_dynfield_updates "$attribute_name = :$attribute_name"
	}
	
	if {$ns_write_p} { ns_write "<li>Going to update person DynFields.\n" }
	if {"" != $person_dynfield_updates} {
	    set person_update_sql "
		update persons set
		[join $person_dynfield_updates ",\n\t\t"]
		where person_id = :user_id
	"
	    if {[catch {
		db_dml person_dynfield_update $person_update_sql
	    } err_msg]} {
		if {$ns_write_p} { ns_write "<li><font color=brown>Warning: Error updating person dynfields:<br><pre>$err_msg</pre></font>" }
	    }
	}
	
	if {$ns_write_p} { ns_write "<li>Going to write audit log.\n" }
	im_audit -object_id $user_id -action after_update
	
    } else {
	if {$ns_write_p} { ns_write "<li><font color=brown>Data for user $first_names $last_name has not been updated or extended using data from import file</font>\n" }
    }
}

if {$ns_write_p} {
    ns_write "</ul>\n"
    ns_write "<p>\n"
    ns_write "<A HREF=$return_url>Return</A>\n"
}

# ------------------------------------------------------------
# Render Report Footer

if {$ns_write_p} {
    ns_write [im_footer]
}


