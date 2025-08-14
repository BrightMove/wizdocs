#!/usr/bin/env python3
"""
Inovium Web Scraper
Scrapes Inovium's website content for knowledge base
"""

import os
import subprocess
import sys
from datetime import datetime

def run_inovium_spider():
    """Run the Inovium spider to scrape their website"""
    print("🕷️  Starting Inovium website scraping...")
    print("=" * 50)
    
    # Change to web_scraper directory
    original_dir = os.getcwd()
    os.chdir('web_scraper')
    
    try:
        # Run the Inovium spider
        cmd = ['scrapy', 'crawl', 'inovium_spider']
        
        print(f"Running command: {' '.join(cmd)}")
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode == 0:
            print("✅ Successfully scraped Inovium website")
            print("📁 Content saved to knowledge-base/website_content/partners/inovium/")
            return True
        else:
            print("❌ Failed to scrape Inovium website")
            print("STDOUT:", result.stdout)
            print("STDERR:", result.stderr)
            return False
            
    except Exception as e:
        print(f"❌ Error scraping Inovium: {e}")
        return False
    finally:
        # Go back to original directory
        os.chdir(original_dir)

def show_inovium_content():
    """Display the scraped Inovium content structure"""
    inovium_dir = 'knowledge-base/website_content/partners/inovium'
    
    if not os.path.exists(inovium_dir):
        print("❌ Inovium content directory not found!")
        return
    
    print("\n📁 Inovium Content Structure:")
    print("=" * 40)
    
    for root, dirs, files in os.walk(inovium_dir):
        level = root.replace(inovium_dir, '').count(os.sep)
        indent = '  ' * level
        print(f"{indent}{os.path.basename(root)}/")
        
        # Show files
        subindent = '  ' * (level + 1)
        for file in files:
            if file.endswith(('.txt', '.json', '.md')):
                size = os.path.getsize(os.path.join(root, file))
                print(f"{subindent}{file} ({size} bytes)")

def show_inovium_summary():
    """Show a summary of scraped Inovium content"""
    inovium_dir = 'knowledge-base/website_content/partners/inovium'
    
    if not os.path.exists(inovium_dir):
        print("❌ Inovium content not found!")
        return
    
    # Read the index file if it exists
    index_file = os.path.join(inovium_dir, 'index.txt')
    if os.path.exists(index_file):
        print("\n📋 Inovium Content Summary:")
        print("=" * 40)
        with open(index_file, 'r', encoding='utf-8') as f:
            print(f.read())
    
    # Check for raw data
    raw_data_file = os.path.join(inovium_dir, 'raw_data', 'complete_scrape.json')
    if os.path.exists(raw_data_file):
        import json
        with open(raw_data_file, 'r', encoding='utf-8') as f:
            data = json.load(f)
            print(f"\n📊 Raw Data Summary:")
            print(f"• Total pages scraped: {len(data.get('pages', []))}")
            print(f"• Services found: {len(data.get('services', []))}")
            print(f"• Solutions found: {len(data.get('solutions', []))}")
            print(f"• Case studies found: {len(data.get('case_studies', []))}")
            print(f"• Team info found: {len(data.get('team', []))}")
            print(f"• Blog posts found: {len(data.get('blog_posts', []))}")

def main():
    """Main function"""
    print("🏢 Inovium Web Scraper")
    print("=" * 30)
    
    while True:
        print("\nOptions:")
        print("1. Scrape Inovium website")
        print("2. Show content structure")
        print("3. Show content summary")
        print("4. Exit")
        
        choice = input("\nSelect option (1-4): ").strip()
        
        if choice == '1':
            success = run_inovium_spider()
            if success:
                print("\n✅ Scraping completed successfully!")
            else:
                print("\n❌ Scraping failed!")
                
        elif choice == '2':
            show_inovium_content()
            
        elif choice == '3':
            show_inovium_summary()
            
        elif choice == '4':
            print("👋 Goodbye!")
            break
            
        else:
            print("❌ Invalid option. Please select 1-4.")

if __name__ == "__main__":
    main() 