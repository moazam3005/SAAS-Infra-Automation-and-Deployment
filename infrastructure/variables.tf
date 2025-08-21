variable "project_name" { type = string }
variable "aws_region"   { type = string }
variable "vpc_cidr"     { type = string  default = "10.20.0.0/16" }
variable "public_subnet_cidrs"  { type = list(string) default = ["10.20.1.0/24","10.20.2.0/24"] }
variable "private_subnet_cidrs" { type = list(string) default = ["10.20.11.0/24","10.20.12.0/24"] }
variable "instance_type" { type = string default = "t3.micro" }
variable "artifact_bucket_name" { type = string }
variable "github_org"  { type = string }
variable "github_repo" { type = string }

variable "tags" {
  type = map(string)
  default = {}
}
