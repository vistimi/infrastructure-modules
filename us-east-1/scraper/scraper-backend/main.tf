terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"

  # save the state in a bucket
  backend "s3" {
    bucket = "terraformeksproject"
    key    = "state.tfstate"
  }
}



# test
resource "aws_instance" "app_server" {
  ami                    = "ami-....."
  instance_type          = "t2.micro"
  vpc_security_group_ids = ["sg-0077..."]
  subnet_id              = "subnet-923a..."

  tags = {
    Name = "ExampleAppServerInstance"
  }
}
