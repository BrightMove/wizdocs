#!/bin/bash

# Admin UI Start Script
# This script sets up and starts the Admin UI application

echo "🚀 Starting Admin UI - JIRA & Intercom Ticket Analysis"
echo "=================================================="

# Check if we're in the right directory
if [ ! -f "app.rb" ]; then
    echo "❌ Error: Please run this script from the admin-ui directory"
    exit 1
fi

# Check if Ruby is installed
if ! command -v ruby &> /dev/null; then
    echo "❌ Error: Ruby is not installed. Please install Ruby first."
    exit 1
fi

# Check if Bundler is installed
if ! command -v bundle &> /dev/null; then
    echo "📦 Installing Bundler..."
    gem install bundler
fi

# Install dependencies
echo "📦 Installing dependencies..."
bundle install

# Check if config.env exists
if [ ! -f "config.env" ]; then
    echo "⚠️  Warning: config.env not found"
    echo "📝 Creating config.env from example..."
    if [ -f "config.env.example" ]; then
        cp config.env.example config.env
        echo "✅ Created config.env - Please edit it with your API credentials"
        echo "   JIRA: https://id.atlassian.com/manage-profile/security/api-tokens"
        echo "   Intercom: https://developers.intercom.com/"
    else
        echo "❌ Error: config.env.example not found"
        exit 1
    fi
fi

# Check if config.env has been configured
if grep -q "your-domain.atlassian.net" config.env; then
    echo "⚠️  Warning: Please configure your API credentials in config.env"
    echo "   The application will work but won't connect to JIRA/Intercom"
fi

# Start the application
echo "🌐 Starting Admin UI..."
echo "   URL: http://localhost:3000"
echo "   Press Ctrl+C to stop"
echo ""

ruby app.rb 