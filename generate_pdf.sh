#!/bin/bash

# Generate PDF from Skills Assessment using macOS Safari/WebKit

cat > /tmp/skills_assessment.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Coding Skills Assessment</title>
    <style>
        @page {
            size: A4;
            margin: 2cm;
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
        }
        h1 {
            color: #1a73e8;
            border-bottom: 3px solid #1a73e8;
            padding-bottom: 10px;
        }
        h2 {
            color: #1967d2;
            margin-top: 30px;
        }
        h3 {
            color: #185abc;
            margin-top: 20px;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin: 20px 0;
        }
        th, td {
            border: 1px solid #ddd;
            padding: 12px;
            text-align: left;
        }
        th {
            background-color: #1a73e8;
            color: white;
        }
        tr:nth-child(even) {
            background-color: #f2f2f2;
        }
        .highlight {
            background-color: #fff3cd;
            padding: 15px;
            border-left: 4px solid #ffc107;
            margin: 20px 0;
        }
        .checkmark {
            color: #34a853;
            font-weight: bold;
        }
        hr {
            border: none;
            border-top: 2px solid #e0e0e0;
            margin: 30px 0;
        }
        ul {
            margin-left: 20px;
        }
        li {
            margin: 5px 0;
        }
    </style>
</head>
<body>
EOF

# Convert markdown to HTML (simplified version)
sed -e 's/^# \(.*\)$/<h1>\1<\/h1>/' \
    -e 's/^## \(.*\)$/<h2>\1<\/h2>/' \
    -e 's/^### \(.*\)$/<h3>\1<\/h3>/' \
    -e 's/^#### \(.*\)$/<h4>\1<\/h4>/' \
    -e 's/^\*\*\(.*\)\*\*$/<strong>\1<\/strong>/' \
    -e 's/\*\*\([^*]*\)\*\*/<strong>\1<\/strong>/g' \
    -e 's/^- \(.*\)$/<li>\1<\/li>/' \
    -e 's/^---$/<hr>/' \
    -e 's/✅/<span class="checkmark">✅<\/span>/g' \
    -e 's/^$/<br>/' \
    SKILLS_ASSESSMENT.md >> /tmp/skills_assessment.html

cat >> /tmp/skills_assessment.html << 'EOF'
</body>
</html>
EOF

# Use Safari to generate PDF
osascript << 'APPLESCRIPT'
set htmlFile to POSIX file "/tmp/skills_assessment.html"
set pdfFile to POSIX file ((POSIX path of (path to current user folder)) & "Documents/APPs/PluginReporter/SKILLS_ASSESSMENT.pdf")

tell application "Safari"
    activate
    open htmlFile
    delay 2
    tell application "System Events"
        keystroke "p" using command down
        delay 1
        keystroke return
    end tell
end tell
APPLESCRIPT

echo "PDF generation initiated. Please save the PDF manually when Safari's print dialog appears."
echo "Target location: ~/Documents/APPs/PluginReporter/SKILLS_ASSESSMENT.pdf"
EOF

chmod +x generate_pdf.sh
