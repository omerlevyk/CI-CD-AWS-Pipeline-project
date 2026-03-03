aws_region = "us-east-1"

gitlab_ami             = "ami-01b8aa21ca97b006d"
gitlab_instance_type   = "t3.large"
jenkins_controller_ami = "ami-0c6557ac13b7389ce"
jenkins_agent_ami      = "ami-0f251bdc660bf07fb"

key_name        = "gitlab-key"
certificate_arn = "arn:aws:acm:us-east-1:516608940168:certificate/3866e6bc-32e6-4afe-af39-6101563fee3b"

cloudflare_api_token = "L428P5k3JPMrxLZQk1OpQIPKsuH_q7ww5lJrRNcE"
cloudflare_zone_id   = "8c97e7ebab9dc3e0ee71ff49b653ecfa"
allowed_client_cidr  = "80.230.129.252/32"
vpn_allowed_cidrs = ["80.230.129.252/32", "34.225.201.93/32"]

weather_app_image_repository         = "omerlevyk/weather_app_private"
weather_app_image_tag                = "v1.0.0"
manage_alb_controller_with_terraform = true
create_jenkins_agent                 = false
