import os

from fastapi import FastAPI
from fastapi.responses import HTMLResponse

app = FastAPI(title="frontend", version="0.1.0")

PUBLIC_API_BASE_PATH = os.getenv("PUBLIC_API_BASE_PATH", "/api")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "service": "frontend"}


@app.get("/", response_class=HTMLResponse)
def home() -> str:
    return f"""
    <!DOCTYPE html>
    <html lang=\"en\">
      <head>
        <meta charset=\"utf-8\" />
        <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />
        <title>GitOps Lab</title>
        <style>
          :root {{
            color-scheme: light;
            font-family: Georgia, 'Times New Roman', serif;
            background: radial-gradient(circle at top, #f7efe4 0%, #efe4d2 48%, #ddd3c4 100%);
            color: #1f1914;
          }}
          body {{
            margin: 0;
            min-height: 100vh;
            display: grid;
            place-items: center;
          }}
          main {{
            width: min(720px, calc(100vw - 32px));
            background: rgba(255, 252, 246, 0.92);
            border: 1px solid rgba(31, 25, 20, 0.12);
            border-radius: 24px;
            box-shadow: 0 20px 60px rgba(79, 54, 33, 0.15);
            padding: 32px;
          }}
          h1 {{
            margin-top: 0;
            font-size: clamp(2rem, 4vw, 3.25rem);
          }}
          p {{
            line-height: 1.6;
          }}
          .controls {{
            display: flex;
            gap: 12px;
            flex-wrap: wrap;
            margin: 24px 0;
          }}
          select, button {{
            font: inherit;
            padding: 12px 14px;
            border-radius: 999px;
            border: 1px solid rgba(31, 25, 20, 0.2);
            background: white;
          }}
          button {{
            background: #1f1914;
            color: #f8f2ea;
            cursor: pointer;
          }}
          pre {{
            margin: 0;
            padding: 20px;
            border-radius: 18px;
            background: #1f1914;
            color: #f8f2ea;
            overflow-x: auto;
          }}
        </style>
      </head>
      <body>
        <main>
          <h1>Argo CD GitOps Lab</h1>
          <p>
            This frontend calls <strong>backend-orders</strong>, which then calls <strong>backend-products</strong>.
            Change the app code or image tag in Git, let GitHub Actions update the manifests, and let Argo CD roll out the change.
          </p>
          <div class=\"controls\">
            <select id=\"order-id\">
              <option value=\"101\">Order 101</option>
              <option value=\"102\">Order 102</option>
            </select>
            <button id=\"load-order\" type=\"button\">Load order</button>
          </div>
          <pre id=\"result\">Loading...</pre>
        </main>
        <script>
          const apiBase = {PUBLIC_API_BASE_PATH!r};
          const result = document.getElementById('result');
          const selector = document.getElementById('order-id');
          const button = document.getElementById('load-order');

          async function loadOrder() {{
            const orderId = selector.value;
            result.textContent = 'Loading order ' + orderId + '...';

            const response = await fetch(`${{apiBase}}/orders/${{orderId}}`, {{
              headers: {{ 'Accept': 'application/json' }}
            }});
            const payload = await response.json();
            result.textContent = JSON.stringify(payload, null, 2);
          }}

          button.addEventListener('click', loadOrder);
          loadOrder();
        </script>
      </body>
    </html>
    """