<!DOCTYPE html>
<html lang="en" data-theme="system">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>WizDocs</title>
    <link rel="stylesheet" href="/styles.css?v=3">
    <script src="/theme.js" defer></script>
    <style>
        /* Wiz Chat Button */
        .wiz-chat-btn {
            width: 48px;
            height: 48px;
            border-radius: 12px;
            background: var(--gradient-primary);
            border: none;
            cursor: pointer;
            display: flex;
            align-items: center;
            justify-content: center;
            transition: all 0.3s ease;
            box-shadow: var(--shadow-secondary);
            position: relative;
        }
        
        .wiz-chat-btn:hover {
            transform: translateY(-2px);
            box-shadow: var(--shadow-hover);
        }
        
        .wiz-chat-icon {
            font-size: 20px;
            color: white;
        }
        
        /* Wiz Chat Modal */
        .wiz-modal {
            display: none;
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: rgba(0, 0, 0, 0.5);
            backdrop-filter: blur(10px);
            z-index: 1000;
            animation: fadeIn 0.3s ease;
        }
        
        .wiz-modal.show {
            display: flex;
            align-items: center;
            justify-content: center;
        }
        
        .wiz-modal-content {
            background: var(--bg-card);
            border-radius: 20px;
            padding: 0;
            max-width: 500px;
            width: 90%;
            max-height: 80vh;
            box-shadow: var(--shadow-hover);
            border: 1px solid var(--border-primary);
            animation: slideIn 0.3s ease;
            overflow: hidden;
        }
        
        .wiz-modal-header {
            background: var(--gradient-primary);
            color: white;
            padding: 20px 24px;
            display: flex;
            align-items: center;
            justify-content: space-between;
        }
        
        .wiz-modal-title {
            font-size: 20px;
            font-weight: 700;
            margin: 0;
            display: flex;
            align-items: center;
            gap: 12px;
        }
        
        .wiz-modal-close {
            background: none;
            border: none;
            color: white;
            font-size: 24px;
            cursor: pointer;
            padding: 4px;
            border-radius: 8px;
            transition: background-color 0.3s ease;
        }
        
        .wiz-modal-close:hover {
            background: rgba(255, 255, 255, 0.2);
        }
        
        .wiz-modal-body {
            padding: 24px;
            max-height: 60vh;
            overflow-y: auto;
        }
        
        .wiz-chat-messages {
            max-height: 300px;
            overflow-y: auto;
            padding: 16px;
            background: var(--bg-secondary);
            border-radius: 12px;
            border: 1px solid var(--border-secondary);
        }
        
        .wiz-message {
            display: flex;
            gap: 12px;
            margin-bottom: 16px;
        }
        
        .wiz-message:last-child {
            margin-bottom: 0;
        }
        
        .wiz-message-avatar {
            width: 32px;
            height: 32px;
            border-radius: 8px;
            background: var(--gradient-primary);
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 16px;
            color: white;
            flex-shrink: 0;
        }
        
        .wiz-message-user .wiz-message-avatar {
            background: var(--gradient-secondary);
        }
        
        .wiz-message-content {
            flex: 1;
            background: var(--bg-card);
            padding: 12px 16px;
            border-radius: 12px;
            border: 1px solid var(--border-primary);
        }
        
        .wiz-message-content p {
            margin: 0;
            color: var(--text-primary);
            line-height: 1.5;
        }
        
        .wiz-chat-input {
            display: flex;
            gap: 12px;
        }
        
        .wiz-input {
            flex: 1;
            padding: 12px 16px;
            border: 2px solid var(--border-primary);
            border-radius: 12px;
            background: var(--bg-card);
            color: var(--text-primary);
            font-size: 14px;
            transition: border-color 0.3s ease;
        }
        
        .wiz-input:focus {
            outline: none;
            border-color: var(--accent-primary);
        }
        
        .wiz-send-btn {
            padding: 12px 24px;
            background: var(--gradient-primary);
            color: white;
            border: none;
            border-radius: 12px;
            cursor: pointer;
            font-size: 14px;
            font-weight: 500;
            transition: all 0.3s ease;
        }
        
        .wiz-send-btn:hover {
            transform: translateY(-2px);
            box-shadow: var(--shadow-hover);
        }
        
        .wiz-quick-actions {
            display: flex;
            gap: 8px;
            flex-wrap: wrap;
        }
        
        .wiz-quick-btn {
            padding: 8px 16px;
            background: var(--bg-secondary);
            color: var(--text-primary);
            border: 1px solid var(--border-primary);
            border-radius: 8px;
            cursor: pointer;
            font-size: 12px;
            font-weight: 500;
            transition: all 0.3s ease;
        }
        
        .wiz-quick-btn:hover {
            background: var(--bg-card);
            border-color: var(--accent-primary);
            transform: translateY(-1px);
        }
        
        @keyframes fadeIn {
            from { opacity: 0; }
            to { opacity: 1; }
        }
        
        @keyframes slideIn {
            from { 
                opacity: 0;
                transform: translateY(-20px) scale(0.95);
            }
            to { 
                opacity: 1;
                transform: translateY(0) scale(1);
            }
        }
    </style>
</head>
<body>
    <header class="header">
        <div class="container">
            <div class="header-content">
                <div class="logo">
                    <div class="logo-icon">🦉</div>
                    <div class="logo-text">
                        <h1>WizDocs</h1>
                        <p>Agentic AI Platform</p>
                    </div>
                </div>
                
                <div class="header-actions">
                    <button class="wiz-chat-btn" onclick="openWizModal()" title="Chat with Wiz">
                        <span class="wiz-chat-icon">🦉</span>
                    </button>
                    <div class="theme-toggle" id="themeToggle" data-theme="system" title="Toggle theme">
                        <span style="position: absolute; top: 50%; left: 6px; transform: translateY(-50%); font-size: 10px;">☀️</span>
                        <span style="position: absolute; top: 50%; right: 6px; transform: translateY(-50%); font-size: 10px;">🌙</span>
                    </div>
                </div>
            </div>
            
            <div class="nav-tabs">
                <a href="/" class="nav-tab ">Dashboard</a>
                <a href="/sales-tools" class="nav-tab ">Sales Tools</a>
                <a href="/knowledge-base" class="nav-tab ">Knowledge Base</a>
                <a href="/audits" class="nav-tab ">Audits</a>
                <a href="/settings" class="nav-tab ">Settings</a>
            </div>
        </div>
    </header>

    <main class="main-content">
        <!DOCTYPE html>
<html lang="en" data-theme="system">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Error - WizDocs</title>
    <link rel="stylesheet" href="/styles.css">
    <script src="/theme.js" defer></script>
</head>
<body>
    <div class="container">
        <!-- Header -->
        <header class="header">
            <div class="header-content">
                <div class="logo">
                    <div class="logo-icon">🦉</div>
                    <div class="logo-text">
                        <h1>WizDocs</h1>
                        <p>Agentic AI Platform</p>
                    </div>
                </div>
                <div class="header-actions">
                    <div class="theme-toggle" data-theme="system" onclick="ThemeManager.toggle()">
                        <span class="theme-icon">🌙</span>
                    </div>
                </div>
            </div>
        </header>

        <!-- Navigation -->
        <nav class="nav-tabs">
            <a href="/" class="nav-tab">Dashboard</a>
            <a href="/sales-tools" class="nav-tab">Sales Tools</a>
            <a href="/audits" class="nav-tab">Audits</a>
            <a href="/settings" class="nav-tab">Settings</a>
        </nav>

        <!-- Main Content -->
        <main class="main-content">
            <div class="container">
                <div style="margin-bottom: 24px;">
                    <a href="javascript:history.back()" class="btn secondary" style="display: inline-flex; align-items: center; gap: 8px; width: auto;">
                        <span>←</span>
                        <span>Go Back</span>
                    </a>
                </div>

                <!-- Error Card -->
                <div class="card fade-in-up" style="text-align: center; padding: 48px 24px;">
                    <div class="card-icon error" style="font-size: 64px; margin: 0 auto 24px;">⚠️</div>
                    <h2 class="card-title" style="color: var(--accent-error); margin-bottom: 16px;">
                        Page not found
                    </h2>
                    <p class="card-description" style="margin-bottom: 32px; color: var(--text-secondary);">
                        The requested resource could not be found or an error occurred while processing your request.
                    </p>
                    
                    <div style="display: flex; gap: 16px; justify-content: center; flex-wrap: wrap;">
                        <a href="/" class="btn primary">
                            Go to Dashboard
                        </a>
                        <a href="/sales-tools" class="btn secondary">
                            Sales Tools
                        </a>
                    </div>
                </div>

                <!-- Help Section -->
                <div class="card fade-in-up" style="animation-delay: 0.1s; margin-top: 24px;">
                    <div class="card-header">
                        <div class="card-icon info">💡</div>
                        <h3 class="card-title">Need Help?</h3>
                    </div>
                    <p class="card-description">
                        If you believe this is an error or need assistance, please check the following:
                    </p>
                    <ul style="margin: 16px 0; padding-left: 24px; color: var(--text-secondary);">
                        <li>Verify the URL is correct</li>
                        <li>Check if the project or resource still exists</li>
                        <li>Try refreshing the page</li>
                        <li>Contact support if the issue persists</li>
                    </ul>
                </div>
            </div>
        </main>
    </div>
</body>
</html>

    </main>
    
    <!-- Wiz Chat Modal -->
    <div id="wizModal" class="wiz-modal">
        <div class="wiz-modal-content">
            <div class="wiz-modal-header">
                <h3 class="wiz-modal-title">
                    <span>🦉</span>
                    <span>Wiz - Your AI Assistant</span>
                </h3>
                <button class="wiz-modal-close" onclick="closeWizModal()">×</button>
            </div>
            <div class="wiz-modal-body">
                <div class="wiz-chat-messages" id="wizModalMessages">
                    <div class="wiz-message wiz-message-bot">
                        <div class="wiz-message-avatar">🦉</div>
                        <div class="wiz-message-content">
                            <p>Hello! I'm Wiz, your AI assistant for WizDocs. I can help you with sales tools, audits, and knowledge base management. What would you like to work on today?</p>
                        </div>
                    </div>
                </div>
                
                <div class="wiz-chat-input" style="margin-top: 16px;">
                    <input type="text" id="wizModalInput" placeholder="Ask Wiz anything..." class="wiz-input">
                    <button onclick="sendWizModalMessage()" class="wiz-send-btn">Send</button>
                </div>
                
                <div class="wiz-quick-actions" style="margin-top: 16px;">
                    <button onclick="askWizModal('Help me with RFP generation', 'sales')" class="wiz-quick-btn">📋 RFP Help</button>
                    <button onclick="askWizModal('Search the knowledge base for SSO', 'knowledge')" class="wiz-quick-btn">🔍 Search KB</button>
                    <button onclick="askWizModal('Run a JIRA audit', 'audit')" class="wiz-quick-btn">🎫 Audit JIRA</button>
                    <button onclick="askWizModal('What can you do?', 'general')" class="wiz-quick-btn">❓ Help</button>
                </div>
            </div>
        </div>
    </div>
    
    <script>
        // Wiz Modal Functions
        function openWizModal() {
            const modal = document.getElementById('wizModal');
            modal.classList.add('show');
            document.body.style.overflow = 'hidden';
            
            // Focus on input
            setTimeout(() => {
                const input = document.getElementById('wizModalInput');
                if (input) input.focus();
            }, 300);
        }
        
        function closeWizModal() {
            const modal = document.getElementById('wizModal');
            modal.classList.remove('show');
            document.body.style.overflow = '';
        }
        
        function sendWizModalMessage() {
            const input = document.getElementById('wizModalInput');
            const message = input.value.trim();
            
            if (!message) return;
            
            // Add user message to chat
            addWizModalMessage(message, 'user');
            input.value = '';
            
            // Send to Wiz API
            fetch('/api/wiz/chat', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ 
                    message: message,
                    context: 'general'
                })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    addWizModalMessage(data.response, 'bot');
                } else {
                    addWizModalMessage('Sorry, I encountered an error. Please try again.', 'bot');
                }
            })
            .catch(error => {
                console.error('Error:', error);
                addWizModalMessage('Sorry, I encountered an error. Please try again.', 'bot');
            });
        }
        
        function addWizModalMessage(message, sender) {
            const messagesContainer = document.getElementById('wizModalMessages');
            const messageDiv = document.createElement('div');
            messageDiv.className = `wiz-message wiz-message-${sender}`;
            
            const avatar = document.createElement('div');
            avatar.className = 'wiz-message-avatar';
            avatar.textContent = sender === 'user' ? '👤' : '🦉';
            
            const content = document.createElement('div');
            content.className = 'wiz-message-content';
            content.innerHTML = `<p>${message}</p>`;
            
            messageDiv.appendChild(avatar);
            messageDiv.appendChild(content);
            messagesContainer.appendChild(messageDiv);
            
            // Scroll to bottom
            messagesContainer.scrollTop = messagesContainer.scrollHeight;
        }
        
        function askWizModal(message, context) {
            // Add user message to chat
            addWizModalMessage(message, 'user');
            
            // Send to Wiz API
            fetch('/api/wiz/chat', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ 
                    message: message,
                    context: context
                })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    addWizModalMessage(data.response, 'bot');
                } else {
                    addWizModalMessage('Sorry, I encountered an error. Please try again.', 'bot');
                }
            })
            .catch(error => {
                console.error('Error:', error);
                addWizModalMessage('Sorry, I encountered an error. Please try again.', 'bot');
            });
        }
        
        // Handle Enter key in modal input
        document.addEventListener('DOMContentLoaded', function() {
            const wizModalInput = document.getElementById('wizModalInput');
            if (wizModalInput) {
                wizModalInput.addEventListener('keypress', function(e) {
                    if (e.key === 'Enter') {
                        sendWizModalMessage();
                    }
                });
            }
            
            // Close modal when clicking outside
            const modal = document.getElementById('wizModal');
            if (modal) {
                modal.addEventListener('click', function(e) {
                    if (e.target === modal) {
                        closeWizModal();
                    }
                });
            }
        });
    </script>
</body>
</html>
