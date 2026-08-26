import crypto from 'node:crypto';
import { SwiggyAgentService } from '../services/swiggyAgentService.js';
import { createHttpError } from '../utils/httpError.js';

// Cache for PKCE verifiers and Dynamic Client Registration details
const pkceStore = new Map(); // state -> { verifier, redirectUri }
let registeredClient = null; // cached dynamic client { client_id, client_secret }

async function getOrRegisterClient(redirectUri) {
  if (registeredClient) {
    return registeredClient;
  }

  try {
    console.log('Registering Swiggy dynamic client for redirectUri:', redirectUri);
    const response = await fetch('https://mcp.swiggy.com/auth/register', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        client_name: 'Blushy Local Client',
        redirect_uris: [redirectUri],
        grant_types: ['authorization_code'],
        response_types: ['code'],
      }),
    });

    if (!response.ok) {
      const text = await response.text();
      throw new Error(`Registration failed status ${response.status}: ${text}`);
    }

    const data = await response.json();
    registeredClient = {
      client_id: data.client_id,
      client_secret: data.client_secret,
    };
    return registeredClient;
  } catch (error) {
    console.error('Dynamic Client Registration failed:', error);
    throw error;
  }
}

export async function getSwiggyAuthUrl(req, res, next) {
  try {
    // Determine the callback URL based on backend server address
    const redirectUri = `${req.protocol}://${req.get('host')}/swiggy/callback`;
    
    // Generate PKCE
    const codeVerifier = crypto.randomBytes(32).toString('base64url');
    const codeChallenge = crypto
      .createHash('sha256')
      .update(codeVerifier)
      .digest('base64url');

    const state = crypto.randomBytes(16).toString('hex');

    // Save PKCE verifier using the state token as key
    pkceStore.set(state, { codeVerifier, redirectUri });

    // Register or get registered client_id
    const client = await getOrRegisterClient(redirectUri);

    // Build authorization url
    const authUrl = `https://mcp.swiggy.com/auth/authorize?` +
      `response_type=code&` +
      `client_id=${encodeURIComponent(client.client_id)}&` +
      `redirect_uri=${encodeURIComponent(redirectUri)}&` +
      `code_challenge=${encodeURIComponent(codeChallenge)}&` +
      `code_challenge_method=S256&` +
      `state=${encodeURIComponent(state)}&` +
      `scope=mcp:tools`;

    res.status(200).json({ authUrl });
  } catch (error) {
    next(error);
  }
}

export async function handleSwiggyCallback(req, res, next) {
  try {
    const { code, state, error: swiggyError } = req.query;

    if (swiggyError) {
      throw createHttpError(400, `Swiggy authorization error: ${swiggyError}`);
    }

    if (!code || !state) {
      throw createHttpError(400, 'Missing code or state parameters.');
    }

    const pkce = pkceStore.get(state);
    if (!pkce) {
      throw createHttpError(400, 'Invalid or expired state.');
    }

    pkceStore.delete(state);

    const { codeVerifier, redirectUri } = pkce;

    // Exchange code for access token
    const tokenResponse = await fetch('https://mcp.swiggy.com/auth/token', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        grant_type: 'authorization_code',
        code: code,
        code_verifier: codeVerifier,
        redirect_uri: redirectUri,
      }),
    });

    if (!tokenResponse.ok) {
      const errText = await tokenResponse.text();
      throw new Error(`Token exchange failed: ${errText}`);
    }

    const tokenData = await tokenResponse.json();

    // Render a success HTML page that delivers the token back to the app/web
    res.setHeader('Content-Type', 'text/html');
    res.status(200).send(`
      <!DOCTYPE html>
      <html>
      <head>
        <title>Blushy Swiggy Connection</title>
        <style>
          body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            background-color: #fcf4f6;
            color: #2d2529;
            display: flex;
            align-items: center;
            justify-content: center;
            height: 100vh;
            margin: 0;
          }
          .card {
            background: white;
            padding: 32px;
            border-radius: 20px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.05);
            text-align: center;
            max-width: 400px;
          }
          h1 { color: #b51c5c; margin-bottom: 8px; font-size: 24px; }
          p { color: #7d6b72; line-height: 1.5; font-size: 14px; }
          .token-box {
            background: #f4ebee;
            padding: 12px;
            border-radius: 8px;
            font-family: monospace;
            word-break: break-all;
            margin: 16px 0;
            font-size: 12px;
          }
          .btn {
            background: #b51c5c;
            color: white;
            padding: 10px 20px;
            border-radius: 20px;
            text-decoration: none;
            display: inline-block;
            font-weight: bold;
            font-size: 14px;
            margin-top: 12px;
            cursor: pointer;
            border: none;
          }
        </style>
        <script>
          // Send deep link message or postMessage if web
          const token = "${tokenData.access_token}";
          
          // Send to parent window if inside an iframe/popup
          if (window.opener) {
            window.opener.postMessage({ type: 'SWIGGY_TOKEN', token: token }, '*');
          }

          // Mobile Deep Link fallback redirect
          function returnToApp() {
            window.location.href = "blushy://auth/swiggy?token=" + encodeURIComponent(token);
          }
        </script>
      </head>
      <body>
        <div class="card">
          <h1>Connection Successful!</h1>
          <p>You have successfully authorized Blushy with your Swiggy Staging/Developer Account.</p>
          <div class="token-box">${tokenData.access_token}</div>
          <button class="btn" onclick="returnToApp()">Return to Blushy App</button>
        </div>
      </body>
      </html>
    `);
  } catch (error) {
    next(error);
  }
}

export async function handleSwiggyChat(req, res, next) {
  try {
    const { messages } = req.body;
    const swiggyToken = req.headers['x-swiggy-token'] || req.body.swiggyToken;

    if (!messages || !Array.isArray(messages)) {
      throw createHttpError(400, 'Messages array is required.');
    }

    const agentResult = await SwiggyAgentService.runAgent({
      messages,
      swiggyToken,
    });

    res.status(200).json(agentResult);
  } catch (error) {
    next(error);
  }
}
