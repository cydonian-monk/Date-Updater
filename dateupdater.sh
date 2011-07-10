#!/bin/bash
#
# dateupdater.sh - Updates Modified date of files in target directory.
#
# Copyright (C) 2011 Andrew W. Cummings
# 
# This program is free software: You can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#
# Usage: dateupdate.sh [TARGET [DATE]]
#        TARGET - Directory script will operate on.
#        DATE - Date in YYYYMMDD, YYYY-MM-DD, or YYYY/MM/DD format.
#
# Date Updater is used to update the last modified date of all files in the  
# a specified target directory.  If no date is provided, Date Updater will
# attempt to extract the date from the directory name.   
#
# Date Updater will only update the Modified Date if the Date is not
# specified on the command line and the current Modified Date of the target
# file is in the future.
#
# Date Updater is recursive by design.  All files under the TARGET directory, 
# including other directories and their files, will have their Modified date 
# altered.  Symbolic Links are ignored.
#
#
# Contributor(s): Andrew Cummings <cydonian.monk@gmail.com>
#
# Version | Date       | Author             | Note
# --------+------------+--------------------+----------------------------------
# 1.0     | 2011/07/10 | Andrew Cummings    | Initial version.
#
# See README for detailed release notes.
#


# Variable Declarations

DU_VERSION="1.0"
DU_VERSION_DATE="2011/07/10"
DU_USAGE="\nUsage: dateupdate.sh [TARGET [DATE]] \n    TARGET - Directory script will operate on. \n    DATE - Date in YYYYMMDD, YYYY-MM-DD, or YYYY/MM/DD format."

DU_TARGET=$1
DU_DATE=$2

DU_WORKING_DATE=""
DU_UPDATED=0
DU_SKIPPED=0
DU_IGNORED=0

# Function Declarations

# function: Extract Date
function extract_date () {
    local L_DU_EXTRACT_DATE=""

    # Attempt to extract the date from the directory name.
    L_DU_EXTRACT_DATE=$(expr match "`basename $1`" "\([0-9]\{8\}\)") 

    # If no date was extracted from the directory, leave unchanged.
    if [ "$L_DU_EXTRACT_DATE" != "" ] ; then
        DU_WORKING_DATE=$L_DU_EXTRACT_DATE
    fi
}

# function: Update File
function update_file () {
    # Only update a file if we have a target date.
    if [ "$2" == "" ] ; then
        echo "? Skipped: No date available for $1."
	DU_SKIPPED=$[DU_SKIPPED+1]
	return
    fi

    # Only update if the target date is valid.
    date -d $2 > /dev/null
    if test $? -ne 0; then
        echo "! Skipped: Invalid date $2."
	DU_SKIPPED=$[DU_SKIPPED+1]
        return
    fi

    # Sanity Checking: We check the Last Modified date to make sure
    # we're only updating files with dates in the (target's) future.
    if [ "$DU_DATE" == "" ] ; then
        local L_DU_DATE_MODIFY=""
        local L_DU_DATE_CURRENT=""
        local L_DU_DATE_TARGET=""
        #L_DU_DATE_MODIFY=$(expr substr "`stat --format=%y $1`" 1 10 | sed 's/-//g')
	L_DU_DATE_MODIFY=$(date -r $1 +%Y%m%d)
	L_DU_DATE_CURRENT=$(date -d "$L_DU_DATE_MODIFY" +%s)
	L_DU_DATE_TARGET=$(date -d "$2" +%s)
	if [ $L_DU_DATE_CURRENT -le $L_DU_DATE_TARGET ] ; then
            echo "- Skipped $1 with mod $L_DU_DATE_MODIFY vs $2."
            DU_SKIPPED=$[DU_SKIPPED+1]
            return
	fi
    fi

    # Update the Modified timestamp of the file.
    if touch $1 -md $2 ; then
        echo "+ Updating $1 with date $2" 
        DU_UPDATED=$[DU_UPDATED+1]
    else
        echo "! Skipped: touch exited with non-zero return code!"
        DU_SKIPPED=$[DU_SKIPPED+1]
    fi
}

# function: Process File
function process_file () {
    local L_DU_WORKING_DATE=""

    # If we were provided a date on the command line, use only that.
    if [ "$DU_DATE" != "" ] ; then
        DU_WORKING_DATE=$DU_DATE
    else
        extract_date $1
    fi

    L_DU_WORKING_DATE=$DU_WORKING_DATE
    for file in $(find -P $1 -maxdepth 1 -mindepth 0) ; do
        # Ignore Symbolic Links
	if test -L $file ; then
	    DU_IGNORED=$[DU_IGNORED+1]
	    continue
	fi

        # Recursively process directories, except self.
	if [ "$file" != "$1" ] ; then
            if test -d $file ; then
	        process_file $file
		continue
	    fi
	fi
        update_file $file $L_DU_WORKING_DATE
    done
}


# Script Main

echo "Date Updater ver $DU_VERSION rev $DU_VERSION_DATE"

if [ "$DU_TARGET" == "" ] ; then
    DU_TARGET=$(pwd)
fi

if test -d $DU_TARGET ; then
    echo "   Target : $DU_TARGET"
else
    echo "! Error: TARGET must be a Directory."
    echo -e "$DU_USAGE"
    exit 1
fi

if [ "$DU_DATE" != "" ] ; then
    if [ `expr match "$DU_DATE" "[0-9]\{4\}[/-][0-9]\{2\}[/-][0-9]\{2\}\|[0-9]\{8\}"` -gt 0 ] ; then
        echo "   Date   : $DU_DATE"
    else
        echo "! Error: Invalid Date Format."
	echo -e "$DU_USAGE"
	exit 1
    fi
fi

echo " "

process_file $DU_TARGET

echo " "
echo "Date Updater Finished."
echo "Files Updated : $DU_UPDATED"
echo "Files Skipped : $DU_SKIPPED"
echo "Files Ignored : $DU_IGNORED"
exit 0


