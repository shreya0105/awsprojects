resource "aws_launch_configuration" "web" {
  name_prefix = "web-"
  image_id = "ami-0261755bbcb8c4a84" 
  instance_type = "t2.micro"
  #key_name = "tests"
  security_groups = [aws_security_group.webSg.id]
  associate_public_ip_address = true
  user_data = "${file("userdata1.sh")}"
lifecycle {
  create_before_destroy = true
}
}