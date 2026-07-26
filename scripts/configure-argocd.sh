#!/bin/bash
set -e

GITHUB_REPO_URL=${1:-""}

if [ -z "$GITHUB_REPO_URL" ]; then
  echo "Usage: $0 <github-repo-url>"
  echo "Example: $0 https://github.com/your-org/your-repo.git"
  exit 1
fi

echo "🔧 Configuring ArgoCD Application..."

# Update the application manifest with the correct repo URL
sed -i "s|repoURL:.*|repoURL: $GITHUB_REPO_URL|" argocd/applications/dvn-workshop-app.yaml

# Apply the application
kubectl apply -f argocd/applications/dvn-workshop-app.yaml

echo "✅ ArgoCD Application configured successfully!"
echo ""
echo "🔗 To view the application:"
echo "   kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "   Then open: https://localhost:8080"
echo ""
