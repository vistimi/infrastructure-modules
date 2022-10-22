locals {
  region                 = var.region
  vpc_name               = var.vpc_name
  service                = "${var.service_name}-${var.environment_name}${var.hash}"
  bucket_images_name     = "${service}-bucket-images"
  bucket_db_name         = "${service}-bucket-db"
  db_version             = var.db_version
  ec2_cluster_name       = "${service}-ec2-cluster"
  db_remote_state_bucket = "(YOUR_BUCKET_NAME)"
  db_remote_state_key    = "stage/data-stores/mysql/terraform.tfstate"

  # Common tags to be assigned to all resources
  common_tags = {
    Region  = local.region
    Service = local.service
  }
}

resource "aws_launch_configuration" "example" {
  image_id        = "ami-0fb653ca2d3203ac1"
  instance_type   = var.instance_type
  security_groups = [aws_security_group.instance.id]

  user_data = templatefile("user-data.sh", {
    server_port = var.server_port
    db_address  = data.terraform_remote_state.db.outputs.address
    db_port     = data.terraform_remote_state.db.outputs.port
  })
  # Required when using a launch configuration with an ASG.
  lifecycle {
    create_before_destroy = true
  }
}

module "ec2" {
  source = "modules/services/ec2"

  instance_type        = "m4.large"
  min_size             = 2
  max_size             = 10
  custom_tags = {
    Owner     = "team-foo"
    ManagedBy = "terraform"
  }
}

autoscaling_group_name = module.webserver_cluster.asg_name
