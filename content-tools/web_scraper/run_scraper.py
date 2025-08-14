#!/usr/bin/env python3
"""
Script to run the BrightMove web scraper and organize content in knowledge-base
"""

import os
import subprocess
import sys

def main():
    print("🚀 Starting BrightMove Web Scraper")
    print("=" * 50)
    
    # Check if we're in the right directory
    if not os.path.exists('web_scraper'):
        print("❌ Error: web_scraper directory not found!")
        print("Please run this script from the sales-operations directory")
        sys.exit(1)
    
    # Change to web_scraper directory
    os.chdir('web_scraper')
    
    print("📁 Knowledge-base directory structure will be created:")
    print("knowledge-base/")
    print("├── website_content/          # All scraped website content")
    print("│   ├── brightmove/          # BrightMove's website content")
    print("│   │   ├── company/         # Company overview and information")
    print("│   │   ├── features/        # Product features and capabilities")
    print("│   │   ├── solutions/       # Solution offerings and use cases")
    print("│   │   ├── pricing/         # Pricing information and plans")
    print("│   │   ├── testimonials/    # Customer testimonials and reviews")
    print("│   │   ├── case_studies/    # Success stories and case studies")
    print("│   │   ├── technical/       # Technical specifications and APIs")
    print("│   │   ├── products/        # Product information")
    print("│   │   ├── services/        # Service offerings")
    print("│   │   ├── raw_data/        # Complete JSON data and all page content")
    print("│   │   └── index.txt        # Summary index file")
    print("│   ├── competitors/         # Competitor website content")
    print("│   ├── partners/            # Partner website content")
    print("│   └── industry_research/   # Industry research websites")
    print("├── documents/               # Sales documents and materials")
    print("├── presentations/           # Sales presentations and decks")
    print("├── templates/               # RFP/RPI response templates")
    print("└── research/                # Market research and analysis")
    print()
    
    # Run the spider
    print("🕷️  Running spider...")
    try:
        result = subprocess.run(['scrapy', 'crawl', 'brightmove_spider'], 
                              capture_output=True, text=True)
        
        if result.returncode == 0:
            print("✅ Spider completed successfully!")
            print()
            print("📊 Content has been organized in the knowledge-base folder:")
            
            # Show what was created
            knowledge_base = os.path.join('..', 'knowledge-base')
            if os.path.exists(knowledge_base):
                for root, dirs, files in os.walk(knowledge_base):
                    level = root.replace(knowledge_base, '').count(os.sep)
                    indent = ' ' * 2 * level
                    print(f"{indent}{os.path.basename(root)}/")
                    subindent = ' ' * 2 * (level + 1)
                    for file in files:
                        print(f"{subindent}{file}")
        else:
            print("❌ Spider failed!")
            print("STDOUT:", result.stdout)
            print("STDERR:", result.stderr)
            
    except Exception as e:
        print(f"❌ Error running spider: {e}")

if __name__ == "__main__":
    main() 