#!/bin/bash

function print_help()
{
  echo "usage: watermark.sh -i <infile> [-o outfile]"
  echo "  if outfile is omitted '_WM' is appended to the input filename"
  echo "  run this on multiple files like so:"
  echo "    ls | xargs -i -t watermark.sh -i {}"
}

identify=/usr/bin/identify
convert=/usr/bin/convert
outpath=''
fappend='_WM' # append to filename
ratio=150 # expected ratio (6x4" photo) multiplied by 100 to avoid floating point
# dividers to calculate optimal font size and margins using pixel dimensions
# this is optimised to use 72pt for a 15mpix image
psizewx=68 # divide width by this to get pointsize
psizehx=45 # divide height by this to get pointsize
marginwx=28 # divide width by this to get marginw ~ 3.7%
marginhx=26 # divide height by this to get marginh ~ 3.8%

if [ $# -eq "0" ]; then
	print_help
	exit 2 
fi
POSITIONAL=()
while [[ $# -gt 0 ]]; do
key="$1"
case $key in
	-h|--help|-\?)
		print_help
		exit 0
		;;
	-i)
		inpath=$2
		shift # past argument
		shift # past value
		;;
	-o)
		outpath=$2
		shift # past argument
		shift # past value
		;;
	*) # unknown option
		POSITIONAL+=("$1") # save it in array for later
		shift # past argument
		;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters
if [[ -n $1 ]]; then
    echo "Last line of file specified as non-opt/last argument:"
    tail -1 "$1"
fi
if [[ -z $outpath ]]; then
	# append to filename
	fname=${inpath%.*} # filename without extension
	fext=${inpath##*.} # file extension
	outpath=$fname''$fappend'.'$fext
fi
	#file=${inpath##*/} # filename without full path
echo $inpath
echo $outpath
#if [ $# -eq "2" ]; then
#	outdir="$2"
#fi

#idate=`identify -format '%[EXIF:DateTimeOriginal]' "$inpath" | awk '{print $1}' | tr ':' '-'`
ident=$($identify -format '%w %h %[EXIF:DateTimeOriginal]' "$inpath")
imagew=$(echo "$ident" | cut -f1 -d' ')
imageh=$(echo "$ident" | cut -f2 -d' ')
if [ "$imagew" -gt "$imageh" ]; then
	ilong=$imagew
	ishort=$imageh
	portrait=false
else
	ilong=$imageh
	ishort=$imagew
	portrait=true
fi
idate=$(echo "$ident" | cut -f3 -d' ' | tr ':' '-')
#iratio=$(echo "$imageh / $imagew" | bc -l)
iratio=$(( 100 * $ilong / $ishort ))

# if the image ratio is not exactly $ratio then the image will be cropped when it is printed.
# Here we adjust the annotation margins to account for the expected crop factor.

# image is too high, use long side to calculate fontsize and extend margin
if [ "$iratio" -le "$ratio" ]; then
	psize=$(( $ilong / $psizewx ))
	marginw=$(( $ilong / $marginwx ))
	marginh=$(( $ishort / $marginhx ))
	madjust=$(( ($ishort - (100*$ilong / $ratio )) / 2 ))
	if [ "$portrait" = true ]; then
		marginw=$(( $marginw + $madjust ))
	else
		marginh=$(( $marginh + $madjust ))
	fi
fi
# image is too wide, use short side to calculate fontsize and extend margin
if [ "$iratio" -gt "$ratio" ]; then
	psize=$(( $ishort / $psizehx ))
	marginw=$(( $ilong / $marginwx ))
	marginh=$(( $ishort / $marginhx ))
	madjust=$(( ($ilong - ($ishort * $ratio/100 )) / 2 ))
	if [ "$portrait" = true ]; then
		marginh=$(( $marginh + $madjust ))
	else
		marginw=$(( $marginw + $madjust ))
	fi
fi


echo "ratio: $iratio/100; psize: $psize +$marginw+$marginh"

# annotate with white text stroked in black
# bottom-left is filename without extension
# bottom-right is EXIF date
# use mogrify instead of convert to overwrite files
$convert "$inpath" -auto-orient -gravity SouthEast -font Helvetica-Bold -pointsize $psize \
-stroke black -strokewidth 10 -annotate +$marginw+$marginh $idate \
-stroke none -fill white -annotate +$marginw+$marginh $idate \
-gravity SouthWest \
-stroke black -strokewidth 10 -annotate +$marginw+$marginh '%t' \
-stroke none -fill white -annotate +$marginw+$marginh '%t' \
"$outpath"
