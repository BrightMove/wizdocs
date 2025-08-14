import scrapy
import json
import os
from urllib.parse import urljoin, urlparse
from datetime import datetime
import re


class UniversalSpiderSpider(scrapy.Spider):
    name = "universal_spider"
    
    def __init__(self, website_name=None, start_url=None, allowed_domains=None, *args, **kwargs):
        super(UniversalSpiderSpider, self).__init__(*args, **kwargs)
        
        # Set website-specific parameters
        self.website_name = website_name or 'unknown_website'
        self.start_urls = [start_url] if start_url else []
        self.allowed_domains = allowed_domains or []
        
        # Create knowledge-base directory structure
        self.knowledge_base_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), 'knowledge-base')
        self.website_content_dir = os.path.join(self.knowledge_base_dir, 'website_content')
        self.create_directory_structure()
        
        # Track scraped content
        self.scraped_content = {
            'website_info': {
                'name': self.website_name,
                'start_url': start_url,
                'scraped_at': datetime.now().isoformat()
            },
            'company_info': {},
            'features': [],
            'solutions': [],
            'pages': [],
            'pricing': [],
            'testimonials': [],
            'case_studies': [],
            'technical_specs': [],
            'products': [],
            'services': []
        }

    def create_directory_structure(self):
        """Create organized directory structure in knowledge-base/website_content"""
        # Main knowledge-base structure
        main_dirs = [
            'website_content',
            'documents',
            'presentations',
            'templates',
            'research'
        ]
        
        for directory in main_dirs:
            dir_path = os.path.join(self.knowledge_base_dir, directory)
            os.makedirs(dir_path, exist_ok=True)
        
        # Website content subdirectories
        website_dirs = [
            'brightmove',
            'competitors',
            'partners',
            'industry_research'
        ]
        
        for directory in website_dirs:
            dir_path = os.path.join(self.website_content_dir, directory)
            os.makedirs(dir_path, exist_ok=True)
            
            # Create subdirectories for each website
            subdirs = [
                'company',
                'features',
                'solutions', 
                'pricing',
                'testimonials',
                'case_studies',
                'technical',
                'products',
                'services',
                'raw_data'
            ]
            
            for subdir in subdirs:
                subdir_path = os.path.join(dir_path, subdir)
                os.makedirs(subdir_path, exist_ok=True)

    def parse(self, response):
        """Parse the main page and extract key information"""
        # Extract company information
        company_info = {
            'url': response.url,
            'title': response.css('title::text').get(),
            'description': response.css('meta[name="description"]::attr(content)').get(),
            'keywords': response.css('meta[name="keywords"]::attr(content)').get(),
            'scraped_at': datetime.now().isoformat()
        }
        
        # Extract main content sections
        main_content = {
            'headlines': [h.strip() for h in response.css('h1, h2, h3::text').getall() if h.strip()],
            'paragraphs': [p.strip() for p in response.css('p::text').getall() if p.strip()],
            'features': [f.strip() for f in response.css('[class*="feature"], [class*="benefit"]::text').getall() if f.strip()],
            'cta_text': [c.strip() for c in response.css('[class*="button"], [class*="cta"]::text').getall() if c.strip()],
            'navigation': [n.strip() for n in response.css('nav a::text').getall() if n.strip()]
        }
        
        self.scraped_content['company_info'] = company_info
        self.scraped_content['pages'].append({
            'url': response.url,
            'content': main_content
        })
        
        # Follow links to other pages
        for link in response.css('a::attr(href)').getall():
            if link and not link.startswith(('#', 'javascript:', 'mailto:')):
                full_url = urljoin(response.url, link)
                if any(domain in full_url for domain in self.allowed_domains):
                    yield scrapy.Request(full_url, callback=self.parse_page)
    
    def parse_page(self, response):
        """Parse individual pages"""
        page_content = {
            'url': response.url,
            'title': response.css('title::text').get(),
            'headlines': [h.strip() for h in response.css('h1, h2, h3::text').getall() if h.strip()],
            'paragraphs': [p.strip() for p in response.css('p::text').getall() if p.strip()],
            'lists': [l.strip() for l in response.css('ul li::text, ol li::text').getall() if l.strip()],
            'scraped_at': datetime.now().isoformat()
        }
        
        self.scraped_content['pages'].append(page_content)
        
        # Categorize content based on URL and content
        self.categorize_content(response.url, page_content)
    
    def categorize_content(self, url, content):
        """Categorize content based on URL patterns and content"""
        url_lower = url.lower()
        
        # Features
        if any(keyword in url_lower for keyword in ['feature', 'capability', 'functionality']):
            features = content.get('headlines', []) + content.get('paragraphs', [])
            self.scraped_content['features'].extend(features)
        
        # Solutions
        if any(keyword in url_lower for keyword in ['solution', 'use-case', 'industry']):
            solutions = content.get('headlines', []) + content.get('paragraphs', [])
            self.scraped_content['solutions'].extend(solutions)
        
        # Pricing
        if any(keyword in url_lower for keyword in ['pricing', 'price', 'cost', 'plan']):
            pricing = content.get('headlines', []) + content.get('paragraphs', [])
            self.scraped_content['pricing'].extend(pricing)
        
        # Testimonials
        if any(keyword in url_lower for keyword in ['testimonial', 'review', 'customer']):
            testimonials = content.get('paragraphs', [])
            self.scraped_content['testimonials'].extend(testimonials)
        
        # Case Studies
        if any(keyword in url_lower for keyword in ['case-study', 'case', 'success']):
            case_studies = content.get('headlines', []) + content.get('paragraphs', [])
            self.scraped_content['case_studies'].extend(case_studies)
        
        # Technical specs
        if any(keyword in url_lower for keyword in ['technical', 'spec', 'api', 'integration']):
            tech_specs = content.get('headlines', []) + content.get('paragraphs', [])
            self.scraped_content['technical_specs'].extend(tech_specs)
        
        # Products
        if any(keyword in url_lower for keyword in ['product', 'platform', 'software']):
            products = content.get('headlines', []) + content.get('paragraphs', [])
            self.scraped_content['products'].extend(products)
        
        # Services
        if any(keyword in url_lower for keyword in ['service', 'consulting', 'support']):
            services = content.get('headlines', []) + content.get('paragraphs', [])
            self.scraped_content['services'].extend(services)
    
    def closed(self, reason):
        """Save scraped content when spider finishes"""
        # Save all content to knowledge-base with organized structure
        self.save_organized_content()
        
        self.logger.info(f"All scraped content saved to {self.website_content_dir}/{self.website_name}")
    
    def save_organized_content(self):
        """Save content in organized structure under website_content/[website_name]"""
        website_dir = os.path.join(self.website_content_dir, self.website_name)
        
        # Save raw JSON data
        raw_data_file = os.path.join(website_dir, 'raw_data', 'complete_scrape.json')
        with open(raw_data_file, 'w', encoding='utf-8') as f:
            json.dump(self.scraped_content, f, indent=2, ensure_ascii=False)
        
        # Save company information
        if self.scraped_content['company_info']:
            company_file = os.path.join(website_dir, 'company', 'company_overview.txt')
            with open(company_file, 'w', encoding='utf-8') as f:
                f.write(f"{self.website_name.upper()} COMPANY OVERVIEW\n")
                f.write("=" * 50 + "\n\n")
                f.write(f"Title: {self.scraped_content['company_info'].get('title', 'N/A')}\n")
                f.write(f"Description: {self.scraped_content['company_info'].get('description', 'N/A')}\n")
                f.write(f"Keywords: {self.scraped_content['company_info'].get('keywords', 'N/A')}\n")
                f.write(f"Scraped from: {self.scraped_content['company_info'].get('url', 'N/A')}\n")
                f.write(f"Scraped at: {self.scraped_content['company_info'].get('scraped_at', 'N/A')}\n")
        
        # Save all categorized content
        content_categories = {
            'features': 'FEATURES',
            'solutions': 'SOLUTIONS', 
            'pricing': 'PRICING INFORMATION',
            'testimonials': 'TESTIMONIALS',
            'case_studies': 'CASE STUDIES',
            'technical_specs': 'TECHNICAL SPECIFICATIONS',
            'products': 'PRODUCTS',
            'services': 'SERVICES'
        }
        
        for category, title in content_categories.items():
            if self.scraped_content[category]:
                category_file = os.path.join(website_dir, category, f'{category}.txt')
                with open(category_file, 'w', encoding='utf-8') as f:
                    f.write(f"{self.website_name.upper()} {title}\n")
                    f.write("=" * (len(title) + 10) + "\n\n")
                    unique_items = list(set(self.scraped_content[category]))
                    for item in unique_items:
                        if item.strip():
                            if category == 'testimonials':
                                f.write(f"\"{item.strip()}\"\n\n")
                            else:
                                f.write(f"• {item.strip()}\n")
        
        # Save comprehensive page content
        pages_file = os.path.join(website_dir, 'raw_data', 'all_pages.txt')
        with open(pages_file, 'w', encoding='utf-8') as f:
            f.write(f"{self.website_name.upper()} ALL PAGE CONTENT\n")
            f.write("=" * 35 + "\n\n")
            for page in self.scraped_content['pages']:
                f.write(f"URL: {page.get('url', 'N/A')}\n")
                f.write(f"Title: {page.get('title', 'N/A')}\n")
                f.write("-" * 50 + "\n")
                
                if page.get('headlines'):
                    f.write("HEADLINES:\n")
                    for headline in page['headlines']:
                        if headline.strip():
                            f.write(f"  {headline.strip()}\n")
                
                if page.get('paragraphs'):
                    f.write("CONTENT:\n")
                    for para in page['paragraphs']:
                        if para.strip():
                            f.write(f"  {para.strip()}\n")
                
                if page.get('lists'):
                    f.write("LISTS:\n")
                    for item in page['lists']:
                        if item.strip():
                            f.write(f"  • {item.strip()}\n")
                
                f.write("\n" + "=" * 50 + "\n\n")
        
        # Create a summary index file for this website
        self.create_website_index(website_dir)
    
    def create_website_index(self, website_dir):
        """Create a summary index file for the specific website"""
        index_file = os.path.join(website_dir, 'index.txt')
        with open(index_file, 'w', encoding='utf-8') as f:
            f.write(f"{self.website_name.upper()} WEBSITE CONTENT INDEX\n")
            f.write("=" * 40 + "\n\n")
            f.write(f"This directory contains scraped content from {self.website_name}'s website.\n\n")
            f.write("DIRECTORY STRUCTURE:\n")
            f.write("-" * 25 + "\n")
            f.write("company/ - Company overview and information\n")
            f.write("features/ - Product features and capabilities\n")
            f.write("solutions/ - Solution offerings and use cases\n")
            f.write("pricing/ - Pricing information and plans\n")
            f.write("testimonials/ - Customer testimonials and reviews\n")
            f.write("case_studies/ - Success stories and case studies\n")
            f.write("technical/ - Technical specifications and APIs\n")
            f.write("products/ - Product information\n")
            f.write("services/ - Service offerings\n")
            f.write("raw_data/ - Complete JSON data and all page content\n\n")
            
            f.write("CONTENT SUMMARY:\n")
            f.write("-" * 20 + "\n")
            f.write(f"Total pages scraped: {len(self.scraped_content['pages'])}\n")
            f.write(f"Features found: {len(set(self.scraped_content['features']))}\n")
            f.write(f"Solutions found: {len(set(self.scraped_content['solutions']))}\n")
            f.write(f"Pricing items: {len(set(self.scraped_content['pricing']))}\n")
            f.write(f"Testimonials: {len(set(self.scraped_content['testimonials']))}\n")
            f.write(f"Case studies: {len(set(self.scraped_content['case_studies']))}\n")
            f.write(f"Technical specs: {len(set(self.scraped_content['technical_specs']))}\n")
            f.write(f"Products: {len(set(self.scraped_content['products']))}\n")
            f.write(f"Services: {len(set(self.scraped_content['services']))}\n")
            f.write(f"Scraped at: {datetime.now().isoformat()}\n") 