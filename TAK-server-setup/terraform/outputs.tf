output "instance_id" {
  description = "The OCID of the created instance"
  value       = oci_core_instance.tak_server.id
}

output "instance_public_ip" {
  description = "The public IP address of the OpenTAK server"
  value       = data.oci_core_vnic.tak_server_vnic.public_ip_address
}

output "instance_private_ip" {
  description = "The private IP address of the OpenTAK server"
  value       = oci_core_instance.tak_server.private_ip
}

output "ssh_connection" {
  description = "SSH connection command"
  value       = "ssh ubuntu@${data.oci_core_vnic.tak_server_vnic.public_ip_address}"
}

output "opentakserver_web_url" {
  description = "OpenTAK Server web interface URL"
  value       = "http://${data.oci_core_vnic.tak_server_vnic.public_ip_address}"
}

output "opentakserver_https_url" {
  description = "OpenTAK Server HTTPS web interface URL"
  value       = "https://${data.oci_core_vnic.tak_server_vnic.public_ip_address}"
}

output "tak_streaming_tcp_endpoint" {
  description = "TAK TCP streaming endpoint for ATAK clients"
  value       = "${data.oci_core_vnic.tak_server_vnic.public_ip_address}:8089"
}

output "tak_streaming_ssl_endpoint" {
  description = "TAK SSL streaming endpoint for ATAK clients"
  value       = "${data.oci_core_vnic.tak_server_vnic.public_ip_address}:8443"
}

output "installation_status_check" {
  description = "Command to check installation status"
  value       = "ssh ubuntu@${data.oci_core_vnic.tak_server_vnic.public_ip_address} 'cat /home/opentakserver/installation_status.txt'"
}

output "installation_logs_check" {
  description = "Command to check installation logs"
  value       = "ssh ubuntu@${data.oci_core_vnic.tak_server_vnic.public_ip_address} 'tail -f /home/opentakserver/ots_ubuntu_installer.log'"
}