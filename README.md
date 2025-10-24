
# BraTS2021 Image Quality Control Tool - Usage Guide

## Overview

This tool helps you quickly review and label brain MRI images from the BraTS dataset. It displays multiple MRI contrasts (T1, T1CE, T2, FLAIR) with tumor segmentation overlays, allowing you to mark images as "good", "bad", or leave them "unspecified".

## Required Software
- Bash shell (Mac/Linux native, or WSL on Windows)
- MINC toolkit (mincpik, mincstats, mincinfo, nii2mnc)
- ImageMagick (convert, montage, composite)
- GNU Parallel (optional but recommended for speed)


## Installation

### Full Conda Environment

'''bash
conda env create -f environment.yml
conda activate minc
'''

## Data Structure
Your BraTS data should be organized like this:

/path/to/brats_data/
├── BraTS-GLI-00000-000/
│   ├── BraTS-GLI-00000-000_t1.nii.gz (or .mnc)
│   ├── BraTS-GLI-00000-000_t1ce.nii.gz
│   ├── BraTS-GLI-00000-000_t2.nii.gz
│   ├── BraTS-GLI-00000-000_flair.nii.gz
│   └── BraTS-GLI-00000-000_seg.nii.gz
├── BraTS-GLI-00001-000/
│   └── ...

## Running the Tool

### Basic Usage
'''bash
./BraTS2021_QualityControl.sh /path/to/brats_data
'''

### Customization

Edit these parameters in the show_image() function:
- bashcrosshair_size=6        # Crosshair arm length (pixels)
- line_width=1.5          # Crosshair line thickness
- color="red"             # Crosshair color
- slice_offset=15         # Distance between displayed slices

## Keyboard Controls

#### Navigation (does not label images as "good" or "bad")

→ (Right Arrow) - Next image
← (Left Arrow) - Previous image

#### Labeling

g - Mark current image as "good" and advance
b - Mark current image as "bad" and advance
u - Undo last labeling action

#### Display Options

m - Toggle crosshair marker visibility on/off

#### Filtering

1 - Show all images (default)
2 - Show only "good" images
3 - Show only "bad" images
4 - Show only "unspecified" images

#### Exit

q - Quit the viewer


## Workflow Example

1) Start the viewer
'''bash
./BraTS2021_QualityControl.sh /path/to/brats_data

'''

2) Review the first image:

Check all contrasts for artifacts, alignment, quality
Look at the segmentation overlay (rightmost column)


3) Label the image:

Press g if good quality → advances to next image
Press b if bad quality → advances to next image
Press → to skip without labeling


4) Use filters to review specific categories:
*These modes can be switched between without exiting the program
Press 1 to see all images ("good', "bad", "unlabelled") [default]
Press 4 to see only unlabelled images
Press 3 to verify all "bad" images
Press 2 to verify all "good" images


5) Made a mistake?
Press u to undo your last label and return to the previous image


6) Finish:
Press q to quit

Your labels are saved in order in BraTS2021_Evaluation.csv