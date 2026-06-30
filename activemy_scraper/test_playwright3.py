from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    browser = p.chromium.launch()
    page = browser.new_page()
    
    urls = []
    page.on("request", lambda request: urls.append(request.url))
    
    page.goto("https://sohikers.com/trips", wait_until="networkidle")
    page.evaluate("window.scrollTo(0, document.body.scrollHeight)")
    page.wait_for_timeout(2000)
    
    for u in set(urls):
        if 'firebasestorage' in u or 'storage' in u or 'image' in u or 'jpg' in u or 'png' in u:
            print("Fetched:", u)
    
    browser.close()
