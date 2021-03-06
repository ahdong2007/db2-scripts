 #!/bin/bash

#     get_mem.sh
#     Copyright (C) 2016 Mason Hua

#     This program is free software; you can redistribute it and/or modify
#     it under the terms of the GNU General Public License as published by
#     the Free Software Foundation; either version 2 of the License, or
#     (at your option) any later version.

#     This program is distributed in the hope that it will be useful,
#     but WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#     GNU General Public License for more details.

#     You should have received a copy of the GNU General Public License along
#     with this program; if not, write to the Free Software Foundation, Inc.,
#     51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

#     This is script is use to view how much memory is used by DB2
#     Usage: get_mem.sh sample_db
#

db2 get dbm cfg show detail | grep INSTANCE_MEMORY

db2pd -dbptnmem

db2 get snapshot for applications on $1

db2mtrk -a
db2mtrk -p

db2pd -mempools
db2pd -memsets