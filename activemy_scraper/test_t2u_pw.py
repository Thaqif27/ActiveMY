from playwright.sync_api import sync_playwright

url = "https://www.ticket2u.com.my/event/36000/kuala-lumpur-standard-chartered-marathon-2024"

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    page = browser.new_page()
    page.goto(url, wait_until="domcontentloaded")
    
    print("Title:", page.title())
    
    try:
        venue = page.locator('#eventVenue').inner_text(timeout=2000)
        print("Venue ID:", venue)
    except: pass
    
    try:
        addrs = page.locator('address').all_inner_texts()
        print("Addresses:", addrs)
    except: pass
    
    browser.close()
