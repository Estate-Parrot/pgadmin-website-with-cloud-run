# 🚀 Host pgAdmin as a Website on Google Cloud Run with Cloud SQL

> **Easily deploy pgAdmin as a public website on Google Cloud Run, securely connect to Cloud SQL, and manage your PostgreSQL databases from anywhere.**

---

<div align="center">

<img src="https://upload.wikimedia.org/wikipedia/commons/thumb/2/29/Postgresql_elephant.svg/993px-Postgresql_elephant.svg.png" alt="pgAdmin Logo" width="96" />

<br>

<p><b>Built for Mac users.</b></p>
<sub>For Windows/Linux, adapt the commands or ask your favorite LLM for equivalents.</sub>

</div>

---

## 📚 Table of Contents

- [✨ Overview](#-overview)
- [🛠️ Prerequisites](#️-prerequisites)
- [⚡ Step 1: Initialize gcloud and Docker](#step-1-initialize-gcloud-and-docker)
- [📁 Step 2: Project Setup](#step-2-project-setup)
- [🐳 Step 3: Build the Docker Image](#step-3-build-the-docker-image)
- [☁️ Step 4: Deploy to Cloud Run with Cloud SQL Proxy](#step-4-deploy-to-cloud-run-with-cloud-sql-proxy)
- [🌐 Step 5: Connect Your Domain via Cloudflare](#step-5-connect-your-domain-via-cloudflare)
- [🩺 Troubleshooting](#troubleshooting)
- [💡 Key Takeaways](#key-takeaways)
- [🔗 Alternatives & Further Reading](#alternatives--further-reading)
- [🤝 Contributing](#contributing)

---

## ✨ Overview

- 🌍 **Host pgAdmin** (a PostgreSQL admin tool) as a website using Cloud Run.
- 🔒 **Securely connect** pgAdmin to your Google Cloud SQL database using the Cloud SQL Proxy.
- ⚡ **Preload your database connection** for easy access.

---

## 🛠️ Prerequisites

> **You’ll need:**
>
> - 🏦 Google Cloud account with billing enabled  
> - 🐘 Cloud SQL PostgreSQL instance (with credentials)  
> - 💻 Macbook

---

## ⚡ Step 1: Initialize gcloud and Docker

<details>
<summary><strong>Expand for setup commands</strong></summary>

```bash
# Install gcloud CLI (if not already installed)
# Visit: https://cloud.google.com/sdk/docs/install

# Authenticate with your Google Cloud account
gcloud auth login

# Update if needed
gcloud components update

# Find your Project ID and Project Number at: https://console.cloud.google.com/welcome

# Set your project ID
gcloud config set project $YOUR_PROJECT_ID

# Enable required APIs
gcloud services enable run.googleapis.com
gcloud services enable sqladmin.googleapis.com
gcloud services enable artifactregistry.googleapis.com

# Grant Cloud SQL Client permissions to Cloud Run service account
gcloud projects add-iam-policy-binding $YOUR_PROJECT_ID \
  --member="serviceAccount:$YOUR_PROJECT_NUMBER-compute@developer.gserviceaccount.com" \
  --role="roles/cloudsql.admin"
```

---

```bash
# Install Docker Desktop (if not already installed)
# Visit: https://www.docker.com/products/docker-desktop/

# Start Docker Desktop
# On macOS, launch Docker Desktop from Applications

# Verify Docker is running
docker --version
docker ps
```

---

```bash
# Create a repository for your Docker images
gcloud artifacts repositories create pgadmin-repo \
  --repository-format=docker \
  --location=us-central1 \
  --description="Repository for pgAdmin Docker images"
```
</details>

---

## 📁 Step 2: Project Setup

<details>
<summary><strong>Expand for project structure & templates</strong></summary>

```bash
mkdir pgadmin-cloudrun
cd pgadmin-cloudrun
touch Dockerfile servers.json
```

**Open the project in your IDE:**

```bash
code .
```

---

**Dockerfile template:**

```dockerfile
FROM dpage/pgadmin4:latest
ENV PGADMIN_LISTEN_PORT=8080

COPY servers.json /pgadmin4/servers.json
```

*Explanation:*  
This uses the official pgAdmin image and configures it to listen on port 8080, which Cloud Run requires. The COPY command will add the servers.json file to the container.

**servers.json template:**

```json
{
  "Servers": {
    "1": {
      "Name": "YOUR_DATABASE_NAME",
      "Group": "Servers",
      "Host": "/cloudsql/YOUR_PROJECT_ID:YOUR_REGION:YOUR_INSTANCE_NAME",
      "Port": 5432,
      "MaintenanceDB": "postgres",
      "Username": "YOUR_DB_USERNAME",
      "SSLMode": "disable"
    }
  }
}
```

> ⚠️ **Replace the ALL_CAPS values with your actual Cloud SQL details.**
>
> - `Host` uses the Cloud SQL Proxy format: `/cloudsql/PROJECT_ID:REGION:INSTANCE_NAME`

</details>

---

## 🐳 Step 3: Build the Docker Image

<details>
<summary><strong>Expand for build & push commands</strong></summary>

```bash
# Authenticate Docker with Google Artifact Registry
gcloud auth configure-docker us-central1-docker.pkg.dev

# Build and push the image for the correct architecture (Apple Silicon users: this is required!)
docker buildx build --platform linux/amd64 \
  -t us-central1-docker.pkg.dev/YOUR_PROJECT_ID/pgadmin-repo/pgadmin:latest \
  --push .
```
*Explanation:*  
The `--platform linux/amd64` flag ensures compatibility with Cloud Run, especially if you're on Apple Silicon.

</details>

---

## ☁️ Step 4: Deploy to Cloud Run with Cloud SQL Proxy

<details>
<summary><strong>Expand for deploy command</strong></summary>

```bash
gcloud run deploy pgadmin-service \
  --image=us-central1-docker.pkg.dev/YOUR_PROJECT_ID/pgadmin-repo/pgadmin:latest \
  --platform=managed \
  --region=us-central1 \
  --allow-unauthenticated \
  --set-env-vars=PGADMIN_DEFAULT_EMAIL=admin@example.com,PGADMIN_DEFAULT_PASSWORD=SecurePassword123,PGADMIN_CONFIG_SERVER_MODE=True,PGADMIN_CONFIG_SERVERS_JSON_PATH=/pgadmin4/servers.json \
  --add-cloudsql-instances=YOUR_PROJECT_ID:REGION:INSTANCE_NAME
```

*Explanation:*  
- `--add-cloudsql-instances` enables the Cloud SQL Proxy integration, allowing secure database access.
- Environment variables configure pgAdmin and preload your database connection.

---

## 🌐 Step 5: Connect Your Domain via Cloudflare

<ol>
  <li><b>Get your Cloud Run URL</b> (e.g., <code>https://pgadmin-service-xxxxxx-uc.a.run.app</code>).</li>
  <li><b>In Cloudflare DNS:</b>
    <ul>
      <li>Add a <code>CNAME</code> record:
        <ul>
          <li>Name: <code>pgadmin</code> (for <code>pgadmin.yourdomain.com</code>)</li>
          <li>Target: <code>ghs.googlehosted.com</code></li>
          <li>Proxy status: DNS only (gray cloud)</li>
        </ul>
      </li>
    </ul>
  </li>
  <li><b>In Google Cloud Console:</b>
    <ul>
      <li>Go to Cloud Run → Domain mappings</li>
      <li>Map <code>pgadmin.yourdomain.com</code> to your service</li>
      <li>Follow verification prompts (may require adding a TXT record in Cloudflare)</li>
    </ul>
  </li>
  <li>Wait for DNS propagation (usually a few minutes).</li>
  <li>Access your pgAdmin website at your custom domain.</li>
</ol>

---

## 🩺 Troubleshooting

<table>
  <tr>
    <th>🐞 Problem</th>
    <th>💡 Solution</th>
  </tr>
  <tr>
    <td>Docker build fails</td>
    <td>Ensure Dockerfile and config files are present and correct. Use <code>--platform linux/amd64</code>.</td>
  </tr>
  <tr>
    <td>Cloud Run container fails to start</td>
    <td>Ensure <code>PGADMIN_LISTEN_PORT=8080</code> is set as an environment variable. Check logs in Cloud Console.</td>
  </tr>
  <tr>
    <td>pgAdmin can't connect to Cloud SQL</td>
    <td>Check <code>servers.json</code> host, deploy with <code>--add-cloudsql-instances</code>, ensure service account has <code>Cloud SQL Client</code> role.</td>
  </tr>
  <tr>
    <td>Domain doesn't resolve</td>
    <td>Double-check Cloudflare DNS and Google Cloud Run domain mapping. Use DNS only mode until SSL is provisioned.</td>
  </tr>
</table>

---

## 💡 Key Takeaways

> - 🚀 **Cloud Run** is the simplest and most secure way to host pgAdmin as a website on GCP.  
> - 🔗 **Cloud SQL Proxy** is the recommended method for connecting securely to Cloud SQL from any platform.  
> - 🏗️ **Use Docker's `--platform linux/amd64`** when building images on Apple Silicon.  
> - ⚡ **Preload your database connection** in pgAdmin using `servers.json` for a seamless experience.  
> - 🆕 **Modern alternatives** to pgAdmin (like CloudBeaver or Pgweb) are available if you want a different web UI.

---

## 🔗 Alternatives & Further Reading

- [pgAdmin Official Docs](https://www.pgadmin.org/docs/pgadmin4/latest/container_deployment.html)
- [Google Cloud SQL Proxy](https://cloud.google.com/sql/docs/postgres/connect-run)
- [Cloudflare DNS Docs](https://developers.cloudflare.com/dns/manage-dns-records/how-to/)
- [CloudBeaver (web-based DBeaver)](https://cloudbeaver.io/)
- [Pgweb (lightweight web-based PostgreSQL client)](https://github.com/sosedoff/pgweb)

---

## 🤝 Contributing

> 🙌 **Found a bug or have an idea?**  
> <b>Open an issue or PR!</b>  
> Your feedback makes this project better.

---








