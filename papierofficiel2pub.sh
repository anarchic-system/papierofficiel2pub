#!/bin/sh

##
## Usage info
##
show_help() {
cat << EOF
Usage: ${0##*/} [-hv] -s STAMPFILE -i INFILE [-o OUTFILE]
Prepare INFILE to be made public by applying some filters and a watermarking provided by STAMPFILE.

    -h           display this help and exit
    -v           verbose mode
    -s STAMPFILE file with the stamp to use to watermark OUTFILE
    -i INFILE    papier officiel file that must be made public
    -o OUTFILE   papier officiel file ready to be shared
If OUTFILE is missing, $0 is postfixing INFILE with '-public'
Depends on:
- ImageMagick (convert & composite)
- bc
- mktemp.
EOF
}

##
## Variables
##
## stamp to use for watermarking the copy
path_stamp=./stamp-watermarking-copy-BURP.png
## document to make a public copy of
path_image_in=
dir_image_in=
## path of the produced public copy
##  default = $(path_image_in)-public
path_image_out=
## maximum size for the public version
image_out_size_max=2097152

## temp dir
#TMP="${TMPDIR:=/tmp}/po2pub_$$"
#mkdir "$TMP"
TMP="$(mktemp -d)"
#TMP="$(mktemp -dt $0.XXXXXX)"


## Handle exit signal and cleaning
##  FIXME- does not work? -FIXME
trap 'rm -rf "$TMP" >/dev/null 2>&1' 0
trap "exit 2" 1 2 3 13 15

##
## Handle options
##
while getopts "hs:i:o:" opt; do
	case $opt in
		h)
			show_help
			exit 0
			;;
		s)
			path_stamp=$OPTARG
			echo "Stamp to use for watermarking is: $path_stamp" >&2
			;;
		i)
			path_image_in=$OPTARG
			echo "Input / Papier officiel to make public is: $path_image_in" >&2
			## set default value for $path_image_out if -o option is not provided
			dir_image_out=$(dirname "$path_image_in")
			filename_image_out=$(basename "$path_image_in" | cut -d. -f1)-public.png
			path_image_out=$dir_image_out/$filename_image_out
			;;
		o)
			path_image_out=$OPTARG
			echo "Output / Public version of papier officiel is: $path_image_out" >&2
			;;
		\?)
			echo "Invalid option: -$OPTARG" >&2
			show_help
			exit 1
			;;
		:)
			echo "Option -$OPTARG requires an argument." >&2
			exit 1
			;;
	esac
done

#echo "dir_image_out is: $dir_image_out"
#echo "filename_image_out is: $filename_image_out"
#echo "path_image_out is: $path_image_out"
#echo "TMP is: $TMP"
#exit 12

##
## Reduce size below $(image_out_size_max) bytes
##
##  input:
##  - $path_image_in
## output
##  - $TMP/papierofficiel2pub-reduced.png
convert \
	$path_image_in \
	-colorspace RGB \
	-filter Triangle \
	-distort Resize $(echo "scale=12; sqrt($image_out_size_max/$(wc -c < $path_image_in))*100" | bc)% \
	-colorspace sRGB \
	$TMP/papierofficiel2pub-reduced.png


##
## Apply photocopy filter
##
## input:
##  - $TMP/papierofficiel2pub-reduced.png
## output:
##  - $TMP/papierofficiel2pub-photocop.png
convert \
	$TMP/papierofficiel2pub-reduced.png \
	-colorspace gray \
	-contrast-stretch 10%x0% \
	\( +clone -blur 0x2 \) \
	\+swap \
	-compose divide \
	-composite \
	$TMP/papierofficiel2pub-photocop.png
rm "$TMP/papierofficiel2pub-reduced.png"


##
## Apply watermarking
##
## input:
##  - $TMP/papierofficiel2pub-photocop.png
##  - $path_stamp
## output:
##  - $path_image_out

composite \
	-tile $path_stamp \
	$TMP/papierofficiel2pub-photocop.png \
	$path_image_out
rm "$TMP/papierofficiel2pub-photocop.png"
rmdir "$TMP"
