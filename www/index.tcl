# /package/intranet-csv-import/www/index.tcl
#
# Copyright (C) 2004 ]project-open[
#
# This program is free software. You can redistribute it
# and/or modify it under the terms of the GNU General
# Public License as published by the Free Software Foundation;
# either version 2 of the License, or (at your option)
# any later version. This program is distributed in the
# hope that it will be useful, but WITHOUT ANY WARRANTY;
# without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.

ad_page_contract {
    Serve the user a form to upload a new file or URL

    @author Frank Bergmann (frank.bergmann@project-open.com)
    @creation-date July 2003
} {
    { return_url "" }
    { object_type "" }
}

set user_id [auth::require_login]
set page_title [lang::message::lookup "" intranet-csv-import.Upload_file "Upload File"]
set context_bar [im_context_bar "" $page_title]
set main_navbar_label [im_csv_import_label_from_object_type -object_type $object_type]

# Get CSV Export links

db_1row get_report_ids "
	select 
		(select report_id from im_reports where report_name = 'Export Absences') as report_id_export_absemces,
		(select report_id from im_reports where report_name = 'Export Companies') as report_id_export_companies,
		(select report_id from im_reports where report_name = 'Export Conf Items') as report_id_export_conf_items,
		(select report_id from im_reports where report_name = 'Export Expense Bundles') as report_id_export_expense_bundles,
		(select report_id from im_reports where report_name = 'Export Expense Items') as report_id_export_expense_items,
		(select report_id from im_reports where report_name = 'Export Finance Documents') as report_id_export_finance_documents,
		(select report_id from im_reports where report_name = 'Export Hours') as report_id_export_hours,
		(select report_id from im_reports where report_name = 'Export Invoice Items') as report_id_export_invoice_items,
		(select report_id from im_reports where report_name = 'Export Persons') as report_id_export_persons,
		(select report_id from im_reports where report_name = 'Export Project-Task Relationships') as report_id_export_project_task_relationships,
		(select report_id from im_reports where report_name = 'Export Projects') as report_id_export_projects,
		(select report_id from im_reports where report_name = 'Export Risks') as report_id_export_risks,
		(select report_id from im_reports where report_name = 'Export Tasks') as report_id_export_tasks,
		(select report_id from im_reports where report_name = 'Export Tickets') as report_id_export_tickets
	from dual
"

if { "" eq $return_url } { set return_url "/intranet-csv-import/" }

