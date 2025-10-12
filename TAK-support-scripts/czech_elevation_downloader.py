#!/usr/bin/env python3
"""
Czech Republic Elevation Data Downloader for ATAK
Downloads elevation data from Czech CUZK services and creates elevation overlays
"""

import os
import json
import sqlite3
import requests
import numpy as np
from PIL import Image, ImageFilter
import mercantile
import time

class CzechElevationDownloader:
    def __init__(self):
        self.base_url = "https://ags.cuzk.gov.cz/arcgis/rest/services"
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Czech-ATAK-Elevation-Downloader/1.0'
        })
    
    def download_elevation_tile(self, x, y, z, service="3D/dmr5g"):
        """Download elevation data tile from DMR service"""
        bbox = mercantile.bounds(x, y, z)
        
        # Request elevation data in GeoTIFF format
        url = (f"{self.base_url}/{service}/ImageServer/exportImage?"
               f"bbox={bbox.west},{bbox.south},{bbox.east},{bbox.north}&"
               f"bboxSR=4326&"
               f"imageSR=4326&"
               f"size=256,256&"
               f"format=tiff&"
               f"pixelType=F32&"
               f"noData=0&"
               f"interpolation=RSP_BilinearInterpolation&"
               f"f=image")
        
        try:
            response = self.session.get(url, timeout=60)
            if response.status_code == 200:
                return response.content
            else:
                print(f"Failed to download elevation tile {z}/{x}/{y}: HTTP {response.status_code}")
                return None
        except Exception as e:
            print(f"Error downloading elevation tile {z}/{x}/{y}: {e}")
            return None
    
    def elevation_to_hillshade(self, elevation_data, azimuth=315, altitude=45):
        """Convert elevation data to hillshade visualization"""
        if elevation_data is None or len(elevation_data) == 0:
            return None

        try:
            # Load elevation data as numpy array
            from io import BytesIO

            # Verify the data is valid before processing
            if len(elevation_data) < 1000:  # Too small for a valid TIFF
                return None

            try:
                img = Image.open(BytesIO(elevation_data))
                img.load()  # Force loading to detect truncation

                # Check if image has valid dimensions
                if img.size[0] == 0 or img.size[1] == 0:
                    return None

            except Exception as e:
                return None

            # Convert to array with proper error handling
            try:
                with np.errstate(invalid='ignore'):
                    elevation = np.array(img, dtype=np.float64)

                # Check if conversion was successful
                if elevation.size == 0:
                    return None

            except Exception:
                return None

            # Handle no-data values and invalid data
            elevation[elevation == 0] = np.nan
            elevation[~np.isfinite(elevation)] = np.nan

            if np.all(np.isnan(elevation)) or elevation.size == 0:
                return None

            # Fill NaN values with mean for gradient calculation
            valid_mask = ~np.isnan(elevation)
            if np.sum(valid_mask) < 10:  # Too few valid points
                return None

            mean_elevation = np.nanmean(elevation)
            elevation_filled = elevation.copy()
            elevation_filled[~valid_mask] = mean_elevation

            # Calculate gradients with full error suppression
            with np.errstate(all='ignore'):
                dy, dx = np.gradient(elevation_filled)

                # Handle any remaining invalid values
                dx = np.nan_to_num(dx, nan=0.0, posinf=0.0, neginf=0.0)
                dy = np.nan_to_num(dy, nan=0.0, posinf=0.0, neginf=0.0)

                # Clip extreme values to prevent overflow
                dx = np.clip(dx, -100, 100)
                dy = np.clip(dy, -100, 100)

                # Calculate slope and aspect
                slope = np.arctan(np.sqrt(dx*dx + dy*dy))
                aspect = np.arctan2(-dx, dy)

                # Convert angles to radians
                azimuth_rad = np.radians(azimuth)
                altitude_rad = np.radians(altitude)

                # Calculate hillshade
                hillshade = (np.sin(altitude_rad) * np.sin(slope) +
                            np.cos(altitude_rad) * np.cos(slope) *
                            np.cos(azimuth_rad - aspect))

                # Handle any invalid values in hillshade
                hillshade = np.nan_to_num(hillshade, nan=0.5, posinf=1.0, neginf=0.0)

                # Normalize to 0-255 range
                hillshade = np.clip(hillshade * 255, 0, 255).astype(np.uint8)

            # Convert back to PIL Image (fix deprecated mode parameter)
            hillshade_img = Image.fromarray(hillshade).convert('L')
            
            # Apply slight blur for smoother appearance
            hillshade_img = hillshade_img.filter(ImageFilter.GaussianBlur(radius=0.5))
            
            # Convert to PNG bytes
            from io import BytesIO
            output = BytesIO()
            hillshade_img.save(output, format='PNG')
            return output.getvalue()
            
        except Exception as e:
            print(f"Error processing elevation data: {e}")
            return None
    
    def create_hillshade_mbtiles(self, output_file, zoom_levels=[6, 8, 10, 12]):
        """Create hillshade overlay MBTiles from elevation data"""
        print(f"Creating hillshade overlay: {output_file}")

        # Check if database exists (for resume functionality)
        db_exists = os.path.exists(output_file)

        # Create MBTiles database
        conn = sqlite3.connect(output_file)
        cursor = conn.cursor()

        if not db_exists:
            # Create tables for new database
            cursor.execute('''
                CREATE TABLE metadata (
                    name TEXT,
                    value TEXT
                )
            ''')

            cursor.execute('''
                CREATE TABLE tiles (
                    zoom_level INTEGER,
                    tile_column INTEGER,
                    tile_row INTEGER,
                    tile_data BLOB
                )
            ''')

            cursor.execute('''
                CREATE UNIQUE INDEX tile_index ON tiles (
                    zoom_level, tile_column, tile_row
                )
            ''')

            # Insert metadata
            metadata = [
                ('name', 'Czech Republic Hillshade'),
                ('type', 'overlay'),
                ('version', '1.0'),
                ('description', 'Elevation hillshade overlay for Czech Republic'),
                ('format', 'png'),
                ('bounds', '12.0,48.5,19.0,51.1'),
                ('minzoom', str(min(zoom_levels))),
                ('maxzoom', str(max(zoom_levels)))
            ]

            cursor.executemany('INSERT INTO metadata (name, value) VALUES (?, ?)', metadata)
            conn.commit()
            print("Created new MBTiles database")
        else:
            print("Resuming from existing MBTiles database")

        # Get existing tiles for resume functionality
        cursor.execute('SELECT zoom_level, tile_column, tile_row FROM tiles')
        existing_tiles = set(cursor.fetchall())

        total_tiles = 0
        processed_tiles = len(existing_tiles)  # Start count from existing tiles
        skipped_tiles = 0

        for zoom in zoom_levels:
            # Czech Republic bounds
            west, south = 12.0, 48.5
            east, north = 19.0, 51.1

            ul_tile = mercantile.tile(west, north, zoom)
            lr_tile = mercantile.tile(east, south, zoom)

            level_tiles = (lr_tile.x - ul_tile.x + 1) * (lr_tile.y - ul_tile.y + 1)
            total_tiles += level_tiles

            print(f"Processing zoom level {zoom}: {level_tiles} tiles")

            for x in range(ul_tile.x, lr_tile.x + 1):
                for y in range(ul_tile.y, lr_tile.y + 1):
                    # Convert Y coordinate for MBTiles format (TMS)
                    tms_y = (2 ** zoom - 1) - y

                    # Check if tile already exists (resume functionality)
                    if (zoom, x, tms_y) in existing_tiles:
                        skipped_tiles += 1
                        continue

                    # Download elevation data
                    elevation_data = self.download_elevation_tile(x, y, zoom)

                    if elevation_data:
                        # Convert to hillshade
                        hillshade_png = self.elevation_to_hillshade(elevation_data)

                        if hillshade_png:
                            cursor.execute('''
                                INSERT OR REPLACE INTO tiles
                                (zoom_level, tile_column, tile_row, tile_data)
                                VALUES (?, ?, ?, ?)
                            ''', (zoom, x, tms_y, hillshade_png))

                            processed_tiles += 1

                            if processed_tiles % 10 == 0:
                                conn.commit()
                                print(f"Processed {processed_tiles}/{total_tiles} tiles "
                                      f"({processed_tiles/total_tiles*100:.1f}%)")

                    # Be nice to the server
                    time.sleep(0.5)
        
        conn.commit()
        conn.close()

        if skipped_tiles > 0:
            print(f"Skipped {skipped_tiles} existing tiles")

        print(f"Hillshade creation complete: {processed_tiles}/{total_tiles} tiles")
        return processed_tiles

def main():
    """Main function to create elevation overlays"""
    downloader = CzechElevationDownloader()
    
    # Create output directory
    output_dir = "downloaded_maps"
    os.makedirs(output_dir, exist_ok=True)
    
    print("Czech Republic Elevation Data Downloader")
    print("========================================")
    
    # Create hillshade overlay
    hillshade_file = os.path.join(output_dir, "czech_hillshade.mbtiles")
    print(f"\nCreating hillshade overlay...")
    downloader.create_hillshade_mbtiles(
        hillshade_file,
        zoom_levels=[6, 8, 10, 12, 14]
    )
    
    print(f"\n✓ Elevation overlay created successfully!")
    print(f"📁 Output directory: {output_dir}")
    print(f"📄 Hillshade overlay: {hillshade_file}")
    print(f"\nTo use in ATAK:")
    print(f"1. Copy the hillshade .mbtiles file to your Android device")
    print(f"2. In ATAK, go to Settings > Layers > Import")
    print(f"3. Import as an overlay layer")

if __name__ == "__main__":
    main()