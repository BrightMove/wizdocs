import scrapy
import json
import os
from urllib.parse import urljoin, urlparse
from datetime import datetime
import re


class BrightmoveSpiderSpider(scrapy.Spider):
    name = "brightmove_spider"
    allowed_domains = ["brightmove.com"]
    start_urls = ["https://brightmove.com"]
    
    def __init__(self, *args, **kwargs):
        super(BrightmoveSpiderSpider, self).__init__(*args, **kwargs)
        # Create knowledge-base directory structure with website_content subfolder
        self.knowledge_base_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), 'knowledge-base')
        self.website_content_dir = os.path.join(self.knowledge_base_dir, 'website_content')
        self.create_directory_structure()
        
        # Track scraped content
        self.scraped_content = {
            'company_info': {},
            'features': [],
            'solutions': [],
            'pages': [],
            'pricing': [],
            'testimonials': [],
            'case_studies': [],
            'technical_specs': []
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
                if 'brightmove.com' in full_url:
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
    
    def closed(self, reason):
        """Save scraped content when spider finishes"""
        # Save all content to knowledge-base with organized structure
        self.save_organized_content()
        
        self.logger.info(f"All scraped content saved to {self.website_content_dir}/brightmove")
    
    def save_organized_content(self):
        """Save content in organized structure under website_content/brightmove"""
        brightmove_dir = os.path.join(self.website_content_dir, 'brightmove')
        
        # Save raw JSON data
        raw_data_file = os.path.join(brightmove_dir, 'raw_data', 'complete_scrape.json')
        with open(raw_data_file, 'w', encoding='utf-8') as f:
            json.dump(self.scraped_content, f, indent=2, ensure_ascii=False)
        
        # Save company information
        if self.scraped_content['company_info']:
            company_file = os.path.join(brightmove_dir, 'company', 'company_overview.txt')
            with open(company_file, 'w', encoding='utf-8') as f:
                f.write("BRIGHTMOVE COMPANY OVERVIEW\n")
                f.write("=" * 50 + "\n\n")
                f.write(f"Title: {self.scraped_content['company_info'].get('title', 'N/A')}\n")
                f.write(f"Description: {self.scraped_content['company_info'].get('description', 'N/A')}\n")
                f.write(f"Keywords: {self.scraped_content['company_info'].get('keywords', 'N/A')}\n")
                f.write(f"Scraped from: {self.scraped_content['company_info'].get('url', 'N/A')}\n")
                f.write(f"Scraped at: {self.scraped_content['company_info'].get('scraped_at', 'N/A')}\n")
        
        # Save features
        if self.scraped_content['features']:
            features_file = os.path.join(brightmove_dir, 'features', 'features.txt')
            with open(features_file, 'w', encoding='utf-8') as f:
                f.write("BRIGHTMOVE FEATURES\n")
                f.write("=" * 30 + "\n\n")
                unique_features = list(set(self.scraped_content['features']))
                for feature in unique_features:
                    if feature.strip():
                        f.write(f"• {feature.strip()}\n")
        
        # Save solutions
        if self.scraped_content['solutions']:
            solutions_file = os.path.join(brightmove_dir, 'solutions', 'solutions.txt')
            with open(solutions_file, 'w', encoding='utf-8') as f:
                f.write("BRIGHTMOVE SOLUTIONS\n")
                f.write("=" * 30 + "\n\n")
                unique_solutions = list(set(self.scraped_content['solutions']))
                for solution in unique_solutions:
                    if solution.strip():
                        f.write(f"• {solution.strip()}\n")
        
        # Save pricing information
        if self.scraped_content['pricing']:
            pricing_file = os.path.join(brightmove_dir, 'pricing', 'pricing_info.txt')
            with open(pricing_file, 'w', encoding='utf-8') as f:
                f.write("BRIGHTMOVE PRICING INFORMATION\n")
                f.write("=" * 40 + "\n\n")
                unique_pricing = list(set(self.scraped_content['pricing']))
                for price_info in unique_pricing:
                    if price_info.strip():
                        f.write(f"• {price_info.strip()}\n")
        
        # Save testimonials
        if self.scraped_content['testimonials']:
            testimonials_file = os.path.join(brightmove_dir, 'testimonials', 'testimonials.txt')
            with open(testimonials_file, 'w', encoding='utf-8') as f:
                f.write("BRIGHTMOVE TESTIMONIALS\n")
                f.write("=" * 30 + "\n\n")
                unique_testimonials = list(set(self.scraped_content['testimonials']))
                for testimonial in unique_testimonials:
                    if testimonial.strip():
                        f.write(f"\"{testimonial.strip()}\"\n\n")
        
        # Save case studies
        if self.scraped_content['case_studies']:
            case_studies_file = os.path.join(brightmove_dir, 'case_studies', 'case_studies.txt')
            with open(case_studies_file, 'w', encoding='utf-8') as f:
                f.write("BRIGHTMOVE CASE STUDIES\n")
                f.write("=" * 30 + "\n\n")
                unique_cases = list(set(self.scraped_content['case_studies']))
                for case in unique_cases:
                    if case.strip():
                        f.write(f"• {case.strip()}\n")
        
        # Save technical specifications
        if self.scraped_content['technical_specs']:
            tech_file = os.path.join(brightmove_dir, 'technical', 'technical_specs.txt')
            with open(tech_file, 'w', encoding='utf-8') as f:
                f.write("BRIGHTMOVE TECHNICAL SPECIFICATIONS\n")
                f.write("=" * 40 + "\n\n")
                unique_specs = list(set(self.scraped_content['technical_specs']))
                for spec in unique_specs:
                    if spec.strip():
                        f.write(f"• {spec.strip()}\n")
        
        # Save comprehensive page content
        pages_file = os.path.join(brightmove_dir, 'raw_data', 'all_pages.txt')
        with open(pages_file, 'w', encoding='utf-8') as f:
            f.write("BRIGHTMOVE ALL PAGE CONTENT\n")
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
        self.create_website_index(brightmove_dir)
    
    def create_website_index(self, website_dir):
        """Create a summary index file for the specific website"""
        index_file = os.path.join(website_dir, 'index.txt')
        with open(index_file, 'w', encoding='utf-8') as f:
            f.write("BRIGHTMOVE WEBSITE CONTENT INDEX\n")
            f.write("=" * 40 + "\n\n")
            f.write("This directory contains scraped content from BrightMove's website.\n\n")
            f.write("DIRECTORY STRUCTURE:\n")
            f.write("-" * 25 + "\n")
            f.write("company/ - Company overview and information\n")
            f.write("features/ - Product features and capabilities\n")
            f.write("solutions/ - Solution offerings and use cases\n")
            f.write("pricing/ - Pricing information and plans\n")
            f.write("testimonials/ - Customer testimonials and reviews\n")
            f.write("case_studies/ - Success stories and case studies\n")
            f.write("technical/ - Technical specifications and APIs\n")
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
            f.write(f"Scraped at: {datetime.now().isoformat()}\n")
