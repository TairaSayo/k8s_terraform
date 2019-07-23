# Automation of deploying K8s cluster to AWS EC2

## Requrements

- terraform version 0.12
- AWS account

### To start

- update file variables.tf with
- ssh_key => public part of SSH key
- ssh_priv => private part of SSH key
- access_key => AWS account API access key
- secret_key => AWS account API secret key

### Output

- Public IP of bastion host

### Additional info

- SSH daemon on bastion running on port 443 (22 port blocked in my case)
- K8s nodes can access internet but can't be accessed from internet directly (use bastion)
