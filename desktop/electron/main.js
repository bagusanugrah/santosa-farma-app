const { app, BrowserWindow, ipcMain } = require('electron');
const path = require('path');
const { spawn, exec } = require('child_process');
const http = require('http');

let mainWindow = null;
let backendProcess = null;
let ngrokProcess = null;

// Read config from env
const NGROK_AUTHTOKEN = process.env.NGROK_AUTHTOKEN || '';
const NGROK_DOMAIN = process.env.NGROK_DOMAIN || '';
const BACKEND_PORT = 8000;
const NEXT_PORT = 3001;

function makeRequest(path, method = 'GET') {
  return new Promise((resolve, reject) => {
    const req = http.request(
      {
        hostname: '127.0.0.1',
        port: BACKEND_PORT,
        path: path,
        method: method,
        timeout: 2000,
      },
      (res) => {
        let body = '';
        res.on('data', (chunk) => (body += chunk));
        res.on('end', () => resolve(body));
      }
    );
    req.on('error', (err) => reject(err));
    req.end();
  });
}

async function isBackendRunning() {
  try {
    await makeRequest('/api/store/status');
    return true;
  } catch (e) {
    return false;
  }
}

async function startBackendAndNgrok() {
  const alreadyRunning = await isBackendRunning();
  if (alreadyRunning) {
    console.log('[Electron] Backend sudah berjalan di port 8000 (mode manual). Tidak perlu menjalankan ulang.');
  } else {
    console.log('[Electron] Starting Laravel Backend...');
    const rootDir = path.join(__dirname, '../..');
    const backendDir = path.join(rootDir, 'backend');
    const binDir = path.join(rootDir, 'bin');
    const phpExtIniDir = path.join(rootDir, '.php_ext/ini');

    const customEnv = {
      ...process.env,
      PATH: `${binDir}:${process.env.PATH}`,
      PHP_INI_SCAN_DIR: `:${phpExtIniDir}`,
    };

    // Spawn php artisan serve
    backendProcess = spawn('php', ['artisan', 'serve', `--port=${BACKEND_PORT}`], {
      cwd: backendDir,
      shell: true,
      env: customEnv,
      stdio: 'ignore',
    });
  }

  // Start ngrok if token & domain configured
  if (NGROK_AUTHTOKEN && NGROK_DOMAIN) {
    console.log(`[Electron] Starting Ngrok with static domain: ${NGROK_DOMAIN}...`);
    ngrokProcess = spawn(
      'ngrok',
      ['http', `${BACKEND_PORT}`, `--domain=${NGROK_DOMAIN}`, `--authtoken=${NGROK_AUTHTOKEN}`],
      {
        shell: true,
        stdio: 'ignore',
      }
    );
  }

  // Set store open
  setTimeout(async () => {
    try {
      await makeRequest('/api/store/open', 'POST');
      console.log('[Electron] Store status set to OPEN.');
    } catch (e) {
      console.warn('[Electron] Could not set store open immediately, will retry:', e.message);
    }
  }, 2000);
}

async function stopBackendAndNgrok() {
  console.log('[Electron] Closing store and stopping background services...');
  try {
    await makeRequest('/api/store/close', 'POST');
    console.log('[Electron] Store status set to CLOSED.');
  } catch (e) {
    console.warn('[Electron] Error notifying store close:', e.message);
  }

  if (backendProcess) {
    try {
      process.kill(-backendProcess.pid);
    } catch (e) {
      backendProcess.kill();
    }
    backendProcess = null;
  }

  if (ngrokProcess) {
    try {
      process.kill(-ngrokProcess.pid);
    } catch (e) {
      ngrokProcess.kill();
    }
    ngrokProcess = null;
  }
}

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1366,
    height: 850,
    minWidth: 1024,
    minHeight: 700,
    title: 'Apotek Santosa Farma — POS Kasir & Super Admin',
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      nodeIntegration: false,
      contextIsolation: true,
    },
  });

  const isDev = process.env.NODE_ENV !== 'production';
  const startUrl = isDev
    ? `http://localhost:${NEXT_PORT}`
    : `file://${path.join(__dirname, '../out/index.html')}`;

  mainWindow.loadURL(startUrl);

  // Auto retry if Next dev server is still starting or hot-reloading
  mainWindow.webContents.on('did-fail-load', (event, errorCode, errorDescription, validatedURL) => {
    console.warn(`[Electron] Page failed to load: ${errorDescription} (${errorCode}) at ${validatedURL}`);
    if (isDev && errorCode !== -3) { // ignore ABORTED (-3)
      setTimeout(() => {
        if (mainWindow && !mainWindow.isDestroyed()) {
          console.log('[Electron] Retrying loadURL...');
          mainWindow.loadURL(validatedURL || startUrl);
        }
      }, 2000);
    }
  });

  mainWindow.on('closed', () => {
    mainWindow = null;
  });
}

app.whenReady().then(async () => {
  await startBackendAndNgrok();
  createWindow();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('before-quit', async (event) => {
  await stopBackendAndNgrok();
});

app.on('window-all-closed', async () => {
  await stopBackendAndNgrok();
  if (process.platform !== 'darwin') {
    app.quit();
  }
});
