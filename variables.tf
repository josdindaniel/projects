variable "access_key" {}
variable "secret_key" {}
variable "region" {
  default = "us-east-1"
}
variable "az" { type = "list" }
variable "cidrs_vpc" { type = "list" }
variable "ec2_info" { type = "list" }
variable "key_name" {}
variable "userdb" {}
variable "passdb" {}
variable "port" {}
variable "databasename" {}