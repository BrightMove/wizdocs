#!/usr/bin/env python3
"""
Simple Markdown to HTML converter for PDF generation
"""

import markdown
import os
import sys

def convert_md_to_html(md_file, html_file):
    """Convert Markdown file to HTML with professional styling"""
    
    # Read the markdown file
    with open(md_file, 'r', encoding='utf-8') as f:
        md_content = f.read()
    
    # Convert markdown to HTML
    html_content = markdown.markdown(md_content, extensions=['tables', 'fenced_code'])
    
    # Create professional CSS styling
    css_content = """
    <style>
    body {
        font-family: 'Helvetica Neue', Arial, sans-serif;
        line-height: 1.6;
        color: #333;
        max-width: 800px;
        margin: 0 auto;
        padding: 20px;
        background-color: #fff;
    }
    
    h1 {
        color: #2c3e50;
        font-size: 28px;
        font-weight: bold;
        border-bottom: 3px solid #3498db;
        padding-bottom: 10px;
        margin-top: 0;
        margin-bottom: 30px;
    }
    
    h2 {
        color: #34495e;
        font-size: 20px;
        font-weight: bold;
        margin-top: 30px;
        margin-bottom: 15px;
        border-left: 4px solid #3498db;
        padding-left: 15px;
    }
    
    h3 {
        color: #2c3e50;
        font-size: 16px;
        font-weight: bold;
        margin-top: 25px;
        margin-bottom: 10px;
    }
    
    p {
        margin-bottom: 12px;
        text-align: justify;
    }
    
    ul, ol {
        margin-bottom: 15px;
        padding-left: 20px;
    }
    
    li {
        margin-bottom: 5px;
    }
    
    strong {
        color: #2c3e50;
        font-weight: bold;
    }
    
    em {
        font-style: italic;
        color: #7f8c8d;
    }
    
    .executive-summary {
        background-color: #f8f9fa;
        padding: 20px;
        border-left: 5px solid #3498db;
        margin: 20px 0;
        border-radius: 5px;
    }
    
    .company-overview {
        background-color: #ecf0f1;
        padding: 15px;
        border-radius: 5px;
        margin: 15px 0;
    }
    
    .features-list {
        background-color: #f8f9fa;
        padding: 15px;
        border-radius: 5px;
        margin: 10px 0;
    }
    
    .pricing-table {
        width: 100%;
        border-collapse: collapse;
        margin: 15px 0;
    }
    
    .pricing-table th {
        background-color: #3498db;
        color: white;
        padding: 12px;
        text-align: left;
        font-weight: bold;
    }
    
    .pricing-table td {
        padding: 10px;
        border-bottom: 1px solid #ddd;
    }
    
    .pricing-table tr:nth-child(even) {
        background-color: #f8f9fa;
    }
    
    .conclusion {
        background-color: #e8f5e8;
        padding: 20px;
        border-radius: 5px;
        margin: 20px 0;
        border-left: 5px solid #27ae60;
    }
    
    .contact-info {
        background-color: #fff3cd;
        padding: 15px;
        border-radius: 5px;
        margin: 15px 0;
        border-left: 5px solid #ffc107;
    }
    
    @media print {
        body {
            max-width: none;
            margin: 0;
            padding: 20px;
        }
        
        h1 {
            page-break-after: avoid;
        }
        
        h2 {
            page-break-after: avoid;
        }
        
        .page-break {
            page-break-before: always;
        }
    }
    </style>
    """
    
    # Wrap HTML content with proper structure
    full_html = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <title>BrightMove RFP Response - RFP 2025-46</title>
        {css_content}
    </head>
    <body>
        {html_content}
    </body>
    </html>
    """
    
    # Write HTML file
    with open(html_file, 'w', encoding='utf-8') as f:
        f.write(full_html)
    
    print(f"✅ Successfully converted {md_file} to {html_file}")
    print(f"📄 HTML saved as: {os.path.abspath(html_file)}")
    print("\n📋 To convert to PDF:")
    print("1. Open the HTML file in your browser")
    print("2. Press Cmd+P (Mac) or Ctrl+P (Windows)")
    print("3. Select 'Save as PDF'")
    print("4. Choose your desired settings and save")

if __name__ == "__main__":
    # Check if markdown file is provided as argument
    if len(sys.argv) > 1:
        md_file = sys.argv[1]
    else:
        md_file = "BrightMove_RFP_Response.md"
    
    # Generate HTML filename from markdown filename
    html_file = md_file.replace('.md', '.html')
    
    if os.path.exists(md_file):
        convert_md_to_html(md_file, html_file)
    else:
        print(f"❌ Error: Markdown file '{md_file}' not found!")
        print(f"Available markdown files:")
        for file in os.listdir('.'):
            if file.endswith('.md'):
                print(f"  - {file}")
        sys.exit(1) 