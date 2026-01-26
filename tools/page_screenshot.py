import asyncio
import sys
import os
from pyppeteer import launch
from pyppeteer.errors import TimeoutError as PyppeteerTimeout, NetworkError, PageError

async def take_screenshot(url, output_file, width, height):
    browser = None
    try:
        browser = await launch(
            headless=True,
            args=[
                '--disable-gpu',
                '--no-sandbox',
                '--disable-setuid-sandbox',
                '--disable-dev-shm-usage',
                '--disable-web-security',
                '--disable-features=IsolateOrigins,site-per-process'
            ]
        )
        page = await browser.newPage()
        
        # Set viewport size
        await page.setViewport({'width': width, 'height': height})
        
        # Navigate to URL with longer timeout for IPFS content
        print(f"Loading URL: {url}", file=sys.stderr)
        await page.goto(url, waitUntil='networkidle0', timeout=45000)
        
        # Wait for map tiles to load with retry logic
        tiles_loaded = False
        for attempt in range(3):
            try:
                await page.waitForFunction('''
                    () => {
                        const tiles = document.querySelectorAll('.leaflet-tile-loaded');
                        return tiles.length > 0;
                    }
                ''', timeout=15000)
                tiles_loaded = True
                break
            except PyppeteerTimeout:
                if attempt < 2:
                    print(f"Tiles not loaded yet, retry {attempt + 1}/3...", file=sys.stderr)
                    await asyncio.sleep(2)
        
        if not tiles_loaded:
            # Take screenshot anyway - might have partial content
            print("Warning: Tiles may not be fully loaded, taking screenshot anyway", file=sys.stderr)
        
        # Take screenshot
        await page.screenshot({
            'path': output_file,
            'fullPage': False
        })
        
        # Verify file was created
        if os.path.exists(output_file) and os.path.getsize(output_file) > 0:
            print(f"Screenshot saved: {output_file} ({os.path.getsize(output_file)} bytes)", file=sys.stderr)
            return True
        else:
            print(f"Error: Screenshot file not created or empty", file=sys.stderr)
            return False
        
    except PyppeteerTimeout as e:
        print(f"Timeout error: {e}", file=sys.stderr)
        return False
    except NetworkError as e:
        print(f"Network error (URL unreachable?): {e}", file=sys.stderr)
        return False
    except PageError as e:
        print(f"Page error: {e}", file=sys.stderr)
        return False
    except Exception as e:
        print(f"Unexpected error: {type(e).__name__}: {e}", file=sys.stderr)
        return False
    finally:
        if browser:
            try:
                await browser.close()
            except Exception:
                pass

def main():
    if len(sys.argv) != 5:
        print("Usage: python page_screenshot.py <URL> <output_file> <width> <height>", file=sys.stderr)
        sys.exit(1)

    url = sys.argv[1]
    output_file = sys.argv[2]
    
    try:
        width = int(sys.argv[3])
        height = int(sys.argv[4])
    except ValueError as e:
        print(f"Invalid dimensions: {e}", file=sys.stderr)
        sys.exit(1)

    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)

    try:
        success = loop.run_until_complete(
            asyncio.wait_for(
                take_screenshot(url, output_file, width, height),
                timeout=90  # Increased global timeout for slow IPFS
            )
        )
        if not success:
            sys.exit(1)
    except asyncio.TimeoutError:
        print(f"Global timeout (90s): URL may be unreachable or IPFS slow", file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        print("Interrupted by user", file=sys.stderr)
        sys.exit(130)
    finally:
        loop.close()

if __name__ == "__main__":
    main()
