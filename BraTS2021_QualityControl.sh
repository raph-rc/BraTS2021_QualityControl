#!/bin/bash

#Script to iterate through BraTS2021 dataset to identify useable ground truth segmentation labels

#"Useable labels" are labels with accurately segmented edema, enhancing tumour tissue, and non-enhancing tumour tissue (both necrosis and non-enhancing tissue) labels

#This script iterates through samples of BraTS2021, displays three slices - Slice #1 at the center of mass of the labelled tumour, Slice #2 above the enter of mass of the labelled tumour, Slice #3 below the enter of mass of the labelled tumour

#Each slice is displayed in each available contrast to the user (T1, T2, T1-gadolinium contrast enhanced, and FLAIR) using mincpik

#The user can use key commands to iterate through samples, adding samples to either the "good" or the "bad" folders. The user\s choice is stored in the CSV file.
#The user can go back to the previous selection using key command if an error was made.

#Done:
#: Only have one window open at a time - done
#: Get slices to always show tumour - done
#: Save the points when you generate for the first time so it becomes a lot faster as you go (hopefully) - done
#: Add the 'good' and "bad" keyboard commands and make sure you can undo, iterate through subsets, etc.
#: Toggle the crosshairs - works a little slow
#: Check file type (could be .mnc)
#: Slow! Make faster = ~3 seconds per rendering
#: Maybe add labels to the grid
#: Verify order of labels
#: Stop FLAIR with overlay from getting so dark - trade off between clarity of label 
#: Make sure it could work on OS or Windows - hasn't been tested but should run on Windows

#TODO:

#COULDDO: maybe make it go back to first index when iterating?
#TODO: Useage documentation / commenting / clean up 

declare -a current_files
declare -i total
declare -i current
show_crosshairs=true

refresh_files() {
    if [[ "$filter_mode" == "all" ]]; then
        current_files=("${files[@]}")
    else
        # Read files with matching status into array
        current_files=()
        while IFS=',' read -r filename status rest; do
            if [[ "$status" == "$filter_mode" ]]; then
                current_files+=("$filename")
            fi
        done < <(tail -n +2 "$CSV_TRACKING")
    fi
    
    total=${#current_files[@]}
    
    if [[ $total -eq 0 ]]; then
        echo "No files match filter: $filter_mode"
        filter_mode="all"
        refresh_files
        return
    fi
    
    # Keep current index valid
    [[ $current -ge $total ]] && current=$((total - 1))
    [[ $current -lt 0 ]] && current=0
}

brats_dir=$1 
CSV_TRACKING="BraTS2021_Evaluation.csv"
show_crosshairs=true

if [ ! -f "$CSV_TRACKING" ]; then
    #mkdir -p "$CSV_TRACKING"
    #Initial state= All samples have "unspecified" quality status (haven't been validated as good or bad samples yet)
    (echo "File,Status,Points1,Points2,Points3"; find $brats_dir/ -mindepth 1 -maxdepth 1 -type d | xargs -n1 basename | awk '{print $0",unspecified"}') >> "$CSV_TRACKING"

fi

files=()
while IFS= read -r line; do
    files+=("$line")
done < <(tail -n +2 "$CSV_TRACKING" | cut -d',' -f1)

current=0
filter_mode="all" # "all", "good", "bad", "unspecified"
current_files=()

refresh_files

#echo "Total files: $total"
#echo "First file: ${current_files[0]}"
#echo " $total "


if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="mac"
    VIEWER_CLOSE='osascript -e "tell application \"Preview\" to close every window"'
    VIEWER_OPEN="open"
elif [[ "$OSTYPE" == "linux-gnu"* ]] || [[ -n "$WSL_DISTRO_NAME" ]]; then
        OS="linux"
        VIEWER_CLOSE=""  # No equivalent
        VIEWER_OPEN="xdg-open"  # Or: explorer.exe for WSL
else
        OS="windows"
        VIEWER_CLOSE=""
        VIEWER_OPEN="cmd.exe /c start"
fi

# Undo tracking
last_file=""
last_status=""

# Function to get filtered list based on current mode
get_filtered_files() {
    local mode="$1"
    local filtered=()
    
    if [[ "$mode" == "all" ]]; then
        filtered=("${files[@]}")
    else
        # Read files with matching status
        while IFS=',' read -r filename status rest; do
            if [[ "$status" == "$mode" ]]; then
                filtered+=("$filename")
            fi
        done < <(tail -n +2 "$CSV_TRACKING")
    fi
    
    echo "${filtered[@]}"
}

# Undo last status change
undo_last() {
    if [[ -z "$last_file" ]]; then
        echo "Nothing to undo"
        return
    fi
    
    echo "Undoing: $last_file -> $last_status"
    
    # Restore previous status
    awk -v file="$last_file" -v status="$last_status" -F',' 'BEGIN{OFS=","}
        NR==1 {print; next}
        $1==file {$2=status}
        {print}' "$CSV_TRACKING" > "${CSV_TRACKING}.tmp" && 
    mv "${CSV_TRACKING}.tmp" "$CSV_TRACKING"
    
    # Clear undo buffer
    last_file=""
    last_status=""
    
}


prepare_subject_images() {
    local subdir="$1"
    local fname
    fname=$(basename "$subdir")

    # persistent tmp dir (RAM-based is fastest)
    #tmpdir="/tmp/minc_fast_${fname}"
    # Fix temp directory
    if [[ -n "$WSL_DISTRO_NAME" ]]; then
        tmpdir="/tmp/minc_fast_${fname}"
    else
        tmpdir="${TMPDIR:-/tmp}/minc_fast_${fname}"
    fi
    mkdir -p "$tmpdir"

    local t1base=${subdir}/${fname}_t1
    local t1cebase=${subdir}/${fname}_t1ce
    local flairbase=${subdir}/${fname}_flair
    local t2base=${subdir}/${fname}_t2
    local labelbase=${subdir}/${fname}_seg

    convert_if_needed() {
        local base=$1 out=$2
        if [[ -f ${base}.mnc ]]; then
            ln -sf "${base}.mnc" "$out"
        elif [[ -f ${base}.nii.gz ]]; then
            [[ -f "$out" ]] || nii2mnc "${base}.nii.gz" "$out" -quiet
        else
            echo "Missing file: $base" >&2
            exit 1
        fi
    }

    # These are GLOBAL outputs
    tmpt1=$tmpdir/t1.mnc
    tmpt1ce=$tmpdir/t1ce.mnc
    tmpt2=$tmpdir/t2.mnc
    tmpflair=$tmpdir/flair.mnc
    tmplabel=$tmpdir/label.mnc

    convert_if_needed "$t1base" "$tmpt1"
    convert_if_needed "$t1cebase" "$tmpt1ce"
    convert_if_needed "$t2base" "$tmpt2"
    convert_if_needed "$flairbase" "$tmpflair"
    convert_if_needed "$labelbase" "$tmplabel"
}


get_csv_value() {
    local file="$1"
    local id="$2"
    local col="$3"

    awk -F',' -v id="$id" -v col="$col" '
        $1==id {gsub(/\r/,"",$col); gsub(/^ *| *$/,"",$col); print $col; exit}
    ' "$file"
}


update_csv_value() {
    local file="$1"
    local id="$2"
    local col="$3"
    local val="$4"
    local tmpfile    
    # Clean the value:
    # 1. Remove leading/trailing whitespace from each line
    # 2. Replace commas with colons (302,190 -> 302:190)
    # 3. Join lines with semicolons and remove carriage returns
    local cleaned_val=$(printf '%s' "$val" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//; s/,/:/g' | tr -d '\r' | paste -sd ';' -)
    
    tmpfile=$(mktemp)
    
    awk -F',' -v id="$id" -v col="$col" -v val="$cleaned_val" '
        BEGIN {
            OFS=","
        }
        
        NR==1 {
            # Keep header intact
            print
            next
        }
        
        {
            # Clean the ID field
            gsub(/\r$/, "", $1)
            gsub(/^ *| *$/, "", $1)
        }
        
        $1 == id {
            # Update the specified column
            $col = val
        }
        
        {
            print
        }
    ' "$file" > "$tmpfile" && mv "$tmpfile" "$file"
}


draw_crosshairs() {
    local input_img="$1"
    local output_img="$2"

    if [[ "$show_crosshairs" != true ]]; then
        return
    fi
    
    # Pre-allocate array for coordinates
    local -a valid_coords=()
    
    # Extract valid coordinates
    for pt in "${points[@]}"; do
        [[ "$pt" =~ ^# ]] && continue
        IFS=',' read -r x y <<< "$pt"
        [[ -n "$x" && -n "$y" ]] && valid_coords+=("$x" "$y")
    done
    
    # Early exit if no points
    if [ ${#valid_coords[@]} -eq 0 ]; then
        cp "$input_img" "$output_img"
        return
    fi
    
    # Build all draw commands efficiently
    local draw_cmds=()
    for ((i=0; i<${#valid_coords[@]}; i+=2)); do
        local x=${valid_coords[i]}
        local y=${valid_coords[i+1]}
        draw_cmds+=("line $((x - crosshair_size)),$y $((x + crosshair_size)),$y")
        draw_cmds+=("line $x,$((y - crosshair_size)) $x,$((y + crosshair_size))")
    done
    
    # Single convert call with all operations
    convert "$input_img" \
        -stroke "$color" -strokewidth "$line_width" -fill none \
        -draw "${draw_cmds[*]}" \
        "$output_img"
}

show_image() {
    #osascript -e 'tell application "Preview" to close every window' 2>/dev/null
    eval "$VIEWER_CLOSE" 2>/dev/null

    clear
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo "Filter: [$filter_mode] | Image $((current + 1)) of $total: ${current_files[$current]}"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo ""
    echo "SEGMENTATION LABELS:"
    echo "  Orange = Edema | White = Enhancing Tumour | Red = Non-enhancing Tumour & Necrosis"
    echo ""
    echo "CONTROLS:"
    echo "  Navigation:  ← → (arrow keys) | u (undo)"
    echo "  Labelling:    g (good) | b (bad)"
    echo "  Display:     m (toggle crosshair)"
    echo "  Filters:     1 (all) [default on start-up]| 2 (good only) | 3 (bad only) | 4 (unlabeled only)"
    echo "  Exit:        q (quit)"
    echo ""
    echo "IMPORTANT: If continuing labelling from a previous session, press '4' to skip already labeled images"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    # echo "Filter: [$filter_mode] | Image $((current + 1)) of $total: ${current_files[$current]}"\n
    # echo "IMPORTANT: If continuing from a previous labelling session, press '4' (iterate only unlabelled images) to avoid relabelling previous work"
    # echo "Orange = edema ; White = enhancing tumour ; Red = Non-enhancing tumour AND necrosis"\n
    # echo "← → navigate | g=label as 'good' | b=label as 'bad' | u=undo | m= toggle crosshair visibility | 1=iterate all (default) | 2= iterate good | 3=iterate bad | 4=iterate unspecified | q=quit"
    
    # Parameters
    contrast_names=("T1" "T1CE" "T2" "FLAIR" "FLAIR+Label")
    crosshair_size=6
    line_width=1.5
    color="red"

    subdir="$brats_dir/${current_files[$current]}"
    prepare_subject_images "$subdir"
    fname=$(basename "$subdir")

    # Get voxel coordinates of label
    read z_vox y_vox x_vox _ _ _ <<< "$(mincstats -quiet -CoM "$tmplabel")"
    slice_index=$(printf "%.0f" "$z_vox")
    read max_z <<< "$(mincinfo $tmpflair -dimlength zspace)"

    slice_1=$(( ($slice_index-15) > 0 ? ( $slice_index-15 ) : 0 ))
    slice_3=$(( ($slice_index+15) < $max_z ? ( $slice_index+15 ) : $max_z ))
    slice_indices=("$slice_1" "$slice_index" "$slice_3")

    contrasts=("$tmpt1" "$tmpt1ce" "$tmpt2" "$tmpflair")
    
    # Pre-create all temp file paths (avoids mktemp overhead)
    temp_images=()
    
    # Determine number of parallel jobs based on OS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        NPROC=$(sysctl -n hw.ncpu)
    else
        NPROC=$(nproc)
    fi
    MAX_JOBS=$((NPROC > 4 ? 4 : NPROC))  # Cap at 4 to avoid overwhelming disk I/O

    # Export necessary variables and functions
    export tmpdir contrasts tmpflair tmplabel show_crosshairs CSV_TRACKING fname
    export crosshair_size line_width color
    export -f draw_crosshairs get_csv_value update_csv_value
    
    for i in "${!slice_indices[@]}"; do
        slice="${slice_indices[$i]}"
        colNum=$((i + 3))
        
        val=$(get_csv_value "$CSV_TRACKING" "$fname" "$colNum")
        
        if [[ -z "$val" ]]; then
            #echo "[$fname] col $colNum empty — computing points..."
            temp_label="$tmpdir/label_${slice}.png"
            mincpik --clobber --lookup "-hotmetal" --slice "$slice" "$tmplabel" "$temp_label" 2>/dev/null
            
            points_str=$(python3 find_boundaries.py "$temp_label" 3)
            update_csv_value "$CSV_TRACKING" "$fname" "$colNum" "$points_str"
            
            rm "$temp_label"
        fi
    done
   
    # Now process slices in parallel (all CSV data is ready)
    process_slice() {
        local slice=$1
        local slice_idx=$2
        
        temp_label="$tmpdir/label_${slice}.png"
        
        # Generate label image
        mincpik --clobber --lookup "-hotmetal" --slice "$slice" "$tmplabel" "$temp_label" 2>/dev/null
        
        colNum=$((slice_idx + 3))
        points_str=$(get_csv_value "$CSV_TRACKING" "$fname" "$colNum")

        # Parse points into array for this slice
        IFS=';' read -ra points_array <<< "$(echo "$points_str" | tr ':' ',')"
        
        # Convert points_array to points array (removing the # prefix handling)
        local points=()
        for pt in "${points_array[@]}"; do
            points+=("$pt")
        done
        
        # Export points array for draw_crosshairs
        export points

        # Process all contrasts for this slice
        for j in "${!contrasts[@]}"; do
            contrast_file="${contrasts[$j]}"
            temp_file="$tmpdir/$(basename "$contrast_file" .mnc)_${slice}.png"
            
            mincpik --clobber --slice "$slice" "$contrast_file" "$temp_file" 2>/dev/null
            
            if [[ "$show_crosshairs" == true ]]; then
                temp_crosshair="$tmpdir/$(basename "$contrast_file" .mnc)_${slice}_ch.png"
                draw_crosshairs "$temp_file" "$temp_crosshair"
                rm "$temp_file"
            fi
        done
        
        # FLAIR with label overlay
        temp_flair="$tmpdir/flair_base_${slice}.png"
        temp_overlay="$tmpdir/overlay_${slice}.png"
        
        mincpik --clobber --slice "$slice" "$tmpflair" "$temp_flair" 2>/dev/null
        
        #composite -blend 45 "$temp_label" "$temp_flair" "$temp_overlay" 2>/dev/null
        composite "$temp_label" "$temp_flair" -compose screen -blend 45 "$temp_overlay" 2>/dev/null
       

        if [[ "$show_crosshairs" == true ]]; then
            temp_overlay_crosshair="$tmpdir/overlay_${slice}_ch.png"
            draw_crosshairs "$temp_overlay" "$temp_overlay_crosshair"
            rm "$temp_overlay"
        fi
        
        rm "$temp_flair" "$temp_label"
    }
    
    export -f process_slice
    
    # Process slices in parallel
    if command -v parallel &> /dev/null; then
        # Use GNU parallel if available (much faster)
        printf "%s\n" "${!slice_indices[@]}" | parallel -j $MAX_JOBS process_slice "${slice_indices[{}]}" {}
    else
        # Fallback: background processes with job control
        for i in "${!slice_indices[@]}"; do
            process_slice "${slice_indices[$i]}" "$i" &
            
            # Limit concurrent jobs
            if (( $(jobs -r | wc -l) >= MAX_JOBS )); then
                wait -n
            fi
        done
        wait  # Wait for all background jobs to complete
    fi

    # Collect images in correct order
    for i in "${!slice_indices[@]}"; do
        slice="${slice_indices[$i]}"
        for contrast_file in "${contrasts[@]}"; do
            if [[ "$show_crosshairs" == true ]]; then
                temp_images+=("$tmpdir/$(basename "$contrast_file" .mnc)_${slice}_ch.png")
            else
                temp_images+=("$tmpdir/$(basename "$contrast_file" .mnc)_${slice}.png")
            fi
        done
        
        if [[ "$show_crosshairs" == true ]]; then
            temp_images+=("$tmpdir/overlay_${slice}_ch.png")
        else
            temp_images+=("$tmpdir/overlay_${slice}.png")
        fi
    done

    tmpimg="$tmpdir/"$fname"_final_montage.png"
    

    montage "${temp_images[@]}"  -tile 5x3 -geometry +2+2 "$tmpimg" 2>/dev/null
    
    #Add Row/ Column labels for clarity:
    img_width=$(identify -format "%w" "$tmpimg")
    img_height=$(identify -format "%h" "$tmpimg")

    # Calculate positions (in pixels from top)
    pos_slice_1=$((img_height * 4 / 5))      # 80% down (top row)
    pos_slice_index=$((img_height / 2))      # 50% down (middle row)
    pos_slice_3=$((img_height / 5))          # 20% down (bottom row)

    col_width=$((img_width / 5))
    pos_col_1=$((col_width / 2))
    pos_col_2=$((col_width + col_width / 2))
    pos_col_3=$((col_width * 2 + col_width / 2))
    pos_col_4=$((col_width * 3 + col_width / 2))
    pos_col_5=$((col_width * 4 + col_width / 2))

    # Add header space at top
    header_height=40
    
    convert "$tmpimg" -gravity NorthWest -splice 100x${header_height} \
        -font Courier -pointsize 25 -fill black \
        -gravity North -annotate +$((pos_col_1 - img_width/2))+10 "T1" \
        -annotate +$((pos_col_2 - img_width/2))+10 "T1CE" \
        -annotate +$((pos_col_3 - img_width/2))+10 "T2" \
        -annotate +$((pos_col_4 - img_width/2))+10 "FLAIR" \
        -annotate +$((pos_col_5 - img_width/2))+10 "FLAIR+Label" \
        -gravity NorthWest -pointsize 16 \
        -annotate +10+$((pos_slice_1 + header_height)) "Slice $slice_1" \
        -annotate +10+$((pos_slice_index + header_height)) "Slice $slice_index" \
        -annotate +10+$((pos_slice_3 + header_height)) "Slice $slice_3" \
        "$tmpimg" 2>/dev/null

    open "$tmpimg"
    
    # Cleanup
    rm -f "$tmpflair" "$tmpt1" "$tmpt1ce" "$tmpt2" "$tmplabel"
}


# Get current status of a file
get_status() {
    local filename="$1"
    awk -F',' -v file="$filename" '$1==file {print $2}' "$CSV_TRACKING"
}

# Update status function with undo tracking
update_status() {
    local filename="$1"
    local new_status="$2"
    
    # Save current status for undo
    last_file="$filename"
    last_status=$(get_status "$filename")
    
    # Update the Status column
    awk -v file="$filename" -v status="$new_status" -F',' 'BEGIN{OFS=","}
        NR==1 {print; next}
        $1==file {$2=status}
        {print}' "$CSV_TRACKING" > "${CSV_TRACKING}.tmp" && 
    mv "${CSV_TRACKING}.tmp" "$CSV_TRACKING"
}


show_image

#Read keyboard input
while true; do
    read -rsn1 input
    
    # Handle arrow keys (they send 3 characters: ESC[A/B/C/D)
    if [[ $input == $'\x1b' ]]; then
        read -rsn2 input
        case $input in
            '[C') # Right arrow
                ((current++))
                [[ $current -ge $total ]] && current=$((total - 1))
                show_image
                ;;
            '[D') # Left arrow
                ((current--))
                [[ $current -lt 0 ]] && current=0
                show_image
                ;;
            
        esac
    elif [[ $input == 'm' ]]; then
        # Toggle crosshairs
        if [[ "$show_crosshairs" == true ]]; then
            show_crosshairs=false
            echo "Crosshairs: OFF"
        else
            show_crosshairs=true
            echo "Crosshairs: ON"
        fi
        #sleep 0.3
        show_image  # Regenerate current image

    elif [[ $input == 'g' ]]; then
        # Mark as good
        update_status "${current_files[$current]}" "good"
        echo "Marked as GOOD"
        #sleep 0.2
        if [[ "$filter_mode" != "all" ]]; then
            refresh_files
        else
            ((current++))
            [[ $current -ge $total ]] && current=$((total - 1))
        fi
        show_image
    elif [[ $input == 'b' ]]; then
        # Mark as bad
        update_status "${files[$current]}" "bad"
        echo "Marked as BAD"
        #sleep 0.2
        if [[ "$filter_mode" != "all" ]]; then
            refresh_files
        else
            ((current++))
            [[ $current -ge $total ]] && current=$((total - 1))
        fi 
        show_image

        elif [[ $input == 'u' ]]; then
        # Undo last change
        undo_last
        refresh_files
        ((current--))
        #[[ $current -ge $total ]] && current=$((total - 1))
        show_image
        
    elif [[ $input == '1' ]]; then
        echo "Filter: ALL images"
        filter_mode="all"
        refresh_files
        show_image
        
    elif [[ $input == '2' ]]; then
        echo "Filter: GOOD images only"
        filter_mode="good"
        refresh_files
        show_image
        
    elif [[ $input == '3' ]]; then
        echo "Filter: BAD images only"
        filter_mode="bad"
        refresh_files
        show_image
        
    elif [[ $input == '4' ]]; then
        echo "Filter: UNSPECIFIED images only"
        filter_mode="unspecified"
        refresh_files
        show_image

    elif [[ $input == 'q' ]]; then
        # kill $display_pid 2>/dev/null
        #osascript -e 'tell application "Preview" to close every window' 2>/dev/null
        eval "$VIEWER_CLOSE" 2>/dev/null

        break
    fi
done
