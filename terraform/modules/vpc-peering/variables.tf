variable "requester_vpc_id" {
  description = "VPC ID of the peering requester (gateway)"
  type        = string
}

variable "accepter_vpc_id" {
  description = "VPC ID of the peering accepter (backend)"
  type        = string
}

variable "requester_vpc_cidr" {
  description = "CIDR of the requester VPC — added as a route in the accepter's route tables"
  type        = string
}

variable "accepter_vpc_cidr" {
  description = "CIDR of the accepter VPC — added as a route in the requester's route tables"
  type        = string
}

variable "requester_private_route_table_ids" {
  description = "Private route table IDs in the requester VPC"
  type        = list(string)
}

variable "accepter_private_route_table_ids" {
  description = "Private route table IDs in the accepter VPC"
  type        = list(string)
}

variable "environment" {
  description = "Environment label"
  type        = string
}
