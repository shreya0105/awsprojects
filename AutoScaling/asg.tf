resource "aws_autoscaling_group" "web" {
  name = "${aws_launch_configuration.web.name}-asg"
  target_group_arns = ["${aws_lb_target_group.tg.arn}"]
  min_size             = 1
  desired_capacity     = 2
  max_size             = 3

  health_check_type    = "ELB"
    
launch_configuration = aws_launch_configuration.web.name

vpc_zone_identifier  = [aws_subnet.sub1.id , aws_subnet.sub2.id]
# Required to redeploy without an outage.
lifecycle {
  create_before_destroy = true
}
tag {
  key                 = "Name"
  value               = "web"
  propagate_at_launch = true
}
}