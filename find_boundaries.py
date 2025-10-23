#!/usr/bin/env python3
"""
Find significant points on segmentation boundaries for crosshair placement.
These points represent label transitions or edges of the label map.
"""

import numpy as np
from scipy import ndimage
from PIL import Image
import sys

def find_boundary_points(label_image, num_points=3):
    """
    Find significant boundary points where labels change.
    
    Args:
        label_image: 2D numpy array of segmentation labels
        num_points: Number of crosshair points to return (2-3)
    
    Returns:
        List of (x, y) coordinates for crosshair placement
    """
    # Find edges where labels change
    # Use Sobel filter to detect boundaries
    edges_x = ndimage.sobel(label_image, axis=1)
    edges_y = ndimage.sobel(label_image, axis=0)
    edges = np.hypot(edges_x, edges_y)
    
    # Also find outer edges of the label map (non-zero regions)
    label_mask = label_image > 0
    outer_edges = label_mask.astype(float) - ndimage.binary_erosion(label_mask).astype(float)
    
    # Combine internal boundaries and outer edges
    boundary_map = (edges > 0) | (outer_edges > 0)
    
    # Get all boundary coordinates
    boundary_coords = np.argwhere(boundary_map)
    
    if len(boundary_coords) == 0:
        print("No boundaries found!", file=sys.stderr)
        return []
    
    # Select well-distributed points using k-means-like approach
    selected_points = []
    
    # Start with the centroid of all boundaries
    centroid = boundary_coords.mean(axis=0)
    
    # Find point closest to centroid as first point
    distances = np.linalg.norm(boundary_coords - centroid, axis=1)
    first_idx = np.argmin(distances)
    selected_points.append(boundary_coords[first_idx])
    
    # For remaining points, choose points that maximize minimum distance to already selected points
    for _ in range(num_points - 1):
        max_min_dist = -1
        best_point = None
        
        for candidate in boundary_coords[::10]:  # Sample every 10th point for speed
            min_dist = min(np.linalg.norm(candidate - sp) for sp in selected_points)
            if min_dist > max_min_dist:
                max_min_dist = min_dist
                best_point = candidate
        
        if best_point is not None:
            selected_points.append(best_point)
    
    # Convert from (row, col) to (x, y) coordinates
    points_xy = [(int(pt[1]), int(pt[0])) for pt in selected_points]
    
    return points_xy


def load_label_image(filepath):
    """Load label image and return as numpy array."""
    img = Image.open(filepath)
    return np.array(img)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python find_points.py <label_image.png> [num_points]")
        sys.exit(1)
    
    label_path = sys.argv[1]
    num_points = int(sys.argv[2]) if len(sys.argv) > 2 else 3
    
    # Load label image
    label_img = load_label_image(label_path)
    
    # Find significant points
    points = find_boundary_points(label_img, num_points)
    
    # Output coordinates
    #print(f"# Found {len(points)} significant boundary points:")
    for i, (x, y) in enumerate(points, 1):
        print(f"{x},{y}")