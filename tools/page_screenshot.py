import asyncio
import sys
from pyppeteer import launch

async def take_screenshot(url, output_file, width, height):
    browser = await launch(
        headless=True,
        args=['--disable-gpu', '--no-sandbox', '--disable-setuid-sandbox']
    )
    page = await browser.newPage()

    try:
        # Set viewport size
        await page.setViewport({'width': width, 'height': height})
        
        # Navigate to URL and wait for network idle
        await page.goto(url, waitUntil='networkidle0')
        
        # Additional wait for map tiles to load
        await page.waitForFunction('''
            () => {
                const tiles = document.querySelectorAll('.leaflet-tile-loaded');
                return tiles.length > 0;
            }
        ''', timeout=10000)
        
        # Take screenshot
        await page.screenshot({
            'path': output_file,
            'fullPage': False
        })
        
    except Exception as e:
        print(f"Error taking screenshot: {e}")
        return False
    finally:
        await browser.close()
    return True

def main():
    if len(sys.argv) != 5:
        print("Usage: python page_screenshot.py <URL> <output_file> <width> <height>")
        sys.exit(1)

    url = sys.argv[1]
    output_file = sys.argv[2]
    width = int(sys.argv[3])
    height = int(sys.argv[4])

    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)

    try:
        success = loop.run_until_complete(
            asyncio.wait_for(
                take_screenshot(url, output_file, width, height),
                timeout=30
            )
        )
        if not success:
            sys.exit(1)
    except asyncio.TimeoutError:
        print("Timeout: The operation took too long to complete.")
        sys.exit(1)
    finally:
        loop.close()

if __name__ == "__main__":
    main()
