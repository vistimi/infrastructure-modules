require "matching_ami" {
  test    = var.ami_name == "ubuntu-fossa" || var.ami_name == "aws-linux-2"
  message = "${var.ami_name} invalid"
}

module "ami" {

  depends_on = [
    "require.matching_ami",
  ]

  source = "modules/components/ami/${var.ami_name}"

}
