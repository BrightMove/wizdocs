#!/usr/bin/env python3
"""
Convert BrightMove RFP Response to PDF
"""

import markdown
from pathlib import Path
import os

def convert_markdown_to_html(markdown_file, output_file):
    """Convert markdown file to HTML with styling"""
    
    # Read the markdown file
    with open(markdown_file, 'r', encoding='utf-8') as f:
        markdown_content = f.read()
    
    # Convert markdown to HTML
    html = markdown.markdown(markdown_content, extensions=['tables', 'toc', 'fenced_code'])
    
    # Add CSS styling for better formatting
    css_style = '''
    <style>
    body {
        font-family: Arial, sans-serif;
        line-height: 1.6;
        margin: 40px;
        color: #333;
        max-width: 800px;
    }
    h1 {
        color: #2c3e50;
        border-bottom: 2px solid #3498db;
        padding-bottom: 10px;
        page-break-before: auto;
    }
    h2 {
        color: #34495e;
        border-bottom: 1px solid #bdc3c7;
        padding-bottom: 5px;
        margin-top: 30px;
    }
    h3 {
        color: #2980b9;
        margin-top: 25px;
    }
    table {
        border-collapse: collapse;
        width: 100%;
        margin: 20px 0;
        font-size: 12px;
    }
    th, td {
        border: 1px solid #ddd;
        padding: 8px;
        text-align: left;
    }
    th {
        background-color: #f2f2f2;
        font-weight: bold;
    }
    tr:nth-child(even) {
        background-color: #f9f9f9;
    }
    .highlight {
        background-color: #fff3cd;
        padding: 10px;
        border-left: 4px solid #ffc107;
        margin: 10px 0;
    }
    ul, ol {
        margin: 10px 0;
        padding-left: 20px;
    }
    li {
        margin: 5px 0;
    }
    strong {
        color: #2c3e50;
    }
    blockquote {
        border-left: 4px solid #3498db;
        padding-left: 20px;
        margin: 20px 0;
        font-style: italic;
    }
    @media print {
        body {
            margin: 0;
            padding: 20px;
        }
        h1 {
            page-break-before: auto;
        }
    }
    </style>
    '''
    
    # Combine CSS and HTML
    full_html = f'''<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>BrightMove RFP Response - City of Bowling Green</title>
    {css_style}
</head>
<body>
    {html}
</body>
</html>'''
    
    # Save HTML file
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(full_html)
    
    print(f"HTML file generated: {output_file}")
    return output_file

def main():
    """Main function to convert markdown to HTML"""
    
    # File paths
    markdown_file = "output/BrightMove_RFP_Response_Bowling_Green_2025.md"
    html_file = "output/BrightMove_RFP_Response_Bowling_Green_2025.html"
    
    # Check if markdown file exists
    if not os.path.exists(markdown_file):
        print(f"Error: Markdown file not found: {markdown_file}")
        return
    
    # Convert to HTML
    convert_markdown_to_html(markdown_file, html_file)
    
    print("\nConversion complete!")
    print(f"HTML file: {html_file}")
    print("\nTo convert to PDF:")
    print("1. Open the HTML file in a web browser")
    print("2. Use the browser's Print function")
    print("3. Select 'Save as PDF' as the destination")
    print("4. Adjust margins and settings as needed")

if __name__ == "__main__":
    main() 