<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="description" content="Reliable digital infrastructure and secure web services.">
  <title>${WEB_DOMAIN}</title>
  <style>
    :root {
      color-scheme: light;
      --bg: #f4f7fb;
      --surface: #ffffff;
      --ink: #172033;
      --muted: #667085;
      --line: #d9e2ee;
      --accent: #0f766e;
      --accent-2: #2563eb;
      --soft: #ecfdf5;
    }

    * {
      box-sizing: border-box;
    }

    body {
      margin: 0;
      font-family: Arial, Helvetica, sans-serif;
      background: var(--bg);
      color: var(--ink);
      line-height: 1.6;
    }

    .topbar {
      position: sticky;
      top: 0;
      z-index: 10;
      border-bottom: 1px solid var(--line);
      background: rgba(255, 255, 255, 0.92);
      backdrop-filter: blur(12px);
    }

    .nav {
      width: min(1120px, calc(100% - 32px));
      margin: 0 auto;
      min-height: 68px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 24px;
    }

    .brand {
      font-size: 18px;
      font-weight: 700;
      letter-spacing: 0;
      color: var(--ink);
      text-decoration: none;
    }

    .navlinks {
      display: flex;
      align-items: center;
      gap: 22px;
      font-size: 14px;
      color: var(--muted);
    }

    .hero {
      width: min(1120px, calc(100% - 32px));
      margin: 0 auto;
      padding: 72px 0 56px;
      display: grid;
      grid-template-columns: minmax(0, 1.1fr) minmax(320px, 0.9fr);
      gap: 48px;
      align-items: center;
    }

    .eyebrow {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      padding: 6px 10px;
      border: 1px solid #b7ead8;
      border-radius: 999px;
      background: var(--soft);
      color: #047857;
      font-size: 13px;
      font-weight: 700;
    }

    h1 {
      margin: 20px 0 18px;
      max-width: 720px;
      font-size: clamp(36px, 6vw, 68px);
      line-height: 1.02;
      letter-spacing: 0;
    }

    .lead {
      max-width: 650px;
      color: var(--muted);
      font-size: 18px;
    }

    .actions {
      margin-top: 30px;
      display: flex;
      flex-wrap: wrap;
      gap: 12px;
    }

    .button {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      min-height: 44px;
      padding: 0 18px;
      border-radius: 8px;
      border: 1px solid transparent;
      font-weight: 700;
      text-decoration: none;
    }

    .button.primary {
      background: var(--accent);
      color: #fff;
    }

    .button.secondary {
      border-color: var(--line);
      color: var(--ink);
      background: #fff;
    }

    .panel {
      border: 1px solid var(--line);
      border-radius: 8px;
      background: var(--surface);
      box-shadow: 0 18px 50px rgba(23, 32, 51, 0.08);
      overflow: hidden;
    }

    .panel-head {
      padding: 18px 20px;
      border-bottom: 1px solid var(--line);
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 12px;
    }

    .status {
      width: 10px;
      height: 10px;
      border-radius: 50%;
      background: #22c55e;
      box-shadow: 0 0 0 5px rgba(34, 197, 94, 0.15);
      flex: 0 0 auto;
    }

    .metric-grid {
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
    }

    .metric {
      padding: 22px 20px;
      border-bottom: 1px solid var(--line);
    }

    .metric:nth-child(odd) {
      border-right: 1px solid var(--line);
    }

    .metric strong {
      display: block;
      font-size: 28px;
      line-height: 1.1;
    }

    .metric span {
      display: block;
      margin-top: 6px;
      color: var(--muted);
      font-size: 13px;
    }

    .panel-foot {
      padding: 20px;
      color: var(--muted);
      font-size: 14px;
    }

    .section {
      border-top: 1px solid var(--line);
      background: #fff;
      padding: 54px 0;
    }

    .features {
      width: min(1120px, calc(100% - 32px));
      margin: 0 auto;
      display: grid;
      grid-template-columns: repeat(3, minmax(0, 1fr));
      gap: 22px;
    }

    .feature {
      padding: 24px;
      border: 1px solid var(--line);
      border-radius: 8px;
      background: #fff;
    }

    .feature h2 {
      margin: 0 0 10px;
      font-size: 18px;
      letter-spacing: 0;
    }

    .feature p {
      margin: 0;
      color: var(--muted);
      font-size: 15px;
    }

    footer {
      width: min(1120px, calc(100% - 32px));
      margin: 0 auto;
      padding: 28px 0 42px;
      color: var(--muted);
      font-size: 14px;
    }

    @media (max-width: 820px) {
      .navlinks {
        display: none;
      }

      .hero {
        grid-template-columns: 1fr;
        padding-top: 48px;
      }

      .features {
        grid-template-columns: 1fr;
      }
    }

    @media (max-width: 520px) {
      .metric-grid {
        grid-template-columns: 1fr;
      }

      .metric:nth-child(odd) {
        border-right: 0;
      }

      h1 {
        font-size: 38px;
      }
    }
  </style>
</head>
<body>
  <header class="topbar">
    <nav class="nav" aria-label="Primary navigation">
      <a class="brand" href="/">${WEB_DOMAIN}</a>
      <div class="navlinks" aria-hidden="true">
        <span>Platform</span>
        <span>Reliability</span>
        <span>Contact</span>
      </div>
    </nav>
  </header>

  <main>
    <section class="hero">
      <div>
        <span class="eyebrow">Service online</span>
        <h1>Reliable web infrastructure for modern teams.</h1>
        <p class="lead">We provide fast, secure and carefully maintained digital services with a focus on availability, privacy and everyday operational clarity.</p>
        <div class="actions">
          <a class="button primary" href="/">Get started</a>
          <a class="button secondary" href="/">View status</a>
        </div>
      </div>

      <aside class="panel" aria-label="Service status">
        <div class="panel-head">
          <strong>Live service status</strong>
          <span class="status" aria-hidden="true"></span>
        </div>
        <div class="metric-grid">
          <div class="metric">
            <strong>99.9%</strong>
            <span>Monthly availability target</span>
          </div>
          <div class="metric">
            <strong>24/7</strong>
            <span>Automated monitoring</span>
          </div>
          <div class="metric">
            <strong>TLS</strong>
            <span>Encrypted transport</span>
          </div>
          <div class="metric">
            <strong>Global</strong>
            <span>Standards-based delivery</span>
          </div>
        </div>
        <div class="panel-foot">All core services are operating normally.</div>
      </aside>
    </section>

    <section class="section">
      <div class="features">
        <article class="feature">
          <h2>Secure by default</h2>
          <p>Modern TLS settings and clean operational boundaries keep the public surface focused and predictable.</p>
        </article>
        <article class="feature">
          <h2>Built for uptime</h2>
          <p>Automated service management keeps routine operations stable across restarts and maintenance windows.</p>
        </article>
        <article class="feature">
          <h2>Simple operations</h2>
          <p>Clear logs, renewal automation and repeatable deployment steps make service management straightforward.</p>
        </article>
      </div>
    </section>
  </main>

  <footer>
    <span>&copy; 2026 ${WEB_DOMAIN}. All rights reserved.</span>
  </footer>
</body>
</html>
