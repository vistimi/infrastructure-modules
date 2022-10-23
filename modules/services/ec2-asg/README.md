# ec2-asg

EC2 Auto Scaling Group template

```mermaid
flowchart LR
    Inbound_traffic -- HTTP: 80 --> ALB -- HTTP: server_port --> ASG --> EC2_1 & EC2_2
```