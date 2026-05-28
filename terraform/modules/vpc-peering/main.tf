# Both VPCs are in the same account, so auto_accept = true is valid.
resource "aws_vpc_peering_connection" "this" {
  vpc_id      = var.requester_vpc_id
  peer_vpc_id = var.accepter_vpc_id
  auto_accept = true

  accepter {
    allow_remote_vpc_dns_resolution = true
  }

  requester {
    allow_remote_vpc_dns_resolution = true
  }

  tags = {
    Name = "pcx-gateway-to-backend"
    Env  = var.environment
  }
}

# Routes in gateway VPC → backend
resource "aws_route" "gateway_to_backend" {
  count                     = length(var.requester_private_route_table_ids)
  route_table_id            = var.requester_private_route_table_ids[count.index]
  destination_cidr_block    = var.accepter_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.this.id
}

# Routes in backend VPC → gateway
resource "aws_route" "backend_to_gateway" {
  count                     = length(var.accepter_private_route_table_ids)
  route_table_id            = var.accepter_private_route_table_ids[count.index]
  destination_cidr_block    = var.requester_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.this.id
}
