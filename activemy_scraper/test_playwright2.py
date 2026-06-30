from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    browser = p.chromium.launch()
    page = browser.new_page()
    
    urls = []
    page.on("request", lambda request: urls.append(request.url) if request.resource_type == "image" else None)
    
    page.goto("https://sohikers.com/trips", wait_until="networkidle")
    
    # scroll down a bit to trigger lazy loading
    page.evaluate("window.scrollTo(0, document.body.scrollHeight)")
    page.wait_for_timeout(2000)
    
    for u in set(urls):
        print("Fetched Image:", u)
    
    browser.close()
