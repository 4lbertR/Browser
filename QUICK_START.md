# Quick Start - Get Browser Working in 2 Minutes

## Step 1: Get a Free API Key (30 seconds)

Choose ONE of these free services:

### Option A: Apiflash (Recommended)
1. Go to https://apiflash.com
2. Click "Get Started Free"
3. Sign up with email
4. Copy your API key

### Option B: ScreenshotMachine
1. Go to https://www.screenshotmachine.com
2. Click "Sign Up"
3. Create free account
4. Copy your API key

## Step 2: Add Your API Key (30 seconds)

1. Open `App/Sources/Config.swift`
2. Find this line:
   ```swift
   static let apiflashKey = "YOUR_API_KEY_HERE"
   ```
3. Replace `YOUR_API_KEY_HERE` with your actual API key:
   ```swift
   static let apiflashKey = "af-1234567890abcdef"
   ```

## Step 3: Build and Run

1. Open project in Xcode
2. Build and run on your iPhone
3. Navigate to any website - it will now render perfectly!

## That's It! 🎉

Your browser now:
- Renders all websites with full CSS
- Executes JavaScript
- Shows dynamic content
- Bypasses WebKit completely

## Troubleshooting

**Still seeing "API Key Not Configured"?**
- Make sure you saved Config.swift after adding your key
- Clean build folder (Cmd+Shift+K) and rebuild
- Check that your API key doesn't have extra spaces

**Getting API errors?**
- Verify your API key is correct
- Check you haven't exceeded free tier limit (100/month)
- Try the alternative service

## Want Unlimited Rendering?

Deploy the included server to get unlimited rendering:

1. Go to https://replit.com
2. New Repl → Import from GitHub
3. Import: `https://github.com/4lbertR/Browser`
4. Navigate to `/server` folder
5. Click Run
6. Update Config.swift with your Replit URL

## How It Works

The browser uses a real Chrome engine running on a server to render pages perfectly. Your iPhone displays the rendered result, completely bypassing WebKit and iOS restrictions.

This is the same technology used by:
- Opera Mini
- UC Browser
- Puffin Browser
- Amazon Silk

All major non-WebKit mobile browsers use this approach!