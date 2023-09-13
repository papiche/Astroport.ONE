import asyncio
import sys
from pyppeteer import launch

async def take_screenshot(url, output_file, width, height):
    browser = await launch(headless=True)
    page = await browser.newPage()

    try:
        await page.setViewport({'width': width, 'height': height})  # Set the viewport size
        await page.goto(url, waitUntil='networkidle2')
        await page.screenshot({'path': output_file})
    except Exception as e:
        print(f"An error occurred: {e}")
    finally:
        await browser.close()

if __name__ == "__main__":
    if len(sys.argv) != 5:
        print("Usage: python page_screenshot.py <URL> <output_file> <width> <height>")
        sys.exit(1)

    url = sys.argv[1]
    output_file = sys.argv[2]
    width = int(sys.argv[3])
    height = int(sys.argv[4])

    asyncio.get_event_loop().run_until_complete(take_screenshot(url, output_file, width, height))
