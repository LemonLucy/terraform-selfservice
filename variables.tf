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
