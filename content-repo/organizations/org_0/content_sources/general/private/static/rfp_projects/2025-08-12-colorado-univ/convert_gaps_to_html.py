import markdown
import re

def convert_gaps_to_html():
    # Read the markdown file
    with open("output/GAPS_ANALYSIS_FOR_MIKE.md", "r") as f:
        md_content = f.read()
    
    # Convert markdown to HTML
    html_content = markdown.markdown(md_content, extensions=['tables', 'fenced_code'])
    
    # Create a complete HTML document with styling for printing
    full_html = f"""
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>BrightMove Colorado University RFP - Gaps Analysis</title>
    <style>
        body {{
            font-family: Arial, sans-serif;
            line-height: 1.6;
            margin: 0;
            padding: 20px;
            color: #333;
        }}
        
        h1 {{
            color: #2c3e50;
            border-bottom: 3px solid #3498db;
            padding-bottom: 10px;
            margin-bottom: 30px;
        }}
        
        h2 {{
            color: #34495e;
            border-bottom: 2px solid #bdc3c7;
            padding-bottom: 5px;
            margin-top: 30px;
            margin-bottom: 20px;
        }}
        
        h3 {{
            color: #2c3e50;
            margin-top: 25px;
            margin-bottom: 15px;
        }}
        
        h4 {{
            color: #34495e;
            margin-top: 20px;
            margin-bottom: 10px;
        }}
        
        .high-impact {{
            background-color: #ffebee;
            border-left: 4px solid #f44336;
            padding: 15px;
            margin: 15px 0;
        }}
        
        .medium-impact {{
            background-color: #fff3e0;
            border-left: 4px solid #ff9800;
            padding: 15px;
            margin: 15px 0;
        }}
        
        .capabilities {{
            background-color: #e8f5e8;
            border-left: 4px solid #4caf50;
            padding: 15px;
            margin: 15px 0;
        }}
        
        .questions {{
            background-color: #e3f2fd;
            border-left: 4px solid #2196f3;
            padding: 15px;
            margin: 15px 0;
        }}
        
        ul, ol {{
            margin-left: 20px;
        }}
        
        li {{
            margin-bottom: 5px;
        }}
        
        strong {{
            color: #2c3e50;
        }}
        
        .status-high {{
            color: #f44336;
            font-weight: bold;
        }}
        
        .status-medium {{
            color: #ff9800;
            font-weight: bold;
        }}
        
        .status-meets {{
            color: #4caf50;
            font-weight: bold;
        }}
        
        @media print {{
            body {{
                font-size: 12pt;
                line-height: 1.4;
            }}
            
            h1 {{
                font-size: 18pt;
            }}
            
            h2 {{
                font-size: 16pt;
            }}
            
            h3 {{
                font-size: 14pt;
            }}
            
            h4 {{
                font-size: 13pt;
            }}
            
            .high-impact, .medium-impact, .capabilities, .questions {{
                break-inside: avoid;
                page-break-inside: avoid;
            }}
            
            .page-break {{
                page-break-before: always;
            }}
        }}
        
        .header-info {{
            background-color: #f8f9fa;
            border: 1px solid #dee2e6;
            padding: 15px;
            margin-bottom: 30px;
            border-radius: 5px;
        }}
        
        .contact-info {{
            background-color: #e8f5e8;
            border: 1px solid #4caf50;
            padding: 15px;
            margin-top: 30px;
            border-radius: 5px;
        }}
    </style>
</head>
<body>
    <div class="header-info">
        <h1>BRIGHTMOVE COLORADO UNIVERSITY RFP - GAPS ANALYSIS</h1>
        <p><strong>For Review with Mike Brandt</strong></p>
        <p><strong>Date:</strong> {__import__('datetime').datetime.now().strftime('%B %d, %Y')}</p>
        <p><strong>Purpose:</strong> Identify and address capability gaps before finalizing RFP response</p>
    </div>

    {html_content}
    
    <div class="contact-info">
        <h3>Contact Information</h3>
        <p><strong>Mike Brandt:</strong> Head of Alliances, Inovium</p>
        <p><strong>Email:</strong> michael.brandt@inovium.com</p>
        <p><strong>Meeting Request:</strong> Schedule 1-hour call to review gaps analysis</p>
    </div>
    
    <div style="margin-top: 40px; padding-top: 20px; border-top: 1px solid #ccc; font-size: 0.9em; color: #666;">
        <p><em>This analysis is based on documented knowledge base content and should be verified with Mike before finalizing the RFP response.</em></p>
        <p><em>Generated on: {__import__('datetime').datetime.now().strftime('%B %d, %Y at %I:%M %p')}</em></p>
    </div>
</body>
</html>
"""
    
    # Write the HTML file
    with open("output/GAPS_ANALYSIS_FOR_MIKE.html", "w") as f:
        f.write(full_html)
    
    print("HTML file created: output/GAPS_ANALYSIS_FOR_MIKE.html")
    print("You can now open this file in a browser and print it.")

if __name__ == "__main__":
    convert_gaps_to_html()
