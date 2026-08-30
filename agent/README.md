# ServerIDE Agent

The mobile application reads real server data through this small, token-protected agent. It uses only Python's standard library.

## Ubuntu installation

```bash
sudo mkdir -p /opt/serveride-agent
sudo cp agent/serveride_agent.py /opt/serveride-agent/
sudo cp agent/serveride-agent.service /etc/systemd/system/
TOKEN=$(openssl rand -hex 32)
sudo sh -c "printf 'SERVERIDE_AGENT_TOKEN=%s\nSERVERIDE_ROOT=/root\n' '$TOKEN' > /etc/serveride-agent.env"
sudo chmod 600 /etc/serveride-agent.env
sudo systemctl daemon-reload
sudo systemctl enable --now serveride-agent
printf 'Save this token in the ServerIDE app: %s\n' "$TOKEN"
```

Keep the agent bound to `127.0.0.1:8787`. Publish it only through an HTTPS reverse proxy. Never expose it over plain HTTP because the agent can run terminal commands and modify files within `SERVERIDE_ROOT`.

Example Nginx location:

```nginx
location /serveride-agent/ {
    proxy_pass http://127.0.0.1:8787/;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_read_timeout 130s;
}
```

The URL entered in the app would then be `https://your-domain.example/serveride-agent`.
