module "test" {
  source = "./projects/module/aws/iam/statements/project"

  root_path     = "./"
  project_names = ["scraper"]
}

output "test" {
  value = module.test
}
