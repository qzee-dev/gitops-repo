resource "helm_release" "eck_operator" {
  name             = "elastic-operator"
  repository       = "https://helm.elastic.co"
  chart            = "eck-operator"
  version          = var.eck_operator_chart_version
  namespace        = "elastic-system"
  create_namespace = true
  wait             = true
  timeout          = 900
}

resource "helm_release" "stack" {
  name             = "${var.environment}-efk"
  chart            = "${path.module}/../../charts/efk"
  namespace        = "logging"
  create_namespace = true
  wait             = true
  timeout          = 1800

  values = [yamlencode({
    elasticsearch = {
      version       = var.elasticsearch_version
      nodeCount     = var.elasticsearch_node_count
      storageSize   = var.elasticsearch_storage_size
      storageClass  = var.elasticsearch_storage_class
      cpu           = var.elasticsearch_cpu
      memory        = var.elasticsearch_memory
      retentionDays = var.retention_days
    }
    kibana = {
      version = var.elasticsearch_version
      cpu     = var.kibana_cpu
      memory  = var.kibana_memory
    }
  })]

  depends_on = [helm_release.eck_operator]
}

resource "helm_release" "fluent_bit" {
  name             = "${var.environment}-fluent-bit"
  repository       = "https://fluent.github.io/helm-charts"
  chart            = "fluent-bit"
  version          = var.fluent_bit_chart_version
  namespace        = "logging"
  create_namespace = true
  wait             = true
  timeout          = 900

  values = [yamlencode({
    testFramework = {
      enabled = false
    }
    resources = {
      requests = {
        cpu    = "100m"
        memory = "128Mi"
      }
      limits = {
        cpu    = "500m"
        memory = "512Mi"
      }
    }
    env = [{
      name = "ES_API_KEY"
      valueFrom = {
        secretKeyRef = {
          name = "efk-fluent-bit-api-key"
          key  = "api_key"
        }
      }
    }]
    daemonSetVolumes = [
      {
        name = "elasticsearch-ca"
        secret = {
          secretName = "elasticsearch-es-http-certs-public"
        }
      }
    ]
    daemonSetVolumeMounts = [
      {
        name      = "elasticsearch-ca"
        mountPath = "/fluent-bit/tls"
        readOnly  = true
      }
    ]
    config = {
      service = <<-EOT
        [SERVICE]
            Daemon Off
            Flush 1
            Log_Level info
            Parsers_File /fluent-bit/etc/parsers.conf
            Parsers_File /fluent-bit/etc/conf/custom_parsers.conf
            HTTP_Server On
            HTTP_Listen 0.0.0.0
            HTTP_Port 2020
            Health_Check On
      EOT
      inputs  = <<-EOT
        [INPUT]
            Name tail
            Path /var/log/containers/*.log
            multiline.parser docker, cri
            Tag kube.*
            Mem_Buf_Limit 10MB
            Skip_Long_Lines On
      EOT
      filters = <<-EOT
        [FILTER]
            Name kubernetes
            Match kube.*
            Merge_Log On
            Keep_Log Off
            K8S-Logging.Parser On
            K8S-Logging.Exclude On
      EOT
      outputs = <<-EOT
        [OUTPUT]
            Name es
            Match kube.*
            Host elasticsearch-es-http.logging.svc
            Port 9200
            HTTP_API_Key $${ES_API_KEY}
            Logstash_Format On
            Logstash_Prefix logs
            Suppress_Type_Name On
            Generate_ID On
            Retry_Limit False
            tls On
            tls.verify On
            tls.ca_file /fluent-bit/tls/ca.crt
      EOT
    }
  })]

  depends_on = [helm_release.stack]
}
