resource "helm_release" "weather_app" {
  name             = var.app_name
  chart            = "${path.module}/chart"
  namespace        = var.namespace
  create_namespace = true

  values = [yamlencode({
    weather = {
      replicas = var.weather_replicas
      image = {
        repository = var.weather_image_repository
        tag        = var.weather_image_tag
        pullPolicy = "IfNotPresent"
      }
      service = {
        type       = "NodePort"
        port       = var.weather_service_port
        targetPort = var.weather_container_port
        nodePort   = var.weather_node_port
      }
      bgColorConfigMap = var.weather_bg_color_configmap
      historyMountPath = var.weather_history_mount_path
    }
    solitaire = {
      replicas = var.solitaire_replicas
      image = {
        repository = var.solitaire_image_repository
        tag        = var.solitaire_image_tag
        pullPolicy = "IfNotPresent"
      }
      service = {
        type       = "NodePort"
        port       = var.solitaire_service_port
        targetPort = var.solitaire_container_port
        nodePort   = var.solitaire_node_port
      }
    }
    configMaps = {
      blue = {
        name    = "bg-color-blue"
        bgColor = "blue"
      }
      green = {
        name    = "bg-color-green"
        bgColor = "green"
      }
    }
    persistence = {
      enabled = true
      storageClass = {
        name                 = var.storage_class_name
        isDefaultClass       = var.storage_class_is_default
        provisioner          = "efs.csi.aws.com"
        volumeBindingMode    = "Immediate"
        allowVolumeExpansion = true
        parameters = {
          provisioningMode = "efs-ap"
          fileSystemId     = var.efs_file_system_id
          directoryPerms   = "700"
        }
      }
      pvc = {
        name         = "weather-history-pvc-efs-v1"
        storageClass = var.storage_class_name
        size         = var.storage_size
        accessModes  = ["ReadWriteMany"]
      }
    }
    ingress = {
      enabled        = var.ingress_enabled
      className      = var.ingress_class_name
      weatherHost    = var.ingress_host
      solitaireHost  = var.solitaire_ingress_host
      certificateArn = var.ingress_certificate_arn
    }
  })]
}
