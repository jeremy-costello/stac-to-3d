from pystac_client import Client
import planetary_computer
import rasterio
import argparse
import stackstac


def fetch_raster(
        api_link: str,
        collection: str,
        asset_name: str,
        bbox: tuple[float, float, float, float],
        sign_items: bool,
        out_path: str
):
    if sign_items:
        modifier = planetary_computer.sign_inplace
    else:
        modifier = None
    
    stac = Client.open(
        api_link,
        modifier=modifier
    )

    search = stac.search(
        collections=[collection],
        bbox=bbox,
        limit=1
    )

    items = list(search.items())

    if not items:
        raise RuntimeError(f"No items found in collection {collection} for the specified bbox.")

    stack = stackstac.stack(
        items,
        assets=[asset_name],
        epsg=4326,
        resolution=None,
        bounds_latlon=bbox
    )

    stack = stackstac.mosaic(stack)
    
    transform = stack.attrs["transform"]
    crs = stack.attrs["crs"]
    height = stack.shape[1]
    width = stack.shape[2]

    data = stack.data

    with rasterio.open(
        out_path,
        "w",
        driver="GTiff",
        height=height,
        width=width,
        count=data.shape[0],
        dtype=data.dtype,
        crs=crs,
        transform=transform
    ) as dst:
        dst.write(data)


def main():
    parser = argparse.ArgumentParser(description="Download and merge rasters from MPC or NRCan STAC APIs.")
    parser.add_argument("--api", choices=["mpc", "nrcan"], required=True, help="Which STAC API to use: mpc or nrcan")
    parser.add_argument("--bbox", required=True, help="Bounding box coordinates")
    args = parser.parse_args()

    bbox = [float(coord) for coord in args.bbox.split(",")]

    if args.api == "mpc":
        api_link = "https://planetarycomputer.microsoft.com/api/stac/v1"
        sign_items = True
        collection_template = "3dep-lidar-{dm_type}"

        for dm_type in ["dsm", "dtm"]:
            collection = collection_template.format(dm_type=dm_type)
            asset_name = "data"
            out_path = f"/working/data/{dm_type}.tif"

            fetch_raster(
                api_link=api_link,
                collection=collection,
                asset_name=asset_name,
                bbox=bbox,
                sign_items=sign_items,
                out_path=out_path
            )

    elif args.api == "nrcan":
        api_link = "https://datacube.services.geo.ca/stac/api/"
        sign_items = False
        collection = "hrdem-mosaic-1m"  # maybe add fallback to 2m?

        for dm_type in ["dsm", "dtm"]:
            asset_name = dm_type
            out_path = f"/working/data/{dm_type}.tif"

            fetch_raster(
                api_link=api_link,
                collection=collection,
                asset_name=asset_name,
                bbox=bbox,
                sign_items=sign_items,
                out_path=out_path
            )


if __name__ == "__main__":
    main()
