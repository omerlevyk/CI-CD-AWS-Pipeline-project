aws_region = "us-east-1"

gitlab_ami             = "ami-0739a90584ef88b2e"
gitlab_instance_type   = "t3.large"
jenkins_controller_ami = "ami-0bfb8e76522514238"
jenkins_agent_ami      = "ami-0f251bdc660bf07fb"

key_name        = "gitlab-key"
certificate_arn = "arn:aws:acm:us-east-1:960828421635:certificate/354e07ad-76e2-4921-a459-85fe48702d1f"

cloudflare_api_token = "L428P5k3JPMrxLZQk1OpQIPKsuH_q7ww5lJrRNcE"
cloudflare_zone_id   = "8c97e7ebab9dc3e0ee71ff49b653ecfa"
allowed_client_cidr  = "213.57.121.34/32"

weather_app_image_repository = "omerlevyk/weather_app_private"
weather_app_image_tag        = "v1.0.0"
