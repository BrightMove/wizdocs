#!/usr/bin/env python3
"""
Script to read the RFP PDF and extract requirements
"""

import PyPDF2
import os

def read_pdf(pdf_path):
    """Read PDF and extract text content"""
    try:
        with open(pdf_path, 'rb') as file:
            pdf_reader = PyPDF2.PdfReader(file)
            
            print(f"PDF has {len(pdf_reader.pages)} pages")
            print("=" * 50)
            
            full_text = ""
            for page_num, page in enumerate(pdf_reader.pages, 1):
                text = page.extract_text()
                full_text += f"\n--- PAGE {page_num} ---\n{text}\n"
                print(f"Page {page_num}: {len(text)} characters")
            
            return full_text
            
    except Exception as e:
        print(f"Error reading PDF: {e}")
        return None

def save_text_to_file(text, output_file):
    """Save extracted text to a file"""
    try:
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(text)
        print(f"Text saved to: {output_file}")
    except Exception as e:
        print(f"Error saving file: {e}")

if __name__ == "__main__":
    pdf_file = "RFP_2025-46_Applicant_Tracking_System.pdf"
    output_file = "RFP_requirements.txt"
    
    if os.path.exists(pdf_file):
        print(f"Reading PDF: {pdf_file}")
        text = read_pdf(pdf_file)
        
        if text:
            save_text_to_file(text, output_file)
            print("\nFirst 1000 characters of extracted text:")
            print("-" * 50)
            print(text[:1000])
        else:
            print("Failed to extract text from PDF")
    else:
        print(f"PDF file not found: {pdf_file}") 