#!/usr/bin/env python3
"""
Multi-site web scraper for organizing content in knowledge-base
"""

import os
import subprocess
import sys
import json
from datetime import datetime

# Website configurations
WEBSITE_CONFIGS = {
    'brightmove': {
        'name': 'brightmove',
        'start_url': 'https://brightmove.com',
        'allowed_domains': ['brightmove.com'],
        'category': 'brightmove'
    },
    'support_brightmove': {
        'name': 'support_brightmove',
        'start_url': 'https://support.brightmove.com',
        'allowed_domains': ['support.brightmove.com'],
        'category': 'brightmove'
    },
    'competitor1': {
        'name': 'competitor1',
        'start_url': 'https://example-competitor.com',
        'allowed_domains': ['example-competitor.com'],
        'category': 'competitors'
    },
    'partner1': {
        'name': 'partner1', 
        'start_url': 'https://example-partner.com',
        'allowed_domains': ['example-partner.com'],
        'category': 'partners'
    },
    'inovium': {
        'name': 'inovium',
        'start_url': 'https://www.inovium.com',
        'allowed_domains': ['inovium.com'],
        'category': 'partners'
    }
}

def create_knowledge_base_structure():
    """Create the main knowledge-base directory structure"""
    knowledge_base = 'knowledge-base'
    
    # Main directories
    main_dirs = [
        'website_content',
        'documents',
        'presentations', 
        'templates',
        'research'
    ]
    
    for directory in main_dirs:
        dir_path = os.path.join(knowledge_base, directory)
        os.makedirs(dir_path, exist_ok=True)
    
    # Website content subdirectories
    website_dirs = [
        'brightmove',
        'competitors',
        'partners',
        'industry_research'
    ]
    
    for directory in website_dirs:
        dir_path = os.path.join(knowledge_base, 'website_content', directory)
        os.makedirs(dir_path, exist_ok=True)
    
    print("✅ Knowledge-base directory structure created")

def run_spider(website_config):
    """Run the universal spider for a specific website"""
    print(f"🕷️  Scraping {website_config['name']}...")
    
    # Change to web_scraper directory
    os.chdir('web_scraper')
    
    # Build the scrapy command with custom settings
    cmd = [
        'scrapy', 'crawl', 'universal_spider',
        '-a', f"website_name={website_config['name']}",
        '-a', f"start_url={website_config['start_url']}",
        '-a', f"allowed_domains={','.join(website_config['allowed_domains'])}"
    ]
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode == 0:
            print(f"✅ Successfully scraped {website_config['name']}")
            return True
        else:
            print(f"❌ Failed to scrape {website_config['name']}")
            print("STDOUT:", result.stdout)
            print("STDERR:", result.stderr)
            return False
            
    except Exception as e:
        print(f"❌ Error scraping {website_config['name']}: {e}")
        return False
    finally:
        # Go back to main directory
        os.chdir('..')

def scrape_all_websites():
    """Scrape all configured websites"""
    print("🚀 Starting multi-site web scraping")
    print("=" * 50)
    
    # Create directory structure
    create_knowledge_base_structure()
    
    results = {}
    
    for website_id, config in WEBSITE_CONFIGS.items():
        print(f"\n📋 Processing {config['name']}...")
        success = run_spider(config)
        results[website_id] = {
            'name': config['name'],
            'success': success,
            'timestamp': datetime.now().isoformat()
        }
    
    # Save scraping results
    results_file = os.path.join('knowledge-base', 'scraping_results.json')
    with open(results_file, 'w') as f:
        json.dump(results, f, indent=2)
    
    # Create summary
    print("\n📊 Scraping Summary:")
    print("-" * 30)
    successful = sum(1 for r in results.values() if r['success'])
    total = len(results)
    print(f"Successfully scraped: {successful}/{total} websites")
    
    for website_id, result in results.items():
        status = "✅" if result['success'] else "❌"
        print(f"{status} {result['name']}")
    
    return results

def show_knowledge_base_structure():
    """Display the knowledge-base directory structure"""
    knowledge_base = 'knowledge-base'
    
    if not os.path.exists(knowledge_base):
        print("❌ Knowledge-base directory not found!")
        return
    
    print("\n📁 Knowledge-base structure:")
    print("=" * 40)
    
    for root, dirs, files in os.walk(knowledge_base):
        level = root.replace(knowledge_base, '').count(os.sep)
        indent = '  ' * level
        print(f"{indent}{os.path.basename(root)}/")
        
        # Show files
        subindent = '  ' * (level + 1)
        for file in files:
            if file.endswith(('.txt', '.json', '.md')):
                print(f"{subindent}{file}")

def add_new_website():
    """Interactive function to add a new website configuration"""
    print("\n➕ Add New Website Configuration")
    print("-" * 35)
    
    name = input("Website name (e.g., 'competitor2'): ").strip()
    start_url = input("Start URL (e.g., 'https://example.com'): ").strip()
    domain = input("Domain (e.g., 'example.com'): ").strip()
    category = input("Category (brightmove/competitors/partners/industry_research): ").strip()
    
    if not all([name, start_url, domain, category]):
        print("❌ All fields are required!")
        return
    
    # Add to configurations
    WEBSITE_CONFIGS[name] = {
        'name': name,
        'start_url': start_url,
        'allowed_domains': [domain],
        'category': category
    }
    
    print(f"✅ Added {name} to website configurations")
    
    # Save updated config
    config_file = 'website_configs.json'
    with open(config_file, 'w') as f:
        json.dump(WEBSITE_CONFIGS, f, indent=2)
    
    print(f"💾 Configuration saved to {config_file}")

def main():
    """Main function with menu"""
    while True:
        print("\n🌐 Multi-Site Web Scraper")
        print("=" * 30)
        print("1. Scrape all configured websites")
        print("2. Scrape specific website")
        print("3. Add new website configuration")
        print("4. Show knowledge-base structure")
        print("5. Exit")
        
        choice = input("\nSelect an option (1-5): ").strip()
        
        if choice == '1':
            scrape_all_websites()
        elif choice == '2':
            print("\nConfigured websites:")
            for i, (website_id, config) in enumerate(WEBSITE_CONFIGS.items(), 1):
                print(f"{i}. {config['name']} ({config['start_url']})")
            
            try:
                website_choice = int(input("Select website number: ")) - 1
                website_ids = list(WEBSITE_CONFIGS.keys())
                if 0 <= website_choice < len(website_ids):
                    website_id = website_ids[website_choice]
                    run_spider(WEBSITE_CONFIGS[website_id])
                else:
                    print("❌ Invalid selection!")
            except ValueError:
                print("❌ Please enter a valid number!")
        elif choice == '3':
            add_new_website()
        elif choice == '4':
            show_knowledge_base_structure()
        elif choice == '5':
            print("👋 Goodbye!")
            break
        else:
            print("❌ Invalid option!")

if __name__ == "__main__":
    main() 