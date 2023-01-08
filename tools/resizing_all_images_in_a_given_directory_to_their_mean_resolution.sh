#!/bin/bash
# This script resizes all images in a given directory to their mean resolution

#Set Path to Images
dir="$1"
[[ ! -d $dir ]] \
&& echo "Please provide the directory containing the images to be resized (e.g. /home/user/myimages):" \
&& read dir

# if directory is not specified, use the current directory
if [ -z "$dir" ]; then
    echo "ERROR"
    exit 1
fi

# get list of all images in directory
images=$(ls $dir | grep -E "\.(jpg|jpeg|png|gif)$")

# calculate mean resolution
resolutions=()

for image in $images; do
    # get resolution of image
    resolution=$(identify -format "%wx%h" $dir/$image)
    # add to array
    resolutions+=($resolution)
done

# calculate mean resolution
sum=0
for resolution in ${resolutions[@]}; do
    # add resolutions
    sum=$(echo "$sum + $(echo $resolution | cut -d'x' -f1)" | bc)
done

mean_width=$(echo "$sum / ${#resolutions[@]}" | bc)
mean_height=$(echo "$sum / ${#resolutions[@]}" | bc)

# resize images
for image in $images; do
    convert $dir/$image -resize $mean_width"x"$mean_height $dir/$image
    echo "Resized $dir/$image to $mean_width x $mean_height"
done
