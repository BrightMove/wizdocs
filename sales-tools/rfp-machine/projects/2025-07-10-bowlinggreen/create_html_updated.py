#!/usr/bin/env python3

import re
import os

def simple_markdown_to_html(markdown_content):
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
    
    # Convert paragraphs
    lines = html.split('\n')
    processed_lines = []
    
    for line in lines:
        line = line.strip()
        if line and not line.startswith('<') and not line.startswith('|'):
            processed_lines.append(f'<p>{line}</p>')
        else:
            processed_lines.append(line)
    
    return '\n'.join(processed_lines)

def create_html_document(content):
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
        margin-top: 30px;
    }
    h2 {
        color: #34495e;
        border-bottom: 1px solid #bdc3c7;
        padding-bottom: 5px;
        margin-top: 25px;
    }
    h3 {
        color: #2980b9;
        margin-top: 20px;
    }
    ul {
        margin: 10px 0;
        padding-left: 20px;
    }
    li {
        margin: 5px 0;
    }
    strong {
        color: #2c3e50;
    }
    hr {
        border: none;
        border-top: 1px solid #bdc3c7;
        margin: 20px 0;
    }
    p {
        margin: 10px 0;
        text-align: justify;
    }
    </style>
    '''
    
    doctype = '<!DOCTYPE html>'
    html_open = '<html>'
    head_open = '<head>'
    meta_charset = '<meta charset="utf-8">'
    title = '<title>BrightMove RFP Response - City of Bowling Green</title>'
    head_close = '</head>'
    body_open = '<body>'
    body_close = '</body>'
    html_close = '</html>'
    
    return f'{doctype}\n{html_open}\n{head_open}\n{meta_charset}\n{title}\n{css_style}\n{head_close}\n{body_open}\n{content}\n{body_close}\n{html_close}'

if __name__ == "__main__":
    # Read the updated markdown file
    with open('output/BrightMove_RFP_Response_Bowling_Green_2025_Updated.md', 'r', encoding='utf-8') as f:
        markdown_content = f.read()

    # Convert to HTML
    html_content = simple_markdown_to_html(markdown_content)
    html_document = create_html_document(html_content)

    # Write HTML file
    with open('output/BrightMove_RFP_Response_Bowling_Green_2025_Updated.html', 'w', encoding='utf-8') as f:
        f.write(html_document)

    print('Successfully created updated HTML version of the RFP response')
    print('Files created:')
    print('- output/BrightMove_RFP_Response_Bowling_Green_2025_Updated.md')
    print('- output/BrightMove_RFP_Response_Bowling_Green_2025_Updated.html') 