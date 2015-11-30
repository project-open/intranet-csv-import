<master>
<property name="doc(title)">@page_title;literal@</property>
<property name="context">@context_bar;literal@</property>
<property name="main_navbar_label">@main_navbar_label;literal@</property>

<script type="text/javascript">
$(document).ready(function() {

    // Initialize
    $('#@form_id;literal@').sayt({'days': 180});

    // if($('#@form_id;literal@').sayt({'checksaveexists': true}) == true)
    //	{ console.log('Form has an existing save cookie.'); } else { console.log('No cookie found'); };

    // Do not save the hidden fields 
    $('#@form_id;literal@').sayt({'exclude': 
    	[
		'[name=return_url]', 
		'[name=object_type]', 
		'[name=import_filename]'
	]
    });

    $('#forms_delete_save_button').click(function() {
    	$('#@form_id@').sayt({'erase': true});
        console.log('Form cookie was deleted.');
        alert('Saved settings have been deleted');
        return false;
    });
});
</script>

<form enctype="multipart/form-data" method=POST action="import-@redirect_object_type@.tcl" id="@form_id@">
<%= [export_vars -form {object_type return_url import_filename}] %>


<if @object_type;literal@ eq im_hour>
    <table cellpadding="0" cellspacing="0" border="0">
    <tr>
	<td><input type="checkbox" name="merge_p" /></td>
	<td>If checked, import hours will be added to already existing hours found on target server.</td>
    </tr>
    <tr>
	<td><input type="checkbox" name="test_run_p" checked></td>
	<td>Uncheck to perform a real run</td>
    </tr>
    </table>
</if> 

     <table>
     <tr clas=rowtitle>
     <td class=rowtitle>Field Name</td>
     <td class=rowtitle>Row 1</td>
     <td class=rowtitle>Row 2</td>
     <td class=rowtitle>Row 3</td>
     <td class=rowtitle>Row 4</td>
     <td class=rowtitle>Map to Field</td>
     <td class=rowtitle>Transformation</td>
     <td class=rowtitle>Parameters</td>
     </tr>

     <multiple name=mapping>

     <if @mapping.rownum@ odd><tr class="list-odd"></if>
     <else><tr class="list-even"></else>

     <td>@mapping.field_name@ @mapping.column;noquote@</td>
     <td>@mapping.row_1@</td>
     <td>@mapping.row_2@</td>
     <td>@mapping.row_3@</td>
     <td>@mapping.row_4@</td>
     <td>@mapping.map;noquote@</td>
     <td>@mapping.parser;noquote@</td>
     <td>@mapping.parser_args;noquote@</td>
     </tr>
     </multiple>
     </table>

     <table>
<!--
     <tr>
     <td>Save Mapping as:</td>
     <td><input type="text" name="mapping_name"></td>
     </tr>
-->
     <tr>
     <td></td>
     <td><input type="submit" value="<%= [lang::message::lookup "" intranet-csv-import.Import_CSV "Import CSV"] %>"></td>
     </tr>
     </table>
<p>
The mapping showing up on this page will be saved as-you-type to simplify the import process.<br/>
This allows you to go back, reload the file without loosing your mapping settings.<br/>
To erase the savings, please click <span id="forms_delete_save_button" style="text-decoration:underline;cursor:pointer"	>here</span>.
</p>
</form>

