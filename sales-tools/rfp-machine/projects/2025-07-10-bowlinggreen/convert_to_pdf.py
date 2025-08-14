#!/usr/bin/env python3
"""
Convert Markdown RFP response to PDF with professional styling
"""

import markdown
from weasyprint import HTML, CSS
import os

def convert_md_to_pdf(md_file, pdf_file):
    """Convert Markdown file to PDF with professional styling"""
    
    # Read the markdown file
    with open(md_file, 'r', encoding='utf-8') as f:
        md_content = f.read()
    
    # Convert markdown to HTML
    html_content = markdown.markdown(md_content, extensions=['tables', 'fenced_code'])
    
    # Create professional CSS styling
    css_content = """
    @page {
        margin: 1in;
        @top-center {
            content: "BrightMove RFP Response - RFP 2025-46";
            font-size: 10pt;
            color: #666;
        }
        @bottom-center {
            content: "Page " counter(page) " of " counter(pages);
            font-size: 10pt;
            color: #666;
        }
    }
    
    body {
        font-family: 'Helvetica Neue', Arial, sans-serif;
        line-height: 1.6;
        color: #333;
        max-width: 100%;
        margin: 0;
        padding: 0;
    }
    
    h1 {
        color: #2c3e50;
        font-size: 28pt;
        font-weight: bold;
        border-bottom: 3px solid #3498db;
        padding-bottom: 10px;
        margin-top: 0;
        margin-bottom: 30px;
    }
    
    h2 {
        color: #34495e;
        font-size: 20pt;
        font-weight: bold;
        margin-top: 30px;
        margin-bottom: 15px;
        border-left: 4px solid #3498db;
        padding-left: 15px;
    }
    
    h3 {
        color: #2c3e50;
        font-size: 16pt;
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
    """
    
    # Wrap HTML content with proper structure
    full_html = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <title>BrightMove RFP Response</title>
        <style>{css_content}</style>
    </head>
    <body>
        {html_content}
    </body>
    </html>
    """
    
    # Generate PDF
    HTML(string=full_html).write_pdf(pdf_file)
    
    print(f"✅ Successfully converted {md_file} to {pdf_file}")
    print(f"📄 PDF saved as: {os.path.abspath(pdf_file)}")

if __name__ == "__main__":
    md_file = "BrightMove_RFP_Response.md"
    pdf_file = "BrightMove_RFP_Response.pdf"
    
    if os.path.exists(md_file):
        convert_md_to_pdf(md_file, pdf_file)
    else:
        print(f"❌ Error: {md_file} not found!")
        print("Please make sure the Markdown file exists in the current directory.") 