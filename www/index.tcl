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

