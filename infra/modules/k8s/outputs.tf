output "service_name" {
  value = "weather-service"
}

output "node_port" {
  value = var.weather_node_port
}

output "release_name" {
  value = helm_release.weather_app.name
}
