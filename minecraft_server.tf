provider "aws"{
    region = "us-east-2"
}

resource "aws_vpc" "spoke_minecraft" {
    cidr_block = "10.10.0.0/16"

}

resource "aws_subnet" "spoke_minecraft" {
    vpc_id = aws_vpc.spoke_minecraft.id
    cidr_block = "10.10.1.0/24"

}


resource "aws_security_group" "allow_all" {
    name = "allow_all"
    vpc_id = aws_vpc.spoke_minecraft.id

    egress {
        from_port        = 0
        to_port          = 0
        protocol         = "-1"
        cidr_blocks      = ["0.0.0.0/0"]
        ipv6_cidr_blocks = ["::/0"]
  }

    ingress {
        from_port        = 0
        to_port          = 0
        protocol         = "-1"
        cidr_blocks      = ["0.0.0.0/0"]
        ipv6_cidr_blocks = ["::/0"]
    }

}

resource "aws_network_interface" "minecraft_eni" {
    subnet_id   = aws_subnet.spoke_minecraft.id
    private_ips = ["10.10.1.100"]
    security_groups = [aws_security_group.allow_all.id]

}

resource "aws_internet_gateway" "minecraft_gw" {
  vpc_id = aws_vpc.spoke_minecraft.id

}

resource "aws_eip" "eip_manager" {
  instance = aws_instance.minecraft_server.id
  domain = "vpc"
  
}

resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.minecraft_server.id
  allocation_id = aws_eip.eip_manager.id
}

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.spoke_minecraft.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.minecraft_gw.id
  }

  route {
    cidr_block ="10.10.0.0/16"
    gateway_id = "local"
  }

}

resource "aws_main_route_table_association" "a" {
  vpc_id         = aws_vpc.spoke_minecraft.id
  route_table_id = aws_route_table.main.id
}

resource "aws_instance" "minecraft_server" {
    ami = "ami-09694bfab577e90b0"
    instance_type = "t3.large"
    key_name = "minecraft_server"

    network_interface {
        network_interface_id = aws_network_interface.minecraft_eni.id
        device_index = 0
    }
    
    user_data = <<-EOL
    #!/bin/bash

    # *** INSERT SERVER DOWNLOAD URL BELOW ***
    # Do not add any spaces between your link and the "=", otherwise it won't work. EG: MINECRAFTSERVERURL=https://urlexample


    MINECRAFTSERVERURL=https://piston-data.mojang.com/v1/objects/8dd1a28015f51b1803213892b50b7b4fc76e594d/server.jar


    # Download Java
    sudo yum install -y java-17-amazon-corretto-headless
    # Install MC Java server in a directory we create
    adduser minecraft
    mkdir /opt/minecraft/
    mkdir /opt/minecraft/server/
    cd /opt/minecraft/server

    # Download server jar file from Minecraft official website
    wget $MINECRAFTSERVERURL

    # Generate Minecraft server files and create script
    chown -R minecraft:minecraft /opt/minecraft/
    java -Xmx1300M -Xms1300M -jar server.jar nogui
    sleep 40
    sed -i 's/false/true/p' eula.txt
    touch start
    printf '#!/bin/bash\njava -Xmx1300M -Xms1300M -jar server.jar nogui\n' >> start
    chmod +x start
    sleep 1
    touch stop
    printf '#!/bin/bash\nkill -9 $(ps -ef | pgrep -f "java")' >> stop
    chmod +x stop
    sleep 1

    # Create SystemD Script to run Minecraft server jar on reboot
    cd /etc/systemd/system/
    touch minecraft.service
    printf '[Unit]\nDescription=Minecraft Server on start up\nWants=network-online.target\n[Service]\nUser=minecraft\nWorkingDirectory=/opt/minecraft/server\nExecStart=/opt/minecraft/server/start\nStandardInput=null\n[Install]\nWantedBy=multi-user.target' >> minecraft.service
    sudo systemctl daemon-reload
    sudo systemctl enable minecraft.service
    sudo systemctl start minecraft.service

    # End script
    EOL

}