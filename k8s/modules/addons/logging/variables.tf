variable "environment" {
  type = string
}

variable "eck_operator_chart_version" {
  type = string
}

variable "elasticsearch_version" {
  type = string
}

variable "elasticsearch_node_count" {
  type = number

  validation {
    condition     = var.elasticsearch_node_count > 0
    error_message = "elasticsearch_node_count must be greater than zero."
  }
}

variable "elasticsearch_storage_size" {
  type = string
}

variable "elasticsearch_storage_class" {
  type = string
}

variable "elasticsearch_cpu" {
  type = string
}

variable "elasticsearch_memory" {
  type = string
}

variable "kibana_cpu" {
  type = string
}

variable "kibana_memory" {
  type = string
}

variable "fluent_bit_chart_version" {
  type = string
}

variable "retention_days" {
  type = number

  validation {
    condition     = var.retention_days > 0
    error_message = "retention_days must be greater than zero."
  }
}
