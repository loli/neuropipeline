#!/bin/bash

#####
# Tranform all segmentation binary images to T2 space.
#####

## Changelog
# 2013-11-06 added an additional step, correcting precision errors in the image header
# 2013-11-05 optimized
# 2013-10-21 created

# include shared information
source $(dirname $0)/include.sh

# main code
log 2 "Tranforming all expert segmentation to T2 space" "[$BASH_SOURCE:$FUNCNAME:$LINENO]"
tmpdir=`mktemp -d`
for i in "${images[@]}"; do

	# continue if target file already exists
	if [ -f "${t2segmentations}/${i}.${imgfiletype}" ]; then
		continue
	fi

	# edit transformation file (strange, array using syntax, since otherwise quotes '' are passed to sed)
	command=(sed -e 's/(FinalBSplineInterpolationOrder 3)/(FinalBSplineInterpolationOrder 0)/g' -e 's/(ResultImagePixelType \"float\")/(ResultImagePixelType \"char\")/g' "${t2space}/${i}/flair_tra.txt")
	#echo "Command: \"${command[*]}\""
	"${command[@]}" > "${tmpdir}/tf.txt"

	# run transformation
	cmd="transformix -out ${tmpdir} -tp ${tmpdir}/tf.txt -in ${segmentations}/${i}.${imgfiletype}"
	$cmd > /dev/null

	# copy transformed binary segmentation file
	cmd="mv ${tmpdir}/result.${imgfiletype} ${t2segmentations}/${i}.${imgfiletype}"
	$cmd

	# adapt header, as eslatix seems to use another precision, which might lead to error later
	cmd="${scripts}/pass_header.py ${t2segmentations}/${i}.${imgfiletype} ${t2space}/${i}/t2_sag_tse.${imgfiletype}"
	$cmd

	emptydircond ${tmpdir}
done
rmdircond ${tmpdir}
log 2 "Done." "[$BASH_SOURCE:$FUNCNAME:$LINENO]"