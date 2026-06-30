import requests

storage_key = "trip_2d1n_kuala_rompin____20260808_2jbpf"
base_url = "https://firebasestorage.googleapis.com/v0/b/so-hikers-trip-builder.appspot.com/o/"

# Try different combinations
paths_to_try = [
    f"trips%2F{storage_key}",
    f"trips%2F{storage_key}%2Fcover",
    f"trips%2F{storage_key}%2Fcover.jpg",
    f"trips%2F{storage_key}%2Fcover.png",
    f"images%2F{storage_key}",
    f"{storage_key}",
    f"trip_images%2F{storage_key}"
]

for path in paths_to_try:
    url = base_url + path + "?alt=media"
    resp = requests.head(url)
    print(f"{path}: {resp.status_code}")
