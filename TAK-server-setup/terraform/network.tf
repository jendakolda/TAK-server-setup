# Virtual Cloud Network
resource "oci_core_vcn" "tak_vcn" {
  compartment_id = var.compartment_ocid
  cidr_block     = var.vcn_cidr
  display_name   = "tak-vcn"
  dns_label      = "takvcn"
}

# Internet Gateway
resource "oci_core_internet_gateway" "tak_internet_gateway" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.tak_vcn.id
  display_name   = "tak-internet-gateway"
}

# Route Table
resource "oci_core_route_table" "tak_route_table" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.tak_vcn.id
  display_name   = "tak-route-table"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.tak_internet_gateway.id
  }
}

# Public Subnet
resource "oci_core_subnet" "tak_public_subnet" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.tak_vcn.id
  cidr_block                 = var.subnet_cidr
  display_name               = "tak-public-subnet"
  dns_label                  = "taksubnet"
  route_table_id             = oci_core_route_table.tak_route_table.id
  security_list_ids          = [oci_core_security_list.tak_security_list.id]
  prohibit_public_ip_on_vnic = false
}