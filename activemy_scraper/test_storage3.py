import requests

storage_key = "trip_2d1n_kuala_rompin____20260808_2jbpf"
base_url = "https://firebasestorage.googleapis.com/v0/b/so-hikers-trip-builder.appspot.com/o/"

paths = [
    f"covers%2F{storage_key}",
    f"covers%2F{storage_key}.jpg",
    f"trip_covers%2F{storage_key}",
    f"trip_covers%2F{storage_key}.jpg",
    f"uploads%2F{storage_key}",
    f"uploads%2F{storage_key}.jpg",
    f"trips%2F{storage_key}%2Fimage",
    f"trips%2F{storage_key}%2Fimage.jpg",
    f"trips%2F{storage_key}%2Fcover_image",
    f"trips%2F{storage_key}%2Fcover_image.jpg"
]

for p in paths:
    url = base_url + p + "?alt=media"
    r = requests.head(url)
    if r.status_code == 200:
        print("FOUND!", url)
