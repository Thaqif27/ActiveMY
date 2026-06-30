from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    browser = p.chromium.launch()
    page = browser.new_page()
    page.goto("https://sohikers.com/trips", wait_until="networkidle")
    
    # Extract background images from elements with specific classes or all divs
    bg_images = page.evaluate('''() => {
        return Array.from(document.querySelectorAll('*'))
            .map(el => window.getComputedStyle(el).backgroundImage)
            .filter(bg => bg !== 'none' && bg.includes('url('));
    }''')
    
    # Extract images
    imgs = page.evaluate('''() => {
        return Array.from(document.querySelectorAll('img')).map(img => img.src);
    }''')
    
    print("Background Images:", set(bg_images))
    print("Images:", set(imgs))
    
    browser.close()
