from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    browser = p.chromium.launch()
    page = browser.new_page()
    urls = []
    page.on("request", lambda request: urls.append(request.url))
    page.goto("https://sohikers.com/trips", wait_until="networkidle")
    for u in set(urls):
        print(u)
    browser.close()
