
resource "aws_vpc" "one" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "my-vpc"
  }
}

resource "aws_subnet" "all" {
  for_each = var.subnet_cidrs

  vpc_id            = aws_vpc.one.id
  cidr_block        = each.value
  availability_zone = var.az
  tags = {
    Name = each.key
  }
}

resource "aws_internet_gateway" "default" {
  vpc_id = aws_vpc.one.id
  tags = {
    Name = "my-vpc-igw"
  }
}

resource "aws_route_table" "all" {
  for_each = var.subnet_cidrs
  vpc_id   = aws_vpc.one.id

  tags = {
    Name = "${each.key}-rt"
  }
}


resource "aws_route" "default" {
  for_each = toset([for net, cidr in var.subnet_cidrs : net if strcontains(net, "pub")])

  route_table_id         = aws_route_table.all[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.default.id
}

resource "aws_route_table_association" "all" {
  for_each       = var.subnet_cidrs
  subnet_id      = aws_subnet.all[each.key].id
  route_table_id = aws_route_table.all[each.key].id
}