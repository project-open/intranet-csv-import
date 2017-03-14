<master>
<property name="doc(title)">@page_title;literal@</property>
<property name="context">@context_bar;literal@</property>
<property name="main_navbar_label">@main_navbar_label;literal@</property>

<form enctype="multipart/form-data" method=POST action="import-@redirect_object_type@.tcl">
<%= [export_vars -form {object_type return_url import_filename}] %>

<if @object_type@ eq im_hour>
    <h2>Settings</h2>
    <table cellpadding="0" cellspacing="0" border="0">
    <tr>
	<td valign="top"><input type="checkbox" name="merge_p" value="1" checked/>&nbsp;</td>
	<td valign="top"><strong>Merge?</strong><br/>If checked, import hours will be added to already existing hours found on target server. <br/>If 'unchecked', existing hours will be overwritten</td>
    </tr>
    <tr>
	<td valign="top"><input type="checkbox" name="test_run_p" value="1" checked>&nbsp;</td>
	<td valign="top"><strong>Test Run?</strong><br/>Uncheck to perform an import, otherwise import will be done in test mode and no data will be written to the DB</td>
    </tr>
    <tr>
        <td valign="top"><input type="checkbox" name="output_device_log" value="file">&nbsp;</td>
        <td valign="top"><strong>Redirect to file?</strong><br/>Uncheck to redirect log messages to file in default tmp directory</td>
    </tr>
    </table>
</if> 
<if @object_type@ eq person>

    <%
    foreach profile_tuple [im_profile::profile_options_all] {
            set profile_name [lindex $profile_tuple 0]
	    regsub -all {\[} $profile_name {} profile_name
	    regsub -all {\]} $profile_name {} profile_name
	    set profile_arr($profile_name) [lindex $profile_tuple 1]
    }

    %>
    <table cellpadding="5" cellspacing="5" border="0">
	<tr>	   
    		<td>	   
		<h2>Settings:</h2>
		<table cellpadding="0" cellspacing="0" border="0">
		    <tr>
		        <td valign="top"><input type="checkbox" name="overwrite_existing_user_attributes_p" value="1">&nbsp;</td>
		        <td valign="top"><strong>Should already existing user attributes be overwritten?</strong><br/>Check to overwrite.</td>
		    </tr>
		    </table>
		</td>
		<td>
		<h2>Please note:</h2>
			<ul><li>Accepted ]po[ Profiles: <%=[array names profile_arr]%></li></ul>		
		</td>
    	</tr>
    </table>

</if>

<if @object_type@ eq im_company>
    <table cellpadding="5" cellspacing="5" border="0">
	<tr>	   
    		<td>	   
		<h2>Settings:</h2>
		<table cellpadding="0" cellspacing="0" border="0">
		    <tr>
		        <td valign="top"><input type="checkbox" name="overwrite_existing_company_attributes_p" value="1">&nbsp;</td>
		        <td valign="top"><strong>Should already existing company attributes be overwritten?</strong><br/>Check to overwrite.</td>
		    </tr>
		    </table>
		</td>
		<!-- 
		<td>
		<h2>Please note:</h2>
			<ul><li></li></ul>		
		</td>
		-->
    	</tr>
    </table>

</if>


<if @object_type@ eq im_invoice>
    <table cellpadding="5" cellspacing="5" border="0">
	<tr>	   
    		<td>	   
		<h2>Settings:</h2>
		<table cellpadding="0" cellspacing="0" border="0">
		    <tr>
		        <td valign="top"><input type="checkbox" name="overwrite_existing_invoice_attributes_p" value="1">&nbsp;</td>
		        <td valign="top"><strong>Should already existing invoice attributes be overwritten?</strong><br/>Check to overwrite.</td>
		    </tr>
		    </table>
		</td>
		<!-- 
		<td>
		<h2>Please note:</h2>
			<ul><li></li></ul>		
		</td>
		-->
    	</tr>
    </table>

</if>

<if @object_type@ eq im_expense_bundle>
    <table cellpadding="5" cellspacing="5" border="0">
        <tr>
                <td>
                <h2>Settings:</h2>
                <table cellpadding="0" cellspacing="0" border="0">
                    <tr>
                        <td valign="top"><input type="checkbox" name="overwrite_existing_expense_bundles_p" value="1">&nbsp;</td>
                        <td valign="top"><strong>Should already existing invoice attributes be overwritten?</strong><br/>Check to overwrite.</td>
                    </tr>
                    </table>
                </td>
                <!--
                <td>
                <h2>Please note:</h2>
                        <ul><li></li></ul>
                </td>
                -->
        </tr>
    </table>

</if>


<if @object_type@ eq im_expense>
    <table cellpadding="5" cellspacing="5" border="0">
        <tr>
                <td>
                <h2>Settings:</h2>
                <table cellpadding="0" cellspacing="0" border="0">
                    <tr>
                        <td valign="top"><input type="checkbox" name="overwrite_existing_expense_item_attributes_p" value="1">&nbsp;</td>
                        <td valign="top"><strong>Should already existing expense attributes be overwritten?</strong><br/>Check to overwrite.</td>
                    </tr>
                    </table>
                </td>
                <!--
                <td>
                <h2>Please note:</h2>
                        <ul><li></li></ul>
                </td>
                -->
        </tr>
    </table>

</if>



<br/>
<h2>Mapping</h2>
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
</form>

