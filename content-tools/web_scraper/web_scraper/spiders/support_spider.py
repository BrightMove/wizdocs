import scrapy
import json
import os
from urllib.parse import urljoin, urlparse
from datetime import datetime
import re


class SupportSpiderSpider(scrapy.Spider):
    name = "support_spider"
    allowed_domains = ["support.brightmove.com"]
    start_urls = ["https://support.brightmove.com/en/"]
    
    def __init__(self, *args, **kwargs):
        super(SupportSpiderSpider, self).__init__(*args, **kwargs)
        # Create knowledge-base directory structure
        self.knowledge_base_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), 'knowledge-base')
        self.website_content_dir = os.path.join(self.knowledge_base_dir, 'website_content')
        self.support_dir = os.path.join(self.website_content_dir, 'brightmove', 'support')
        self.create_directory_structure()
        
        # Track scraped content
        self.scraped_content = {
            'website_info': {
                'name': 'support_brightmove',
                'start_url': 'https://support.brightmove.com/en/',
                'scraped_at': datetime.now().isoformat()
            },
            'company_info': {},
            'help_articles': [],
            'faqs': [],
            'tutorials': [],
            'pages': [],
            'technical_docs': [],
            'user_guides': [],
            'api_docs': [],
            'troubleshooting': [],
            'collections': [],
            'articles': []
        }
        
        # Track visited URLs to avoid duplicates
        self.visited_urls = set()

    def create_directory_structure(self):
        """Create organized directory structure for support content"""
        # Create support subdirectories under brightmove
        support_dirs = [
            'support',
            'support/help_articles',
            'support/faqs',
            'support/tutorials',
            'support/technical_docs',
            'support/user_guides',
            'support/api_docs',
            'support/troubleshooting',
            'support/raw_data'
        ]
        
        for directory in support_dirs:
            dir_path = os.path.join(self.website_content_dir, 'brightmove', directory)
            os.makedirs(dir_path, exist_ok=True)

    def parse(self, response):
        """Parse the support main page and extract key information"""
        if response.url in self.visited_urls:
            return
        self.visited_urls.add(response.url)
        
        # Extract support site information
        support_info = {
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
            'search_terms': [s.strip() for s in response.css('[class*="search"]::text, [placeholder*="search"]::attr(placeholder)').getall() if s.strip()]
        }
        
        self.scraped_content['company_info'] = support_info
        self.scraped_content['pages'].append({
            'url': response.url,
            'content': main_content
        })
        
        # Extract all links - be more comprehensive
        all_links = []
        
        # Get all anchor tags
        for link in response.css('a::attr(href)').getall():
            if link and not link.startswith(('#', 'javascript:', 'mailto:')):
                full_url = urljoin(response.url, link)
                if 'support.brightmove.com' in full_url:
                    all_links.append(full_url)
        
        # Also look for links in data attributes and other sources
        for link in response.css('[data-href]::attr(data-href), [href]::attr(href)').getall():
            if link and not link.startswith(('#', 'javascript:', 'mailto:')):
                full_url = urljoin(response.url, link)
                if 'support.brightmove.com' in full_url:
                    all_links.append(full_url)
        
        # Remove duplicates and follow links
        unique_links = list(set(all_links))
        self.logger.info(f"Found {len(unique_links)} unique links on {response.url}")
        
        for link in unique_links:
            if link not in self.visited_urls:
                yield scrapy.Request(link, callback=self.parse_support_page, meta={'source_url': response.url})
    
    def parse_support_page(self, response):
        """Parse individual support pages"""
        if response.url in self.visited_urls:
            return
        self.visited_urls.add(response.url)
        
        # Determine if this is a collection page or article page
        url_path = urlparse(response.url).path
        
        if '/collections/' in url_path:
            # This is a collection page - extract article links
            yield from self.parse_collection_page(response)
        elif '/articles/' in url_path or '/posts/' in url_path:
            # This is an article page - extract content
            yield from self.parse_article_page(response)
        else:
            # Generic page - extract content and follow links
            yield from self.parse_generic_page(response)
    
    def parse_collection_page(self, response):
        """Parse collection pages and extract article links"""
        collection_info = {
            'url': response.url,
            'title': response.css('title::text').get(),
            'headlines': [h.strip() for h in response.css('h1, h2, h3::text').getall() if h.strip()],
            'description': [p.strip() for p in response.css('p::text').getall() if p.strip()],
            'scraped_at': datetime.now().isoformat()
        }
        
        self.scraped_content['collections'].append(collection_info)
        
        # Extract article links from collection page
        article_links = []
        
        # Look for article links in various selectors
        selectors = [
            'a[href*="/articles/"]::attr(href)',
            'a[href*="/posts/"]::attr(href)',
            '.article-link::attr(href)',
            '.post-link::attr(href)',
            '[data-article-url]::attr(data-article-url)',
            'a::attr(href)'  # General links that might be articles
        ]
        
        for selector in selectors:
            links = response.css(selector).getall()
            for link in links:
                if link and not link.startswith(('#', 'javascript:', 'mailto:')):
                    full_url = urljoin(response.url, link)
                    if 'support.brightmove.com' in full_url and ('/articles/' in full_url or '/posts/' in full_url):
                        article_links.append(full_url)
        
        # Also look for links in JavaScript data or other attributes
        for link in response.css('[data-url]::attr(data-url), [data-href]::attr(data-href)').getall():
            if link and not link.startswith(('#', 'javascript:', 'mailto:')):
                full_url = urljoin(response.url, link)
                if 'support.brightmove.com' in full_url and ('/articles/' in full_url or '/posts/' in full_url):
                    article_links.append(full_url)
        
        # Remove duplicates
        unique_article_links = list(set(article_links))
        self.logger.info(f"Found {len(unique_article_links)} article links in collection {response.url}")
        
        # Follow article links
        for link in unique_article_links:
            if link not in self.visited_urls:
                yield scrapy.Request(link, callback=self.parse_article_page, meta={'collection_url': response.url})
        
        # Also follow any other links that might lead to more content
        for link in response.css('a::attr(href)').getall():
            if link and not link.startswith(('#', 'javascript:', 'mailto:')):
                full_url = urljoin(response.url, link)
                if 'support.brightmove.com' in full_url and full_url not in self.visited_urls:
                    yield scrapy.Request(full_url, callback=self.parse_support_page, meta={'source_url': response.url})
    
    def parse_article_page(self, response):
        """Parse individual article pages"""
        article_content = {
            'url': response.url,
            'title': response.css('title::text').get(),
            'headlines': [h.strip() for h in response.css('h1, h2, h3::text').getall() if h.strip()],
            'paragraphs': [p.strip() for p in response.css('p::text').getall() if p.strip()],
            'lists': [l.strip() for l in response.css('ul li::text, ol li::text').getall() if l.strip()],
            'code_blocks': [c.strip() for c in response.css('code::text, pre::text').getall() if c.strip()],
            'images': [img.strip() for img in response.css('img::attr(alt)').getall() if img.strip()],
            'collection_url': response.meta.get('collection_url', ''),
            'scraped_at': datetime.now().isoformat()
        }
        
        self.scraped_content['articles'].append(article_content)
        self.scraped_content['pages'].append(article_content)
        
        # Categorize content based on URL and content
        self.categorize_support_content(response.url, article_content)
        
        # Follow any related links
        for link in response.css('a::attr(href)').getall():
            if link and not link.startswith(('#', 'javascript:', 'mailto:')):
                full_url = urljoin(response.url, link)
                if 'support.brightmove.com' in full_url and full_url not in self.visited_urls:
                    yield scrapy.Request(full_url, callback=self.parse_support_page, meta={'source_url': response.url})
    
    def parse_generic_page(self, response):
        """Parse generic pages that aren't clearly collections or articles"""
        page_content = {
            'url': response.url,
            'title': response.css('title::text').get(),
            'headlines': [h.strip() for h in response.css('h1, h2, h3::text').getall() if h.strip()],
            'paragraphs': [p.strip() for p in response.css('p::text').getall() if p.strip()],
            'lists': [l.strip() for l in response.css('ul li::text, ol li::text').getall() if l.strip()],
            'code_blocks': [c.strip() for c in response.css('code::text, pre::text').getall() if c.strip()],
            'scraped_at': datetime.now().isoformat()
        }
        
        self.scraped_content['pages'].append(page_content)
        
        # Categorize content based on URL and content
        self.categorize_support_content(response.url, page_content)
        
        # Follow all links to find more content
        for link in response.css('a::attr(href)').getall():
            if link and not link.startswith(('#', 'javascript:', 'mailto:')):
                full_url = urljoin(response.url, link)
                if 'support.brightmove.com' in full_url and full_url not in self.visited_urls:
                    yield scrapy.Request(full_url, callback=self.parse_support_page, meta={'source_url': response.url})
    
    def categorize_support_content(self, url, content):
        """Categorize support content based on URL patterns and content"""
        url_lower = url.lower()
        
        # Help articles
        if any(keyword in url_lower for keyword in ['article', 'help', 'guide']):
            help_content = content.get('headlines', []) + content.get('paragraphs', [])
            self.scraped_content['help_articles'].extend(help_content)
        
        # FAQs
        if any(keyword in url_lower for keyword in ['faq', 'question', 'answer']):
            faq_content = content.get('headlines', []) + content.get('paragraphs', [])
            self.scraped_content['faqs'].extend(faq_content)
        
        # Tutorials
        if any(keyword in url_lower for keyword in ['tutorial', 'how-to', 'step-by-step']):
            tutorial_content = content.get('headlines', []) + content.get('paragraphs', [])
            self.scraped_content['tutorials'].extend(tutorial_content)
        
        # Technical documentation
        if any(keyword in url_lower for keyword in ['technical', 'api', 'integration', 'developer']):
            tech_content = content.get('headlines', []) + content.get('paragraphs', []) + content.get('code_blocks', [])
            self.scraped_content['technical_docs'].extend(tech_content)
        
        # User guides
        if any(keyword in url_lower for keyword in ['user', 'manual', 'guide', 'instruction']):
            guide_content = content.get('headlines', []) + content.get('paragraphs', [])
            self.scraped_content['user_guides'].extend(guide_content)
        
        # API documentation
        if any(keyword in url_lower for keyword in ['api', 'endpoint', 'rest', 'webhook']):
            api_content = content.get('headlines', []) + content.get('paragraphs', []) + content.get('code_blocks', [])
            self.scraped_content['api_docs'].extend(api_content)
        
        # Troubleshooting
        if any(keyword in url_lower for keyword in ['troubleshoot', 'error', 'fix', 'problem', 'issue']):
            trouble_content = content.get('headlines', []) + content.get('paragraphs', [])
            self.scraped_content['troubleshooting'].extend(trouble_content)
    
    def closed(self, reason):
        """Save scraped content when spider finishes"""
        # Save all content to knowledge-base with organized structure
        self.save_organized_content()
        
        self.logger.info(f"All support content saved to {self.support_dir}")
        self.logger.info(f"Total pages scraped: {len(self.scraped_content['pages'])}")
        self.logger.info(f"Total articles found: {len(self.scraped_content['articles'])}")
        self.logger.info(f"Total collections found: {len(self.scraped_content['collections'])}")
    
    def save_organized_content(self):
        """Save content in organized structure under brightmove/support"""
        
        # Save raw JSON data
        raw_data_file = os.path.join(self.support_dir, 'raw_data', 'complete_scrape.json')
        with open(raw_data_file, 'w', encoding='utf-8') as f:
            json.dump(self.scraped_content, f, indent=2, ensure_ascii=False)
        
        # Save support site information
        if self.scraped_content['company_info']:
            info_file = os.path.join(self.support_dir, 'support_info.txt')
            with open(info_file, 'w', encoding='utf-8') as f:
                f.write("BRIGHTMOVE SUPPORT SITE INFORMATION\n")
                f.write("=" * 40 + "\n\n")
                f.write(f"Title: {self.scraped_content['company_info'].get('title', 'N/A')}\n")
                f.write(f"Description: {self.scraped_content['company_info'].get('description', 'N/A')}\n")
                f.write(f"Scraped from: {self.scraped_content['company_info'].get('url', 'N/A')}\n")
                f.write(f"Scraped at: {self.scraped_content['company_info'].get('scraped_at', 'N/A')}\n")
                f.write(f"Total pages scraped: {len(self.scraped_content['pages'])}\n")
                f.write(f"Total articles found: {len(self.scraped_content['articles'])}\n")
                f.write(f"Total collections found: {len(self.scraped_content['collections'])}\n")
        
        # Save all categorized content
        content_categories = {
            'help_articles': 'HELP ARTICLES',
            'faqs': 'FREQUENTLY ASKED QUESTIONS',
            'tutorials': 'TUTORIALS',
            'technical_docs': 'TECHNICAL DOCUMENTATION',
            'user_guides': 'USER GUIDES',
            'api_docs': 'API DOCUMENTATION',
            'troubleshooting': 'TROUBLESHOOTING'
        }
        
        for category, title in content_categories.items():
            if self.scraped_content[category]:
                category_file = os.path.join(self.support_dir, category, f'{category}.txt')
                with open(category_file, 'w', encoding='utf-8') as f:
                    f.write(f"BRIGHTMOVE SUPPORT - {title}\n")
                    f.write("=" * (len(title) + 20) + "\n\n")
                    unique_items = list(set(self.scraped_content[category]))
                    for item in unique_items:
                        if item.strip():
                            f.write(f"• {item.strip()}\n")
        
        # Save comprehensive page content
        pages_file = os.path.join(self.support_dir, 'raw_data', 'all_pages.txt')
        with open(pages_file, 'w', encoding='utf-8') as f:
            f.write("BRIGHTMOVE SUPPORT - ALL PAGE CONTENT\n")
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
                if page.get('lists'):
                    f.write("LISTS:\n")
                    for item in page.get('lists', []):
                        f.write(f"  • {item}\n")
                f.write("\n" + "=" * 50 + "\n\n")
        
        # Save articles separately
        if self.scraped_content['articles']:
            articles_file = os.path.join(self.support_dir, 'raw_data', 'articles.txt')
            with open(articles_file, 'w', encoding='utf-8') as f:
                f.write("BRIGHTMOVE SUPPORT - ALL ARTICLES\n")
                f.write("=" * 40 + "\n\n")
                for article in self.scraped_content['articles']:
                    f.write(f"ARTICLE: {article.get('title', 'N/A')}\n")
                    f.write(f"URL: {article.get('url', 'N/A')}\n")
                    f.write(f"Collection: {article.get('collection_url', 'N/A')}\n")
                    f.write("-" * 50 + "\n")
                    if article.get('headlines'):
                        for headline in article.get('headlines', []):
                            f.write(f"  {headline}\n")
                    if article.get('paragraphs'):
                        for para in article.get('paragraphs', []):
                            f.write(f"  {para}\n")
                    f.write("\n" + "=" * 50 + "\n\n")
        
        # Create support index
        self.create_support_index()
    
    def create_support_index(self):
        """Create an index file for easy navigation of support content"""
        index_file = os.path.join(self.support_dir, 'index.txt')
        with open(index_file, 'w', encoding='utf-8') as f:
            f.write("BRIGHTMOVE SUPPORT KNOWLEDGE BASE INDEX\n")
            f.write("=" * 50 + "\n\n")
            f.write(f"Total Pages Scraped: {len(self.scraped_content['pages'])}\n")
            f.write(f"Total Articles: {len(self.scraped_content['articles'])}\n")
            f.write(f"Total Collections: {len(self.scraped_content['collections'])}\n")
            f.write(f"Scraped At: {datetime.now().isoformat()}\n\n")
            
            f.write("CONTENT CATEGORIES:\n")
            f.write("-" * 20 + "\n")
            for category, title in [
                ('help_articles', 'Help Articles'),
                ('faqs', 'FAQs'),
                ('tutorials', 'Tutorials'),
                ('technical_docs', 'Technical Documentation'),
                ('user_guides', 'User Guides'),
                ('api_docs', 'API Documentation'),
                ('troubleshooting', 'Troubleshooting')
            ]:
                count = len(self.scraped_content[category])
                f.write(f"• {title}: {count} items\n")
            
            f.write("\nCOLLECTIONS FOUND:\n")
            f.write("-" * 20 + "\n")
            for collection in self.scraped_content['collections']:
                f.write(f"• {collection.get('title', 'N/A')} - {collection.get('url', 'N/A')}\n")
            
            f.write("\nSAMPLE ARTICLES:\n")
            f.write("-" * 20 + "\n")
            for i, article in enumerate(self.scraped_content['articles'][:10]):  # Show first 10
                f.write(f"{i+1}. {article.get('title', 'N/A')} - {article.get('url', 'N/A')}\n") 