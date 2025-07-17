from pystac_client import Client
from planetary_computer import sign
import rasterio
from rasterio.windows import from_bounds
import xarray as xr
import rioxarray
import geopandas as gpd
from shapely.geometry import box
import os
import argparse


def open_cog_cropped(url, bbox):
    """
    Open a Cloud Optimized GeoTIFF at url and read only the window defined by bbox (in EPSG:4326).
    Returns a rioxarray.DataArray.
    """
    with rasterio.Env():
        with rasterio.open(url) as src:
            # Reproject bbox coords to source CRS to get correct window
            geom = box(*bbox)
            gdf = gpd.GeoDataFrame({"geometry": [geom]}, crs="EPSG:4326")
            gdf = gdf.to_crs(src.crs)
            bounds = gdf.total_bounds  # xmin, ymin, xmax, ymax in src.crs

            window = from_bounds(*bounds, transform=src.transform)
            data = src.read(window=window, masked=True)  # (bands, height, width)
            out_transform = src.window_transform(window)
            profile = src.profile.copy()
            profile.update({
                "height": data.shape[1],
                "width": data.shape[2],
                "transform": out_transform
            })

    # Create xarray.DataArray from numpy array
    da = xr.DataArray(
        data,
        dims=("band", "y", "x"),
        coords={
            "band": list(range(1, data.shape[0] + 1))
        },
        attrs={"transform": out_transform, "crs": src.crs}
    )
    da = da.rio.write_crs(src.crs)
    da = da.rio.write_transform(out_transform)
    return da


def fetch_and_merge(api_link, collection, asset_name, bbox, sign_items=False, out_path="output.tif"):
    print(f"🔷 Searching collection: {collection}")
    stac = Client.open(api_link)

    search = stac.search(
        collections=[collection],
        bbox=bbox,
        limit=100
    )

    items = list(search.items())

    if not items:
        raise RuntimeError(f"No items found in collection {collection} for the specified bbox.")

    if sign_items:
        items = [sign(item) for item in items]

    asset_urls = []
    for item in items:
        if asset_name in item.assets:
            url = item.assets[asset_name].href
            # Use /vsicurl/ prefix for GDAL streaming from HTTP
            asset_urls.append(f"/vsicurl/{url}")

    if not asset_urls:
        raise RuntimeError(f"No assets named '{asset_name}' found in collection {collection}.")

    print(f"✅ Found {len(asset_urls)} assets in {collection}")

    # Open only the window corresponding to bbox for each COG asset
    rasters = [open_cog_cropped(url, bbox) for url in asset_urls]

    if len(rasters) == 1:
        r = rasters[0]
    else:
        # Merge on spatial coordinates, override attrs to avoid conflicts
        r = xr.combine_by_coords(rasters, combine_attrs="override")
        r = r.rio.write_crs(rasters[0].rio.crs)

    print(f"📏 Merged raster shape: {r.shape}")

    r.rio.to_raster(out_path)
    print(f"📁 Saved clipped raster: {os.path.abspath(out_path)}")


def main():
    parser = argparse.ArgumentParser(description="Download and merge rasters from MPC or NRCan STAC APIs.")
    parser.add_argument("--api", choices=["mpc", "nrcan"], required=True, help="Which STAC API to use: mpc or nrcan")
    parser.add_argument("--bbox", required=True, help="Bounding box coordinates")
    args = parser.parse_args()

    bbox = [float(coord) for coord in args.bbox.split(",")]

    if args.api == "mpc":
        api_link = "https://planetarycomputer.microsoft.com/api/stac/v1"
        sign_items = True
        collections = [
            ("3dep-lidar-dsm", "data", "/working/data/mpc_dsm.tif"),
            ("3dep-lidar-dtm", "data", "/working/data/mpc_dtm.tif"),
        ]
        for col, asset, out in collections:
            fetch_and_merge(api_link, col, asset, bbox, sign_items, out)

    else:  # NRCan
        api_link = "https://datacube.services.geo.ca/stac/api/"
        sign_items = False

        preferred_collections = [
            ("hrdem-mosaic-1m", "dsm", "/working/data/nrcan_dsm.tif"),
            ("hrdem-mosaic-1m", "dtm", "/working/data/nrcan_dtm.tif"),
        ]
        fallback_collections = [
            ("hrdem-mosaic-2m", "dsm", "/working/data/nrcan_dsm.tif"),
            ("hrdem-mosaic-2m", "dtm", "/working/data/nrcan_dtm.tif"),
        ]

        for (pref_col, pref_asset, pref_out), (fb_col, fb_asset, fb_out) in zip(preferred_collections, fallback_collections):
            try:
                fetch_and_merge(api_link, pref_col, pref_asset, bbox, sign_items, pref_out)
            except RuntimeError as e:
                print(f"⚠️ {e}")
                print(f"🔷 Trying fallback collection: {fb_col}")
                fetch_and_merge(api_link, fb_col, fb_asset, bbox, sign_items, fb_out)


if __name__ == "__main__":
    main()

