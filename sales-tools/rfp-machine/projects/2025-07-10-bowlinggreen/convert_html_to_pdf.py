#!/usr/bin/env python3
"""
Convert HTML file to PDF using Playwright
"""

import asyncio
from playwright.async_api import async_playwright
import os

async def convert_html_to_pdf():
    """Convert HTML file to PDF using Playwright"""
    
    # Get the current directory
    current_dir = os.path.dirname(os.path.abspath(__file__))
    html_file = os.path.join(current_dir, "BrightMove_RFP_Response_Complete.html")
    pdf_file = os.path.join(current_dir, "BrightMove_RFP_Response_Complete.pdf")
    
    # Convert file path to file URL
    file_url = f"file://{html_file}"
    
    async with async_playwright() as p:
        # Launch browser
        browser = await p.chromium.launch()
        page = await browser.new_page()
        
        # Navigate to the HTML file
        await page.goto(file_url, wait_until='networkidle')
        
        # Wait a bit for any dynamic content to load
        await page.wait_for_timeout(2000)
        
        # Generate PDF with proper settings
        await page.pdf(
            path=pdf_file,
            format='A4',
            margin={
                'top': '0.75in',
                'right': '0.75in',
                'bottom': '0.75in',
                'left': '0.75in'
            },
            print_background=True,
            prefer_css_page_size=True
        )
        
        await browser.close()
        
        print(f"PDF generated successfully: {pdf_file}")

if __name__ == "__main__":
    asyncio.run(convert_html_to_pdf()) 