#!/usr/bin/env python3
"""
Simple Markdown to HTML converter for BrightMove RFP Response
"""

import re
import os

def simple_markdown_to_html(markdown_content):
    """Convert basic markdown to HTML"""
    
    # Convert headers
    html = re.sub(r'^# (.+)$', r'<h1>\1</h1>', markdown_content, flags=re.MULTILINE)
    html = re.sub(r'^## (.+)$', r'<h2>\1</h2>', html, flags=re.MULTILINE)
    html = re.sub(r'^### (.+)$', r'<h3>\1</h3>', html, flags=re.MULTILINE)
    
    # Convert bold text
    html = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', html)
    
    # Convert italic text
    html = re.sub(r'\*(.+?)\*', r'<em>\1</em>', html)
    
    # Convert horizontal rules
    html = re.sub(r'^---$', r'<hr>', html, flags=re.MULTILINE)
    
    # Convert bullet points
    html = re.sub(r'^- (.+)$', r'<li>\1</li>', html, flags=re.MULTILINE)
    
    # Wrap consecutive list items in <ul>
    html = re.sub(r'(<li>.*?</li>)\s*(?=<li>)', r'\1', html, flags=re.DOTALL)
    html = re.sub(r'(<li>.*?</li>)(?!\s*<li>)', r'<ul>\1</ul>', html, flags=re.DOTALL)
    
    # Convert paragraphs (lines that aren't headers, lists, or other elements)
    lines = html.split('\n')
    processed_lines = []
    
    for line in lines:
        line = line.strip()
        if line and not line.startswith('<') and not line.startswith('|'):
            if not processed_lines or processed_lines[-1] == '':
                processed_lines.append(f'<p>{line}</p>')
            else:
                processed_lines.append(line)
        else:
            processed_lines.append(line)
    
    return '\n'.join(processed_lines)

def create_html_document(content):
    """Create a complete HTML document with styling"""
    
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
    p {
        margin: 10px 0;
    }
    hr {
        border: none;
        border-top: 1px solid #ccc;
        margin: 20px 0;
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
    
    html_template = f'''<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>BrightMove RFP Response - City of Bowling Green</title>
    {css_style}
</head>
<body>
    {content}
</body>
</html>'''
    
    return html_template

def main():
    """Main function to convert markdown to HTML"""
    
    # File paths
    markdown_file = "output/BrightMove_RFP_Response_Bowling_Green_2025.md"
    html_file = "output/BrightMove_RFP_Response_Bowling_Green_2025.html"
    
    # Check if markdown file exists
    if not os.path.exists(markdown_file):
        print(f"Error: Markdown file not found: {markdown_file}")
        return
    
    # Read markdown file
    with open(markdown_file, 'r', encoding='utf-8') as f:
        markdown_content = f.read()
    
    # Convert to HTML
    html_content = simple_markdown_to_html(markdown_content)
    
    # Create complete HTML document
    full_html = create_html_document(html_content)
    
    # Save HTML file
    with open(html_file, 'w', encoding='utf-8') as f:
        f.write(full_html)
    
    print(f"HTML file generated: {html_file}")
    print("\nConversion complete!")
    print("\nTo convert to PDF:")
    print("1. Open the HTML file in a web browser")
    print("2. Use the browser's Print function (Ctrl+P or Cmd+P)")
    print("3. Select 'Save as PDF' as the destination")
    print("4. Adjust margins and settings as needed")
    print("5. Save the PDF file")

if __name__ == "__main__":
    main() 