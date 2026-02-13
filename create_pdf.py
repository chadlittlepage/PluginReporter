#!/usr/bin/env python3
"""
Generate PDF from Skills Assessment markdown file
Uses macOS native tools
"""

import subprocess
import os

# Read the markdown file
with open('SKILLS_ASSESSMENT.md', 'r', encoding='utf-8') as f:
    content = f.read()

# Create HTML with styling
html_content = f"""<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Coding Skills Assessment</title>
    <style>
        @media print {{
            @page {{ margin: 1.5cm; }}
        }}
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Helvetica Neue', Arial, sans-serif;
            line-height: 1.6;
            color: #1a1a1a;
            max-width: 900px;
            margin: 0 auto;
            padding: 40px 20px;
            background: white;
        }}
        h1 {{
            color: #0066cc;
            font-size: 32px;
            border-bottom: 4px solid #0066cc;
            padding-bottom: 12px;
            margin-bottom: 30px;
        }}
        h2 {{
            color: #0052a3;
            font-size: 24px;
            margin-top: 40px;
            margin-bottom: 15px;
            border-left: 4px solid #0066cc;
            padding-left: 15px;
        }}
        h3 {{
            color: #003d7a;
            font-size: 20px;
            margin-top: 25px;
            margin-bottom: 10px;
        }}
        h4 {{
            color: #002952;
            font-size: 16px;
            margin-top: 20px;
        }}
        p {{
            margin: 10px 0;
        }}
        table {{
            width: 100%;
            border-collapse: collapse;
            margin: 25px 0;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
        }}
        th {{
            background: linear-gradient(135deg, #0066cc 0%, #0052a3 100%);
            color: white;
            padding: 14px;
            text-align: left;
            font-weight: 600;
        }}
        td {{
            border: 1px solid #e0e0e0;
            padding: 12px;
        }}
        tr:nth-child(even) {{
            background-color: #f8f9fa;
        }}
        ul {{
            margin: 15px 0;
            padding-left: 30px;
        }}
        li {{
            margin: 8px 0;
        }}
        hr {{
            border: none;
            border-top: 2px solid #e0e0e0;
            margin: 35px 0;
        }}
        .highlight {{
            background: #fff3cd;
            border-left: 4px solid #ffc107;
            padding: 15px;
            margin: 20px 0;
        }}
        strong {{
            color: #0066cc;
            font-weight: 600;
        }}
        code {{
            background: #f4f4f4;
            padding: 2px 6px;
            border-radius: 3px;
            font-family: 'Monaco', 'Courier New', monospace;
            font-size: 0.9em;
        }}
        .footer {{
            margin-top: 50px;
            padding-top: 20px;
            border-top: 2px solid #e0e0e0;
            text-align: center;
            color: #666;
            font-size: 14px;
        }}
    </style>
</head>
<body>
"""

# Simple markdown to HTML conversion
lines = content.split('\n')
in_list = False
in_table = False
table_headers = False

for line in lines:
    # Headers
    if line.startswith('# '):
        html_content += f'<h1>{line[2:]}</h1>\n'
    elif line.startswith('## '):
        html_content += f'<h2>{line[3:]}</h2>\n'
    elif line.startswith('### '):
        html_content += f'<h3>{line[4:]}</h3>\n'
    elif line.startswith('#### '):
        html_content += f'<h4>{line[5:]}</h4>\n'
    # Horizontal rule
    elif line.strip() == '---':
        if in_list:
            html_content += '</ul>\n'
            in_list = False
        html_content += '<hr>\n'
    # Lists
    elif line.startswith('- '):
        if not in_list:
            html_content += '<ul>\n'
            in_list = True
        html_content += f'<li>{line[2:]}</li>\n'
    # Tables
    elif '|' in line and line.strip().startswith('|'):
        if not in_table:
            html_content += '<table>\n'
            in_table = True
        cells = [cell.strip() for cell in line.strip().split('|')[1:-1]]
        if not table_headers and cells:
            html_content += '<tr>\n'
            for cell in cells:
                html_content += f'<th>{cell}</th>\n'
            html_content += '</tr>\n'
            table_headers = True
        elif not all(c.strip().startswith('-') for c in cells):
            html_content += '<tr>\n'
            for cell in cells:
                html_content += f'<td>{cell}</td>\n'
            html_content += '</tr>\n'
    # Empty line
    elif not line.strip():
        if in_list:
            html_content += '</ul>\n'
            in_list = False
        if in_table:
            html_content += '</table>\n'
            in_table = False
            table_headers = False
        html_content += '<p></p>\n'
    # Regular text
    else:
        if in_list:
            html_content += '</ul>\n'
            in_list = False
        # Bold text
        while '**' in line:
            start = line.find('**')
            end = line.find('**', start + 2)
            if end != -1:
                line = line[:start] + '<strong>' + line[start+2:end] + '</strong>' + line[end+2:]
            else:
                break
        html_content += f'<p>{line}</p>\n'

# Close any open tags
if in_list:
    html_content += '</ul>\n'
if in_table:
    html_content += '</table>\n'

html_content += """
<div class="footer">
    <p>Generated from Plugin Reporter v005 Project</p>
    <p>Assessment Date: January 2025</p>
</div>
</body>
</html>
"""

# Write HTML file
html_file = '/tmp/skills_assessment_formatted.html'
with open(html_file, 'w', encoding='utf-8') as f:
    f.write(html_content)

print(f"HTML file created: {html_file}")
print("\nGenerating PDF using system tools...")

# Try to convert to PDF using wkhtmltopdf if available, otherwise use system print
try:
    # Check if wkhtmltopdf exists
    result = subprocess.run(['which', 'wkhtmltopdf'], capture_output=True)
    if result.returncode == 0:
        subprocess.run([
            'wkhtmltopdf',
            '--enable-local-file-access',
            '--print-media-type',
            html_file,
            'SKILLS_ASSESSMENT.pdf'
        ])
        print("✅ PDF created: SKILLS_ASSESSMENT.pdf")
    else:
        print("\n📄 HTML file created successfully!")
        print(f"   Open in browser: file://{html_file}")
        print("\n💡 To create PDF:")
        print("   1. Open the HTML file in Safari")
        print(f"      open -a Safari {html_file}")
        print("   2. Press Cmd+P to print")
        print("   3. Click 'PDF' button in bottom-left")
        print("   4. Choose 'Save as PDF'")
        print(f"   5. Save to: {os.getcwd()}/SKILLS_ASSESSMENT.pdf")

        # Try to open in Safari automatically
        subprocess.run(['open', '-a', 'Safari', html_file])

except Exception as e:
    print(f"Note: {e}")
    print(f"\n📄 HTML created at: {html_file}")
    print("   Open it in a browser and print to PDF manually.")
