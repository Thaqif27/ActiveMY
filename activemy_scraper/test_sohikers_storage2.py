import requests

storage_key = "trip_2d1n_kuala_rompin____20260808_2jbpf"
base_url = "https://firebasestorage.googleapis.com/v0/b/so-hikers-trip-builder.appspot.com/o/"

# Try different combinations
paths_to_try = [
    f"trips%2F{storage_key}.jpg",
    f"trips%2F{storage_key}.png",
    f"trips%2F{storage_key}.webp",
    f"trips%2F{storage_key}.jpeg",
    f"images%2F{storage_key}.jpg",
    f"images%2F{storage_key}.png",
    f"images%2F{storage_key}.webp",
    f"{storage_key}.jpg",
    f"{storage_key}.png"
]

for path in paths_to_try:
    url = base_url + path + "?alt=media"
    resp = requests.head(url)
    print(f"{path}: {resp.status_code}")
    if resp.status_code == 200:
        print("FOUND:", url)
