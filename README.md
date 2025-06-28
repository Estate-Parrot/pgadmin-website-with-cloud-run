# Host pgAdmin as a Website on Google Cloud Run with Cloud SQL

This guide walks you through deploying pgAdmin as a public website using Google Cloud Run and securely connecting it to a Google Cloud SQL PostgreSQL database via the Cloud SQL Proxy. From there you can map your domain with Cloudflare or other hosting services. This uses pgAdmin's official Docker Image. 

This is made for Mac users, sorry :\. I would suggest feeding in the commands to your prefered LLM and asking for the windows/linux equivalents. 

---

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Step 1: Initialize gcloud and Docker](#step-1-initialize-gcloud-and-docker)
- [Step 2: Project Setup](#step-2-project-setup)
- [Step 3: Build the Docker Image](#step-3-build-the-docker-image)
- [Step 4: Deploy to Cloud Run with Cloud SQL Proxy](#step-4-deploy-to-cloud-run-with-cloud-sql-proxy)
- [Step 5: Connect Your Domain via Cloudflare](#step-5-connect-your-domain-via-cloudflare)
- [Troubleshooting](#troubleshooting)
- [Key Takeaways](#key-takeaways)
- [Alternatives & Further Reading](#alternatives--further-reading)

---

## Overview

This project enables you to:

- Host pgAdmin (a PostgreSQL admin tool) as a website using Cloud Run.
- Securely connect pgAdmin to your Google Cloud SQL database using the Cloud SQL Proxy.
- Preload your database connection for easy access.

---

## Prerequisites

- Google Cloud account with billing enabled
- Cloud SQL PostgreSQL instance (with credentials)
- Macbook

---

## Step 1: Initialize gcloud and Docker

**Install and authenticate with Google Cloud SDK:**

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

**Install and start Docker:**

```bash
# Install Docker Desktop (if not already installed)
# Visit: https://www.docker.com/products/docker-desktop/

# Start Docker Desktop
# On macOS, launch Docker Desktop from Applications

# Verify Docker is running
docker --version
docker ps
```

**Create Artifact Registry repository:**

```bash
# Create a repository for your Docker images
# Replace with optimal location for you

gcloud artifacts repositories create pgadmin-repo \
  --repository-format=docker \
  --location=us-central1 \
  --description="Repository for pgAdmin Docker images"
```

---

## Step 2: Project Setup

**Create and enter project directory:**

```bash
mkdir pgadmin-cloudrun
cd pgadmin-cloudrun
```

**Create the Dockerfile:**

```bash
# Create an empty Dockerfile
touch Dockerfile
```

**Create the servers.json file:**

```bash
# Create an empty servers.json file
touch servers.json
```

**Edit the Dockerfile:**

```bash
# Open the project in your preferred IDE
# For VS Code:
code .

# For other IDEs, open the pgadmin-cloudrun folder in your editor
```

Now open the `Dockerfile` in your IDE and add the following content:

```dockerfile
FROM dpage/pgadmin4:latest
ENV PGADMIN_LISTEN_PORT=8080

COPY servers.json /pgadmin4/servers.json
```

*Explanation:*  
This uses the official pgAdmin image and configures it to listen on port 8080, which Cloud Run requires. The COPY command will add the servers.json file to the container.


**Edit servers.json:**

Open `servers.json` in your IDE and add the following content (replace the placeholder values with your actual Cloud SQL details):

```json
{
  "Servers": {
    "1": {
      "Name": "My Cloud SQL Database",
      "Group": "Servers",
      "Host": "/cloudsql/striking-lane-458100-j4:us-central1:v1-database",
      "Port": 5432,
      "MaintenanceDB": "postgres",
      "Username": "postgres",
      "SSLMode": "disable"
    }
  }
}
```

*Explanation:*  
- `servers.json` preloads your Cloud SQL database in pgAdmin.
- Replace CAPS_VALUES with your actual values.
- The `Host` uses the Cloud SQL Proxy format: `/cloudsql/PROJECT_ID:REGION:INSTANCE_NAME`

---

## Step 3: Build the Docker Image

**Authenticate Docker with Google Artifact Registry:**

```bash
# Replace location with what is optimal for you

gcloud auth configure-docker us-central1-docker.pkg.dev
```

**Build and push the image for the correct architecture:**

```bash
# Replace location with what is optimal for you

docker buildx build --platform linux/amd64 \
  -t us-central1-docker.pkg.dev/YOUR_PROJECT_ID/pgadmin-repo/pgadmin:latest \
  --push .
```

*Explanation:*  
The `--platform linux/amd64` flag ensures compatibility with Cloud Run, especially if you're on Apple Silicon.

---

## Step 4: Deploy to Cloud Run with Cloud SQL Proxy

```bash
# Replace location with what is optimal for you
gcloud run deploy pgadmin-service \
  --image=us-central1-docker.pkg.dev/YOUR_PROJECT_ID/pgadmin-repo/pgadmin:latest \
  --platform=managed \
  --region=us-central1 \
  --allow-unauthenticated \
  --set-env-vars=PGADMIN_DEFAULT_EMAIL=admin@example.com,PGADMIN_DEFAULT_PASSWORD=SecurePassword123 \
  --add-cloudsql-instances=YOUR_PROJECT_ID:REGION:INSTANCE_NAME
```

*Explanation:*  
- `--add-cloudsql-instances` enables the Cloud SQL Proxy integration, allowing secure database access.
- Environment variables configure pgAdmin and preload your database connection.

---

## Step 5: Connect Your Domain via Cloudflare

1. **Get your Cloud Run URL** (e.g., `https://pgadmin-service-xxxxxx-uc.a.run.app`).
2. **In Cloudflare DNS:**
   - Add a CNAME record:
     - Name: `pgadmin` (for `pgadmin.yourdomain.com`)
     - Target: `ghs.googlehosted.com`
     - Proxy status: DNS only (gray cloud)
3. **In Google Cloud Console:**
   - Go to Cloud Run → Domain mappings
   - Map `pgadmin.yourdomain.com` to your service
   - Follow verification prompts (may require adding a TXT record in Cloudflare)
4. **Wait for DNS propagation** (usually a few minutes).
5. **Access your pgAdmin website** at your custom domain.

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Docker build fails | Ensure Dockerfile and config files are present and correct. Use `--platform linux/amd64`. |
| Cloud Run container fails to start | Ensure `ENV PGADMIN_LISTEN_PORT=8080` is set. |
| pgAdmin can't connect to Cloud SQL | Check `servers.json` host, deploy with `--add-cloudsql-instances`, ensure service account has `Cloud SQL Client` role. |
| Domain doesn't resolve | Double-check Cloudflare DNS and Google Cloud Run domain mapping. Use DNS only mode until SSL is provisioned. |

---

## Key Takeaways

- **Cloud Run is the simplest and most secure way to host pgAdmin as a website on GCP.**
- **Cloud SQL Proxy is the recommended method for connecting securely to Cloud SQL from any platform.**
- **Use Docker's `--platform linux/amd64` when building images on Apple Silicon.**
- **Preload your database connection in pgAdmin using `servers.json` and `pgpass` for a seamless experience.**
- **Alternatives like Compute Engine, GKE, or Docker Compose are possible but require more manual setup.**
- **Modern alternatives to pgAdmin (like CloudBeaver or Pgweb) are available if you want a different web UI.**

---

## Alternatives & Further Reading

- [pgAdmin Official Docs](https://www.pgadmin.org/docs/pgadmin4/latest/container_deployment.html)
- [Google Cloud SQL Proxy](https://cloud.google.com/sql/docs/postgres/connect-run)
- [Cloudflare DNS Docs](https://developers.cloudflare.com/dns/manage-dns-records/how-to/)
- [CloudBeaver (web-based DBeaver)](https://cloudbeaver.io/)
- [Pgweb (lightweight web-based PostgreSQL client)](https://github.com/sosedoff/pgweb)

---

## Contributing

Feel free to open issues or PRs if you find improvements or want to share your own experience!








