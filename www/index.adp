<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN">
<master>
<property name="doc(title)">@page_title;literal@</property>
<property name="context">@context_bar;literal@</property>
<property name="main_navbar_label">@main_navbar_label;literal@</property>

<form enctype="multipart/form-data" method=POST action="import-2.tcl">
<%= [export_vars -form {return_url main_navbar_label}] %>
     <table border="0">
     <tr> 
	<td>#intranet-csv-import.Object_Type#</td>
	<td> 
	<%= [im_select object_type [list \
	      im_budget_item "Budget Item" \
	      im_company "Company" \
	      im_conf_item "Configuration Item" \
	      im_expense "Expense" \
              im_expense_bundle "Expense Bundle" \
	      im_invoice "Financial Document" \
	      im_timesheet_task "Gantt Task" \
	      im_membership "Membership" \
	      person "Person" \
	      im_project "Project" \
	      rels "Relationship: Projects/Tasks - Members " \
	      im_risk "Risk" \
	      im_hour "Timesheet Hour" \
	      im_ticket "Ticket" \
	    ] $object_type] %>
	</td>
     </tr>
     <tr> 
	<td><%= [lang::message::lookup "" intranet-csv-import.Filename] %></td>
	<td><input type="file" name="upload_file" size="30">
	<%= [im_gif help "Use the &quot;Browse...&quot; button to locate your file, then click &quot;Open&quot;."] %>
	</td>
     </tr>
     <tr><td></td><td><input type="submit"></td></tr>
    </table>
</form>

<br>&nbsp;<br>
<h1>Working CSV Examples</h1>
<table cellspacing="2" cellpadding="5">
<tr>
  <td colspan=6>
    <p>Please find below sample CSV files for each of the object types above. The header line shows the attributes that are supported by the CSV import.</p>
    <p>Column names are case insensitive and spaces may be replaced by "_" (underscore characters).</p>
  </td>
</tr>
<tr>
  <th colspan="2" align="left"><nobr>Object Type</nobr></th>
  <th><nobr>Example<br/>CSV import</nobr></th>
  <th><nobr>Example<br/>Export SQL</nobr></th>
  <th align="left">Comments</th>
</tr>


<tr>
  <td><%= [im_gif [db_string gif "select object_type_gif from acs_object_types where object_type = 'im_budget_item'"]] %></td>
  <td>Budget Item</td>
  <td align=center><a href="examples/im_budget_item.csv"><%= [im_gif csv-doc] %></a></td>
  <td align="center"></td>
  <td>
    Please note that this import requires exact naming of column headers.<br>
    Budget Item <a href="/intranet-dynfield/object-type?object_type=im_budget_item">DynFields</a> are also recognized by their "pretty name" or "column name".</p>
  </td>
</tr>


<tr>
  <td><%= [im_gif [db_string gif "select object_type_gif from acs_object_types where object_type = 'im_company'"]] %></td>
  <td>Company</td>
  <td align=center><a href="examples/im_company.csv"><%= [im_gif csv-doc] %></a></td>
  <td align=center><a href="/intranet-reporting/view?report_id=<%=$report_id_export_companies%>"><%= [im_gif database_table] %></a></td>
  <td>Company <a href="/intranet-dynfield/object-type?object_type=im_company">DynFields</a> are also recognized by their "pretty name" or "column name".</p>
  </td>
</tr>

<tr>
  <td><%= [im_gif [db_string gif "select object_type_gif from acs_object_types where object_type = 'im_conf_item'"]] %></td>
  <td>Conf Item</td>
  <td align=center><a href="examples/im_conf_item.csv"><%= [im_gif csv-doc] %></a></td>
  <td align="center"></td>
  <td>
    Please note that this import requires exact naming of column headers.<br>
    Conf Item <a href="/intranet-dynfield/object-type?object_type=im_conf_item">DynFields</a> are also recognized by their "pretty name" or "column name".</p>
  </td>
</tr>

<tr>
  <td><%= [im_gif money] %></td>
  <td>Expense Items</td>
  <td align=center><a href="examples/im_expense.csv"><%= [im_gif csv-doc] %></a></td>
  <td align=center><a href="/intranet-reporting/view?report_id=<%=$report_id_export_expense_items%>"><%= [im_gif database_table] %></a></td>
  <td>
    Expense <a href="/intranet-dynfield/object-type?object_type=im_expense">DynFields</a> are also recognized by their "pretty name" or "column name".
  </td>
</tr>

<tr>
  <td><%= [im_gif box] %></td>
  <td>Expense Bundles</td>
  <td align=center><a href="examples/im_expense_bundle.csv"><%= [im_gif csv-doc] %></a></td>
  <td align=center><a href="/intranet-reporting/view?report_id=<%=$report_id_export_expense_bundles%>"><%= [im_gif database_table] %></a></td>
  <td></td>
</tr>


<tr>
  <td><%= [im_gif [db_string gif "select object_type_gif from acs_object_types where object_type = 'im_invoice'"]] %></td>
  <td>Financial Documents (Invoices, Purchase Orders, etc.)</td>
  <td align=center><a href="examples/im_invoice.csv"><%= [im_gif csv-doc] %></a></td>
  <td align=center><a href="/intranet-reporting/view?report_id=<%=$report_id_export_companies%>"><%= [im_gif database_table] %></a></td>
  <td>
    <a href="http://www.project-open.com/en/object-type-im-invoice" target="_blank">Financial Documents</a> are
    <a href="http://www.project-open.com/en/object-type-im-cost" target="_blank">cost items</a> with a header and
    one more more lines. Financial documents include invoices, quotes, purchase orders and others.<br>
    Financial document lines can be imported together with the headers (please see the example document).<br>
    Cost Item <a href="/intranet-dynfield/object-type?object_type=im_invoice">DynFields</a> are also recognized by their "pretty name" or "column name".</p>
  </td>
</tr>

<!--
<tr>
  <td><%= [im_gif page_white_star] %></td>
  <td>Financial Document Item</td>
  <td align=center><a href="examples/im_invoice_item.csv"><%= [im_gif csv-doc] %></a></td>
  <td align=center><a href="/intranet-reporting/view?report_id=<%=$report_id_export_invoice_items%>"><%= [im_gif database_table] %></a></td>
  <td>Allows to import "Items" seperately from headers.</td>
</tr>
-->

<tr>
  <td><%= [im_gif [db_string gif "select object_type_gif from acs_object_types where object_type = 'im_gantt_task'" -default ""]] %></td>
  <td>Gantt Task</td>
  <td align=center><a href="examples/im_project.csv"><%= [im_gif csv-doc] %></a></td>
  <td align=center><a href="/intranet-reporting/view?report_id=<%=$report_id_export_tasks%>"><%= [im_gif database_table] %></a></td>
  <td>Allows to import Timesheet Tasks separately from projects/sub-projects.</td>
</tr>


<tr>
  <td><%= [im_gif [db_string gif "select object_type_gif from acs_object_types where object_type = 'person'"]] %></td>
  <td>Person</td>
  <td align=center><a href="examples/person.csv"><%= [im_gif csv-doc] %></a></td>
  <td align=center><a href="/intranet-reporting/view?report_id=<%=$report_id_export_persons%>"><%= [im_gif database_table] %></a></td>
  <td><!--Alternatively you can use the old facilities for <a href="<%= [export_vars -base "/intranet/users/upload-contacts" {return_url}] %>">importing users from MS-Outlook exports</a>.--></td>
</tr>

<tr>
  <td><%= [im_gif [db_string gif "select object_type_gif from acs_object_types where object_type = 'im_project'"]] %></td>
  <td>Project</td>
  <td align=center><a href="examples/im_project.csv"><%= [im_gif csv-doc] %></a></td>
  <td align=center><a href="/intranet-reporting/view?report_id=<%=$report_id_export_projects%>"><%= [im_gif database_table] %></a></td>
  <td>
    Project <a href="/intranet-dynfield/object-type?object_type=im_project">DynFields</a> are also recognized by their "pretty name" or "column name".</p>
  </td>
</tr>


<tr>
  <td><%=[im_gif brick_link]%></td>
  <td>Relationships</td>
  <td align=center><a href="examples/im_relation.csv"><%= [im_gif csv-doc] %></a></td>
  <td align=center><a href="/intranet-reporting/view?report_id=<%=$report_id_export_project_task_relationships%>"><%= [im_gif database_table] %></a></td>
  <td>Import relationships between projects/tasks and persons.</td>
</tr>

<tr>
  <td><%= [im_gif [db_string gif "select object_type_gif from acs_object_types where object_type = 'im_risk'"]] %></td>
  <td>Risk</td>
  <td align=center><a href="examples/im_risk.csv"><%= [im_gif csv-doc] %></a></td>
  <td></td>  
  <td>Risk <a href="/intranet-dynfield/object-type?object_type=im_risk">DynFields</a> are also recognized by their "pretty name" or "column name".</p></td>
</tr>

<tr>
  <td><%= [im_gif hourglass] %></td>
  <td>Timesheet Hour</td>
  <td align=center><a href="examples/im_hour.csv"><%= [im_gif csv-doc] %></a></td>
  <td align=center><a href="/intranet-reporting/view?report_id=<%=$report_id_export_hours%>"><%= [im_gif database_table] %></a></td>
  <td>DynFields for hours are not supported.</td>
</tr>

<tr>
  <td><%= [im_gif [db_string gif "select object_type_gif from acs_object_types where object_type = 'im_ticket'"]] %></td>
  <td>Tickets</td>
  <td align=center><a href="examples/im_ticket.csv"><%= [im_gif csv-doc] %></a></td>
  <td align=center><a href="/intranet-reporting/view?report_id=<%=$report_id_export_tickets%>"><%= [im_gif database_table] %></a></td>
  <td>
    Ticket <a href="/intranet-dynfield/object-type?object_type=im_ticket">DynFields</a> are also recognized by their "pretty name" or "column name".</p>
  </td>
</tr>

<tr>
  <td><%= [im_gif [db_string gif "select object_type_gif from acs_object_types where object_type = 'im_user_absence'"]] %></td>
  <td>User Absence</td>
  <td align=center></td>
  <td align=center></td>
  <td>
    Absence import is under active development at the moment.<br>Please <a href="http://www.project-open.com/en/contact">contact us</a> for the current status or updates.
  </td>
</tr>

<!--
<tr>
  <td><%= [im_gif [db_string gif "select object_type_gif from acs_object_types where object_type = 'im_cost'"]] %></td>
  <td>Cost Item</td>
  <td align=center><a href="examples/im_cost.csv"><%= [im_gif csv-doc] %></a></td>
  <td>
    Project Nrs, Name, Nr, Type, Status, Customer, Provider, Effective Date, Amount, Currency, Payment Days, Paid Amount, 
    VAT, TAX, Description, Note, VAT Type<br>
    Cost Item <a href="/intranet-dynfield/object-type?object_type=im_cost">DynFields</a> 
    are also recognized by their "pretty name" or "column name".</p>
  </td>
</tr>
-->

<tr>
  <td colspan=4>
    <p>The ]project-open[ team offers professional services to help you import data from
      systems including SAP, Navision, Jira, MS-Project and many more. 
      Please <a href="http://www.project-open.com/en/contact">contact</a> us for more information.</p>
  </td>
</tr>
</table>

