# BraTS2021 Image Quality Control Tool - Usage Guide

## Overview

This tool helps you quickly review and label brain MRI images from the BraTS dataset. It displays multiple MRI contrasts (T1, T1CE, T2, FLAIR) with tumor segmentation overlays, allowing you to mark images as "good", "bad", or leave them "unspecified".

**Quick Navigation:**
- For step-by-step instructions on how to install and use the tool, see: [Running the Tool](#running-the-tool)
- For in-depth instructions on keyboard navigation, see: [Keyboard Controls](#keyboard-controls)

---

## Required Software

- Bash shell (Mac/Linux native, or WSL on Windows)
- MINC toolkit (mincpik, mincstats, mincinfo, nii2mnc)
- ImageMagick (convert, montage, composite)
- GNU Parallel (optional but recommended for speed)

---

## Installation

### Full Conda Environment

```bash
conda env create -f environment.yml
conda activate minc
```

---

## Data Structure

Your BraTS data should be organized like this:

```
/path/to/brats_data/
├── BraTS-GLI-00000-000/
│   ├── BraTS-GLI-00000-000_t1.nii.gz (or .mnc)
│   ├── BraTS-GLI-00000-000_t1ce.nii.gz
│   ├── BraTS-GLI-00000-000_t2.nii.gz
│   ├── BraTS-GLI-00000-000_flair.nii.gz
│   └── BraTS-GLI-00000-000_seg.nii.gz
├── BraTS-GLI-00001-000/
│   └── ...
```

---

## Basic Usage

```bash
./BraTS2021_QualityControl.sh /path/to/brats_data
```

---

## Customization

Edit these parameters in the `show_image()` function:

- `crosshair_size=6` - Crosshair arm length (pixels)
- `line_width=1.5` - Crosshair line thickness
- `color="red"` - Crosshair color
- `slice_offset=15` - Distance between displayed slices

---

## Keyboard Controls

### Navigation
*Does not label images as "good" or "bad"*

- `→` (Right Arrow) - Next image
- `←` (Left Arrow) - Previous image

### Labeling

- `g` - Mark current image as "good" and advance
- `b` - Mark current image as "bad" and advance
- `u` - Undo last labeling action

### Display Options

- `m` - Toggle crosshair marker visibility on/off

### Filtering

- `1` - Show all images (default)
- `2` - Show only "good" images
- `3` - Show only "bad" images
- `4` - Show only "unspecified" images

### Exit

- `q` - Quit the viewer

---

## Running the Tool

### Step 1: Install Environment

If using conda, install the environment `minc` from the `environment.yml`:

```bash
conda env create -f environment.yml
conda activate minc
```

Otherwise, manually install the packages specified in [Required Software](#required-software).

---

### Step 2: Ensure BraTS2021 Dataset Format

By convention, the BraTS2021 folder should contain 1251 subfolders following the "BraTS-GLI-00000-000" naming convention. Each subfolder should contain five files (t1, t1ce, t2, flair, seg), of file type either `.nii.gz` or `.mnc`. The quality control script runs with either file type.

```
/path/to/brats_data/
├── BraTS-GLI-00000-000/
│   ├── BraTS-GLI-00000-000_t1.nii.gz (or .mnc)
│   ├── BraTS-GLI-00000-000_t1ce.nii.gz
│   ├── BraTS-GLI-00000-000_t2.nii.gz
│   ├── BraTS-GLI-00000-000_flair.nii.gz
│   └── BraTS-GLI-00000-000_seg.nii.gz
├── BraTS-GLI-00001-000/
│   └── ...
```

---

### Step 3: Navigate to Working Directory and Start the Viewer

```bash
cd BraTS_Evaluation
./BraTS2021_QualityControl.sh /path/to/brats_data
```

This will create the CSV file `BraTSEvaluation.csv` which will store QC evaluations and display the first image.

---

## Typical Workflow

### 1. Review the First Image

- Check all contrasts for artifacts, alignment, and quality
- Look at the segmentation overlay (rightmost column)
- To toggle crosshairs on/off, press `m` (see [Keyboard Controls](#keyboard-controls))

### 2. Label the Image

- Press `g` if good quality → advances to next image
- Press `b` if bad quality → advances to next image
- Press `→` to skip without labeling

### 3. Use Filters to Review Specific Categories

> **Note:** These modes can be switched between without exiting the program
> 
> **Tip:** If continuing from a previous labeling session, press `4` to avoid relabeling previous work

- Press `1` to see all images ("good", "bad", "unlabeled") [default]
- Press `2` to verify all "good" images
- Press `3` to verify all "bad" images
- Press `4` to see only unlabeled images

### 4. Made a Mistake?

Press `u` to undo your last label and return to the previous image for re-evaluation.

### 5. Finish

Press `q` to quit.

Your labels are saved in `BraTS2021_Evaluation.csv`.

---

## Summary

This tool provides an efficient way to perform quality control on the BraTS2021 dataset. Use keyboard shortcuts to quickly navigate and label images, and leverage filtering modes to focus on specific categories or resume previous work sessions.
