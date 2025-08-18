#!/usr/bin/env ruby

require_relative 'vector_manager'
require_relative 'content_categorizer'
require 'json'

# Test script for the Vector Relationship System
class VectorSystemTester
  def initialize
    @vector_manager = VectorRelationshipManager.new
    @categorizer = ContentCategorizer.new(@vector_manager.config, @vector_manager.categories)
  end

  def run_tests
    puts "🧪 Testing Vector Relationship System"
    puts "=" * 50
    
    # Test 1: Add sample content from different categories
    test_add_sample_content
    
    # Test 2: Test categorization
    test_categorization
    
    # Test 3: Test relationship analysis
    test_relationship_analysis
    
    # Test 4: Test impact analysis
    test_impact_analysis
    
    # Test 5: Test conflict detection
    test_conflict_detection
    
    # Test 6: Display statistics
    display_statistics
    
    puts "\n✅ All tests completed!"
  end

  private

  def test_add_sample_content
    puts "\n📝 Test 1: Adding Sample Content"
    puts "-" * 30
    
    sample_content = [
      # Knowledge Base Content (What the application says it does)
      {
        content: "SSO Integration Guide: Learn how to configure Single Sign-On integration for BrightMove ATS. This comprehensive guide covers setup, configuration, and troubleshooting steps for seamless authentication.",
        source: "confluence",
        metadata: {
          title: "SSO Integration Guide",
          url: "https://company.atlassian.net/wiki/spaces/DOCS/pages/123456789/SSO+Integration",
          author: "Technical Documentation Team",
          version: "2.1"
        }
      },
      {
        content: "User Management Documentation: Complete guide to managing users, roles, and permissions in the BrightMove ATS system. Includes step-by-step instructions for adding, editing, and removing users.",
        source: "lighthub",
        metadata: {
          title: "User Management Guide",
          url: "https://help.lighthub.com/articles/user-management",
          author: "Support Team",
          version: "1.5"
        }
      },
      
      # Backlog Content (What the application should do)
      {
        content: "Feature Request: Implement advanced reporting dashboard with real-time analytics and customizable widgets. Users need better visibility into hiring metrics and performance indicators.",
        source: "jira",
        metadata: {
          title: "Advanced Reporting Dashboard",
          priority: "high",
          status: "to do",
          assignee: "Development Team",
          story_points: 13
        }
      },
      {
        content: "Bug Report: SSO integration fails when users have special characters in their email addresses. This affects approximately 15% of enterprise customers.",
        source: "intercom",
        metadata: {
          title: "SSO Email Character Bug",
          priority: "high",
          status: "in progress",
          assignee: "Backend Team",
          story_points: 5
        }
      },
      
      # Platform Content (What the application actually does)
      {
        content: "SSO Implementation: The current SSO integration uses SAML 2.0 protocol with Azure AD and Okta providers. Configuration is stored in /etc/brightmove/sso-config.yml with JWT token validation.",
        source: "github",
        metadata: {
          title: "SSO Implementation Details",
          file_path: "src/auth/sso_integration.rb",
          commit_hash: "a1b2c3d",
          branch: "main",
          file_type: "rb"
        }
      },
      {
        content: "User Management Code: User management system implemented with role-based access control (RBAC). Supports LDAP integration and custom permission sets. Database schema includes users, roles, and permissions tables.",
        source: "github",
        metadata: {
          title: "User Management Implementation",
          file_path: "src/models/user.rb",
          commit_hash: "e4f5g6h",
          branch: "main",
          file_type: "rb"
        }
      }
    ]
    
    @content_ids = []
    
    sample_content.each do |item|
      # Categorize content
      categorization = @categorizer.categorize_content(
        content: item[:content],
        source: item[:source],
        metadata: item[:metadata]
      )
      
      # Add to vector manager
      content_id = @vector_manager.add_content(
        content: item[:content],
        source: item[:source],
        category: categorization[:category],
        metadata: categorization[:metadata]
      )
      
      @content_ids << content_id
      
      puts "✅ Added #{categorization[:category]} content: #{item[:metadata][:title]} (ID: #{content_id})"
    end
  end

  def test_categorization
    puts "\n🏷️  Test 2: Content Categorization"
    puts "-" * 30
    
    # Test categorization suggestions
    test_content = "We need to implement a new feature for advanced user analytics"
    
    suggestions = @categorizer.suggest_category(
      content: test_content,
      source: "jira"
    )
    
    puts "Category suggestions for: '#{test_content}'"
    suggestions.each do |suggestion|
      puts "  - #{suggestion[:category]}: #{suggestion[:confidence].round(2)} confidence"
    end
  end

  def test_relationship_analysis
    puts "\n🔗 Test 3: Relationship Analysis"
    puts "-" * 30
    
    # Test relationships for SSO-related content
    sso_content_id = @content_ids.find { |id| 
      content = @vector_manager.get_content(id)
      content && content[:content].include?("SSO")
    }
    
    if sso_content_id
      relationships = @vector_manager.analyze_relationships(
        content_id: sso_content_id,
        relationship_type: "implements"
      )
      
      puts "Relationships for SSO content (ID: #{sso_content_id}):"
      relationships.each do |rel|
        puts "  - #{rel[:type]} → #{rel[:to_content_id]} (strength: #{rel[:strength].round(2)})"
      end
    end
  end

  def test_impact_analysis
    puts "\n💥 Test 4: Impact Analysis"
    puts "-" * 30
    
    # Test impact of a change
    change_description = "Update SSO configuration to support special characters in email addresses"
    
    impacts = @vector_manager.analyze_impact(
      change_description: change_description,
      categories: ["platform", "knowledge_base"]
    )
    
    puts "Impact analysis for: '#{change_description}'"
    impacts.first(3).each do |impact|
      content = impact[:content]
      puts "  - #{content[:metadata][:title]} (impact: #{impact[:impact_score].round(2)})"
    end
  end

  def test_conflict_detection
    puts "\n⚠️  Test 5: Conflict Detection"
    puts "-" * 30
    
    conflicts = @vector_manager.detect_conflicts
    
    if conflicts.any?
      puts "Found #{conflicts.length} conflicts:"
      conflicts.each do |conflict|
        puts "  - #{conflict[:conflict_type]} between content pieces"
        puts "    Similarity: #{conflict[:similarity].round(2)}, Conflict Score: #{conflict[:conflict_score].round(2)}"
      end
    else
      puts "No conflicts detected"
    end
  end

  def display_statistics
    puts "\n📊 Test 6: System Statistics"
    puts "-" * 30
    
    # Get statistics
    stats = @vector_manager.get_statistics
    health = @vector_manager.health_check
    
    puts "System Health:"
    puts "  - Storage: #{health[:storage][:status]}"
    puts "  - Embeddings: #{health[:embeddings][:status]}"
    puts "  - Relationships: #{health[:relationships][:status]}"
    
    puts "\nContent Statistics:"
    puts "  - Total Content: #{stats[:total_content]}"
    puts "  - Relationships: #{stats[:relationships]}"
    puts "  - Embeddings: #{stats[:embeddings]}"
    
    puts "\nContent by Category:"
    stats[:by_category].each do |category, count|
      puts "  - #{category}: #{count}"
    end
    
    puts "\nContent by Source:"
    stats[:by_source].each do |source, count|
      puts "  - #{source}: #{count}"
    end
  end
end

# Run the tests
if __FILE__ == $0
  tester = VectorSystemTester.new
  tester.run_tests
end
