#!/bin/bash
#check if adb is installed


STORAGE_ROOT="/sdcard"
DCIM_PATH="DCIM"
CAMERA_PATH=$STORAGE_ROOT"/"$DCIM_PATH"/Camera"
if ! command -v adb &> /dev/null
then
    echo "adb could not be found, please install it"
    exit
fi
echo "Check for devices..."
output_string=`adb devices`
cut_output_string="List of devices attached"
devices=${output_string#"$cut_output_string"}

#check if device is connected 

if [ ${#devices} -le 0 ]
then
    echo "Connect a device, or enable USB debugging!"
    exit
fi
is_range_index(){
    ind=$1
    res=0
    if [[ $ind != *"-"* ]] 
    then
        res=1
    fi
    echo $res
}

sanity_check(){
    indexes=$1
    max_index=$2
    res=0
    for ind in ${indexes[@]}
    do
        if [[ `is_range_index $ind` == 0 ]] 
        then
            if (( `echo $1 | cut -d "-" -f1` >= $2 || `echo $1 | cut -d "-" -f2` >= $2 )) #check range index
            then
                res=1
                break
            fi
        fi
        if (( $ind >= $max_index )) #check normal index
        then
            res=1
            break
        fi
    done
    echo $res
}
static_pull(){
    local -n files_path=$1
    dest_path=$2
    echo "Pulling files..."
    for _path in ${files_path[@]}
    do
         adb pull "$_path" $dest_path
    done
} >&2
pull_files(){   
    local -n files_path=$1 #number of index
    dest_path=$2
    local -n indexes=$3
    out=""
    for ind in ${indexes[@]}
    do
        if [[ `is_range_index $ind` == 0 ]] 
        then
            first=`echo $ind | cut -d "-" -f1`
            second=`echo $ind | cut -d "-" -f2`
            for i in $(seq $first 1 $second) #pull range files
            do
                adb pull "${files_path[$i]}" $dest_path
            done
        else
            _path="${files_path[$ind]}"
            [ -d "${files_path[$ind]}" ] && echo _path="${files_path[$ind]}/."
            adb pull "$_path" $dest_path #pull single file or directory recursively
        fi
    done

} >&2
while true; do
    echo "Type quit to close the script"
    echo "Insert a destination path where save files"
    read dest_path
    echo "Menu. 1. Backup camera only. 2. Backup all photo and video 3. Choose files or directory 4. All files in phone " #tasks
    read choice
    case $choice in
    1)
    file_res=($CAMERA_PATH)
    static_pull file_res $dest_path
    ;;
    2)
    MEDIA_EXT=(".jpg",".png",".avi",".mp3",".mp4",".mkv",".webm",".gif",".gifv")
    res=`adb shell find /sdcard/\*`

    echo "Not available yet" ;;
    3)
    read -p 'Type a filename or a part of file to find: ' filename
    [[ $filename == "quit" ]] && exit 1
    declare -a file_res
    readarray -t file_res <<< $(adb shell find /sdcard/\* -name "*${filename}*")
    printf "%s\n" "${file_res[@]}"
    l=${#file_res[@]}
    if [ $l -gt 0 ]
    then
        echo "Insert a number or numbers separated by ',' from 0 to" $((l-1)) "for select a files to pull" 
        read line
        
        declare -a f_indexes
        if [[ $line =~ ^[0-9]+((,|-)[0-9]+)*$ ]]
        then
            if [[ $line == *","* || $line == *"-"* ]]
            then
                f_indexes=(`echo $line | tr ',' ' '`)
            else
                f_indexes=($line)
            fi
            if (( $(sanity_check ${f_indexes[@]} $l) == 0 )) #check if one index exceed the lines length
            then
                if [[ ! -d $dest_path ]]
                then 
                    echo "Directory" $dest_path "doesn't exists."
                else
                    pull_files file_res $dest_path f_indexes
                fi
            else
                echo "One or more index exceed the number of files found"
            fi
        fi
    else
        echo "Not" $filename "file or directory found in device"
    fi
    ;;
    4)
    file_res=($STORAGE_ROOT)
    static_pull file_res $dest_path
    ;;
    esac
done