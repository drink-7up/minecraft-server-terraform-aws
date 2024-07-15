variable "minecraft_subnet" {
    description = "Subnet that the EC2 instance that hosts the minecraft server will reside in."
    type = string
    default = "10.0.1.0/24"
}

variable "vpc_network" {
    type = string
    default = "10.0.0.0/16"
}