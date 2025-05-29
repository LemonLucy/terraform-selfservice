resource "aws_instance" "example" {
  ami           = var.ami_id
  instance_type = var.instance_type
  tags = {
    Name = "${var.instance_name}"   # ← 뒤에 v2 같은 거 붙여서 이름만 바꿔줘
  }
}