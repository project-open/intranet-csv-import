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
	      im_company "Company" \
	      im_conf_item "Configuration Item" \
	      im_project "Project" \
	      im_risk "Risk" \
	      im_hour "Timesheet Hour" \
	      im_timesheet_task "Timesheet Task" \
	      im_membership "Membership" \
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
  <td colspan=4>
    <p>Please find below sample CSV files for each of the object types above.</p>
    <p>Each file contains a list of column names in the first row. 
       Column names are case insensitive and spaces may be replaced by "_" (underscore characters).</p>
  </td>
</tr>

<tr>
  <th colspan=2><nobr>Object Type</nobr></th>
  <th><nobr>Example CSV</nobr></th>
  <th>Available Column Headers</th>
</tr>

<tr>
  <td><%= [im_gif [db_string gif "select object_type_gif from acs_object_types where object_type = 'im_user_absence'"]] %></td>
  <td>Absence</td>
  <td align=center>
  </td>
  <td>
    Absence import is under active development at the moment.<br>
    Please <a href="http://www.project-open.com/en/contact">contact us</a> for the current status or updates.
  </td>
</tr>

<tr>
  <td><%= [im_gif [db_string gif "select object_type_gif from acs_object_types where object_type = 'im_company'"]] %></td>
  <td>Company</td>
  <td align=center>
    <a href="examples/im_company.csv"><%= [im_gif zip-download] %></a>
  </td>
  <td>
    Company Name, Company Path, Company Status, Company Type, Primary Contact, Accounting Contact, Note, VAT Number, 
    Phone, Fax, Address Line1, Address Line2, Address City, Address State, Address Postal Code, Address Country Code, 
    Default Payment Days, Default VAT.<br>
    Company <a href="/intranet-dynfield/object-type?object_type=im_company">DynFields</a> 
    are also recognized by their "pretty name" or "column name".</p>
  </td>
</tr>

<tr>
  <td><%= [im_gif [db_string gif "select object_type_gif from acs_object_types where object_type = 'im_conf_item'"]] %></td>
  <td>Conf Item</td>
  <td align=center>
    <a href="examples/im_conf_item.csv"><%= [im_gif zip-download] %></a>
  </td>
  <td>
    Please note that this import requires exact naming of column headers.<br>
    Conf Item Parent Nrs, Conf Item Name, Conf Item Code, Conf Item Nr, Conf Item Status, Conf Item Type, IP Address, 
    Conf Item Owner, Conf Item Cost Center, Description, Note<br>
    Conf Item <a href="/intranet-dynfield/object-type?object_type=im_conf_item">DynFields</a> 
    are also recognized by their "pretty name" or "column name".</p>
  </td>
</tr>

<tr>
  <td><%= [im_gif [db_string gif "select object_type_gif from acs_object_types where object_type = 'im_invoice'"]] %></td>
  <td>Financial Items</td>
  <td align=center>
  </td>
  <td>
    Financial Items import is under active development at the moment.<br>
    Please <a href="http://www.project-open.com/en/contact">contact us</a> for the current status or updates.
  </td>
</tr>

<tr>
  <td><%= [im_gif [db_string gif "select object_type_gif from acs_object_types where object_type = 'person'"]] %></td>
  <td>Person</td>
  <td align=center>
  </td>
  <td>
    Person import is under active development at the moment.<br>
    Please <a href="http://www.project-open.com/en/contact">contact us</a> for the current status or updates.
    Meanwhile, please use the old facilities for 
    <a href="<%= [export_vars -base "/intranet/users/upload-contacts" {return_url}] %>">importing users from MS-Outlook exports</a>.
  </td>
</tr>

<tr>
  <td><%= [im_gif [db_string gif "select object_type_gif from acs_object_types where object_type = 'im_project'"]] %></td>
  <td>Project</td>
  <td align=center>
    <a href="examples/im_project.csv"><%= [im_gif zip-download] %></a>
  </td>
  <td>
    Parent Nrs, Project Nr, Project Name, Customer Name, Project Status, Project Type, Start Date, End Date, 
    Percent Completed, On Track Status, Budget, Budget Hours, Priority, Note, Project Manager, Description.<br>
    Project <a href="/intranet-dynfield/object-type?object_type=im_project">DynFields</a> 
    are also recognized by their "pretty name" or "column name".</p>
  </td>
</tr>

<tr>
  <td><%= [im_gif [db_string gif "select object_type_gif from acs_object_types where object_type = 'im_risk'"]] %></td>
  <td>Risk</td>
  <td align=center>
    <a href="examples/im_risk.csv"><%= [im_gif zip-download] %></a>
  </td>
  <td>
    Risk Project Parent Nrs, Risk Name, Risk Probability, Risk Impact, Risk Status, Risk Type, Risk Description, 
    Risk Mitigation Plan<br>
    Risk <a href="/intranet-dynfield/object-type?object_type=im_risk">DynFields</a> 
    are also recognized by their "pretty name" or "column name".</p>
  </td>
</tr>

<tr>
  <td><%= [im_gif hourglass] %></td>
  <td>Timesheet Hour</td>
  <td align=center>
    <a href="examples/im_hour.csv"><%= [im_gif zip-download] %></a>
  </td>
  <td>
    Hour Project Parent Nrs, Hour Name, Hour Probability, Hour Impact, Hour Status, Hour Type, Hour Description<br>
    DynFields for hours are not supported.
  </td>
</tr>

<tr>
  <td><%= [im_gif [db_string gif "select object_type_gif from acs_object_types where object_type = 'im_ticket'"]] %></td>
  <td>Tickets</td>
  <td align=center>
  </td>
  <td>
    Tickets import is under active development at the moment.<br>
    Please <a href="http://www.project-open.com/en/contact">contact us</a> for the current status or updates.
  </td>
</tr>

<tr>
  <td colspan=4>
    <p>The ]project-open[ team offers professional services to help you import data from
      systems including SAP, Navision, Jira, MS-Project and many more. 
      Please <a href="http://www.project-open.com/en/contact">contact</a> us for more information.</p>
  </td>
</tr>
</table>

