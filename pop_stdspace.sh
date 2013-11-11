#!/bin/bash

#####
# Registers the T2 image to STD space, then transforms all sequences to it using SPM
#####

## Changelog
# 2013-11-07 fixed problem with SPM using sform instead of qform information
# 2013-11-06 added saveguard for when target file(s) already exist
# 2013-11-01 minor changes for bug-fixing
# 2013-10-31 created

# include shared information
source $(dirname $0)/include.sh

# main code
tmpdir=`mktemp -d`

for i in "${images[@]}"; do
	log 2 "Processing case ${i}" "[$BASH_SOURCE:$FUNCNAME:$LINENO]"
	mkdircond ${stdspace}/${i}

	# continue if target file already exists (making assumption from T2 to all sequences)
	if [ -f "${stdspace}/${i}/t2_sag_tse.${imgfiletype}" ]; then
		continue
	fi

	log 2 "Unpacking original images to .nii format and correct sform" "[$BASH_SOURCE:$FUNCNAME:$LINENO]"
	for seq in "${sequences[@]}"; do
		cmd="${scripts}/correct_sform.py ${originals}/${i}/${seq}.${imgfiletype} ${tmpdir}/${seq}.nii"
		$cmd
	done

	log 2 "For T2 sequence, use isospaced image instead" "[$BASH_SOURCE:$FUNCNAME:$LINENO]"
	cmd="${scripts}/correct_sform.py ${t2space}/${i}/t2_sag_tse.${imgfiletype} ${tmpdir}/t2_sag_tse.nii -f"
	$cmd

	log 2 "Create inverses of preliminary lesion mask in T2 space" "[$BASH_SOURCE:$FUNCNAME:$LINENO]"
	cmd="${scripts}/invert.py ${t2segmentations}/${i}.${imgfiletype} ${tmpdir}/_lesion_mask.nii"
	$cmd

	log 2 "Correct sforms of lesion mask" "[$BASH_SOURCE:$FUNCNAME:$LINENO]"
	cmd="${scripts}/correct_sform.py ${tmpdir}/_lesion_mask.nii ${tmpdir}/lesion_mask.nii"
	$cmd

	log 2 "Create and run SPM Normalize Estimate step" "[$BASH_SOURCE:$FUNCNAME:$LINENO]"
	cmd="${scripts}/make_spm_normalize_estimate.py ${tmpdir}/t2_sag_tse.nii ${tmpdir}/lesion_mask.nii ${tmpdir}/estimate.m"
	$cmd
	matlab -nodisplay -nosplash -nodesktop -r "addpath '${tmpdir}'; estimate;" > ${tmpdir}/log

	log 2 "Check whether registration seemed to have failed" "[$BASH_SOURCE:$FUNCNAME:$LINENO]"
	cmd="${scripts}/check_spm_normalize_estimate_log.py ${tmpdir}/log 15"
	$cmd

	log 2 "Create matlab scripts that modify the transformation parameters to include the inter-sequence registration performed by elastix and execute them" "[$BASH_SOURCE:$FUNCNAME:$LINENO]"
	for seq in "${sequences[@]}"; do
		if [ "${seq}" == "t2_sag_tse" ]; then
			continue
		fi
		cmd="${scripts}/prepare_combination_of_transformation_matrices.py ${t2space}/${i}/${seq}.txt ${tmpdir}/t2_sag_tse_sn.mat ${tmpdir}/${seq}_sn.mat ${tmpdir}/${seq}_combine.m"
		$cmd
		matlab -nodisplay -nosplash -nodesktop -r "addpath '${tmpdir}'; ${seq}_combine;" > /dev/null
	done

	log 2 "Create and run SPM Normalize Write / Warp step" "[$BASH_SOURCE:$FUNCNAME:$LINENO]"
	for seq in "${sequences[@]}"; do
		cmd="${scripts}/make_spm_normalize_write.py ${tmpdir}/${seq}.nii ${tmpdir}/${seq}_sn.mat ${tmpdir}/${seq}_warp.m"
		$cmd
		matlab -nodisplay -nosplash -nodesktop -r "addpath '${tmpdir}'; ${seq}_warp;" > /dev/null
	done

	log 2 "Move created images to the target directory" "[$BASH_SOURCE:$FUNCNAME:$LINENO]"
	for seq in "${sequences[@]}"; do
		cmd="medpy_convert.py ${tmpdir}/w${seq}.nii ${stdspace}/${i}/${seq}.${imgfiletype}"
		$cmd
	done

	emptydircond ${tmpdir}
done

rmdircond ${tmpdir}
log 2 "Done." "[$BASH_SOURCE:$FUNCNAME:$LINENO]"