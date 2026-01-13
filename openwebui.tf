resource "null_resource" "wait_for_openwebui" {
  depends_on = [kubectl_manifest.openwebui]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<EOF
      export KUBECONFIG=${local.kubeconfig_path}

      echo "Waiting for OpenWebUI pod to be ready..."
      MAX_RETRIES=60
      count=0

      while [ $count -lt $MAX_RETRIES ]; do
        POD_STATUS=$(kubectl get pods -n ai-platform -l app=openwebui -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")
        POD_READY=$(kubectl get pods -n ai-platform -l app=openwebui -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")

        if [[ "$POD_STATUS" == "Running" ]] && [[ "$POD_READY" == "True" ]]; then
          echo "OpenWebUI pod is ready!"

          echo "Waiting for OpenWebUI API to respond..."
          sleep 10

          kubectl port-forward -n ai-platform svc/openwebui 8080:8080 &
          PF_PID=$!
          sleep 5

          for i in {1..30}; do
            if curl -s http://localhost:8080/health > /dev/null 2>&1; then
              echo "OpenWebUI API is ready!"
              kill $PF_PID 2>/dev/null || true
              exit 0
            fi
            sleep 2
          done

          kill $PF_PID 2>/dev/null || true
          echo "OpenWebUI API did not respond in time"
          exit 1
        fi

        echo "Pod status: $POD_STATUS, Ready: $POD_READY (attempt $count/$MAX_RETRIES)"
        sleep 10
        count=$((count + 1))
      done

      echo "Timeout waiting for OpenWebUI pod"
      exit 1
    EOF
  }
}

data "kubernetes_service" "openwebui" {
  metadata {
    name      = "openwebui"
    namespace = "ai-platform"
  }

  depends_on = [null_resource.wait_for_openwebui]
}

locals {
  openwebui_url = "http://localhost:8080"
}

# provider "openwebui" {
#   endpoint  = local.openwebui_url
#   token=random_password.webui_secret_key.value
#   depends_on = [null_resource.wait_for_openwebui]
# }
