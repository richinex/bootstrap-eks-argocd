locals {
  master_utils_values = <<-EOT
  apiVersion: argoproj.io/v1alpha1
  kind: Application
  metadata:
    name: master-utilities
    finalizers:
      - resources-finalizer.argocd.argoproj.io
  spec:
    project: default
    source:
      repoURL: https://github.com/PacktPublishing/ArgoCD-in-Practice.git
      targetRevision: HEAD
      path: ch05/applications/master-utilities
      helm:
        values: |
          externalDNS:
            iamRole: ${aws_iam_role.external_dns.arn}
            domain: ${var.domain}
            txtOwnerID: ${var.zone_id}

    destination:
      namespace: argocd
      server: https://kubernetes.default.svc

    syncPolicy:
      automated:
        prune: true
        selfHeal: true

  EOT

  values_dev = <<-EOT
  spec:
    destination:
      server: https://kubernetes.default.svc

  externalDNS:
    iamRole: ${aws_iam_role.external_dns.arn}
    domain: ${var.domain}
    txtOwnerID: ${var.zone_id}
  EOT

  istio_values_dev = <<-EOT
  apiVersion: install.istio.io/v1alpha1
  kind: IstioOperator
  metadata:
    namespace: istio-system
    name: istio-control-plane
  spec:
    profile: default
    components:
      ingressGateways:
      - namespace: istio-system
        name: istio-ingressgateway
        enabled: true
        k8s:
          serviceAnnotations:
            service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
            service.beta.kubernetes.io/aws-load-balancer-ssl-cert: "${var.ssl_cert_arn}"
            service.beta.kubernetes.io/aws-load-balancer-backend-protocol: "http"
            service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "https"
            service.beta.kubernetes.io/aws-load-balancer-connection-idle-timeout: "60"
    addonComponents:
      prometheus:
        enabled: false
  EOT
}

resource "local_file" "master_utils_values" {
  filename = "../k8s-bootstrap/base/master-utilities.yaml"
  content  = local.master_utils_values
}

resource "local_file" "master_utils_values_yaml" {
  filename = "../applications/master-utilities/values.yaml"
  content  = local.values_dev
}

resource "local_file" "istio_values_yaml" {
  filename = "../applications/istio-control-plane/istio-control-plane.yaml"
  content  = local.istio_values_dev
}


data "kustomization_build" "argocd" {
  path = "../k8s-bootstrap/bootstrap"
}

resource "kustomization_resource" "argocd" {
  for_each = data.kustomization_build.argocd.ids
  manifest = data.kustomization_build.argocd.manifests[each.value]
  depends_on = [
    local_file.master_utils_values,
    local_file.master_utils_values_yaml,
    local_file.istio_values_yaml,
  ]
}
