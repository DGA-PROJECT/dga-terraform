# VPC 생성
resource "aws_vpc" "dga-vpc" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "dga-vpc"
  }
}

# NACL 디폴트 생성
resource "aws_default_network_acl" "default" {
  default_network_acl_id = aws_vpc.dga-vpc.default_network_acl_id

  ingress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }
  egress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = "dga-nacl"
  }
}

# 퍼블릭 서브넷 생성
resource "aws_subnet" "dga-pub-1" {
  vpc_id            = aws_vpc.dga-vpc.id
  cidr_block        = "10.0.0.0/20"
  availability_zone = "ap-northeast-2a"
  # EKS ALB 생성을 위한 태그 지정
  tags = {
    Name = "dga-pub-1"
    "kubernetes.io/cluster/dga-cluster-test" = "shared"
    "kubernetes.io/role/elb" = "1"
  }
}
resource "aws_subnet" "dga-pub-2" {
  vpc_id            = aws_vpc.dga-vpc.id
  cidr_block        = "10.0.16.0/20"
  availability_zone = "ap-northeast-2c"

  tags = {
    Name = "dga-pub-2"
    "kubernetes.io/cluster/dga-cluster-test" = "shared"
    "kubernetes.io/role/elb" = "1"
  }
}

## 프라이빗 서브넷 생성
resource "aws_subnet" "dga-pri-1" {
  vpc_id            = aws_vpc.dga-vpc.id
  cidr_block        = "10.0.128.0/20"
  availability_zone = "ap-northeast-2a"

  tags = {
    Name = "dga-pri-1"
    "kubernetes.io/cluster/dga-cluster-test" = "shared"
    "kubernetes.io/role/internal-elb" = "1"
  }
}
resource "aws_subnet" "dga-pri-2" {
  vpc_id            = aws_vpc.dga-vpc.id
  cidr_block        = "10.0.144.0/20"
  availability_zone = "ap-northeast-2c"

  tags = {
    Name = "dga-pri-2"
    "kubernetes.io/cluster/dga-cluster-test" = "shared"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# NATGW 탄력적 주소 생성
resource "aws_eip" "dga-eip-ngw" {
  vpc = true

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "dga-eip-ngw"
  }
}

# 인터넷 게이트웨이 생성
resource "aws_internet_gateway" "dga-igw" {
  vpc_id = aws_vpc.dga-vpc.id

  tags = {
    Name = "dga-igw"
  }
}

# NAT 게이트웨이 생성
resource "aws_nat_gateway" "dga-ngw" {
  # 탄력적ip id 지정
  allocation_id = aws_eip.dga-eip-ngw.id
  subnet_id     = aws_subnet.dga-pub-1.id

  tags = {
    Name = "dga-ngw"
  }
}

# 퍼블릭 라우팅 테이블 생성
resource "aws_route_table" "dga-rtb-pub" {
  vpc_id = aws_vpc.dga-vpc.id
  # 외부 트래픽, 인터넷 게이트웨이 지정
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dga-igw.id
  }
  # 내부 트래픽, 로컬
  route {
    cidr_block = "10.0.0.0/16"
    gateway_id = "local"
  }

  tags = {
    Name = "dga-rtb-pub"
  }
}

# 프라이빗 라우팅 테이블 생성
resource "aws_route_table" "dga-rtb-pri" {
  vpc_id = aws_vpc.dga-vpc.id
  # 외부 트래픽, NAT 게이트웨이 지정
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.dga-ngw.id
  }
  # 내부 트래픽, 로컬
  route {
    cidr_block = "10.0.0.0/16"
    gateway_id = "local"
  }

  tags = {
    Name = "dga-rtb-pri"
  }
}

# 라우팅 테이블 + 서브넷 연결
resource "aws_route_table_association" "dga-rtb-association-pub-1" {
  subnet_id      = aws_subnet.dga-pub-1.id
  route_table_id = aws_route_table.dga-rtb-pub.id
}
resource "aws_route_table_association" "dga-rtb-association-pub-2" {
  subnet_id      = aws_subnet.dga-pub-2.id
  route_table_id = aws_route_table.dga-rtb-pub.id
}
resource "aws_route_table_association" "dga-rtb-association-pri-1" {
  subnet_id      = aws_subnet.dga-pri-1.id
  route_table_id = aws_route_table.dga-rtb-pri.id
}
resource "aws_route_table_association" "dga-rtb-association-pri-2" {
  subnet_id      = aws_subnet.dga-pri-2.id
  route_table_id = aws_route_table.dga-rtb-pri.id
}