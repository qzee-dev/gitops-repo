global:
  domain: argocd.example.com

  networkPolicy:
    create: true
    defaultDenyIngress: true

configs:
  params:
    server.insecure: "false"

server:
  replicas: 2

  ingress:
    enabled: true
    controller: aws
    ingressClassName: alb

    hostname: argocd.example.com

    # TLS is terminated by the AWS ALB.
    tls: false

    annotations:
      alb.ingress.kubernetes.io/scheme: internal
      alb.ingress.kubernetes.io/target-type: ip

      alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS":443}]'

      alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:eu-west-1:123456789012:certificate/xxxxxxxx"

      alb.ingress.kubernetes.io/ssl-redirect: "443"

      # ALB -> Argo CD server uses HTTPS.
      alb.ingress.kubernetes.io/backend-protocol: HTTPS

      alb.ingress.kubernetes.io/healthcheck-protocol: HTTPS
      alb.ingress.kubernetes.io/healthcheck-path: /healthz
      alb.ingress.kubernetes.io/success-codes: "200"

  resources:
    requests:
      cpu: 250m
      memory: 256Mi

    limits:
      cpu: "1"
      memory: 1Gi


repoServer:
  replicas: 2

  resources:
    requests:
      cpu: 250m
      memory: 256Mi

    limits:
      cpu: "1"
      memory: 1Gi


controller:
  replicas: 1


applicationSet:
  replicas: 2


notifications:
  enabled: true

