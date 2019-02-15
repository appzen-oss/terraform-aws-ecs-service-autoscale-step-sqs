provider "aws" {
  profile                     = "appzen-dev"
  region                      = "us-east-1"
  skip_credentials_validation = true
  skip_get_ec2_platforms      = true
  skip_region_validation      = true
}
