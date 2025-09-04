const puppeteer = require('puppeteer');
const WebSocket = require('ws');
const express = require('express');

const app = express();
const PORT = process.env.PORT || 3000;
const WS_PORT = process.env.WS_PORT || 8080;

// Serve static files
app.use(express.static('public'));

// WebSocket server for real-time rendering
const wss = new WebSocket.Server({ port: WS_PORT });

console.log(`WebSocket server running on ws://localhost:${WS_PORT}`);

// Browser pool for multiple connections
const browserPool = [];
const MAX_BROWSERS = 5;

async function getBrowser() {
    if (browserPool.length < MAX_BROWSERS) {
        const browser = await puppeteer.launch({
            headless: 'new', // Use new headless mode
            args: [
                '--no-sandbox',
                '--disable-setuid-sandbox',
                '--disable-dev-shm-usage',
                '--disable-accelerated-2d-canvas',
                '--no-first-run',
                '--no-zygote',
                '--disable-gpu'
            ]
        });
        browserPool.push(browser);
        return browser;
    }
    // Return random browser from pool
    return browserPool[Math.floor(Math.random() * browserPool.length)];
}

wss.on('connection', async (ws) => {
    console.log('New client connected');
    
    let browser;
    let page;
    
    try {
        browser = await getBrowser();
        page = await browser.newPage();
        
        // Set a reasonable viewport
        await page.setViewport({
            width: 390, // iPhone 14 Pro width
            height: 844, // iPhone 14 Pro height
            deviceScaleFactor: 3
        });
        
        // Enable JavaScript
        await page.setJavaScriptEnabled(true);
        
        // Set user agent to mobile
        await page.setUserAgent('Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1');
        
    } catch (error) {
        console.error('Failed to initialize browser:', error);
        ws.send(JSON.stringify({ error: 'Failed to initialize browser' }));
        return;
    }
    
    ws.on('message', async (message) => {
        try {
            const data = JSON.parse(message);
            console.log('Received action:', data.action);
            
            switch(data.action) {
                case 'navigate':
                    // Navigate to URL
                    await page.goto(data.url, { 
                        waitUntil: 'networkidle2',
                        timeout: 30000 
                    });
                    
                    // Take screenshot
                    const screenshot = await page.screenshot({ 
                        type: 'png',
                        fullPage: false 
                    });
                    
                    // Send screenshot back
                    ws.send(screenshot);
                    
                    // Also send page info
                    const pageInfo = {
                        type: 'pageInfo',
                        title: await page.title(),
                        url: page.url()
                    };
                    ws.send(JSON.stringify(pageInfo));
                    break;
                    
                case 'click':
                    // Click at coordinates
                    await page.mouse.click(data.x, data.y);
                    
                    // Wait for navigation or changes
                    await page.waitForTimeout(1000);
                    
                    // Send updated screenshot
                    const clickScreenshot = await page.screenshot({ type: 'png' });
                    ws.send(clickScreenshot);
                    break;
                    
                case 'scroll':
                    // Scroll the page
                    await page.evaluate((scrollData) => {
                        window.scrollBy(scrollData.x || 0, scrollData.y || 0);
                    }, { x: data.deltaX, y: data.deltaY });
                    
                    // Send updated screenshot
                    const scrollScreenshot = await page.screenshot({ type: 'png' });
                    ws.send(scrollScreenshot);
                    break;
                    
                case 'type':
                    // Type text into focused element
                    await page.keyboard.type(data.text);
                    
                    // Send updated screenshot
                    const typeScreenshot = await page.screenshot({ type: 'png' });
                    ws.send(typeScreenshot);
                    break;
                    
                case 'back':
                    // Go back
                    await page.goBack();
                    await page.waitForTimeout(1000);
                    
                    const backScreenshot = await page.screenshot({ type: 'png' });
                    ws.send(backScreenshot);
                    break;
                    
                case 'forward':
                    // Go forward
                    await page.goForward();
                    await page.waitForTimeout(1000);
                    
                    const forwardScreenshot = await page.screenshot({ type: 'png' });
                    ws.send(forwardScreenshot);
                    break;
                    
                case 'reload':
                    // Reload page
                    await page.reload({ waitUntil: 'networkidle2' });
                    
                    const reloadScreenshot = await page.screenshot({ type: 'png' });
                    ws.send(reloadScreenshot);
                    break;
            }
        } catch (error) {
            console.error('Error processing message:', error);
            ws.send(JSON.stringify({ error: error.message }));
        }
    });
    
    ws.on('close', async () => {
        console.log('Client disconnected');
        if (page) {
            try {
                await page.close();
            } catch (error) {
                console.error('Error closing page:', error);
            }
        }
    });
    
    ws.on('error', (error) => {
        console.error('WebSocket error:', error);
    });
});

// HTTP endpoint for simple screenshot API
app.get('/screenshot', async (req, res) => {
    const url = req.query.url;
    if (!url) {
        return res.status(400).json({ error: 'URL parameter required' });
    }
    
    try {
        const browser = await getBrowser();
        const page = await browser.newPage();
        
        await page.goto(url, { waitUntil: 'networkidle2' });
        const screenshot = await page.screenshot({ type: 'png' });
        
        await page.close();
        
        res.set('Content-Type', 'image/png');
        res.send(screenshot);
    } catch (error) {
        console.error('Screenshot error:', error);
        res.status(500).json({ error: error.message });
    }
});

app.listen(PORT, () => {
    console.log(`HTTP server running on http://localhost:${PORT}`);
});

// Cleanup on exit
process.on('SIGINT', async () => {
    console.log('Shutting down...');
    for (const browser of browserPool) {
        await browser.close();
    }
    process.exit(0);
});