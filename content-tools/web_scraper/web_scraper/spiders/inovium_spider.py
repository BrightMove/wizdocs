import scrapy
import json
import os
from urllib.parse import urljoin, urlparse
from datetime import datetime
import re


class InoviumSpiderSpider(scrapy.Spider):
    name = "inovium_spider"
    allowed_domains = ["inovium.com"]
    start_urls = ["https://www.inovium.com/"]
    
    def __init__(self, *args, **kwargs):
        super(InoviumSpiderSpider, self).__init__(*args, **kwargs)
        # Create knowledge-base directory structure for Inovium
        # Get the project root directory (3 levels up from spider file)
        spider_dir = os.path.dirname(__file__)
        web_scraper_dir = os.path.dirname(os.path.dirname(spider_dir))
        project_root = os.path.dirname(web_scraper_dir)
        
        self.knowledge_base_dir = os.path.join(project_root, 'knowledge-base')
        self.website_content_dir = os.path.join(self.knowledge_base_dir, 'website_content')
        self.inovium_dir = os.path.join(self.website_content_dir, 'partners', 'inovium')
        self.create_directory_structure()
        
        # Track scraped content
        self.scraped_content = {
            'website_info': {
                'name': 'inovium',
                'start_url': 'https://www.inovium.com/',
                'scraped_at': datetime.now().isoformat()
            },
            'company_info': {},
            'services': [],
            'solutions': [],
            'case_studies': [],
            'team': [],
            'blog_posts': [],
            'pages': [],
            'contact_info': {},
            'partnership_info': []
        }
        
        # Track visited URLs to avoid duplicates
        self.visited_urls = set()

    def create_directory_structure(self):
        """Create organized directory structure for Inovium content"""
        # Create Inovium subdirectories under partners
        inovium_dirs = [
            'partners/inovium',
            'partners/inovium/company',
            'partners/inovium/services',
            'partners/inovium/solutions',
            'partners/inovium/case_studies',
            'partners/inovium/team',
            'partners/inovium/blog',
            'partners/inovium/contact',
            'partners/inovium/partnership',
            'partners/inovium/raw_data'
        ]
        
        for directory in inovium_dirs:
            dir_path = os.path.join(self.website_content_dir, directory)
            os.makedirs(dir_path, exist_ok=True)

    def parse(self, response):
        """Parse the Inovium main page and extract key information"""
        if response.url in self.visited_urls:
            return
        self.visited_urls.add(response.url)
        
        # Extract company information
        company_info = {
            'url': response.url,
            'title': response.css('title::text').get(),
            'description': response.css('meta[name="description"]::attr(content)').get(),
            'scraped_at': datetime.now().isoformat()
        }
        
        # Extract main content sections
        main_content = {
            'headlines': [h.strip() for h in response.css('h1, h2, h3::text').getall() if h.strip()],
            'paragraphs': [p.strip() for p in response.css('p::text').getall() if p.strip()],
            'navigation': [n.strip() for n in response.css('nav a::text, .nav a::text').getall() if n.strip()],
            'hero_content': [h.strip() for h in response.css('.hero h1::text, .hero p::text, .banner h1::text, .banner p::text').getall() if h.strip()]
        }
        
        self.scraped_content['company_info'] = company_info
        self.scraped_content['pages'].append({
            'url': response.url,
            'content': main_content
        })
        
        # Extract all links - be comprehensive
        all_links = []
        
        # Get all anchor tags
        for link in response.css('a::attr(href)').getall():
            if link and not link.startswith(('#', 'javascript:', 'mailto:')):
                full_url = urljoin(response.url, link)
                if 'inovium.com' in full_url:
                    all_links.append(full_url)
        
        # Also look for links in data attributes and other sources
        for link in response.css('[data-href]::attr(data-href), [href]::attr(href)').getall():
            if link and not link.startswith(('#', 'javascript:', 'mailto:')):
                full_url = urljoin(response.url, link)
                if 'inovium.com' in full_url:
                    all_links.append(full_url)
        
        # Remove duplicates and follow links
        unique_links = list(set(all_links))
        self.logger.info(f"Found {len(unique_links)} unique links on {response.url}")
        
        for link in unique_links:
            if link not in self.visited_urls:
                yield scrapy.Request(link, callback=self.parse_inovium_page, meta={'source_url': response.url})
    
    def parse_inovium_page(self, response):
        """Parse individual Inovium pages"""
        if response.url in self.visited_urls:
            return
        self.visited_urls.add(response.url)
        
        # Determine page type based on URL and content
        url_path = urlparse(response.url).path
        url_lower = url_path.lower()
        
        page_content = {
            'url': response.url,
            'title': response.css('title::text').get(),
            'headlines': [h.strip() for h in response.css('h1, h2, h3::text').getall() if h.strip()],
            'paragraphs': [p.strip() for p in response.css('p::text').getall() if p.strip()],
            'lists': [l.strip() for l in response.css('ul li::text, ol li::text').getall() if l.strip()],
            'images': [img.strip() for img in response.css('img::attr(alt)').getall() if img.strip()],
            'scraped_at': datetime.now().isoformat()
        }
        
        self.scraped_content['pages'].append(page_content)
        
        # Categorize content based on URL patterns and content
        self.categorize_inovium_content(response.url, page_content)
        
        # Follow all links to find more content
        for link in response.css('a::attr(href)').getall():
            if link and not link.startswith(('#', 'javascript:', 'mailto:')):
                full_url = urljoin(response.url, link)
                if 'inovium.com' in full_url and full_url not in self.visited_urls:
                    yield scrapy.Request(full_url, callback=self.parse_inovium_page, meta={'source_url': response.url})
    
    def categorize_inovium_content(self, url, content):
        """Categorize Inovium content based on URL patterns and content"""
        url_lower = url.lower()
        
        # Services
        if any(keyword in url_lower for keyword in ['services', 'consulting', 'solutions', 'offerings']):
            service_content = content.get('headlines', []) + content.get('paragraphs', [])
            self.scraped_content['services'].extend(service_content)
        
        # Solutions
        if any(keyword in url_lower for keyword in ['solutions', 'platforms', 'technology', 'tools']):
            solution_content = content.get('headlines', []) + content.get('paragraphs', [])
            self.scraped_content['solutions'].extend(solution_content)
        
        # Case studies
        if any(keyword in url_lower for keyword in ['case-study', 'case-studies', 'success', 'clients', 'results']):
            case_content = content.get('headlines', []) + content.get('paragraphs', [])
            self.scraped_content['case_studies'].extend(case_content)
        
        # Team
        if any(keyword in url_lower for keyword in ['team', 'about', 'leadership', 'people']):
            team_content = content.get('headlines', []) + content.get('paragraphs', [])
            self.scraped_content['team'].extend(team_content)
        
        # Blog posts
        if any(keyword in url_lower for keyword in ['blog', 'news', 'insights', 'articles']):
            blog_content = content.get('headlines', []) + content.get('paragraphs', [])
            self.scraped_content['blog_posts'].extend(blog_content)
        
        # Contact information
        if any(keyword in url_lower for keyword in ['contact', 'location', 'phone', 'email']):
            contact_content = content.get('headlines', []) + content.get('paragraphs', [])
            self.scraped_content['contact_info'][url] = contact_content
        
        # Partnership information
        if any(keyword in url_lower for keyword in ['partners', 'partnership', 'alliances', 'ecosystem']):
            partnership_content = content.get('headlines', []) + content.get('paragraphs', [])
            self.scraped_content['partnership_info'].extend(partnership_content)
    
    def closed(self, reason):
        """Save scraped content when spider finishes"""
        # Save all content to knowledge-base with organized structure
        self.save_organized_content()
        
        self.logger.info(f"All Inovium content saved to {self.inovium_dir}")
        self.logger.info(f"Total pages scraped: {len(self.scraped_content['pages'])}")
    
    def save_organized_content(self):
        """Save content in organized structure under partners/inovium"""
        
        # Save raw JSON data
        raw_data_file = os.path.join(self.inovium_dir, 'raw_data', 'complete_scrape.json')
        with open(raw_data_file, 'w', encoding='utf-8') as f:
            json.dump(self.scraped_content, f, indent=2, ensure_ascii=False)
        
        # Save company information
        if self.scraped_content['company_info']:
            info_file = os.path.join(self.inovium_dir, 'company', 'company_info.txt')
            with open(info_file, 'w', encoding='utf-8') as f:
                f.write("INOVIUM COMPANY INFORMATION\n")
                f.write("=" * 40 + "\n\n")
                f.write(f"Title: {self.scraped_content['company_info'].get('title', 'N/A')}\n")
                f.write(f"Description: {self.scraped_content['company_info'].get('description', 'N/A')}\n")
                f.write(f"Scraped from: {self.scraped_content['company_info'].get('url', 'N/A')}\n")
                f.write(f"Scraped at: {self.scraped_content['company_info'].get('scraped_at', 'N/A')}\n")
        
        # Save all categorized content
        content_categories = {
            'services': 'SERVICES',
            'solutions': 'SOLUTIONS',
            'case_studies': 'CASE STUDIES',
            'team': 'TEAM',
            'blog_posts': 'BLOG POSTS',
            'partnership_info': 'PARTNERSHIP INFORMATION'
        }
        
        for category, title in content_categories.items():
            if self.scraped_content[category]:
                category_file = os.path.join(self.inovium_dir, category, f'{category}.txt')
                with open(category_file, 'w', encoding='utf-8') as f:
                    f.write(f"INOVIUM - {title}\n")
                    f.write("=" * (len(title) + 10) + "\n\n")
                    unique_items = list(set(self.scraped_content[category]))
                    for item in unique_items:
                        if item.strip():
                            f.write(f"• {item.strip()}\n")
        
        # Save contact information
        if self.scraped_content['contact_info']:
            contact_file = os.path.join(self.inovium_dir, 'contact', 'contact_info.txt')
            with open(contact_file, 'w', encoding='utf-8') as f:
                f.write("INOVIUM CONTACT INFORMATION\n")
                f.write("=" * 40 + "\n\n")
                for url, content in self.scraped_content['contact_info'].items():
                    f.write(f"URL: {url}\n")
                    f.write("-" * 50 + "\n")
                    for item in content:
                        f.write(f"  {item}\n")
                    f.write("\n")
        
        # Save comprehensive page content
        pages_file = os.path.join(self.inovium_dir, 'raw_data', 'all_pages.txt')
        with open(pages_file, 'w', encoding='utf-8') as f:
            f.write("INOVIUM - ALL PAGE CONTENT\n")
            f.write("=" * 40 + "\n\n")
            for page in self.scraped_content['pages']:
                f.write(f"URL: {page.get('url', 'N/A')}\n")
                f.write(f"Title: {page.get('title', 'N/A')}\n")
                f.write("-" * 50 + "\n")
                if page.get('headlines'):
                    f.write("HEADLINES:\n")
                    for headline in page.get('headlines', []):
                        f.write(f"  {headline}\n")
                if page.get('paragraphs'):
                    f.write("CONTENT:\n")
                    for para in page.get('paragraphs', []):
                        f.write(f"  {para}\n")
                f.write("\n" + "=" * 50 + "\n\n")
        
        # Create Inovium index
        self.create_inovium_index()
    
    def create_inovium_index(self):
        """Create an index file for easy navigation of Inovium content"""
        index_file = os.path.join(self.inovium_dir, 'index.txt')
        with open(index_file, 'w', encoding='utf-8') as f:
            f.write("INOVIUM KNOWLEDGE BASE INDEX\n")
            f.write("=" * 50 + "\n\n")
            f.write(f"Total Pages Scraped: {len(self.scraped_content['pages'])}\n")
            f.write(f"Scraped At: {datetime.now().isoformat()}\n\n")
            
            f.write("CONTENT CATEGORIES:\n")
            f.write("-" * 20 + "\n")
            for category, title in [
                ('services', 'Services'),
                ('solutions', 'Solutions'),
                ('case_studies', 'Case Studies'),
                ('team', 'Team'),
                ('blog_posts', 'Blog Posts'),
                ('partnership_info', 'Partnership Information')
            ]:
                count = len(self.scraped_content[category])
                f.write(f"• {title}: {count} items\n")
            
            f.write("\nSAMPLE CONTENT:\n")
            f.write("-" * 20 + "\n")
            if self.scraped_content['company_info'].get('title'):
                f.write(f"Company: {self.scraped_content['company_info']['title']}\n")
            if self.scraped_content['services']:
                f.write(f"Sample Service: {self.scraped_content['services'][0]}\n")
            if self.scraped_content['solutions']:
                f.write(f"Sample Solution: {self.scraped_content['solutions'][0]}\n") 