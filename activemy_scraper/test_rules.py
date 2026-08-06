import os
import sys
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from main import geocode_location
import googlemaps

print("=== RULE 1: Singapore Geocode Filter ===")
# Test Singapore location
lat, lng = geocode_location("Marina Bay, Singapore")
print(f"Marina Bay, Singapore -> Lat: {lat}, Lng: {lng} (Expected: None, None)")

lat2, lng2 = geocode_location("Singapore")
print(f"Singapore -> Lat: {lat2}, Lng: {lng2} (Expected: None, None)")

lat3, lng3 = geocode_location("Dataran Merdeka, Kuala Lumpur")
print(f"Dataran Merdeka -> Lat: {lat3}, Lng: {lng3} (Expected: ~3.14, ~101.69)")


print("\n=== RULE 2: Smart AI Trigger Logic ===")
def check_trigger(location):
    loc_lower = location.lower().strip()
    return not location or len(location) < 4 or len(location) > 60 or loc_lower in ['malaysia', 'virtual', 'tba', 'kuala lumpur', 'selangor'] or 'singapore' in loc_lower or 'indonesia' in loc_lower

locations = [
    ("Dataran Merdeka, Kuala Lumpur", False), # Valid physical location
    ("Kuala Lumpur", True), # Too generic
    ("TBA", True), # Generic
    ("Singapore Expo", True), # Contains singapore
    ("Jakarta, Indonesia", True), # Contains indonesia
    ("This is a very long description that somehow got scraped as the location of the event instead of the actual venue name which happens a lot with jomrun", True), # > 60 chars
]

for loc, expected in locations:
    result = check_trigger(loc)
    status = "PASS" if result == expected else "FAIL"
    print(f"{status} | Location: '{loc[:30]}...' | Trigger AI: {result}")

print("\n=== RULE 3: Malaysia Bounding Box ===")
def check_bounds(lat, lng):
    if lat != 0.0 or lng != 0.0:
        return (0.5 <= lat <= 8.0) and (99.0 <= lng <= 120.0)
    return True # Virtual events are allowed

coords = [
    (3.1412, 101.6865, True), # KL (Valid)
    (1.3521, 103.8198, True), # Singapore (Valid within rough box, but geocode blocks it earlier)
    (-6.2088, 106.8456, False), # Jakarta (Invalid lat)
    (51.5074, -0.1278, False), # London (Invalid)
    (0.0, 0.0, True), # Virtual event (Valid)
]

for lat, lng, expected in coords:
    result = check_bounds(lat, lng)
    status = "PASS" if result == expected else "FAIL"
    print(f"{status} | Lat: {lat}, Lng: {lng} | Allowed: {result}")
