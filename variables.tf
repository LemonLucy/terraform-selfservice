variable "ami_id" {
  type = string
}

variable "instance_name" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "aws_region" {
  type    = string
  default = "ap-northeast-2"
}

variable "ecr_repo_name" {}
variable "service_name" {}
variable "github_owner" {}
variable "github_repo" {}
variable "github_token" {}
variable "app_repo_url" {}
