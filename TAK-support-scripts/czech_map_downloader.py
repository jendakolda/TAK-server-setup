#!/usr/bin/env python3
"""
Czech Republic Map Downloader for ATAK
Downloads topographical maps and elevation data from Czech CUZK services
and prepares them for use in ATAK (Android Team Awareness Kit)
"""

import os
import sqlite3
import requests
import mercantile
from concurrent.futures import ThreadPoolExecutor, as_completed
import threading

class CzechMapDownloader:
    def __init__(self, max_workers=8):
        self.base_url = "https://ags.cuzk.gov.cz/arcgis/rest/services"
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Czech-ATAK-Map-Downloader/1.0'
        })
        self.max_workers = max_workers
        self.lock = threading.Lock()
        
    def get_tile_bounds_czech_republic(self, zoom_level=12):
        """Get tile bounds for Czech Republic at given zoom level"""
        # Czech Republic approximate bounds in WGS84
        west, south = 12.0, 48.5   # Southwest corner
        east, north = 19.0, 51.1   # Northeast corner
        
        # Convert to tile coordinates
        ul_tile = mercantile.tile(west, north, zoom_level)
        lr_tile = mercantile.tile(east, south, zoom_level)
        
        return {
            'min_x': ul_tile.x,
            'max_x': lr_tile.x,
            'min_y': ul_tile.y,
            'max_y': lr_tile.y,
            'zoom': zoom_level
        }
    
    def download_arcgis_tile(self, service_name, x, y, z, image_format='png'):
        """Download a single tile from ArcGIS REST service"""
        # Convert tile coordinates to geographic bounds
        bbox = mercantile.bounds(x, y, z)
        
        # Convert to Czech coordinate system (S-JTSK / Krovak East North - EPSG:5514)
        # For simplicity, we'll use Web Mercator and let the service reproject
        
        url = (f"{self.base_url}/{service_name}/MapServer/export?"
               f"bbox={bbox.west},{bbox.south},{bbox.east},{bbox.north}&"
               f"bboxSR=4326&"
               f"imageSR=3857&"
               f"size=256,256&"
               f"format={image_format}&"
               f"transparent=true&"
               f"f=image")
        
        try:
            response = self.session.get(url, timeout=30)
            if response.status_code == 200:
                return response.content
            else:
                print(f"Failed to download tile {z}/{x}/{y}: HTTP {response.status_code}")
                return None
        except Exception as e:
            print(f"Error downloading tile {z}/{x}/{y}: {e}")
            return None
    
    def create_mbtiles_database(self, filepath, name, description="Czech Republic Topographical Map"):
        """Create an MBTiles SQLite database"""
        conn = sqlite3.connect(filepath)
        cursor = conn.cursor()
        
        # Create tables
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
        
        # Create unique index
        cursor.execute('''
            CREATE UNIQUE INDEX tile_index ON tiles (
                zoom_level, tile_column, tile_row
            )
        ''')
        
        # Insert metadata
        metadata = [
            ('name', name),
            ('type', 'baselayer'),
            ('version', '1.0'),
            ('description', description),
            ('format', 'png'),
            ('bounds', '12.0,48.5,19.0,51.1'),  # Czech Republic bounds
            ('minzoom', '8'),
            ('maxzoom', '16')
        ]
        
        cursor.executemany('INSERT INTO metadata (name, value) VALUES (?, ?)', metadata)
        conn.commit()
        return conn
    
    def tms_to_xyz(self, y, z):
        """Convert TMS tile Y to XYZ tile Y (flip Y axis)"""
        return (2 ** z - 1) - y
    
    def download_tile_worker(self, service_name, x, y, z):
        """Worker function to download a single tile"""
        tile_data = self.download_arcgis_tile(service_name, x, y, z)
        if tile_data:
            tms_y = self.tms_to_xyz(y, z)
            return (z, x, tms_y, tile_data)
        return None

    def download_topographic_maps(self, output_file, zoom_levels=[6, 8, 10, 12, 14],
                                 service='ZABAGED_POLOHOPIS'):
        """
        Download Czech topographical maps with resume functionality and parallelization

        Args:
            output_file: Output MBTiles file path
            zoom_levels: List of zoom levels to download
            service: ArcGIS service name to use
        """
        print(f"Starting download of {service} maps to {output_file}")

        # Check if database exists (for resume functionality)
        db_exists = os.path.exists(output_file)

        if not db_exists:
            conn = self.create_mbtiles_database(output_file, f"Czech {service}")
            print("Created new MBTiles database")
        else:
            conn = sqlite3.connect(output_file)
            print("Resuming from existing MBTiles database")

        cursor = conn.cursor()

        # Get existing tiles for resume functionality
        cursor.execute('SELECT zoom_level, tile_column, tile_row FROM tiles')
        existing_tiles = set(cursor.fetchall())

        # Generate list of all tiles to download
        all_tiles = []
        total_tiles = 0

        for zoom in zoom_levels:
            bounds = self.get_tile_bounds_czech_republic(zoom)
            level_tiles = ((bounds['max_x'] - bounds['min_x'] + 1) *
                          (bounds['max_y'] - bounds['min_y'] + 1))
            total_tiles += level_tiles

            print(f"Processing zoom level {zoom}: {level_tiles} tiles")

            for x in range(bounds['min_x'], bounds['max_x'] + 1):
                for y in range(bounds['min_y'], bounds['max_y'] + 1):
                    tms_y = self.tms_to_xyz(y, zoom)

                    # Check if tile already exists (resume functionality)
                    if (zoom, x, tms_y) not in existing_tiles:
                        all_tiles.append((service, x, y, zoom))

        downloaded_tiles = len(existing_tiles)
        skipped_tiles = len(existing_tiles)

        if skipped_tiles > 0:
            print(f"Skipping {skipped_tiles} existing tiles")

        print(f"Downloading {len(all_tiles)} remaining tiles using {self.max_workers} parallel workers")

        # Download tiles in parallel
        with ThreadPoolExecutor(max_workers=self.max_workers) as executor:
            # Submit all download tasks
            future_to_tile = {
                executor.submit(self.download_tile_worker, service, x, y, z): (x, y, z)
                for service, x, y, z in all_tiles
            }

            # Process completed downloads
            for future in as_completed(future_to_tile):
                result = future.result()

                if result:
                    z, x, tms_y, tile_data = result

                    with self.lock:
                        cursor.execute('''
                            INSERT OR REPLACE INTO tiles
                            (zoom_level, tile_column, tile_row, tile_data)
                            VALUES (?, ?, ?, ?)
                        ''', (z, x, tms_y, tile_data))

                        downloaded_tiles += 1

                        if downloaded_tiles % 50 == 0:
                            conn.commit()
                            print(f"Downloaded {downloaded_tiles}/{total_tiles} tiles "
                                  f"({downloaded_tiles/total_tiles*100:.1f}%)")

        conn.commit()
        conn.close()

        print(f"Download complete: {downloaded_tiles}/{total_tiles} tiles saved to {output_file}")
        return downloaded_tiles
    
    def download_contour_overlay(self, output_file, zoom_levels=[6, 8, 10, 12, 14]):
        """Download contour lines as a separate overlay"""
        return self.download_topographic_maps(
            output_file, 
            zoom_levels, 
            service='ZABAGED_VRSTEVNICE'
        )

def main():
    """Main function to download Czech maps for ATAK"""
    downloader = CzechMapDownloader()
    
    # Create output directory
    output_dir = "downloaded_maps"
    os.makedirs(output_dir, exist_ok=True)
    
    print("Czech Republic ATAK Map Downloader")
    print("==================================")
    
    # Download base topographic map
    base_map_file = os.path.join(output_dir, "czech_topographic.mbtiles")
    print("\n1. Downloading base topographic map (ZABAGED_POLOHOPIS)...")
    downloader.download_topographic_maps(
        base_map_file, 
        zoom_levels=[6, 8, 10, 12, 14, 16],
        service='ZABAGED_POLOHOPIS'
    )
    
    # Download contour lines
    contour_file = os.path.join(output_dir, "czech_contours.mbtiles")
    print("\n2. Downloading contour lines overlay...")
    downloader.download_contour_overlay(
        contour_file,
        zoom_levels=[6, 8, 10, 12, 14]
    )
    
    print(f"\n✓ Maps downloaded successfully!")
    print(f"📁 Output directory: {output_dir}")
    print(f"📄 Base map: {base_map_file}")
    print(f"📄 Contours: {contour_file}")
    print(f"\nTo use in ATAK:")
    print(f"1. Copy the .mbtiles files to your Android device")
    print(f"2. In ATAK, go to Settings > Layers > Import")
    print(f"3. Select the .mbtiles files to import them")

if __name__ == "__main__":
    main()