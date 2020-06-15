provider "aws" {
 region = "ap-south-1"
 profile = "prakhar"
}


resource "tls_private_key" "example" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "mytask_key" {
  key_name   = "task1_key"
  public_key = tls_private_key.example.public_key_openssh
}

/*
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}
*/

resource "aws_security_group" "task1_sec_group" {
  name = "task1_security_group"
  description = "Allow SSH and HTTP protocol inbound traffic"
  //vpc_id      = aws_vpc.main.id

  ingress {
    description = "For SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "For HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "task_sec_group"
  }
}



resource "aws_instance" "mytask1instance"  {
  ami = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name = aws_key_pair.mytask_key.key_name
  security_groups = [aws_security_group.task1_sec_group.name]

   connection {
  type = "ssh"
  user = "ec2-user"
  private_key = tls_private_key.example.private_key_pem
  host = aws_instance.mytask1instance.public_ip
 }

 provisioner "remote-exec" {
  inline = [
   "sudo yum install httpd git -y",
   "sudo systemctl start httpd",
   "sudo systemctl enable httpd",
  ]
 }

  tags = {
    Name = "OS_task1"
  }
}


resource "aws_ebs_volume" "vol1" {
  availability_zone = aws_instance.mytask1instance.availability_zone
  size = 1

  tags = {
    Name = "myfirst_vol"
  }
}

resource "aws_volume_attachment" "vol1_attach" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.vol1.id
  instance_id = aws_instance.mytask1instance.id
  force_detach = true
}


output "myos_ip" {
  value = aws_instance.mytask1instance.public_ip
}


resource "null_resource" "nullip"  {
	provisioner "local-exec" {
	    command = "echo  ${aws_instance.mytask1instance.public_ip} > publicip.txt"
  	}
}



resource "null_resource" "nullmount"  {
  depends_on = [
    aws_volume_attachment.vol1_attach,
  ]

 
  connection {
  type = "ssh"
  user = "ec2-user"
  private_key = tls_private_key.example.private_key_pem
  host = aws_instance.mytask1instance.public_ip
 }
 
  
 provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/prakhar1508/terraform_task1.git   /var/www/html/"
    ]
  }
}



resource "null_resource" "nulllocal1" {
     depends_on = [
               null_resource.nullmount,
          ]

     provisioner "local-exec" {
	    command = "chrome  ${aws_instance.mytask1instance.public_ip}/task1_2.jpg"
  	}
} 




resource "aws_s3_bucket" "tf-bucket" {
      depends_on = [
          aws_volume_attachment.vol1_attach,
       ]

  bucket = "mytask1bucket"
  acl    = "public-read"

  tags = {
    Name = "My Task1 bucket"
  }
  versioning {
   enabled = true
  }

/*
 provisioner "local-exec" {
  // inline
      command = "git clone https://github.com/prakhar1508/terraform_task1.git   My-images"
     }

  provisioner "local-exec" {
        when = destroy 
        command = "sudo rm -rf My-images/*"
      }
*/ 
}

resource "aws_s3_bucket_object" "terraobject" {
        bucket = aws_s3_bucket.tf-bucket.bucket
        key = "task1_3.jpeg"
        source = "C:/Users/user/Desktop/task1_3.jpeg"
       // source = "My-images/task1_3.jpeg"
        content_type = "image/jpeg"
        acl = "public-read"
        depends_on = [
              aws_s3_bucket.tf-bucket
         ]
}

locals {
   s3_origin_id = "S3-${aws_s3_bucket.tf-bucket.bucket}"
   }


resource "aws_cloudfront_distribution" "tf_cloudfront" {
  origin {
        domain_name = aws_s3_bucket.tf-bucket.bucket_regional_domain_name
        origin_id = "local.s3_origin_id"

        custom_origin_config {
                   http_port = 80
                   https_port = 80
                   origin_protocol_policy = "match-viewer"
                   origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"]
          }
      }

   enabled = true
   is_ipv6_enabled = true
 


   default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "local.s3_origin_id"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }


  restrictions {
      geo_restriction {
         restriction_type = "none"
      }
   }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  depends_on = [
    aws_s3_bucket.tf-bucket
   ]

}



resource "null_resource" "nullremote"  {
  depends_on = [
     aws_cloudfront_distribution.tf_cloudfront,
    // null_resource.nullmount,
  ]


	provisioner "local-exec" {
	   // command = "chrome  ${aws_instance.mytask1instance.public_ip}/task1_3.jpeg"
                command = "chrome  ${aws_cloudfront_distribution.tf_cloudfront.domain_name}/task1_3.jpeg" 
  	}
}

output "my_cloudfront_domain_name" {
   value = aws_cloudfront_distribution.tf_cloudfront.domain_name
 }



