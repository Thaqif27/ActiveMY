import puppeteer from 'puppeteer';

(async () => {
  const browser = await puppeteer.launch({ headless: "new" });
  const page = await browser.newPage();
  await page.goto('https://sohikers.com/trips', { waitUntil: 'networkidle0' });

  // Get all img src
  const images = await page.evaluate(() => {
    return Array.from(document.querySelectorAll('img')).map(img => img.src);
  });
  
  // Get all elements with background-image
  const bgImages = await page.evaluate(() => {
    return Array.from(document.querySelectorAll('*'))
      .map(el => window.getComputedStyle(el).backgroundImage)
      .filter(bg => bg !== 'none' && bg.includes('url('));
  });

  console.log("Images:", images);
  console.log("Background Images:", bgImages);

  await browser.close();
})();
